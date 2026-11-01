"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { RoomLog, RoomLogEntry } from "@/lib/api/models";
import { celsius } from "@/lib/format";
import { anteilText, KEIN_WERT } from "./palette";
import { artText, fahnenPosition, fensterText, indexFuerAnteil, pfad, QUELLE_FARBE, QUELLE_WORT, spanne, sprungText, ueberschrift, verdichte, wertText, xFuerZeit, yFuerWert, zeitMarken } from "./protokoll";

/**
 * Das Protokoll eines Raums: was gemessen wurde, worauf geregelt wurde, und wer daran gedreht hat.
 *
 * **Wofür es gedacht ist.** Ein Raum ist wärmer, als er soll, und die Frage lautet: Woran lag es?
 * Die Kachel auf der Raumseite zeigt den Verlauf, aber nicht die Ursache. Hier stehen beide
 * übereinander - die Kurve oben, die Zeitleiste darunter - und zwar über denselben Zeitraum, so
 * dass ein Knick in der Kurve und die Zeile, die ihn erklärt, senkrecht untereinander liegen.
 *
 * **Drei Herkünfte, und die dritte ist die ehrliche.** `hier gestellt` und `Automatik` sind
 * belegt: Zu ihnen gibt es einen Protokolleintrag mit Begründung. `von außen` heißt nur, dass
 * dieses Werkzeug es nicht war - dahinter steckt die Controme-App, das Bedienteil an der Wand
 * oder Contromes eigenes Heizprogramm. Diese drei lassen sich von hier nicht unterscheiden, und
 * sie alle „Nutzeränderung" zu nennen wäre eine Behauptung über einen Menschen.
 *
 * **Ventil und Fenster stehen darunter**, weil sie die Kurve erklären, ohne dass jemand etwas
 * gestellt hat: Ein Raum, der ohne Sollwertänderung wärmer wird, hatte entweder lange offene
 * Kreise oder ein geschlossenes Fenster, hinter dem vorher gelüftet wurde.
 */

/** Die Breite des Koordinatensystems. Die Anzeige skaliert es per `viewBox` auf ihre Breite. */
const BREITE = 1000;
const HOEHE = 170;

/** Welche Fensterbreite zu welchem Rückblick passt.
 *
 *  **Die Sprünge hängen nicht daran.** Sie kommen im Dienst aus den Minutenzeilen, nicht aus
 *  diesen Fenstern; die Verdichtung betrifft nur die Kurve. Zwei Tage in Fünfminutenschritten
 *  wären 576 Punkte auf wenigen hundert Bildpunkten - sichtbar wäre davon nichts. */
const STUFEN = [
  { stunden: 24, stepMin: 5, wort: "24 h" },
  { stunden: 48, stepMin: 15, wort: "48 h" },
] as const;

function Streifen({ serie, farbe, titel, label, jeStunde }: { serie: (number | null)[]; farbe: string; titel: string; label: string; jeStunde: number }) {
  const felder = verdichte(serie, jeStunde);
  return (
    <div className="flex items-center gap-2">
      <span className="kicker w-[52px] shrink-0 text-right" style={{ fontSize: 10 }}>{label}</span>
      <div className="flex h-[8px] flex-1 gap-px" role="img" aria-label={titel}>
        {felder.map((v, i) => (
          <span
            key={i}
            style={{
              flex: "1 1 0",
              borderRadius: 1,
              background: v == null ? KEIN_WERT : v > 0 ? farbe : "rgba(255,255,255,.07)",
              opacity: v == null || v === 0 ? 1 : 0.35 + 0.65 * v,
            }}
          />
        ))}
      </div>
    </div>
  );
}

function Zeile({ e }: { e: RoomLogEntry }) {
  const zeit = new Date(e.at);
  const sprung = sprungText(e);
  return (
    <li className="flex gap-3 border-b border-line-1 py-2 last:border-b-0">
      <span className="mono w-[86px] shrink-0 text-[11px] text-text-3">
        {zeit.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" })}
        {" "}
        {zeit.toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" })}
      </span>
      <span
        className="mono h-fit shrink-0 rounded-[2px] px-[5px] py-px text-[10px] uppercase tracking-[.08em]"
        style={{ border: `1px solid ${QUELLE_FARBE[e.quelle]}`, color: QUELLE_FARBE[e.quelle] }}
      >
        {QUELLE_WORT[e.quelle]}
      </span>
      <span className="min-w-0 flex-1">
        <span className="flex flex-wrap items-baseline gap-x-2">
          {sprung ? <span className="mono whitespace-nowrap text-[13px] text-text-1">{sprung} °C</span> : null}
          {/* **Wer es war, steht neben dem Wert, nicht im Satz darunter.** Das ist die Frage, mit
              der jemand dieses Protokoll aufmacht; sie soll nicht am Ende einer Zeile stehen, die
              man erst lesen muss. Ist das Feld leer, steht hier nichts - leer heißt unbekannt,
              und „unbekannt" hinzuschreiben fuellte die Liste mit einer Nichtauskunft. */}
          {e.urheber ? (
            <span className="mono whitespace-nowrap text-[11px] text-text-2">{e.urheber}</span>
          ) : null}
        </span>
        {/* Der Text des Dienstes, wenn es einen gibt - er trägt die Begründung der Automatik.
            Sonst die Art in eigenen Worten, damit keine Zeile stumm bleibt. */}
        <span className="block text-[12px] leading-[1.45] text-text-3">{e.text || artText(e)}</span>
      </span>
    </li>
  );
}

export function Protokoll({ roomId, name, floor, onClose }: { roomId: number; name: string; floor: string; onClose: () => void }) {
  const [stufe, setStufe] = useState<(typeof STUFEN)[number]>(STUFEN[1]);
  const [log, setLog] = useState<RoomLog | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  // Welcher Punkt der Kurve gerade abgelesen wird. Ein Index, kein Pixel: Die Fahne soll den
  // gemessenen Wert zeigen, nicht einen zwischen zwei Messungen interpolierten.
  const [marke, setMarke] = useState<number | null>(null);

  useEffect(() => {
    let lebt = true;
    setLog(null);
    setFehler(null);
    setMarke(null);
    void api
      .roomLog(roomId, stufe.stunden, stufe.stepMin)
      .then((l) => { if (lebt) setLog(l); })
      .catch(() => { if (lebt) setFehler("Das Protokoll konnte nicht geladen werden."); });
    return () => { lebt = false; };
  }, [roomId, stufe]);

  // Escape schließt. Wer ein Fenster über einer Liste öffnet, erwartet das.
  useEffect(() => {
    const auf = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", auf);
    return () => window.removeEventListener("keydown", auf);
  }, [onClose]);

  const s = log ? spanne([log.room.temp_c, log.target_c]) : null;
  // Ein Feld der Streifen ist eine Stunde. Die Fensterbreite kommt aus der Antwort, nicht aus
  // der Stufe: Liefert die Schnittstelle eines Tages eine andere, bleiben es Stunden.
  const jeStunde = Math.max(1, Math.round(60 / (log?.step_min ?? stufe.stepMin)));

  // Der Finger wandert ueber den Rahmen; daraus wird ein Anteil der Breite und daraus ein Punkt.
  const zeige = (clientX: number, el: HTMLElement) => {
    if (!log || log.ts.length === 0) return;
    const r = el.getBoundingClientRect();
    if (r.width <= 0) return;
    setMarke(indexFuerAnteil((clientX - r.left) / r.width, log.ts.length));
  };

  const letzter = log ? Math.max(1, log.ts.length - 1) : 1;
  const markeX = marke == null ? null : (marke / letzter) * BREITE;
  const markeTempY = marke == null || !s ? null : yFuerWert(log?.room.temp_c[marke], s, HOEHE);
  const markeZielY = marke == null || !s ? null : yFuerWert(log?.target_c[marke], s, HOEHE);
  // **Die Fahne weicht der Kurve aus.** Liegt der abgelesene Punkt oben, haengt sie unten und
  // umgekehrt. Fest oben angeschlagen verdeckte sie bei warmen Raeumen genau die Punkte, die sie
  // beschriftet - und man las eine Zahl, ohne zu sehen, wo sie herkommt.
  const fahneUnten = markeTempY != null && markeTempY < HOEHE / 2;

  return (
    <div className="raum-blende" role="dialog" aria-modal="true" aria-label={`Protokoll ${name}`} onClick={onClose}>
      <div className="raum-blatt raum-blatt-breit" onClick={(e) => e.stopPropagation()} onPointerDown={() => setMarke(null)}>
        <div className="flex items-baseline justify-between gap-3">
          <span className="flex items-baseline gap-3">
            <span className="text-[19px] font-semibold tracking-[-.01em]">{name}</span>
            <span className="kicker" style={{ fontSize: 11 }}>{floor}</span>
          </span>
          <span className="flex items-center gap-3">
            <span className="flex gap-1">
              {STUFEN.map((x) => (
                <button
                  key={x.stunden}
                  onClick={() => setStufe(x)}
                  className="mono whitespace-nowrap rounded-[3px] border px-2 py-[3px] text-[11px]"
                  style={{
                    borderColor: x.stunden === stufe.stunden ? "var(--amber)" : "var(--line-2)",
                    color: x.stunden === stufe.stunden ? "var(--amber)" : "var(--text-3)",
                  }}
                >
                  {x.wort}
                </button>
              ))}
            </span>
            <button onClick={onClose} className="text-[13px] text-text-3" aria-label="Schließen">schließen</button>
          </span>
        </div>

        {fehler ? <p className="m-0 text-[13px]" style={{ color: "var(--alert)" }}>{fehler}</p> : null}
        {!log && !fehler ? <p className="m-0 text-[13px] text-text-3">lädt …</p> : null}

        {log && s ? (
          <>
            <p className="m-0 text-[13px] text-text-2">{ueberschrift(log.entries, stufe.stunden)}</p>

            <div className="flex flex-col gap-2">
              {/* **Die Ablesefläche liegt über der Zeichnung, nicht in ihr.** Das SVG ist auf
                  `preserveAspectRatio="none"` verzerrt; Mauszeiger darin umzurechnen hieße, die
                  Verzerrung nachzurechnen. Der Rahmen daneben hat echte Bildpunkte, und aus
                  denen wird ein Anteil der Breite - der gilt in beiden Welten. */}
              <div
                className="relative"
                style={{ touchAction: "none", cursor: "crosshair" }}
                onPointerMove={(e) => zeige(e.clientX, e.currentTarget)}
                // Haelt das Ereignis hier fest: Das Blatt darueber raeumt bei jedem Tipp die
                // Fahne weg, und ohne das Anhalten loeschte der eigene Tipp sie sofort wieder.
                onPointerDown={(e) => { e.stopPropagation(); zeige(e.clientX, e.currentTarget); }}
                // **Nur die Maus raeumt beim Verlassen auf.** Ein Finger verlaesst die Flaeche in
                // dem Augenblick, in dem er hochgeht - die Fahne waere weg, bevor jemand sie
                // lesen kann, und ein Tippen zeigte gar nichts. Der abgelesene Wert bleibt
                // deshalb stehen, bis woanders hingetippt oder das Fenster geschlossen wird.
                onPointerLeave={(e) => { if (e.pointerType === "mouse") setMarke(null); }}
                onPointerCancel={() => setMarke(null)}
              >
                <svg viewBox={`0 0 ${BREITE} ${HOEHE}`} preserveAspectRatio="none" style={{ width: "100%", height: 170, display: "block" }} role="img" aria-label={`Temperaturverlauf ${name}`}>
                  {/* Die Zielkurve zuerst, damit die gemessene darüber liegt: Sie ist die Antwort,
                      die andere der Maßstab. */}
                  <path d={pfad(log.target_c, s, BREITE, HOEHE)} fill="none" stroke="var(--text-3)" strokeWidth={2} strokeDasharray="6 5" vectorEffect="non-scaling-stroke" />
                  <path d={pfad(log.room.temp_c, s, BREITE, HOEHE)} fill="none" stroke="var(--amber)" strokeWidth={2} vectorEffect="non-scaling-stroke" />
                  {/* Jede Sollwertänderung als senkrechte Marke in der Farbe ihrer Herkunft. Damit
                      liegt der Knick in der Kurve und sein Grund auf derselben Senkrechten. */}
                  {log.entries
                    .filter((e) => e.art === "sollwert")
                    .map((e, i) => {
                      const x = xFuerZeit(e.at, log.ts, BREITE);
                      return x == null ? null : (
                        <line key={i} x1={x} x2={x} y1={0} y2={HOEHE} stroke={QUELLE_FARBE[e.quelle]} strokeWidth={1} strokeDasharray="3 3" vectorEffect="non-scaling-stroke" opacity={0.75} />
                      );
                    })}

                  {/* Das Fadenkreuz. Die Punkte sitzen auf den Kurven, nicht auf dem Finger:
                      Abgelesen wird der Messwert, nicht die Stelle, auf die jemand zeigt. */}
                  {markeX != null ? (
                    <>
                      <line x1={markeX} x2={markeX} y1={0} y2={HOEHE} stroke="var(--text-2)" strokeWidth={1} vectorEffect="non-scaling-stroke" opacity={0.6} />
                      {markeZielY != null ? (
                        <circle cx={markeX} cy={markeZielY} r={4} fill="var(--petrol)" stroke="var(--text-3)" strokeWidth={2} vectorEffect="non-scaling-stroke" />
                      ) : null}
                      {markeTempY != null ? (
                        <circle cx={markeX} cy={markeTempY} r={4} fill="var(--petrol)" stroke="var(--amber)" strokeWidth={2} vectorEffect="non-scaling-stroke" />
                      ) : null}
                    </>
                  ) : null}
                </svg>

                {/* Die Fahne. Sie liegt über der Zeichnung und fängt keine Zeiger ab, sonst
                    verlöre die Fläche darunter den Finger, sobald er die Fahne berührt. */}
                {marke != null ? (
                  <div
                    className="pointer-events-none absolute z-10 rounded-[6px] border border-line-2 px-2.5 py-2"
                    style={{
                      left: `${fahnenPosition(marke / Math.max(1, log.ts.length - 1))}%`,
                      [fahneUnten ? "bottom" : "top"]: 4,
                      transform: "translateX(-50%)",
                      background: "rgba(5,26,36,.95)",
                      minWidth: 168,
                    }}
                  >
                    <div className="mono whitespace-nowrap text-[10px] uppercase tracking-[.08em] text-text-3">{fensterText(log.ts, marke, log.step_min)}</div>
                    <div className="mt-1 flex flex-col gap-[2px]">
                      <span className="mono flex items-center justify-between gap-3 whitespace-nowrap text-[12px]">
                        <span style={{ color: "var(--amber)" }}>gemessen</span>
                        <span className="text-text-1">{wertText(log.room.temp_c[marke])}</span>
                      </span>
                      <span className="mono flex items-center justify-between gap-3 whitespace-nowrap text-[12px]">
                        <span className="text-text-3">geregelt auf</span>
                        <span className="text-text-2">{wertText(log.target_c[marke])}</span>
                      </span>
                      <span className="mono flex items-center justify-between gap-3 whitespace-nowrap text-[12px]">
                        <span className="text-text-3">Ventil</span>
                        <span className="text-text-2">{anteilText(log.room.valve[marke])}</span>
                      </span>
                      {log.room.window[marke] != null && log.room.window[marke]! > 0 ? (
                        <span className="mono whitespace-nowrap text-[12px]" style={{ color: "var(--mist)" }}>Fenster offen</span>
                      ) : null}
                    </div>
                  </div>
                ) : null}
              </div>

              <div className="mono flex justify-between text-[10px] text-text-3">
                {zeitMarken(log.ts).map((m, i) => (
                  <span key={i}>{m.text}</span>
                ))}
              </div>

              <div className="flex flex-col gap-1 pt-1">
                <Streifen serie={log.room.valve} farbe="var(--valve-open)" label="Ventil" titel="Ventilstellungen über den Zeitraum" jeStunde={jeStunde} />
                <Streifen serie={log.room.window} farbe="var(--alert)" label="Fenster" titel="Fensterkontakt über den Zeitraum" jeStunde={jeStunde} />
              </div>

              <div className="mono flex flex-wrap gap-x-5 gap-y-1 text-[11px] text-text-3">
                {/* Striche, keine Schriftzeichen: Ein Gedankenstrich ist ein Buchstabe und
                    nimmt die Farbe und Dicke der Schrift an, nicht die der Kurve. */}
                <span className="flex items-center gap-2">
                  <span style={{ display: "inline-block", width: 18, height: 2, background: "var(--amber)" }} />
                  gemessen
                </span>
                <span className="flex items-center gap-2">
                  <span style={{ display: "inline-block", width: 18, height: 0, borderTop: "2px dashed var(--text-3)" }} />
                  geregelt auf (Soll + Offset)
                </span>
                <span>Spanne {celsius(s.min, 1)} bis {celsius(s.max, 1)}</span>
              </div>
            </div>

            {log.entries.length ? (
              <ul className="m-0 flex list-none flex-col p-0">
                {log.entries.slice().reverse().map((e, i) => <Zeile key={i} e={e} />)}
              </ul>
            ) : (
              <p className="m-0 rounded-[6px] border border-line-1 p-3 text-[13px] text-text-3">
                Keine Einträge. Der Sollwert dieses Raums stand die ganze Zeit still - wenn die
                Temperatur trotzdem gestiegen ist, liegt es nicht an der Regelung, sondern an
                Ventilstellung, Fenster, Sonne oder der Vorlauftemperatur.
              </p>
            )}

            <p className="m-0 text-[11px] leading-[1.5] text-text-3">
              „von außen" heißt: nicht über dieses Werkzeug. Das kann die Controme-App sein, das
              Bedienteil an der Wand oder Contromes eigenes Heizprogramm; welches davon, steht
              nirgends, wo dieser Dienst nachsehen könnte.
            </p>
          </>
        ) : null}
      </div>
    </div>
  );
}
