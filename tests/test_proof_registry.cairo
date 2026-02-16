use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};
use starknet::ContractAddress;
use btc_yield_vault::proof_registry::{
    IProofRegistryDispatcher, IProofRegistryDispatcherTrait, ProofRegistry,
};

fn AGENT() -> ContractAddress {
    starknet::contract_address_const::<0x123>()
}

fn deploy() -> IProofRegistryDispatcher {
    let contract = declare("ProofRegistry").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![AGENT().into()]).unwrap();
    IProofRegistryDispatcher { contract_address: address }
}

fn make_portfolio(balance: felt252, utxos: felt252, ordinals: felt252, runes: felt252) -> ProofRegistry::PortfolioInput {
    ProofRegistry::PortfolioInput {
        balance_sats: balance, num_utxos: utxos, num_ordinals: ordinals, num_runes: runes,
    }
}

fn make_strategy(threshold: felt252, max_risk: felt252) -> ProofRegistry::StrategyParams {
    ProofRegistry::StrategyParams { rebalance_threshold: threshold, max_risk: max_risk }
}

#[test]
fn test_submit_rebalance_proof() {
    let registry = deploy();
    let agent = AGENT();
    start_cheat_caller_address(registry.contract_address, agent);

    // balance=50_000_000 > threshold=10_000 → REBALANCE
    // amount = min(50_000_000/10, 5000) = 5000
    // risk = max((5000*100/50_000_000)+20, 30) = max(20, 30) = 30
    let portfolio = make_portfolio(50_000_000, 3, 2, 1);
    let strategy = make_strategy(10_000, 80);
    let proposed = ProofRegistry::ActionOutput { action_type: 1, amount: 5000, risk_score: 30 };

    let proof_id = registry.submit_proof(portfolio, strategy, proposed);
    assert(proof_id == 0, 'Wrong proof id');

    let proof = registry.verify_proof(0);
    assert(proof.verified, 'Should be verified');
    assert(proof.agent == agent, 'Wrong agent');
    assert(registry.get_total_proofs() == 1, 'Wrong total');
    assert(registry.get_proof_count_for_agent(agent) == 1, 'Wrong agent count');
}

#[test]
fn test_submit_catalog_proof() {
    let registry = deploy();
    start_cheat_caller_address(registry.contract_address, AGENT());

    // balance=5000 <= threshold=10_000, ordinals=3 > 0 → CATALOG
    let portfolio = make_portfolio(5000, 1, 3, 0);
    let strategy = make_strategy(10_000, 80);
    let proposed = ProofRegistry::ActionOutput { action_type: 2, amount: 0, risk_score: 10 };

    let proof_id = registry.submit_proof(portfolio, strategy, proposed);
    assert(proof_id == 0, 'Wrong proof id');
}

#[test]
fn test_submit_swap_proof() {
    let registry = deploy();
    start_cheat_caller_address(registry.contract_address, AGENT());

    // balance=5000 <= threshold=10_000, ordinals=0, runes=2 > 0 → SWAP
    let portfolio = make_portfolio(5000, 1, 0, 2);
    let strategy = make_strategy(10_000, 80);
    let proposed = ProofRegistry::ActionOutput { action_type: 3, amount: 1000, risk_score: 40 };

    let proof_id = registry.submit_proof(portfolio, strategy, proposed);
    assert(proof_id == 0, 'Wrong proof id');
}

#[test]
fn test_submit_default_proof() {
    let registry = deploy();
    start_cheat_caller_address(registry.contract_address, AGENT());

    // balance=5000 <= threshold=10_000, ordinals=0, runes=0 → default rebalance
    let portfolio = make_portfolio(5000, 1, 0, 0);
    let strategy = make_strategy(10_000, 80);
    let proposed = ProofRegistry::ActionOutput { action_type: 1, amount: 100, risk_score: 5 };

    let proof_id = registry.submit_proof(portfolio, strategy, proposed);
    assert(proof_id == 0, 'Wrong proof id');
}

#[test]
#[should_panic(expected: 'Wrong action type')]
fn test_reject_wrong_action() {
    let registry = deploy();
    start_cheat_caller_address(registry.contract_address, AGENT());

    let portfolio = make_portfolio(50_000_000, 3, 2, 1);
    let strategy = make_strategy(10_000, 80);
    // Should be REBALANCE (1), but proposing CATALOG (2)
    let proposed = ProofRegistry::ActionOutput { action_type: 2, amount: 5000, risk_score: 30 };

    registry.submit_proof(portfolio, strategy, proposed);
}

#[test]
#[should_panic(expected: 'Wrong amount')]
fn test_reject_wrong_amount() {
    let registry = deploy();
    start_cheat_caller_address(registry.contract_address, AGENT());

    let portfolio = make_portfolio(50_000_000, 3, 2, 1);
    let strategy = make_strategy(10_000, 80);
    let proposed = ProofRegistry::ActionOutput { action_type: 1, amount: 9999, risk_score: 30 };

    registry.submit_proof(portfolio, strategy, proposed);
}

#[test]
fn test_multiple_proofs_indexing() {
    let registry = deploy();
    let agent = AGENT();
    start_cheat_caller_address(registry.contract_address, agent);

    let portfolio = make_portfolio(50_000_000, 3, 2, 1);
    let strategy = make_strategy(10_000, 80);
    let proposed = ProofRegistry::ActionOutput { action_type: 1, amount: 5000, risk_score: 30 };

    registry.submit_proof(portfolio, strategy, proposed);
    registry.submit_proof(portfolio, strategy, proposed);

    assert(registry.get_total_proofs() == 2, 'Wrong total');
    assert(registry.get_proof_count_for_agent(agent) == 2, 'Wrong count');
    assert(registry.get_proof_id_for_agent(agent, 0) == 0, 'Wrong id 0');
    assert(registry.get_proof_id_for_agent(agent, 1) == 1, 'Wrong id 1');
}

#[test]
fn test_compute_output_hash() {
    let registry = deploy();
    let h1 = registry.compute_output_hash(1, 5000, 30);
    let h2 = registry.compute_output_hash(1, 5000, 30);
    assert(h1 == h2, 'Hashes should match');

    let h3 = registry.compute_output_hash(2, 5000, 30);
    assert(h1 != h3, 'Different inputs diff hash');
}
