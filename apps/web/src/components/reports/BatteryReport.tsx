"use client";

import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary, HistoryRow, Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { batteryDayChart, C, donut, stackedBars } from "./charts";
import { CoverageNote, de1, ErrorBanner, eur, KpiGrid, Note, pct, ReportShell, usePeriod } from "./ReportShell";
import { BatteryControl } from "./BatteryControl";
import { PeriodStrip } from "./PeriodStrip";
import { isoToday, useMultiPeriod, useReport } from "./useReport";

const CHARGE = [
  { key: "pv_to_battery_kwh" as const, name: "Ladung aus PV", color: C.pv },
  { key: "grid_to_battery_kwh" as const, name: "Ladung aus Netz", color: C.grid },
];
const DISCHARGE = [{ key: "battery_to_house_kwh" as const, name: "Entladung ins Haus", color: C.battery }];

/**
 * Geladene und entladene Energie aus dem Ladestandsverlauf, unabhängig von der Leistungsmessung.
 *
 * Summiert werden die Anstiege und die Abstiege des Ladestands, mal Kapazität. Das ist die Energie
 * *im* Speicher; an den Klemmen ist die Ladung etwas größer und die Entladung etwas kleiner, weil
 * die Verluste dazwischenliegen. Für die Frage „stimmt die Größenordnung?" reicht das genau.
 */
export function socEnergy(rows: HistoryRow[], capacityKwh: number): { charge: number; discharge: number; samples: number } | null {
  if (capacityKwh <= 0) return null;
  const soc = rows.map((r) => (typeof r.battery_soc === "number" ? r.battery_soc : null)).filter((v): v is number => v !== null);
  if (soc.length < 10) return null;
  let up = 0;
  let down = 0;
  for (let i = 1; i < soc.length; i++) {
    const d = soc[i]! - soc[i - 1]!;
    if (d > 0) up += d;
    else down -= d;
  }
  return { charge: up * capacityKwh, discharge: down * capacityKwh, samples: soc.length };
}

/** Ortszeit-Mitternacht des Ankertags und des Folgetags - die Grenzen, die der Nutzer meint. */
function dayBounds(anchor: string): [Date, Date] {
  const start = new Date(`${anchor}T00:00:00`);
  const end = new Date(start);
  end.setDate(end.getDate() + 1);
  return [start, end];
}

export function BatteryReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod();
  const { data, error } = useReport<EnergySummary>(api.energySummary, period, anchor);
  const strip = useMultiPeriod<EnergySummary>(api.energySummary);
  const [rows, setRows] = useState<HistoryRow[]>([]);
  const isDay = period === "day";
  const isToday = anchor === isoToday();
  useEffect(() => {
    if (!isDay) {
      setRows([]);
      return;
    }
    let alive = true;
    const load = async () => {
      try {
        const [start, end] = dayBounds(anchor);
        const h = isToday ? await api.history("today") : await api.historyDay(start, end);
        if (alive) setRows(h.rows as HistoryRow[]);
      } catch {
        if (alive) setRows([]);
      }
    };
    void load();
    // Nur der laufende Tag wächst noch; ein vergangener Tag wird einmal geladen.
    if (!isToday) return () => { alive = false; };
    const t = setInterval(() => void load(), 60_000);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, [isDay, isToday, anchor]);

  const t = data?.totals;
  const cap = data?.meta.battery_capacity_kwh ?? 0;
  // Gegenprobe aus dem Ladestand: was der Speicher laut seinem eigenen Füllstand abgegeben hat.
  // Zwei unabhängige Wege zur selben Zahl - die Leistungsmessung integriert über die Zeit, der
  // Ladestand zählt nur Anfang und Ende. Laufen sie auseinander, fehlen der Bilanz Minuten, und
  // das gehört auf die Seite und nicht in eine Rückfrage.
  const bySoc = useMemo(() => socEnergy(rows, cap), [rows, cap]);
  // Anteil des Zeitraums, der nur als Stundenmittel vorliegt. Dort sind die Summen richtig, die
  // Aufteilung auf PV und Netz ist eine Annahme - und genau die steht auf diesen beiden Kacheln.
  const coarse = t && t.minutes > 0 ? t.coarse_minutes / t.minutes : 0;
  const est = coarse > 0.05 ? ` · Aufteilung für ${Math.round(coarse * 100)} % des Zeitraums geschätzt` : "";
  const cycles = t && cap > 0 ? t.battery_discharge_kwh / cap : null;
  const pvShare = t && t.battery_charge_kwh > 0 ? t.pv_to_battery_kwh / t.battery_charge_kwh : null;
  const eff = t && t.battery_charge_kwh > 0.5 ? Math.min(1, t.battery_discharge_kwh / t.battery_charge_kwh) : null;
  const chargeOpt = useMemo(() => stackedBars(data?.buckets ?? [], CHARGE), [data]);
  const dischargeOpt = useMemo(() => stackedBars(data?.buckets ?? [], DISCHARGE), [data]);
  const donutOpt = useMemo(() => donut(CHARGE.map((s) => ({ name: s.name, value: t ? t[s.key] : 0, color: s.color })), pct(pvShare), "aus PV geladen"), [t, pvShare]);
  const dayOpt = useMemo(() => batteryDayChart(rows), [rows]);
  const val = (p: Period, f: (s: EnergySummary) => string) => (strip[p] ? f(strip[p] as EnergySummary) : "-");

  return (
    <ReportShell title="Batteriespeicher" kicker={cap > 0 ? `${de1(cap, 1)} kWh · Nutzung und Ersparnis` : "Nutzung und Ersparnis"} period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={7}>
        <Stat label="Geladen" value={de1(t?.battery_charge_kwh)} unit="kWh" tone="amber" hint={t ? `PV ${de1(t.pv_to_battery_kwh)} · Netz ${de1(t.grid_to_battery_kwh)} kWh${est}` : undefined} />
        <Stat
          label="Netzladung bei Dunkelheit"
          value={de1(t?.grid_to_battery_dark_kwh)}
          unit="kWh"
          tone={(t?.grid_to_battery_dark_kwh ?? 0) > 0.2 ? "ember" : "muted"}
          hint={t ? `von ${de1(t.grid_to_battery_kwh)} kWh Netzladung insgesamt${est}` : undefined}
        />
        <Stat label="Entladen" value={de1(t?.battery_discharge_kwh)} unit="kWh" tone="mist" hint={t ? `${de1(t.battery_to_house_kwh)} kWh ins Haus` : undefined} />
        <Stat label="Vollzyklen" value={cycles != null ? de1(cycles, cycles >= 10 ? 0 : 1) : "-"} hint={cap > 0 ? `Entladung ÷ ${de1(cap, 1)} kWh` : "Kapazität unbekannt"} />
        <Stat label="Ersparnis" value={eur(t?.battery_savings_eur)} tone="amber" hint="gegenüber Netzbezug" />
        <Stat label="PV-Anteil Ladung" value={pct(pvShare)} hint={(t && t.grid_to_battery_kwh > 0.05 ? `${de1(t.grid_to_battery_kwh)} kWh aus dem Netz geladen` : "keine Netzladung") + est} />
        {bySoc ? (
          <Stat
            label="Laut Ladestand"
            value={de1(bySoc.discharge)}
            unit="kWh"
            tone={t && Math.abs(bySoc.discharge - t.battery_discharge_kwh) > 0.25 * Math.max(bySoc.discharge, 0.5) ? "ember" : "muted"}
            hint={t ? `entladen · Leistungsmessung ${de1(t.battery_discharge_kwh)} kWh` : "entladen"}
          />
        ) : (
          <Stat label="Wirkungsgrad" value={pct(eff)} tone="muted" hint="Entladen ÷ Geladen" />
        )}
      </KpiGrid>
      <BatteryControl />
      <div className="report-row" style={{ "--cols": "5fr 3fr 4fr" } as React.CSSProperties}>
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
      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Ladezustand über den Tag" right={isDay ? "Minutenwerte · + Entladen, − Laden" : "nur in der Tagesansicht"} />
          {isDay && rows.length > 0 ? <div className="min-h-0 flex-1"><EChart option={dayOpt} /></div> : <div className="flex flex-1 items-center justify-center"><Note>{isDay ? "Für diesen Tag liegen keine Minutenwerte vor; die Stundenbilanzen oben stammen dann aus dem Historienimport." : "Der Verlauf wird je Tag gezeigt; für längere Zeiträume gelten die Stundenbilanzen oben."}</Note></div>}
        </Card>
        <PeriodStrip
          title="Speicher im Überblick"
          rows={[
            { label: "Ersparnis", value: (p) => val(p, (s) => eur(s.totals.battery_savings_eur)), tone: "amber" },
            { label: "Entladen · kWh", value: (p) => val(p, (s) => de1(s.totals.battery_discharge_kwh, s.totals.battery_discharge_kwh >= 100 ? 0 : 1)) },
            { label: "Vollzyklen", value: (p) => val(p, (s) => (cap > 0 ? de1(s.totals.battery_discharge_kwh / cap, 1) : "-")) },
            { label: "PV-Anteil", value: (p) => val(p, (s) => pct(s.totals.battery_charge_kwh > 0 ? s.totals.pv_to_battery_kwh / s.totals.battery_charge_kwh : null)) },
          ]}
        />
      </div>
      <CoverageNote meta={data?.meta} extra="Ersparnis: jede ins Haus entladene Kilowattstunde spart den Bezugspreis der Stunde, abzüglich der Einspeisevergütung, die der gespeicherte PV-Strom sonst gebracht hätte." />
    </ReportShell>
  );
}
