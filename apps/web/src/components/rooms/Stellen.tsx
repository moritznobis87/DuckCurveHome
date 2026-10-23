"use client";

import { useEffect, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { RoomEffect, RoomLive } from "@/lib/api/models";
import { celsius } from "@/lib/format";
import { zahl1 } from "./palette";

/**
 * Das Fenster, in dem ein Raum seinen Sollwert bekommt.
 *
 * **Dauerhaft, ohne Frist.** Wer hier dreht, meint es so, bis er es anders meint - genau wie in
 * Contromes eigener Oberflaeche. Ein Wert auf Zeit waere eine zweite Wahrheit neben der, die der
 * Regler kennt.
 *
 * **Die Wirkung steht daneben, bevor gestellt wird.** Ein halbes Grad mehr kostet etwas, und zwar
 * jeden Tag; dieselbe Waerme vor einem Preishoch eingelagert bringt etwas. Beide Zahlen rechnet
 * die API aus dem Verlustkoeffizienten des Hauses, dem Anteil dieses Raums an den Heizkreisen und
 * der Zeitkonstante - geschaetzt, und das steht auch da. Ohne sie waere die Frage „soll ich?" eine
 * Gefuehlssache.
 *
 * **Gaeste sehen alles und stellen nichts.** Der Knopf bleibt sichtbar und sagt, warum er nicht
 * geht; ein fehlender Knopf laesst suchen.
 */
// **Verstellt wird in halben Graden, gerundet auf Zehntel.** Die Stufe der Knoepfe ist eine Frage
// der Bedienung, das Raster eine der Wahrheit: Controme fuehrt Zehntel, und ein Raum dieser
// Anlage steht auf 22,2. Wer ihn auf 22,0 zoege, weil die Oberflaeche ein halbes Grad fuer die
// einzig moegliche Stufe haelt, haette ihn verstellt, ohne es zu sagen.
const SCHRITT = 0.5;
// Fuenf Grad, weil ein Raum dieses Hauses auf Frostschutz steht (8,0 Grad, gesehen am
// 23.10.2026). Eine Untergrenze darueber machte diesen Wert unerreichbar.
const MIN = 5;
const MAX = 30;
/** So lange wird nach der letzten Berührung gewartet, bevor die Wirkung neu gerechnet wird. */
const RUHE_MS = 300;

function Zeile({ k, v, stark = false }: { k: string; v: string; stark?: boolean }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-line-1 py-1.5 last:border-b-0">
      <span className="text-[13px] text-text-3">{k}</span>
      <span className={`mono text-[13px] ${stark ? "text-text-1" : "text-text-2"}`}>{v}</span>
    </div>
  );
}

export function Stellen({ raum, readOnly, onClose, onDone }: { raum: RoomLive; readOnly: boolean; onClose: () => void; onDone: () => void }) {
  const aktuell = raum.setpoint_c ?? 21;
  // Angefangen wird beim Wert, der dasteht - nicht beim naechsten Rasterpunkt.
  const [soll, setSoll] = useState(Math.round(aktuell * 10) / 10);
  const [wirkung, setWirkung] = useState<RoomEffect | null>(null);
  const [busy, setBusy] = useState(false);
  const [fehler, setFehler] = useState<string | null>(null);
  const [fertig, setFertig] = useState<string | null>(null);
  const delta = Math.round((soll - aktuell) * 100) / 100;

  // Die Wirkung kommt vom Dienst, nicht aus dem Browser: dieselbe Rechnung, die auch der Planer
  // benutzt, und sie kennt Wetter und Preise. Bei delta 0 wird 0,5 K gefragt, damit das Fenster
  // nicht leer ist, bevor jemand tippt.
  useEffect(() => {
    let alive = true;
    const t = setTimeout(() => {
      void api
        .roomEffect(raum.id, delta === 0 ? SCHRITT : delta)
        .then((w) => { if (alive) setWirkung(w); })
        .catch(() => { if (alive) setWirkung(null); });
    }, RUHE_MS);
    return () => { alive = false; clearTimeout(t); };
  }, [raum.id, delta]);

  const stellen = async () => {
    setBusy(true);
    setFehler(null);
    try {
      const r = await api.setRoomSetpoint(raum.id, soll);
      setFertig(r.message_de);
      onDone();
      setTimeout(onClose, 1200);
    } catch (e) {
      setFehler(e instanceof ApiError ? e.message : "Der Sollwert wurde nicht bestätigt.");
    } finally {
      setBusy(false);
    }
  };

  const eur = (n: number | null | undefined) => (n == null ? "-" : `${n.toFixed(2).replace(".", ",")} €`);
  // Kleine Mengen mit zwei Stellen: "0,1 kWh" neben einem Satz, der 0,14 sagt, sieht nach
  // Widerspruch aus.
  const kwh = (n: number) => `${(Math.abs(n) < 1 ? n.toFixed(2) : n.toFixed(1)).replace(".", ",")} kWh`;
  const zeichen = delta > 0 ? "+" : "";

  return (
    <div className="raum-blende" role="dialog" aria-modal="true" aria-label={`${raum.name} stellen`} onClick={onClose}>
      <div className="raum-blatt" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-baseline justify-between gap-3">
          <span className="flex items-baseline gap-3">
            <span className="text-[19px] font-semibold tracking-[-.01em]">{raum.name}</span>
            <span className="kicker" style={{ fontSize: 11 }}>{raum.floor}</span>
          </span>
          <button onClick={onClose} className="text-[13px] text-text-3" aria-label="Schließen">schließen</button>
        </div>

        <div className="flex items-center justify-between gap-4">
          <button
            onClick={() => setSoll((s) => Math.max(MIN, Math.round((s - SCHRITT) * 10) / 10))}
            disabled={soll <= MIN}
            aria-label="Ein halbes Grad weniger"
            className="raum-knopf"
          >
            −
          </button>
          <div className="flex flex-col items-center gap-1">
            <span className="mono text-[46px] font-medium leading-none tracking-[-.03em]">{zahl1(soll)}<span className="text-[18px] text-text-3"> °C</span></span>
            <span className="mono text-[12px]" style={{ color: delta === 0 ? "var(--text-3)" : "var(--amber-soft)" }}>
              {delta === 0 ? "unverändert" : `${zeichen}${zahl1(delta)} K gegenüber jetzt`}
            </span>
          </div>
          <button
            onClick={() => setSoll((s) => Math.min(MAX, Math.round((s + SCHRITT) * 10) / 10))}
            disabled={soll >= MAX}
            aria-label="Ein halbes Grad mehr"
            className="raum-knopf"
          >
            +
          </button>
        </div>

        <div className="flex flex-col">
          <Zeile k="gemessen" v={celsius(raum.temp_c, 1)} stark />
          <Zeile k="Sollwert jetzt" v={celsius(raum.setpoint_c, 1)} />
          <Zeile k="Offset der Regelung" v={raum.offset_k == null ? "-" : `${raum.offset_k > 0 ? "+" : ""}${zahl1(raum.offset_k)} K`} />
          <Zeile k="geregelt wird auf" v={celsius(raum.target_c, 1)} />
        </div>

        {/* Die Schätzung. Sie steht unter einer eigenen Überschrift, weil sie etwas anderes ist
            als die Messwerte darüber: gerechnet, nicht gemessen. */}
        <div className="flex flex-col gap-1.5 rounded-[6px] border border-line-1 p-3">
          <span className="kicker" style={{ fontSize: 11 }}>Was das bedeutet, geschätzt</span>
          {wirkung ? (
            <>
              <Zeile k={`${wirkung.delta_k > 0 ? "+" : ""}${zahl1(wirkung.delta_k)} K kosten am Tag`} v={`${eur(wirkung.daily_eur)} · ${kwh(wirkung.daily_kwh_el)} Strom`} stark />
              <Zeile k="einmal aufladen" v={`${kwh(wirkung.store_kwh_el)} Strom`} />
              {wirkung.shift_saving_eur != null ? (
                <Zeile k="davor laden statt im Preishoch" v={`${wirkung.shift_saving_eur > 0 ? "spart " : "kostet "}${eur(Math.abs(wirkung.shift_saving_eur))}`} />
              ) : null}
              <Zeile k="halbe Wirkung weg nach" v={`${zahl1(wirkung.half_life_h)} h`} />
              <p className="m-0 pt-1 text-[11px] leading-[1.5] text-text-3">{wirkung.note_de}</p>
            </>
          ) : (
            <p className="m-0 text-[13px] text-text-3">rechnet …</p>
          )}
        </div>

        {fehler ? <p className="m-0 text-[13px]" style={{ color: "var(--alert)" }}>{fehler}</p> : null}
        {fertig ? <p className="m-0 text-[13px]" style={{ color: "var(--pv)" }}>{fertig}</p> : null}
        {readOnly ? <p className="m-0 text-[12px] text-text-3">Nur Ansicht: dieses Gerät sieht zu, stellt aber nichts.</p> : null}

        <div className="flex gap-2">
          <button onClick={onClose} className="raum-aktion" style={{ borderColor: "var(--line-2)", color: "var(--text-2)" }}>
            Abbrechen
          </button>
          <button
            onClick={() => void stellen()}
            disabled={busy || readOnly || delta === 0}
            className="raum-aktion"
            style={{ borderColor: "var(--amber)", background: delta === 0 || readOnly ? "transparent" : "var(--amber)", color: delta === 0 || readOnly ? "var(--text-3)" : "var(--petrol)" }}
          >
            {busy ? "stellt …" : "Übernehmen"}
          </button>
        </div>
      </div>
    </div>
  );
}
