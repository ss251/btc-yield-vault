/// BTCMultiStrategyVault — A multi-strategy yield vault for BTC on Starknet
///
/// Users deposit WBTC → vault splits deposits across multiple ERC-4626 strategies
/// (e.g., Endur staking + Vesu V2 lending) based on configurable allocation.
/// Vault shares represent proportional ownership of all underlying positions.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IBTCMultiStrategyVault<TContractState> {
    fn asset(self: @TContractState) -> ContractAddress;
    fn strategy1(self: @TContractState) -> ContractAddress;
    fn strategy2(self: @TContractState) -> ContractAddress;
    fn allocation(self: @TContractState) -> (u256, u256); // (strategy1_bps, strategy2_bps)
    fn total_assets(self: @TContractState) -> u256;
    fn total_shares(self: @TContractState) -> u256;
    fn share_balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
    fn withdraw(
        ref self: TContractState,
        shares: u256,
        receiver: ContractAddress,
        owner: ContractAddress,
    ) -> u256;
    fn set_allocation(ref self: TContractState, strategy1_bps: u256, strategy2_bps: u256);
    fn harvest(self: @TContractState) -> u256;
    fn rebalance(ref self: TContractState);
    fn set_paused(ref self: TContractState, paused: bool);
    fn is_paused(self: @TContractState) -> bool;
}

#[starknet::contract]
pub mod BTCMultiStrategyVault {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use btc_yield_vault::interfaces::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC4626Dispatcher, IERC4626DispatcherTrait,
    };

    /// Basis points constant (100% = 10000 bps)
    const BPS_DENOMINATOR: u256 = 10000;

    #[storage]
    struct Storage {
        /// The underlying BTC token (e.g., WBTC)
        asset: ContractAddress,
        /// Strategy 1 (e.g., Endur xWBTC - ERC4626)
        strategy1: ContractAddress,
        /// Strategy 2 (e.g., Vesu V2 - ERC4626)
        strategy2: ContractAddress,
        /// Allocation to strategy 1 in basis points (e.g., 6000 = 60%)
        strategy1_allocation_bps: u256,
        /// Allocation to strategy 2 in basis points (e.g., 4000 = 40%)
        strategy2_allocation_bps: u256,
        /// Vault owner/admin
        owner: ContractAddress,
        /// Total vault shares outstanding
        total_shares: u256,
        /// Share balances per user
        shares: Map<ContractAddress, u256>,
        /// Whether deposits are paused
        paused: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
        Harvest: Harvest,
        Rebalance: Rebalance,
        AllocationChanged: AllocationChanged,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposit {
        #[key]
        pub caller: ContractAddress,
        #[key]
        pub receiver: ContractAddress,
        pub assets: u256,
        pub shares: u256,
        pub strategy1_deposit: u256,
        pub strategy2_deposit: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdraw {
        #[key]
        pub caller: ContractAddress,
        #[key]
        pub receiver: ContractAddress,
        #[key]
        pub owner: ContractAddress,
        pub assets: u256,
        pub shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Harvest {
        pub total_assets: u256,
        pub strategy1_assets: u256,
        pub strategy2_assets: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Rebalance {
        pub strategy1_before: u256,
        pub strategy1_after: u256,
        pub strategy2_before: u256,
        pub strategy2_after: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AllocationChanged {
        pub old_strategy1_bps: u256,
        pub old_strategy2_bps: u256,
        pub new_strategy1_bps: u256,
        pub new_strategy2_bps: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        asset: ContractAddress,
        strategy1: ContractAddress,
        strategy2: ContractAddress,
        strategy1_allocation_bps: u256,
        strategy2_allocation_bps: u256,
        owner: ContractAddress,
    ) {
        assert!(
            strategy1_allocation_bps + strategy2_allocation_bps == BPS_DENOMINATOR,
            "Allocations must sum to 10000 bps",
        );
        self.asset.write(asset);
        self.strategy1.write(strategy1);
        self.strategy2.write(strategy2);
        self.strategy1_allocation_bps.write(strategy1_allocation_bps);
        self.strategy2_allocation_bps.write(strategy2_allocation_bps);
        self.owner.write(owner);
        self.total_shares.write(0);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl BTCMultiStrategyVaultImpl of super::IBTCMultiStrategyVault<ContractState> {
        /// Returns the underlying asset address (WBTC)
        fn asset(self: @ContractState) -> ContractAddress {
            self.asset.read()
        }

        /// Returns strategy 1 address
        fn strategy1(self: @ContractState) -> ContractAddress {
            self.strategy1.read()
        }

        /// Returns strategy 2 address
        fn strategy2(self: @ContractState) -> ContractAddress {
            self.strategy2.read()
        }

        /// Returns current allocation in basis points
        fn allocation(self: @ContractState) -> (u256, u256) {
            (self.strategy1_allocation_bps.read(), self.strategy2_allocation_bps.read())
        }

        /// Returns total assets under management (WBTC equivalent)
        /// This includes WBTC value across both strategies
        fn total_assets(self: @ContractState) -> u256 {
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };

            // Direct WBTC balance held by vault
            let direct_balance = asset_token.balance_of(get_contract_address());

            // Assets in strategy 1
            let strategy1_assets = self._get_strategy_assets(self.strategy1.read());

            // Assets in strategy 2
            let strategy2_assets = self._get_strategy_assets(self.strategy2.read());

            direct_balance + strategy1_assets + strategy2_assets
        }

        /// Returns total vault shares outstanding
        fn total_shares(self: @ContractState) -> u256 {
            self.total_shares.read()
        }

        /// Returns share balance of an account
        fn share_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.shares.entry(account).read()
        }

        /// Convert asset amount to share amount
        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            let total_shares = self.total_shares.read();
            let total_assets = self.total_assets();

            if total_shares == 0 || total_assets == 0 {
                assets // 1:1 ratio for first deposit
            } else {
                (assets * total_shares) / total_assets
            }
        }

        /// Convert share amount to asset amount
        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            let total_shares = self.total_shares.read();
            let total_assets = self.total_assets();

            if total_shares == 0 {
                shares // 1:1 ratio
            } else {
                (shares * total_assets) / total_shares
            }
        }

        /// Deposit WBTC into the vault, receive vault shares
        /// Assets are split across strategies based on allocation
        fn deposit(ref self: ContractState, assets: u256, receiver: ContractAddress) -> u256 {
            assert!(!self.paused.read(), "Vault is paused");
            assert!(assets > 0, "Cannot deposit 0");

            let caller = get_caller_address();
            let this = get_contract_address();

            // Calculate shares before transfer (using current ratio)
            let shares = self.convert_to_shares(assets);
            assert!(shares > 0, "Zero shares");

            // Transfer WBTC from caller to vault
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.transfer_from(caller, this, assets);

            // Calculate split based on allocation
            let strategy1_bps = self.strategy1_allocation_bps.read();
            let strategy1_amount = (assets * strategy1_bps) / BPS_DENOMINATOR;
            let strategy2_amount = assets - strategy1_amount; // Remainder to avoid rounding issues

            // Deploy to strategy 1
            let strategy1_addr = self.strategy1.read();
            if strategy1_amount > 0 {
                asset_token.approve(strategy1_addr, strategy1_amount);
                let strategy1_vault = IERC4626Dispatcher { contract_address: strategy1_addr };
                strategy1_vault.deposit(strategy1_amount, this);
            }

            // Deploy to strategy 2
            let strategy2_addr = self.strategy2.read();
            if strategy2_amount > 0 {
                asset_token.approve(strategy2_addr, strategy2_amount);
                let strategy2_vault = IERC4626Dispatcher { contract_address: strategy2_addr };
                strategy2_vault.deposit(strategy2_amount, this);
            }

            // Mint vault shares to receiver
            let current_shares = self.shares.entry(receiver).read();
            self.shares.entry(receiver).write(current_shares + shares);
            self.total_shares.write(self.total_shares.read() + shares);

            self
                .emit(
                    Deposit {
                        caller,
                        receiver,
                        assets,
                        shares,
                        strategy1_deposit: strategy1_amount,
                        strategy2_deposit: strategy2_amount,
                    },
                );

            shares
        }

        /// Withdraw WBTC from the vault by burning shares
        /// Withdraws proportionally from both strategies
        fn withdraw(
            ref self: ContractState,
            shares: u256,
            receiver: ContractAddress,
            owner: ContractAddress,
        ) -> u256 {
            assert!(shares > 0, "Cannot withdraw 0 shares");

            let caller = get_caller_address();
            assert!(caller == owner, "Not authorized");

            let owner_shares = self.shares.entry(owner).read();
            assert!(owner_shares >= shares, "Insufficient shares");

            // Calculate assets to withdraw
            let assets = self.convert_to_assets(shares);
            assert!(assets > 0, "Zero assets");

            // Burn shares first
            self.shares.entry(owner).write(owner_shares - shares);
            self.total_shares.write(self.total_shares.read() - shares);

            let this = get_contract_address();

            // Calculate proportion of assets in each strategy
            let strategy1_assets = self._get_strategy_assets(self.strategy1.read());
            let strategy2_assets = self._get_strategy_assets(self.strategy2.read());
            let total_in_strategies = strategy1_assets + strategy2_assets;

            let mut withdrawn: u256 = 0;

            // Withdraw proportionally from each strategy
            if total_in_strategies > 0 {
                // Calculate how much to withdraw from each strategy
                let withdraw_from_1 = if strategy1_assets > 0 {
                    (assets * strategy1_assets) / total_in_strategies
                } else {
                    0
                };
                let withdraw_from_2 = assets - withdraw_from_1; // Remainder

                // Withdraw from strategy 1
                if withdraw_from_1 > 0 && strategy1_assets >= withdraw_from_1 {
                    let strategy1_vault = IERC4626Dispatcher {
                        contract_address: self.strategy1.read(),
                    };
                    strategy1_vault.withdraw(withdraw_from_1, receiver, this);
                    withdrawn += withdraw_from_1;
                }

                // Withdraw from strategy 2
                if withdraw_from_2 > 0 && strategy2_assets >= withdraw_from_2 {
                    let strategy2_vault = IERC4626Dispatcher {
                        contract_address: self.strategy2.read(),
                    };
                    strategy2_vault.withdraw(withdraw_from_2, receiver, this);
                    withdrawn += withdraw_from_2;
                }
            }

            self.emit(Withdraw { caller, receiver, owner, assets: withdrawn, shares });

            withdrawn
        }

        /// Set new allocation (owner only)
        /// Does NOT automatically rebalance - call rebalance() separately
        fn set_allocation(ref self: ContractState, strategy1_bps: u256, strategy2_bps: u256) {
            assert!(get_caller_address() == self.owner.read(), "Not owner");
            assert!(
                strategy1_bps + strategy2_bps == BPS_DENOMINATOR, "Allocations must sum to 10000",
            );

            let old_strategy1_bps = self.strategy1_allocation_bps.read();
            let old_strategy2_bps = self.strategy2_allocation_bps.read();

            self.strategy1_allocation_bps.write(strategy1_bps);
            self.strategy2_allocation_bps.write(strategy2_bps);

            self
                .emit(
                    AllocationChanged {
                        old_strategy1_bps,
                        old_strategy2_bps,
                        new_strategy1_bps: strategy1_bps,
                        new_strategy2_bps: strategy2_bps,
                    },
                );
        }

        /// Report current total assets across both strategies
        fn harvest(self: @ContractState) -> u256 {
            let strategy1_assets = self._get_strategy_assets(self.strategy1.read());
            let strategy2_assets = self._get_strategy_assets(self.strategy2.read());
            let total = strategy1_assets + strategy2_assets;

            // Note: events can only be emitted in mutable functions
            // This is a view function, so we just return the value
            total
        }

        /// Rebalance assets between strategies based on current allocation
        fn rebalance(ref self: ContractState) {
            let this = get_contract_address();
            let asset_addr = self.asset.read();
            let asset_token = IERC20Dispatcher { contract_address: asset_addr };

            // Get current assets in each strategy
            let strategy1_assets_before = self._get_strategy_assets(self.strategy1.read());
            let strategy2_assets_before = self._get_strategy_assets(self.strategy2.read());
            let total_assets = strategy1_assets_before + strategy2_assets_before;

            if total_assets == 0 {
                return; // Nothing to rebalance
            }

            // Calculate target amounts based on allocation
            let strategy1_bps = self.strategy1_allocation_bps.read();
            let target_strategy1 = (total_assets * strategy1_bps) / BPS_DENOMINATOR;
            let target_strategy2 = total_assets - target_strategy1;

            let strategy1_addr = self.strategy1.read();
            let strategy2_addr = self.strategy2.read();
            let strategy1_vault = IERC4626Dispatcher { contract_address: strategy1_addr };
            let strategy2_vault = IERC4626Dispatcher { contract_address: strategy2_addr };

            // Rebalance: withdraw excess from one, deposit to the other
            if strategy1_assets_before > target_strategy1 {
                // Move from strategy1 to strategy2
                let amount_to_move = strategy1_assets_before - target_strategy1;
                // Withdraw from strategy1 to vault
                strategy1_vault.withdraw(amount_to_move, this, this);
                // Deposit to strategy2
                asset_token.approve(strategy2_addr, amount_to_move);
                strategy2_vault.deposit(amount_to_move, this);
            } else if strategy2_assets_before > target_strategy2 {
                // Move from strategy2 to strategy1
                let amount_to_move = strategy2_assets_before - target_strategy2;
                // Withdraw from strategy2 to vault
                strategy2_vault.withdraw(amount_to_move, this, this);
                // Deposit to strategy1
                asset_token.approve(strategy1_addr, amount_to_move);
                strategy1_vault.deposit(amount_to_move, this);
            }

            // Get final assets
            let strategy1_assets_after = self._get_strategy_assets(self.strategy1.read());
            let strategy2_assets_after = self._get_strategy_assets(self.strategy2.read());

            self
                .emit(
                    Rebalance {
                        strategy1_before: strategy1_assets_before,
                        strategy1_after: strategy1_assets_after,
                        strategy2_before: strategy2_assets_before,
                        strategy2_after: strategy2_assets_after,
                    },
                );
        }

        /// Pause/unpause deposits (owner only)
        fn set_paused(ref self: ContractState, paused: bool) {
            assert!(get_caller_address() == self.owner.read(), "Not owner");
            self.paused.write(paused);
        }

        /// Returns whether the vault is paused
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Get assets held in a strategy (converts strategy shares to underlying assets)
        fn _get_strategy_assets(self: @ContractState, strategy: ContractAddress) -> u256 {
            let strategy_token = IERC20Dispatcher { contract_address: strategy };
            let strategy_vault = IERC4626Dispatcher { contract_address: strategy };
            let strategy_shares = strategy_token.balance_of(get_contract_address());

            if strategy_shares > 0 {
                strategy_vault.convert_to_assets(strategy_shares)
            } else {
                0
            }
        }
    }
}
