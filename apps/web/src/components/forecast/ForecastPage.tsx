"use client";

import { useEffect, useMemo, useState } from "react";
import type { EChartsCoreOption } from "echarts/core";
import { api, ApiError } from "@/lib/api/client";
import type { ForecastDay, ForecastEvaluation } from "@/lib/api/models";
import Link from "next/link";
import { hhmm } from "@/lib/format";
import { Card, CardHead } from "@/components/ui/Card";
import { Pill } from "@/components/ui/Pill";
import { EChart } from "@/components/charts/EChart";
import { dayBounds } from "@/components/charts/DayChart";

const C = {
  pv: "#f2a900",
  ahead: "#e4ecef",
  corrected: "#7fa3b3",
  ember: "#e0533d",
  grid: "rgba(255,255,255,.09)",
  axis: "rgba(255,255,255,.2)",
  text: "rgba(255,255,255,.48)",
  deep: "#082431",
};
const MONO = "'IBM Plex Mono', ui-monospace, monospace";
const REFRESH_MS = 5 * 60_000;

const de = (n: number | null | undefined, digits = 1): string => (n == null ? "–" : n.toFixed(digits).replace(".", ","));
const pct = (n: number | null | undefined): string => (n == null ? "–" : `${n > 0 ? "+" : ""}${de(n, 1)} %`);
const dayLabel = (iso: string): string => new Date(`${iso}T12:00:00`).toLocaleDateString("de-DE", { weekday: "short", day: "2-digit", month: "2-digit" });

const axisText = { color: C.text, fontFamily: MONO, fontSize: 11 };
const tooltip = {
  backgroundColor: C.deep,
  borderColor: "rgba(255,255,255,.14)",
  borderRadius: 3,
  textStyle: { color: "rgba(255,255,255,.92)", fontFamily: MONO, fontSize: 12 },
};

/** Prognose gegen Ist im 15-min-Raster eines Tages. */
function dayOption(day: ForecastDay, nowMs: number, isToday: boolean): EChartsCoreOption {
  const [start] = dayBounds(new Date(`${day.day}T12:00:00Z`).getTime());
  const hx = (iso: string) => (new Date(iso).getTime() - start) / 3600000;
  const actual = day.points.filter((p) => p.actual_kw != null).map((p) => [hx(p.ts), p.actual_kw]);
  const ahead = day.points.filter((p) => p.day_ahead_kw != null).map((p) => [hx(p.ts), p.day_ahead_kw]);
  const corrected = isToday ? day.points.filter((p) => p.corrected_kw != null).map((p) => [hx(p.ts), p.corrected_kw]) : [];
  const maxKw = Math.max(1, ...actual.map((p) => p[1] ?? 0), ...ahead.map((p) => p[1] ?? 0), ...corrected.map((p) => p[1] ?? 0));
  const yMax = Math.ceil((maxKw * 1.1) / 2) * 2;
  const nowLine = isToday ? { symbol: "none", silent: true, lineStyle: { color: C.pv, type: "dashed", width: 1.5 }, label: { show: false }, data: [{ xAxis: hx(new Date(nowMs).toISOString()) }] } : undefined;
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      formatter: (params: unknown) => {
        const ps = params as Array<{ seriesName: string; value: [number, number | null]; color: string }>;
        if (!ps.length) return "";
        const t = hhmm(new Date(start + ps[0]!.value[0] * 3600000));
        const rows = ps
          .filter((p) => p.value[1] != null)
          .map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${de(p.value[1])} kW</span></div>`)
          .join("");
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>${rows}`;
      },
    },
    grid: { left: 48, right: 16, top: 24, bottom: 34 },
    xAxis: {
      type: "value",
      min: 0,
      max: 24,
      interval: 3,
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel: { ...axisText, formatter: (v: number) => `${String(v % 24).padStart(2, "0")}:00` },
    },
    yAxis: { type: "value", min: 0, max: yMax, interval: yMax / 2, name: "kW", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.grid } }, axisLabel: axisText },
    series: [
      { name: "Ist", type: "line", data: actual, showSymbol: false, lineStyle: { color: C.pv, width: 2.5 }, areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1, colorStops: [{ offset: 0, color: "rgba(242,169,0,.3)" }, { offset: 1, color: "rgba(242,169,0,.03)" }] } }, markLine: nowLine, z: 3 },
      { name: "Day-ahead (06:00)", type: "line", data: ahead, showSymbol: false, lineStyle: { color: C.ahead, width: 2, type: [7, 6] }, z: 2 },
      { name: "Korrigiert (jüngster Lauf)", type: "line", data: corrected, showSymbol: false, lineStyle: { color: C.corrected, width: 2, type: [2, 4] }, z: 2 },
    ],
  };
}

function dailyOption(ev: ForecastEvaluation): EChartsCoreOption {
  const days = ev.daily.slice(-14);
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      formatter: (params: unknown) => {
        const ps = params as Array<{ seriesName: string; value: number; color: string; dataIndex: number }>;
        if (!ps.length) return "";
        const d = days[ps[0]!.dataIndex];
        const rows = ps.map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${de(p.value, 1)} kWh</span></div>`).join("");
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${d ? dayLabel(d.day) : ""}</div>${rows}<div style="margin-top:4px;color:rgba(255,255,255,.6)">Abweichung ${d ? pct(d.energy_error_pct) : "–"} · MAE ${d ? de(d.mae_kw, 2) : "–"} kW</div>`;
      },
    },
    grid: { left: 44, right: 12, top: 24, bottom: 30 },
    xAxis: { type: "category", data: days.map((d) => dayLabel(d.day).slice(0, 2)), axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10 } },
    yAxis: { type: "value", name: "kWh", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.grid } }, axisLabel: axisText, splitNumber: 3 },
    series: [
      { name: "Prognose", type: "bar", data: days.map((d) => d.energy_forecast_kwh), itemStyle: { color: "rgba(228,236,239,.55)", borderRadius: [2, 2, 0, 0] }, barGap: "10%", barCategoryGap: "35%" },
      { name: "Ist", type: "bar", data: days.map((d) => d.energy_actual_kwh), itemStyle: { color: C.pv, borderRadius: [2, 2, 0, 0] } },
    ],
  };
}

function horizonOption(ev: ForecastEvaluation): EChartsCoreOption {
  const hs = ev.horizons;
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      formatter: (params: unknown) => {
        const ps = params as Array<{ dataIndex: number }>;
        const h = hs[ps[0]?.dataIndex ?? 0];
        if (!h) return "";
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${h.label_de}</div>MAE ${de(h.score.mae_kw, 2)} kW · Bias ${de(h.score.bias_kw, 2)} kW · n = ${h.score.n}`;
      },
    },
    grid: { left: 44, right: 12, top: 24, bottom: 30 },
    xAxis: { type: "category", data: hs.map((h) => h.key), axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: axisText },
    yAxis: { type: "value", name: "kW", nameTextStyle: { color: C.text, fontSize: 10, align: "right", padding: [0, 6, 0, 0] }, splitLine: { lineStyle: { color: C.grid } }, axisLabel: axisText, splitNumber: 3, min: 0 },
    series: [
      { name: "MAE", type: "bar", data: hs.map((h) => h.score.mae_kw), itemStyle: { color: C.corrected, borderRadius: [2, 2, 0, 0] }, barCategoryGap: "45%" },
      { name: "Bias", type: "bar", data: hs.map((h) => Math.abs(h.score.bias_kw)), itemStyle: { color: "rgba(228,236,239,.4)", borderRadius: [2, 2, 0, 0] } },
    ],
  };
}

function factorOption(ev: ForecastEvaluation): EChartsCoreOption {
  // Abweichung von 1,00 in Prozentpunkten: Balken stehen auf der Nulllinie, nicht auf dem Achsenminimum
  const bins = ev.corrector.bins ?? [];
  const dev = (x: number | null | undefined) => (x == null ? null : Math.round((x - 1) * 1000) / 10);
  const vals = bins.flatMap((b) => [dev(b.factor) ?? 0, dev(b.previous) ?? 0, dev(b.last_ratio) ?? 0]);
  const span = Math.max(10, Math.ceil((Math.max(...vals.map(Math.abs)) * 1.15) / 10) * 10);
  const fmt = (v: number) => `${v > 0 ? "+" : ""}${v.toFixed(0)} %`;
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      formatter: (params: unknown) => {
        const ps = params as Array<{ dataIndex: number }>;
        const b = bins[ps[0]?.dataIndex ?? 0];
        if (!b) return "";
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">Sonnenhöhe ${b.label_de}</div>Faktor ${de(b.factor, 3)} · gestern ${de(b.previous, 3)}<br/>letztes Ist/Prognose ${b.last_ratio == null ? "–" : de(b.last_ratio, 3)} · ${b.days} Lerntage`;
      },
    },
    grid: { left: 52, right: 12, top: 24, bottom: 30 },
    xAxis: { type: "category", data: bins.map((b) => b.label_de), axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, axisLabel: { ...axisText, fontSize: 10 } },
    yAxis: { type: "value", min: -span, max: span, interval: span / 2, splitLine: { lineStyle: { color: C.grid } }, axisLabel: { ...axisText, formatter: fmt } },
    series: [
      {
        name: "Faktor",
        type: "bar",
        data: bins.map((b) => ({ value: dev(b.factor), itemStyle: { color: b.factor < 1 ? C.ember : C.pv } })),
        barCategoryGap: "45%",
        itemStyle: { borderRadius: 2 },
        markLine: { silent: true, symbol: "none", lineStyle: { color: "rgba(255,255,255,.55)", type: "solid", width: 1 }, label: { show: false }, data: [{ yAxis: 0 }] },
        z: 2,
      },
      { name: "Gestern", type: "scatter", data: bins.map((b) => dev(b.previous)), symbol: "diamond", symbolSize: 9, itemStyle: { color: C.ahead }, z: 3 },
      { name: "Letztes Ist/Prognose", type: "scatter", data: bins.map((b) => dev(b.last_ratio)), symbol: "circle", symbolSize: 7, itemStyle: { color: C.corrected }, z: 3 },
    ],
  };
}

function Stat({ label, value, unit, tone }: { label: string; value: string; unit?: string; tone?: "amber" | "ember" | "muted" }) {
  const color = tone === "amber" ? "var(--amber)" : tone === "ember" ? "var(--alert)" : tone === "muted" ? "var(--text-3)" : "var(--text-1)";
  return (
    <Card style={{ padding: "14px 18px", gap: 6 }}>
      <span className="kicker" style={{ fontSize: 11 }}>{label}</span>
      <span className="mono text-[28px] leading-none tracking-[-.02em]" style={{ color }}>
        {value}
        {unit ? <span className="ml-1.5 text-[13px] text-text-3" style={{ fontFamily: "var(--font-sans)" }}>{unit}</span> : null}
      </span>
    </Card>
  );
}

function Legend({ color, label, dashed }: { color: string; label: string; dashed?: "dash" | "dot" }) {
  return (
    <span className="flex items-center gap-2 text-[12px] text-text-2">
      <span className="inline-block w-[18px]" style={{ borderTop: `2px ${dashed === "dash" ? "dashed" : dashed === "dot" ? "dotted" : "solid"} ${color}` }} />
      {label}
    </span>
  );
}

export function ForecastPage() {
  const [ev, setEv] = useState<ForecastEvaluation | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [range, setRange] = useState<"today" | "yesterday">("today");
  const [nowMs, setNowMs] = useState(() => Date.now());

  useEffect(() => {
    let alive = true;
    const load = async () => {
      try {
        const r = await api.forecastEvaluation();
        if (!alive) return;
        setEv(r);
        setNowMs(new Date(r.generated_at).getTime());
        setError(null);
      } catch (e) {
        if (alive) setError(e instanceof ApiError ? e.message : "Auswertung nicht verfügbar.");
      }
    };
    void load();
    const t = setInterval(() => void load(), REFRESH_MS);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, []);

  const day = range === "today" ? ev?.today : ev?.yesterday;
  const dayOpt = useMemo(() => (day ? dayOption(day, nowMs, range === "today") : null), [day, nowMs, range]);
  const dailyOpt = useMemo(() => (ev ? dailyOption(ev) : null), [ev]);
  const horizonOpt = useMemo(() => (ev ? horizonOption(ev) : null), [ev]);
  const factorOpt = useMemo(() => (ev ? factorOption(ev) : null), [ev]);

  const todayScore = ev?.today.score ?? null;
  const recent = ev?.daily.slice(-7) ?? [];
  const mae7 = ev?.sources[0]?.mae_7d_kw ?? null;
  const bias7 = recent.length ? recent.reduce((a, d) => a + d.bias_kw, 0) / recent.length : null;
  const hits = recent.filter((d) => d.energy_error_pct != null && Math.abs(d.energy_error_pct) <= 15).length;
  const st = ev?.corrector;

  return (
    <main className="dashboard-bg flex min-h-[100dvh] flex-col gap-4 p-5 text-text-1">
      <header className="flex h-14 shrink-0 items-center justify-between rounded-[3px] border border-line-2 px-5" style={{ background: "var(--surface-glass)", backdropFilter: "blur(18px)" }}>
        <div className="flex items-center gap-5">
          <Link href="/" className="kicker whitespace-nowrap" style={{ fontSize: 12 }}>← Dashboard</Link>
          <div className="flex items-baseline gap-2.5">
            <span className="text-[17px] font-semibold tracking-[-.02em]">Prognose</span>
            <span className="kicker whitespace-nowrap" style={{ fontSize: 12 }}>Auswertung und Lernen</span>
          </div>
        </div>
        <div className="flex items-center gap-4">
          {ev ? <span className="mono hidden whitespace-nowrap text-[12px] uppercase tracking-[.1em] text-text-3 min-[1400px]:inline">Stand {hhmm(ev.generated_at)} · {ev.sources[0]?.label_de}</span> : null}
          {ev ? <span className="whitespace-nowrap"><Pill tone={ev.correction_active ? "amber" : "neutral"}>{ev.stage_de}{ev.correction_active ? " · aktiv" : " · lernt"}</Pill></span> : null}
        </div>
      </header>

      {error ? (
        <div className="mono rounded-[3px] border px-4 py-3 text-[12px] uppercase tracking-[.1em]" style={{ borderColor: "rgba(224,83,61,.4)", background: "rgba(224,83,61,.12)", color: "var(--alert)" }}>
          {error}
        </div>
      ) : null}

      <div className="grid gap-4" style={{ gridTemplateColumns: "repeat(5, minmax(0, 1fr))" }}>
        <Stat label="Heute · Ist bis jetzt" value={todayScore ? de(todayScore.energy_actual_kwh, 1) : "–"} unit="kWh" tone="amber" />
        <Stat label="Heute · Day-ahead bis jetzt" value={todayScore ? de(todayScore.energy_forecast_kwh, 1) : "–"} unit="kWh" />
        <Stat label="Heute · Abweichung" value={todayScore ? pct(todayScore.energy_error_pct) : "–"} tone={todayScore?.energy_error_pct != null && Math.abs(todayScore.energy_error_pct) > 15 ? "ember" : undefined} />
        <Stat label="MAE · 7 Tage" value={mae7 == null ? "–" : de(mae7, 2)} unit="kW" />
        <Stat label="Tage innerhalb ±15 %" value={recent.length ? `${hits} / ${recent.length}` : "–"} tone="muted" />
      </div>

      <Card style={{ padding: 16, height: 340 }}>
        <div className="flex items-center justify-between">
          <div className="flex items-baseline gap-5 overflow-hidden">
            <h2 className="kicker m-0 whitespace-nowrap">{range === "today" ? "Heute" : "Gestern"} · Prognose gegen Ist</h2>
            <div className="flex gap-5 whitespace-nowrap">
              <Legend color={C.pv} label="Ist (15-min-Mittel)" />
              <Legend color={C.ahead} label={`Day-ahead${day?.issued_at ? ` · ausgegeben ${hhmm(day.issued_at)}` : ""}`} dashed="dash" />
              {range === "today" ? <Legend color={C.corrected} label="Jüngster Lauf, korrigiert" dashed="dot" /> : null}
            </div>
          </div>
          <div className="flex items-center gap-4">
            {day?.score ? (
              <span className="mono hidden whitespace-nowrap text-[12px] text-text-3 min-[1400px]:inline">
                MAE {de(day.score.mae_kw, 2)} kW · Bias {de(day.score.bias_kw, 2)} kW · {pct(day.score.energy_error_pct)}
              </span>
            ) : null}
            <div className="flex shrink-0 overflow-hidden rounded-[3px] border border-line-2">
              {(["today", "yesterday"] as const).map((v) => (
                <button key={v} onClick={() => setRange(v)} className="mono px-4 py-2 text-[12px] uppercase tracking-[.08em]" style={{ background: range === v ? "var(--amber)" : "transparent", color: range === v ? "var(--petrol)" : "var(--text-3)" }}>
                  {v === "today" ? "Heute" : "Gestern"}
                </button>
              ))}
            </div>
          </div>
        </div>
        <div className="mt-1 min-h-0 flex-1">{dayOpt ? <EChart key={range} option={dayOpt} /> : null}</div>
      </Card>

      <div className="grid gap-4" style={{ gridTemplateColumns: "5fr 3fr 4fr" }}>
        <Card style={{ padding: 16, height: 280 }}>
          <div className="flex items-baseline justify-between">
            <h2 className="kicker m-0">Tagesenergie · letzte {Math.min(14, ev?.daily.length ?? 0)} Tage</h2>
            <div className="flex gap-4">
              <Legend color="rgba(228,236,239,.55)" label="Day-ahead" />
              <Legend color={C.pv} label="Ist" />
            </div>
          </div>
          <div className="mt-1 min-h-0 flex-1">{dailyOpt ? <EChart option={dailyOpt} /> : null}</div>
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Fehler nach Horizont" right="gestern und heute, alle Läufe" />
          <div className="mt-1 min-h-0 flex-1">{horizonOpt ? <EChart option={horizonOpt} /> : null}</div>
          <div className="flex gap-4">
            <Legend color={C.corrected} label="MAE" />
            <Legend color="rgba(228,236,239,.4)" label="|Bias|" />
          </div>
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Korrekturfaktoren nach Sonnenhöhe" right={st ? `${st.days_learned} Lerntage · Halbwertszeit ${de(st.half_life_days, 0)} d` : undefined} />
          <div className="mt-1 min-h-0 flex-1">{factorOpt ? <EChart option={factorOpt} /> : null}</div>
          <div className="flex gap-4 text-[12px] text-text-2">
            <span className="flex items-center gap-2"><span className="inline-block h-3 w-3 rounded-[2px]" style={{ background: C.pv }} /> Faktor heute</span>
            <span className="flex items-center gap-2"><span className="inline-block h-2.5 w-2.5 rotate-45" style={{ background: C.ahead }} /> gestern</span>
            <span className="flex items-center gap-2"><span className="inline-block h-2.5 w-2.5 rounded-full" style={{ background: C.corrected }} /> letztes Ist/Prognose</span>
          </div>
        </Card>
      </div>

      <div className="grid gap-4" style={{ gridTemplateColumns: "7fr 5fr" }}>
        <Card accent style={{ padding: 18 }}>
          <CardHead title="Was sich für die nächste Prognose ändert" right={st?.updated_on ? `Tagesabschluss ${dayLabel(st.updated_on)}` : "noch kein Tagesabschluss"} />
          <ol className="m-0 mt-3 flex list-none flex-col gap-2 p-0">
            {(ev?.next_changes_de ?? []).map((line, i) => (
              <li key={i} className="flex gap-3 text-[14px] leading-[1.5] text-text-1">
                <span className="mono mt-[3px] shrink-0 text-[11px] text-text-3">{String(i + 1).padStart(2, "0")}</span>
                <span>{line}</span>
              </li>
            ))}
          </ol>
          <div className="mt-4 flex flex-col gap-1 border-t border-line-1 pt-3">
            {(ev?.notes_de ?? []).map((n, i) => (
              <span key={i} className="text-[12px] leading-[1.5] text-text-3">{n}</span>
            ))}
          </div>
        </Card>
        <Card style={{ padding: 18 }}>
          <CardHead title="Quellen und Gewichte" right={`Ist/Prognose gesamt ${st ? de(st.k_global, 2) : "–"}`} />
          <table className="mt-3 w-full border-collapse text-[13px]">
            <thead>
              <tr className="kicker text-left" style={{ fontSize: 11 }}>
                <th className="pb-2 font-normal">Quelle</th>
                <th className="pb-2 text-right font-normal">Gewicht</th>
                <th className="pb-2 text-right font-normal">MAE 7 d</th>
                <th className="pb-2 text-right font-normal">Status</th>
              </tr>
            </thead>
            <tbody>
              {(ev?.sources ?? []).map((s) => (
                <tr key={s.name} className="border-t border-line-1">
                  <td className="py-2 text-text-1">{s.label_de}<div className="mono text-[11px] text-text-3">{s.name}</div></td>
                  <td className="mono py-2 text-right text-text-1">{de(s.weight, 2)}</td>
                  <td className="mono py-2 text-right text-text-1">{s.mae_7d_kw == null ? "–" : `${de(s.mae_7d_kw, 2)} kW`}</td>
                  <td className="mono py-2 text-right text-[11px] uppercase tracking-[.1em]" style={{ color: s.active ? "var(--amber)" : "var(--text-3)" }}>{s.active ? "aktiv" : "aus"}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="mt-4 text-[12px] leading-[1.55] text-text-3">
            Weitere Quellen (forecast.solar, Solcast aus Home Assistant) kommen mit der Bridge dazu und werden hier nach ihrer Güte gewichtet. Bias 7 Tage: {bias7 == null ? "–" : `${de(bias7, 2)} kW`} · aufbewahrte Läufe: {ev?.runs_kept ?? "–"}.
          </p>
        </Card>
      </div>
    </main>
  );
}
