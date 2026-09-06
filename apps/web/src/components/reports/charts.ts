import type { EChartsCoreOption } from "echarts/core";
import type { EnergyBucket, EnergyTotals, HeatForecastPoint } from "@/lib/api/models";

export const C = {
  pv: "#f2a900",
  battery: "#7fa3b3",
  grid: "#e0533d",
  hp: "#e4ecef",
  ev: "#5c8fa3",
  base: "#4d6b78",
  export: "rgba(228,236,239,.5)",
  mist: "#7fa3b3",
  gridline: "rgba(255,255,255,.09)",
  axis: "rgba(255,255,255,.2)",
  text: "rgba(255,255,255,.48)",
  deep: "#082431",
};
export const MONO = "'IBM Plex Mono', ui-monospace, monospace";
const axisText = { color: C.text, fontFamily: MONO, fontSize: 11 };
const tooltip = { backgroundColor: C.deep, borderColor: "rgba(255,255,255,.14)", borderRadius: 3, textStyle: { color: "rgba(255,255,255,.92)", fontFamily: MONO, fontSize: 12 } };
const de1 = (n: number, d = 1) => n.toLocaleString("de-DE", { minimumFractionDigits: d, maximumFractionDigits: d });

export type BarSeries = { key: keyof EnergyTotals; name: string; color: string };

/** Gestapelte Balken je Zeitraum-Bucket; Werte in kWh. Leere Buckets (keine Daten) bleiben leer. */
export function stackedBars(buckets: EnergyBucket[], series: BarSeries[], unit = "kWh"): EChartsCoreOption {
  const labels = buckets.map((b) => b.label);
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      axisPointer: { type: "shadow" },
      formatter: (params: unknown) => {
        const ps = params as Array<{ seriesName: string; value: number; color: string; dataIndex: number }>;
        if (!ps.length) return "";
        const b = buckets[ps[0]!.dataIndex];
        const total = ps.reduce((a, p) => a + (typeof p.value === "number" ? p.value : 0), 0);
        const rows = ps
          .filter((p) => typeof p.value === "number" && p.value !== 0)
          .map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${de1(p.value)} ${unit}</span></div>`)
          .join("");
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${b?.label ?? ""}</div>${rows}<div style="margin-top:4px;border-top:1px solid rgba(255,255,255,.12);padding-top:3px">Summe ${de1(total)} ${unit}</div>`;
      },
    },
    grid: { left: 48, right: 12, top: 24, bottom: 30 },
    xAxis: { type: "category", data: labels, axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10, interval: buckets.length > 12 ? "auto" : 0, hideOverlap: true } },
    yAxis: { type: "value", name: unit, nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText, splitNumber: 3 },
    series: series.map((s, i) => ({
      name: s.name,
      type: "bar",
      stack: "total",
      data: buckets.map((b) => {
        const v = b.totals[s.key];
        return typeof v === "number" ? Math.round(v * 100) / 100 : 0;
      }),
      itemStyle: { color: s.color, borderRadius: i === series.length - 1 ? [2, 2, 0, 0] : 0 },
      barCategoryGap: "35%",
    })),
  };
}

/** Anteile als Ring, Beschriftung in der Mitte. */
export function donut(parts: Array<{ name: string; value: number; color: string }>, center: string, sub: string): EChartsCoreOption {
  const total = parts.reduce((a, p) => a + p.value, 0);
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, formatter: (p: unknown) => { const q = p as { name: string; value: number; percent: number }; return `${q.name}: ${de1(q.value)} kWh · ${Math.round(q.percent)} %`; } },
    series: [
      {
        type: "pie",
        radius: ["62%", "86%"],
        avoidLabelOverlap: false,
        label: { show: false },
        itemStyle: { borderColor: C.deep, borderWidth: 2 },
        data: total > 0 ? parts.map((p) => ({ name: p.name, value: Math.round(p.value * 100) / 100, itemStyle: { color: p.color } })) : [{ name: "keine Daten", value: 1, itemStyle: { color: "rgba(255,255,255,.08)" } }],
      },
    ],
    graphic: [
      { type: "text", left: "center", top: "42%", style: { text: center, fill: "rgba(255,255,255,.92)", font: `600 22px ${MONO}`, textAlign: "center" } },
      { type: "text", left: "center", top: "58%", style: { text: sub, fill: C.text, font: `11px ${MONO}`, textAlign: "center" } },
    ],
  };
}

/** Wärmebedarfsprognose: Heizung + Warmwasser gestapelt (kW_th), Strombedarf als Linie, Außentemperatur rechts. */
export function heatForecastChart(points: HeatForecastPoint[]): EChartsCoreOption {
  const labels = points.map((p) => new Date(p.ts).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" }));
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "axis" },
    legend: { type: "scroll", bottom: 0, left: "center", textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 }, itemWidth: 14, itemHeight: 8, itemGap: 14, pageIconColor: C.text, pageIconInactiveColor: "rgba(255,255,255,.15)", pageTextStyle: { color: C.text, fontFamily: MONO, fontSize: 10 } },
    grid: { left: 48, right: 48, top: 26, bottom: 56 },
    xAxis: { type: "category", data: labels, axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10, interval: "auto", hideOverlap: true } },
    yAxis: [
      { type: "value", name: "kW", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText, splitNumber: 3, min: 0 },
      { type: "value", name: "°C", position: "right", nameTextStyle: { color: C.text, fontSize: 10, align: "left", padding: [0, 0, 0, 6] }, splitLine: { show: false }, axisLabel: axisText, splitNumber: 3 },
    ],
    series: [
      { name: "Heizung (thermisch)", type: "bar", stack: "th", data: points.map((p) => p.heating_kw), itemStyle: { color: "rgba(242,169,0,.55)" }, barCategoryGap: "30%" },
      { name: "Warmwasser (thermisch)", type: "bar", stack: "th", data: points.map((p) => p.dhw_kw), itemStyle: { color: "rgba(127,163,179,.7)", borderRadius: [2, 2, 0, 0] } },
      { name: "Strombedarf WP", type: "line", data: points.map((p) => p.electric_kw), showSymbol: false, lineStyle: { color: C.hp, width: 2 }, z: 3 },
      { name: "Außentemperatur", type: "line", yAxisIndex: 1, data: points.map((p) => p.outdoor_c), showSymbol: false, lineStyle: { color: C.grid, width: 1.5, type: [4, 4] }, z: 2 },
    ],
  };
}

/** Puffertemperaturen und WP-Leistung über den Tag (5-min-Raster). */
export function bufferChart(rows: Array<Record<string, number | string | null>>): EChartsCoreOption {
  const labels = rows.map((r) => new Date(String(r.ts)).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" }));
  const num = (k: string) => rows.map((r) => (typeof r[k] === "number" ? (r[k] as number) : null));
  const temps: Array<[string, string, string]> = [
    ["buffer_temp_top_c", "oben", "#f2a900"],
    ["buffer_temp_mid_top_c", "mitte oben", "#ffd778"],
    ["buffer_temp_mid_bottom_c", "mitte unten", "#7fa3b3"],
    ["buffer_temp_bottom_c", "unten", "#1f4c66"],
  ];
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "axis" },
    legend: { type: "scroll", bottom: 0, left: "center", textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 }, itemWidth: 14, itemHeight: 8, itemGap: 14, pageIconColor: C.text, pageIconInactiveColor: "rgba(255,255,255,.15)", pageTextStyle: { color: C.text, fontFamily: MONO, fontSize: 10 } },
    grid: { left: 48, right: 48, top: 26, bottom: 56 },
    xAxis: { type: "category", data: labels, axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10, interval: "auto", hideOverlap: true } },
    yAxis: [
      { type: "value", name: "°C", min: 20, max: 70, interval: 10, nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText },
      { type: "value", name: "kW", position: "right", min: 0, nameTextStyle: { color: C.text, fontSize: 10, align: "left", padding: [0, 0, 0, 6] }, splitLine: { show: false }, axisLabel: axisText, splitNumber: 3 },
    ],
    series: [
      ...temps.map(([k, name, color]) => ({ name, type: "line", data: num(k), showSymbol: false, connectNulls: true, lineStyle: { color, width: 2 }, z: 3 })),
      { name: "WP-Leistung", type: "line", yAxisIndex: 1, step: "end", data: num("heat_pump_power_kw"), showSymbol: false, lineStyle: { color: C.hp, width: 1.5 }, areaStyle: { color: "rgba(228,236,239,.10)" }, z: 1 },
    ],
  };
}

/** Linie einer Größe über den Tag (z. B. SOC) aus Minutenzeilen der Historie. */
export function lineOverDay(rows: Array<{ ts: number; value: number | null }>, name: string, color: string, unit: string, max?: number): EChartsCoreOption {
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "axis", formatter: (params: unknown) => { const ps = params as Array<{ value: [number, number | null] }>; const p = ps[0]; if (!p || p.value[1] == null) return ""; return `${new Date(p.value[0]).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" })} · ${de1(p.value[1], 0)} ${unit}`; } },
    grid: { left: 48, right: 12, top: 24, bottom: 30 },
    xAxis: { type: "time", axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, splitLine: { show: false }, axisLabel: { ...axisText, formatter: (v: number) => new Date(v).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" }) } },
    yAxis: { type: "value", min: 0, max, name: unit, nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText, splitNumber: 3 },
    series: [{ name, type: "line", data: rows.map((r) => [r.ts, r.value]), showSymbol: false, connectNulls: true, lineStyle: { color, width: 2 }, areaStyle: { color: "rgba(127,163,179,.14)" } }],
  };
}

/** PV-Leistung: Ist heute (Minutenwerte) und Prognose über den Planhorizont (heute + morgen) auf einer Zeitachse. */
export function pvForecastChart(actual: Array<{ ts: number; kw: number | null }>, forecast: Array<{ ts: number; kw: number }>, dayStartMs: number, nowMs: number): EChartsCoreOption {
  const end = dayStartMs + 48 * 3600_000;
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      formatter: (params: unknown) => {
        const ps = params as Array<{ seriesName: string; value: [number, number | null]; color: string }>;
        const p0 = ps[0];
        if (!p0) return "";
        const t = new Date(p0.value[0]).toLocaleString("de-DE", { weekday: "short", hour: "2-digit", minute: "2-digit" });
        const rows = ps.filter((p) => p.value[1] != null).map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${de1(p.value[1] ?? 0)} kW</span></div>`).join("");
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>${rows}`;
      },
    },
    legend: { type: "scroll", bottom: 0, left: "center", textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 }, itemWidth: 14, itemHeight: 8, itemGap: 14, pageIconColor: C.text, pageIconInactiveColor: "rgba(255,255,255,.15)", pageTextStyle: { color: C.text, fontFamily: MONO, fontSize: 10 } },
    grid: { left: 48, right: 16, top: 26, bottom: 56 },
    xAxis: {
      type: "time",
      min: dayStartMs,
      max: end,
      interval: 6 * 3600_000,
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel: { ...axisText, fontSize: 10, formatter: (v: number) => { const d = new Date(v); const h = d.getHours(); return h === 0 ? d.toLocaleDateString("de-DE", { weekday: "short", day: "2-digit", month: "2-digit" }) : `${String(h).padStart(2, "0")}:00`; } },
    },
    yAxis: { type: "value", min: 0, name: "kW", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText, splitNumber: 3 },
    series: [
      {
        name: "Prognose",
        type: "line",
        data: forecast.map((p) => [p.ts, p.kw]),
        showSymbol: false,
        lineStyle: { color: "#e4ecef", width: 1.5, type: [5, 4] },
        areaStyle: { color: "rgba(228,236,239,.06)" },
        z: 2,
        markLine: { symbol: "none", silent: true, lineStyle: { color: "rgba(255,255,255,.25)", type: "solid", width: 1 }, label: { show: true, position: "insideEndTop", color: C.text, fontFamily: MONO, fontSize: 10, formatter: "morgen" }, data: [{ xAxis: dayStartMs + 24 * 3600_000 }] },
      },
      {
        name: "Ist",
        type: "line",
        data: actual.map((p) => [p.ts, p.kw]),
        showSymbol: false,
        connectNulls: false,
        lineStyle: { color: C.pv, width: 2.5 },
        areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1, colorStops: [{ offset: 0, color: "rgba(242,169,0,.3)" }, { offset: 1, color: "rgba(242,169,0,.03)" }] } },
        z: 3,
        markLine: { symbol: "none", silent: true, lineStyle: { color: C.pv, type: "dashed", width: 1.5 }, label: { show: false }, data: [{ xAxis: nowMs }] },
      },
    ],
  };
}

/** Batterie über den Tag: Ladezustand (links, %) und Leistung (rechts, kW; + Entladen, − Laden). */
export function batteryDayChart(rows: Array<Record<string, number | string | null>>): EChartsCoreOption {
  const ts = (r: Record<string, number | string | null>) => new Date(String(r.ts)).getTime();
  const num = (r: Record<string, number | string | null>, k: string) => (typeof r[k] === "number" ? (r[k] as number) : null);
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      formatter: (params: unknown) => {
        const ps = params as Array<{ seriesName: string; value: [number, number | null]; color: string }>;
        const p0 = ps[0];
        if (!p0) return "";
        const t = new Date(p0.value[0]).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });
        const rows2 = ps.filter((p) => p.value[1] != null).map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${p.seriesName === "Ladezustand" ? `${Math.round(p.value[1] ?? 0)} %` : `${de1(p.value[1] ?? 0, 2)} kW`}</span></div>`).join("");
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>${rows2}`;
      },
    },
    legend: { type: "scroll", bottom: 0, left: "center", textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 }, itemWidth: 14, itemHeight: 8, itemGap: 14, pageIconColor: C.text, pageIconInactiveColor: "rgba(255,255,255,.15)", pageTextStyle: { color: C.text, fontFamily: MONO, fontSize: 10 } },
    grid: { left: 48, right: 48, top: 26, bottom: 56 },
    xAxis: { type: "time", axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, splitLine: { show: false }, axisLabel: { ...axisText, fontSize: 10, formatter: (v: number) => new Date(v).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" }) } },
    yAxis: [
      { type: "value", min: 0, max: 100, interval: 25, name: "%", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText },
      { type: "value", name: "kW", position: "right", nameTextStyle: { color: C.text, fontSize: 10, align: "left", padding: [0, 0, 0, 6] }, splitLine: { show: false }, axisLabel: axisText, splitNumber: 3 },
    ],
    series: [
      { name: "Leistung", type: "line", yAxisIndex: 1, step: "end", data: rows.map((r) => [ts(r), num(r, "battery_power_kw")]), showSymbol: false, lineStyle: { color: "rgba(127,163,179,.7)", width: 1 }, areaStyle: { color: "rgba(127,163,179,.12)" }, z: 1 },
      { name: "Ladezustand", type: "line", data: rows.map((r) => [ts(r), num(r, "battery_soc") != null ? (num(r, "battery_soc") as number) * 100 : null]), showSymbol: false, connectNulls: true, lineStyle: { color: C.pv, width: 2.5 }, z: 3 },
    ],
  };
}
