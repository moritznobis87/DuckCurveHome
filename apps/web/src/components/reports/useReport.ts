"use client";

import { useEffect, useState } from "react";
import { ApiError } from "@/lib/api/client";
import type { Period } from "@/lib/api/models";

const REFRESH_MS = 5 * 60_000;
export const ALL_PERIODS: Period[] = ["day", "week", "month", "year"];

function describe(e: unknown): string {
  if (e instanceof ApiError) return e.status === 401 || e.status === 403 ? "Nicht angemeldet - bitte Gerät koppeln." : e.message;
  return "Daten konnten nicht geladen werden.";
}

export { isoToday } from "./ReportShell";

/** Lädt einen Bericht für Zeitraum + Anker, aktualisiert alle 5 min, hält beim Wechsel den alten Stand bis neue Daten da sind. */
export function useReport<T>(loader: (period: Period, anchor: string) => Promise<T>, period: Period, anchor: string): { data: T | null; error: string | null; loading: boolean } {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    if (!anchor) return;
    let alive = true;
    const load = async () => {
      setLoading(true);
      try {
        const r = await loader(period, anchor);
        if (!alive) return;
        setData(r);
        setError(null);
      } catch (e) {
        if (alive) setError(describe(e));
      } finally {
        if (alive) setLoading(false);
      }
    };
    void load();
    const t = setInterval(() => void load(), REFRESH_MS);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, [loader, period, anchor]);
  return { data, error, loading };
}

/**
 * Dieselbe Kennzahl für Tag, Woche, Monat und Jahr **des Ankertags** - alle vier auf einmal.
 *
 * Der Anker kommt von außen und war vorher fest auf heute verdrahtet. Wer in der Navigation auf den
 * 3. Januar blätterte, sah oben die Zahlen dieses Tages und in der Übersicht daneben weiterhin die
 * laufende Woche und das laufende Jahr. Zwei Zeiträume in einer Ansicht, ohne dass es dastand.
 */
export function useMultiPeriod<T>(loader: (period: Period, anchor: string) => Promise<T>, anchor: string): Partial<Record<Period, T>> {
  const [out, setOut] = useState<Partial<Record<Period, T>>>({});
  useEffect(() => {
    if (!anchor) return;
    let alive = true;
    const load = async () => {
      const results = await Promise.allSettled(ALL_PERIODS.map((p) => loader(p, anchor)));
      if (!alive) return;
      const next: Partial<Record<Period, T>> = {};
      results.forEach((r, i) => {
        if (r.status === "fulfilled") next[ALL_PERIODS[i]!] = r.value;
      });
      setOut(next);
    };
    void load();
    const t = setInterval(() => void load(), REFRESH_MS);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, [loader, anchor]);
  return out;
}
