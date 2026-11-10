"use client";

import Link from "next/link";
import { useCallback, useMemo } from "react";
import { api } from "@/lib/api/client";
import type { HeatBalance, HeatReport, Period, ShiftReport } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Methode, MethodeAbsatz } from "@/components/ui/Methode";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { bufferChart, C, heatBalanceChart, stackedBars } from "./charts";
import { ChartLegend, CoverageNote, de1, ErrorBanner, eur, KpiGrid, Note, pct, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip, type StripRow } from "./PeriodStrip";
import { useMultiPeriod, useReport } from "./useReport";

/**
 * Die Wärmeübersicht: wer geliefert hat, was es gekostet hat, wie die Anlage lief.
 *
 * **Eine Seite statt zweier.** Bis zum 10.11.2026 gab es „Erzeuger" und „Bilanz" nebeneinander,
 * und sie nannten für denselben Tag verschiedene Zahlen: 24,5 kWh Wärme und Arbeitszahl 2,90 auf
 * der einen, 20,4 kWh und 2,41 auf der anderen, dazu 9,2 gegen 11,1 Cent je Kilowattstunde. Beide
 * Seiten rechneten, keine maß; die eine nahm die Kennlinie roh, die andere rechnete sie auf den
 * wirklichen Vorlauf um. Zwei Wahrheiten für dieselbe Größe sind keine.
 *
 * **Die Wärme kommt aus der Bilanz, und nur von dort.** Wärmemenge, Arbeitszahl und Wärmepreis
 * stehen auf dieser Seite genau einmal und stammen aus `GET /energy/waermebilanz`: der feineren
 * der beiden Rechnungen. Aus `GET /energy/heat` kommt nur noch, was gemessen ist - der Strom der
 * Wärmepumpe nach Herkunft - und was aus Messungen gezählt wird: Taktung und Ofenbetrieb.
 *
 * **Was hier nicht mehr steht.** Der Wärmebedarf der kommenden Stunden gehört zum Fahrplan und
 * steht dort. Ob sich das Verschieben gelohnt hat, rechnet eine Stelle; diese Seite zeigt ihre
 * Zahl und verweist auf sie. Die Annahmen der Rechnung haben einen eigenen Reiter.
 */

const STROM = [
  { key: "heat_pump_pv_kwh" as const, name: "aus PV", color: C.pv },
  { key: "heat_pump_battery_kwh" as const, name: "aus Batterie", color: C.battery },
  { key: "heat_pump_grid_kwh" as const, name: "aus Netz", color: C.grid },
];

const ERZEUGER = [
  { key: "heat_pump_kwh" as const, name: "Wärmepumpe", color: C.hp },
  { key: "stove_water_kwh" as const, name: "Ofen (Wasser)", color: C.stove },
  // Halbtransparentes Ofenbraun statt einer eigenen Farbe: derselbe Erzeuger, ein anderer Weg.
  { key: "stove_room_kwh" as const, name: "Ofen (Raum)", color: "rgba(181,101,29,.55)" },
];

/** Einordnung der Taktung. Bewusst zurückhaltend: ein Hinweis, keine Diagnose. */
const TAKTUNG = {
  ok: "unauffällig",
  watch: "grenzwertig",
  short_cycling: "taktet häufig",
  unknown: "zu wenig Daten",
} as const;

/** Null ist eine Messung, „keine Daten" ist keine. Ohne Minuten im Zeitraum steht ein Strich. */
const kwh = (n: number | null | undefined) => (n == null ? "-" : de1(n, 1));
const feld = (d: HeatBalance | undefined, pick: (t: HeatBalance["totals"]) => number | null | undefined) =>
  !d || d.totals.minutes === 0 ? "-" : `${kwh(pick(d.totals))} kWh`;
const ct = (n: number | null | undefined) => (n == null ? "-" : `${de1(n, 1)} ct`);

/** Minuten als Stunden und Minuten. „3:05 h" liest sich schneller als „185 min". */
function dauer(min: number | null | undefined): string {
  if (min == null) return "-";
  if (min < 60) return `${min} min`;
  return `${Math.floor(min / 60)}:${String(min % 60).padStart(2, "0")} h`;
}

function Zeile({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-t border-line-1 py-1.5">
      <dt className="text-text-3">{k}</dt>
      <dd className="mono m-0 whitespace-nowrap text-text-1">{v}</dd>
    </div>
  );
}

/** Die große Zahl einer Karte mit ihrer Unterzeile. Schrift in Textfarbe, wie überall. */
function Kernzahl({ wert, einheit, rechts }: { wert: string; einheit: string; rechts?: string }) {
  return (
    <div className="flex items-baseline gap-3">
      <span className="mono text-[26px] leading-none text-text-1">{wert}</span>
      <span className="text-[13px] text-text-3">{einheit}</span>
      {rechts ? <span className="mono ml-auto text-[11px] uppercase tracking-[.08em] text-text-3">{rechts}</span> : null}
    </div>
  );
}

export function HeatOverview() {
  const { period, anchor, setPeriod, move, today } = usePeriod();
  const bilanzLader = useCallback((p: Period, a: string) => api.heatBalance(p, a), []);
  const { data: bilanz, error } = useReport<HeatBalance>(bilanzLader, period, anchor);
  const { data: strom } = useReport<HeatReport>(api.energyHeat, period, anchor);
  const { data: schieben } = useReport<ShiftReport>(api.energyShift, period, anchor);
  const alle = useMultiPeriod<HeatBalance>(bilanzLader, anchor);

  const t = bilanz?.totals;
  const kosten = bilanz?.cost;
  const e = strom?.summary.totals;
  const sonnenanteil = e && e.heat_pump_kwh > 0 ? (e.heat_pump_pv_kwh + e.heat_pump_battery_kwh) / e.heat_pump_kwh : null;
  const netzCt = e && e.heat_pump_grid_kwh > 0.01 && kosten ? (kosten.heat_pump_paid_eur / e.heat_pump_grid_kwh) * 100 : null;
  const ofenKwh = (t?.stove_water_kwh ?? 0) + (t?.stove_room_kwh ?? 0);
  const lueftung = bilanz?.ventilation;
  const takt = strom?.cycling;
  const ofen = strom?.stove;
  const stufen = Object.entries(ofen?.minutes_by_level ?? {}).sort(([a], [b]) => Number(a) - Number(b));
  const p = bilanz?.params;
  const tag = period === "day";
  const zeigtFenster = Boolean(lueftung && (lueftung.kwh > 0.01 || lueftung.open_minutes > 0));
  const zeigtOfen = Boolean(ofen?.available);

  const stromBalken = useMemo(() => stackedBars(strom?.summary.buckets ?? [], STROM), [strom]);
  const pufferBild = useMemo(() => bufferChart(strom?.buffer_series ?? []), [strom]);
  const hatPuffer = (strom?.buffer_series.length ?? 0) > 0;

  const zeilen: StripRow[] = [
    { label: "Wärme gesamt", value: (x) => feld(alle[x], (s) => s.produced_kwh) },
    { label: "davon Wärmepumpe", value: (x) => feld(alle[x], (s) => s.heat_pump_kwh) },
    { label: "davon Ofen (Wasser)", value: (x) => feld(alle[x], (s) => s.stove_water_kwh) },
    { label: "davon Ofen (Raum)", value: (x) => feld(alle[x], (s) => s.stove_room_kwh) },
    { label: "Entnahme Heizung und Warmwasser", value: (x) => feld(alle[x], (s) => s.draw_kwh) },
    { label: "Verlust an den Aufstellraum", value: (x) => feld(alle[x], (s) => s.loss_kwh) },
    { label: "Strom der Wärmepumpe", value: (x) => feld(alle[x], (s) => s.electric_kwh) },
    { label: "Arbeitszahl", value: (x) => (alle[x]?.totals.cop_mean == null ? "-" : de1(alle[x]?.totals.cop_mean, 2)) },
    { label: "nicht zuzuordnen", value: (x) => feld(alle[x], (s) => s.residual_kwh) },
    { label: "Strom bezahlt", value: (x) => eur(alle[x]?.cost.heat_pump_paid_eur) },
    { label: "Pellets verbrannt", value: (x) => (alle[x] ? `${de1(alle[x]!.cost.stove_kg, 1)} kg` : "-") },
    { label: "Pellets im Wert von", value: (x) => eur(alle[x]?.cost.stove_eur) },
  ];

  const gelohnt = schieben && schieben.days_used > 0 ? schieben.saving_eur : null;
  const zeitraum = `?period=${period}&anchor=${anchor}`;

  return (
    <ReportShell title="Wärme" kicker="gerechnet, nicht gemessen" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today}>
      {error ? <ErrorBanner message={error} /> : null}

      <KpiGrid cols={6}>
        <Stat
          label="Wärme gesamt"
          value={kwh(t?.produced_kwh)}
          unit="kWh"
          hint={t ? (ofenKwh > 0.05 ? `Wärmepumpe ${kwh(t.heat_pump_kwh)} · Ofen ${kwh(ofenKwh)} kWh` : "nur die Wärmepumpe") : undefined}
        />
        <Stat label="Strom Wärmepumpe" value={de1(e?.heat_pump_kwh)} unit="kWh" hint={e ? `${pct(sonnenanteil)} Sonnenstrom` : undefined} />
        <Stat label="Arbeitszahl" value={t?.cop_mean == null ? "-" : de1(t.cop_mean, 2)} hint={t?.cop_mean == null ? "keine Laufzeit" : "aus Kennlinie und Vorlauf"} />
        <Stat
          label="Bezahlt"
          value={eur(kosten?.heat_pump_paid_eur)}
          hint={e ? `${de1(e.heat_pump_grid_kwh)} kWh Netz${netzCt != null ? ` · Ø ${de1(netzCt, 1)} ct` : ""}` : undefined}
        />
        <Stat
          label="Wärmepreis"
          value={kosten?.heat_pump_ct_per_kwh == null ? "-" : de1(kosten.heat_pump_ct_per_kwh, 1)}
          unit="ct/kWh"
          hint={kosten?.stove_ct_per_kwh != null ? `Wärmepumpe · Ofen ${ct(kosten.stove_ct_per_kwh)}` : "je kWh Wärme der Wärmepumpe"}
        />
        <Stat
          label="Entnahme"
          value={kwh(t?.draw_kwh)}
          unit="kWh"
          hint={t ? `Heizung und Warmwasser · Verlust ${kwh(t.loss_kwh)} kWh` : undefined}
        />
      </KpiGrid>

      {/* Der Tag als Verlauf, jeder längere Zeitraum als Balken. Beides zugleich war dieselbe
          Zufuhr zweimal: einmal je Minute, einmal je Stunde. */}
      {tag ? (
        <Card style={{ padding: 16, minHeight: 320 }}>
          <CardHead title="Tagesverlauf" right={bilanz?.resolution_de} />
          {bilanz && bilanz.series.length > 0 ? (
            <div className="mt-2 h-[340px]">
              <EChart option={heatBalanceChart(bilanz.series)} />
            </div>
          ) : (
            <Note>Für diesen Tag liegen keine Minutenwerte vor.</Note>
          )}
        </Card>
      ) : (
        <Card style={{ padding: 16 }}>
          <CardHead title={period === "year" ? "Wärme je Monat" : "Wärme je Tag"} right={<ChartLegend items={ERZEUGER.map((s) => ({ color: s.color, name: s.name }))} />} />
          {bilanz && bilanz.buckets.length > 0 ? (
            <div className="mt-2 h-[260px]">
              <EChart option={stackedBars(bilanz.buckets.map((b) => ({ label: b.label_de, totals: b })), ERZEUGER)} />
            </div>
          ) : (
            <Note>Für diesen Zeitraum liegen keine Werte vor.</Note>
          )}
        </Card>
      )}

      <div className="report-row" style={{ "--cols": tag && hatPuffer ? "7fr 5fr" : "1fr" } as React.CSSProperties}>
        {/* Die Schichtung des Puffers gibt es nur je Tag; in einer Woche wäre sie ein Knäuel.
            Dann fehlt die Karte, statt mit einem Platzhalter die halbe Zeile zu belegen. */}
        {tag && hatPuffer ? (
          <Card id="puffer" style={{ padding: 16, height: 300 }}>
            <CardHead title="Pufferspeicher" right="Temperaturen in vier Höhen · Leistung der Wärmepumpe" />
            <div className="min-h-0 flex-1">
              <EChart option={pufferBild} />
            </div>
          </Card>
        ) : null}
        <Card style={{ padding: 16, height: 300 }}>
          <CardHead title="Strom der Wärmepumpe nach Herkunft" right={<ChartLegend items={STROM} />} />
          <div className="min-h-0 flex-1">
            <EChart option={stromBalken} />
          </div>
        </Card>
      </div>

      <div className="report-row" style={{ "--cols": "1fr 1fr 1fr" } as React.CSSProperties}>
        <Card style={{ padding: "14px 18px", gap: 10 }}>
          <CardHead title="Was die Wärme gekostet hat" />
          <Kernzahl wert={kosten?.heat_pump_ct_per_kwh == null ? "-" : de1(kosten.heat_pump_ct_per_kwh, 1)} einheit="ct je kWh Wärme" />
          <dl className="m-0 text-[12px]">
            <Zeile k="Wärmepumpe: bezahlter Netzstrom" v={eur(kosten?.heat_pump_paid_eur)} />
            <Zeile k="Wärmepumpe: entgangene Vergütung" v={eur(kosten?.heat_pump_opportunity_eur)} />
            <Zeile k="Pellets: verbrannte Menge" v={kosten ? `${de1(kosten.stove_kg, 1)} kg` : "-"} />
            <Zeile k="Pellets: Wert zum hinterlegten Preis" v={eur(kosten?.stove_eur)} />
            <Zeile k="Ofen: je kWh Wärme" v={ct(kosten?.stove_ct_per_kwh)} />
          </dl>
          <Note>{kosten?.cheaper_de}</Note>
        </Card>

        <Card style={{ padding: "14px 18px", gap: 10 }}>
          <CardHead title="Taktung" right={takt?.covered_hours ? `${de1(takt.covered_hours, 0)} h bewertet` : undefined} />
          <Kernzahl
            wert={takt?.starts_per_day != null ? de1(takt.starts_per_day, 1) : "-"}
            einheit="Starts je Tag"
            rechts={TAKTUNG[(takt?.verdict ?? "unknown") as keyof typeof TAKTUNG] ?? TAKTUNG.unknown}
          />
          <dl className="m-0 grid grid-cols-2 gap-x-4 text-[12px]">
            <Zeile k="Läufe" v={takt ? String(takt.runs) : "-"} />
            <Zeile k="Laufanteil" v={pct(takt?.duty_cycle)} />
            <Zeile k="Lauf im Mittel" v={takt?.mean_run_min != null ? `${de1(takt.mean_run_min, 0)} min` : "-"} />
            <Zeile k="kürzester Lauf" v={takt?.shortest_run_min != null ? `${takt.shortest_run_min} min` : "-"} />
            <Zeile k="Pause im Mittel" v={takt?.mean_pause_min != null ? `${de1(takt.mean_pause_min, 0)} min` : "-"} />
            <Zeile k="unter Mindestlaufzeit" v={takt?.short_runs != null ? `${takt.short_runs}×` : "-"} />
          </dl>
          <Note>{takt?.note_de}</Note>
        </Card>

        {/* Dieselbe Zahl wie auf „Geld": eine Rechnung, an zwei Stellen gezeigt. Vorher stand hier
            eine eigene Karte „Lief sie zur richtigen Zeit?" mit einer zweiten Antwort auf dieselbe
            Frage. */}
        <Card style={{ padding: "14px 18px", gap: 10 }}>
          <CardHead title="Hat sich das Verschieben gelohnt?" right="geschätzt" />
          <Kernzahl
            wert={gelohnt == null ? "-" : eur(Math.abs(gelohnt))}
            einheit={gelohnt == null ? "keine Aussage für diesen Zeitraum" : gelohnt >= 0 ? "gespart gegenüber einem Lauf ohne Preisblick" : "mehr bezahlt als ohne Preisblick"}
          />
          {schieben && schieben.days_used > 0 ? (
            <dl className="m-0 text-[12px]">
              <Zeile k="in andere Stunden verschoben" v={`${de1(schieben.shifted_kwh, 0)} von ${de1(schieben.heat_pump_kwh, 0)} kWh`} />
              <Zeile k="je verschobener kWh" v={schieben.saving_ct_per_kwh == null ? "-" : `${de1(schieben.saving_ct_per_kwh, 1)} ct`} />
              <Zeile k="gerechnete Tage" v={String(schieben.days_used)} />
            </dl>
          ) : (
            <Note>{schieben?.skipped_de || "Dafür braucht es einen Tag mit genug gemessenen Stunden und laufender Wärmepumpe."}</Note>
          )}
          <div className="mt-auto flex flex-wrap gap-x-5 gap-y-1 pt-1 text-[12px]">
            <Link href={`/geld${zeitraum}`} className="text-amber">
              Rechnung und Annahmen ›
            </Link>
            {tag ? (
              <Link href={`/waerme/nachbetrachtung?day=${anchor}`} className="text-amber">
                Fahrplan gegen Wirklichkeit ›
              </Link>
            ) : null}
          </div>
        </Card>
      </div>

      {zeigtOfen || zeigtFenster ? (
        <div className="report-row" style={{ "--cols": zeigtOfen && zeigtFenster ? "5fr 7fr" : "1fr" } as React.CSSProperties}>
          {zeigtOfen && ofen ? (
            <Card id="ofen" style={{ padding: "14px 18px", gap: 10 }}>
              <CardHead title="Pelletofen" right={`${ofen.runs} Brennphase${ofen.runs === 1 ? "" : "n"}`} />
              <Kernzahl wert={dauer(ofen.running_minutes)} einheit="Laufzeit" />
              <dl className="m-0 grid grid-cols-2 gap-x-4 text-[12px]">
                <Zeile k="davon mit Feuer" v={dauer(ofen.burning_minutes)} />
                <Zeile k="längste Phase" v={ofen.longest_run_min ? `${ofen.longest_run_min} min` : "-"} />
                <Zeile k="Brennstoff" v={ofen.pellet_kg ? `${de1(ofen.pellet_kg, 1)} kg` : "-"} />
                <Zeile k="zum Preis von" v={ofen.pellet_eur ? eur(ofen.pellet_eur) : "-"} />
                <Zeile k="Spreizung" v={ofen.spread_k != null ? `${de1(ofen.spread_k, 1)} K` : "-"} />
                <Zeile k="Rauchgas max." v={ofen.fume_temp_max_c != null ? `${de1(ofen.fume_temp_max_c, 0)} °C` : "-"} />
                <Zeile k="Warmwasser" v={dauer(ofen.dhw_minutes)} />
                <Zeile k="Betriebsstunden" v={ofen.operating_hours != null ? `${de1(ofen.operating_hours, 0)} h` : "-"} />
                <Zeile k="Zündungen" v={ofen.ignitions != null ? String(ofen.ignitions) : "-"} />
              </dl>
              {stufen.length ? (
                <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1 text-[12px] text-text-3">
                  <span>Leistungsstufen:</span>
                  {stufen.map(([stufe, min]) => (
                    <span key={stufe} className="mono text-text-1">
                      {stufe}: {dauer(min)}
                    </span>
                  ))}
                </div>
              ) : null}
              <Note>{ofen.note_de}</Note>
              {ofen.auger_revolutions ? <Note>{ofen.fuel_note_de}</Note> : null}
            </Card>
          ) : null}

          {/* Nur zeigen, wenn es etwas zu zeigen gibt: eine Karte, die jeden Tag „null" sagt,
              liest nach einer Woche niemand mehr. */}
          {zeigtFenster && lueftung ? (
            <Card style={{ padding: "14px 18px", gap: 10 }}>
              <CardHead title="Bei offenem Fenster" right="geschätzt, nach offenen Heizkreisen verteilt" />
              <Kernzahl
                wert={kwh(lueftung.kwh)}
                einheit="kWh in Räume mit offenem Fenster"
                rechts={`${Math.round(lueftung.open_minutes)} min offen${lueftung.share != null && lueftung.share >= 0.01 ? ` · ${de1(lueftung.share * 100, 0)} % der Entnahme` : ""}`}
              />
              {(lueftung.rooms ?? []).length ? (
                <table className="w-full border-collapse text-[12px]">
                  <thead>
                    <tr className="kicker" style={{ fontSize: 10 }}>
                      <th className="pb-1 text-left font-medium">Raum</th>
                      <th className="pb-1 text-right font-medium">Fenster offen</th>
                      <th className="pb-1 text-right font-medium">davon geheizt</th>
                      <th className="pb-1 text-right font-medium">Wärme</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(lueftung.rooms ?? []).map((r) => (
                      <tr key={r.room_id} className="border-t border-line-1">
                        <td className="py-1.5 pr-3 text-text-1">{r.name}</td>
                        <td className="mono py-1.5 pr-3 text-right text-text-2">{r.open_minutes} min</td>
                        <td className="mono py-1.5 pr-3 text-right text-text-2">{r.heating_minutes} min</td>
                        <td className="mono py-1.5 text-right text-text-1">{kwh(r.kwh)} kWh</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : null}
              <Note>{lueftung.note_de}</Note>
            </Card>
          ) : null}
        </div>
      ) : null}

      <PeriodStrip title="Wärme im Zeitraum" rows={zeilen} anchor={anchor} />

      <Methode kurz="Kein Wärmemengenzähler im Haus: jede Wärmemenge auf dieser Seite ist aus Strom, Ofenbetrieb und Puffertemperaturen gerechnet.">
        <MethodeAbsatz>
          Gemessen werden der Strom der Wärmepumpe, der Betriebszustand des Ofens und vier Puffertemperaturen. Die Wärme der Wärmepumpe ist Strom mal Arbeitszahl. Die
          Arbeitszahl folgt der Kennlinie über der Außentemperatur und wird über das Verhältnis der Carnot-Zahlen auf den wirklichen Vorlauf umgerechnet: dieselbe Maschine
          liefert bei 40 °C Vorlauf deutlich mehr als bei 58 °C, und der Puffer durchläuft an einem Wintertag beides.
        </MethodeAbsatz>
        <MethodeAbsatz>
          Die Entnahme in Heiz- und Brauchwasserkreis wird nicht gemessen; sie ist der Rest der Bilanz, und jeder Fehler der anderen Größen landet in ihr. Was nicht
          aufgeht, steht deshalb in der Tabelle als „nicht zuzuordnen“. Ein dauerhaft großer Rest heißt, dass eine Annahme nicht stimmt.
        </MethodeAbsatz>
        <MethodeAbsatz>
          Bei den Kosten stehen zwei Zahlen verschiedener Art nebeneinander. Der Strom der Wärmepumpe ist geflossen und bezahlt; dazu gehört die entgangene
          Einspeisevergütung für Sonnenstrom, der in den Verdichter statt ins Netz ging. Die Pellets waren bezahlt, als sie geliefert wurden; hier steht, was die verbrannte
          Menge zum hinterlegten Preis wert war. Die Menge ist aus den Leistungsstufen des Ofens geschätzt.
        </MethodeAbsatz>
        <MethodeAbsatz>
          Im Tagesverlauf sind Flächen Zufuhr in den Puffer und addieren sich; Linien sind, was wieder herausgeht. Die Raumwärme des Ofens geht nicht durch den Puffer.
          {bilanz?.note_de ? ` ${bilanz.note_de}` : ""}
        </MethodeAbsatz>
        <MethodeAbsatz>
          Gerechnet wird mit: Kennlinie {(p?.cop_curve ?? []).map(([a, b]) => `${de1(a, 0)} °C: ${de1(b, 1)}`).join(" · ") || "-"}, gültig bei {de1(p?.cop_reference_c, 0)} °C
          Vorlauf; Puffer {de1(p?.buffer_volume_liters, 0)} l mit {de1((p?.buffer_loss_kw_per_k ?? 0) * 1000, 0)} W/K Verlust; Ofen {de1(p?.stove_nominal_heat_kw, 1)} kW, davon{" "}
          {de1(p?.stove_water_heat_kw, 1)} kW ins Wasser; Pellets {de1(p?.pellet_kwh_per_kg, 2)} kWh/kg zu {de1(p?.pellet_price_eur_per_t, 0)} €/t. Wer diese Werte unter{" "}
          <Link href="/waerme/annahmen" className="text-amber">
            Annahmen
          </Link>{" "}
          ändert, ändert jede Zahl auf dieser Seite, auch die vergangener Jahre.
        </MethodeAbsatz>
      </Methode>

      <CoverageNote meta={strom?.summary.meta} />
    </ReportShell>
  );
}
