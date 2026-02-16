"use client";

import { Shield, Zap, Database } from "lucide-react";
import { useAgentVault } from "@/hooks/useAgentVault";
import { useProofRegistry } from "@/hooks/useProofRegistry";
import { formatSats } from "@/lib/xverse-api";

export function AgentStatus() {
  const { agentState: state, actions, usingMock } = useAgentVault();
  const { totalProofs, usingMock: proofsMock } = useProofRegistry();

  const approvedCount = actions.filter((a) => a.status === "approved").length;
  const rejectedCount = actions.filter((a) => a.status === "rejected").length;
  const spendPercent =
    state.constraints.maxDailySpend > 0
      ? (state.dailySpent / state.constraints.maxDailySpend) * 100
      : 0;

  return (
    <div className="bg-dark-card border border-dark-border rounded-2xl p-6 animate-fade-in">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-sm font-medium text-gray-400 uppercase tracking-wider">
          Agent Status
          {usingMock && (
            <span className="ml-2 text-[10px] text-warning bg-warning/10 px-1.5 py-0.5 rounded">
              Demo
            </span>
          )}
        </h2>
        <div
          className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${
            state.constraints.isActive
              ? "bg-success/10 text-success border border-success/20"
              : "bg-danger/10 text-danger border border-danger/20"
          }`}
        >
          <div
            className={`w-1.5 h-1.5 rounded-full ${
              state.constraints.isActive
                ? "bg-success animate-pulse"
                : "bg-danger"
            }`}
          />
          {state.constraints.isActive ? "Active" : "Paused"}
        </div>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-4 gap-3 mb-5">
        <div className="text-center">
          <p className="text-2xl font-bold text-btc">{state.totalActions}</p>
          <p className="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">
            Total
          </p>
        </div>
        <div className="text-center">
          <p className="text-2xl font-bold text-success">{approvedCount}</p>
          <p className="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">
            Approved
          </p>
        </div>
        <div className="text-center">
          <p className="text-2xl font-bold text-danger">{rejectedCount}</p>
          <p className="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">
            Rejected
          </p>
        </div>
        <div className="text-center">
          <p className="text-2xl font-bold text-purple-400">
            {proofsMock ? "—" : totalProofs}
          </p>
          <p className="text-[10px] text-gray-500 uppercase tracking-wider mt-0.5">
            Proofs
          </p>
        </div>
      </div>

      {/* Daily spend progress */}
      <div className="mb-4">
        <div className="flex justify-between text-xs mb-1.5">
          <span className="text-gray-400">Daily Spend</span>
          <span className="text-gray-500">
            {formatSats(state.dailySpent)} /{" "}
            {formatSats(state.constraints.maxDailySpend)}
          </span>
        </div>
        <div className="h-1.5 bg-dark-surface rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-btc to-btc-hover rounded-full transition-all duration-500"
            style={{ width: `${Math.min(spendPercent, 100)}%` }}
          />
        </div>
      </div>

      {/* Constraints */}
      <div className="space-y-2">
        <ConstraintRow
          icon={<Shield className="w-3.5 h-3.5" />}
          label="Risk Threshold"
          value={`${state.constraints.riskThreshold}/255`}
        />
        <ConstraintRow
          icon={<Zap className="w-3.5 h-3.5" />}
          label="Max Single Tx"
          value={formatSats(state.constraints.maxSingleTx)}
        />
        <ConstraintRow
          icon={<Database className="w-3.5 h-3.5" />}
          label="Action Bitmap"
          value={`0b${state.constraints.allowedActionTypes.toString(2).padStart(3, "0")}`}
        />
      </div>
    </div>
  );
}

function ConstraintRow({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center justify-between py-2 px-3 bg-dark-surface border border-dark-border rounded-lg">
      <div className="flex items-center gap-2 text-gray-400">
        {icon}
        <span className="text-xs">{label}</span>
      </div>
      <span className="text-xs font-medium text-gray-300">{value}</span>
    </div>
  );
}
