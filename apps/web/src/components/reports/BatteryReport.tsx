"use client";

import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary, HistoryRow, Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { batteryDayChart, C, donut, stackedBars } from "./charts";
import { CoverageNote, de1, ErrorBanner, eur, KpiGrid, Note, pct, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip } from "./PeriodStrip";
import { isoToday, useMultiPeriod, useReport } from "./useReport";

const CHARGE = [
  { key: "pv_to_battery_kwh" as const, name: "Ladung aus PV", color: C.pv },
  { key: "grid_to_battery_kwh" as const, name: "Ladung aus Netz", color: C.grid },
];
const DISCHARGE = [{ key: "battery_to_house_kwh" as const, name: "Entladung ins Haus", color: C.battery }];

function isoShift(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function BatteryReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod();
  const { data, error } = useReport<EnergySummary>(api.energySummary, period, anchor);
  const strip = useMultiPeriod<EnergySummary>(api.energySummary);
  const [rows, setRows] = useState<HistoryRow[]>([]);
  const dayRange: "today" | "yesterday" | null = period !== "day" ? null : anchor === isoToday() ? "today" : anchor === isoShift(-1) ? "yesterday" : null;
  useEffect(() => {
    if (!dayRange) {
      setRows([]);
      return;
    }
    let alive = true;
    const load = async () => {
      try {
        const h = await api.history(dayRange);
        if (alive) setRows(h.rows as HistoryRow[]);
      } catch {
        if (alive) setRows([]);
      }
    };
    void load();
    const t = setInterval(() => void load(), 60_000);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, [dayRange]);

  const t = data?.totals;
  const cap = data?.meta.battery_capacity_kwh ?? 0;
  const cycles = t && cap > 0 ? t.battery_discharge_kwh / cap : null;
  const pvShare = t && t.battery_charge_kwh > 0 ? t.pv_to_battery_kwh / t.battery_charge_kwh : null;
  const eff = t && t.battery_charge_kwh > 0.5 ? Math.min(1, t.battery_discharge_kwh / t.battery_charge_kwh) : null;
  const chargeOpt = useMemo(() => stackedBars(data?.buckets ?? [], CHARGE), [data]);
  const dischargeOpt = useMemo(() => stackedBars(data?.buckets ?? [], DISCHARGE), [data]);
  const donutOpt = useMemo(() => donut(CHARGE.map((s) => ({ name: s.name, value: t ? t[s.key] : 0, color: s.color })), pct(pvShare), "aus PV geladen"), [t, pvShare]);
  const dayOpt = useMemo(() => batteryDayChart(rows), [rows]);
  const val = (p: Period, f: (s: EnergySummary) => string) => (strip[p] ? f(strip[p] as EnergySummary) : "–");

  return (
    <ReportShell title="Batteriespeicher" kicker={cap > 0 ? `${de1(cap, 1)} kWh · Nutzung und Ersparnis` : "Nutzung und Ersparnis"} period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={6}>
        <Stat label="Geladen" value={de1(t?.battery_charge_kwh)} unit="kWh" tone="amber" hint={t ? `PV ${de1(t.pv_to_battery_kwh)} · Netz ${de1(t.grid_to_battery_kwh)} kWh` : undefined} />
        <Stat label="Entladen" value={de1(t?.battery_discharge_kwh)} unit="kWh" tone="mist" hint={t ? `${de1(t.battery_to_house_kwh)} kWh ins Haus` : undefined} />
        <Stat label="Vollzyklen" value={cycles != null ? de1(cycles, cycles >= 10 ? 0 : 1) : "–"} hint={cap > 0 ? `Entladung ÷ ${de1(cap, 1)} kWh` : "Kapazität unbekannt"} />
        <Stat label="Ersparnis" value={eur(t?.battery_savings_eur)} tone="amber" hint="gegenüber Netzbezug" />
        <Stat label="PV-Anteil Ladung" value={pct(pvShare)} hint={t && t.grid_to_battery_kwh > 0.05 ? `${de1(t.grid_to_battery_kwh)} kWh aus dem Netz geladen` : "keine Netzladung"} />
        <Stat label="Wirkungsgrad" value={pct(eff)} tone="muted" hint="Entladen ÷ Geladen" />
      </KpiGrid>
      <div className="grid gap-4" style={{ gridTemplateColumns: "5fr 3fr 4fr" }}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Ladung nach Herkunft" right="PV · Netz" />
          <div className="min-h-0 flex-1"><EChart option={chargeOpt} /></div>
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Entladung ins Haus" />
          <div className="min-h-0 flex-1"><EChart option={dischargeOpt} /></div>
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Herkunft der Ladung" />
          <div className="min-h-0 flex-1"><EChart option={donutOpt} /></div>
        </Card>
      </div>
      <div className="grid gap-4" style={{ gridTemplateColumns: "8fr 4fr" }}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Ladezustand über den Tag" right={dayRange ? "Minutenwerte · + Entladen, − Laden" : "nur für heute und gestern verfügbar"} />
          {dayRange && rows.length > 0 ? <div className="min-h-0 flex-1"><EChart option={dayOpt} /></div> : <div className="flex flex-1 items-center justify-center"><Note>{dayRange ? "Noch keine Minutenwerte für diesen Tag." : "Der Ladezustandsverlauf wird für heute und gestern gezeigt; für andere Zeiträume gelten die Stundenbilanzen oben."}</Note></div>}
        </Card>
        <PeriodStrip
          title="Speicher im Überblick"
          rows={[
            { label: "Ersparnis", value: (p) => val(p, (s) => eur(s.totals.battery_savings_eur)), tone: "amber" },
            { label: "Entladen · kWh", value: (p) => val(p, (s) => de1(s.totals.battery_discharge_kwh, s.totals.battery_discharge_kwh >= 100 ? 0 : 1)) },
            { label: "Vollzyklen", value: (p) => val(p, (s) => (cap > 0 ? de1(s.totals.battery_discharge_kwh / cap, 1) : "–")) },
            { label: "PV-Anteil", value: (p) => val(p, (s) => pct(s.totals.battery_charge_kwh > 0 ? s.totals.pv_to_battery_kwh / s.totals.battery_charge_kwh : null)) },
          ]}
        />
      </div>
      <CoverageNote meta={data?.meta} extra="Ersparnis: jede ins Haus entladene Kilowattstunde spart den Bezugspreis der Stunde, abzüglich der Einspeisevergütung, die der gespeicherte PV-Strom sonst gebracht hätte." />
    </ReportShell>
  );
}
