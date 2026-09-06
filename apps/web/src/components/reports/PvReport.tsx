"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary, HistoryRow, Period, Plan } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { dayBounds } from "@/components/charts/DayChart";
import { C, donut, pvForecastChart, stackedBars } from "./charts";
import { CoverageNote, de1, ErrorBanner, eur, KpiGrid, pct, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip } from "./PeriodStrip";
import { isoToday, useMultiPeriod, useReport } from "./useReport";

const SERIES = [
  { key: "pv_direct_kwh" as const, name: "Direkt genutzt", color: C.pv },
  { key: "pv_to_battery_kwh" as const, name: "In Batterie", color: C.battery },
  { key: "export_kwh" as const, name: "Eingespeist", color: C.export },
];

/** Prognosesummen heute/morgen aus den Planintervallen (Intervallbreite aus dem Zeitraster). */
function forecastKwh(plan: Plan | null, dayStart: number): { today: number; tomorrow: number; points: Array<{ ts: number; kw: number }> } {
  if (!plan || plan.intervals.length < 2) return { today: plan?.pv_forecast_today_kwh ?? 0, tomorrow: 0, points: [] };
  const pts = plan.intervals.map((i) => ({ ts: new Date(i.ts).getTime(), kw: i.expected_pv_kw }));
  const stepH = Math.max(1 / 60, (pts[1]!.ts - pts[0]!.ts) / 3600_000);
  const dayEnd = dayStart + 24 * 3600_000;
  let today = 0;
  let tomorrow = 0;
  for (const p of pts) {
    if (p.ts >= dayStart && p.ts < dayEnd) today += p.kw * stepH;
    else if (p.ts >= dayEnd && p.ts < dayEnd + 24 * 3600_000) tomorrow += p.kw * stepH;
  }
  return { today: plan.pv_forecast_today_kwh || today, tomorrow, points: pts };
}

export function PvReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod();
  const { data, error } = useReport<EnergySummary>(api.energySummary, period, anchor);
  const strip = useMultiPeriod<EnergySummary>(api.energySummary);
  const [plan, setPlan] = useState<Plan | null>(null);
  const [rows, setRows] = useState<HistoryRow[]>([]);
  const [nowMs, setNowMs] = useState(() => Date.now());
  useEffect(() => {
    let alive = true;
    const load = async () => {
      const [p, h] = await Promise.allSettled([api.plan(), api.history("today")]);
      if (!alive) return;
      if (p.status === "fulfilled") setPlan(p.value);
      if (h.status === "fulfilled") setRows(h.value.rows as HistoryRow[]);
      setNowMs(Date.now());
    };
    void load();
    const t = setInterval(() => void load(), 5 * 60_000);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, []);

  const t = data?.totals;
  const [dayStart] = dayBounds(nowMs);
  const fc = useMemo(() => forecastKwh(plan, dayStart), [plan, dayStart]);
  const barsOpt = useMemo(() => stackedBars(data?.buckets ?? [], SERIES), [data]);
  const donutOpt = useMemo(
    () => donut(SERIES.map((s) => ({ name: s.name, value: t ? t[s.key] : 0, color: s.color })), t ? `${de1(t.pv_kwh, t.pv_kwh >= 100 ? 0 : 1)} kWh` : "–", "Erzeugung"),
    [t],
  );
  const fcOpt = useMemo(() => {
    const actual = rows.map((r) => ({ ts: new Date(String(r.ts)).getTime(), kw: typeof r.pv_power_kw === "number" ? (r.pv_power_kw as number) : null }));
    return pvForecastChart(actual, fc.points, dayStart, nowMs);
  }, [rows, fc, dayStart, nowMs]);
  const isToday = anchor === isoToday();
  const val = (p: Period, f: (s: EnergySummary) => string) => (strip[p] ? f(strip[p] as EnergySummary) : "–");

  return (
    <ReportShell title="Photovoltaik" kicker="Erzeugung · Verwendung · Prognose" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={6}>
        <Stat label="Erzeugung" value={de1(t?.pv_kwh)} unit="kWh" tone="amber" hint={t?.minutes ? `${Math.round(t.minutes / 60)} h bewertet` : "keine Daten"} />
        <Stat label="Eigenverbrauch" value={pct(t?.self_consumption_share)} hint={t ? `${de1(t.pv_direct_kwh + t.pv_to_battery_kwh)} kWh selbst genutzt` : undefined} />
        <Stat label="Eingespeist" value={de1(t?.export_kwh)} unit="kWh" tone="mist" hint={t ? `Erlös ${eur(t.export_revenue_eur)} bei ${de1(data?.meta.feed_in_ct_kwh, 1)} ct` : undefined} />
        <Stat label="Ersparnis direkt" value={eur(t?.pv_direct_savings_eur)} tone="amber" hint="gegenüber Netzbezug" />
        <Stat label="Prognose heute" value={de1(fc.today)} unit="kWh" hint={isToday && t ? `${de1(t.pv_kwh)} kWh bisher erzeugt` : "Tagesprognose"} />
        <Stat label="Prognose morgen" value={fc.tomorrow > 0 ? de1(fc.tomorrow) : "–"} unit="kWh" hint={fc.tomorrow > 0 ? "aus Wetterprognose" : "noch nicht verfügbar"} />
      </KpiGrid>
      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 300 }}>
          <CardHead title="Erzeugung und Verwendung" right="direkt genutzt · in Batterie · eingespeist" />
          <div className="min-h-0 flex-1"><EChart option={barsOpt} /></div>
        </Card>
        <Card style={{ padding: 16, height: 300 }}>
          <CardHead title="Wohin ging der Strom?" />
          <div className="min-h-0 flex-1"><EChart option={donutOpt} /></div>
        </Card>
      </div>
      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Heute und morgen" right={<Link href="/prognose" className="text-amber">Prognosegüte →</Link>} />
          <div className="min-h-0 flex-1"><EChart option={fcOpt} /></div>
        </Card>
        <PeriodStrip
          title="PV im Überblick"
          rows={[
            { label: "Erzeugt · kWh", value: (p) => val(p, (s) => de1(s.totals.pv_kwh, s.totals.pv_kwh >= 100 ? 0 : 1)), tone: "amber" },
            { label: "Eigenverbrauch", value: (p) => val(p, (s) => pct(s.totals.self_consumption_share)) },
            { label: "Einspeiseerlös", value: (p) => val(p, (s) => eur(s.totals.export_revenue_eur)) },
            { label: "Ersparnis", value: (p) => val(p, (s) => eur(s.totals.pv_direct_savings_eur + s.totals.battery_savings_eur)) },
          ]}
        />
      </div>
      <CoverageNote meta={data?.meta} extra="Ersparnis im Überblick = PV direkt plus Batterieentladung, jeweils gegen den Strompreis der Stunde." />
    </ReportShell>
  );
}
