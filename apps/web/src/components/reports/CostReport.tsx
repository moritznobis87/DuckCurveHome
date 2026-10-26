"use client";

import Link from "next/link";
import { useMemo } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary, HeatReport, Period, ShiftReport } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { EChart } from "@/components/charts/EChart";
import { C, moneyBars } from "./charts";
import { ChartLegend, CoverageNote, de1, ErrorBanner, eur, Note, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip } from "./PeriodStrip";
import { useMultiPeriod, useReport } from "./useReport";

/**
 * Was der Zeitraum gekostet hat, in einer Zeile.
 *
 * **Warum es diese Seite gibt.** Euro-Betraege standen auf fuenf Seiten verstreut: Netzbezug beim
 * Haus, Pellets bei der Waerme, Ladekosten bei der Wallbox, Erloes bei der PV-Abrechnung, Ersparnis
 * beim Speicher. Was der Oktober gekostet hat, war nirgends in einer Zeile zu lesen. Hier steht sie,
 * und jede Zahl darunter fuehrt zu der Seite, auf der sie herkommt.
 *
 * **Fast nichts hier ist neu gerechnet.** Alle Betraege kommen aus denselben Stundenbilanzen wie
 * die Geraeteseiten; die Seite addiert sie nur. Ersparnis heisst, was Sonne und Speicher gegenueber
 * dem Netzpreis derselben Stunde eingespart haben, abzueglich der Einspeiseverguetung, die man
 * stattdessen bekommen haette.
 *
 * **Die eine Ausnahme ist der Vergleichslauf.** Was das Verschieben der Waermepumpe gebracht hat,
 * laesst sich nicht messen - es gibt nur den einen Verlauf, der stattgefunden hat. Die Zahl kommt
 * deshalb aus einer Rechnung (`accounting/counterfactual.py`), steht als Schaetzung da und nennt
 * ihre Annahmen. Sie darf auch negativ sein; genau dann hat das Verschieben Geld gekostet, und
 * eine Anzeige, die das verschweigt, waere Werbung.
 */
function Betrag({ label, value, tone, hint }: { label: string; value: string; tone: string; hint?: string }) {
  return (
    <div className="flex min-w-0 flex-1 flex-col gap-1 px-5 py-1 first:pl-0 last:pr-0">
      <span className="kicker" style={{ fontSize: 11 }}>{label}</span>
      <span className="mono text-[34px] leading-none tracking-[-.03em]" style={{ color: tone }}>
        {value}
      </span>
      {hint ? <span className="line-clamp-2 text-[12px] leading-[1.35] text-text-3">{hint}</span> : null}
    </div>
  );
}

function Posten({ name, menge, preis, betrag, tone, href, seite }: { name: string; menge: string; preis: string; betrag: string; tone?: string; href: string; seite: string }) {
  return (
    <tr className="border-t border-line-1">
      <td className="py-2 pr-3 text-text-1">{name}</td>
      <td className="mono py-2 pr-3 text-right text-text-2">{menge}</td>
      <td className="mono py-2 pr-3 text-right text-text-2">{preis}</td>
      <td className="mono py-2 pr-3 text-right" style={{ color: tone ?? "var(--text-1)" }}>{betrag}</td>
      <td className="py-2 text-right">
        <Link href={href} className="text-[12px] text-amber">{seite} ›</Link>
      </td>
    </tr>
  );
}

export function CostReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod("month");
  const { data, error } = useReport<EnergySummary>(api.energySummary, period, anchor);
  const { data: heat } = useReport<HeatReport>(api.energyHeat, period, anchor);
  const { data: shift } = useReport<ShiftReport>(api.energyShift, period, anchor);
  const strip = useMultiPeriod<EnergySummary>(api.energySummary, anchor);
  const t = data?.totals;
  const pellets = heat?.stove.pellet_eur ?? 0;
  const bezahlt = t ? t.import_cost_eur + pellets : null;
  const bekommen = t?.export_revenue_eur ?? null;
  const gespart = t ? t.pv_direct_savings_eur + t.battery_savings_eur : null;
  const tage = t && t.minutes > 0 ? Math.max(1, t.minutes / 1440) : null;
  const jeTag = bezahlt != null && bekommen != null && tage ? (bezahlt - bekommen) / tage : null;

  const barsOpt = useMemo(() => {
    const b = data?.buckets ?? [];
    return moneyBars(
      b.map((x) => x.label),
      [
        { name: "Netzstrom", color: C.alert, values: b.map((x) => x.totals.import_cost_eur) },
        // Die Verguetung steht unter der Nulllinie: bekommen, nicht bezahlt.
        { name: "Einspeisung", color: "#ffd778", values: b.map((x) => -x.totals.export_revenue_eur) },
      ],
    );
  }, [data]);

  // Ein Balken je Tag, nach oben was es gebracht hat, nach unten was es gekostet hat. Zwei
  // Serien statt einer eingefaerbten: So steht in der Legende, was ein Vorzeichen bedeutet.
  const shiftBars = useMemo(() => {
    const d = (shift?.days ?? []).filter((x) => !x.note_de);
    return moneyBars(
      d.map((x) => new Date(x.day).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" })),
      [
        { name: "gebracht", color: C.pv, values: d.map((x) => Math.max(0, x.saving_eur)) },
        { name: "gekostet", color: C.alert, values: d.map((x) => Math.min(0, x.saving_eur)) },
      ],
    );
  }, [shift]);

  const val = (p: Period, f: (s: EnergySummary) => string) => (strip[p] ? f(strip[p] as EnergySummary) : "-");
  const haushaltCost = t ? Math.max(0, t.import_cost_eur - t.heat_pump_cost_eur - t.ev_cost_eur) : 0;
  const haushaltKwh = t ? Math.max(0, t.import_kwh - t.heat_pump_grid_kwh - t.ev_grid_kwh) : 0;
  const shiftTon = shift && shift.days_used > 0 ? (shift.saving_eur >= 0 ? "var(--amber)" : "var(--alert)") : "var(--text-3)";
  const ct = (e: number, kwh: number) => (kwh > 0.05 ? `${de1((e / kwh) * 100, 1)} ct` : "-");

  return (
    <ReportShell title="Kosten" kicker="Was der Zeitraum gekostet hat, in einer Zeile" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}

      <Card style={{ padding: "18px 22px" }}>
        <div className="cost-line flex divide-x divide-line-1">
          <Betrag label="Bezahlt" value={eur(bezahlt)} tone="var(--alert)" hint={t ? `Netzstrom ${eur(t.import_cost_eur)} · Pellets ${eur(pellets)}` : undefined} />
          <Betrag label="Bekommen" value={eur(bekommen)} tone="var(--mist)" hint={t ? `Einspeisung ${de1(t.export_kwh, 0)} kWh · netto` : undefined} />
          <Betrag label="Gespart" value={eur(gespart)} tone="var(--amber)" hint="Sonne direkt und Speicher, gegen den Netzpreis derselben Stunde" />
          <Betrag label="Energie je Tag" value={eur(jeTag)} tone="var(--text-1)" hint={tage ? `bezahlt minus bekommen, ${de1(tage, 0)} ${tage < 1.5 ? "Tag" : "Tage"} bewertet` : undefined} />
        </div>
      </Card>

      <div className="report-row" style={{ "--cols": "8fr 4fr" } as React.CSSProperties}>
        <Card style={{ padding: 16, height: 300 }}>
          <CardHead title="Bezahlt und bekommen" right={<ChartLegend items={[{ color: C.alert, name: "Netzstrom" }, { color: "#ffd778", name: "Einspeisung" }]} />} />
          <div className="min-h-0 flex-1">{data?.buckets.length ? <EChart option={barsOpt} /> : <div className="flex h-full items-center justify-center"><Note>Für diesen Zeitraum liegen keine bewerteten Stunden vor.</Note></div>}</div>
        </Card>
        <Card style={{ padding: 16, gap: 12 }}>
          <CardHead title="Woraus die Ersparnis besteht" />
          {[
            { name: "Sonne direkt genutzt", v: t?.pv_direct_savings_eur ?? 0, color: C.pv },
            { name: "Speicher statt Netz", v: t?.battery_savings_eur ?? 0, color: C.battery },
          ].map((e) => {
            const max = Math.max(0.01, t?.pv_direct_savings_eur ?? 0, t?.battery_savings_eur ?? 0);
            return (
              <div key={e.name} className="flex flex-col gap-1.5">
                <div className="flex items-baseline justify-between text-[13px]">
                  <span className="text-text-2">{e.name}</span>
                  <span className="mono text-text-1">{eur(e.v)}</span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-line-1">
                  <div className="h-full rounded-full" style={{ width: `${Math.round((e.v / max) * 100)}%`, background: e.color }} />
                </div>
              </div>
            );
          })}
          <Note>
            Gerechnet gegen den Netzpreis der jeweiligen Stunde, abzüglich der Vergütung, die der Strom
            eingespeist gebracht hätte. Was das Verschieben in Preistiefs gebracht hat, steht in der
            Karte darunter - gerechnet, nicht gemessen.
          </Note>
        </Card>
      </div>

      <Card style={{ padding: 16, gap: 12 }}>
        <CardHead
          title="Was das Verschieben gebracht hat"
          right={<ChartLegend items={[{ color: C.pv, name: "gebracht" }, { color: C.alert, name: "gekostet" }]} />}
        />
        <div className="shift-row flex flex-wrap items-stretch gap-5">
          <div className="flex min-w-[230px] flex-col justify-center gap-2">
            <span className="mono text-[40px] leading-none tracking-[-.03em]" style={{ color: shiftTon }}>
              {shift ? eur(shift.saving_eur) : "-"}
            </span>
            <span className="text-[13px] leading-[1.5] text-text-2">
              {shift && shift.days_used > 0
                ? `${shift.saving_eur >= 0 ? "gespart" : "mehr bezahlt"} gegenüber einem Lauf ohne Preisblick`
                : "Für diesen Zeitraum reicht es nicht für eine Aussage."}
            </span>
            {shift && shift.days_used > 0 ? (
              <span className="mono text-[12px] text-text-3">
                {shift.saving_ct_per_kwh != null ? `${de1(shift.saving_ct_per_kwh, 1)} ct je verschobener kWh · ` : ""}
                {de1(shift.shifted_kwh, 0)} von {de1(shift.heat_pump_kwh, 0)} kWh verschoben · {shift.days_used} {shift.days_used === 1 ? "Tag" : "Tage"} gerechnet
                {shift.days_skipped > 0 ? ` · ${shift.days_skipped} ohne Aussage (${shift.skipped_de})` : ""}
              </span>
            ) : null}
          </div>
          <div className="min-w-[280px] flex-1" style={{ height: 150 }}>
            {shift?.days?.some((d) => !d.note_de) ? <EChart option={shiftBars} /> : null}
          </div>
        </div>
        <Note>{shift?.method_de ?? ""}</Note>
        {/* Die Annahmen gehoeren dazu, aber nicht jedem jeden Tag ins Gesicht: zugeklappt steht
            die Karte ruhig, aufgeklappt steht alles da, was die Zahl voraussetzt. */}
        {shift?.assumptions_de?.length ? (
          <details className="text-[12px] leading-[1.5] text-text-3">
            <summary className="cursor-pointer text-text-2">Annahmen des Vergleichslaufs</summary>
            <ul className="mt-1.5 flex list-disc flex-col gap-1 pl-5">
              {shift.assumptions_de.map((a) => (
                <li key={a}>{a}</li>
              ))}
            </ul>
          </details>
        ) : null}
      </Card>

      <Card style={{ padding: 16, gap: 8 }}>
        <CardHead title="Aufstellung" right="Beträge in Euro · aus denselben Stundenbilanzen wie alle anderen Seiten" />
        <table className="w-full border-collapse text-[13px]">
          <thead>
            <tr className="kicker" style={{ fontSize: 10 }}>
              <th className="pb-1 text-left font-medium">Posten</th>
              <th className="pb-1 text-right font-medium">Menge</th>
              <th className="pb-1 text-right font-medium">Ø Preis</th>
              <th className="pb-1 text-right font-medium">Betrag</th>
              <th className="pb-1 text-right font-medium">Seite</th>
            </tr>
          </thead>
          <tbody>
            <Posten name="Netzstrom Haushalt" menge={`${de1(haushaltKwh, 0)} kWh`} preis={ct(haushaltCost, haushaltKwh)} betrag={eur(haushaltCost)} tone="var(--alert)" href="/strom" seite="Strom" />
            <Posten name="Netzstrom Wärmepumpe" menge={`${de1(t?.heat_pump_grid_kwh, 0)} kWh`} preis={t ? ct(t.heat_pump_cost_eur, t.heat_pump_grid_kwh) : "-"} betrag={eur(t?.heat_pump_cost_eur)} tone="var(--alert)" href="/waerme" seite="Wärme" />
            <Posten name="Netzstrom Wallbox" menge={`${de1(t?.ev_grid_kwh, 0)} kWh`} preis={t ? ct(t.ev_cost_eur, t.ev_grid_kwh) : "-"} betrag={eur(t?.ev_cost_eur)} tone="var(--alert)" href="/strom/wallbox" seite="Wallbox" />
            <Posten name="Pellets" menge={heat ? `${de1(heat.stove.pellet_kg, 1)} kg` : "-"} preis="" betrag={eur(pellets)} tone="var(--stove)" href="/waerme" seite="Wärme" />
            <Posten name="Einspeisung" menge={`${de1(t?.export_kwh, 0)} kWh`} preis={data ? `${de1(data.meta.feed_in_ct_kwh, 2)} ct` : "-"} betrag={bekommen != null ? `− ${eur(bekommen)}` : "-"} tone="var(--mist)" href="/geld/pv-abrechnung" seite="PV-Abrechnung" />
            <Posten name="Entgangene Vergütung (Wärmepumpe, Wallbox)" menge="" preis="" betrag={eur(t ? t.heat_pump_opportunity_eur + t.ev_opportunity_eur : null)} tone="var(--text-3)" href="/strom/pv" seite="Photovoltaik" />
          </tbody>
        </table>
        <Note>
          Die Pelletmenge ist aus den Leistungsstufen des Ofens geschätzt, nicht gewogen. Die entgangene
          Vergütung ist kein Geld, das fehlt, sondern der Preis dafür, Sonnenstrom selbst zu nutzen statt
          ihn einzuspeisen; sie steht hier, weil sie in den Wärme- und Wallboxkosten mitgerechnet wird.
        </Note>
      </Card>

      <PeriodStrip
        title="Kosten im Zeitraum"
        anchor={anchor}
        rows={[
          { label: "Bezahlt (Netzstrom)", value: (p) => val(p, (s) => eur(s.totals.import_cost_eur)), tone: "ember" },
          { label: "Bekommen (Einspeisung)", value: (p) => val(p, (s) => eur(s.totals.export_revenue_eur)), tone: "mist" },
          { label: "Gespart (Sonne, Speicher)", value: (p) => val(p, (s) => eur(s.totals.pv_direct_savings_eur + s.totals.battery_savings_eur)), tone: "amber" },
          { label: "Netzbezug", value: (p) => val(p, (s) => `${de1(s.totals.import_kwh, 0)} kWh`) },
          { label: "Ø Bezugspreis", value: (p) => val(p, (s) => (s.totals.avg_import_price_ct != null ? `${de1(s.totals.avg_import_price_ct, 1)} ct` : "-")) },
        ]}
      />
      <CoverageNote meta={data?.meta} extra={heat?.stove.note_de} />
    </ReportShell>
  );
}
