"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import type { Period } from "@/lib/api/models";

export const PERIOD_LABEL: Record<Period, string> = { day: "Tag", week: "Woche", month: "Monat", year: "Jahr" };
const PERIODS: Period[] = ["day", "week", "month", "year"];

export const de1 = (n: number | null | undefined, digits = 1): string => (n == null || Number.isNaN(n) ? "–" : n.toLocaleString("de-DE", { minimumFractionDigits: digits, maximumFractionDigits: digits }));
export const eur = (n: number | null | undefined): string => (n == null ? "–" : `${de1(n, 2)} €`);
export const pct = (frac: number | null | undefined): string => (frac == null ? "–" : `${Math.round(frac * 100)} %`);

function isoDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/** Heutiges Datum im Haus-Zeitraum (Europe/Berlin), unabhängig von der Zeitzone des Geräts. */
export function isoToday(): string {
  try {
    return new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Berlin", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
  } catch {
    return isoDate(new Date());
  }
}

function shift(anchor: string, period: Period, dir: -1 | 1): string {
  const d = new Date(`${anchor}T12:00:00`);
  if (period === "day") d.setDate(d.getDate() + dir);
  else if (period === "week") d.setDate(d.getDate() + 7 * dir);
  else if (period === "month") d.setMonth(d.getMonth() + dir);
  else d.setFullYear(d.getFullYear() + dir);
  return isoDate(d);
}

function isoWeek(d: Date): number {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  return Math.ceil(((t.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
}

export function anchorLabel(anchor: string, period: Period): string {
  const d = new Date(`${anchor}T12:00:00`);
  if (period === "day") return d.toLocaleDateString("de-DE", { weekday: "long", day: "2-digit", month: "2-digit", year: "numeric" });
  if (period === "week") {
    const monday = new Date(d);
    monday.setDate(d.getDate() - ((d.getDay() + 6) % 7));
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    const f = (x: Date) => x.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" });
    return `KW ${isoWeek(d)} · ${f(monday)} – ${f(sunday)}${sunday.getFullYear()}`;
  }
  if (period === "month") return d.toLocaleDateString("de-DE", { month: "long", year: "numeric" });
  return String(d.getFullYear());
}

/** Zeitraum-Zustand mit URL-Synchronisation (?period=&anchor=), ohne useSearchParams (statisches Prerender). */
export function usePeriod(): { period: Period; anchor: string; setPeriod: (p: Period) => void; move: (dir: -1 | 1) => void; today: () => void } {
  const [period, setPeriodState] = useState<Period>("day");
  // Leer bis zum ersten Client-Render: die Seite wird statisch vorgerendert, das Datum darf nicht vom Build stammen.
  const [anchor, setAnchor] = useState<string>("");
  useEffect(() => {
    let a: string | null = null;
    try {
      const q = new URLSearchParams(window.location.search);
      const p = q.get("period");
      a = q.get("anchor");
      if (p && PERIODS.includes(p as Period)) setPeriodState(p as Period);
    } catch {
      /* ignorieren */
    }
    setAnchor(a && /^\d{4}-\d{2}-\d{2}$/.test(a) ? a : isoToday());
  }, []);
  useEffect(() => {
    if (!anchor) return;
    try {
      const url = new URL(window.location.href);
      url.searchParams.set("period", period);
      url.searchParams.set("anchor", anchor);
      window.history.replaceState(null, "", url.toString());
    } catch {
      /* ignorieren */
    }
  }, [period, anchor]);
  return {
    period,
    anchor,
    setPeriod: setPeriodState,
    move: (dir) => setAnchor((a) => shift(a, period, dir)),
    today: () => setAnchor(isoToday()),
  };
}

export function ReportShell({ title, kicker, period, anchor, onPeriod, onMove, onToday, right, children }: { title: string; kicker: string; period: Period; anchor: string; onPeriod: (p: Period) => void; onMove: (dir: -1 | 1) => void; onToday: () => void; right?: React.ReactNode; children: React.ReactNode }) {
  const isToday = !anchor || anchor === isoToday();
  return (
    <main className="dashboard-bg report-main flex min-h-[100dvh] flex-col gap-4 p-5 text-text-1">
      <header className="report-header flex h-14 shrink-0 items-center justify-between rounded-[3px] border border-line-2 px-5" style={{ background: "var(--surface-glass)", backdropFilter: "blur(18px)" }}>
        <div className="flex min-w-0 items-center gap-5">
          <Link href="/" className="kicker whitespace-nowrap" style={{ fontSize: 12 }}>← Dashboard</Link>
          <div className="flex min-w-0 items-baseline gap-2.5">
            <span className="whitespace-nowrap text-[17px] font-semibold tracking-[-.02em]">{title}</span>
            <span className="kicker truncate" style={{ fontSize: 12 }}>{kicker}</span>
          </div>
        </div>
        <div className="report-header-right flex shrink-0 items-center gap-4">
          {right}
          <div className="report-nav flex items-center gap-1 rounded-[3px] border border-line-2 p-1">
            <button onClick={() => onMove(-1)} aria-label="Zurück" className="mono px-2.5 py-1 text-[13px] text-text-2 hover:text-text-1">‹</button>
            <span className="report-anchor mono min-w-[190px] text-center text-[12px] text-text-1">{anchor ? anchorLabel(anchor, period) : "…"}</span>
            <button onClick={() => onMove(1)} aria-label="Weiter" className="mono px-2.5 py-1 text-[13px] text-text-2 hover:text-text-1">›</button>
            {!isToday ? <button onClick={onToday} className="mono px-2 py-1 text-[11px] uppercase tracking-[.08em] text-amber">heute</button> : null}
          </div>
          <div className="report-periods flex gap-1 rounded-[3px] border border-line-2 p-1" role="tablist" aria-label="Zeitraum">
            {PERIODS.map((p) => (
              <button key={p} onClick={() => onPeriod(p)} className="px-3 py-1.5 text-[12px] font-medium" style={{ background: period === p ? "var(--amber)" : "transparent", color: period === p ? "var(--petrol)" : "var(--text-2)", borderRadius: 2 }}>
                {PERIOD_LABEL[p]}
              </button>
            ))}
          </div>
        </div>
      </header>
      {children}
    </main>
  );
}

export function Note({ children }: { children: React.ReactNode }) {
  return <p className="m-0 text-[12px] leading-[1.55] text-text-3">{children}</p>;
}

export function ErrorBanner({ message }: { message: string }) {
  return (
    <div className="mono rounded-[3px] border px-4 py-3 text-[12px] uppercase tracking-[.1em]" style={{ borderColor: "rgba(224,83,61,.4)", background: "rgba(224,83,61,.12)", color: "var(--alert)" }}>
      {message}
    </div>
  );
}

/** Fußnote zur Datenbasis: Abdeckung des Zeitraums und Beginn der Aufzeichnung. */
export function CoverageNote({ meta, extra }: { meta: { coverage: number | null; data_since: string | null; estimated_note_de: string } | undefined; extra?: string }) {
  if (!meta) return null;
  const since = meta.data_since ? new Date(meta.data_since).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "numeric" }) : null;
  const cov = meta.coverage != null ? `Datenabdeckung ${Math.round(meta.coverage * 100)} %` : "noch keine Messdaten im Zeitraum";
  return (
    <Note>
      {cov}
      {since ? ` · Aufzeichnung seit ${since}` : ""}
      {" · "}
      {meta.estimated_note_de}
      {extra ? ` ${extra}` : ""}
    </Note>
  );
}

export function KpiGrid({ children, cols }: { children: React.ReactNode; cols: number }) {
  return (
    <div className="kpi-grid" style={{ "--cols": cols } as React.CSSProperties}>
      {children}
    </div>
  );
}
