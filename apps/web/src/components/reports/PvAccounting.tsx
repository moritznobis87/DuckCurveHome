"use client";

import Link from "next/link";
import { useMemo } from "react";
import { api } from "@/lib/api/client";
import type { Period, PvTaxReport } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { C, donut, moneyBars } from "./charts";
import { de1, ErrorBanner, eur, KpiGrid, Note, pct, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip } from "./PeriodStrip";
import { useMultiPeriod, useReport } from "./useReport";

const ct = (n: number | null | undefined): string => (n == null ? "-" : `${de1(n, 2)} ct`);

/** Eine Zeile der Aufstellung - dieselbe Struktur für die Buckets und für die Summenzeile. */
type Row = {
  label: string;
  exportKwh: number;
  exportNet: number;
  exportVat: number;
  selfKwh: number;
  selfNet: number;
  selfVat: number;
  vat: number;
};

const COLUMNS: Array<{ head: string; sub: string; get: (r: Row) => string; strong?: boolean }> = [
  { head: "Einspeisung", sub: "kWh", get: (r) => de1(r.exportKwh, r.exportKwh >= 100 ? 0 : 1) },
  { head: "Vergütung", sub: "netto", get: (r) => eur(r.exportNet) },
  { head: "USt darauf", sub: "erhalten", get: (r) => eur(r.exportVat) },
  { head: "Eigenverbrauch", sub: "kWh", get: (r) => de1(r.selfKwh, r.selfKwh >= 100 ? 0 : 1) },
  { head: "Wertabgabe", sub: "netto", get: (r) => eur(r.selfNet) },
  { head: "USt darauf", sub: "geschuldet", get: (r) => eur(r.selfVat) },
  { head: "Zahllast", sub: "USt gesamt", get: (r) => eur(r.vat), strong: true },
];

function rowOf(label: string, t: PvTaxReport["totals"]): Row {
  return {
    label,
    exportKwh: t.export_kwh,
    exportNet: t.export_net_eur,
    exportVat: t.export_vat_eur,
    selfKwh: t.self_consumption_kwh,
    selfNet: t.self_value_net_eur,
    selfVat: t.self_vat_eur,
    vat: t.vat_payable_eur,
  };
}

export function PvAccounting() {
  // Steuerlich zählt das Kalenderjahr; die kürzeren Zeiträume sind der Blick hinein, nicht umgekehrt.
  const { period, anchor, setPeriod, move, today } = usePeriod("year");
  const { data, error } = useReport<PvTaxReport>(api.energyPv, period, anchor);
  const strip = useMultiPeriod<PvTaxReport>(api.energyPv);
  const t = data?.totals;
  const vatOff = data?.meta.small_business === true;

  const rows = useMemo(
    () => (data?.buckets ?? []).filter((b) => b.totals.export_kwh > 0.005 || b.totals.self_consumption_kwh > 0.005).map((b) => rowOf(b.label, b.totals)),
    [data],
  );
  const barsOpt = useMemo(
    () =>
      moneyBars(
        rows.map((r) => r.label),
        [
          { name: "Einspeisevergütung netto", color: C.mist, values: rows.map((r) => r.exportNet) },
          { name: "Eigenverbrauch (Wert netto)", color: C.pv, values: rows.map((r) => r.selfNet) },
        ],
      ),
    [rows],
  );
  const donutOpt = useMemo(
    () =>
      donut(
        [
          { name: "Direkt verbraucht", value: t?.self_direct_kwh ?? 0, color: C.pv },
          { name: "Über den Speicher", value: t?.self_battery_kwh ?? 0, color: C.battery },
          { name: "Eingespeist", value: t?.export_kwh ?? 0, color: C.export },
        ],
        t ? `${de1(t.pv_kwh, t.pv_kwh >= 100 ? 0 : 1)} kWh` : "-",
        "Erzeugung",
      ),
    [t],
  );

  const val = (p: Period, f: (r: PvTaxReport) => string) => (strip[p] ? f(strip[p] as PvTaxReport) : "-");
  const sum = t ? rowOf("Summe", t) : null;

  return (
    <ReportShell
      title="PV-Abrechnung"
      kicker="Einspeisung · Eigenverbrauch · Umsatzsteuer"
      period={period}
      anchor={anchor}
      onPeriod={setPeriod}
      onMove={move}
      onToday={today}
      right={<Link href="/pv" className="text-[12px] text-amber">Erzeugung →</Link>}
    >
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={6}>
        <Stat label="Eingespeist" value={de1(t?.export_kwh, (t?.export_kwh ?? 0) >= 100 ? 0 : 1)} unit="kWh" tone="mist" hint={data ? `${de1(data.meta.feed_in_ct_kwh, 2)} ct/kWh netto` : undefined} />
        <Stat label="Vergütung netto" value={eur(t?.export_net_eur)} hint={vatOff ? "ohne Umsatzsteuer" : `brutto ${eur(t?.export_gross_eur)}`} />
        <Stat label="USt auf Einspeisung" value={eur(t?.export_vat_eur)} tone={vatOff ? "muted" : undefined} hint="ausgezahlt, abzuführen" />
        <Stat label="Eigenverbrauch" value={de1(t?.self_consumption_kwh, (t?.self_consumption_kwh ?? 0) >= 100 ? 0 : 1)} unit="kWh" tone="amber" hint={t ? `davon ${de1(t.self_battery_kwh, t.self_battery_kwh >= 100 ? 0 : 1)} kWh über den Speicher` : undefined} />
        <Stat label="Wert des Eigenverbrauchs" value={eur(t?.self_value_net_eur)} hint={t ? `netto, Ø ${ct(t.self_ct_kwh)}/kWh` : undefined} />
        <Stat label="Umsatzsteuer gesamt" value={eur(t?.vat_payable_eur)} tone={vatOff ? "muted" : "amber"} hint={vatOff ? "Kleinunternehmer: keine USt" : "Einspeisung + Wertabgabe"} />
      </KpiGrid>

      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 300 }}>
          <CardHead title="Erlös und Wertabgabe" right="Einspeisevergütung · Eigenverbrauch, jeweils netto" />
          <div className="min-h-0 flex-1">{rows.length ? <EChart option={barsOpt} /> : <Note>Für diesen Zeitraum liegen keine bewerteten Stunden vor.</Note>}</div>
        </Card>
        <Card style={{ padding: 16, height: 300 }}>
          <CardHead title="Wohin ging die Erzeugung?" right={t ? `Eigenverbrauchsquote ${pct(t.self_consumption_share)}` : undefined} />
          <div className="min-h-0 flex-1"><EChart option={donutOpt} /></div>
        </Card>
      </div>

      <Card style={{ padding: "14px 18px", gap: 10 }}>
        <CardHead title="Aufstellung" right={data ? `${rows.length} Zeilen · Beträge in Euro` : undefined} />
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-[12px]">
            <thead>
              <tr className="kicker" style={{ fontSize: 10 }}>
                <th className="pb-1.5 pr-3 text-left font-medium">Zeitraum</th>
                {COLUMNS.map((c) => (
                  <th key={`${c.head}-${c.sub}`} className="whitespace-nowrap pb-1.5 pl-3 text-right font-medium">
                    {c.head} <span className="text-text-3">· {c.sub}</span>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.label} className="border-t border-line-1">
                  <td className="whitespace-nowrap py-2 pr-3 text-text-2">{r.label}</td>
                  {COLUMNS.map((c) => (
                    <td key={`${c.head}-${c.sub}`} className="mono whitespace-nowrap py-2 pl-3 text-right" style={{ color: c.strong ? "var(--amber)" : "var(--text-1)" }}>
                      {c.get(r)}
                    </td>
                  ))}
                </tr>
              ))}
              {sum ? (
                <tr className="border-t-2 border-line-2">
                  <td className="whitespace-nowrap py-2 pr-3 font-semibold text-text-1">Summe</td>
                  {COLUMNS.map((c) => (
                    <td key={`${c.head}-${c.sub}`} className="mono whitespace-nowrap py-2 pl-3 text-right font-semibold" style={{ color: c.strong ? "var(--amber)" : "var(--text-1)" }}>
                      {c.get(sum)}
                    </td>
                  ))}
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
        <Note>
          Die Summe stammt aus den ungerundeten Stundenwerten, die Zeilen sind einzeln gerundet: ihre
          Addition kann um wenige Cent abweichen.
        </Note>
      </Card>

      <PeriodStrip
        title="Zeiträume im Vergleich"
        rows={[
          { label: "Einspeisung · kWh", value: (p) => val(p, (r) => de1(r.totals.export_kwh, r.totals.export_kwh >= 100 ? 0 : 1)), tone: "mist" },
          { label: "Vergütung netto", value: (p) => val(p, (r) => eur(r.totals.export_net_eur)) },
          { label: "Eigenverbrauch · kWh", value: (p) => val(p, (r) => de1(r.totals.self_consumption_kwh, r.totals.self_consumption_kwh >= 100 ? 0 : 1)) },
          { label: "Wert Eigenverbrauch netto", value: (p) => val(p, (r) => eur(r.totals.self_value_net_eur)) },
          { label: "Umsatzsteuer gesamt", value: (p) => val(p, (r) => eur(r.totals.vat_payable_eur)), tone: "amber" },
        ]}
      />

      {data ? (
        <Note>
          {data.meta.method_de}
          {data.meta.coverage != null ? ` Datenabdeckung ${Math.round(data.meta.coverage * 100)} %.` : " Für diesen Zeitraum liegen keine Messdaten vor."}
          {t && t.self_estimated_kwh > 0.05
            ? ` Bei ${de1(t.self_estimated_kwh)} kWh der Speicherentladung war die Herkunft nicht bekannt; sie zählen als PV.`
            : ""}
          {" Die Zahlen bereiten die Beträge auf, sie ersetzen keine Steuerberatung."}
        </Note>
      ) : null}
    </ReportShell>
  );
}
