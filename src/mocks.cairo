/// Mock contracts for testing the BTC Yield Vault

use starknet::ContractAddress;

/// Simple ERC20 token with mint function for testing
#[starknet::contract]
pub mod MockERC20 {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use btc_yield_vault::interfaces::IERC20;

    #[storage]
    struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: ByteArray, symbol: ByteArray, decimals: u8,
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.total_supply.write(0);
    }

    #[abi(embed_v0)]
    impl MockERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.entry(account).read()
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.entry((owner, spender)).read()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let current_allowance = self.allowances.entry((sender, caller)).read();
            assert!(current_allowance >= amount, "Insufficient allowance");
            self.allowances.entry((sender, caller)).write(current_allowance - amount);
            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let owner = get_caller_address();
            self.allowances.entry((owner, spender)).write(amount);
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let sender_balance = self.balances.entry(sender).read();
            assert!(sender_balance >= amount, "Insufficient balance");
            self.balances.entry(sender).write(sender_balance - amount);
            let recipient_balance = self.balances.entry(recipient).read();
            self.balances.entry(recipient).write(recipient_balance + amount);
        }
    }

    /// Public mint function for testing
    #[external(v0)]
    fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
        let current_balance = self.balances.entry(to).read();
        self.balances.entry(to).write(current_balance + amount);
        self.total_supply.write(self.total_supply.read() + amount);
    }
}

/// Interface for MockERC20's mint function
#[starknet::interface]
pub trait IMockERC20<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
}


/// Simple ERC4626 vault wrapping an ERC20 asset (simulates Endur xWBTC)
#[starknet::contract]
pub mod MockERC4626 {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use btc_yield_vault::interfaces::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait, IERC4626};

    #[storage]
    struct Storage {
        /// Underlying asset (e.g., WBTC)
        asset: ContractAddress,
        /// Share balances
        balances: Map<ContractAddress, u256>,
        /// Allowances
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        /// Total shares
        total_supply: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, asset: ContractAddress) {
        self.asset.write(asset);
        self.total_supply.write(0);
    }

    /// Implement ERC20 interface for share token
    #[abi(embed_v0)]
    impl MockERC4626AsERC20 of IERC20<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "Mock xWBTC"
        }

        fn symbol(self: @ContractState) -> ByteArray {
            "xWBTC"
        }

        fn decimals(self: @ContractState) -> u8 {
            8
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.entry(account).read()
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.entry((owner, spender)).read()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let current_allowance = self.allowances.entry((sender, caller)).read();
            assert!(current_allowance >= amount, "Insufficient allowance");
            self.allowances.entry((sender, caller)).write(current_allowance - amount);
            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let owner = get_caller_address();
            self.allowances.entry((owner, spender)).write(amount);
            true
        }
    }

    /// Implement ERC4626 interface
    #[abi(embed_v0)]
    impl MockERC4626Impl of IERC4626<ContractState> {
        fn asset(self: @ContractState) -> ContractAddress {
            self.asset.read()
        }

        fn total_assets(self: @ContractState) -> u256 {
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.balance_of(get_contract_address())
        }

        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            let total_supply = self.total_supply.read();
            let total_assets = self.total_assets();

            if total_supply == 0 || total_assets == 0 {
                assets // 1:1 ratio initially
            } else {
                (assets * total_supply) / total_assets
            }
        }

        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            let total_supply = self.total_supply.read();
            let total_assets = self.total_assets();

            if total_supply == 0 {
                shares // 1:1 ratio initially
            } else {
                (shares * total_assets) / total_supply
            }
        }

        fn max_deposit(self: @ContractState, receiver: ContractAddress) -> u256 {
            // Unlimited for mock
            let _ = receiver;
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        }

        fn preview_deposit(self: @ContractState, assets: u256) -> u256 {
            self.convert_to_shares(assets)
        }

        fn deposit(ref self: ContractState, assets: u256, receiver: ContractAddress) -> u256 {
            assert!(assets > 0, "Cannot deposit 0");
            let caller = get_caller_address();

            // Calculate shares
            let shares = self.convert_to_shares(assets);

            // Transfer assets from caller
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.transfer_from(caller, get_contract_address(), assets);

            // Mint shares
            let current = self.balances.entry(receiver).read();
            self.balances.entry(receiver).write(current + shares);
            self.total_supply.write(self.total_supply.read() + shares);

            shares
        }

        fn max_mint(self: @ContractState, receiver: ContractAddress) -> u256 {
            let _ = receiver;
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        }

        fn preview_mint(self: @ContractState, shares: u256) -> u256 {
            self.convert_to_assets(shares)
        }

        fn mint(ref self: ContractState, shares: u256, receiver: ContractAddress) -> u256 {
            let assets = self.convert_to_assets(shares);
            let caller = get_caller_address();

            // Transfer assets
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.transfer_from(caller, get_contract_address(), assets);

            // Mint shares
            let current = self.balances.entry(receiver).read();
            self.balances.entry(receiver).write(current + shares);
            self.total_supply.write(self.total_supply.read() + shares);

            assets
        }

        fn max_withdraw(self: @ContractState, owner: ContractAddress) -> u256 {
            self.convert_to_assets(self.balances.entry(owner).read())
        }

        fn preview_withdraw(self: @ContractState, assets: u256) -> u256 {
            self.convert_to_shares(assets)
        }

        fn withdraw(
            ref self: ContractState,
            assets: u256,
            receiver: ContractAddress,
            owner: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();

            // Calculate shares to burn
            let shares = self.convert_to_shares(assets);
            let owner_balance = self.balances.entry(owner).read();
            assert!(owner_balance >= shares, "Insufficient shares");

            // Handle allowance if caller != owner
            if caller != owner {
                let current_allowance = self.allowances.entry((owner, caller)).read();
                assert!(current_allowance >= shares, "Insufficient allowance");
                self.allowances.entry((owner, caller)).write(current_allowance - shares);
            }

            // Burn shares
            self.balances.entry(owner).write(owner_balance - shares);
            self.total_supply.write(self.total_supply.read() - shares);

            // Transfer assets to receiver
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.transfer(receiver, assets);

            shares
        }

        fn max_redeem(self: @ContractState, owner: ContractAddress) -> u256 {
            self.balances.entry(owner).read()
        }

        fn preview_redeem(self: @ContractState, shares: u256) -> u256 {
            self.convert_to_assets(shares)
        }

        fn redeem(
            ref self: ContractState,
            shares: u256,
            receiver: ContractAddress,
            owner: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();
            let owner_balance = self.balances.entry(owner).read();
            assert!(owner_balance >= shares, "Insufficient shares");

            // Handle allowance if caller != owner
            if caller != owner {
                let current_allowance = self.allowances.entry((owner, caller)).read();
                assert!(current_allowance >= shares, "Insufficient allowance");
                self.allowances.entry((owner, caller)).write(current_allowance - shares);
            }

            // Calculate assets
            let assets = self.convert_to_assets(shares);

            // Burn shares
            self.balances.entry(owner).write(owner_balance - shares);
            self.total_supply.write(self.total_supply.read() - shares);

            // Transfer assets
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.transfer(receiver, assets);

            assets
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let sender_balance = self.balances.entry(sender).read();
            assert!(sender_balance >= amount, "Insufficient balance");
            self.balances.entry(sender).write(sender_balance - amount);
            let recipient_balance = self.balances.entry(recipient).read();
            self.balances.entry(recipient).write(recipient_balance + amount);
        }
    }
}
