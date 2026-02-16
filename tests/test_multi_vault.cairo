use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use btc_yield_vault::multi_vault::{
    IBTCMultiStrategyVaultDispatcher, IBTCMultiStrategyVaultDispatcherTrait,
};
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

// Deploy MockERC4626 wrapping an asset
fn deploy_mock_erc4626(asset: ContractAddress) -> ContractAddress {
    let contract = declare("MockERC4626").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    asset.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

// Deploy BTCMultiStrategyVault
fn deploy_multi_vault(
    asset: ContractAddress,
    strategy1: ContractAddress,
    strategy2: ContractAddress,
    strategy1_bps: u256,
    strategy2_bps: u256,
    owner: ContractAddress,
) -> IBTCMultiStrategyVaultDispatcher {
    let contract = declare("BTCMultiStrategyVault").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    asset.serialize(ref calldata);
    strategy1.serialize(ref calldata);
    strategy2.serialize(ref calldata);
    strategy1_bps.serialize(ref calldata);
    strategy2_bps.serialize(ref calldata);
    owner.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    IBTCMultiStrategyVaultDispatcher { contract_address: address }
}

// Helper: full test setup with 60/40 allocation
fn setup() -> (
    ContractAddress, // wbtc address
    ContractAddress, // strategy1 (Endur xWBTC)
    ContractAddress, // strategy2 (Vesu)
    IBTCMultiStrategyVaultDispatcher, // vault dispatcher
) {
    // Deploy WBTC mock
    let wbtc = deploy_mock_erc20("Wrapped Bitcoin", "WBTC", 8);

    // Deploy two ERC4626 strategies (both wrapping WBTC)
    let strategy1 = deploy_mock_erc4626(wbtc); // Endur xWBTC
    let strategy2 = deploy_mock_erc4626(wbtc); // Vesu vWBTC

    // Deploy multi-vault with 60/40 allocation
    let vault = deploy_multi_vault(wbtc, strategy1, strategy2, 6000, 4000, OWNER());

    (wbtc, strategy1, strategy2, vault)
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

// ============ DEPLOYMENT TESTS ============

#[test]
fn test_multi_vault_deployment() {
    let (wbtc, strategy1, strategy2, vault) = setup();

    assert!(vault.asset() == wbtc, "Wrong asset");
    assert!(vault.strategy1() == strategy1, "Wrong strategy1");
    assert!(vault.strategy2() == strategy2, "Wrong strategy2");

    let (s1_bps, s2_bps) = vault.allocation();
    assert!(s1_bps == 6000, "Wrong strategy1 allocation");
    assert!(s2_bps == 4000, "Wrong strategy2 allocation");

    assert!(vault.total_shares() == 0, "Should start with 0 shares");
    assert!(vault.total_assets() == 0, "Should start with 0 assets");
    assert!(!vault.is_paused(), "Should not be paused");
}

#[test]
fn test_deploy_with_different_allocations() {
    let wbtc = deploy_mock_erc20("Wrapped Bitcoin", "WBTC", 8);
    let strategy1 = deploy_mock_erc4626(wbtc);
    let strategy2 = deploy_mock_erc4626(wbtc);

    // 50/50 allocation
    let vault = deploy_multi_vault(wbtc, strategy1, strategy2, 5000, 5000, OWNER());
    let (s1_bps, s2_bps) = vault.allocation();
    assert!(s1_bps == 5000, "Should be 50%");
    assert!(s2_bps == 5000, "Should be 50%");
}

// ============ DEPOSIT SPLIT TESTS ============

#[test]
fn test_deposit_splits_correctly() {
    let (wbtc, strategy1, strategy2, vault) = setup();

    let deposit_amount: u256 = 100_000_000; // 1 WBTC

    // Mint and approve
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    // User deposits
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Check shares
    assert!(shares == deposit_amount, "Should get 1:1 shares on first deposit");
    assert!(vault.share_balance_of(USER1()) == shares, "User should have shares");

    // Check strategy balances (60/40 split)
    let strategy1_token = IERC20Dispatcher { contract_address: strategy1 };
    let strategy2_token = IERC20Dispatcher { contract_address: strategy2 };

    let s1_shares = strategy1_token.balance_of(vault.contract_address);
    let s2_shares = strategy2_token.balance_of(vault.contract_address);

    // With 60/40 split: 60M and 40M
    assert!(s1_shares == 60_000_000, "Strategy1 should have 60% of deposit");
    assert!(s2_shares == 40_000_000, "Strategy2 should have 40% of deposit");

    // Total assets should equal deposit
    assert!(vault.total_assets() == deposit_amount, "Total assets should match deposit");
}

#[test]
fn test_deposit_with_50_50_split() {
    let wbtc = deploy_mock_erc20("Wrapped Bitcoin", "WBTC", 8);
    let strategy1 = deploy_mock_erc4626(wbtc);
    let strategy2 = deploy_mock_erc4626(wbtc);
    let vault = deploy_multi_vault(wbtc, strategy1, strategy2, 5000, 5000, OWNER());

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    let strategy1_token = IERC20Dispatcher { contract_address: strategy1 };
    let strategy2_token = IERC20Dispatcher { contract_address: strategy2 };

    let s1_shares = strategy1_token.balance_of(vault.contract_address);
    let s2_shares = strategy2_token.balance_of(vault.contract_address);

    assert!(s1_shares == 50_000_000, "Strategy1 should have 50%");
    assert!(s2_shares == 50_000_000, "Strategy2 should have 50%");
}

// ============ WITHDRAW TESTS ============

#[test]
fn test_withdraw_pulls_from_both_strategies() {
    let (wbtc, _, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    // Deposit
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Withdraw half
    let withdraw_shares = shares / 2;
    start_cheat_caller_address(vault.contract_address, USER1());
    let assets = vault.withdraw(withdraw_shares, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Should get half the assets back
    let wbtc_token = IERC20Dispatcher { contract_address: wbtc };
    assert!(assets == deposit_amount / 2, "Should withdraw half");
    assert!(wbtc_token.balance_of(USER1()) == assets, "User should have WBTC");
    assert!(vault.share_balance_of(USER1()) == shares - withdraw_shares, "Shares should decrease");
}

#[test]
fn test_full_withdraw_from_both_strategies() {
    let (wbtc, _, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    // Deposit
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Full withdraw
    start_cheat_caller_address(vault.contract_address, USER1());
    let assets = vault.withdraw(shares, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);

    let wbtc_token = IERC20Dispatcher { contract_address: wbtc };
    assert!(assets == deposit_amount, "Should withdraw all");
    assert!(wbtc_token.balance_of(USER1()) == deposit_amount, "User should have all WBTC");
    assert!(vault.share_balance_of(USER1()) == 0, "User should have no shares");
    assert!(vault.total_shares() == 0, "Vault should have no shares");
}

// ============ ALLOCATION CHANGE TESTS ============

#[test]
fn test_owner_can_change_allocation() {
    let (_, _, _, vault) = setup();

    // Check initial
    let (s1_bps, s2_bps) = vault.allocation();
    assert!(s1_bps == 6000, "Initial s1 should be 60%");
    assert!(s2_bps == 4000, "Initial s2 should be 40%");

    // Owner changes allocation to 30/70
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_allocation(3000, 7000);
    stop_cheat_caller_address(vault.contract_address);

    let (new_s1_bps, new_s2_bps) = vault.allocation();
    assert!(new_s1_bps == 3000, "New s1 should be 30%");
    assert!(new_s2_bps == 7000, "New s2 should be 70%");
}

#[test]
#[should_panic]
fn test_non_owner_cannot_change_allocation() {
    let (_, _, _, vault) = setup();

    // Non-owner tries to change allocation
    start_cheat_caller_address(vault.contract_address, NON_OWNER());
    vault.set_allocation(5000, 5000);
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
#[should_panic]
fn test_allocation_must_sum_to_100() {
    let (_, _, _, vault) = setup();

    // Try invalid allocation (doesn't sum to 10000)
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_allocation(5000, 4000); // Only 90%
    stop_cheat_caller_address(vault.contract_address);
}

// ============ REBALANCE TESTS ============

#[test]
fn test_rebalance_moves_funds() {
    let (wbtc, strategy1, strategy2, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    // Deposit with 60/40 allocation
    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Check initial split
    let strategy1_token = IERC20Dispatcher { contract_address: strategy1 };
    let strategy2_token = IERC20Dispatcher { contract_address: strategy2 };

    let s1_before = strategy1_token.balance_of(vault.contract_address);
    let s2_before = strategy2_token.balance_of(vault.contract_address);
    assert!(s1_before == 60_000_000, "Strategy1 should have 60M before");
    assert!(s2_before == 40_000_000, "Strategy2 should have 40M before");

    // Change allocation to 40/60
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_allocation(4000, 6000);
    stop_cheat_caller_address(vault.contract_address);

    // Rebalance (no owner check needed for rebalance)
    vault.rebalance();

    // Check new split
    let s1_after = strategy1_token.balance_of(vault.contract_address);
    let s2_after = strategy2_token.balance_of(vault.contract_address);

    // Should now be 40/60 (40M / 60M)
    assert!(s1_after == 40_000_000, "Strategy1 should have 40M after rebalance");
    assert!(s2_after == 60_000_000, "Strategy2 should have 60M after rebalance");

    // Total assets should be unchanged
    assert!(vault.total_assets() == deposit_amount, "Total assets should be unchanged");
}

#[test]
fn test_rebalance_from_strategy2_to_strategy1() {
    let (wbtc, strategy1, strategy2, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    // Deposit with 60/40 allocation
    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Change allocation to 80/20 (need to move more to strategy1)
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_allocation(8000, 2000);
    stop_cheat_caller_address(vault.contract_address);

    // Rebalance
    vault.rebalance();

    // Check new split
    let strategy1_token = IERC20Dispatcher { contract_address: strategy1 };
    let strategy2_token = IERC20Dispatcher { contract_address: strategy2 };

    let s1_after = strategy1_token.balance_of(vault.contract_address);
    let s2_after = strategy2_token.balance_of(vault.contract_address);

    assert!(s1_after == 80_000_000, "Strategy1 should have 80M after rebalance");
    assert!(s2_after == 20_000_000, "Strategy2 should have 20M after rebalance");
}

#[test]
fn test_rebalance_with_no_change_needed() {
    let (wbtc, strategy1, strategy2, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Rebalance without changing allocation - should be no-op
    vault.rebalance();

    let strategy1_token = IERC20Dispatcher { contract_address: strategy1 };
    let strategy2_token = IERC20Dispatcher { contract_address: strategy2 };

    let s1_shares = strategy1_token.balance_of(vault.contract_address);
    let s2_shares = strategy2_token.balance_of(vault.contract_address);

    assert!(s1_shares == 60_000_000, "Strategy1 should still have 60M");
    assert!(s2_shares == 40_000_000, "Strategy2 should still have 40M");
}

// ============ HARVEST TESTS ============

#[test]
fn test_harvest_reports_total_assets() {
    let (wbtc, _, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Harvest should report total assets
    let total = vault.harvest();
    assert!(total == deposit_amount, "Harvest should report total assets");
}

#[test]
fn test_total_assets_sums_both_strategies() {
    let (wbtc, strategy1, strategy2, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);

    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // Simulate yield in strategy1 (10%)
    let yield_amount: u256 = 10_000_000;
    let wbtc_mint = IMockERC20Dispatcher { contract_address: wbtc };
    wbtc_mint.mint(strategy1, yield_amount);

    // Total assets should now include yield
    let total = vault.total_assets();
    assert!(total == deposit_amount + yield_amount, "Total should include yield from strategy1");

    // Add yield to strategy2 as well
    wbtc_mint.mint(strategy2, yield_amount);
    let total_with_both = vault.total_assets();
    assert!(
        total_with_both == deposit_amount + (yield_amount * 2),
        "Total should include yield from both strategies",
    );
}

// ============ YIELD DISTRIBUTION TESTS ============

#[test]
fn test_yield_distributed_proportionally() {
    let (wbtc, strategy1, _, vault) = setup();

    // User1 deposits 100 WBTC
    let deposit1: u256 = 10_000_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit1);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares1 = vault.deposit(deposit1, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // User2 deposits 100 WBTC
    let deposit2: u256 = 10_000_000_000;
    mint_and_approve(wbtc, USER2(), vault.contract_address, deposit2);
    start_cheat_caller_address(vault.contract_address, USER2());
    let shares2 = vault.deposit(deposit2, USER2());
    stop_cheat_caller_address(vault.contract_address);

    assert!(shares1 == shares2, "Equal deposits should give equal shares");

    // Simulate 10% yield in strategy1
    let yield_amount: u256 = 2_000_000_000; // 20 WBTC
    let wbtc_mint = IMockERC20Dispatcher { contract_address: wbtc };
    wbtc_mint.mint(strategy1, yield_amount);

    // Each user's shares should be worth deposit + 50% of yield
    let expected_per_user = deposit1 + (yield_amount / 2);
    let user1_value = vault.convert_to_assets(shares1);
    let user2_value = vault.convert_to_assets(shares2);

    assert!(user1_value == expected_per_user, "User1 should get proportional yield");
    assert!(user2_value == expected_per_user, "User2 should get proportional yield");
}

// ============ PAUSE TESTS ============

#[test]
#[should_panic]
fn test_cannot_deposit_when_paused() {
    let (wbtc, _, _, vault) = setup();

    // Owner pauses vault
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_paused(true);
    stop_cheat_caller_address(vault.contract_address);

    assert!(vault.is_paused(), "Vault should be paused");

    // Try to deposit - should fail
    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
fn test_can_withdraw_when_paused() {
    let (wbtc, _, _, vault) = setup();

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

#[test]
#[should_panic]
fn test_non_owner_cannot_pause() {
    let (_, _, _, vault) = setup();

    start_cheat_caller_address(vault.contract_address, NON_OWNER());
    vault.set_paused(true);
    stop_cheat_caller_address(vault.contract_address);
}

// ============ EDGE CASES ============

#[test]
#[should_panic]
fn test_cannot_deposit_zero() {
    let (_, _, _, vault) = setup();

    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(0, USER1());
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
#[should_panic]
fn test_cannot_withdraw_zero() {
    let (wbtc, _, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    vault.deposit(deposit_amount, USER1());

    vault.withdraw(0, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
#[should_panic]
fn test_cannot_withdraw_more_than_balance() {
    let (wbtc, _, _, vault) = setup();

    let deposit_amount: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit_amount);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares = vault.deposit(deposit_amount, USER1());

    vault.withdraw(shares + 1, USER1(), USER1());
    stop_cheat_caller_address(vault.contract_address);
}

#[test]
fn test_convert_to_shares_empty_vault() {
    let (_, _, _, vault) = setup();

    let assets: u256 = 100_000_000;
    let shares = vault.convert_to_shares(assets);
    assert!(shares == assets, "Empty vault should have 1:1 ratio");
}

#[test]
fn test_convert_to_assets_empty_vault() {
    let (_, _, _, vault) = setup();

    let shares: u256 = 100_000_000;
    let assets = vault.convert_to_assets(shares);
    assert!(assets == shares, "Empty vault should have 1:1 ratio");
}

// ============ MULTIPLE DEPOSITORS TESTS ============

#[test]
fn test_multiple_depositors_correct_shares() {
    let (wbtc, _, _, vault) = setup();

    // User1 deposits 100 WBTC
    let deposit1: u256 = 10_000_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit1);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares1 = vault.deposit(deposit1, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // User2 deposits 200 WBTC
    let deposit2: u256 = 20_000_000_000;
    mint_and_approve(wbtc, USER2(), vault.contract_address, deposit2);
    start_cheat_caller_address(vault.contract_address, USER2());
    let shares2 = vault.deposit(deposit2, USER2());
    stop_cheat_caller_address(vault.contract_address);

    // User2 should have 2x the shares
    assert!(shares2 == shares1 * 2, "Shares should be proportional");

    // Total shares should match
    assert!(vault.total_shares() == shares1 + shares2, "Total shares mismatch");

    // Verify ownership proportions
    let total_assets = vault.total_assets();
    let user1_assets = vault.convert_to_assets(shares1);
    let user2_assets = vault.convert_to_assets(shares2);

    assert!(user1_assets == total_assets / 3, "User1 should own 1/3");
    assert!(user2_assets == (total_assets * 2) / 3, "User2 should own 2/3");
}

#[test]
fn test_rebalance_with_multiple_depositors_preserves_value() {
    let (wbtc, _, _, vault) = setup();

    // User1 deposits
    let deposit1: u256 = 100_000_000;
    mint_and_approve(wbtc, USER1(), vault.contract_address, deposit1);
    start_cheat_caller_address(vault.contract_address, USER1());
    let shares1 = vault.deposit(deposit1, USER1());
    stop_cheat_caller_address(vault.contract_address);

    // User2 deposits
    let deposit2: u256 = 200_000_000;
    mint_and_approve(wbtc, USER2(), vault.contract_address, deposit2);
    start_cheat_caller_address(vault.contract_address, USER2());
    let shares2 = vault.deposit(deposit2, USER2());
    stop_cheat_caller_address(vault.contract_address);

    let total_before = vault.total_assets();
    let user1_value_before = vault.convert_to_assets(shares1);
    let user2_value_before = vault.convert_to_assets(shares2);

    // Change allocation and rebalance
    start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_allocation(2000, 8000);
    stop_cheat_caller_address(vault.contract_address);
    vault.rebalance();

    // Total assets should be preserved
    let total_after = vault.total_assets();
    assert!(total_after == total_before, "Total assets should be preserved after rebalance");

    // Individual values should be preserved
    let user1_value_after = vault.convert_to_assets(shares1);
    let user2_value_after = vault.convert_to_assets(shares2);
    assert!(user1_value_after == user1_value_before, "User1 value should be preserved");
    assert!(user2_value_after == user2_value_before, "User2 value should be preserved");
}
