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

/** Mittelwert über die vorhandenen Werte einer Reihe. `null`, wenn keiner vorhanden ist. */
export function mittel(werte: (number | null)[]): number | null {
  const gut = werte.filter((v): v is number => v != null);
  if (gut.length === 0) return null;
  return gut.reduce((a, b) => a + b, 0) / gut.length;
}

/** Die Abweichung je Fenster: Ist minus Soll, wo beides vorliegt. */
export function abweichungen(s: RoomSeries): (number | null)[] {
  return s.temp_c.map((t, i) => {
    const soll = s.setpoint_c[i];
    return t == null || soll == null ? null : t - soll;
  });
}

/** Zusammenfassung einer Etage - was in einer Zeile über ihr steht. */
export function etagenText(rooms: RoomLive[]): string {
  const n = rooms.length;
  const wort = `${n} ${n === 1 ? "Raum" : "Räume"}`;
  const stumm = rooms.filter((r) => r.temp_c == null).length;
  const kalt = rooms.filter((r) => r.deviation_k != null && r.deviation_k < -BAND_K).length;
  const teile: string[] = [];
  if (kalt > 0) teile.push(`${kalt} unter Sollwert`);
  if (stumm > 0) teile.push(`${stumm} ohne Messwert`);
  if (teile.length === 0) teile.push("alle auf Sollwert");
  return `${wort} · ${teile.join(" · ")}`;
}
