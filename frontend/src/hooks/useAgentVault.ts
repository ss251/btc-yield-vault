"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { fetchAgentState, fetchAction } from "@/lib/contracts";
import {
  MOCK_AGENT_STATE,
  MOCK_ACTIONS,
  ACTION_TYPE_MAP,
  type AgentState,
  type AgentAction,
  type ActionStatus,
} from "@/lib/constants";

const POLL_INTERVAL = 5000;

function toBigIntSafe(v: unknown): number {
  try {
    return Number(BigInt(String(v)));
  } catch {
    return 0;
  }
}

function toHex(v: unknown): string {
  try {
    const n = BigInt(String(v));
    return "0x" + n.toString(16);
  } catch {
    return "0x0";
  }
}

/**
 * Parse the tuple returned by get_agent_state:
 * (agent: ContractAddress, daily_spent: u256, last_reset: u64, total_actions: u64, constraints: Constraints)
 *
 * starknet.js v6+ returns this as an object or array depending on ABI parse.
 */
function parseAgentState(raw: unknown): AgentState | null {
  try {
    if (!raw || typeof raw !== "object") return null;

    // starknet.js can return as array-like or named object
    const r = raw as Record<string, unknown>;

    // Try named tuple access first, then positional
    const agent = String(r.agent ?? r[0] ?? "0x0");
    const dailySpent = toBigIntSafe(r.daily_spent ?? r[1]);
    const lastResetTimestamp = toBigIntSafe(r.last_reset_timestamp ?? r[2]);
    const totalActions = toBigIntSafe(r.total_actions ?? r[3]);

    // Constraints is a struct — could be nested object or positional
    const c = (r.constraints ?? r[4]) as Record<string, unknown> | undefined;
    if (!c) return null;

    const constraints = {
      maxDailySpend: toBigIntSafe(c.max_daily_spend ?? c[0]),
      allowedActionTypes: toBigIntSafe(c.allowed_action_types ?? c[1]),
      maxSingleTx: toBigIntSafe(c.max_single_tx ?? c[2]),
      riskThreshold: toBigIntSafe(c.risk_threshold ?? c[3]),
      isActive: Boolean(c.is_active ?? c[4]),
    };

    return {
      agent,
      dailySpent,
      lastResetTimestamp,
      totalActions,
      constraints,
    };
  } catch {
    return null;
  }
}

function parseAction(raw: unknown, id: number): AgentAction | null {
  try {
    if (!raw || typeof raw !== "object") return null;
    const r = raw as Record<string, unknown>;

    const actionTypeNum = toBigIntSafe(r.action_type ?? r[0]);
    const amount = toBigIntSafe(r.amount ?? r[1]);
    const riskScore = toBigIntSafe(r.risk_score ?? r[2]);
    const proofHash = toHex(r.proof_hash ?? r[3]);
    const timestamp = toBigIntSafe(r.timestamp ?? r[4]);
    const approved = Boolean(r.approved ?? r[5]);

    const status: ActionStatus = approved ? "approved" : "pending";

    return {
      id,
      actionType: ACTION_TYPE_MAP[actionTypeNum] || "Transfer",
      amount,
      riskScore,
      status,
      proofHash:
        proofHash.length > 10
          ? proofHash.slice(0, 6) + "..." + proofHash.slice(-4)
          : proofHash,
      timestamp: timestamp > 0 ? new Date(timestamp * 1000) : new Date(),
    };
  } catch {
    return null;
  }
}

export function useAgentVault() {
  const [agentState, setAgentState] = useState<AgentState>(MOCK_AGENT_STATE);
  const [actions, setActions] = useState<AgentAction[]>(MOCK_ACTIONS);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [usingMock, setUsingMock] = useState(false);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const fetchAll = useCallback(async () => {
    try {
      const rawState = await fetchAgentState();
      if (rawState) {
        const parsed = parseAgentState(rawState);
        if (parsed) {
          setAgentState(parsed);
          setUsingMock(false);

          // Fetch recent actions
          const total = parsed.totalActions;
          if (total > 0) {
            const start = Math.max(0, total - 20);
            const promises: Promise<AgentAction | null>[] = [];
            for (let i = total - 1; i >= start; i--) {
              promises.push(
                fetchAction(i).then((raw) => parseAction(raw, i))
              );
            }
            const results = await Promise.all(promises);
            const valid = results.filter(
              (a): a is AgentAction => a !== null
            );
            if (valid.length > 0) {
              setActions(valid);
            }
          } else {
            setActions([]);
          }
          setError(null);
          return;
        }
      }
      // Fallback to mock
      setUsingMock(true);
      setAgentState(MOCK_AGENT_STATE);
      setActions(MOCK_ACTIONS);
      setError(null);
    } catch (err) {
      console.warn("useAgentVault: falling back to mock data", err);
      setUsingMock(true);
      setAgentState(MOCK_AGENT_STATE);
      setActions(MOCK_ACTIONS);
      setError(err instanceof Error ? err.message : "Failed to fetch");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAll();
    intervalRef.current = setInterval(fetchAll, POLL_INTERVAL);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [fetchAll]);

  return { agentState, actions, loading, error, usingMock, refetch: fetchAll };
}
