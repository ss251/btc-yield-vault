"use client";

import { Clock, ArrowUpRight, ArrowDownRight, RotateCcw, ExternalLink } from "lucide-react";
import { type AgentAction, type ActionStatus } from "@/lib/constants";
import { useAgentVault } from "@/hooks/useAgentVault";
import { formatSats } from "@/lib/xverse-api";

const statusConfig: Record<ActionStatus, { color: string; bg: string; border: string }> = {
  pending: { color: "text-warning", bg: "bg-warning/10", border: "border-warning/20" },
  approved: { color: "text-success", bg: "bg-success/10", border: "border-success/20" },
  rejected: { color: "text-danger", bg: "bg-danger/10", border: "border-danger/20" },
};

export function ActionHistory() {
  const { actions, loading } = useAgentVault();

  return (
    <div className="bg-dark-card border border-dark-border rounded-2xl p-6 animate-fade-in">
      <div className="flex items-center justify-between mb-5">
        <h2 className="text-sm font-medium text-gray-400 uppercase tracking-wider">Action History</h2>
        <span className="text-xs text-gray-600">{actions.length} actions</span>
      </div>

      <div className="space-y-2">
        {actions.map((action, i) => (
          <ActionRow key={action.id} action={action} style={{ animationDelay: `${i * 60}ms` }} />
        ))}
      </div>
    </div>
  );
}

function ActionRow({ action, style }: { action: AgentAction; style?: React.CSSProperties }) {
  const sc = statusConfig[action.status];
  const timeAgo = getTimeAgo(action.timestamp);

  return (
    <div className="flex items-center gap-3 p-3 bg-dark-surface border border-dark-border rounded-xl hover:border-dark-border-hover transition-colors animate-slide-in" style={style}>
      {/* Icon */}
      <div className="w-8 h-8 rounded-lg bg-dark-card border border-dark-border flex items-center justify-center shrink-0">
        <ActionIcon type={action.actionType} />
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">{action.actionType}</span>
          <span className={`px-1.5 py-0.5 rounded text-[10px] font-medium ${sc.color} ${sc.bg} border ${sc.border}`}>
            {action.status}
          </span>
        </div>
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-xs text-gray-500">{formatSats(action.amount)}</span>
          <span className="text-gray-700">·</span>
          <span className="text-xs text-gray-500">Risk: {action.riskScore}</span>
          <span className="text-gray-700">·</span>
          <span className="text-xs text-gray-600">{timeAgo}</span>
        </div>
      </div>

      {/* Proof link */}
      <button className="p-1.5 text-gray-600 hover:text-btc transition-colors" title={action.proofHash}>
        <ExternalLink className="w-3.5 h-3.5" />
      </button>
    </div>
  );
}

function ActionIcon({ type }: { type: string }) {
  switch (type) {
    case "Transfer": return <ArrowUpRight className="w-4 h-4 text-btc" />;
    case "Swap": return <RotateCcw className="w-4 h-4 text-purple-400" />;
    case "DCA Buy": return <ArrowDownRight className="w-4 h-4 text-success" />;
    default: return <Clock className="w-4 h-4 text-gray-400" />;
  }
}

function getTimeAgo(date: Date): string {
  const mins = Math.floor((Date.now() - date.getTime()) / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}
