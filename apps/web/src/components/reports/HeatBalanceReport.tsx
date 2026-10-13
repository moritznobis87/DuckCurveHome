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
    { label: "Strom der Wärmepumpe", value: (x) => feld(alle[x], (t) => t.electric_kwh) },
    { label: "Arbeitszahl", value: (x) => (alle[x]?.totals.cop_mean == null ? "-" : de1(alle[x]?.totals.cop_mean, 2)), tone: "mist" },
    { label: "nicht zuzuordnen", value: (x) => feld(alle[x], (t) => t.residual_kwh), tone: "ember" },
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
        <Stat label="Entnahme" value={kwh(t?.draw_kwh)} unit="kWh" hint="Heizkreis und Warmwasser, als Rest der Bilanz" />
        <Stat label="Verlust" value={kwh(t?.loss_kwh)} unit="kWh" tone="mist" hint="an den Aufstellraum, nicht verloren" />
      </KpiGrid>

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

      <PeriodStrip title="Wärme im Zeitraum" rows={rows} anchor={anchor} />

      <Card style={{ padding: 16 }}>
        <CardHead title="Womit gerechnet wird" right={data?.resolution_de} />
        <div className="mt-2 grid gap-x-8 md:grid-cols-2">
          <div>
            <Param k="COP-Kennlinie (Außentemperatur → COP)" v={(p?.cop_curve ?? []).map(([a, b]) => `${de1(a, 0)}°C: ${de1(b, 1)}`).join(" · ") || "-"} />
            <Param k="Kennlinie gilt bei Vorlauf" v={`${de1(p?.cop_reference_c, 0)} °C`} />
            <Param k="Puffer" v={`${de1(p?.buffer_volume_liters, 0)} l · Verlust ${de1((p?.buffer_loss_kw_per_k ?? 0) * 1000, 0)} W/K`} />
            <Param k="Raumtemperatur für den Verlust" v={p?.room_source_de ?? "-"} />
          </div>
          <div>
            <Param k="Ofen Volllast" v={`${de1(p?.stove_nominal_heat_kw, 1)} kW, davon ${de1(p?.stove_water_heat_kw, 1)} kW ins Wasser`} />
            <Param k="Ofen Minimallast" v={`${de1(p?.stove_min_heat_kw, 1)} kW, davon ${de1(p?.stove_min_water_heat_kw, 1)} kW ins Wasser`} />
            <Param k="Verbrennungswirkungsgrad" v={`${de1((p?.stove_combustion_efficiency ?? 0) * 100, 1)} %`} />
            <Param k="Heizwert der Pellets" v={`${de1(p?.pellet_kwh_per_kg, 2)} kWh/kg · ${de1(p?.pellet_price_eur_per_t, 0)} €/t`} />
          </div>
        </div>
        <Note>
          {data?.note_de} {vergleich}
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
