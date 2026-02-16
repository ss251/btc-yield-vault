"use client";

import { useState, useEffect, useCallback } from "react";
import { fetchBtcBalance, fetchOrdinals } from "@/lib/xverse-api";

interface BtcPortfolio {
  balance: number; // sats
  ordinals: { id: string; content_type: string; number: number }[];
  runes: unknown[];
  loading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useBtcPortfolio(address: string | null): BtcPortfolio {
  const [balance, setBalance] = useState(0);
  const [ordinals, setOrdinals] = useState<BtcPortfolio["ordinals"]>([]);
  const [runes] = useState<unknown[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    if (!address) {
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const [bal, ords] = await Promise.all([
        fetchBtcBalance(address),
        fetchOrdinals(address),
      ]);
      setBalance(bal);
      setOrdinals(ords);
      setError(null);
    } catch (err) {
      console.warn("useBtcPortfolio: fetch failed", err);
      setError(err instanceof Error ? err.message : "Failed to fetch");
    } finally {
      setLoading(false);
    }
  }, [address]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return { balance, ordinals, runes, loading, error, refetch: fetchData };
}
