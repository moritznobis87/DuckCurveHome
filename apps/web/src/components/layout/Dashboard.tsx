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
import { DayChart, type ChartLayout, type ChartRange } from "@/components/charts/DayChart";
import { ControlsBar } from "@/components/controls/ControlsBar";
import { useIsMobile } from "@/lib/useIsMobile";

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
  const isMobile = useIsMobile();

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

  const changeRange = async (r: ChartRange) => {
    if (r === "tomorrow") {
      setHistory([], r); // morgen gibt es nur Prognose (PV) und Preise aus dem Plan
      return;
    }
    const h = await api.history(r);
    setHistory(h.rows.map(rowToPoint), r);
  };

  const degraded = connection !== "live";
  return (
    <main className="dashboard-bg dash-main flex flex-col" style={{ paddingTop: "max(var(--dash-pad), env(safe-area-inset-top))", paddingBottom: "max(var(--dash-pad), env(safe-area-inset-bottom))" }}>
      <Header />
      {degraded ? (
        <div className="mono -mt-2 flex h-9 shrink-0 items-center justify-center rounded-[3px] border text-[12px] uppercase tracking-[.1em]" style={{ borderColor: "rgba(224,83,61,.4)", background: "rgba(224,83,61,.12)", color: "var(--alert)" }}>
          Verbindung unterbrochen{lastFrameAt ? ` · letzte Daten ${hhmm(new Date(lastFrameAt + offset))}` : ""} – Anzeige wird fortgesetzt, sobald das Backend erreichbar ist
        </div>
      ) : null}
      <div className="dash-top" style={{ opacity: degraded ? 0.6 : 1, transition: "opacity .4s" }}>
        <EnergyFlow snapshot={state?.snapshot ?? null} nowMs={nowMs} />
        <EnergyPlanCard state={state} plan={plan} />
        <BufferTank snapshot={state?.snapshot ?? null} buffer={state?.buffer ?? null} />
      </div>
      <div className="dash-chart" style={{ opacity: degraded ? 0.6 : 1 }}>
        <div className="flex min-h-0 w-full flex-col">
          <DayChart history={history} plan={plan} nowMs={nowMs} range={historyRange} onRange={(r) => void changeRange(r)} layout={isMobile ? "stacked" : chartLayout} />
        </div>
      </div>
      <ControlsBar state={state} />
    </main>
  );
}
