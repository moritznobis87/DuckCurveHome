"use client";

import { useEffect, useRef, useState } from "react";
import { useLiveStore, rowToPoint } from "@/lib/live/store";
import { startLiveClient } from "@/lib/live/sseClient";
import { startReloadPolicy } from "@/lib/live/reloadPolicy";
import { api } from "@/lib/api/client";
import { hhmm } from "@/lib/format";
import { Header } from "./Header";
import { EnergyFlow } from "@/components/energy-flow/EnergyFlow";
import { EnergyPlanCard } from "@/components/energy-plan/EnergyPlanCard";
import { BufferTank } from "@/components/buffer/BufferTank";
import { DayChart, isoDay, type ChartLayout } from "@/components/charts/DayChart";
import { istTagIso } from "@/lib/day";
import { ControlsBar } from "@/components/controls/ControlsBar";
import { useRole } from "@/lib/live/useRole";
import { useIsMobile } from "@/lib/useIsMobile";

/**
 * Kam dieses Dokument aus einem Neuladen?
 *
 * Der Unterschied entscheidet, wie ernst ein `?tag=` in der Adresse zu nehmen ist. Ein geteilter
 * oder gemerkter Link ist ein Wunsch; dieselbe Adresse nach einem selbst ausgeloesten Neuladen ist
 * nur ein Rest, den `replaceState` hinterlassen hat.
 */
function ausNeuladen(): boolean {
  try {
    const nav = performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming | undefined;
    return nav?.type === "reload";
  } catch {
    return false;
  }
}

export function Dashboard() {
  const role = useRole();
  const state = useLiveStore((s) => s.state);
  const plan = useLiveStore((s) => s.plan);
  const history = useLiveStore((s) => s.history);
  const historyDay = useLiveStore((s) => s.historyDay);
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
      /* Speicher nicht verfügbar - Standard behalten */
    }
  }, []);

  /**
   * Startwert des Tages: aus der Adresse, sonst der heutige Tag **des Servers**.
   *
   * Erst nach dem ersten Live-Rahmen, und das ist kein Detail: bis dahin ist der Zeitversatz zum
   * Server unbekannt, und im Demo-Modus läuft die Uhr im Zeitraffer. Der Tag des Browsers war dort
   * ein anderer als der des Servers, und die Ansicht lud einen Tag, für den es keine Messwerte gab.
   */
  useEffect(() => {
    if (lastFrameAt === null) return;
    let iso: string | null = null;
    try {
      const q = new URLSearchParams(window.location.search).get("tag");
      if (q && /^\d{4}-\d{2}-\d{2}$/.test(q)) iso = q;
    } catch {
      /* ignorieren */
    }
    // Ein Tag in der Adresse gilt auch dann, wenn schon einer geladen ist: aus einer Unterseite
    // führt „← Dashboard" mit `?tag=` zurück, und das ist eine Navigation innerhalb der Anwendung.
    // Der Zustandsspeicher überlebt sie, die Bedingung „nur beim ersten Mal" verwarf den Tag daher.
    //
    // **Nach einem Neuladen gilt er nicht.** `changeDay` schreibt den Tag in die Adresse, damit die
    // Ansicht teilbar ist. Lädt die Seite danach neu - und das tut sie von selbst, sobald eine neue
    // Fassung ausgerollt ist -, stand dort immer noch der Tag von vorgestern, und die Wandanzeige
    // blieb daran hängen, bis jemand hinging. Ein geteilter Link ist ein Wunsch, dieser Rest nicht.
    const heute = isoDay(useLiveStore.getState().nowMs());
    if (iso && iso !== heute && ausNeuladen()) iso = null;
    if (iso) {
      if (iso !== historyDay) void changeDay(iso);
      return;
    }
    // Nicht „ist schon einer gesetzt", sondern „ist der gesetzte brauchbar". Steht dort etwas, das
    // kein Kalendertag ist, blieb die Ansicht sonst fuer immer daran haengen: die Bedingung sah
    // einen Wert und war zufrieden, und die Wandanzeige zeigte bis zum naechsten Mitternacht nichts.
    if (!istTagIso(historyDay)) void changeDay(heute);
  }, [historyDay, lastFrameAt]);

  /**
   * Mitternacht: dem neuen Tag folgen, aber nur, wer auf dem laufenden Tag stand.
   *
   * Vorher wechselte die Ansicht gar nicht. Um 0:01 zeigte sie weiter gestern, und weil der
   * Zustandsspeicher Live-Werte nur an den laufenden Tag anhängt, hörte die Kurve dort schlicht
   * auf - eine Anzeige, die aussieht, als sei nichts mehr passiert.
   *
   * Wer gerade einen vergangenen Tag liest, wird nicht weggezogen. Wer auf „Morgen" stand, bekommt
   * den Tag neu geladen: er ist jetzt der laufende und hat Messwerte, die es vorhin nicht gab.
   */
  const gesehenerTag = useRef<string>("");
  useEffect(() => {
    if (lastFrameAt === null) return;
    const heute = isoDay(useLiveStore.getState().nowMs());
    const vorher = gesehenerTag.current;
    gesehenerTag.current = heute;
    if (!vorher || vorher === heute) return;
    if (historyDay === vorher || historyDay === heute) void changeDay(heute);
  }, [nowMs, historyDay, lastFrameAt]);

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

  /**
   * Den angezeigten Kalendertag wechseln und die Messwerte dazu laden.
   *
   * Der Tag steht in der Adresse (`?tag=`), damit die Ansicht teilbar ist und ein Neuladen nicht
   * zurück auf heute springt. Für den laufenden Tag wird der Schnellweg `range=today` genommen, weil
   * daran anschließend die Live-Werte angehängt werden; jeder andere Tag kommt als Zeitraum. Ein
   * künftiger Tag hat keine Messwerte, dort bleiben nur Prognose und Preise aus dem Plan.
   */
  const changeDay = async (iso: string) => {
    const now = Date.now() + useLiveStore.getState().serverOffsetMs;
    try {
      const url = new URL(window.location.href);
      // Der laufende Tag steht nicht in der Adresse. Er ist die Vorgabe, und was Vorgabe ist, muss
      // man nicht aufschreiben; aufgeschrieben wäre er morgen falsch.
      if (iso === isoDay(now)) url.searchParams.delete("tag");
      else url.searchParams.set("tag", iso);
      window.history.replaceState(null, "", url.toString());
    } catch {
      /* ignorieren */
    }
    if (iso > isoDay(now)) {
      setHistory([], iso);
      return;
    }
    try {
      if (iso === isoDay(now)) {
        const h = await api.history("today");
        setHistory(h.rows.map(rowToPoint), iso);
        return;
      }
      const start = new Date(`${iso}T00:00:00`);
      const end = new Date(start.getTime() + 86400000);
      const h = await api.historyDay(start, end);
      setHistory(h.rows.map(rowToPoint), iso);
    } catch {
      setHistory([], iso);
    }
  };

  const degraded = connection !== "live";
  return (
    <main className="dashboard-bg dash-main flex flex-col" style={{ paddingTop: "max(var(--dash-pad), env(safe-area-inset-top))", paddingBottom: "max(var(--dash-pad), env(safe-area-inset-bottom))" }}>
      <Header />
      {degraded ? (
        <div className="mono -mt-2 flex h-9 shrink-0 items-center justify-center rounded-[3px] border text-[12px] uppercase tracking-[.1em]" style={{ borderColor: "rgba(224,83,61,.4)", background: "rgba(224,83,61,.12)", color: "var(--alert)" }}>
          Verbindung unterbrochen{lastFrameAt ? ` · letzte Daten ${hhmm(new Date(lastFrameAt + offset))}` : ""} - Anzeige wird fortgesetzt, sobald das Backend erreichbar ist
        </div>
      ) : null}
      <div className="dash-top" style={{ opacity: degraded ? 0.6 : 1, transition: "opacity .4s" }}>
        <EnergyFlow snapshot={state?.snapshot ?? null} nowMs={nowMs} />
        <EnergyPlanCard state={state} plan={plan} />
        <BufferTank snapshot={state?.snapshot ?? null} buffer={state?.buffer ?? null} />
      </div>
      <div className="dash-chart" style={{ opacity: degraded ? 0.6 : 1 }}>
        <div className="flex min-h-0 w-full flex-col">
          <DayChart history={history} plan={plan} nowMs={nowMs} dayIso={historyDay} onDay={(iso) => void changeDay(iso)} layout={isMobile ? "stacked" : chartLayout} />
        </div>
      </div>
      <ControlsBar state={state} readOnly={role !== "owner"} />
    </main>
  );
}
