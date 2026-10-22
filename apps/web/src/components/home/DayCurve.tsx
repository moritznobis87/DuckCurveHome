"use client";

import { useMemo } from "react";
import type { EChartsCoreOption } from "echarts/core";
import type { Plan } from "@/lib/api/models";
import type { HistoryPoint } from "@/lib/live/store";
import { hhmm } from "@/lib/format";
import { isoDay } from "@/lib/day";
import { EChart } from "@/components/charts/EChart";
import { C, MONO } from "@/components/charts/palette";
import { priceBounds } from "@/components/charts/dayBounds";

/**
 * Die Kurve des Tages: die Marke selbst.
 *
 * Sonne als Flaeche (gemessen voll, Prognose blass und gestrichelt), das Haus als weisse Linie,
 * der Strompreis als Linie auf eigener Achse, das Preistief als Band. Ein Blick zeigt, warum es
 * dieses Haus gibt: mittags ist Strom billig, weil die Sonne scheint.
 *
 * Nur der laufende Tag. Vergangene Tage stehen unter Strom, mit Blaettern und allem; die
 * Wandanzeige soll nicht an einem Tag von vorgestern haengen bleiben, wie es der alten passiert
 * ist.
 */
function boundsOf(dayIso: string): [number, number] {
  const s = new Date(`${dayIso}T00:00:00`).getTime();
  return [s, s + 86400000];
}

export function DayCurve({ history, plan, nowMs }: { history: HistoryPoint[]; plan: Plan | null; nowMs: number }) {
  const day = isoDay(nowMs);
  const [start, end] = useMemo(() => boundsOf(day), [day]);

  const option = useMemo<EChartsCoreOption>(() => {
    const hx = (ts: number) => (ts - start) / 3600000;
    const inDay = history.filter((p) => p.ts >= start && p.ts < end);
    const pv = inDay.map((p) => [hx(p.ts), p.pv]);
    const haus = inDay.map((p) => [hx(p.ts), p.house]);
    const preisHist = inDay.map((p) => [hx(p.ts), p.price]);
    const future = (plan?.intervals ?? []).filter((i) => {
      const t = new Date(i.ts).getTime();
      return t >= nowMs - 15 * 60000 && t >= start && t <= end;
    });
    const pvPrognose = future.map((i) => [hx(new Date(i.ts).getTime()), i.expected_pv_kw]);
    const preisVoraus = future.map((i) => [hx(new Date(i.ts).getTime()), i.price_ct_kwh]);
    const baender = (plan?.windows ?? [])
      .filter((w) => (w.kind === "cheap" || w.kind === "negative") && new Date(w.start).getTime() < end && new Date(w.end).getTime() > start)
      .map((w) => [
        { xAxis: Math.max(0, hx(new Date(w.start).getTime())), itemStyle: { color: w.kind === "negative" ? "rgba(224,83,61,.14)" : "rgba(127,163,179,.14)" }, label: { show: true, position: "insideTopLeft", formatter: w.kind === "negative" ? "NEGATIV" : "PREISTIEF", color: w.kind === "negative" ? C.alert : C.price, fontFamily: MONO, fontSize: 10, letterSpacing: 1 } },
        { xAxis: Math.min(24, hx(new Date(w.end).getTime())) },
      ]);
    const maxOf = (rows: Array<Array<number | null>>) => rows.reduce((m, p) => (typeof p[1] === "number" && Number.isFinite(p[1]) ? Math.max(m, p[1]) : m), 0);
    const powerMax = Math.max(3, Math.ceil((maxOf([...pv, ...haus, ...pvPrognose]) * 1.1) / 2) * 2);
    const { min: pMin, max: pMax, step: pStep } = priceBounds([...preisHist, ...preisVoraus]);
    const jetzt = { symbol: "none", silent: true, lineStyle: { color: "var(--amber-soft)", type: "dashed", width: 1.2 }, label: { show: false }, data: [{ xAxis: hx(nowMs) }] };
    return {
      animation: false,
      backgroundColor: "transparent",
      textStyle: { fontFamily: MONO },
      tooltip: {
        trigger: "axis",
        backgroundColor: C.deep,
        borderColor: "rgba(255,255,255,.14)",
        borderRadius: 3,
        textStyle: { color: "rgba(255,255,255,.92)", fontFamily: MONO, fontSize: 12 },
        formatter: (params: unknown) => {
          const ps = params as Array<{ seriesName: string; value: [number, number | null]; color: string }>;
          if (!ps.length) return "";
          const t = hhmm(new Date(start + ps[0]!.value[0] * 3600000));
          const rows = ps
            .filter((p) => p.value[1] != null)
            .map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${p.value[1]!.toFixed(1).replace(".", ",")} ${p.seriesName.startsWith("Preis") || p.seriesName === "Strompreis" ? "ct" : "kW"}</span></div>`)
            .join("");
          return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>${rows}`;
        },
      },
      grid: { left: 40, right: 44, top: 10, bottom: 24 },
      xAxis: { type: "value", min: 0, max: 24, interval: 6, axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, splitLine: { show: false }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, formatter: (v: number) => `${String(v % 24).padStart(2, "0")}:00` } },
      yAxis: [
        { type: "value", min: 0, max: powerMax, interval: powerMax / 2, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, formatter: (v: number) => `${v} kW` } },
        { type: "value", position: "right", min: pMin, max: pMax, interval: pStep, splitLine: { show: false }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, formatter: (v: number) => `${v} ct` } },
      ],
      series: [
        { name: "Sonne", type: "line", yAxisIndex: 0, data: pv, showSymbol: false, lineStyle: { color: C.pv, width: 2 }, areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1, colorStops: [{ offset: 0, color: "rgba(242,169,0,.45)" }, { offset: 1, color: "rgba(242,169,0,.04)" }] } }, markArea: { silent: true, data: baender }, markLine: jetzt, z: 3 },
        { name: "Sonne, Prognose", type: "line", yAxisIndex: 0, data: pvPrognose, showSymbol: false, lineStyle: { color: C.pv, width: 1.5, type: [5, 5], opacity: 0.7 }, areaStyle: { color: "rgba(242,169,0,.08)" }, z: 2 },
        { name: "Haus", type: "line", yAxisIndex: 0, data: haus, showSymbol: false, lineStyle: { color: "rgba(255,255,255,.88)", width: 1.8 }, z: 4 },
        { name: "Strompreis", type: "line", step: "end", yAxisIndex: 1, data: preisHist, showSymbol: false, lineStyle: { color: C.price, width: 1.6 }, z: 3 },
        { name: "Preis voraus", type: "line", step: "end", yAxisIndex: 1, data: preisVoraus, showSymbol: false, lineStyle: { color: C.price, width: 1.6, type: [5, 5], opacity: 0.8 }, z: 2 },
      ],
    };
  }, [history, plan, nowMs, start, end]);

  const Legende = ({ color, label, dashed = false, flaeche = false }: { color: string; label: string; dashed?: boolean; flaeche?: boolean }) => (
    <span className="flex items-center gap-1.5 text-[12px] text-text-2">
      <span className="inline-block w-[14px]" style={flaeche ? { height: 8, background: color, borderRadius: 2, opacity: 0.6 } : { borderTop: `2px ${dashed ? "dashed" : "solid"} ${color}` }} />
      {label}
    </span>
  );
  return (
    <div className="home-kurve">
      <div className="flex items-baseline justify-between gap-4">
        <span className="kicker" style={{ fontSize: 11 }}>Heute</span>
        <div className="home-kurve-legende flex flex-wrap items-center justify-end gap-x-4 gap-y-1">
          <Legende color={C.pv} label="Sonne" flaeche />
          <Legende color={C.pv} label="Prognose" dashed />
          <Legende color="rgba(255,255,255,.88)" label="Haus" />
          <Legende color={C.price} label="Strompreis" />
          <Legende color={C.price} label="Preistief" flaeche />
        </div>
      </div>
      <div className="min-h-0 flex-1">
        <EChart option={option} />
      </div>
    </div>
  );
}
