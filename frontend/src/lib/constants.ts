// Contract addresses on Starknet devnet
export const AGENT_VAULT_ADDRESS =
  process.env.NEXT_PUBLIC_VAULT_ADDRESS ||
  "0x00feed60bab3040d068f6d8976a2dc05b3e7b17bedaa88bc58d8382c4d85b3f2";

export const PROOF_REGISTRY_ADDRESS =
  process.env.NEXT_PUBLIC_REGISTRY_ADDRESS ||
  "0x03673bedfe85fd5f12b9fa5dcf06d84a05143cb7fb55a2367dee43215caed5b3";

export const STARKNET_RPC =
  process.env.NEXT_PUBLIC_STARKNET_RPC || "http://localhost:5050";

// Xverse API
export const XVERSE_API_BASE = "https://api.secretkeylabs.io";
export const XVERSE_API_KEY =
  process.env.NEXT_PUBLIC_XVERSE_API_KEY || "";

// UI
export const BITCOIN_ORANGE = "#F7931A";

// Demo BTC address for display when no wallet connected
export const DEMO_BTC_ADDRESS = "bc1qa5wkgaew2dkv56kc6hp24cc2nsilxntakv84v8";

// Action type bitmap constants (must match Cairo contract)
export const ACTION_TYPE_REBALANCE = 1;
export const ACTION_TYPE_CATALOG = 2;
export const ACTION_TYPE_SWAP = 3;

// Human-readable action types
export const ACTION_TYPES = [
  "Rebalance",
  "Catalog",
  "Swap",
  "Transfer",
  "DCA Buy",
] as const;
export type ActionType = (typeof ACTION_TYPES)[number];

// Map felt252 action_type from contract to display name
export const ACTION_TYPE_MAP: Record<number, ActionType> = {
  1: "Rebalance",
  2: "Catalog",
  3: "Swap",
  0: "Transfer", // fallback
};

// Status types
export type ActionStatus = "pending" | "approved" | "rejected";

export interface AgentAction {
  id: number;
  actionType: ActionType;
  amount: number; // in sats
  riskScore: number; // 0-100
  status: ActionStatus;
  proofHash: string;
  timestamp: Date;
  reason?: string;
}

export interface AgentConstraints {
  maxDailySpend: number; // sats
  maxSingleTx: number; // sats
  allowedActionTypes: number; // bitmap felt252
  riskThreshold: number; // 0-255 (u8)
  isActive: boolean;
}

export interface AgentState {
  agent: string;
  dailySpent: number;
  lastResetTimestamp: number;
  totalActions: number;
  constraints: AgentConstraints;
}

export interface DecisionProof {
  agent: string;
  inputHash: string;
  outputHash: string;
  strategyHash: string;
  timestamp: number;
  verified: boolean;
}

// Mock data for demo (used when devnet is not available)
export const MOCK_AGENT_STATE: AgentState = {
  agent: "0x06de...809a",
  dailySpent: 125000,
  lastResetTimestamp: Math.floor(Date.now() / 1000) - 3600,
  totalActions: 47,
  constraints: {
    maxDailySpend: 500000,
    allowedActionTypes: 7, // bitmap: rebalance|catalog|swap
    maxSingleTx: 200000,
    riskThreshold: 65,
    isActive: true,
  },
};

export const MOCK_ACTIONS: AgentAction[] = [
  {
    id: 47,
    actionType: "Rebalance",
    amount: 25000,
    riskScore: 12,
    status: "approved",
    proofHash: "0x7a3f...c2e1",
    timestamp: new Date(Date.now() - 1000 * 60 * 5),
    reason: "Within daily limit, low risk",
  },
  {
    id: 46,
    actionType: "Swap",
    amount: 150000,
    riskScore: 78,
    status: "rejected",
    proofHash: "0x9b2d...f4a8",
    timestamp: new Date(Date.now() - 1000 * 60 * 30),
    reason: "Risk score 78 exceeds threshold 65",
  },
  {
    id: 45,
    actionType: "Transfer",
    amount: 50000,
    riskScore: 22,
    status: "approved",
    proofHash: "0x1c4e...8b3d",
    timestamp: new Date(Date.now() - 1000 * 60 * 90),
    reason: "All constraints satisfied",
  },
  {
    id: 44,
    actionType: "Rebalance",
    amount: 25000,
    riskScore: 15,
    status: "approved",
    proofHash: "0x5f8a...d7c2",
    timestamp: new Date(Date.now() - 1000 * 60 * 180),
  },
  {
    id: 43,
    actionType: "Catalog",
    amount: 0,
    riskScore: 10,
    status: "approved",
    proofHash: "0x3e7b...a1f9",
    timestamp: new Date(Date.now() - 1000 * 60 * 240),
  },
  {
    id: 42,
    actionType: "Swap",
    amount: 75000,
    riskScore: 35,
    status: "approved",
    proofHash: "0x8d1c...e5b4",
    timestamp: new Date(Date.now() - 1000 * 60 * 360),
  },
  {
    id: 41,
    actionType: "Transfer",
    amount: 300000,
    riskScore: 82,
    status: "rejected",
    proofHash: "0x2a9f...c8d1",
    timestamp: new Date(Date.now() - 1000 * 60 * 480),
    reason: "Risk score exceeds threshold",
  },
  {
    id: 40,
    actionType: "Rebalance",
    amount: 25000,
    riskScore: 10,
    status: "approved",
    proofHash: "0x6b3e...f2a7",
    timestamp: new Date(Date.now() - 1000 * 60 * 600),
  },
];

export const MOCK_PROOFS: DecisionProof[] = [
  {
    agent: "0x06de...809a",
    inputHash: "0x1234...abcd",
    outputHash: "0x5678...ef01",
    strategyHash: "0x9abc...def0",
    timestamp: Math.floor(Date.now() / 1000) - 300,
    verified: true,
  },
  {
    agent: "0x06de...809a",
    inputHash: "0x2345...bcde",
    outputHash: "0x6789...f012",
    strategyHash: "0x9abc...def0",
    timestamp: Math.floor(Date.now() / 1000) - 1800,
    verified: true,
  },
];
