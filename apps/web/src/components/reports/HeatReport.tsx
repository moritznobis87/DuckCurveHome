"use client";

import { useMemo } from "react";
import { api } from "@/lib/api/client";
import type { HeatReport as HeatReportData, Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { bufferChart, C, heatForecastChart, stackedBars } from "./charts";
import { CoverageNote, de1, ErrorBanner, eur, KpiGrid, Note, pct, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip } from "./PeriodStrip";
import { useMultiPeriod, useReport } from "./useReport";

const SOURCES = [
  { key: "heat_pump_pv_kwh" as const, name: "aus PV", color: C.pv },
  { key: "heat_pump_battery_kwh" as const, name: "aus Batterie", color: C.battery },
  { key: "heat_pump_grid_kwh" as const, name: "aus Netz", color: C.grid },
];

export function HeatReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod();
  const { data, error } = useReport<HeatReportData>(api.energyHeat, period, anchor);
  const strip = useMultiPeriod<HeatReportData>(api.energyHeat);
  const t = data?.summary.totals;
  const pvShare = t && t.heat_pump_kwh > 0 ? (t.heat_pump_pv_kwh + t.heat_pump_battery_kwh) / t.heat_pump_kwh : null;
  const paidCt = t && t.heat_pump_grid_kwh > 0.01 ? (t.heat_pump_cost_eur / t.heat_pump_grid_kwh) * 100 : null;
  const thermalCt = data && data.thermal_kwh_est > 0.01 ? ((t!.heat_pump_cost_eur + t!.heat_pump_opportunity_eur) / data.thermal_kwh_est) * 100 : null;
  const barsOpt = useMemo(() => stackedBars(data?.summary.buckets ?? [], SOURCES), [data]);
  const fcOpt = useMemo(() => heatForecastChart(data?.forecast ?? []), [data]);
  const bufOpt = useMemo(() => bufferChart(data?.buffer_series ?? []), [data]);
  const val = (p: Period, f: (s: HeatReportData) => string) => (strip[p] ? f(strip[p] as HeatReportData) : "–");
  const hasBuffer = (data?.buffer_series.length ?? 0) > 0;

  return (
    <ReportShell title="Wärme" kicker="Wärmepumpe · Pufferspeicher · Wärmelastprognose" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={6}>
        <Stat label="Strom Wärmepumpe" value={de1(t?.heat_pump_kwh)} unit="kWh" hint={t ? `${pct(pvShare)} Sonnenstrom` : undefined} />
        <Stat label="Bezahlt" value={eur(t?.heat_pump_cost_eur)} tone="ember" hint={t ? `${de1(t.heat_pump_grid_kwh)} kWh Netz${paidCt != null ? ` · Ø ${de1(paidCt, 1)} ct` : ""}` : undefined} />
        <Stat label="Entgangene Vergütung" value={eur(t?.heat_pump_opportunity_eur)} tone="muted" hint="nicht eingespeister PV-Strom" />
        <Stat label="Wärme geliefert" value={de1(data?.thermal_kwh_est, data && data.thermal_kwh_est >= 100 ? 0 : 1)} unit="kWh" tone="amber" hint={data ? `geschätzt · COP ${de1(data.cop_est, 2)}` : "geschätzt"} />
        <Stat label="Wärmepreis" value={thermalCt != null ? de1(thermalCt, 1) : "–"} unit="ct/kWh" hint="je kWh Wärme, geschätzt" />
        <Stat label="Prognose 24 h" value={de1(data?.forecast_electric_kwh_24h)} unit="kWh" tone="mist" hint={data ? `Strom für ${de1(data.forecast_thermal_kwh_24h, 0)} kWh Wärme` : undefined} />
      </KpiGrid>
      <div className="report-row" style={{ "--cols": "7fr 5fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Wärmelastprognose 48 h" right="Heizung + Warmwasser thermisch · Strombedarf · Außentemperatur" />
          {data?.forecast.length ? <div className="min-h-0 flex-1"><EChart option={fcOpt} /></div> : <div className="flex flex-1 items-center justify-center"><Note>Keine Wetterprognose verfügbar.</Note></div>}
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Strom der Wärmepumpe nach Herkunft" right="PV · Batterie · Netz" />
          <div className="min-h-0 flex-1"><EChart option={barsOpt} /></div>
        </Card>
      </div>
      <div className="report-row" style={{ "--cols": "7fr 5fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Pufferspeicher und Wärmepumpe" right={period === "day" ? "Temperaturen in vier Höhen · WP-Leistung" : "Verlauf nur in der Tagesansicht"} />
          {period === "day" && hasBuffer ? <div className="min-h-0 flex-1"><EChart option={bufOpt} /></div> : <div className="flex flex-1 items-center justify-center"><Note>{period === "day" ? "Keine Puffertemperaturen für diesen Tag aufgezeichnet." : "Wechseln Sie auf „Tag“, um Temperaturen und Leistung im Verlauf zu sehen."}</Note></div>}
        </Card>
        <PeriodStrip
          title="Wärmepumpe im Überblick"
          rows={[
            { label: "Bezahlt", value: (p) => val(p, (s) => eur(s.summary.totals.heat_pump_cost_eur)), tone: "ember" },
            { label: "Strom · kWh", value: (p) => val(p, (s) => de1(s.summary.totals.heat_pump_kwh, s.summary.totals.heat_pump_kwh >= 100 ? 0 : 1)) },
            { label: "Wärme · kWh (geschätzt)", value: (p) => val(p, (s) => de1(s.thermal_kwh_est, 0)), tone: "amber" },
            { label: "Sonnenanteil", value: (p) => val(p, (s) => pct(s.summary.totals.heat_pump_kwh > 0 ? (s.summary.totals.heat_pump_pv_kwh + s.summary.totals.heat_pump_battery_kwh) / s.summary.totals.heat_pump_kwh : null)) },
          ]}
        />
      </div>
      <CoverageNote meta={data?.summary.meta} extra={data ? `${data.model_note_de} Wärmeverlust ${de1(data.heat_loss_kw_per_k, 2)} kW/K.` : undefined} />
    </ReportShell>
  );
}
