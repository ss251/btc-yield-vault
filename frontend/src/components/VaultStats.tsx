"use client";

import { useAccount } from "@starknet-react/core";
import { useEffect, useState } from "react";
import { MOCK_VAULT_DATA } from "@/lib/constants";

interface StatCardProps {
  label: string;
  value: string;
  suffix?: string;
  highlight?: boolean;
}

function StatCard({ label, value, suffix, highlight }: StatCardProps) {
  return (
    <div className="bg-[#1A1A1A] border border-[#2A2A2A] rounded-2xl p-6 hover:border-[#3A3A3A] transition-colors">
      <p className="text-gray-400 text-sm font-medium mb-2">{label}</p>
      <p
        className={`text-3xl font-bold ${highlight ? "text-[#F7931A]" : "text-white"}`}
      >
        {value}
        {suffix && <span className="text-lg ml-1 text-gray-400">{suffix}</span>}
      </p>
    </div>
  );
}

export function VaultStats() {
  const [mounted, setMounted] = useState(false);
  const { address, status } = useAccount();

  useEffect(() => {
    setMounted(true);
  }, []);

  const isConnected = mounted && status === "connected" && address;

  // TODO: Replace with actual contract reads
  const { tvl, apy, totalDepositors, userPosition, userYieldEarned } =
    MOCK_VAULT_DATA;

  return (
    <div className="space-y-8">
      {/* Global Stats */}
      <div>
        <h2 className="text-xl font-semibold text-white mb-4">Vault Overview</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatCard label="Total Value Locked" value={tvl} suffix="BTC" />
          <StatCard label="Current APY" value={apy} suffix="%" highlight />
          <StatCard
            label="Total Depositors"
            value={totalDepositors.toLocaleString()}
          />
        </div>
      </div>

      {/* User Stats */}
      {isConnected && (
        <div>
          <h2 className="text-xl font-semibold text-white mb-4">
            Your Position
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <StatCard label="Your Deposit" value={userPosition} suffix="BTC" />
            <StatCard
              label="Yield Earned"
              value={userYieldEarned}
              suffix="BTC"
              highlight
            />
          </div>
        </div>
      )}

      {!isConnected && (
        <div className="bg-[#1A1A1A] border border-[#2A2A2A] rounded-2xl p-8 text-center">
          <p className="text-gray-400">
            Connect your wallet to view your position
          </p>
        </div>
      )}
    </div>
  );
}
