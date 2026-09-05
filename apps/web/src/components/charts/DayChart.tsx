"use client";

import { useMemo } from "react";
import type { EChartsCoreOption } from "echarts/core";
import type { Plan } from "@/lib/api/models";
import type { HistoryPoint } from "@/lib/live/store";
import { hhmm } from "@/lib/format";
import { Card } from "@/components/ui/Card";
import { EChart } from "./EChart";

const C = {
  pv: "#f2a900",
  hp: "#e4ecef",
  ev: "#5c8fa3",
  price: "#7fa3b3",
  ember: "#e0533d",
  grid: "rgba(255,255,255,.09)",
  axis: "rgba(255,255,255,.2)",
  text: "rgba(255,255,255,.48)",
  deep: "#082431",
};
const MONO = "'IBM Plex Mono', ui-monospace, monospace";

function berlinOffsetMs(at: number): number {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "Europe/Berlin", hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" }).formatToParts(new Date(at));
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? 0);
  return Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second")) - at;
}

/** Mitternacht in Europe/Berlin als UTC-Zeitstempel – unabhängig von der Zeitzone des Browsers. */
export function dayBounds(nowMs: number): [number, number] {
  const off = berlinOffsetMs(nowMs);
  const local = new Date(nowMs + off);
  const midnightLocal = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  const start = midnightLocal - berlinOffsetMs(midnightLocal - off);
  return [start, start + 24 * 3600 * 1000];
}

export function DayChart({ history, plan, nowMs, range, onRange }: { history: HistoryPoint[]; plan: Plan | null; nowMs: number; range: "today" | "yesterday"; onRange: (r: "today" | "yesterday") => void }) {
  const [start, end] = useMemo(() => {
    const [s, e] = dayBounds(nowMs);
    return range === "today" ? [s, e] : [s - 86400000, e - 86400000];
  }, [nowMs, range]);

  const option = useMemo<EChartsCoreOption>(() => {
    const hx = (ts: number) => (ts - start) / 3600000;
    const inDay = history.filter((p) => p.ts >= start && p.ts < end);
    const pv = inDay.map((p) => [hx(p.ts), p.pv]);
    const hp = inDay.map((p) => [hx(p.ts), p.hp]);
    const ev = inDay.map((p) => [hx(p.ts), p.ev]);
    const priceHist = inDay.map((p) => [hx(p.ts), p.price]);
    const future = (plan?.intervals ?? []).filter((i) => {
      const t = new Date(i.ts).getTime();
      return t >= nowMs - 15 * 60000 && t >= start && t <= end;
    });
    const pvForecast = range === "today" ? future.map((i) => [hx(new Date(i.ts).getTime()), i.expected_pv_kw]) : [];
    const priceFuture = range === "today" ? future.map((i) => [hx(new Date(i.ts).getTime()), i.price_ct_kwh]) : [];
    const bands = (plan?.windows ?? [])
      .filter((w) => new Date(w.start).getTime() < end && new Date(w.end).getTime() > start)
      .map((w) => {
        const color = w.kind === "pv_surplus" ? "rgba(242,169,0,.10)" : w.kind === "expensive" ? "rgba(224,83,61,.08)" : w.kind === "negative" ? "rgba(224,83,61,.14)" : "rgba(127,163,179,.12)";
        const label = { pv_surplus: "PV-ÜBERSCHUSS NUTZEN", expensive: "WP VERMEIDEN", cheap: "GÜNSTIG", negative: "NEGATIVER PREIS" }[w.kind];
        const labelColor = w.kind === "pv_surplus" ? C.pv : w.kind === "expensive" || w.kind === "negative" ? C.ember : C.price;
        return [
          { xAxis: Math.max(0, hx(new Date(w.start).getTime())), itemStyle: { color }, label: { show: true, position: "insideTopLeft", formatter: label, color: labelColor, fontFamily: MONO, fontSize: 10, letterSpacing: 1 } },
          { xAxis: Math.min(24, hx(new Date(w.end).getTime())) },
        ];
      });
    const priceBands = bands.filter((b) => ["GÜNSTIG", "NEGATIVER PREIS"].includes(String((b[0] as { label: { formatter: string } }).label.formatter)));
    const powerBands = bands.filter((b) => !priceBands.includes(b));
    // Achsen skalieren mit den Daten: wenige, runde Schritte, damit der Verlauf ablesbar bleibt
    const maxOf = (rows: Array<Array<number | null>>) => rows.reduce((m, p) => (typeof p[1] === "number" && Number.isFinite(p[1]) ? Math.max(m, p[1]) : m), 0);
    const minOf = (rows: Array<Array<number | null>>) => rows.reduce((m, p) => (typeof p[1] === "number" && Number.isFinite(p[1]) ? Math.min(m, p[1]) : m), 0);
    const powerMax = Math.max(4, Math.ceil((maxOf([...pv, ...hp, ...ev, ...pvForecast]) * 1.1) / 2) * 2);
    const priceRows = [...priceHist, ...priceFuture];
    const priceMin = Math.min(0, Math.floor(minOf(priceRows) / 5) * 5);
    const priceStep = [5, 10, 15, 20, 30, 50].find((st) => priceMin + 3 * st >= Math.max(15, maxOf(priceRows) * 1.1)) ?? 50;
    const priceMax = priceMin + 3 * priceStep;
    const axisCommon = {
      type: "value" as const,
      min: 0,
      max: 24,
      interval: 4,
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 11, formatter: (v: number) => `${String(v % 24).padStart(2, "0")}:00` },
    };
    const nowLine = range === "today" ? { symbol: "none", silent: true, lineStyle: { color: C.pv, type: "dashed", width: 1.5 }, label: { show: false }, data: [{ xAxis: hx(nowMs) }] } : undefined;
    return {
      animation: false,
      backgroundColor: "transparent",
      textStyle: { fontFamily: MONO },
      axisPointer: { link: [{ xAxisIndex: "all" }], lineStyle: { color: C.axis } },
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
            .map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${p.value[1]!.toFixed(1).replace(".", ",")} ${p.seriesName === "Strompreis" || p.seriesName === "Preis morgen" ? "ct/kWh" : "kW"}</span></div>`)
            .join("");
          return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>${rows}`;
        },
      },
      grid: [
        { left: 48, right: 16, top: 22, height: "40%" },
        { left: 48, right: 16, top: "66%", height: "26%" },
      ],
      xAxis: [
        { ...axisCommon, gridIndex: 0, axisLabel: { show: false } },
        { ...axisCommon, gridIndex: 1 },
      ],
      yAxis: [
        { type: "value", gridIndex: 0, min: 0, max: powerMax, interval: powerMax / 2, name: "kW", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.grid } }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: 11 } },
        { type: "value", gridIndex: 1, min: priceMin, max: priceMax, interval: priceStep, name: "ct/kWh", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.grid } }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: 11 } },
      ],
      series: [
        { name: "PV", type: "line", xAxisIndex: 0, yAxisIndex: 0, data: pv, showSymbol: false, lineStyle: { color: C.pv, width: 2.5 }, areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1, colorStops: [{ offset: 0, color: "rgba(242,169,0,.32)" }, { offset: 1, color: "rgba(242,169,0,.03)" }] } }, markArea: { silent: true, data: powerBands }, markLine: nowLine, z: 3 },
        { name: "PV-Prognose", type: "line", xAxisIndex: 0, yAxisIndex: 0, data: pvForecast, showSymbol: false, lineStyle: { color: C.pv, width: 2, type: [7, 7], opacity: 0.8 }, z: 2 },
        { name: "Wärmepumpe", type: "line", step: "end", xAxisIndex: 0, yAxisIndex: 0, data: hp, showSymbol: false, lineStyle: { color: C.hp, width: 2 }, z: 4 },
        { name: "Wallbox", type: "line", step: "end", xAxisIndex: 0, yAxisIndex: 0, data: ev, showSymbol: false, lineStyle: { color: C.ev, width: 2 }, z: 3 },
        { name: "Strompreis", type: "line", step: "end", xAxisIndex: 1, yAxisIndex: 1, data: priceHist, showSymbol: false, lineStyle: { color: C.price, width: 2 }, markArea: { silent: true, data: priceBands }, markLine: nowLine, z: 3 },
        { name: "Preis morgen", type: "line", step: "end", xAxisIndex: 1, yAxisIndex: 1, data: priceFuture, showSymbol: false, lineStyle: { color: C.price, width: 2, type: [7, 7], opacity: 0.8 }, z: 2 },
      ],
    };
  }, [history, plan, nowMs, start, end, range]);

  const Legend = ({ color, label, dashed = false }: { color: string; label: string; dashed?: boolean }) => (
    <span className="flex items-center gap-2 text-[12px] text-text-2">
      <span className="inline-block w-[18px]" style={{ borderTop: `2px ${dashed ? "dashed" : "solid"} ${color}` }} />
      {label}
    </span>
  );
  const Seg = ({ v, label }: { v: "today" | "yesterday"; label: string }) => (
    <button onClick={() => onRange(v)} className="mono px-4 py-2 text-[12px] uppercase tracking-[.08em]" style={{ background: range === v ? "var(--amber)" : "transparent", color: range === v ? "var(--petrol)" : "var(--text-3)" }}>
      {label}
    </button>
  );
  return (
    <Card className="flex-1" style={{ padding: 16, minHeight: 0 }}>
      <div className="flex items-center justify-between">
        <div className="flex items-baseline gap-5">
          <h2 className="kicker m-0">{range === "today" ? "Heute" : "Gestern"} · Leistung und Strompreis</h2>
          <div className="flex gap-5">
            <Legend color={C.pv} label="PV" />
            <Legend color={C.hp} label="Wärmepumpe" />
            <Legend color={C.ev} label="Wallbox" />
            <Legend color={C.price} label="Strompreis" />
            <Legend color={C.pv} label="Prognose" dashed />
          </div>
        </div>
        <div className="flex overflow-hidden rounded-[3px] border border-line-2">
          <Seg v="today" label="Heute" />
          <Seg v="yesterday" label="Gestern" />
        </div>
      </div>
      <div className="mt-1 min-h-0 flex-1">
        <EChart option={option} />
      </div>
    </Card>
  );
}
