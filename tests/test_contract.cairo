use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use starknet::ContractAddress;
use btc_yield_vault::vault::{IBTCYieldVaultDispatcher, IBTCYieldVaultDispatcherTrait};

fn OWNER() -> ContractAddress {
    starknet::contract_address_const::<'owner'>()
}

fn ASSET() -> ContractAddress {
    starknet::contract_address_const::<'wbtc'>()
}

fn STRATEGY() -> ContractAddress {
    starknet::contract_address_const::<'endur_xwbtc'>()
}

fn deploy_vault() -> IBTCYieldVaultDispatcher {
    let contract = declare("BTCYieldVault").unwrap().contract_class();
    let mut calldata = array![];

    // Constructor args: asset, strategy, owner
    ASSET().serialize(ref calldata);
    STRATEGY().serialize(ref calldata);
    OWNER().serialize(ref calldata);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    IBTCYieldVaultDispatcher { contract_address }
}

#[test]
fn test_deployment() {
    let vault = deploy_vault();

    assert!(vault.asset() == ASSET(), "Wrong asset");
    assert!(vault.strategy() == STRATEGY(), "Wrong strategy");
    assert!(vault.total_shares() == 0, "Should start with 0 shares");
    assert!(!vault.is_paused(), "Should not be paused");
}

// Note: convert_to_shares/convert_to_assets tests require mock ERC20/ERC4626
// contracts deployed. Will add integration tests with mocks in next iteration.

#[test]
fn test_pause_unpause() {
    let vault = deploy_vault();

    // Only owner can pause
    snforge_std::start_cheat_caller_address(vault.contract_address, OWNER());
    vault.set_paused(true);
    assert!(vault.is_paused(), "Should be paused");

    vault.set_paused(false);
    assert!(!vault.is_paused(), "Should be unpaused");
    snforge_std::stop_cheat_caller_address(vault.contract_address);
}
