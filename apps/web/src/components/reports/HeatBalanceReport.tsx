"use client";

import { useCallback } from "react";
import { api } from "@/lib/api/client";
import type { HeatBalance as Data, Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { C, heatBalanceChart, stackedBars } from "./charts";
import { ChartLegend, de1, ErrorBanner, KpiGrid, Note, ReportShell, usePeriod } from "./ReportShell";
import { PeriodStrip, type StripRow } from "./PeriodStrip";
import { useMultiPeriod, useReport } from "./useReport";

/**
 * Die Wärmeseite: wer geliefert hat, was entnommen wurde, was in den Raum ging.
 *
 * **Alles auf dieser Seite ist gerechnet.** Es gibt keinen Wärmemengenzähler im Haus; gemessen
 * werden Strom, der Betriebszustand des Ofens und vier Puffertemperaturen. Deshalb stehen die
 * Annahmen auf derselben Seite und nicht in einer Fußnote: eine Wärmemenge ohne ihre Annahmen ist
 * eine Behauptung.
 *
 * **Das offene Fenster steht jetzt dabei.** Ein Raum, der lüftet, zieht weiter Wärme aus dem
 * Fußboden; in der Entnahme sah das aus wie Wärmebedarf. Wie viel davon in Räume mit offenem
 * Fenster ging, steht in einer eigenen Karte - geschätzt, nach offenen Heizkreisen verteilt, und
 * mit der Grenze daneben: Lüftungsverlust ist es nicht ganz, weil ein Teil im Raum bleibt.
 *
 * **Der Rest ist die wichtigste Zahl.** Die Entnahme in Heiz- und Brauchwasserkreis wird nicht
 * gemessen, sie ist der Rest der Bilanz, und jeder Fehler der anderen Größen landet in ihr. Was
 * nicht aufgeht, steht deshalb als eigene Zeile da. Ein dauerhaft großer Rest heißt: ein Parameter
 * stimmt nicht, und dann gehört er auf der Einstellungsseite korrigiert.
 */
const BUCKET_SERIES = [
  { key: "heat_pump_kwh" as const, name: "Wärmepumpe", color: C.hp },
  { key: "stove_water_kwh" as const, name: "Ofen (Wasser)", color: C.stove },
  // Halbtransparentes Ofenbraun statt einer eigenen Farbe: es ist derselbe Erzeuger, nur ein
  // anderer Weg. C.base ist hier belegt - im Verlauf darueber steht es fuer die Entnahme, und
  // dieselbe Farbe darf auf einer Seite nicht zwei Dinge heissen.
  { key: "stove_room_kwh" as const, name: "Ofen (Raum)", color: "rgba(181,101,29,.55)" },
];

/** Null ist eine Messung, „keine Daten" ist keine. Ohne Minuten im Zeitraum steht ein Strich. */
const kwh = (n: number | null | undefined) => (n == null ? "-" : de1(n, 1));
const feld = (d: Data | undefined, pick: (t: Data["totals"]) => number | null | undefined) =>
  !d || d.totals.minutes === 0 ? "-" : `${kwh(pick(d.totals))} kWh`;
const euro = (n: number | null | undefined) => (n == null ? "-" : `${de1(n, 2)} €`);
const ct = (n: number | null | undefined) => (n == null ? "-" : `${de1(n, 1)} ct`);

function Param({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-line-1 py-1.5 last:border-b-0">
      <span className="text-[13px] text-text-3">{k}</span>
      <span className="mono text-[13px] text-text-1">{v}</span>
    </div>
  );
}

export function HeatBalanceReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod("day");
  const loader = useCallback((p: Period, a: string) => api.heatBalance(p, a), []);
  const { data, error } = useReport<Data>(loader, period, anchor);
  const alle = useMultiPeriod<Data>(loader, anchor);

  const t = data?.totals;
  const lueftung = data?.ventilation;
  const p = data?.params;
  // Die Statistik über alle vier Zeiträume: dieselbe Zeile, vier Spalten. Das ist die Antwort auf
  // „was hat welcher Erzeuger umgesetzt" - ohne vier Mal blättern zu müssen.
  const rows: StripRow[] = [
    { label: "Wärme gesamt", value: (x) => feld(alle[x], (t) => t.produced_kwh), tone: "amber" },
    { label: "davon Wärmepumpe", value: (x) => feld(alle[x], (t) => t.heat_pump_kwh) },
    { label: "davon Ofen (Wasser)", value: (x) => feld(alle[x], (t) => t.stove_water_kwh) },
    { label: "davon Ofen (Raum)", value: (x) => feld(alle[x], (t) => t.stove_room_kwh) },
    { label: "Entnahme Heizung und Warmwasser", value: (x) => feld(alle[x], (t) => t.draw_kwh) },
    { label: "Verlust an den Aufstellraum", value: (x) => feld(alle[x], (t) => t.loss_kwh) },
    { label: "davon dem Haus zugute", value: (x) => feld(alle[x], (t) => t.loss_useful_kwh) },
    { label: "Strom der Wärmepumpe", value: (x) => feld(alle[x], (t) => t.electric_kwh) },
    { label: "Arbeitszahl", value: (x) => (alle[x]?.totals.cop_mean == null ? "-" : de1(alle[x]?.totals.cop_mean, 2)), tone: "mist" },
    { label: "nicht zuzuordnen", value: (x) => feld(alle[x], (t) => t.residual_kwh), tone: "ember" },
    { label: "Strom bezahlt", value: (x) => euro(alle[x]?.cost.heat_pump_paid_eur) },
    { label: "Pellets verbrannt", value: (x) => (alle[x] ? `${de1(alle[x]!.cost.stove_kg, 1)} kg` : "-") },
    { label: "Pellets im Wert von", value: (x) => euro(alle[x]?.cost.stove_eur) },
  ];

  const vergleich =
    data?.previous && t
      ? `Vorheriger Zeitraum: ${kwh(data.previous.produced_kwh)} kWh erzeugt, davon ${kwh(data.previous.heat_pump_kwh)} kWh aus der Wärmepumpe.`
      : "";

  return (
    <ReportShell
      title="Wärmebilanz"
      kicker="gerechnet, nicht gemessen"
      period={period}
      anchor={anchor}
      onPeriod={setPeriod}
      onMove={move}
      onToday={today}
    >
      {error ? <ErrorBanner message={error} /> : null}

      <KpiGrid cols={5}>
        <Stat label="Wärme gesamt" value={kwh(t?.produced_kwh)} unit="kWh" tone="amber" hint="beide Erzeuger, Raumwärme des Ofens eingeschlossen" />
        <Stat label="Wärmepumpe" value={kwh(t?.heat_pump_kwh)} unit="kWh" hint={t?.cop_mean ? `Arbeitszahl ${de1(t.cop_mean, 2)}` : "keine Laufzeit"} />
        <Stat label="Pelletofen" value={kwh((t?.stove_water_kwh ?? 0) + (t?.stove_room_kwh ?? 0))} unit="kWh" hint={`${kwh(t?.stove_water_kwh)} kWh ins Wasser, ${kwh(t?.stove_room_kwh)} kWh in den Raum`} />
        <Stat
          label="Entnahme"
          value={kwh(t?.draw_kwh)}
          unit="kWh"
          hint={
            lueftung && lueftung.kwh > 0.05
              ? `Heizkreis und Warmwasser · davon ${kwh(lueftung.kwh)} kWh bei offenem Fenster`
              : "Heizkreis und Warmwasser, als Rest der Bilanz"
          }
        />
        {/* „nicht verloren" stand hier pauschal, und es stimmte nicht: der Puffer steht in einem
            unbeheizten Technikraum, nicht im Wohnraum. Jetzt steht da, wie viel davon dem Haus
            wirklich zugutekommt, und das ist eine eingestellte Annahme. */}
        <Stat label="Verlust" value={kwh(t?.loss_kwh)} unit="kWh" tone="mist" hint={t?.loss_useful_kwh ? `davon ${kwh(t.loss_useful_kwh)} kWh dem Haus zugute` : "an den Aufstellraum des Puffers"} />
      </KpiGrid>

      {/* Die Vorschau steht nur in der Tagesansicht und nur für heute: ein Folgetag eines
          vergangenen Tages waere keine Prognose. */}
      {data?.forecast_heat_kwh != null ? (
        <Card style={{ padding: 16 }}>
          <CardHead title="Morgen" right="Bedarf, nicht Erzeugung" />
          <div className="mt-2 flex flex-wrap items-baseline gap-x-6 gap-y-2">
            <span className="text-[28px] font-semibold tracking-[-.02em] text-amber">
              {kwh(data.forecast_heat_kwh)} <span className="text-[15px] text-text-3">kWh</span>
            </span>
            <Note>{data.forecast_note_de}</Note>
          </div>
        </Card>
      ) : null}

      {/* Nur zeigen, wenn es etwas zu zeigen gibt: Eine Karte, die jeden Tag „null" sagt, liest
          nach einer Woche niemand mehr. */}
      {lueftung && (lueftung.kwh > 0.01 || lueftung.open_minutes > 0) ? (
        <Card style={{ padding: 16 }}>
          <CardHead title="Bei offenem Fenster" right="geschätzt, nach offenen Heizkreisen verteilt" />
          <div className="mt-2 flex flex-wrap items-baseline gap-x-6 gap-y-2">
            <span className="text-[28px] font-semibold tracking-[-.02em]" style={{ color: "var(--amber-soft)" }}>
              {kwh(lueftung.kwh)} <span className="text-[15px] text-text-3">kWh</span>
            </span>
            <span className="mono text-[12px] text-text-3">
              {Math.round(lueftung.open_minutes)} Minuten Fenster offen
              {lueftung.share != null && lueftung.share >= 0.01
                ? ` · ${de1(lueftung.share * 100, 0)} % der Entnahme`
                : ""}
            </span>
          </div>
          {(lueftung.rooms ?? []).length ? (
            <table className="mt-3 w-full border-collapse text-[13px]">
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
                    <td className="mono py-1.5 text-right" style={{ color: r.kwh > 0.05 ? "var(--amber-soft)" : "var(--text-3)" }}>
                      {kwh(r.kwh)} kWh
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : null}
          <Note>{lueftung.note_de}</Note>
        </Card>
      ) : null}

      {period === "day" ? (
        <Card style={{ padding: 16, minHeight: 320 }}>
          {/* Keine zweite Legende: das Diagramm bringt eine eigene mit, und sie ist anklickbar.
              Zwei Legenden fuer dieselben Reihen sind eine zu viel. */}
          <CardHead title="Tagesverlauf" right={data?.resolution_de} />
          {data && data.series.length > 0 ? (
            <div className="mt-2 h-[340px]">
              <EChart option={heatBalanceChart(data.series)} />
            </div>
          ) : (
            <Note>Für diesen Tag liegen keine Minutenwerte vor.</Note>
          )}
          <Note>
            Flächen sind Zufuhr in den Puffer und addieren sich; Linien sind, was wieder herausgeht,
            und stehen deshalb daneben statt im Stapel. Die Raumwärme des Ofens geht nicht durch den
            Puffer. Der Pufferinhalt rechts ist eine Menge in kWh, keine Leistung.
          </Note>
        </Card>
      ) : null}

      <Card style={{ padding: 16 }}>
        <CardHead
          title={period === "day" ? "Je Stunde" : period === "year" ? "Je Monat" : "Je Tag"}
          right={<ChartLegend items={BUCKET_SERIES.map((s) => ({ color: s.color, name: s.name }))} />}
        />
        {data && data.buckets.length > 0 ? (
          <div className="mt-2 h-[240px]">
            {/* Der Balkenstapel will Beschriftung und Werte getrennt; die Bilanz liefert sie flach. */}
            <EChart option={stackedBars(data.buckets.map((b) => ({ label: b.label_de, totals: b })), BUCKET_SERIES)} />
          </div>
        ) : (
          <Note>Für diesen Zeitraum liegen keine Werte vor.</Note>
        )}
      </Card>

      <Card style={{ padding: 16 }}>
        <CardHead title="Was die Wärme gekostet hat" right={data?.cost.cheaper_de} />
        <div className="mt-2 grid gap-x-8 md:grid-cols-2">
          <div>
            <Param k="Wärmepumpe: bezahlter Netzstrom" v={euro(data?.cost.heat_pump_paid_eur)} />
            <Param k="Wärmepumpe: entgangene Vergütung" v={euro(data?.cost.heat_pump_opportunity_eur)} />
            <Param k="Wärmepumpe: je kWh Wärme" v={ct(data?.cost.heat_pump_ct_per_kwh)} />
          </div>
          <div>
            <Param k="Pellets: verbrannte Menge" v={data ? `${de1(data.cost.stove_kg, 1)} kg` : "-"} />
            <Param k="Pellets: Wert zum hinterlegten Preis" v={euro(data?.cost.stove_eur)} />
            <Param k="Ofen: je kWh Wärme" v={ct(data?.cost.stove_ct_per_kwh)} />
          </div>
        </div>
        <Note>
          Die beiden Zahlen sind nicht gleicher Art. Der Strom der Wärmepumpe ist geflossen und
          bezahlt worden, und dazu gehört die entgangene Einspeisevergütung für PV-Strom, der statt
          ins Netz in den Verdichter ging - ohne sie sähe jede sonnige Stunde kostenlos aus. Die
          Pellets sind längst bezahlt, als sie geliefert wurden; hier steht, was die in diesem
          Zeitraum verbrannte Menge zum hinterlegten Preis wert war. Die Menge ist geschätzt: der
          Ofen meldet keine Kilogramm, sondern seine Leistungsstufe.
        </Note>
      </Card>

      <PeriodStrip title="Wärme im Zeitraum" rows={rows} anchor={anchor} />

      <Card style={{ padding: 16 }}>
        <CardHead title="Womit gerechnet wird" right={data?.resolution_de} />
        <div className="mt-2 grid gap-x-8 md:grid-cols-2">
          <div>
            <Param k="COP-Kennlinie (Außentemperatur → COP)" v={(p?.cop_curve ?? []).map(([a, b]) => `${de1(a, 0)}°C: ${de1(b, 1)}`).join(" · ") || "-"} />
            <Param k="Kennlinie gilt bei Vorlauf" v={`${de1(p?.cop_reference_c, 0)} °C`} />
            <Param k="Puffer" v={`${de1(p?.buffer_volume_liters, 0)} l · Verlust ${de1((p?.buffer_loss_kw_per_k ?? 0) * 1000, 0)} W/K`} />
            <Param k="Aufstellraum für den Verlust" v={p?.room_source_de ?? "-"} />
          </div>
          <div>
            <Param k="Ofen Volllast" v={`${de1(p?.stove_nominal_heat_kw, 1)} kW, davon ${de1(p?.stove_water_heat_kw, 1)} kW ins Wasser`} />
            <Param k="Ofen Minimallast" v={`${de1(p?.stove_min_heat_kw, 1)} kW, davon ${de1(p?.stove_min_water_heat_kw, 1)} kW ins Wasser`} />
            <Param k="Verbrennungswirkungsgrad" v={`${de1((p?.stove_combustion_efficiency ?? 0) * 100, 1)} %`} />
            <Param k="Heizwert der Pellets" v={`${de1(p?.pellet_kwh_per_kg, 2)} kWh/kg · ${de1(p?.pellet_price_eur_per_t, 0)} €/t`} />
          </div>
        </div>
        <Note>
          {data?.note_de} {vergleich} {data?.forecast_note_de}
        </Note>
        <Note>
          Die Arbeitszahl folgt der Kennlinie über der Außentemperatur und wird über das Verhältnis
          der Carnot-Zahlen auf den wirklichen Hub umgerechnet: dieselbe Maschine liefert bei 40 °C
          Vorlauf deutlich mehr als bei 58 °C, und der Puffer durchläuft an einem Wintertag beides.
          Die Zahlen oben sind Annahmen und keine Messung; wer sie ändert, ändert jede Zahl auf
          dieser Seite, auch die vergangener Jahre.
        </Note>
      </Card>
    </ReportShell>
  );
}
