"use client";

import { useEffect, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { HeatConfigIn, HemsConfig } from "@/lib/api/models";

/**
 * Die Annahmen der Wärmerechnung von Hand stellen.
 *
 * **Warum diese Werte hier stehen und nicht in der Konfigurationsdatei.** Sie stammen nicht aus der
 * Regelung, sondern vom Gerät und vom Lieferschein: was auf dem Sack Pellets steht, was das
 * Datenblatt des Ofens nennt, wie warm der Puffer gefahren wird. Das sind Zahlen, die der Hausherr
 * kennt und nachtragen können muss, ohne eine Datei zu bearbeiten und den Dienst neu zu starten.
 * Regelparameter bleiben draußen; eine falsche Zahl dort fällt beim Start auf und nicht nachts.
 *
 * **Jede Änderung wirkt rückwirkend.** Gespeichert sind Messwerte und keine Rechenergebnisse, die
 * Auswertung rechnet bei jeder Abfrage neu. Ein korrigierter Heizwert verändert deshalb auch die
 * Jahreszahlen von letztem Jahr. Das ist der Zweck: eine Annahme, die nur nach vorn wirkt, lässt die
 * Vergangenheit falsch stehen, ohne dass es jemandem auffällt.
 */
type Feld = {
  key: keyof HeatConfigIn;
  label: string;
  unit: string;
  step: number;
  hint?: string;
};

const FELDER: Feld[] = [
  { key: "stove_nominal_heat_kw", label: "Ofen: Leistung bei Volllast", unit: "kW", step: 0.1 },
  { key: "stove_water_heat_kw", label: "Ofen: davon ins Wasser", unit: "kW", step: 0.1, hint: "Der Rest heizt den Aufstellraum." },
  { key: "stove_min_heat_kw", label: "Ofen: Leistung bei Minimallast", unit: "kW", step: 0.1 },
  { key: "stove_min_water_heat_kw", label: "Ofen: davon ins Wasser", unit: "kW", step: 0.1 },
  { key: "stove_combustion_efficiency", label: "Verbrennungswirkungsgrad", unit: "0 bis 1", step: 0.001, hint: "Datenblatt, Volllast. Bei Teillast ist er meist besser." },
  { key: "pellet_kwh_per_kg", label: "Heizwert der Pellets", unit: "kWh/kg", step: 0.01, hint: "ENplus A1 liegt zwischen 4,9 und 5,3. Steht auf dem Lieferschein." },
  { key: "pellet_price_eur_per_t", label: "Pelletpreis", unit: "€/t", step: 1 },
  { key: "buffer_volume_liters", label: "Puffervolumen", unit: "l", step: 10 },
  { key: "buffer_target_temperature_c", label: "Zieltemperatur des Puffers", unit: "°C", step: 1, hint: "Zugleich der Vorlauf, bei dem die COP-Kennlinie gilt." },
  { key: "buffer_loss_kw_per_k", label: "Verlustbeiwert des Puffers", unit: "kW/K", step: 0.001, hint: "0,004 kW/K sind 4 Watt je Kelvin Übertemperatur." },
  { key: "indoor_target_c", label: "Raumtemperatur, ersatzweise", unit: "°C", step: 0.5, hint: "Gilt nur, wenn der Raumfühler des Ofens nichts meldet." },
];

/** Die Kennlinie als Textzeile: „-7:2.4, 2:3.0, 7:3.5, 15:4.2". Kürzer als elf Eingabefelder. */
function kurveZuText(kurve: Array<[number, number]> | undefined): string {
  return (kurve ?? []).map(([t, c]) => `${t}:${c}`).join(", ");
}

function textZuKurve(text: string): Array<[number, number]> | null {
  const paare = text
    .split(/[,;]/)
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s) => s.split(":").map((x) => Number(x.replace(",", "."))));
  if (!paare.length || paare.some((p) => p.length !== 2 || p.some((n) => !Number.isFinite(n)))) return null;
  return paare.map((p) => [p[0]!, p[1]!] as [number, number]);
}

function Zeile({ f, wert, onChange }: { f: Feld; wert: string; onChange: (v: string) => void }) {
  return (
    <label className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 border-b border-line-1 py-2 last:border-b-0">
      <span className="flex-1 text-[14px] text-text-2">
        {f.label}
        {f.hint ? <span className="block text-[12px] leading-[1.5] text-text-3">{f.hint}</span> : null}
      </span>
      <span className="flex items-baseline gap-2">
        <input
          type="number"
          step={f.step}
          value={wert}
          onChange={(e) => onChange(e.target.value)}
          className="mono w-[108px] rounded-[2px] border border-line-2 bg-surface-3 px-2 py-1 text-right text-[13px] text-text-1"
        />
        <span className="mono w-[52px] text-[12px] text-text-3">{f.unit}</span>
      </span>
    </label>
  );
}

export function HeatSettings() {
  const [cfg, setCfg] = useState<HemsConfig | null>(null);
  const [werte, setWerte] = useState<Record<string, string>>({});
  const [kurve, setKurve] = useState("");
  const [meldung, setMeldung] = useState<string | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, setLaeuft] = useState(false);

  const uebernehmen = (c: HemsConfig) => {
    setCfg(c);
    setWerte({
      stove_nominal_heat_kw: String(c.stove.nominal_heat_kw),
      stove_water_heat_kw: String(c.stove.water_heat_kw),
      stove_min_heat_kw: String(c.stove.min_heat_kw),
      stove_min_water_heat_kw: String(c.stove.min_water_heat_kw),
      stove_combustion_efficiency: String(c.stove.combustion_efficiency),
      pellet_kwh_per_kg: String(c.stove.pellet_kwh_per_kg),
      pellet_price_eur_per_t: String(c.stove.pellet_price_eur_per_t),
      buffer_volume_liters: String(c.buffer.volume_liters),
      buffer_target_temperature_c: String(c.buffer.target_temperature_c),
      buffer_loss_kw_per_k: String(c.buffer.loss_kw_per_k),
      indoor_target_c: String(c.heat_demand.indoor_target_c),
    });
    setKurve(kurveZuText(c.heat_demand.cop_curve as Array<[number, number]>));
  };

  useEffect(() => {
    api
      .heatConfig()
      .then(uebernehmen)
      .catch(() => setFehler("Die Konfiguration konnte nicht geladen werden."));
  }, []);

  const speichern = async () => {
    setLaeuft(true);
    setMeldung(null);
    setFehler(null);
    const patch: Record<string, unknown> = {};
    for (const f of FELDER) {
      const roh = werte[f.key];
      if (roh === undefined || roh === "") continue;
      const n = Number(roh.replace(",", "."));
      if (Number.isFinite(n)) patch[f.key] = n;
    }
    const k = textZuKurve(kurve);
    if (!k) {
      setFehler("Die Kennlinie wird als Temperatur:COP geschrieben, Stützpunkte mit Komma getrennt.");
      setLaeuft(false);
      return;
    }
    patch.cop_curve = k;
    try {
      const neu = await api.setHeatConfig(patch as HeatConfigIn);
      uebernehmen(neu);
      setMeldung("Übernommen. Die Auswertungen rechnen ab sofort damit, auch rückwirkend.");
    } catch (e) {
      // Der Dienst prüft Widersprüche, die ein einzelnes Feld nicht sehen kann: der Wasseranteil
      // gegen die Gesamtleistung, die Zieltemperatur gegen die Grenzen des Puffers. Seine Begründung
      // ist genauer als alles, was die Oberfläche sagen könnte.
      setFehler(e instanceof ApiError ? e.message : "Die Änderung wurde nicht übernommen.");
    } finally {
      setLaeuft(false);
    }
  };

  if (!cfg) return <p className="m-0 text-[14px] text-text-3">{fehler ?? "lädt …"}</p>;

  return (
    <div className="flex flex-col gap-3">
      <div className="grid gap-x-8 md:grid-cols-2">
        <div>
          {FELDER.slice(0, 6).map((f) => (
            <Zeile key={f.key} f={f} wert={werte[f.key] ?? ""} onChange={(v) => setWerte((w) => ({ ...w, [f.key]: v }))} />
          ))}
        </div>
        <div>
          {FELDER.slice(6).map((f) => (
            <Zeile key={f.key} f={f} wert={werte[f.key] ?? ""} onChange={(v) => setWerte((w) => ({ ...w, [f.key]: v }))} />
          ))}
        </div>
      </div>

      <label className="flex flex-col gap-1.5">
        <span className="text-[14px] text-text-2">COP-Kennlinie über der Außentemperatur</span>
        <span className="text-[12px] leading-[1.5] text-text-3">
          Stützpunkte als <code className="mono">Temperatur:COP</code>, aufsteigend, mit Komma
          getrennt. Sie gilt bei der Zieltemperatur des Puffers; auf den wirklichen Vorlauf wird über
          das Verhältnis der Carnot-Zahlen umgerechnet. Ein zweidimensionales Kennfeld ist das nicht,
          und es wäre auch keines: dafür müsste jede Stützstelle gemessen sein.
        </span>
        <input
          value={kurve}
          onChange={(e) => setKurve(e.target.value)}
          className="mono rounded-[2px] border border-line-2 bg-surface-3 px-3 py-2 text-[13px] text-text-1"
        />
      </label>

      <div className="flex flex-wrap items-center gap-4">
        <button
          onClick={() => void speichern()}
          disabled={laeuft}
          className="rounded-[2px] px-4 py-2 text-[13px] font-medium"
          style={{ background: "var(--amber)", color: "var(--petrol)", opacity: laeuft ? 0.6 : 1 }}
        >
          {laeuft ? "wird übernommen …" : "Übernehmen"}
        </button>
        {meldung ? <span className="text-[13px] text-text-2">{meldung}</span> : null}
        {fehler ? <span className="text-[13px]" style={{ color: "var(--alert)" }}>{fehler}</span> : null}
      </div>
    </div>
  );
}
