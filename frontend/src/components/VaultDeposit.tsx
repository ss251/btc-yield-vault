"use client";

import { useState } from "react";
import { useAccount } from "@starknet-react/core";

export function VaultDeposit() {
  const { address, status } = useAccount();
  const [amount, setAmount] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const isConnected = status === "connected" && address;

  const handleDeposit = async () => {
    if (!amount || !isConnected) return;

    setIsLoading(true);
    try {
      // TODO: Implement actual deposit logic with starknet.js
      console.log("Depositing:", amount, "BTC");
      await new Promise((resolve) => setTimeout(resolve, 2000)); // Simulate transaction
      setAmount("");
    } catch (error) {
      console.error("Deposit failed:", error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-[#1A1A1A] border border-[#2A2A2A] rounded-2xl p-6">
      <h3 className="text-lg font-semibold text-white mb-4">Deposit BTC</h3>

      <div className="space-y-4">
        <div>
          <label className="block text-sm text-gray-400 mb-2">Amount</label>
          <div className="relative">
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              disabled={!isConnected}
              className="w-full bg-[#0D0D0D] border border-[#2A2A2A] rounded-xl px-4 py-4 text-white text-xl font-medium placeholder-gray-600 focus:outline-none focus:border-[#F7931A] transition-colors disabled:opacity-50"
            />
            <div className="absolute right-4 top-1/2 -translate-y-1/2 flex items-center gap-2">
              <span className="text-[#F7931A] font-semibold">BTC</span>
            </div>
          </div>
        </div>

        <button
          onClick={handleDeposit}
          disabled={!isConnected || !amount || isLoading}
          className="w-full py-4 bg-[#F7931A] rounded-xl font-semibold text-black hover:bg-[#E8850F] transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed hover:shadow-[0_0_30px_rgba(247,147,26,0.3)]"
        >
          {isLoading ? (
            <span className="flex items-center justify-center gap-2">
              <svg
                className="animate-spin h-5 w-5"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
              >
                <circle
                  className="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  strokeWidth="4"
                ></circle>
                <path
                  className="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                ></path>
              </svg>
              Processing...
            </span>
          ) : !isConnected ? (
            "Connect Wallet to Deposit"
          ) : (
            "Deposit"
          )}
        </button>

        <p className="text-xs text-gray-500 text-center">
          Your BTC will be deposited into the yield vault
        </p>
      </div>
    </div>
  );
}
