import { RpcProvider, Contract, Account, type Abi } from "starknet";
import {
  AGENT_VAULT_ADDRESS,
  PROOF_REGISTRY_ADDRESS,
  STARKNET_RPC,
} from "./constants";

// ─── ABIs from compiled Cairo contracts ───

export const AGENT_VAULT_ABI: Abi = [
  {
    type: "impl",
    name: "AgentVaultImpl",
    interface_name: "btc_yield_vault::agent_vault::IAgentVault",
  },
  {
    type: "struct",
    name: "core::integer::u256",
    members: [
      { name: "low", type: "core::integer::u128" },
      { name: "high", type: "core::integer::u128" },
    ],
  },
  {
    type: "enum",
    name: "core::bool",
    variants: [
      { name: "False", type: "()" },
      { name: "True", type: "()" },
    ],
  },
  {
    type: "struct",
    name: "btc_yield_vault::agent_vault::AgentVault::Constraints",
    members: [
      { name: "max_daily_spend", type: "core::integer::u256" },
      { name: "allowed_action_types", type: "core::felt252" },
      { name: "max_single_tx", type: "core::integer::u256" },
      { name: "risk_threshold", type: "core::integer::u8" },
      { name: "is_active", type: "core::bool" },
    ],
  },
  {
    type: "struct",
    name: "btc_yield_vault::agent_vault::AgentVault::ActionRecord",
    members: [
      { name: "action_type", type: "core::felt252" },
      { name: "amount", type: "core::integer::u256" },
      { name: "risk_score", type: "core::integer::u8" },
      { name: "proof_hash", type: "core::felt252" },
      { name: "timestamp", type: "core::integer::u64" },
      { name: "approved", type: "core::bool" },
    ],
  },
  {
    type: "interface",
    name: "btc_yield_vault::agent_vault::IAgentVault",
    items: [
      {
        type: "function",
        name: "get_agent_state",
        inputs: [],
        outputs: [
          {
            type: "(core::starknet::contract_address::ContractAddress, core::integer::u256, core::integer::u64, core::integer::u64, btc_yield_vault::agent_vault::AgentVault::Constraints)",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "get_action",
        inputs: [{ name: "action_id", type: "core::integer::u64" }],
        outputs: [
          {
            type: "btc_yield_vault::agent_vault::AgentVault::ActionRecord",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "update_constraints",
        inputs: [
          { name: "max_daily_spend", type: "core::integer::u256" },
          { name: "allowed_action_types", type: "core::felt252" },
          { name: "max_single_tx", type: "core::integer::u256" },
          { name: "risk_threshold", type: "core::integer::u8" },
          { name: "is_active", type: "core::bool" },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "propose_action",
        inputs: [
          { name: "action_type", type: "core::felt252" },
          { name: "amount", type: "core::integer::u256" },
          { name: "risk_score", type: "core::integer::u8" },
          { name: "proof_hash", type: "core::felt252" },
          { name: "portfolio_snapshot_hash", type: "core::felt252" },
        ],
        outputs: [{ type: "core::integer::u64" }],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "approve_action",
        inputs: [{ name: "action_id", type: "core::integer::u64" }],
        outputs: [{ type: "core::bool" }],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "reset_daily_limit",
        inputs: [],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "get_portfolio_commit",
        inputs: [],
        outputs: [{ type: "core::felt252" }],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "get_proof_registry",
        inputs: [],
        outputs: [
          {
            type: "core::starknet::contract_address::ContractAddress",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "set_portfolio_commit",
        inputs: [{ name: "state_hash", type: "core::felt252" }],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "set_proof_registry",
        inputs: [
          {
            name: "registry",
            type: "core::starknet::contract_address::ContractAddress",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
    ],
  },
];

export const PROOF_REGISTRY_ABI: Abi = [
  {
    type: "impl",
    name: "ProofRegistryImpl",
    interface_name: "btc_yield_vault::proof_registry::IProofRegistry",
  },
  {
    type: "struct",
    name: "btc_yield_vault::proof_registry::ProofRegistry::PortfolioInput",
    members: [
      { name: "balance_sats", type: "core::felt252" },
      { name: "num_utxos", type: "core::felt252" },
      { name: "num_ordinals", type: "core::felt252" },
      { name: "num_runes", type: "core::felt252" },
    ],
  },
  {
    type: "struct",
    name: "btc_yield_vault::proof_registry::ProofRegistry::StrategyParams",
    members: [
      { name: "rebalance_threshold", type: "core::felt252" },
      { name: "max_risk", type: "core::felt252" },
    ],
  },
  {
    type: "struct",
    name: "btc_yield_vault::proof_registry::ProofRegistry::ActionOutput",
    members: [
      { name: "action_type", type: "core::felt252" },
      { name: "amount", type: "core::felt252" },
      { name: "risk_score", type: "core::felt252" },
    ],
  },
  {
    type: "enum",
    name: "core::bool",
    variants: [
      { name: "False", type: "()" },
      { name: "True", type: "()" },
    ],
  },
  {
    type: "struct",
    name: "btc_yield_vault::proof_registry::ProofRegistry::DecisionProof",
    members: [
      {
        name: "agent",
        type: "core::starknet::contract_address::ContractAddress",
      },
      { name: "input_hash", type: "core::felt252" },
      { name: "output_hash", type: "core::felt252" },
      { name: "strategy_hash", type: "core::felt252" },
      { name: "timestamp", type: "core::integer::u64" },
      { name: "verified", type: "core::bool" },
    ],
  },
  {
    type: "interface",
    name: "btc_yield_vault::proof_registry::IProofRegistry",
    items: [
      {
        type: "function",
        name: "get_total_proofs",
        inputs: [],
        outputs: [{ type: "core::integer::u64" }],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "verify_proof",
        inputs: [{ name: "proof_id", type: "core::integer::u64" }],
        outputs: [
          {
            type: "btc_yield_vault::proof_registry::ProofRegistry::DecisionProof",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "get_proof_count_for_agent",
        inputs: [
          {
            name: "agent",
            type: "core::starknet::contract_address::ContractAddress",
          },
        ],
        outputs: [{ type: "core::integer::u64" }],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "get_proof_id_for_agent",
        inputs: [
          {
            name: "agent",
            type: "core::starknet::contract_address::ContractAddress",
          },
          { name: "index", type: "core::integer::u64" },
        ],
        outputs: [{ type: "core::integer::u64" }],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "compute_output_hash",
        inputs: [
          { name: "action_type", type: "core::felt252" },
          { name: "amount", type: "core::felt252" },
          { name: "risk_score", type: "core::felt252" },
        ],
        outputs: [{ type: "core::felt252" }],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "submit_proof",
        inputs: [
          {
            name: "portfolio",
            type: "btc_yield_vault::proof_registry::ProofRegistry::PortfolioInput",
          },
          {
            name: "strategy",
            type: "btc_yield_vault::proof_registry::ProofRegistry::StrategyParams",
          },
          {
            name: "proposed",
            type: "btc_yield_vault::proof_registry::ProofRegistry::ActionOutput",
          },
        ],
        outputs: [{ type: "core::integer::u64" }],
        state_mutability: "external",
      },
    ],
  },
];

// ─── Singletons ───

let provider: RpcProvider | null = null;
let vaultContract: Contract | null = null;
let registryContract: Contract | null = null;

export function getProvider(): RpcProvider {
  if (!provider) {
    provider = new RpcProvider({ nodeUrl: STARKNET_RPC });
  }
  return provider;
}

export function getAgentVaultContract(): Contract {
  if (!vaultContract) {
    const p = getProvider();
    vaultContract = new Contract({
      abi: AGENT_VAULT_ABI,
      address: AGENT_VAULT_ADDRESS,
      providerOrAccount: p,
    });
  }
  return vaultContract;
}

export function getProofRegistryContract(): Contract {
  if (!registryContract) {
    const p = getProvider();
    registryContract = new Contract({
      abi: PROOF_REGISTRY_ABI,
      address: PROOF_REGISTRY_ADDRESS,
      providerOrAccount: p,
    });
  }
  return registryContract;
}

/**
 * Get an Account instance for write operations.
 * For devnet, uses a pre-funded account. In production, would use wallet signer.
 */
export function getDevnetAccount(): Account {
  // Standard devnet pre-funded account #0
  const DEVNET_ACCOUNT_ADDRESS =
    "0x064b48806902a367c8598f4f95c305e8c1a1acba5f082d294a43793113115691";
  const DEVNET_PRIVATE_KEY =
    "0x71d7bb07b9a64f6f78ac4c816aff4da9";
  const p = getProvider();
  return new Account({
    provider: p,
    address: DEVNET_ACCOUNT_ADDRESS,
    signer: DEVNET_PRIVATE_KEY,
  });
}

// ─── Read helpers ───

export async function fetchAgentState() {
  try {
    const c = getAgentVaultContract();
    const result = await c.call("get_agent_state");
    return result;
  } catch {
    return null;
  }
}

export async function fetchAction(actionId: number) {
  try {
    const c = getAgentVaultContract();
    const result = await c.call("get_action", [actionId]);
    return result;
  } catch {
    return null;
  }
}

export async function fetchTotalProofs(): Promise<number | null> {
  try {
    const c = getProofRegistryContract();
    const result = await c.call("get_total_proofs");
    return Number(result);
  } catch {
    return null;
  }
}

export async function fetchProof(proofId: number) {
  try {
    const c = getProofRegistryContract();
    const result = await c.call("verify_proof", [proofId]);
    return result;
  } catch {
    return null;
  }
}

// ─── Write helpers ───

export async function updateConstraints(
  maxDailySpend: bigint,
  allowedActionTypes: bigint,
  maxSingleTx: bigint,
  riskThreshold: number,
  isActive: boolean
) {
  const account = getDevnetAccount();
  const c = getAgentVaultContract();
  c.connect(account);
  const tx = await c.invoke("update_constraints", [
    maxDailySpend,
    allowedActionTypes,
    maxSingleTx,
    riskThreshold,
    isActive ? 1 : 0,
  ]);
  await account.waitForTransaction(tx.transaction_hash);
  return tx;
}
