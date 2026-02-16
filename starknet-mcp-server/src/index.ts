#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { RpcProvider, Account, Contract, cairo, CallData } from "starknet";

// --- Config ---
const STARKNET_RPC_URL = process.env.STARKNET_RPC_URL || "https://free-rpc.nethermind.io/sepolia-juno/v0_7";
const VAULT_CONTRACT_ADDRESS = process.env.VAULT_CONTRACT_ADDRESS || "";
const AGENT_PRIVATE_KEY = process.env.AGENT_PRIVATE_KEY || "";
const OWNER_PRIVATE_KEY = process.env.OWNER_PRIVATE_KEY || "";

// --- ABI (minimal, matching agent_vault.cairo) ---
const VAULT_ABI = [
  {
    type: "function",
    name: "propose_action",
    inputs: [
      { name: "action_type", type: "felt" },
      { name: "amount", type: "Uint256" },
      { name: "risk_score", type: "felt" },
      { name: "proof_hash", type: "felt" },
    ],
    outputs: [{ type: "felt" }],
    state_mutability: "external",
  },
  {
    type: "function",
    name: "approve_action",
    inputs: [{ name: "action_id", type: "felt" }],
    outputs: [{ type: "felt" }],
    state_mutability: "external",
  },
  {
    type: "function",
    name: "get_agent_state",
    inputs: [],
    outputs: [
      { name: "agent", type: "felt" },
      { name: "daily_spent", type: "Uint256" },
      { name: "last_reset_timestamp", type: "felt" },
      { name: "total_actions", type: "felt" },
      { name: "constraints", type: "(felt, felt, Uint256, felt, felt)" },
    ],
    state_mutability: "view",
  },
  {
    type: "function",
    name: "get_action",
    inputs: [{ name: "action_id", type: "felt" }],
    outputs: [
      { name: "action_type", type: "felt" },
      { name: "amount", type: "Uint256" },
      { name: "risk_score", type: "felt" },
      { name: "proof_hash", type: "felt" },
      { name: "timestamp", type: "felt" },
      { name: "approved", type: "felt" },
    ],
    state_mutability: "view",
  },
  {
    type: "function",
    name: "update_constraints",
    inputs: [
      { name: "max_daily_spend", type: "Uint256" },
      { name: "allowed_action_types", type: "felt" },
      { name: "max_single_tx", type: "Uint256" },
      { name: "risk_threshold", type: "felt" },
      { name: "is_active", type: "felt" },
    ],
    outputs: [],
    state_mutability: "external",
  },
] as const;

// --- Helpers ---
const provider = new RpcProvider({ nodeUrl: STARKNET_RPC_URL });

function getAgentAccount(): Account {
  if (!AGENT_PRIVATE_KEY) throw new Error("AGENT_PRIVATE_KEY not set");
  // Derive address from key or use env — for now we create account with the key
  // The agent address is stored in the contract, we just need the key to sign
  return new Account(provider, process.env.AGENT_ADDRESS || "", AGENT_PRIVATE_KEY);
}

function getOwnerAccount(): Account {
  if (!OWNER_PRIVATE_KEY) throw new Error("OWNER_PRIVATE_KEY not set");
  return new Account(provider, process.env.OWNER_ADDRESS || "", OWNER_PRIVATE_KEY);
}

function getContract(account?: Account): Contract {
  if (!VAULT_CONTRACT_ADDRESS) throw new Error("VAULT_CONTRACT_ADDRESS not set");
  const contract = new Contract(VAULT_ABI as any, VAULT_CONTRACT_ADDRESS, account || provider);
  return contract;
}

function jsonText(data: any) {
  return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
}

// --- MCP Server ---
const server = new McpServer({
  name: "starknet-vault",
  version: "1.0.0",
});

// 1. propose_action
server.tool(
  "propose_action",
  "Propose an action to the AgentVault contract on Starknet. Returns the action_id.",
  {
    action_type: z.string().describe("Action type as felt252 (hex or decimal string, e.g. '0x1' for transfer)"),
    amount: z.string().describe("Amount as uint256 string (in wei/smallest unit)"),
    risk_score: z.number().int().min(0).max(255).describe("Risk score 0-255"),
    proof_hash: z.string().describe("ZK proof hash as felt252 (hex or decimal string)"),
  },
  async ({ action_type, amount, risk_score, proof_hash }) => {
    const account = getAgentAccount();
    const contract = getContract(account);

    const tx = await contract.invoke("propose_action", [
      action_type,
      cairo.uint256(amount),
      risk_score,
      proof_hash,
    ]);

    await provider.waitForTransaction(tx.transaction_hash);

    return jsonText({
      status: "proposed",
      transaction_hash: tx.transaction_hash,
      message: "Action proposed successfully. Use get_agent_state to find the action_id (total_actions - 1).",
    });
  }
);

// 2. approve_action
server.tool(
  "approve_action",
  "Approve (validate constraints and execute) a proposed action. Returns whether approval succeeded.",
  {
    action_id: z.number().int().min(0).describe("Action ID to approve"),
  },
  async ({ action_id }) => {
    const account = getAgentAccount();
    const contract = getContract(account);

    const tx = await contract.invoke("approve_action", [action_id]);
    await provider.waitForTransaction(tx.transaction_hash);

    return jsonText({
      status: "approval_submitted",
      transaction_hash: tx.transaction_hash,
      action_id,
      message: "Approval transaction submitted. Check action status with get_action.",
    });
  }
);

// 3. get_agent_state
server.tool(
  "get_agent_state",
  "Read the current AgentVault state: agent address, daily spent, constraints, total actions.",
  {},
  async () => {
    const contract = getContract();

    const result = await contract.call("get_agent_state", []);

    // Result is a tuple: (agent, daily_spent, last_reset_timestamp, total_actions, constraints)
    const res = result as any;
    return jsonText({
      agent_address: res[0]?.toString() || res.agent?.toString(),
      daily_spent: res[1]?.toString() || res.daily_spent?.toString(),
      last_reset_timestamp: res[2]?.toString() || res.last_reset_timestamp?.toString(),
      total_actions: res[3]?.toString() || res.total_actions?.toString(),
      constraints: {
        max_daily_spend: res[4]?.[0]?.toString() || "unknown",
        allowed_action_types: res[4]?.[1]?.toString() || "unknown",
        max_single_tx: res[4]?.[2]?.toString() || "unknown",
        risk_threshold: res[4]?.[3]?.toString() || "unknown",
        is_active: res[4]?.[4]?.toString() || "unknown",
      },
    });
  }
);

// 4. get_action
server.tool(
  "get_action",
  "Read a specific action record by ID from the AgentVault.",
  {
    action_id: z.number().int().min(0).describe("Action ID to look up"),
  },
  async ({ action_id }) => {
    const contract = getContract();

    const result = await contract.call("get_action", [action_id]);
    const res = result as any;

    return jsonText({
      action_id,
      action_type: res[0]?.toString() || res.action_type?.toString(),
      amount: res[1]?.toString() || res.amount?.toString(),
      risk_score: res[2]?.toString() || res.risk_score?.toString(),
      proof_hash: res[3]?.toString() || res.proof_hash?.toString(),
      timestamp: res[4]?.toString() || res.timestamp?.toString(),
      approved: res[5]?.toString() || res.approved?.toString(),
    });
  }
);

// 5. update_constraints
server.tool(
  "update_constraints",
  "Update vault constraints (owner only). Controls spending limits, allowed actions, risk threshold.",
  {
    max_daily_spend: z.string().describe("Max daily spend as uint256 string"),
    allowed_action_types: z.string().describe("Bitmask of allowed action types as felt252"),
    max_single_tx: z.string().describe("Max single transaction amount as uint256 string"),
    risk_threshold: z.number().int().min(0).max(255).describe("Max allowed risk score (0-255)"),
    is_active: z.boolean().describe("Whether the vault is active"),
  },
  async ({ max_daily_spend, allowed_action_types, max_single_tx, risk_threshold, is_active }) => {
    const account = getOwnerAccount();
    const contract = getContract(account);

    const tx = await contract.invoke("update_constraints", [
      cairo.uint256(max_daily_spend),
      allowed_action_types,
      cairo.uint256(max_single_tx),
      risk_threshold,
      is_active ? 1 : 0,
    ]);

    await provider.waitForTransaction(tx.transaction_hash);

    return jsonText({
      status: "constraints_updated",
      transaction_hash: tx.transaction_hash,
    });
  }
);

// 6. get_vault_summary
server.tool(
  "get_vault_summary",
  "Get a comprehensive summary of the vault state including recent actions.",
  {
    recent_count: z.number().int().min(0).max(50).optional().default(5).describe("Number of recent actions to include"),
  },
  async ({ recent_count }) => {
    const contract = getContract();

    // Get state
    const stateResult = await contract.call("get_agent_state", []) as any;
    const totalActions = Number(stateResult[3]?.toString() || stateResult.total_actions?.toString() || "0");

    // Get recent actions
    const actions = [];
    const startIdx = Math.max(0, totalActions - recent_count);
    for (let i = startIdx; i < totalActions; i++) {
      try {
        const action = await contract.call("get_action", [i]) as any;
        actions.push({
          id: i,
          action_type: action[0]?.toString() || action.action_type?.toString(),
          amount: action[1]?.toString() || action.amount?.toString(),
          risk_score: action[2]?.toString() || action.risk_score?.toString(),
          proof_hash: action[3]?.toString() || action.proof_hash?.toString(),
          timestamp: action[4]?.toString() || action.timestamp?.toString(),
          approved: action[5]?.toString() || action.approved?.toString(),
        });
      } catch {
        // skip errors for individual actions
      }
    }

    return jsonText({
      vault_address: VAULT_CONTRACT_ADDRESS,
      agent_address: stateResult[0]?.toString() || stateResult.agent?.toString(),
      daily_spent: stateResult[1]?.toString() || stateResult.daily_spent?.toString(),
      last_reset: stateResult[2]?.toString() || stateResult.last_reset_timestamp?.toString(),
      total_actions: totalActions,
      constraints: {
        max_daily_spend: stateResult[4]?.[0]?.toString() || "unknown",
        allowed_action_types: stateResult[4]?.[1]?.toString() || "unknown",
        max_single_tx: stateResult[4]?.[2]?.toString() || "unknown",
        risk_threshold: stateResult[4]?.[3]?.toString() || "unknown",
        is_active: stateResult[4]?.[4]?.toString() || "unknown",
      },
      recent_actions: actions,
    });
  }
);

// --- Start ---
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Starknet Vault MCP server running on stdio");
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
