#[starknet::contract]
pub mod ProofRegistry {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};

    // ── Action type constants (must match AgentVault) ──
    const ACTION_REBALANCE: felt252 = 1;
    const ACTION_CATALOG: felt252 = 2;
    const ACTION_SWAP: felt252 = 3;

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct DecisionProof {
        pub agent: ContractAddress,
        pub input_hash: felt252,
        pub output_hash: felt252,
        pub strategy_hash: felt252,
        pub timestamp: u64,
        pub verified: bool,
    }

    /// Portfolio metrics as inputs to the decision function
    #[derive(Drop, Copy, Serde)]
    pub struct PortfolioInput {
        pub balance_sats: felt252,
        pub num_utxos: felt252,
        pub num_ordinals: felt252,
        pub num_runes: felt252,
    }

    /// Strategy parameters
    #[derive(Drop, Copy, Serde)]
    pub struct StrategyParams {
        pub rebalance_threshold: felt252,
        pub max_risk: felt252,
    }

    /// The proposed action output from the agent
    #[derive(Drop, Copy, Serde)]
    pub struct ActionOutput {
        pub action_type: felt252,
        pub amount: felt252,
        pub risk_score: felt252,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress,
        total_proofs: u64,
        proofs: Map<u64, DecisionProof>,
        agent_proof_count: Map<ContractAddress, u64>,
        agent_proofs: Map<(ContractAddress, u64), u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProofSubmitted: ProofSubmitted,
        ProofRejected: ProofRejected,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProofSubmitted {
        #[key]
        pub proof_id: u64,
        #[key]
        pub agent: ContractAddress,
        pub input_hash: felt252,
        pub output_hash: felt252,
        pub strategy_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProofRejected {
        #[key]
        pub agent: ContractAddress,
        pub reason: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl ProofRegistryImpl of super::IProofRegistry<ContractState> {
        /// Submit and verify a decision proof.
        /// The contract independently computes the expected action from inputs + strategy,
        /// then checks that it matches the agent's proposed output.
        fn submit_proof(
            ref self: ContractState,
            portfolio: PortfolioInput,
            strategy: StrategyParams,
            proposed: ActionOutput,
        ) -> u64 {
            let caller = get_caller_address();

            // 1. Hash inputs
            let input_hash = PedersenTrait::new(0)
                .update_with(portfolio.balance_sats)
                .update_with(portfolio.num_utxos)
                .update_with(portfolio.num_ordinals)
                .update_with(portfolio.num_runes)
                .finalize();

            let strategy_hash = PedersenTrait::new(0)
                .update_with(strategy.rebalance_threshold)
                .update_with(strategy.max_risk)
                .finalize();

            let output_hash = PedersenTrait::new(0)
                .update_with(proposed.action_type)
                .update_with(proposed.amount)
                .update_with(proposed.risk_score)
                .finalize();

            // 2. Deterministically compute expected action from portfolio + strategy
            let (expected_type, expected_amount, expected_risk) = InternalImpl::compute_expected_action(
                portfolio, strategy,
            );

            // 3. Verify proposed matches expected
            assert(proposed.action_type == expected_type, 'Wrong action type');
            assert(proposed.amount == expected_amount, 'Wrong amount');
            assert(proposed.risk_score == expected_risk, 'Wrong risk score');

            // 4. Store proof
            let proof_id = self.total_proofs.read();
            let proof = DecisionProof {
                agent: caller,
                input_hash,
                output_hash,
                strategy_hash,
                timestamp: get_block_timestamp(),
                verified: true,
            };
            self.proofs.entry(proof_id).write(proof);
            self.total_proofs.write(proof_id + 1);

            // Index by agent
            let agent_count = self.agent_proof_count.entry(caller).read();
            self.agent_proofs.entry((caller, agent_count)).write(proof_id);
            self.agent_proof_count.entry(caller).write(agent_count + 1);

            self
                .emit(
                    ProofSubmitted {
                        proof_id, agent: caller, input_hash, output_hash, strategy_hash,
                    },
                );

            proof_id
        }

        fn verify_proof(self: @ContractState, proof_id: u64) -> DecisionProof {
            assert(proof_id < self.total_proofs.read(), 'Proof does not exist');
            self.proofs.entry(proof_id).read()
        }

        fn get_proof_count_for_agent(self: @ContractState, agent: ContractAddress) -> u64 {
            self.agent_proof_count.entry(agent).read()
        }

        fn get_proof_id_for_agent(
            self: @ContractState, agent: ContractAddress, index: u64,
        ) -> u64 {
            assert(index < self.agent_proof_count.entry(agent).read(), 'Index out of bounds');
            self.agent_proofs.entry((agent, index)).read()
        }

        fn get_total_proofs(self: @ContractState) -> u64 {
            self.total_proofs.read()
        }

        /// Compute output_hash for a proposed action (useful off-chain to get the proof_hash
        /// that should be passed to AgentVault.propose_action)
        fn compute_output_hash(
            self: @ContractState, action_type: felt252, amount: felt252, risk_score: felt252,
        ) -> felt252 {
            PedersenTrait::new(0)
                .update_with(action_type)
                .update_with(amount)
                .update_with(risk_score)
                .finalize()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Pure deterministic strategy: given portfolio state and strategy params,
        /// compute the ONE correct action. This is the core "ZK proof" —
        /// Cairo re-executes the decision logic so STARK proofs guarantee correctness.
        fn compute_expected_action(
            portfolio: PortfolioInput, strategy: StrategyParams,
        ) -> (felt252, felt252, felt252) {
            let balance: u256 = portfolio.balance_sats.into();
            let threshold: u256 = strategy.rebalance_threshold.into();
            let ordinals: u256 = portfolio.num_ordinals.into();
            let runes: u256 = portfolio.num_runes.into();

            // Priority 1: If balance > threshold → REBALANCE
            if balance > threshold {
                // amount = min(balance / 10, 5000)
                let tenth = balance / 10;
                let amount = if tenth < 5000 { tenth } else { 5000_u256 };
                // risk = max((amount * 100 / balance) + 20, 30)
                let raw_risk = (amount * 100) / balance + 20;
                let risk = if raw_risk < 30 { 30_u256 } else { raw_risk };
                let amount_felt: felt252 = amount.try_into().unwrap();
                let risk_felt: felt252 = risk.try_into().unwrap();
                return (ACTION_REBALANCE, amount_felt, risk_felt);
            }

            // Priority 2: If ordinals > 0 → CATALOG
            if ordinals > 0 {
                return (ACTION_CATALOG, 0, 10);
            }

            // Priority 3: If runes > 0 → SWAP
            if runes > 0 {
                return (ACTION_SWAP, 1000, 40);
            }

            // Default: demo rebalance
            (ACTION_REBALANCE, 100, 5)
        }
    }
}

#[starknet::interface]
pub trait IProofRegistry<TContractState> {
    fn submit_proof(
        ref self: TContractState,
        portfolio: ProofRegistry::PortfolioInput,
        strategy: ProofRegistry::StrategyParams,
        proposed: ProofRegistry::ActionOutput,
    ) -> u64;
    fn verify_proof(self: @TContractState, proof_id: u64) -> ProofRegistry::DecisionProof;
    fn get_proof_count_for_agent(self: @TContractState, agent: starknet::ContractAddress) -> u64;
    fn get_proof_id_for_agent(
        self: @TContractState, agent: starknet::ContractAddress, index: u64,
    ) -> u64;
    fn get_total_proofs(self: @TContractState) -> u64;
    fn compute_output_hash(
        self: @TContractState, action_type: felt252, amount: felt252, risk_score: felt252,
    ) -> felt252;
}
