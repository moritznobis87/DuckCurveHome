"use client";

import { useMemo } from "react";
import type { EChartsCoreOption } from "echarts/core";
import type { Plan } from "@/lib/api/models";
import type { HistoryPoint } from "@/lib/live/store";
import { hhmm } from "@/lib/format";
import { Card } from "@/components/ui/Card";
import { EChart } from "./EChart";

import { C, MONO } from "./palette";

function berlinOffsetMs(at: number): number {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "Europe/Berlin", hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" }).formatToParts(new Date(at));
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? 0);
  return Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second")) - at;
}

/** Mitternacht in Europe/Berlin als UTC-Zeitstempel - unabhängig von der Zeitzone des Browsers. */
/** Skalierung der Preisachse.
 *
 * Der Strompreis schwankt an einem Tag oft nur zwischen 18 und 45 ct. Eine Achse, die bei 0 beginnt,
 * drückt den Verlauf dann in das obere Drittel und macht ihn flach - deshalb spannt sie hier zwischen
 * dem tatsächlichen Minimum und Maximum auf, gerundet auf runde Schritte und mit etwas Luft, damit die
 * Kurve die Ränder nicht berührt. Negative Preise kommen vor und werden mit erfasst.
 */
export function priceBounds(rows: Array<Array<number | null>>): { min: number; max: number; step: number } {
  const values = rows.map((p) => p[1]).filter((v): v is number => typeof v === "number" && Number.isFinite(v));
  if (values.length === 0) return { min: 0, max: 45, step: 15 };
  const lo = Math.min(...values);
  const hi = Math.max(...values);
  const pad = Math.max(0.5, (hi - lo) * 0.06); // wenig Luft, damit die Kurve die Ränder nicht berührt
  // Der feinste runde Schritt, der mit höchstens sieben Abschnitten auskommt. Weil die Schrittweiten
  // ansteigen, ist der erste Treffer zugleich der mit der engsten Spanne - und je enger die Spanne,
  // desto mehr Höhe bleibt für den Verlauf. Ein gröberer Schritt reißt die Achse beim Runden wieder auf:
  // bei 22-46 ct ergibt Schritt 5 die Spanne 20-50, Schritt 10 dagegen 20-50 → 10-50, Schritt 20 sogar 0-60.
  for (const step of [0.5, 1, 2, 2.5, 5, 10, 20, 25, 50, 100]) {
    const min = Math.floor((lo - pad) / step) * step;
    const max = Math.ceil((hi + pad) / step) * step;
    if ((max - min) / step <= 7) return { min, max: Math.max(max, min + 2 * step), step };
  }
  return { min: Math.floor(lo - pad), max: Math.ceil(hi + pad), step: Math.max(1, Math.round((hi - lo) / 3)) };
}

export function dayBounds(nowMs: number): [number, number] {
  const off = berlinOffsetMs(nowMs);
  const local = new Date(nowMs + off);
  const midnightLocal = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  const start = midnightLocal - berlinOffsetMs(midnightLocal - off);
  return [start, start + 24 * 3600 * 1000];
}

/** Anordnung der beiden Zeitreihen: nebeneinander (Standard), untereinander oder in einem Plot mit zwei y-Achsen. Umschalten per ?chart=side|stacked|overlay, wird pro Gerät gemerkt. */
export type ChartLayout = "stacked" | "side" | "overlay";
/** Ein Kalendertag als ISO-Datum in Ortszeit. `sv-SE` liefert genau YYYY-MM-DD. */
export function isoDay(ms: number): string {
  return new Date(ms).toLocaleDateString("sv-SE");
}

/** Ortszeit-Mitternacht des Tages und des Folgetags. */
function boundsOf(dayIso: string): [number, number] {
  const s = new Date(`${dayIso}T00:00:00`).getTime();
  return [s, s + 86400000];
}

export function DayChart({ history, plan, nowMs, dayIso, onDay, layout = "side" }: { history: HistoryPoint[]; plan: Plan | null; nowMs: number; dayIso: string; onDay: (iso: string) => void; layout?: ChartLayout }) {
  // Ein leerer Tag heisst „noch nicht gesetzt" und darf nicht bis in die Beschriftung durchschlagen
  // - dort stand sonst „Invalid Date", bis die erste Antwort da war.
  const day = dayIso || isoDay(nowMs);
  const [start, end] = useMemo(() => boundsOf(day), [day]);
  const isToday = day === isoDay(nowMs);
  // Prognose und Fahrplan gibt es nur für das, was noch kommt. Für einen abgeschlossenen Tag hätte
  // der aktuelle Plan dort nichts zu suchen - er ist der Plan von heute, nicht der von damals.
  const isPast = end <= nowMs;

  const option = useMemo<EChartsCoreOption>(() => {
    const hx = (ts: number) => (ts - start) / 3600000;
    const inDay = history.filter((p) => p.ts >= start && p.ts < end);
    const pv = inDay.map((p) => [hx(p.ts), p.pv]);
    const hp = inDay.map((p) => [hx(p.ts), p.hp]);
    const ev = inDay.map((p) => [hx(p.ts), p.ev]);
    /**
     * Netzbezug: nur was aus dem Netz kommt, die Einspeisung bleibt draussen.
     *
     * Die Reihe `grid_power_kw` ist vorzeichenbehaftet, + ist Bezug. Hier steht sie auf null, wo
     * eingespeist wird, statt ins Negative zu laufen: die Flaeche dieses Diagramms beginnt bei
     * null, eine negative Linie waere unsichtbar und die Achse muesste sich fuer sie oeffnen - dann
     * schrumpfen alle anderen Reihen. Wer die Einspeisung sehen will, findet sie auf /daten, wo das
     * Netz mit Vorzeichen steht.
     */
    const grid = inDay.map((p) => [hx(p.ts), p.grid === null ? null : Math.max(0, p.grid)]);
    const priceHist = inDay.map((p) => [hx(p.ts), p.price]);
    const future = (plan?.intervals ?? []).filter((i) => {
      const t = new Date(i.ts).getTime();
      return t >= nowMs - 15 * 60000 && t >= start && t <= end;
    });
    const showForecast = !isPast;
    const pvForecast = showForecast ? future.map((i) => [hx(new Date(i.ts).getTime()), i.expected_pv_kw]) : [];
    // Alles ab jetzt, nicht „morgen": innerhalb der Tagesansicht sind das weiterhin die Preise von
    // heute, nur noch nicht eingetreten. Die Reihe hieß darum falsch.
    const priceFuture = showForecast ? future.map((i) => [hx(new Date(i.ts).getTime()), i.price_ct_kwh]) : [];
    const bands = (plan?.windows ?? [])
      .filter((w) => new Date(w.start).getTime() < end && new Date(w.end).getTime() > start)
      .map((w) => {
        const color = w.kind === "pv_surplus" ? "rgba(242,169,0,.10)" : w.kind === "expensive" ? "rgba(224,83,61,.08)" : w.kind === "negative" ? "rgba(224,83,61,.14)" : "rgba(127,163,179,.12)";
        const label = { pv_surplus: "PV NUTZEN", expensive: "WP MEIDEN", cheap: "GÜNSTIG", negative: "NEGATIV" }[w.kind];
        const labelColor = w.kind === "pv_surplus" ? C.pv : w.kind === "expensive" || w.kind === "negative" ? C.alert : C.price;
        return [
          { xAxis: Math.max(0, hx(new Date(w.start).getTime())), itemStyle: { color }, label: { show: true, position: "insideTopLeft", formatter: label, color: labelColor, fontFamily: MONO, fontSize: 10, letterSpacing: 1 } },
          { xAxis: Math.min(24, hx(new Date(w.end).getTime())) },
        ];
      });
    const priceBandsFull = bands.filter((b) => ["GÜNSTIG", "NEGATIV"].includes(String((b[0] as { label: { formatter: string } }).label.formatter)));
    const powerBands = bands.filter((b) => !priceBandsFull.includes(b));
    const priceX = layout === "overlay" ? 0 : 1;
    // Achsen skalieren mit den Daten: wenige, runde Schritte, damit der Verlauf ablesbar bleibt
    const maxOf = (rows: Array<Array<number | null>>) => rows.reduce((m, p) => (typeof p[1] === "number" && Number.isFinite(p[1]) ? Math.max(m, p[1]) : m), 0);
    const powerMax = Math.max(4, Math.ceil((maxOf([...pv, ...hp, ...ev, ...grid, ...pvForecast]) * 1.1) / 2) * 2);
    const priceRows = [...priceHist, ...priceFuture];
    const { min: priceMin, max: priceMax, step: priceStep } = priceBounds(priceRows);
    // Im Overlay teilen sich beide Reihen die Fläche: Preisfenster nur als Streifen am unteren Rand zeigen
    const priceBands =
      layout === "overlay"
        ? priceBandsFull.map(([a, b]) => [{ ...(a as object), yAxis: priceMin }, { ...(b as object), yAxis: priceMin + priceStep * 0.22 }])
        : priceBandsFull;
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
    const nowLine = isToday ? { symbol: "none", silent: true, lineStyle: { color: C.pv, type: "dashed", width: 1.5 }, label: { show: false }, data: [{ xAxis: hx(nowMs) }] } : undefined;
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
            .map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${p.value[1]!.toFixed(1).replace(".", ",")} ${p.seriesName === "Strompreis" || p.seriesName === "Preis voraus" ? "ct/kWh" : "kW"}</span></div>`)
            .join("");
          return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>${rows}`;
        },
      },
      grid: layout === "stacked"
        ? [
            { left: 48, right: 16, top: 22, height: "40%" },
            { left: 48, right: 16, top: "66%", height: "26%" },
          ]
        : layout === "side"
          ? [
              { left: 48, right: "53%", top: 22, bottom: 34 },
              { left: "53%", right: 16, top: 22, bottom: 34 },
            ]
          : [{ left: 48, right: 60, top: 22, bottom: 34 }],
      xAxis: layout === "stacked"
        ? [
            { ...axisCommon, gridIndex: 0, axisLabel: { show: false } },
            { ...axisCommon, gridIndex: 1 },
          ]
        : layout === "side"
          ? [
              { ...axisCommon, gridIndex: 0, interval: 6 },
              { ...axisCommon, gridIndex: 1, interval: 6 },
            ]
          : [{ ...axisCommon, gridIndex: 0 }],
      yAxis: [
        { type: "value", gridIndex: 0, min: 0, max: powerMax, interval: powerMax / 2, name: "kW", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: 11 } },
        {
          type: "value",
          gridIndex: layout === "overlay" ? 0 : 1,
          position: layout === "overlay" ? "right" : "left",
          min: priceMin,
          max: priceMax,
          interval: priceStep,
          name: "ct/kWh",
          nameTextStyle: { color: C.text, fontSize: 10, align: layout === "overlay" ? "left" : "right", padding: layout === "overlay" ? [0, 0, 0, 6] : [0, 6, 0, 0] },
          splitLine: { show: layout !== "overlay", lineStyle: { color: C.gridline } },
          axisLabel: { color: C.text, fontFamily: MONO, fontSize: 11 },
        },
      ],
      series: [
        { name: "PV", type: "line", xAxisIndex: 0, yAxisIndex: 0, data: pv, showSymbol: false, lineStyle: { color: C.pv, width: 2.5 }, areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1, colorStops: [{ offset: 0, color: "rgba(242,169,0,.32)" }, { offset: 1, color: "rgba(242,169,0,.03)" }] } }, markArea: { silent: true, data: powerBands }, markLine: nowLine, z: 3 },
        { name: "PV-Prognose", type: "line", xAxisIndex: 0, yAxisIndex: 0, data: pvForecast, showSymbol: false, lineStyle: { color: C.pv, width: 2, type: [7, 7], opacity: 0.8 }, z: 2 },
        { name: "Wärmepumpe", type: "line", step: "end", xAxisIndex: 0, yAxisIndex: 0, data: hp, showSymbol: false, lineStyle: { color: C.hp, width: 2 }, z: 4 },
        { name: "Wallbox", type: "line", step: "end", xAxisIndex: 0, yAxisIndex: 0, data: ev, showSymbol: false, lineStyle: { color: C.ev, width: 2 }, z: 3 },
        // Hinter den uebrigen Reihen (z: 1): der Netzbezug ist die Folge, nicht die Ursache, und er
        // soll die Erzeugung nicht verdecken. Farbe wie ueberall sonst im Haus fuer das Netz.
        { name: "Netzbezug", type: "line", step: "end", xAxisIndex: 0, yAxisIndex: 0, data: grid, showSymbol: false, lineStyle: { color: C.grid, width: 2 }, z: 1 },
        { name: "Strompreis", type: "line", step: "end", xAxisIndex: priceX, yAxisIndex: 1, data: priceHist, showSymbol: false, lineStyle: { color: C.price, width: 2 }, markArea: { silent: true, data: priceBands }, markLine: nowLine, z: 3 },
        { name: "Preis voraus", type: "line", step: "end", xAxisIndex: priceX, yAxisIndex: 1, data: priceFuture, showSymbol: false, lineStyle: { color: C.price, width: 2, type: [7, 7], opacity: 0.8 }, z: 2 },
      ],
    };
  }, [history, plan, nowMs, start, end, isToday, isPast, layout]);

  const Legend = ({ color, label, dashed = false }: { color: string; label: string; dashed?: boolean }) => (
    <span className="flex items-center gap-2 text-[12px] text-text-2">
      <span className="inline-block w-[18px]" style={{ borderTop: `2px ${dashed ? "dashed" : "solid"} ${color}` }} />
      {label}
    </span>
  );
  // Kalendernavigation statt drei fester Stufen. Gestern und morgen bleiben als Schnellwahl, weil
  // sie die häufigsten Sprünge sind; die Pfeile kommen an jeden anderen Tag.
  const shifted = (days: number) => isoDay(new Date(`${day}T12:00:00`).getTime() + days * 86400000);
  const Nav = ({ dir, label }: { dir: -1 | 1; label: string }) => (
    <button onClick={() => onDay(shifted(dir))} aria-label={label} title={label} className="px-2.5 py-1.5 text-[13px] text-text-2 transition-colors hover:text-text-1">
      {dir < 0 ? "‹" : "›"}
    </button>
  );
  const Quick = ({ iso, text }: { iso: string; text: string }) => (
    <button onClick={() => onDay(iso)} className="px-3 py-1.5 text-[12px] font-medium tracking-[.02em] transition-colors" style={{ background: day === iso ? "var(--amber)" : "transparent", color: day === iso ? "var(--petrol)" : "var(--text-2)", borderRadius: 2 }}>
      {text}
    </button>
  );
  const heute = isoDay(nowMs);
  const gestern = isoDay(nowMs - 86400000);
  const morgen = isoDay(nowMs + 86400000);
  const titel =
    day === heute ? "Heute" : day === gestern ? "Gestern" : day === morgen ? "Morgen" : new Date(`${day}T00:00:00`).toLocaleDateString("de-DE", { weekday: "short", day: "2-digit", month: "2-digit", year: "numeric" });
  return (
    <Card className="flex-1" style={{ padding: 16, minHeight: 0 }}>
      <div className="chart-head flex items-center justify-between">
        <div className="flex flex-wrap items-baseline gap-x-5 gap-y-1">
          <h2 className="kicker m-0">{titel} · Leistung {layout === "side" ? "|" : "und"} Strompreis</h2>
          {/* Zwei Legenden statt einer Reihe aus sechs Einträgen. Leistung und Preis stehen in
              getrennten Flächen mit eigenen Achsen; eine gemeinsame Legende liess offen, welcher
              Eintrag zu welcher Fläche gehört, und machte den Strompreis optisch zum vierten
              Energiefluss. Die Einheit steht jeweils davor und benennt die Zugehörigkeit. */}
          <div className="chart-legend flex flex-wrap items-baseline gap-x-5 gap-y-1">
            <span className="mono text-[11px] uppercase tracking-[.1em]" style={{ color: "var(--text-3)" }}>kW</span>
            <Legend color={C.pv} label="PV" />
            {isPast ? null : <Legend color={C.pv} label="PV-Prognose" dashed />}
            <Legend color={C.hp} label="Wärmepumpe" />
            <Legend color={C.ev} label="Wallbox" />
            <Legend color={C.grid} label="Netzbezug" />
            <span aria-hidden className="h-3 w-px" style={{ background: "var(--line-2)" }} />
            <span className="mono text-[11px] uppercase tracking-[.1em]" style={{ color: "var(--text-3)" }}>ct/kWh</span>
            <Legend color={C.price} label="Strompreis" />
            {isPast ? null : <Legend color={C.price} label="Preis voraus" dashed />}
          </div>
        </div>
        <div className="flex shrink-0 items-center gap-1 rounded-[3px] border border-line-2 p-1" aria-label="Tag wählen">
          <Nav dir={-1} label="Tag zurück" />
          <Quick iso={gestern} text="Gestern" />
          <Quick iso={heute} text="Heute" />
          <Quick iso={morgen} text="Morgen" />
          <Nav dir={1} label="Tag vor" />
        </div>
      </div>
      <div className="mt-1 min-h-0 flex-1">
        <EChart key={layout} option={option} />
      </div>
    </Card>
  );
}
