use starknet::ContractAddress;

/// ERC-4626 Vault interface (used by Endur LSTs)
#[starknet::interface]
pub trait IERC4626<TContractState> {
    /// Returns the address of the underlying asset
    fn asset(self: @TContractState) -> ContractAddress;
    /// Returns total assets managed by the vault
    fn total_assets(self: @TContractState) -> u256;
    /// Converts assets to shares
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    /// Converts shares to assets
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    /// Maximum deposit amount
    fn max_deposit(self: @TContractState, receiver: ContractAddress) -> u256;
    /// Preview deposit (how many shares for given assets)
    fn preview_deposit(self: @TContractState, assets: u256) -> u256;
    /// Deposit assets and mint shares to receiver
    fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
    /// Maximum mint amount
    fn max_mint(self: @TContractState, receiver: ContractAddress) -> u256;
    /// Preview mint (how many assets needed for given shares)
    fn preview_mint(self: @TContractState, shares: u256) -> u256;
    /// Mint exact shares by depositing assets
    fn mint(ref self: TContractState, shares: u256, receiver: ContractAddress) -> u256;
    /// Maximum withdraw amount
    fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
    /// Preview withdraw (how many shares burned for given assets)
    fn preview_withdraw(self: @TContractState, assets: u256) -> u256;
    /// Withdraw assets by burning shares
    fn withdraw(
        ref self: TContractState, assets: u256, receiver: ContractAddress, owner: ContractAddress,
    ) -> u256;
    /// Maximum redeem amount
    fn max_redeem(self: @TContractState, owner: ContractAddress) -> u256;
    /// Preview redeem (how many assets for given shares)
    fn preview_redeem(self: @TContractState, shares: u256) -> u256;
    /// Redeem shares for assets
    fn redeem(
        ref self: TContractState, shares: u256, receiver: ContractAddress, owner: ContractAddress,
    ) -> u256;
}

/// Standard ERC-20 interface
#[starknet::interface]
pub trait IERC20<TContractState> {
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
}
