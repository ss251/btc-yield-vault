"use client";

import { Activity, CheckCircle2, XCircle, Clock, Hash } from "lucide-react";
import { type ActionStatus } from "@/lib/constants";
import { useAgentVault } from "@/hooks/useAgentVault";
import { formatSats } from "@/lib/xverse-api";

const statusIcons: Record<ActionStatus, React.ReactNode> = {
  approved: <CheckCircle2 className="w-4 h-4 text-success" />,
  rejected: <XCircle className="w-4 h-4 text-danger" />,
  pending: <Clock className="w-4 h-4 text-warning" />,
};

export function ActivityFeed() {
  const { actions: MOCK_ACTIONS } = useAgentVault();

  return (
    <div className="bg-dark-card border border-dark-border rounded-2xl p-6 animate-fade-in">
      <div className="flex items-center gap-2 mb-5">
        <Activity className="w-4 h-4 text-btc" />
        <h2 className="text-sm font-medium text-gray-400 uppercase tracking-wider">Activity Feed</h2>
      </div>

      <div className="relative">
        {/* Timeline line */}
        <div className="absolute left-[15px] top-2 bottom-2 w-px bg-dark-border" />

        <div className="space-y-4">
          {MOCK_ACTIONS.map((action, i) => {
            const timeAgo = getTimeAgo(action.timestamp);
            return (
              <div key={action.id} className="relative flex gap-4 animate-slide-in" style={{ animationDelay: `${i * 60}ms` }}>
                {/* Timeline dot */}
                <div className="relative z-10 w-[31px] flex justify-center shrink-0">
                  <div className="mt-1">{statusIcons[action.status]}</div>
                </div>

                {/* Content */}
                <div className="flex-1 pb-4">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <p className="text-sm">
                        <span className="font-medium">{action.actionType}</span>
                        <span className="text-gray-500"> · </span>
                        <span className="text-gray-400">{formatSats(action.amount)}</span>
                      </p>
                      {action.reason && (
                        <p className="text-xs text-gray-500 mt-1">{action.reason}</p>
                      )}
                    </div>
                    <span className="text-[10px] text-gray-600 shrink-0 mt-0.5">{timeAgo}</span>
                  </div>
                  <div className="flex items-center gap-3 mt-2">
                    <span className="flex items-center gap-1 text-[10px] text-gray-600 font-mono">
                      <Hash className="w-3 h-3" />
                      {action.proofHash}
                    </span>
                    <RiskBadge score={action.riskScore} />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function RiskBadge({ score }: { score: number }) {
  const color = score < 30 ? "text-success bg-success/10" : score < 60 ? "text-warning bg-warning/10" : "text-danger bg-danger/10";
  return (
    <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded ${color}`}>
      Risk {score}
    </span>
  );
}

function getTimeAgo(date: Date): string {
  const mins = Math.floor((Date.now() - date.getTime()) / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}
