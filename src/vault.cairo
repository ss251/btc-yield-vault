/// BTCYieldVault — A yield-aggregating vault for BTC on Starknet
///
/// Users deposit WBTC → vault deposits into Endur (xWBTC LST) for staking yield.
/// Vault shares represent proportional ownership of the underlying xWBTC position.
/// Auto-compounds by holding xWBTC which appreciates vs WBTC over time.

#[starknet::contract]
pub mod BTCYieldVault {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use btc_yield_vault::interfaces::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC4626Dispatcher, IERC4626DispatcherTrait,
    };

    #[storage]
    struct Storage {
        /// The underlying BTC token (e.g., WBTC)
        asset: ContractAddress,
        /// The Endur LST vault (e.g., xWBTC - ERC4626)
        strategy: ContractAddress,
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
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposit {
        #[key]
        pub caller: ContractAddress,
        #[key]
        pub receiver: ContractAddress,
        pub assets: u256,
        pub shares: u256,
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
        pub total_shares: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        asset: ContractAddress,
        strategy: ContractAddress,
        owner: ContractAddress,
    ) {
        self.asset.write(asset);
        self.strategy.write(strategy);
        self.owner.write(owner);
        self.total_shares.write(0);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl BTCYieldVaultImpl of super::IBTCYieldVault<ContractState> {
        /// Returns the underlying asset address (WBTC)
        fn asset(self: @ContractState) -> ContractAddress {
            self.asset.read()
        }

        /// Returns the strategy address (Endur xWBTC)
        fn strategy(self: @ContractState) -> ContractAddress {
            self.strategy.read()
        }

        /// Returns total assets under management (WBTC equivalent)
        /// This includes WBTC held directly + WBTC value of xWBTC in Endur
        fn total_assets(self: @ContractState) -> u256 {
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let strategy_vault = IERC4626Dispatcher { contract_address: self.strategy.read() };

            // Direct WBTC balance
            let direct_balance = asset_token.balance_of(get_contract_address());

            // xWBTC shares held by this vault
            let strategy_token = IERC20Dispatcher { contract_address: self.strategy.read() };
            let strategy_shares = strategy_token.balance_of(get_contract_address());

            // Convert xWBTC shares to WBTC equivalent
            let strategy_assets = if strategy_shares > 0 {
                strategy_vault.convert_to_assets(strategy_shares)
            } else {
                0
            };

            direct_balance + strategy_assets
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
        /// Assets are immediately deployed to the Endur strategy
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

            // Deploy to strategy: approve + deposit into Endur xWBTC
            let strategy_addr = self.strategy.read();
            asset_token.approve(strategy_addr, assets);
            let strategy_vault = IERC4626Dispatcher { contract_address: strategy_addr };
            strategy_vault.deposit(assets, this);

            // Mint vault shares to receiver
            let current_shares = self.shares.entry(receiver).read();
            self.shares.entry(receiver).write(current_shares + shares);
            self.total_shares.write(self.total_shares.read() + shares);

            self.emit(Deposit { caller, receiver, assets, shares });

            shares
        }

        /// Withdraw WBTC from the vault by burning shares
        /// Note: Endur withdrawals may involve an NFT queue; this does a direct redeem
        fn withdraw(
            ref self: ContractState,
            shares: u256,
            receiver: ContractAddress,
            owner: ContractAddress,
        ) -> u256 {
            assert!(shares > 0, "Cannot withdraw 0 shares");

            let caller = get_caller_address();
            assert!(caller == owner, "Not authorized"); // Simplified; could add allowances

            let owner_shares = self.shares.entry(owner).read();
            assert!(owner_shares >= shares, "Insufficient shares");

            // Calculate assets to withdraw
            let assets = self.convert_to_assets(shares);
            assert!(assets > 0, "Zero assets");

            // Burn shares
            self.shares.entry(owner).write(owner_shares - shares);
            self.total_shares.write(self.total_shares.read() - shares);

            // Withdraw from strategy
            let strategy_vault = IERC4626Dispatcher { contract_address: self.strategy.read() };
            strategy_vault.withdraw(assets, receiver, get_contract_address());

            self.emit(Withdraw { caller, receiver, owner, assets, shares });

            assets
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
}

use starknet::ContractAddress;

#[starknet::interface]
pub trait IBTCYieldVault<TContractState> {
    fn asset(self: @TContractState) -> ContractAddress;
    fn strategy(self: @TContractState) -> ContractAddress;
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
    fn set_paused(ref self: TContractState, paused: bool);
    fn is_paused(self: @TContractState) -> bool;
}
