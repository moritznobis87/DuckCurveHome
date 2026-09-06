"use client";

import { useMemo } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary, Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { C, donut, stackedBars } from "./charts";
import { CoverageNote, de1, ErrorBanner, eur, KpiGrid, pct, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip } from "./PeriodStrip";
import { useMultiPeriod, useReport } from "./useReport";

const CONSUMERS = [
  { key: "heat_pump_kwh" as const, name: "Wärmepumpe", color: C.hp },
  { key: "ev_kwh" as const, name: "Wallbox", color: C.ev },
  { key: "base_kwh" as const, name: "Haushalt", color: C.base },
];
const SOURCES = [
  { key: "pv_direct_kwh" as const, name: "PV direkt", color: C.pv },
  { key: "battery_to_house_kwh" as const, name: "aus Batterie", color: C.battery },
  { key: "grid_to_house_kwh" as const, name: "aus Netz", color: C.grid },
];

export function HouseReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod();
  const { data, error } = useReport<EnergySummary>(api.energySummary, period, anchor);
  const strip = useMultiPeriod<EnergySummary>(api.energySummary);
  const t = data?.totals;
  const consOpt = useMemo(() => stackedBars(data?.buckets ?? [], CONSUMERS), [data]);
  const srcOpt = useMemo(() => stackedBars(data?.buckets ?? [], SOURCES), [data]);
  const consDonut = useMemo(() => donut(CONSUMERS.map((s) => ({ name: s.name, value: t ? t[s.key] : 0, color: s.color })), t ? `${de1(t.house_kwh, t.house_kwh >= 100 ? 0 : 1)} kWh` : "–", "Verbrauch"), [t]);
  const srcDonut = useMemo(() => donut(SOURCES.map((s) => ({ name: s.name, value: t ? t[s.key] : 0, color: s.color })), pct(t?.autarky), "Autarkie"), [t]);
  const share = (part: number | undefined, whole: number | undefined) => (part != null && whole && whole > 0 ? `${Math.round((part / whole) * 100)} % des Verbrauchs` : undefined);
  const val = (p: Period, f: (s: EnergySummary) => string) => (strip[p] ? f(strip[p] as EnergySummary) : "–");

  return (
    <ReportShell title="Haus" kicker="Verbrauch · Verbraucher · Herkunft" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={6}>
        <Stat label="Verbrauch gesamt" value={de1(t?.house_kwh)} unit="kWh" hint={t?.minutes ? `${Math.round(t.minutes / 60)} h bewertet` : "keine Daten"} />
        <Stat label="Wärmepumpe" value={de1(t?.heat_pump_kwh)} unit="kWh" hint={share(t?.heat_pump_kwh, t?.house_kwh)} />
        <Stat label="Wallbox" value={de1(t?.ev_kwh)} unit="kWh" tone="mist" hint={share(t?.ev_kwh, t?.house_kwh)} />
        <Stat label="Haushalt (Rest)" value={de1(t?.base_kwh)} unit="kWh" tone="muted" hint={share(t?.base_kwh, t?.house_kwh)} />
        <Stat label="Autarkie" value={pct(t?.autarky)} tone="amber" hint={t ? `${de1(t.pv_direct_kwh + t.battery_to_house_kwh)} kWh ohne Netz` : undefined} />
        <Stat label="Netzbezug" value={eur(t?.import_cost_eur)} tone="ember" hint={t ? `${de1(t.import_kwh)} kWh · Ø ${t.avg_import_price_ct != null ? de1(t.avg_import_price_ct, 1) : "–"} ct/kWh` : undefined} />
      </KpiGrid>
      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Wer hat verbraucht?" right="Wärmepumpe · Wallbox · Haushalt" />
          <div className="min-h-0 flex-1"><EChart option={consOpt} /></div>
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Verbraucher" />
          <div className="min-h-0 flex-1"><EChart option={consDonut} /></div>
        </Card>
      </div>
      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Woher kam der Strom?" right="PV direkt · Batterie · Netz" />
          <div className="min-h-0 flex-1"><EChart option={srcOpt} /></div>
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Herkunft" />
          <div className="min-h-0 flex-1"><EChart option={srcDonut} /></div>
        </Card>
      </div>
      <PeriodStrip
        title="Haus im Überblick"
        rows={[
          { label: "Verbrauch · kWh", value: (p) => val(p, (s) => de1(s.totals.house_kwh, s.totals.house_kwh >= 100 ? 0 : 1)) },
          { label: "Autarkie", value: (p) => val(p, (s) => pct(s.totals.autarky)), tone: "amber" },
          { label: "Netzkosten", value: (p) => val(p, (s) => eur(s.totals.import_cost_eur)), tone: "ember" },
          { label: "Einspeiseerlös", value: (p) => val(p, (s) => eur(s.totals.export_revenue_eur)) },
        ]}
      />
      <CoverageNote meta={data?.meta} extra="Haushalt (Rest) = Hausverbrauch ohne Wärmepumpe und Wallbox. Verbraucher erhalten die Quellen anteilig an ihrer Leistung je Minute." />
    </ReportShell>
  );
}
