#[starknet::contract]
pub mod AgentVault {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use super::{IProofRegistryVerifierDispatcher, IProofRegistryVerifierDispatcherTrait};

    const DAY_IN_SECONDS: u64 = 86400;
    const ZERO_ADDRESS: felt252 = 0;

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct Constraints {
        pub max_daily_spend: u256,
        pub allowed_action_types: felt252,
        pub max_single_tx: u256,
        pub risk_threshold: u8,
        pub is_active: bool,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct ActionRecord {
        pub action_type: felt252,
        pub amount: u256,
        pub risk_score: u8,
        pub proof_hash: felt252,
        pub timestamp: u64,
        pub approved: bool,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress,
        agent: ContractAddress,
        constraints: Constraints,
        daily_spent: u256,
        last_reset_timestamp: u64,
        total_actions: u64,
        action_history: Map<u64, ActionRecord>,
        // ZK proof integration
        portfolio_commit: felt252,
        strategy_hash: felt252,
        proof_registry: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ActionProposed: ActionProposed,
        ActionApproved: ActionApproved,
        ActionRejected: ActionRejected,
        ConstraintsUpdated: ConstraintsUpdated,
        PortfolioCommitUpdated: PortfolioCommitUpdated,
        ProofRegistryUpdated: ProofRegistryUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ActionProposed {
        #[key]
        pub action_id: u64,
        pub action_type: felt252,
        pub amount: u256,
        pub risk_score: u8,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ActionApproved {
        #[key]
        pub action_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ActionRejected {
        #[key]
        pub action_id: u64,
        pub reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ConstraintsUpdated {
        pub max_daily_spend: u256,
        pub allowed_action_types: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PortfolioCommitUpdated {
        pub state_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProofRegistryUpdated {
        pub registry: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        agent_address: ContractAddress,
        max_daily_spend: u256,
        allowed_action_types: felt252,
        max_single_tx: u256,
        risk_threshold: u8,
        is_active: bool,
        proof_registry: ContractAddress,
    ) {
        self.owner.write(owner);
        self.agent.write(agent_address);
        self
            .constraints
            .write(
                Constraints {
                    max_daily_spend,
                    allowed_action_types,
                    max_single_tx,
                    risk_threshold,
                    is_active,
                },
            );
        self.last_reset_timestamp.write(get_block_timestamp());
        self.proof_registry.write(proof_registry);
    }

    #[abi(embed_v0)]
    impl AgentVaultImpl of super::IAgentVault<ContractState> {
        fn propose_action(
            ref self: ContractState,
            action_type: felt252,
            amount: u256,
            risk_score: u8,
            proof_hash: felt252,
            portfolio_snapshot_hash: felt252,
        ) -> u64 {
            assert(get_caller_address() == self.agent.read(), 'Only agent can propose');

            // Verify portfolio snapshot matches commitment (if commitment is set)
            let commit = self.portfolio_commit.read();
            if commit != 0 {
                assert(portfolio_snapshot_hash == commit, 'Portfolio mismatch');
            }

            let action_id = self.total_actions.read();
            let record = ActionRecord {
                action_type, amount, risk_score, proof_hash, timestamp: get_block_timestamp(), approved: false,
            };
            self.action_history.entry(action_id).write(record);
            self.total_actions.write(action_id + 1);

            self.emit(ActionProposed { action_id, action_type, amount, risk_score });
            action_id
        }

        fn approve_action(ref self: ContractState, action_id: u64) -> bool {
            self._try_reset_daily_limit();

            assert(action_id < self.total_actions.read(), 'Action does not exist');
            let record = self.action_history.entry(action_id).read();
            assert(!record.approved, 'Already approved');

            let constraints = self.constraints.read();

            // Check active
            if !constraints.is_active {
                self.emit(ActionRejected { action_id, reason: 'Vault inactive' });
                return false;
            }

            // Verify proof exists in ProofRegistry (if registry is set and proof_hash is non-zero)
            let registry_addr = self.proof_registry.read();
            let registry_felt: felt252 = registry_addr.into();
            if registry_felt != 0 && record.proof_hash != 0 {
                // proof_hash stores the proof_id from ProofRegistry
                let proof_id_u256: u256 = record.proof_hash.into();
                let proof_id: u64 = proof_id_u256.try_into().unwrap();
                let registry = IProofRegistryVerifierDispatcher { contract_address: registry_addr };
                let proof = registry.verify_proof(proof_id);
                assert(proof.verified, 'Proof not verified');
            }

            // Check action type allowed (bitmap)
            let action_type_felt: felt252 = record.action_type;
            let action_type_u256: u256 = action_type_felt.into();
            let allowed_u256: u256 = constraints.allowed_action_types.into();
            if action_type_u256 & allowed_u256 == 0 {
                self.emit(ActionRejected { action_id, reason: 'Action type not allowed' });
                return false;
            }

            // Check risk
            if record.risk_score > constraints.risk_threshold {
                self.emit(ActionRejected { action_id, reason: 'Risk too high' });
                return false;
            }

            // Check single tx limit
            if record.amount > constraints.max_single_tx {
                self.emit(ActionRejected { action_id, reason: 'Exceeds single tx limit' });
                return false;
            }

            // Check daily spend
            let new_daily = self.daily_spent.read() + record.amount;
            if new_daily > constraints.max_daily_spend {
                self.emit(ActionRejected { action_id, reason: 'Exceeds daily limit' });
                return false;
            }

            // Approve
            self.daily_spent.write(new_daily);
            let approved_record = ActionRecord { approved: true, ..record };
            self.action_history.entry(action_id).write(approved_record);

            self.emit(ActionApproved { action_id });
            true
        }

        fn get_agent_state(
            self: @ContractState,
        ) -> (ContractAddress, u256, u64, u64, Constraints) {
            (
                self.agent.read(),
                self.daily_spent.read(),
                self.last_reset_timestamp.read(),
                self.total_actions.read(),
                self.constraints.read(),
            )
        }

        fn get_action(self: @ContractState, action_id: u64) -> ActionRecord {
            self.action_history.entry(action_id).read()
        }

        fn update_constraints(
            ref self: ContractState,
            max_daily_spend: u256,
            allowed_action_types: felt252,
            max_single_tx: u256,
            risk_threshold: u8,
            is_active: bool,
        ) {
            assert(get_caller_address() == self.owner.read(), 'Only owner');
            let new_constraints = Constraints {
                max_daily_spend, allowed_action_types, max_single_tx, risk_threshold, is_active,
            };
            self.constraints.write(new_constraints);
            self.emit(ConstraintsUpdated { max_daily_spend, allowed_action_types });
        }

        fn reset_daily_limit(ref self: ContractState) {
            self._try_reset_daily_limit();
        }

        fn set_portfolio_commit(ref self: ContractState, state_hash: felt252) {
            let caller = get_caller_address();
            assert(
                caller == self.owner.read() || caller == self.agent.read(),
                'Only owner or agent',
            );
            self.portfolio_commit.write(state_hash);
            self.emit(PortfolioCommitUpdated { state_hash });
        }

        fn set_proof_registry(ref self: ContractState, registry: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), 'Only owner');
            self.proof_registry.write(registry);
            self.emit(ProofRegistryUpdated { registry });
        }

        fn get_portfolio_commit(self: @ContractState) -> felt252 {
            self.portfolio_commit.read()
        }

        fn get_proof_registry(self: @ContractState) -> ContractAddress {
            self.proof_registry.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _try_reset_daily_limit(ref self: ContractState) {
            let now = get_block_timestamp();
            let last = self.last_reset_timestamp.read();
            if now >= last + DAY_IN_SECONDS {
                self.daily_spent.write(0);
                self.last_reset_timestamp.write(now);
            }
        }
    }
}

// Minimal interface for cross-contract ProofRegistry verification
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct DecisionProofView {
    pub agent: starknet::ContractAddress,
    pub input_hash: felt252,
    pub output_hash: felt252,
    pub strategy_hash: felt252,
    pub timestamp: u64,
    pub verified: bool,
}

#[starknet::interface]
pub trait IProofRegistryVerifier<TContractState> {
    fn verify_proof(self: @TContractState, proof_id: u64) -> DecisionProofView;
}

#[starknet::interface]
pub trait IAgentVault<TContractState> {
    fn propose_action(
        ref self: TContractState,
        action_type: felt252,
        amount: u256,
        risk_score: u8,
        proof_hash: felt252,
        portfolio_snapshot_hash: felt252,
    ) -> u64;
    fn approve_action(ref self: TContractState, action_id: u64) -> bool;
    fn get_agent_state(
        self: @TContractState,
    ) -> (
        starknet::ContractAddress,
        u256,
        u64,
        u64,
        AgentVault::Constraints,
    );
    fn get_action(self: @TContractState, action_id: u64) -> AgentVault::ActionRecord;
    fn update_constraints(
        ref self: TContractState,
        max_daily_spend: u256,
        allowed_action_types: felt252,
        max_single_tx: u256,
        risk_threshold: u8,
        is_active: bool,
    );
    fn reset_daily_limit(ref self: TContractState);
    fn set_portfolio_commit(ref self: TContractState, state_hash: felt252);
    fn set_proof_registry(ref self: TContractState, registry: starknet::ContractAddress);
    fn get_portfolio_commit(self: @TContractState) -> felt252;
    fn get_proof_registry(self: @TContractState) -> starknet::ContractAddress;
}
