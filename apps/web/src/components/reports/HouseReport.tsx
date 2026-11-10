"use client";

import { useMemo } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary, Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { C, stackedBars } from "./charts";
import { ChartLegend, CoverageNote, de1, ErrorBanner, eur, KpiGrid, pct, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip } from "./PeriodStrip";
import { useMultiPeriod, useReport } from "./useReport";
import { useRole } from "@/lib/live/useRole";

// Die Wärmepumpe in ihrer Farbe, wie auf jeder anderen Seite. Sie war hier hell und der Haushalt
// sandfarben; neben dem Orange der Wärmepumpe wäre Sand bei Deuteranopie dieselbe Farbe
// (ΔE 0,2). Der Rest des Hauses ist deshalb hell: schlechtestes Paar ΔE 18,2 normal und 16,2
// deutan (gemessen 10.11.2026 gegen die Kartenfläche).
const CONSUMERS = [
  { key: "heat_pump_kwh" as const, name: "Wärmepumpe", color: C.heatPump },
  { key: "ev_kwh" as const, name: "Wallbox", color: C.ev },
  { key: "base_kwh" as const, name: "Haushalt", color: C.house },
];
const SOURCES = [
  { key: "pv_direct_kwh" as const, name: "PV direkt", color: C.pv },
  { key: "battery_to_house_kwh" as const, name: "aus Batterie", color: C.battery },
  { key: "grid_to_house_kwh" as const, name: "aus Netz", color: C.grid },
];

export function HouseReport() {
  const role = useRole();
  const { period, anchor, setPeriod, move, today } = usePeriod();
  const { data, error } = useReport<EnergySummary>(api.energySummary, period, anchor);
  const strip = useMultiPeriod<EnergySummary>(api.energySummary, anchor);
  const t = data?.totals;
  const consOpt = useMemo(() => stackedBars(data?.buckets ?? [], CONSUMERS), [data]);
  const srcOpt = useMemo(() => stackedBars(data?.buckets ?? [], SOURCES), [data]);
  const share = (part: number | undefined, whole: number | undefined) => (part != null && whole && whole > 0 ? `${Math.round((part / whole) * 100)} % des Verbrauchs` : undefined);
  const val = (p: Period, f: (s: EnergySummary) => string) => (strip[p] ? f(strip[p] as EnergySummary) : "-");

  return (
    <ReportShell title="Strom" kicker="Verbrauch · Verbraucher · Herkunft" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={6}>
        <Stat label="Verbrauch gesamt" value={de1(t?.house_kwh)} unit="kWh" hint={t?.minutes ? `${Math.round(t.minutes / 60)} h bewertet` : "keine Daten"} />
        <Stat label="Wärmepumpe" value={de1(t?.heat_pump_kwh)} unit="kWh" hint={share(t?.heat_pump_kwh, t?.house_kwh)} />
        <Stat label="Wallbox" value={de1(t?.ev_kwh)} unit="kWh" tone="mist" hint={share(t?.ev_kwh, t?.house_kwh)} />
        <Stat label="Haushalt (Rest)" value={de1(t?.base_kwh)} unit="kWh" tone="muted" hint={share(t?.base_kwh, t?.house_kwh)} />
        <Stat label="Autarkie" value={pct(t?.autarky)} tone="amber" hint={t ? `${de1(t.pv_direct_kwh + t.battery_to_house_kwh)} kWh ohne Netz` : undefined} />
        {/* Kosten sehen alle; nur der Weg zur Rechnungsprüfung bleibt dem Hausherrn. */}
        <Stat
          label="Netzbezug"
          value={eur(t?.import_cost_eur)}
          tone="ember"
          href={role === "owner" ? "/geld/rechnungen" : undefined}
          ariaLabel={role === "owner" ? "Netzbezug - zur Rechnungsprüfung" : undefined}
          hint={t ? `${de1(t.import_kwh)} kWh${role === "owner" ? " · Rechnungen prüfen" : ""}` : undefined}
        />
      </KpiGrid>
      {/* Zwei Fragen nebeneinander, jede als Verlauf. Daneben stand je ein Ring mit denselben
          Anteilen, die schon in den Kacheln und im Verlauf stehen. */}
      <div className="report-row" style={{ "--cols": "1fr 1fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Wer hat verbraucht?" right={<ChartLegend items={CONSUMERS} />} />
          <div className="min-h-0 flex-1"><EChart option={consOpt} /></div>
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Woher kam der Strom?" right={<ChartLegend items={SOURCES} />} />
          <div className="min-h-0 flex-1"><EChart option={srcOpt} /></div>
        </Card>
      </div>
      <PeriodStrip
          anchor={anchor}
        title="Strom im Überblick"
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
