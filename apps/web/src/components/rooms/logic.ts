/** Was auf der Raumseite gerechnet wird, getrennt von dem, was sie zeichnet. */

import type { RoomLive, RoomSeries } from "@/lib/api/models";
import { BAND_K } from "./palette";

export type Gruppe = { floor: string; rooms: RoomLive[] };

/** Die Räume nach Etage gruppieren, in der Reihenfolge, in der sie kommen.
 *
 *  Nicht alphabetisch: die Reihenfolge ist Contromes eigene, und sortiert läge das Dachgeschoss
 *  vor dem Erdgeschoss. Räume ohne Etagenangabe stehen am Ende unter einer eigenen Überschrift. */
export function gruppiere(rooms: RoomLive[]): Gruppe[] {
  const out: Gruppe[] = [];
  for (const r of rooms) {
    const name = r.floor || "ohne Etagenangabe";
    const letzte = out.find((g) => g.floor === name);
    if (letzte) letzte.rooms.push(r);
    else out.push({ floor: name, rooms: [r] });
  }
  return out;
}

/**
 * Wie lange das Fenster dieses Raums schon offen steht, in Minuten.
 *
 * Gerechnet aus dem Ende der Zeitreihe rückwärts: so viele Fenster, wie durchgehend „offen"
 * melden, mal ihre Breite. `null` heißt, dass es keinen Kontakt gibt oder gerade keiner offen ist.
 *
 * **Warum nicht aus einem Zeitstempel.** Die Messreihe sagt, *dass* der Kontakt offen ist, nicht
 * *seit wann* - einen Wechselzeitpunkt überträgt die Telemetrie nicht. Die Zeitreihe weiß es
 * trotzdem, und zwar auf die Breite eines Fensters genau. Das reicht für den Satz, um den es geht:
 * „kalt, weil seit einer halben Stunde gelüftet wird".
 */
export function offenSeitMin(werte: (number | null)[], stepMin: number, bisIndex: number): number | null {
  let i = Math.min(bisIndex, werte.length - 1);
  // Noch nicht gemessene Fenster am Ende überspringen.
  while (i >= 0 && werte[i] == null) i--;
  if (i < 0 || (werte[i] ?? 0) < 0.5) return null;
  let zahl = 0;
  while (i >= 0 && (werte[i] ?? 0) >= 0.5) {
    zahl++;
    i--;
  }
  return zahl * stepMin;
}

/** Mittelwert über die vorhandenen Werte einer Reihe. `null`, wenn keiner vorhanden ist. */
export function mittel(werte: (number | null)[]): number | null {
  const gut = werte.filter((v): v is number => v != null);
  if (gut.length === 0) return null;
  return gut.reduce((a, b) => a + b, 0) / gut.length;
}

/** Worauf in diesem Fenster geregelt wurde: Sollwert plus Offset.
 *
 *  Dieselbe Rechnung wie `rooms.ziel` auf der Dienstseite, und sie steht hier ein zweites Mal,
 *  weil die Zeitreihe die beiden Zahlen einzeln überträgt statt den fertigen Zielwert - dann ist
 *  an der Kurve noch zu sehen, woraus er entstand. Ein fehlender Offset ist einer von null, ein
 *  fehlender Sollwert dagegen kein Zielwert. */
export function ziel(s: RoomSeries, i: number): number | null {
  const soll = s.setpoint_c[i];
  if (soll == null) return null;
  return soll + (s.offset_k[i] ?? 0);
}

/** Die Abweichung je Fenster: Ist minus Zielwert, wo beides vorliegt. */
export function abweichungen(s: RoomSeries): (number | null)[] {
  return s.temp_c.map((t, i) => {
    const z = ziel(s, i);
    return t == null || z == null ? null : t - z;
  });
}

/** Zusammenfassung einer Etage - was in einer Zeile über ihr steht. */
export function etagenText(rooms: RoomLive[]): string {
  const n = rooms.length;
  const wort = `${n} ${n === 1 ? "Raum" : "Räume"}`;
  const stumm = rooms.filter((r) => r.temp_c == null).length;
  const kalt = rooms.filter((r) => r.deviation_k != null && r.deviation_k < -BAND_K).length;
  const teile: string[] = [];
  if (kalt > 0) teile.push(`${kalt} unter dem Ziel`);
  if (stumm > 0) teile.push(`${stumm} ohne Messwert`);
  if (teile.length === 0) teile.push("alle am Ziel");
  return `${wort} · ${teile.join(" · ")}`;
}
