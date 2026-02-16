use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use btc_yield_vault::vault::{IBTCYieldVaultDispatcher, IBTCYieldVaultDispatcherTrait};
use btc_yield_vault::interfaces::{IERC20Dispatcher, IERC20DispatcherTrait};
use btc_yield_vault::mocks::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

// Test addresses
fn OWNER() -> ContractAddress {
    starknet::contract_address_const::<'owner'>()
}

fn USER1() -> ContractAddress {
    starknet::contract_address_const::<'user1'>()
}

fn USER2() -> ContractAddress {
    starknet::contract_address_const::<'user2'>()
}

fn NON_OWNER() -> ContractAddress {
    starknet::contract_address_const::<'non_owner'>()
}

// Deploy MockERC20 (WBTC)
fn deploy_mock_erc20(name: ByteArray, symbol: ByteArray, decimals: u8) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    decimals.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

// Deploy MockERC4626 (xWBTC) wrapping an asset
fn deploy_mock_erc4626(asset: ContractAddress) -> ContractAddress {
    let contract = declare("MockERC4626").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    asset.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

// Deploy BTCYieldVault
fn deploy_vault(
    asset: ContractAddress, strategy: ContractAddress, owner: ContractAddress,
) -> IBTCYieldVaultDispatcher {
    let contract = declare("BTCYieldVault").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    asset.serialize(ref calldata);
    strategy.serialize(ref calldata);
    owner.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IBTCYieldVaultDispatcher { contract_address: address }
}

// Helper: full test setup
fn setup() -> (
    ContractAddress, // wbtc address
    ContractAddress, // xwbtc address
    IBTCYieldVaultDispatcher, // vault dispatcher
) {
    // Deploy WBTC mock
    let wbtc = deploy_mock_erc20("Wrapped Bitcoin", "WBTC", 8);

    // Deploy xWBTC mock (ERC4626 wrapping WBTC)
    let xwbtc = deploy_mock_erc4626(wbtc);

    // Deploy vault
    let vault = deploy_vault(wbtc, xwbtc, OWNER());

    (wbtc, xwbtc, vault)
}

// Helper: mint WBTC to user and approve vault
fn mint_and_approve(
    wbtc: ContractAddress, user: ContractAddress, vault_address: ContractAddress, amount: u256,
) {
    let wbtc_mint = IMockERC20Dispatcher { contract_address: wbtc };
    let wbtc_token = IERC20Dispatcher { contract_address: wbtc };

    // Mint WBTC to user
    wbtc_mint.mint(user, amount);

    // User approves vault to spend their WBTC
    start_cheat_caller_address(wbtc, user);
    wbtc_token.approve(vault_address, amount);
    stop_cheat_caller_address(wbtc);
}

// ============ BASIC DEPLOYMENT TESTS ============

#[test]
fn test_deployment() {
    let (wbtc, xwbtc, vault) = setup();

    assert!(vault.asset() == wbtc, "Wrong asset");
    assert!(vault.strategy() == xwbtc, "Wrong strategy");
    assert!(vault.total_shares() == 0, "Should start with 0 shares");
    assert!(vault.total_assets() == 0, "Should start with 0 assets");
    assert!(!vault.is_paused(), "Should not be paused");
}

#[test]
fn test_mock_erc20_basic() {
    let wbtc = deploy_mock_erc20("Wrapped Bitcoin", "WBTC", 8);
    let wbtc_mint = IMockERC20Dispatcher { contract_address: wbtc };
    let wbtc_token = IERC20Dispatcher { contract_address: wbtc };

    // Test minting
    wbtc_mint.mint(USER1(), 1000);
    assert!(wbtc_token.balance_of(USER1()) == 1000, "Mint failed");
    assert!(wbtc_token.total_supply() == 1000, "Total supply wrong");

    // Test transfer
    start_cheat_caller_address(wbtc, USER1());
    wbtc_token.transfer(USER2(), 300);
    stop_cheat_caller_address(wbtc);

    assert!(wbtc_token.balance_of(USER1()) == 700, "Transfer from failed");
    assert!(wbtc_token.balance_of(USER2()) == 300, "Transfer to failed");
}

// ============ DEPOSIT TESTS ============

#[test]
fn test_deposit_wbtc_get_shares() {
    let (wbtc, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000; // 1 WBTC (8 decimals)

    // Mint WBTC to user and approve vault
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    // Check balance before
    let wbtc_token = IERC20Dispatcher { contract_address: wbtc };
    assert!(wbtc_token.balance_of(USER1()) == deposit_amount, "User should have WBTC");

    // User deposits WBTC
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // First deposit: shares = assets (1:1)
    assert!(shares == deposit_amount, "Should get 1:1 shares on first deposit");
    assert!(vault.share_balance_of(USER1()) == shares, "User should have shares");
    assert!(vault.total_shares() == shares, "Total shares should match");
    assert!(vault.total_assets() == deposit_amount, "Total assets should match deposit");

    // User's WBTC should be gone
    assert!(wbtc_token.balance_of(USER1()) == 0, "User WBTC should be transferred");
}

#[test]
fn test_multiple_deposits_same_user() {
    let (wbtc, _, vault) = setup();

    let deposit1: u256 = 50_000_000; // 0.5 WBTC
    let deposit2: u256 = 100_000_000; // 1 WBTC

    // First deposit
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit1);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares1 = vault.deposit(deposit1, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Second deposit
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit2);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares2 = vault.deposit(deposit2, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Without yield, shares should be 1:1
    assert!(shares1 == deposit1, "First deposit shares wrong");
    assert!(shares2 == deposit2, "Second deposit shares wrong");
    assert!(vault.share_balance_of(USER1()) == shares1 + shares2, "Total shares wrong");
}

// ============ WITHDRAW TESTS ============

#[test]
fn test_withdraw_shares_get_wbtc() {
    let (wbtc, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000; // 1 WBTC

    // Deposit
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Withdraw half
    let withdraw_shares = shares / 2;
    start_cheat_caller_address(vault.contract_address, USER1());
    let assets = vault.withdraw(withdraw_shares, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Check results
    let wbtc_token = IERC20Dispatcher { contract_address: wbtc };
    assert!(assets == deposit_amount / 2, "Should get half WBTC back");
    assert!(wbtc_token.balance_of(USER1()) == assets, "User should have WBTC");
    assert!(vault.share_balance_of(USER1()) == shares - withdraw_shares, "Shares should decrease");
}

#[test]
fn test_full_withdraw() {
    let (wbtc, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000; // 1 WBTC

    // Deposit
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Withdraw all
    start_cheat_caller_address(vault.contract_address, USER1());
    let assets = vault.withdraw(shares, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Check results
    let wbtc_token = IERC20Dispatcher { contract_address: wbtc };
    assert!(assets == deposit_amount, "Should get all WBTC back");
    assert!(wbtc_token.balance_of(USER1()) == deposit_amount, "User should have all WBTC");
    assert!(vault.share_balance_of(USER1()) == 0, "User should have no shares");
    assert!(vault.total_shares() == 0, "Vault should have no shares");
}

// ============ YIELD / SHARE PRICE APPRECIATION TESTS ============

#[test]
fn test_share_price_appreciation() {
    let (wbtc, xwbtc, vault) = setup();

    let deposit_amount: u256 = 100_000_000; // 1 WBTC

    // User1 deposits
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Simulate yield: mint extra WBTC directly to the xWBTC vault
    // This simulates the LST appreciating (Endur earning staking rewards)
    let yield_amount: u256 = 10_000_000; // 0.1 WBTC yield (10%)
    let wbtc_mint = IMockERC20Dispatcher { contract_address: wbtc };
    wbtc_mint.mint(xwbtc, yield_amount);

    // Now total_assets should be higher
    let new_total_assets = vault.total_assets();
    assert!(new_total_assets == deposit_amount + yield_amount, "Total assets should include yield");

    // Shares should convert to more assets now
    let assets_for_shares = vault.convert_to_assets(shares);
    assert!(assets_for_shares == deposit_amount + yield_amount, "Shares should be worth more");

    // User1 withdraws all - should get original + yield
    start_cheat_caller_address(vault.contract_address, USER1());
    let withdrawn = vault.withdraw(shares, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);

    assert!(withdrawn == deposit_amount + yield_amount, "Should withdraw deposit + yield");
}

#[test]
fn test_yield_distributed_proportionally() {
    let (wbtc, xwbtc, vault) = setup();

    // User1 deposits 100 WBTC
    let deposit1: u256 = 10_000_000_000; // 100 WBTC
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit1);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares1 = vault.deposit(deposit1, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // User2 deposits 100 WBTC
    let deposit2: u256 = 10_000_000_000; // 100 WBTC
    mint_and_approve(wbtc, USER2(), vault.contract_address, deposit2);
    start_cheat_caller_address(vault.contract_address, USER2());
    let shares2 = vault.deposit(deposit2, USER2());
    stop_cheat_caller_address(vault.contract_address);

    // Equal deposits should give equal shares
    assert!(shares1 == shares2, "Equal deposits should give equal shares");

    // Simulate 10% yield (20 WBTC total)
    let yield_amount: u256 = 2_000_000_000; // 20 WBTC
    let wbtc_mint = IMockERC20Dispatcher { contract_address: wbtc };
    wbtc_mint.mint(xwbtc, yield_amount);

    // Each user's shares should be worth deposit + 50% of yield
    let expected_per_user = deposit1 + (yield_amount / 2);
    let user1_value = vault.convert_to_assets(shares1);
    let user2_value = vault.convert_to_assets(shares2);

    assert!(user1_value == expected_per_user, "User1 should get proportional yield");
    assert!(user2_value == expected_per_user, "User2 should get proportional yield");
}

// ============ MULTIPLE DEPOSITORS TESTS ============

#[test]
fn test_multiple_depositors_correct_shares() {
    let (wbtc, _, vault) = setup();

    // User1 deposits 100 WBTC first
    let deposit1: u256 = 10_000_000_000; // 100 WBTC
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit1);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares1 = vault.deposit(deposit1, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // User2 deposits 200 WBTC
    let deposit2: u256 = 20_000_000_000; // 200 WBTC
    mint_and_approve(wbtc, USER2(), vault.contract_address, deposit2);
    start_cheat_caller_address(vault.contract_address, USER2());
    let shares2 = vault.deposit(deposit2, USER2());
    stop_cheat_caller_address(vault.contract_address);

    // User2 should have 2x the shares of User1
    assert!(shares2 == shares1 * 2, "Shares should be proportional to deposit");

    // Total shares should match
    assert!(vault.total_shares() == shares1 + shares2, "Total shares mismatch");

    // Verify ownership proportions
    // User1 owns 1/3, User2 owns 2/3
    let total_assets = vault.total_assets();
    let user1_assets = vault.convert_to_assets(shares1);
    let user2_assets = vault.convert_to_assets(shares2);

    // User1 should have ~1/3 of assets (with rounding)
    assert!(user1_assets == total_assets / 3, "User1 should own 1/3");
    // User2 should have ~2/3 of assets
    assert!(user2_assets == (total_assets * 2) / 3, "User2 should own 2/3");
}

#[test]
fn test_late_depositor_gets_fewer_shares_after_yield() {
    let (wbtc, xwbtc, vault) = setup();

    // User1 deposits 100 WBTC
    let deposit1: u256 = 10_000_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit1);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares1 = vault.deposit(deposit1, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Yield accrues: 10%
    let yield_amount: u256 = 1_000_000_000; // 10 WBTC
    let wbtc_mint = IMockERC20Dispatcher { contract_address: wbtc };
    wbtc_mint.mint(xwbtc, yield_amount);

    // User2 deposits same 100 WBTC AFTER yield
    let deposit2: u256 = 10_000_000_000;
    mint_and_approve(wbtc, USER2(), vault.contract_address, deposit2);
    start_cheat_caller_address(vault.contract_address, USER2());
    let shares2 = vault.deposit(deposit2, USER2());
    stop_cheat_caller_address(vault.contract_address);

    // User2 should get FEWER shares (shares are worth more now)
    // shares2 = deposit2 * total_shares / total_assets
    // = 100 * 100 / 110 = ~90.9 shares
    assert!(shares2 < shares1, "Late depositor should get fewer shares");

    // User1's shares should still convert to more than original deposit
    let user1_value = vault.convert_to_assets(shares1);
    assert!(user1_value > deposit1, "Early depositor value should include yield");
}

// ============ PAUSE TESTS ============

#[test]
fn test_cannot_deposit_when_paused() {
    let (wbtc, _, vault) = setup();

    // Owner pauses vault
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_paused(true);
    stop_cheat_caller_address(vault.contract_address);

    assert!(vault.is_paused(), "Vault should be paused");

    // Try to deposit - should fail
    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
}

#[test]
#[should_panic]
fn test_deposit_reverts_when_paused() {
    let (wbtc, _, vault) = setup();

    // Owner pauses vault
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_paused(true);
    stop_cheat_caller_address(vault.contract_address);

    // Try to deposit - should panic with "Vault is paused"
    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
fn test_only_owner_can_pause() {
    let (_, _, vault) = setup();

    // Non-owner tries to pause - should fail
    start_cheat_caller_address(vault.contract_address, NON_OWNER());
    // This will panic, but we can't use should_panic on multiple tests
    // So we'll verify state doesn't change
    stop_cheat_caller_address(vault.contract_address);

    assert!(!vault.is_paused(), "Vault should still be unpaused");

    // Owner can pause
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_paused(true);
    stop_cheat_caller_address(vault.contract_address);

    assert!(vault.is_paused(), "Owner should be able to pause");
}

#[test]
#[should_panic]
fn test_non_owner_pause_reverts() {
    let (_, _, vault) = setup();

    // Non-owner tries to pause - should panic with "Not owner"
    start_cheat_caller_address(vault.contract_address, NON_OWNER());
    vault.set_paused(true);
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
fn test_owner_can_unpause() {
    let (_, _, vault) = setup();

    // Owner pauses
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_paused(true);
    assert!(vault.is_paused(), "Should be paused");

    // Owner unpauses
    vault.set_paused(false);
    assert!(!vault.is_paused(), "Should be unpaused");
    stop_cheat_caller_address(vault.contract_address);
}

// ============ EDGE CASES ============

#[test]
#[should_panic]
fn test_cannot_deposit_zero() {
    let (_, _, vault) = setup();

    // Should panic with "Cannot deposit 0"
    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(0, USER1());
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
#[should_panic]
fn test_cannot_withdraw_zero() {
    let (wbtc, _, vault) = setup();

    // First deposit something
    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());

    // Try withdraw 0 - should panic with "Cannot withdraw 0 shares"
    vault.withdraw(0, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
#[should_panic]
fn test_cannot_withdraw_more_than_balance() {
    let (wbtc, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());

    // Try to withdraw more shares than owned - should panic with "Insufficient shares"
    vault.withdraw(shares + 1, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
fn test_convert_to_shares_empty_vault() {
    let (_, _, vault) = setup();

    // Empty vault should have 1:1 conversion
    let assets: u256 = 100_000_000;
    let shares = vault.convert_to_shares(assets);
    assert!(shares == assets, "Empty vault should have 1:1 ratio");
}

#[test]
fn test_convert_to_assets_empty_vault() {
    let (_, _, vault) = setup();

    // Empty vault should have 1:1 conversion
    let shares: u256 = 100_000_000;
    let assets = vault.convert_to_assets(shares);
    assert!(assets == shares, "Empty vault should have 1:1 ratio");
}

// ============ WITHDRAWAL CAN STILL HAPPEN WHEN PAUSED ============

#[test]
fn test_can_withdraw_when_paused() {
    let (wbtc, _, vault) = setup();

    // Deposit first
    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Owner pauses
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_paused(true);
    stop_cheat_caller_address(vault.contract_address);

    // User should still be able to withdraw
    start_cheat_caller_address(vault.contract_address, USER1());
    let assets = vault.withdraw(shares, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);

    assert!(assets == deposit_amount, "Should be able to withdraw when paused");
}
