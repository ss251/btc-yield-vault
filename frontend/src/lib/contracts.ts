import { VAULT_CONTRACT_ADDRESS } from "./constants";

// Vault contract ABI (simplified - add full ABI from contract compilation)
export const VAULT_ABI = [
  {
    name: "deposit",
    type: "function",
    inputs: [{ name: "amount", type: "felt" }],
    outputs: [],
  },
  {
    name: "withdraw",
    type: "function",
    inputs: [{ name: "amount", type: "felt" }],
    outputs: [],
  },
  {
    name: "get_user_balance",
    type: "function",
    inputs: [{ name: "user", type: "felt" }],
    outputs: [{ name: "balance", type: "felt" }],
    stateMutability: "view",
  },
  {
    name: "get_total_tvl",
    type: "function",
    inputs: [],
    outputs: [{ name: "tvl", type: "felt" }],
    stateMutability: "view",
  },
  {
    name: "get_current_apy",
    type: "function",
    inputs: [],
    outputs: [{ name: "apy", type: "felt" }],
    stateMutability: "view",
  },
] as const;

export const getVaultContract = () => ({
  address: VAULT_CONTRACT_ADDRESS,
  abi: VAULT_ABI,
});
