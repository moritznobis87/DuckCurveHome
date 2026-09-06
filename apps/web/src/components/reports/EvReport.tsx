"use client";

import { useMemo } from "react";
import { api } from "@/lib/api/client";
import type { EvReport as EvReportData, Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { C, donut, stackedBars } from "./charts";
import { CoverageNote, de1, ErrorBanner, eur, KpiGrid, Note, pct, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip } from "./PeriodStrip";
import { useMultiPeriod, useReport } from "./useReport";

const SOURCES = [
  { key: "ev_pv_kwh" as const, name: "aus PV", color: C.pv },
  { key: "ev_battery_kwh" as const, name: "aus Batterie", color: C.battery },
  { key: "ev_grid_kwh" as const, name: "aus Netz", color: C.grid },
];

const fmtTime = (iso: string) => new Date(iso).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });
const fmtDay = (iso: string) => new Date(iso).toLocaleDateString("de-DE", { weekday: "short", day: "2-digit", month: "2-digit" });

export function EvReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod();
  const { data, error } = useReport<EvReportData>(api.energyEv, period, anchor);
  const strip = useMultiPeriod<EvReportData>(api.energyEv);
  const t = data?.summary.totals;
  const pvShare = t && t.ev_kwh > 0 ? (t.ev_pv_kwh + t.ev_battery_kwh) / t.ev_kwh : null;
  const paidCt = t && t.ev_grid_kwh > 0.01 ? (t.ev_cost_eur / t.ev_grid_kwh) * 100 : null;
  const effCt = t && t.ev_kwh > 0.01 ? ((t.ev_cost_eur + t.ev_opportunity_eur) / t.ev_kwh) * 100 : null;
  const barsOpt = useMemo(() => stackedBars(data?.summary.buckets ?? [], SOURCES), [data]);
  const donutOpt = useMemo(() => donut(SOURCES.map((s) => ({ name: s.name, value: t ? t[s.key] : 0, color: s.color })), pct(pvShare), "Sonnenstrom"), [t, pvShare]);
  const sessions = useMemo(() => [...(data?.sessions ?? [])].sort((a, b) => b.start.localeCompare(a.start)), [data]);
  const val = (p: Period, f: (s: EvReportData) => string) => (strip[p] ? f(strip[p] as EvReportData) : "–");

  return (
    <ReportShell title="Wallbox" kicker="Ladungen · Herkunft · Kosten" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}
      <KpiGrid cols={6}>
        <Stat label="Geladen" value={de1(t?.ev_kwh)} unit="kWh" tone="mist" hint={data ? `${data.sessions.length} Ladevorgänge` : undefined} />
        <Stat label="Sonnenanteil" value={pct(pvShare)} tone="amber" hint={t ? `PV ${de1(t.ev_pv_kwh)} · Batt. ${de1(t.ev_battery_kwh)} kWh` : undefined} />
        <Stat label="Aus dem Netz" value={de1(t?.ev_grid_kwh)} unit="kWh" tone="ember" hint={paidCt != null ? `Ø ${de1(paidCt, 1)} ct/kWh bezahlt` : "kein Netzbezug"} />
        <Stat label="Bezahlt" value={eur(t?.ev_cost_eur)} tone="ember" hint="Netzanteil × Strompreis" />
        <Stat label="Entgangene Vergütung" value={eur(t?.ev_opportunity_eur)} tone="muted" hint="nicht eingespeister PV-Strom" />
        <Stat label="Effektiv je kWh" value={effCt != null ? de1(effCt, 1) : "–"} unit="ct" hint="bezahlt + entgangen" />
      </KpiGrid>
      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Geladene Energie nach Herkunft" right="PV · Batterie · Netz" />
          <div className="min-h-0 flex-1"><EChart option={barsOpt} /></div>
        </Card>
        <Card style={{ padding: 16, height: 280 }}>
          <CardHead title="Herkunft" />
          <div className="min-h-0 flex-1"><EChart option={donutOpt} /></div>
        </Card>
      </div>
      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, maxHeight: 320 }}>
          <CardHead title="Ladevorgänge" right={sessions.length ? `${sessions.length} im Zeitraum` : "keine im Zeitraum"} />
          {sessions.length ? (
            <div className="mt-2 min-h-0 flex-1 overflow-auto">
              <table className="w-full border-collapse text-[12px]">
                <thead className="sticky top-0" style={{ background: "var(--surface-2)" }}>
                  <tr className="kicker text-left" style={{ fontSize: 10 }}>
                    <th className="py-1.5 pr-3 font-medium">Beginn</th>
                    <th className="py-1.5 pr-3 font-medium">Dauer</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Energie</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Ø Leistung</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Sonnenanteil</th>
                    <th className="py-1.5 pr-3 text-right font-medium">Netz</th>
                    <th className="py-1.5 text-right font-medium">Bezahlt</th>
                  </tr>
                </thead>
                <tbody className="mono">
                  {sessions.map((s) => {
                    const mins = Math.max(1, Math.round((new Date(s.end).getTime() - new Date(s.start).getTime()) / 60000));
                    return (
                      <tr key={s.start} className="border-t border-line-1">
                        <td className="py-1.5 pr-3 whitespace-nowrap">{fmtDay(s.start)} {fmtTime(s.start)}</td>
                        <td className="py-1.5 pr-3 whitespace-nowrap text-text-3">{mins >= 60 ? `${Math.floor(mins / 60)} h ${String(mins % 60).padStart(2, "0")} min` : `${mins} min`}</td>
                        <td className="py-1.5 pr-3 text-right">{de1(s.kwh)} kWh</td>
                        <td className="py-1.5 pr-3 text-right text-text-3">{de1(s.avg_kw)} kW</td>
                        <td className="py-1.5 pr-3 text-right" style={{ color: "var(--amber)" }}>{pct(s.pv_share)}</td>
                        <td className="py-1.5 pr-3 text-right">{de1(s.grid_kwh)} kWh</td>
                        <td className="py-1.5 text-right" style={{ color: s.cost_eur > 0.005 ? "var(--alert)" : "var(--text-3)" }}>{eur(s.cost_eur)}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="flex flex-1 items-center justify-center py-8"><Note>Keine Ladevorgänge im gewählten Zeitraum.</Note></div>
          )}
        </Card>
        <PeriodStrip
          title="Wallbox im Überblick"
          rows={[
            { label: "Geladen · kWh", value: (p) => val(p, (s) => de1(s.summary.totals.ev_kwh, s.summary.totals.ev_kwh >= 100 ? 0 : 1)), tone: "mist" },
            { label: "Sonnenanteil", value: (p) => val(p, (s) => pct(s.summary.totals.ev_kwh > 0 ? (s.summary.totals.ev_pv_kwh + s.summary.totals.ev_battery_kwh) / s.summary.totals.ev_kwh : null)), tone: "amber" },
            { label: "Bezahlt", value: (p) => val(p, (s) => eur(s.summary.totals.ev_cost_eur)), tone: "ember" },
            { label: "Ladevorgänge", value: (p) => val(p, (s) => String(s.sessions.length)) },
          ]}
        />
      </div>
      <CoverageNote meta={data?.summary.meta} extra="Ein Ladevorgang beginnt ab 0,3 kW Wallboxleistung und endet nach 5 Minuten Pause; Vorgänge unter 0,2 kWh werden nicht gezählt." />
    </ReportShell>
  );
}
