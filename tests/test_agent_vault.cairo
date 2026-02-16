use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, cheat_caller_address, CheatSpan,
    cheat_block_timestamp,
};
use starknet::ContractAddress;
use btc_yield_vault::agent_vault::{IAgentVaultDispatcher, IAgentVaultDispatcherTrait};

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn AGENT() -> ContractAddress {
    'agent'.try_into().unwrap()
}

fn OTHER() -> ContractAddress {
    'other'.try_into().unwrap()
}

fn ZERO_ADDR() -> ContractAddress {
    starknet::contract_address_const::<0>()
}

fn deploy() -> IAgentVaultDispatcher {
    let contract = declare("AgentVault").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    // owner
    calldata.append(OWNER().into());
    // agent
    calldata.append(AGENT().into());
    // max_daily_spend: u256 (low, high)
    calldata.append(1000);
    calldata.append(0);
    // allowed_action_types: felt252 (swap=1 | bridge=2 | lend=4 | transfer=8 = 15)
    calldata.append(15);
    // max_single_tx: u256
    calldata.append(500);
    calldata.append(0);
    // risk_threshold: u8
    calldata.append(50);
    // is_active: bool
    calldata.append(1);
    // proof_registry: ContractAddress (zero = no registry)
    calldata.append(0);

    let (address, _) = contract.deploy(@calldata).unwrap();
    IAgentVaultDispatcher { contract_address: address }
}

fn deploy_with_registry(registry: ContractAddress) -> IAgentVaultDispatcher {
    let contract = declare("AgentVault").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    calldata.append(OWNER().into());
    calldata.append(AGENT().into());
    calldata.append(1000);
    calldata.append(0);
    calldata.append(15);
    calldata.append(500);
    calldata.append(0);
    calldata.append(50);
    calldata.append(1);
    calldata.append(registry.into());

    let (address, _) = contract.deploy(@calldata).unwrap();
    IAgentVaultDispatcher { contract_address: address }
}

#[test]
fn test_constructor_state() {
    let vault = deploy();
    let (agent, daily_spent, _, total_actions, constraints) = vault.get_agent_state();
    assert(agent == AGENT(), 'Wrong agent');
    assert(daily_spent == 0, 'Daily spent should be 0');
    assert(total_actions == 0, 'Total actions should be 0');
    assert(constraints.max_daily_spend == 1000, 'Wrong max daily');
    assert(constraints.risk_threshold == 50, 'Wrong risk threshold');
    assert(constraints.is_active, 'Should be active');
}

#[test]
fn test_propose_and_approve() {
    let vault = deploy();

    // Propose as agent
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    let action_id = vault.propose_action(1, 100, 30, 'proof1', 0);
    assert(action_id == 0, 'First action should be 0');

    // Check record
    let record = vault.get_action(0);
    assert(record.amount == 100, 'Wrong amount');
    assert(!record.approved, 'Should not be approved yet');

    // Approve
    let result = vault.approve_action(0);
    assert(result, 'Should approve');

    let record = vault.get_action(0);
    assert(record.approved, 'Should be approved');
}

#[test]
#[should_panic(expected: 'Only agent can propose')]
fn test_propose_non_agent_fails() {
    let vault = deploy();
    cheat_caller_address(vault.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 100, 30, 'proof1', 0);
}

#[test]
fn test_reject_high_risk() {
    let vault = deploy();
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 100, 80, 'proof1', 0); // risk 80 > threshold 50

    let result = vault.approve_action(0);
    assert(!result, 'Should reject high risk');
}

#[test]
fn test_reject_exceeds_single_tx() {
    let vault = deploy();
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 600, 30, 'proof1', 0); // 600 > max_single_tx 500

    let result = vault.approve_action(0);
    assert(!result, 'Should reject large tx');
}

#[test]
fn test_reject_exceeds_daily_limit() {
    let vault = deploy();

    // Propose and approve 800
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 400, 30, 'proof1', 0);
    vault.approve_action(0);

    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 400, 30, 'proof2', 0);
    vault.approve_action(1);

    // This one would push daily to 1100 > 1000
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 300, 30, 'proof3', 0);
    let result = vault.approve_action(2);
    assert(!result, 'Should reject daily exceeded');
}

#[test]
fn test_reject_disallowed_action_type() {
    let vault = deploy();
    // Action type 16 is not in bitmap 15
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(16, 100, 30, 'proof1', 0);

    let result = vault.approve_action(0);
    assert(!result, 'Should reject bad action type');
}

#[test]
fn test_reject_inactive_vault() {
    let vault = deploy();

    // Deactivate
    cheat_caller_address(vault.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    vault.update_constraints(1000, 15, 500, 50, false);

    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 100, 30, 'proof1', 0);

    let result = vault.approve_action(0);
    assert(!result, 'Should reject inactive');
}

#[test]
#[should_panic(expected: 'Only owner')]
fn test_update_constraints_non_owner() {
    let vault = deploy();
    cheat_caller_address(vault.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    vault.update_constraints(2000, 15, 500, 50, true);
}

#[test]
fn test_update_constraints() {
    let vault = deploy();
    cheat_caller_address(vault.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    vault.update_constraints(2000, 3, 1000, 80, true);

    let (_, _, _, _, constraints) = vault.get_agent_state();
    assert(constraints.max_daily_spend == 2000, 'Updated max daily');
    assert(constraints.max_single_tx == 1000, 'Updated max single');
    assert(constraints.risk_threshold == 80, 'Updated risk');
}

#[test]
fn test_daily_reset() {
    let vault = deploy();

    // Spend some
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 400, 30, 'proof1', 0);
    vault.approve_action(0);

    let (_, daily_spent, _, _, _) = vault.get_agent_state();
    assert(daily_spent == 400, 'Should be 400');

    // Advance time by 1 day
    cheat_block_timestamp(vault.contract_address, 86400 + 1, CheatSpan::Indefinite);
    vault.reset_daily_limit();

    let (_, daily_spent, _, _, _) = vault.get_agent_state();
    assert(daily_spent == 0, 'Should reset to 0');
}

#[test]
fn test_multiple_actions() {
    let vault = deploy();

    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(3));
    let id0 = vault.propose_action(1, 100, 10, 'p1', 0);
    let id1 = vault.propose_action(2, 200, 20, 'p2', 0);
    let id2 = vault.propose_action(4, 150, 40, 'p3', 0);

    assert(id0 == 0, 'id0');
    assert(id1 == 1, 'id1');
    assert(id2 == 2, 'id2');

    vault.approve_action(0);
    vault.approve_action(1);
    vault.approve_action(2);

    let (_, daily_spent, _, total, _) = vault.get_agent_state();
    assert(total == 3, 'Should be 3 actions');
    assert(daily_spent == 450, 'Should be 450 spent');
}

// ─── New ZK integration tests ────────────────────────────────────────────────

#[test]
fn test_set_portfolio_commit_by_owner() {
    let vault = deploy();
    cheat_caller_address(vault.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    vault.set_portfolio_commit(0x1234);
    assert(vault.get_portfolio_commit() == 0x1234, 'Wrong commit');
}

#[test]
fn test_set_portfolio_commit_by_agent() {
    let vault = deploy();
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.set_portfolio_commit(0xABCD);
    assert(vault.get_portfolio_commit() == 0xABCD, 'Wrong commit');
}

#[test]
#[should_panic(expected: 'Only owner or agent')]
fn test_set_portfolio_commit_by_other_fails() {
    let vault = deploy();
    cheat_caller_address(vault.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    vault.set_portfolio_commit(0x1234);
}

#[test]
fn test_propose_with_matching_portfolio_commit() {
    let vault = deploy();

    // Set commitment
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.set_portfolio_commit(0xDEAD);

    // Propose with matching snapshot hash
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    let action_id = vault.propose_action(1, 100, 30, 0, 0xDEAD);
    assert(action_id == 0, 'Should succeed');
}

#[test]
#[should_panic(expected: 'Portfolio mismatch')]
fn test_propose_with_wrong_portfolio_commit_fails() {
    let vault = deploy();

    // Set commitment
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.set_portfolio_commit(0xDEAD);

    // Propose with wrong snapshot hash
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 100, 30, 0, 0xBEEF);
}

#[test]
fn test_propose_with_zero_commit_skips_check() {
    let vault = deploy();
    // No commitment set (defaults to 0), any snapshot hash works
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    let action_id = vault.propose_action(1, 100, 30, 0, 0x999);
    assert(action_id == 0, 'Should succeed');
}

#[test]
fn test_set_proof_registry() {
    let vault = deploy();
    let registry_addr: ContractAddress = starknet::contract_address_const::<0x999>();

    cheat_caller_address(vault.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    vault.set_proof_registry(registry_addr);
    assert(vault.get_proof_registry() == registry_addr, 'Wrong registry');
}

#[test]
#[should_panic(expected: 'Only owner')]
fn test_set_proof_registry_non_owner_fails() {
    let vault = deploy();
    let registry_addr: ContractAddress = starknet::contract_address_const::<0x999>();
    cheat_caller_address(vault.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    vault.set_proof_registry(registry_addr);
}

#[test]
fn test_constructor_with_registry() {
    let registry_addr: ContractAddress = starknet::contract_address_const::<0x555>();
    let vault = deploy_with_registry(registry_addr);
    assert(vault.get_proof_registry() == registry_addr, 'Registry should be set');
}

#[test]
fn test_approve_skips_proof_check_with_zero_registry() {
    // With zero registry address, approve should work without proof verification
    let vault = deploy();
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 100, 30, 'some_proof', 0);
    let result = vault.approve_action(0);
    assert(result, 'Should approve without registry');
}

#[test]
fn test_approve_skips_proof_check_with_zero_proof_hash() {
    // With registry set but proof_hash=0, should skip verification
    let registry_addr: ContractAddress = starknet::contract_address_const::<0x555>();
    let vault = deploy_with_registry(registry_addr);
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.propose_action(1, 100, 30, 0, 0);
    let result = vault.approve_action(0);
    assert(result, 'Should approve with zero proof');
}

#[test]
fn test_portfolio_commit_update_flow() {
    let vault = deploy();

    // Agent sets initial commit
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    vault.set_portfolio_commit(0xAAA);
    assert(vault.get_portfolio_commit() == 0xAAA, 'First commit');

    // Owner updates commit
    cheat_caller_address(vault.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    vault.set_portfolio_commit(0xBBB);
    assert(vault.get_portfolio_commit() == 0xBBB, 'Updated commit');

    // Propose with new commit
    cheat_caller_address(vault.contract_address, AGENT(), CheatSpan::TargetCalls(1));
    let id = vault.propose_action(1, 50, 10, 0, 0xBBB);
    assert(id == 0, 'Should work');
}
