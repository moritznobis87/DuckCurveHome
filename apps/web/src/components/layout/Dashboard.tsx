"use client";

import { useEffect, useState } from "react";
import { useLiveStore, rowToPoint } from "@/lib/live/store";
import { startLiveClient } from "@/lib/live/sseClient";
import { startReloadPolicy } from "@/lib/live/reloadPolicy";
import { api } from "@/lib/api/client";
import { hhmm } from "@/lib/format";
import { Header } from "./Header";
import { EnergyFlow } from "@/components/energy-flow/EnergyFlow";
import { EnergyPlanCard } from "@/components/energy-plan/EnergyPlanCard";
import { BufferTank } from "@/components/buffer/BufferTank";
import { DayChart, type ChartLayout } from "@/components/charts/DayChart";
import { ControlsBar } from "@/components/controls/ControlsBar";

export function Dashboard() {
  const state = useLiveStore((s) => s.state);
  const plan = useLiveStore((s) => s.plan);
  const history = useLiveStore((s) => s.history);
  const historyRange = useLiveStore((s) => s.historyRange);
  const connection = useLiveStore((s) => s.connection);
  const lastFrameAt = useLiveStore((s) => s.lastFrameAt);
  const offset = useLiveStore((s) => s.serverOffsetMs);
  const setHistory = useLiveStore((s) => s.setHistory);
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [chartLayout, setChartLayout] = useState<ChartLayout>("side");

  // Chart-Anordnung: ?chart=stacked|side|overlay setzt sie und merkt sie sich pro Gerät
  useEffect(() => {
    const valid = (v: string | null): v is ChartLayout => v === "stacked" || v === "side" || v === "overlay";
    try {
      const q = new URLSearchParams(window.location.search).get("chart");
      if (valid(q)) {
        localStorage.setItem("dch.chartLayout", q);
        setChartLayout(q);
        return;
      }
      const saved = localStorage.getItem("dch.chartLayout");
      if (valid(saved)) setChartLayout(saved);
    } catch {
      /* Speicher nicht verfügbar – Standard behalten */
    }
  }, []);

  useEffect(() => {
    const stop = startLiveClient();
    const stopReload = startReloadPolicy(() => useLiveStore.getState().state?.system.version ?? null);
    const t = setInterval(() => setNowMs(Date.now() + useLiveStore.getState().serverOffsetMs), 1000);
    return () => {
      stop();
      stopReload();
      clearInterval(t);
    };
  }, []);

  const changeRange = async (r: "today" | "yesterday") => {
    const h = await api.history(r);
    setHistory(h.rows.map(rowToPoint), r);
  };

  const degraded = connection !== "live";
  return (
    <main className="dashboard-bg dash-main flex h-[100dvh] flex-col" style={{ paddingTop: "max(var(--dash-pad), env(safe-area-inset-top))" }}>
      <Header />
      {degraded ? (
        <div className="mono -mt-2 flex h-9 shrink-0 items-center justify-center rounded-[3px] border text-[12px] uppercase tracking-[.1em]" style={{ borderColor: "rgba(224,83,61,.4)", background: "rgba(224,83,61,.12)", color: "var(--alert)" }}>
          Verbindung unterbrochen{lastFrameAt ? ` · letzte Daten ${hhmm(new Date(lastFrameAt + offset))}` : ""} – Anzeige wird fortgesetzt, sobald das Backend erreichbar ist
        </div>
      ) : null}
      <div className="grid min-h-0 flex-1 gap-4" style={{ gridTemplateColumns: "repeat(12, minmax(0, 1fr))", gridTemplateRows: "minmax(0, 1fr)", opacity: degraded ? 0.6 : 1, transition: "opacity .4s" }}>
        <EnergyFlow snapshot={state?.snapshot ?? null} nowMs={nowMs} />
        <EnergyPlanCard state={state} plan={plan} />
        <BufferTank snapshot={state?.snapshot ?? null} buffer={state?.buffer ?? null} />
      </div>
      <div className="shrink-0" style={{ height: "clamp(270px, 35vh, 440px)", display: "flex", opacity: degraded ? 0.6 : 1 }}>
        <div className="flex min-h-0 w-full flex-col">
          <DayChart history={history} plan={plan} nowMs={nowMs} range={historyRange} onRange={(r) => void changeRange(r)} layout={chartLayout} />
        </div>
      </div>
      <ControlsBar state={state} />
    </main>
  );
}
