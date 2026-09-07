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

/** Einordnung der Taktung. Bewusst zurückhaltend formuliert: das ist ein Hinweis, keine Diagnose. */
const VERDICT = {
  ok: { label: "unauffällig", color: "var(--ok)" },
  watch: { label: "grenzwertig", color: "var(--amber)" },
  short_cycling: { label: "taktet häufig", color: "var(--alert)" },
  unknown: { label: "zu wenig Daten", color: "var(--text-3)" },
} as const;

function verdictOf(v: string | undefined) {
  return VERDICT[(v ?? "unknown") as keyof typeof VERDICT] ?? VERDICT.unknown;
}

function Fact({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex items-baseline justify-between gap-2 border-t border-line-1 py-1">
      <dt className="truncate text-text-3">{k}</dt>
      <dd className="mono m-0 whitespace-nowrap text-text-1">{v}</dd>
    </div>
  );
}

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
  const val = (p: Period, f: (s: HeatReportData) => string) => (strip[p] ? f(strip[p] as HeatReportData) : "-");
  const hasBuffer = (data?.buffer_series.length ?? 0) > 0;
  const cyc = data?.cycling;
  const pq = data?.price_quality;
  const bb = data?.buffer_balance;

  return (
    <ReportShell title="Wärme" kicker="Wärmepumpe · Pufferspeicher · Wärmelastprognose" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={6}>
        <Stat label="Strom Wärmepumpe" value={de1(t?.heat_pump_kwh)} unit="kWh" hint={t ? `${pct(pvShare)} Sonnenstrom` : undefined} />
        <Stat label="Bezahlt" value={eur(t?.heat_pump_cost_eur)} tone="ember" hint={t ? `${de1(t.heat_pump_grid_kwh)} kWh Netz${paidCt != null ? ` · Ø ${de1(paidCt, 1)} ct` : ""}` : undefined} />
        <Stat label="Entgangene Vergütung" value={eur(t?.heat_pump_opportunity_eur)} tone="muted" hint="nicht eingespeister PV-Strom" />
        <Stat label="Wärme geliefert" value={de1(data?.thermal_kwh_est, data && data.thermal_kwh_est >= 100 ? 0 : 1)} unit="kWh" tone="amber" hint={data ? `geschätzt · COP ${de1(data.cop_est, 2)}` : "geschätzt"} />
        <Stat label="Wärmepreis" value={thermalCt != null ? de1(thermalCt, 1) : "-"} unit="ct/kWh" hint="je kWh Wärme, geschätzt" />
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
      <div className="report-row" style={{ "--cols": "4fr 4fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: "14px 18px", gap: 10 }}>
          <CardHead title="Taktung" right={cyc?.covered_hours ? `${de1(cyc.covered_hours, 0)} h bewertet` : undefined} />
          <div className="flex items-baseline gap-3">
            <span className="mono text-[26px] leading-none" style={{ color: verdictOf(cyc?.verdict).color }}>
              {cyc?.starts_per_day != null ? de1(cyc.starts_per_day, 1) : "-"}
            </span>
            <span className="text-[13px] text-text-3">Starts je Tag</span>
            <span className="mono ml-auto text-[11px] uppercase tracking-[.08em]" style={{ color: verdictOf(cyc?.verdict).color }}>
              {verdictOf(cyc?.verdict).label}
            </span>
          </div>
          <dl className="m-0 grid grid-cols-2 gap-x-4 gap-y-1 text-[12px]">
            <Fact k="Läufe" v={cyc ? String(cyc.runs) : "-"} />
            <Fact k="Laufanteil" v={pct(cyc?.duty_cycle)} />
            <Fact k="Lauf im Mittel" v={cyc?.mean_run_min != null ? `${de1(cyc.mean_run_min, 0)} min` : "-"} />
            <Fact k="kürzester Lauf" v={cyc?.shortest_run_min != null ? `${cyc.shortest_run_min} min` : "-"} />
            <Fact k="Pause im Mittel" v={cyc?.mean_pause_min != null ? `${de1(cyc.mean_pause_min, 0)} min` : "-"} />
            <Fact k="unter Mindestlaufzeit" v={cyc?.short_runs != null ? `${cyc.short_runs}×` : "-"} />
          </dl>
          <Note>{cyc?.note_de}</Note>
        </Card>

        <Card style={{ padding: "14px 18px", gap: 10 }}>
          <CardHead title="Lief sie zur richtigen Zeit?" right={pq?.hours_ranked ? `${pq.hours_ranked} Stunden mit Preis` : undefined} />
          <div className="flex items-baseline gap-3">
            <span className="mono text-[26px] leading-none" style={{ color: (pq?.advantage_ct ?? 0) > 0.5 ? "var(--amber)" : (pq?.advantage_ct ?? 0) < -0.5 ? "var(--alert)" : "var(--text-1)" }}>
              {pq?.advantage_ct != null ? `${pq.advantage_ct > 0 ? "−" : "+"}${de1(Math.abs(pq.advantage_ct), 2)}` : "-"}
            </span>
            <span className="text-[13px] text-text-3">ct/kWh gegen den Hausschnitt</span>
          </div>
          <dl className="m-0 grid grid-cols-2 gap-x-4 gap-y-1 text-[12px]">
            <Fact k="WP-Strom aus dem Netz" v={pq?.hp_grid_price_ct != null ? `${de1(pq.hp_grid_price_ct, 2)} ct` : "-"} />
            <Fact k="Haus im Mittel" v={pq?.house_grid_price_ct != null ? `${de1(pq.house_grid_price_ct, 2)} ct` : "-"} />
            <Fact k="im günstigsten Viertel" v={pct(pq?.cheap_share)} />
            <Fact k="aus eigener Erzeugung" v={pct(pq?.pv_share)} />
          </dl>
          <Note>{pq?.note_de}</Note>
        </Card>

        <Card style={{ padding: "14px 18px", gap: 10 }}>
          <CardHead title="Puffer-Energiebilanz" right={period === "day" ? "Ankertag" : "nur in der Tagesansicht"} />
          <div className="flex items-baseline gap-3">
            <span className="mono text-[26px] leading-none" style={{ color: (bb?.gain_without_hp_kwh ?? 0) > 0.2 ? "var(--heat-pump)" : "var(--text-1)" }}>
              {bb?.samples ? de1(bb.gain_without_hp_kwh, 1) : "-"}
            </span>
            <span className="text-[13px] text-text-3">kWh Fremdwärme</span>
          </div>
          <dl className="m-0 grid grid-cols-2 gap-x-4 gap-y-1 text-[12px]">
            <Fact k="Zufuhr gesamt" v={bb?.samples ? `${de1(bb.gain_kwh, 1)} kWh` : "-"} />
            <Fact k="davon mit WP" v={bb?.samples ? `${de1(bb.gain_with_hp_kwh, 1)} kWh` : "-"} />
            <Fact k="Entnahme + Verluste" v={bb?.samples ? `${de1(bb.drop_kwh, 1)} kWh` : "-"} />
            <Fact k="Inhalt jetzt" v={bb?.energy_end_kwh != null ? `${de1(bb.energy_end_kwh, 1)} kWh` : "-"} />
          </dl>
          <Note>{bb?.note_de}</Note>
        </Card>
      </div>
      <CoverageNote meta={data?.summary.meta} extra={data ? `${data.model_note_de} Wärmeverlust ${de1(data.heat_loss_kw_per_k, 2)} kW/K.` : undefined} />
    </ReportShell>
  );
}
