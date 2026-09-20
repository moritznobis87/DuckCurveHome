import type { EChartsCoreOption } from "echarts/core";
import type { EnergyBucket, EnergyTotals, HeatForecastPoint } from "@/lib/api/models";

export { C, MONO } from "@/components/charts/palette";
import { C, MONO } from "@/components/charts/palette";
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

/** Anteile als Ring, Kennzahl in der Mitte, Legende darunter.
 *
 * Die Legende ist nicht schmückend. Ohne sie trägt allein die Farbe, welches Segment welches ist,
 * und wer den Ring zum ersten Mal sieht, kann es nicht wissen - im Ausdruck, bei Farbenblindheit
 * oder auf dem Kioskbildschirm aus zwei Metern schon gar nicht. Der Ring gibt dafür etwas Radius
 * ab; das ist der günstigere Tausch. */
export function donut(parts: Array<{ name: string; value: number; color: string }>, center: string, sub: string): EChartsCoreOption {
  const total = parts.reduce((a, p) => a + p.value, 0);
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, formatter: (p: unknown) => { const q = p as { name: string; value: number; percent: number }; return `${q.name}: ${de1(q.value)} kWh · ${Math.round(q.percent)} %`; } },
    legend: {
      show: total > 0,
      bottom: 0,
      left: "center",
      itemWidth: 10,
      itemHeight: 8,
      itemGap: 14,
      icon: "roundRect",
      textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 },
    },
    series: [
      {
        type: "pie",
        radius: ["58%", "80%"],
        center: ["50%", "44%"],
        avoidLabelOverlap: false,
        label: { show: false },
        // 2 px Fläche zwischen den Segmenten: die Trennung liegt dann in der Geometrie und nicht
        // allein in der Farbe.
        itemStyle: { borderColor: C.deep, borderWidth: 2 },
        data: total > 0 ? parts.map((p) => ({ name: p.name, value: Math.round(p.value * 100) / 100, itemStyle: { color: p.color } })) : [{ name: "keine Daten", value: 1, itemStyle: { color: "rgba(255,255,255,.08)" } }],
      },
    ],
    graphic: [
      { type: "text", left: "center", top: "37%", style: { text: center, fill: "rgba(255,255,255,.92)", font: `600 22px ${MONO}`, textAlign: "center" } },
      { type: "text", left: "center", top: "51%", style: { text: sub, fill: C.text, font: `11px ${MONO}`, textAlign: "center" } },
    ],
  };
}

/** Wärmebedarfsprognose: Heizung + Warmwasser gestapelt (kW_th), Strombedarf als Linie, Außentemperatur rechts. */
/** Positionen der Tageswechsel auf der Kategorienachse, benannt nach dem Wochentag danach. */
function midnights(points: HeatForecastPoint[]): Array<{ xAxis: number; value: string }> {
  const out: Array<{ xAxis: number; value: string }> = [];
  points.forEach((p, i) => {
    if (i === 0) return;
    const d = new Date(p.ts);
    const prev = new Date(points[i - 1]!.ts);
    if (d.getDate() !== prev.getDate()) {
      out.push({ xAxis: i, value: d.toLocaleDateString("de-DE", { weekday: "short" }) });
    }
  });
  return out;
}

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
      { name: "Außentemperatur", type: "line", yAxisIndex: 1, data: points.map((p) => p.outdoor_c), showSymbol: false, lineStyle: { color: C.grid, width: 1.5, type: [4, 4] }, z: 2,
        // Tagesgrenzen als senkrechte Striche: über 48 Stunden ist sonst nicht zu sehen, wo der
        // eine Tag endet. Angehängt an eine stille Reihe, damit sie nicht in der Legende auftaucht.
        markLine: {
          symbol: "none",
          silent: true,
          lineStyle: { color: "rgba(255,255,255,.28)", width: 1, type: "solid" },
          label: { show: true, position: "insideEndTop", color: C.text, fontFamily: MONO, fontSize: 10, formatter: (p: { value: string }) => p.value },
          data: midnights(points),
        } },
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
  // Brennphasen des Ofens als hinterlegte Bänder. Das ist der eigentliche Erkenntnisgewinn dieses
  // Diagramms: steigt die Puffertemperatur innerhalb eines Bandes, war es der Ofen und nicht die
  // Wärmepumpe. Vorher musste man das aus der Abwesenheit der WP-Leistung erschließen.
  const burns = runsOf(rows, "stove_running");
  const stoveBands = burns.map(([a, b]) => [{ xAxis: a }, { xAxis: b }]);

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
      // Träger der Bänder: eine Reihe ohne Daten, damit sie in der Legende steht und abschaltbar
      // bleibt. markArea allein bekäme keinen Legendeneintrag.
      ...(stoveBands.length
        ? [{ name: "Ofen brennt", type: "line", data: [], itemStyle: { color: C.stove }, markArea: { silent: true, itemStyle: { color: "rgba(181,101,29,.20)" }, data: stoveBands } }]
        : []),
    ],
  };
}

/** Zusammenhängende Abschnitte, in denen `key` wahr ist, als Indexpaare [von, bis]. */
function runsOf(rows: Array<Record<string, number | string | null>>, key: string): Array<[number, number]> {
  const out: Array<[number, number]> = [];
  let start = -1;
  rows.forEach((r, i) => {
    const on = typeof r[key] === "number" && (r[key] as number) > 0;
    if (on && start < 0) start = i;
    if (!on && start >= 0) {
      out.push([start, i - 1]);
      start = -1;
    }
  });
  if (start >= 0) out.push([start, rows.length - 1]);
  return out;
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

/** Abgerechnete Menge gegen die eigene Messung, je Abrechnungszeitraum. */
export function invoiceVsMeasured(items: Array<{ label: string; invoice: number; measured: number | null }>): EChartsCoreOption {
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "axis", axisPointer: { type: "shadow" }, valueFormatter: (v: unknown) => `${de1(Number(v))} kWh` },
    legend: { type: "scroll", bottom: 0, left: "center", textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 }, itemWidth: 14, itemHeight: 8 },
    grid: { left: 52, right: 12, top: 24, bottom: 52 },
    xAxis: { type: "category", data: items.map((i) => i.label), axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10, hideOverlap: true } },
    yAxis: { type: "value", name: "kWh", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText, splitNumber: 3 },
    series: [
      { name: "Rechnung", type: "bar", data: items.map((i) => i.invoice), itemStyle: { color: C.grid, borderRadius: [2, 2, 0, 0] }, barGap: "10%" },
      { name: "Eigene Messung", type: "bar", data: items.map((i) => i.measured), itemStyle: { color: C.mist, borderRadius: [2, 2, 0, 0] } },
    ],
  };
}

/** Rechnungsbetrag je Zeitraum, aufgeteilt in Arbeitspreis, Grundgebühr und Mehrwertsteuer. */
export function invoiceCostStack(items: Array<{ label: string; energy: number; fees: number; vat: number }>): EChartsCoreOption {
  const series: Array<[string, string, (i: (typeof items)[number]) => number]> = [
    ["Arbeitspreis netto", C.pv, (i) => i.energy],
    ["Grundgebühr netto", C.base, (i) => i.fees],
    ["Mehrwertsteuer", C.export, (i) => i.vat],
  ];
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "axis", axisPointer: { type: "shadow" }, valueFormatter: (v: unknown) => `${de1(Number(v), 2)} €` },
    legend: { type: "scroll", bottom: 0, left: "center", textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 }, itemWidth: 14, itemHeight: 8 },
    grid: { left: 52, right: 12, top: 24, bottom: 52 },
    xAxis: { type: "category", data: items.map((i) => i.label), axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10, hideOverlap: true } },
    yAxis: { type: "value", name: "€", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText, splitNumber: 3 },
    series: series.map(([name, color, pick], i) => ({
      name,
      type: "bar",
      stack: "eur",
      data: items.map(pick),
      itemStyle: { color, borderRadius: i === series.length - 1 ? [2, 2, 0, 0] : 0 },
      barCategoryGap: "35%",
    })),
  };
}

/** Durchschnittspreis der Rechnung gegen den aus unseren Preisdaten errechneten Wert. */
export function invoicePriceLine(items: Array<{ label: string; invoice: number; measured: number | null }>): EChartsCoreOption {
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "axis", valueFormatter: (v: unknown) => (v == null ? "-" : `${de1(Number(v), 2)} ct/kWh`) },
    legend: { type: "scroll", bottom: 0, left: "center", textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 }, itemWidth: 14, itemHeight: 8 },
    grid: { left: 52, right: 12, top: 24, bottom: 52 },
    xAxis: { type: "category", data: items.map((i) => i.label), axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10, hideOverlap: true } },
    yAxis: { type: "value", name: "ct/kWh", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText, splitNumber: 3, scale: true },
    series: [
      { name: "Rechnung (brutto)", type: "line", data: items.map((i) => i.invoice), showSymbol: true, symbolSize: 6, lineStyle: { color: C.pv, width: 2.5 }, itemStyle: { color: C.pv } },
      { name: "Eigene Preisreihe", type: "line", data: items.map((i) => i.measured), showSymbol: true, symbolSize: 5, connectNulls: true, lineStyle: { color: C.mist, width: 1.5, type: [5, 4] }, itemStyle: { color: C.mist } },
    ],
  };
}

/** Preisbestandteile einer Rechnung als liegende Balken (ct/kWh). */
export function invoicePositions(positions: Array<{ label: string; group: string; ct: number }>): EChartsCoreOption {
  const color: Record<string, string> = { Stromeinkauf: C.pv, Netz: C.mist, "Steuern, Abgaben & Umlagen": C.base };
  const rows = [...positions].reverse();
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "item", formatter: (p: unknown) => { const q = p as { name: string; value: number; data: { group?: string } }; return `${q.name}<br/>${de1(q.value, 3)} ct/kWh<br/><span style="color:${C.text}">${q.data.group ?? ""}</span>`; } },
    grid: { left: 168, right: 56, top: 8, bottom: 26 },
    xAxis: { type: "value", name: "ct/kWh", nameLocation: "middle", nameGap: 20, nameTextStyle: { color: C.text, fontSize: 10 }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText },
    yAxis: { type: "category", data: rows.map((r) => r.label), axisLine: { show: false }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10, width: 160, overflow: "truncate" } },
    series: [
      {
        type: "bar",
        data: rows.map((r) => ({ value: r.ct, group: r.group, itemStyle: { color: color[r.group] ?? C.base, borderRadius: [0, 2, 2, 0] } })),
        barWidth: "58%",
        label: { show: true, position: "right", color: C.text, fontFamily: MONO, fontSize: 10, formatter: (p: unknown) => de1((p as { value: number }).value, 3) },
      },
    ],
  };
}

export type MoneySeries = { name: string; color: string; values: number[] };

/** Gestapelte Balken über frei gewählte Beschriftungen, Werte in Euro (Tooltip mit zwei Nachkommastellen). */
export function moneyBars(labels: string[], series: MoneySeries[]): EChartsCoreOption {
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
        const total = ps.reduce((a, p) => a + (typeof p.value === "number" ? p.value : 0), 0);
        const rows = ps
          .filter((p) => typeof p.value === "number" && p.value !== 0)
          .map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${de1(p.value, 2)} €</span></div>`)
          .join("");
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${labels[ps[0]!.dataIndex] ?? ""}</div>${rows}<div style="margin-top:4px;border-top:1px solid rgba(255,255,255,.12);padding-top:3px">Summe ${de1(total, 2)} €</div>`;
      },
    },
    grid: { left: 52, right: 12, top: 24, bottom: 30 },
    xAxis: { type: "category", data: labels, axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10, interval: labels.length > 12 ? "auto" : 0, hideOverlap: true } },
    yAxis: { type: "value", name: "€", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: axisText, splitNumber: 3 },
    series: series.map((s, i) => ({
      name: s.name,
      type: "bar",
      stack: "total",
      data: s.values.map((v) => Math.round(v * 100) / 100),
      itemStyle: { color: s.color, borderRadius: i === series.length - 1 ? [2, 2, 0, 0] : 0 },
      barCategoryGap: "35%",
    })),
  };
}

/* Jahreskarte: 365 Spalten × 24 Zeilen.
   Die Rampen sind in OKLab zwischen Markenfarben interpoliert, nicht von Hand gewählt - nur so
   steigt die wahrgenommene Helligkeit gleichmäßig, und nur so liest sich „mehr" als „heller".
   Sequenziell = ein Farbton, von der Kartenfläche bis zur Marke; der dunkelste Schritt ist der
   Hintergrund selbst, damit „fast nichts" mit der Fläche verschmilzt.
   Divergierend = zwei Farbtöne mit neutraler, flächennaher Mitte, gleich große Helligkeitsschritte
   je Arm und beide Pole gleich hell - sonst schriee eine Seite lauter als die andere.
   Farbzuordnung wie im Energiefluss: Bernstein = eigene Energie, Mist = Netz. */
export const RAMP_OWN = ["#123544", "#6a6448", "#c39234", "#f5b22e", "#fac558", "#ffd778"];
export const RAMP_GRID = ["#123544", "#3c5f6e", "#688c9b", "#93b1bf", "#bbced7", "#e4ecef"];
export const RAMP_HEAT = ["#123544", "#655c57", "#b68365", "#e5a17a", "#eeb797", "#f6cdb4"];
/* Einspeisung (bernstein) ← neutral → Bezug (mist) */
export const RAMP_NET = ["#f2a900", "#ac833b", "#695f44", "#2b3a41", "#4c646e", "#70909f", "#96c0d3"];

const MONTHS = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"];

/** Robuste Obergrenze: das 98. Perzentil statt des Maximums.
 *  Ein einzelner Ausreißer - ein Ladevorgang, ein Defekt - zöge sonst die ganze Skala zusammen und
 *  färbte das restliche Jahr einheitlich dunkel. Der wahre Größtwert steht in der Fußnote. */
function robustMax(values: number[]): number {
  if (!values.length) return 1;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.98))] ?? 1;
}

export function yearMap(
  days: string[],
  grid: Array<Array<number | null>>,
  opts: {
    unit: string;
    diverging?: boolean;
    ramp: string[];
    digits?: number;
    // Feste Obergrenze statt des 98. Perzentils. Für eine Verfügbarkeitskarte ist die Skala von
    // vornherein bekannt - eine Stunde hat sechzig Minuten -, und eine Skala, die sich nach den
    // Daten richtet, färbte einen Zeitraum ohne jede Lücke genauso wie einen mit lauter Lücken.
    max?: number;
    // Über vier Wochen gibt es keine Monatsanfänge zu beschriften; dort gehören Tage an die Achse.
    xLabel?: "month" | "day";
  },
): EChartsCoreOption {
  const data: Array<[number, number, number]> = [];
  const present: number[] = [];
  for (let d = 0; d < grid.length; d++) {
    for (let h = 0; h < 24; h++) {
      const v = grid[d]?.[h];
      // null heißt „keine Messdaten" - die Zelle bleibt leer und zeigt die Kartenfläche.
      if (typeof v !== "number") continue;
      data.push([d, h, v]);
      present.push(v);
    }
  }
  const digits = opts.digits ?? 2;
  const bound =
    opts.max ??
    (opts.diverging ? robustMax(present.map(Math.abs)) : robustMax(present.filter((v) => v > 0)));
  const monthStarts = days
    .map((iso, i) => ({ i, d: new Date(`${iso}T12:00:00`) }))
    .filter(({ d }) => d.getDate() === 1);
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      formatter: (params: unknown) => {
        const p = params as { data: [number, number, number] };
        const iso = days[p.data[0]];
        if (!iso) return "";
        const label = new Date(`${iso}T12:00:00`).toLocaleDateString("de-DE", {
          weekday: "short",
          day: "2-digit",
          month: "long",
          year: "numeric",
        });
        const hour = String(p.data[1]).padStart(2, "0");
        return `<div style="color:rgba(255,255,255,.6)">${label}</div><div>${hour}:00 - ${hour}:59</div><div style="margin-top:3px">${de1(p.data[2], digits)} ${opts.unit}</div>`;
      },
    },
    // Die kompakte Variante braucht oben mehr Luft: dort liegt die Skala waagerecht über der
    // Karte, und die obersten Stunden sind gerade die, in denen nächtliche Abrisse stehen.
    grid: { left: 44, right: 16, top: opts.xLabel === "day" ? 52 : 38, bottom: 34 },
    xAxis: {
      type: "category",
      data: days,
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel:
        opts.xLabel === "day"
          ? {
              ...axisText,
              fontSize: 10,
              interval: (i: number) => i % Math.max(1, Math.round(days.length / 10)) === 0,
              formatter: (v: string) => new Date(`${v}T12:00:00`).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" }),
            }
          : {
              ...axisText,
              fontSize: 10,
              interval: (i: number) => monthStarts.some((m) => m.i === i),
              formatter: (_v: string, i: number) => MONTHS[new Date(`${days[i]}T12:00:00`).getMonth()] ?? "",
            },
    },
    yAxis: {
      type: "category",
      data: Array.from({ length: 24 }, (_, h) => String(h)),
      inverse: true, // 00:00 oben, wie ein Tagesplan gelesen wird
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel: { ...axisText, fontSize: 10, interval: (i: number) => i % 6 === 0, formatter: (v: string) => `${String(v).padStart(2, "0")}:00` },
    },
    visualMap: {
      type: "continuous",
      min: opts.diverging ? -bound : 0,
      max: bound,
      calculable: true,
      orient: "horizontal",
      ...(opts.xLabel === "day" ? { itemWidth: 10, itemHeight: 120, top: 2 } : {}),
      // Oben rechts statt unten: unten drängen sich sonst Monatsbeschriftung und Skala, und die
      // Karte selbst verliert die Höhe, die sie zum Lesen braucht.
      right: 8,
      top: 0,
      itemWidth: 12,
      itemHeight: 190,
      // Bei der divergierenden Karte tragen die Pole eine Bedeutung, die nicht in der Farbe allein
      // stehen darf - sie werden benannt.
      text: opts.diverging ? ["Bezug", "Einspeisung"] : undefined,
      textGap: 8,
      textStyle: { color: C.text, fontFamily: MONO, fontSize: 10 },
      formatter: (v: number) => `${de1(v, bound < 5 ? 1 : 0)} ${opts.unit}`,
      inRange: { color: opts.ramp },
    },
    series: [
      {
        type: "heatmap",
        data,
        progressive: 4000,
        emphasis: { itemStyle: { borderColor: "rgba(255,255,255,.85)", borderWidth: 1 } },
      },
    ],
  };
}

/**
 * Alle Leistungen eines Tages übereinander, auf **einer** kW-Achse mit sichtbarer Nulllinie.
 *
 * Dafür gibt es diese Ansicht: die Frage „hat der Speicher aus dem Netz geladen, obwohl die Sonne
 * schien?" lässt sich nur beantworten, wenn Erzeugung, Ladeleistung und Netzbezug im selben Bild und
 * auf derselben Skala liegen. Eine zweite Achse wäre hier ein Fehler - zwei Nulllinien an derselben
 * Stelle im Bild machen jeden Vergleich unmöglich.
 *
 * Vorzeichen wie im Domänenmodell: Netz positiv ist Bezug, negativ Einspeisung; Speicher positiv ist
 * Entladen, negativ Laden. Der Hausverbrauch ist keine eigene Messung, sondern folgt aus der Bilanz
 * `haus = pv + netz + speicher`; er steht mit dabei, weil er erklärt, warum bei laufender PV
 * trotzdem Netzbezug auftreten kann.
 */
export function powerOverlay(rows: Array<Record<string, number | string | null>>): EChartsCoreOption {
  const ts = (r: Record<string, number | string | null>) => new Date(String(r.ts)).getTime();
  const num = (r: Record<string, number | string | null>, k: string) => (typeof r[k] === "number" ? (r[k] as number) : null);
  const house = (r: Record<string, number | string | null>) => {
    const pv = num(r, "pv_power_kw");
    const grid = num(r, "grid_power_kw");
    if (pv === null || grid === null) return null;
    return Math.max(0, pv + grid + (num(r, "battery_power_kw") ?? 0));
  };
  // `color` und nicht nur `lineStyle.color`: die Legende nimmt ihre Farbe aus der Serienfarbe. Ohne
  // sie zeichnet ECharts die Linien richtig und die Legendenpunkte aus seiner eigenen Standardreihe
  // - eine Legende, die andere Farben zeigt als das Bild, ist schlimmer als gar keine.
  const line = (name: string, color: string, pick: (r: Record<string, number | string | null>) => number | null, extra: Record<string, unknown> = {}) => ({
    name,
    type: "line",
    step: "end",
    color,
    data: rows.map((r) => [ts(r), pick(r)]),
    showSymbol: false,
    connectNulls: false,
    lineStyle: { color, width: 2 },
    itemStyle: { color },
    ...extra,
  });
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      axisPointer: { type: "line", lineStyle: { color: C.axis } },
      formatter: (params: unknown) => {
        const ps = params as Array<{ seriesName: string; value: [number, number | null]; color: string }>;
        const p0 = ps[0];
        if (!p0) return "";
        const t = new Date(p0.value[0]).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });
        const body = ps
          .filter((p) => p.value[1] != null)
          .map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${de1(p.value[1] ?? 0, 2)} kW</span></div>`)
          .join("");
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>${body}`;
      },
    },
    legend: {
      bottom: 0,
      left: "center",
      itemWidth: 14,
      itemHeight: 8,
      itemGap: 16,
      icon: "roundRect",
      textStyle: { color: C.text, fontFamily: MONO, fontSize: 11 },
      // Der Ladestand trägt die Farbe des Speichers, weil er dasselbe Gerät ist. Damit hätte er in
      // der Legende auch dessen Fleck, und zwei gleiche Flecken nebeneinander heben die Legende
      // auf. Sein Zeichen sind deshalb zwei Striche: dieselbe Farbe, die Strichelung der Linie.
      data: [
        { name: "PV" },
        { name: "Haus" },
        { name: "Netz" },
        { name: "Netz (Zähler)", icon: "path://M0,0 H6 V3 H0 Z M10,0 H16 V3 H10 Z" },
        { name: "Speicher" },
        { name: "Ladestand %", icon: "path://M0,0 H6 V3 H0 Z M10,0 H16 V3 H10 Z" },
      ],
    },
    /**
     * Das Zeitfenster. Ein Tag hat 1440 Minuten auf gut tausend Bildpunkten: die Strecke, um die es
     * geht, ist oft eine Viertelstunde und damit zehn Pixel breit. Ohne Ausschnitt lässt sich dort
     * nicht ablesen, ob die Erzeugung vor oder nach der Ladung einsetzte - und genau das ist die
     * Frage, für die diese Ansicht da ist.
     *
     * Drei Wege, weil drei Bedürfnisse: das Werkzeug oben zieht ein Fenster auf (die genaueste
     * Geste, wenn man die Strecke schon sieht), der Regler unten schiebt es über den Tag, und Rad
     * beziehungsweise zwei Finger zoomen dort, wo der Zeiger steht. `filterMode: "filter"` lässt
     * die kW-Achse mitgehen: im Ausschnitt einer Nachtstunde ist die Tagesspitze kein Maßstab mehr.
     */
    toolbox: {
      right: 8,
      top: 2,
      itemSize: 13,
      itemGap: 8,
      iconStyle: { borderColor: C.text },
      emphasis: { iconStyle: { borderColor: C.pv } },
      feature: {
        dataZoom: { yAxisIndex: "none", title: { zoom: "Zeitfenster aufziehen", back: "Ein Schritt zurück" }, brushStyle: { color: "rgba(242,169,0,.12)", borderColor: "rgba(242,169,0,.5)" } },
        restore: { title: "Ganzer Tag" },
      },
    },
    dataZoom: [
      // start/end ausdrücklich: ohne sie behielte ECharts beim Tageswechsel den alten Ausschnitt,
      // und der neue Tag erschiene wortlos als Ausschnitt eines Tages, den man nicht mehr sieht.
      { type: "inside", xAxisIndex: 0, filterMode: "filter", start: 0, end: 100, zoomOnMouseWheel: true, moveOnMouseMove: true, moveOnMouseWheel: false },
      {
        type: "slider",
        xAxisIndex: 0,
        filterMode: "filter",
        start: 0,
        end: 100,
        bottom: 30,
        height: 26,
        brushSelect: false,
        borderColor: C.gridline,
        backgroundColor: "rgba(255,255,255,.02)",
        fillerColor: "rgba(127,163,179,.16)",
        handleStyle: { color: C.battery, borderColor: C.battery },
        moveHandleStyle: { color: C.battery },
        dataBackground: { lineStyle: { color: C.axis }, areaStyle: { color: "rgba(255,255,255,.05)" } },
        selectedDataBackground: { lineStyle: { color: C.pv }, areaStyle: { color: "rgba(242,169,0,.14)" } },
        textStyle: { color: C.text, fontFamily: MONO, fontSize: 10 },
        labelFormatter: (v: number) => new Date(v).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" }),
      },
    ],
    // Oben 46 statt 28: die Prozentachse setzt ihre „100" genau auf die obere Gitterkante, und die
    // lag sonst auf derselben Zeile wie die Werkzeuge.
    grid: { left: 52, right: 56, top: 46, bottom: 88 },
    xAxis: {
      type: "time",
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, formatter: (v: number) => new Date(v).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" }) },
    },
    /**
     * Zwei Achsen, und die zweite ist der eigentliche Grund für diese Ansicht.
     *
     * Die Ladeleistung und der Ladestand sind zwei **unabhängige** Messwerte desselben Geräts. Sie
     * müssen zueinander passen: 2,8 kW über anderthalb Stunden sind 4,2 kWh und damit über 80
     * Prozentpunkte in einem 5,1-kWh-Speicher. Steigt der Ladestand dabei nicht, stimmt eine der
     * beiden Reihen nicht, und die Frage „lag es an unseren Daten" ist damit beantwortet, ohne dass
     * jemand raten muss.
     *
     * Die Prozentachse steht fest auf 0 bis 100 und bekommt keine eigenen Gitterlinien: sonst
     * liefen zwei Gitter mit verschiedenen Nullpunkten übereinander, und das war schon einmal der
     * Fehler. Der Ladestand trägt die Farbe des Speichers und ist gestrichelt - es ist dasselbe
     * Gerät, nur seine andere Größe. Eine fünfte Farbe gäbe es hier ohnehin nicht: der
     * Palettenprüfer findet zu jedem Kandidaten ein Paar unter ΔE 15 gegen Speicher oder Haus.
     */
    yAxis: [
      {
        type: "value",
        name: "kW",
        nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] },
        splitLine: { lineStyle: { color: C.gridline } },
        axisLabel: { color: C.text, fontFamily: MONO, fontSize: 11 },
      },
      {
        type: "value",
        name: "%",
        min: 0,
        max: 100,
        // Seitlich in der Mitte statt oben: oben stünde es genau dort, wo die Werkzeuge liegen.
        nameLocation: "middle",
        nameGap: 34,
        nameRotate: 0,
        nameTextStyle: { color: C.text, fontSize: 10 },
        splitLine: { show: false },
        axisLabel: { color: C.text, fontFamily: MONO, fontSize: 11 },
      },
    ],
    series: [
      // Die Nulllinie gehört hervorgehoben: an ihr entscheidet sich Bezug gegen Einspeisung und
      // Laden gegen Entladen. Im Gitter allein geht sie unter.
      {
        ...line("PV", C.pv, (r) => num(r, "pv_power_kw")),
        areaStyle: { color: "rgba(242,169,0,.18)" },
        step: false,
        markLine: { silent: true, symbol: "none", label: { show: false }, lineStyle: { color: "rgba(255,255,255,.4)", width: 1, type: "solid" }, emphasis: { disabled: true }, data: [{ yAxis: 0 }] },
        z: 2,
      },
      line("Haus", C.house, house, { step: false, z: 3 }),
      line("Netz", C.grid, (r) => num(r, "grid_power_kw"), { z: 4 }),
      /**
       * Dieselbe Größe ein zweites Mal, gemessen vom amtlichen Zähler.
       *
       * Sie trägt die Farbe des Netzbezugs und ist gestrichelt, weil sie dieselbe Sache meint und
       * nur von einem anderen Gerät kommt. Eine eigene Farbe wäre hier falsch - der Palettenprüfer
       * findet zu jedem Kandidaten ohnehin ein Paar unter ΔE 15 gegen Speicher oder Haus, und die
       * Legende soll sagen „das ist der Netzwert, nur anders gemessen" und nicht „das ist etwas
       * Neues".
       *
       * Solange der Zähler nichts liefert, ist die Reihe leer und die Linie schlicht nicht da.
       *
       * **Diese eine Reihe verbindet Lücken, und sie zeigt ihre Punkte.** Der Zähler meldet nicht
       * im Minutentakt wie alles andere hier, sondern alle rund fünfzehn Minuten. Zwischen zwei
       * Werten stehen also vierzehn leere Minuten, und mit `connectNulls: false` zeichnet ECharts
       * dann gar nichts: lauter einzelne Punkte ohne Nachbarn, und Punkte sind ausgeschaltet. Die
       * Reihe war vorhanden, vollständig und vollkommen unsichtbar.
       *
       * Die Punkte bleiben deshalb sichtbar - sie sind die Messwerte. Die Linie dazwischen ist
       * gezeichnet und nicht gemessen; gerade und nicht als Treppe, weil eine Treppe behaupten
       * würde, der Wert habe fünfzehn Minuten lang so gestanden.
       */
      {
        ...line("Netz (Zähler)", C.grid, (r) => num(r, "grid_power_meter_kw")),
        step: false,
        connectNulls: true,
        showSymbol: true,
        symbol: "circle",
        symbolSize: 3.5,
        lineStyle: { color: C.grid, width: 1.5, type: "dashed", opacity: 0.85 },
        z: 6,
      },
      line("Speicher", C.battery, (r) => num(r, "battery_power_kw"), { z: 5 }),
      {
        ...line("Ladestand %", C.battery, (r) => {
          const soc = num(r, "battery_soc");
          return soc === null ? null : soc * 100;
        }),
        yAxisIndex: 1,
        step: false,
        lineStyle: { color: C.battery, width: 1.5, type: "dashed", opacity: 0.75 },
        z: 1,
      },
    ],
  };
}
