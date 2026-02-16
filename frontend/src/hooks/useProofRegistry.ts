"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { fetchTotalProofs, fetchProof } from "@/lib/contracts";
import { MOCK_PROOFS, type DecisionProof } from "@/lib/constants";

const POLL_INTERVAL = 8000;

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

function parseProof(raw: unknown): DecisionProof | null {
  try {
    if (!raw || typeof raw !== "object") return null;
    const r = raw as Record<string, unknown>;
    return {
      agent: String(r.agent ?? r[0] ?? "0x0"),
      inputHash: toHex(r.input_hash ?? r[1]),
      outputHash: toHex(r.output_hash ?? r[2]),
      strategyHash: toHex(r.strategy_hash ?? r[3]),
      timestamp: toBigIntSafe(r.timestamp ?? r[4]),
      verified: Boolean(r.verified ?? r[5]),
    };
  } catch {
    return null;
  }
}

export function useProofRegistry() {
  const [proofs, setProofs] = useState<DecisionProof[]>(MOCK_PROOFS);
  const [totalProofs, setTotalProofs] = useState(0);
  const [loading, setLoading] = useState(true);
  const [usingMock, setUsingMock] = useState(false);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const fetchAll = useCallback(async () => {
    try {
      const total = await fetchTotalProofs();
      if (total !== null && total > 0) {
        setTotalProofs(total);
        const start = Math.max(0, total - 10);
        const promises: Promise<DecisionProof | null>[] = [];
        for (let i = total - 1; i >= start; i--) {
          promises.push(fetchProof(i).then(parseProof));
        }
        const results = await Promise.all(promises);
        const valid = results.filter(
          (p): p is DecisionProof => p !== null
        );
        setProofs(valid.length > 0 ? valid : MOCK_PROOFS);
        setUsingMock(valid.length === 0);
      } else {
        setUsingMock(true);
        setProofs(MOCK_PROOFS);
      }
    } catch {
      setUsingMock(true);
      setProofs(MOCK_PROOFS);
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

  return { proofs, totalProofs, loading, usingMock, refetch: fetchAll };
}
