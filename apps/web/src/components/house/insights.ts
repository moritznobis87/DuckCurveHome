/**
 * Was in den Aufklapp-Fenstern der Konsole steht: rechnen, sortieren, benennen.
 *
 * Die Bloecke links am Modell nennen eine Zahl. Die Anschlussfrage steht hier: *welche* Kontakte
 * offen sind, *welcher* Fuehler den Puffer so kalt macht, *wie lange* die Waermepumpe heute lief,
 * *welche* Raeume ihre Kreise offen haben. Dieses Modul kennt dafuer nur Daten, kein DOM.
 */
import type { HistoryPoint } from "@/lib/live/store";
import type { HousePlan, Measurement, RoomLive } from "@/lib/api/models";
import type { HausLive } from "./live";

// ------------------------------------------------------------------ Orte im Plan

export interface Ort {
  deck: string;
  raum: string;
}

/** Wo ein Raum der Einzelraumregelung im Plan liegt. `null`, wenn der Plan ihn nicht kennt. */
export function raumOrt(plan: HousePlan | null, roomId: number | null | undefined): Ort | null {
  if (!plan || roomId == null) return null;
  for (const deck of plan.decks) {
    const raum = deck.rooms.find((r) => r.room_id === roomId && !r.part_of);
    if (raum) return { deck: deck.key, raum: raum.name };
  }
  return null;
}

/** Zu welchem Raum ein Kontakt gehoert. `null`, wenn er keinem zugeordnet ist. */
export function kontaktOrt(plan: HousePlan | null, key: string): Ort | null {
  if (!plan) return null;
  for (const deck of plan.decks) {
    const k = (deck.contacts ?? []).find((c) => c.key === key);
    if (k?.room) return { deck: deck.key, raum: k.room };
  }
  return null;
}

// ------------------------------------------------------------------ Fenster und Tueren

export interface KontaktZeile {
  key: string;
  name: string;
  tuer: boolean;
  raum: string | null;
  ort: Ort | null;
  /** `null` heisst: nichts Frisches gemeldet. */
  offen: boolean | null;
  observed_at: string | null;
}

/**
 * Alle Kontakte des Plans, offene zuerst.
 *
 * Reihenfolge: offen vor zu vor stumm, Tueren vor Fenstern, sonst nach Namen. Ein stummer Kontakt
 * steht hinten und nicht gar nicht: dass er schweigt, ist die Auskunft, die jemand sucht, der sich
 * fragt, warum eine Tuer nie offen erscheint.
 */
export function kontaktZeilen(plan: HousePlan | null, live: HausLive): KontaktZeile[] {
  const zeilen: KontaktZeile[] = [];
  for (const deck of plan?.decks ?? []) {
    for (const k of deck.contacts ?? []) {
      const z = live.kontakte.get(k.key);
      zeilen.push({
        key: k.key,
        name: k.name,
        tuer: k.door,
        raum: k.room ?? null,
        ort: k.room ? { deck: deck.key, raum: k.room } : null,
        offen: z?.open ?? null,
        observed_at: z?.observed_at ?? null,
      });
    }
  }
  const rang = (z: KontaktZeile) => (z.offen === true ? 0 : z.offen === false ? 1 : 2);
  return zeilen.sort((a, b) => rang(a) - rang(b) || Number(b.tuer) - Number(a.tuer) || a.name.localeCompare(b.name, "de"));
}

// ------------------------------------------------------------------ Heizkreise

export interface KreisZeile {
  id: number;
  name: string;
  floor: string;
  valve: number;
  circuits: number;
  temp_c: number | null;
  target_c: number | null;
  deviation_k: number | null;
  ort: Ort | null;
}

/**
 * Die Raeume mit offenen Heizkreisen, der weiteste zuerst.
 *
 * **Warum nicht alle Raeume.** Der Block zaehlt die offenen; das Fenster soll dieselbe Zahl
 * erklaeren und nicht eine zweite Liste daneben stellen. Wer alle sehen will, geht auf die
 * Raumseite, und dorthin fuehrt der Fuss des Fensters.
 */
export function kreisZeilen(rooms: RoomLive[] | null, plan: HousePlan | null): KreisZeile[] {
  return (rooms ?? [])
    .filter((r) => (r.valve ?? 0) > 0)
    .map((r) => ({
      id: r.id,
      name: r.name,
      floor: r.floor,
      valve: r.valve ?? 0,
      circuits: r.circuits,
      temp_c: r.temp_c,
      target_c: r.target_c ?? r.setpoint_c,
      deviation_k: r.deviation_k,
      ort: raumOrt(plan, r.id),
    }))
    .sort((a, b) => b.valve - a.valve || (a.deviation_k ?? 0) - (b.deviation_k ?? 0) || a.name.localeCompare(b.name, "de"));
}

/** Der Raum, der am weitesten unter seinem Ziel liegt und dessen Kreise ganz offen stehen.
 *
 *  Er bestimmt die noetige Vorlauftemperatur fuer alle anderen mit. Genau diese eine Zeile ist
 *  der Grund, warum die Liste nach Ventilanteil sortiert ist und nicht nach Namen. */
export function anDerGrenze(zeilen: KreisZeile[]): KreisZeile | null {
  return zeilen.find((z) => z.valve >= 0.99 && (z.deviation_k ?? 0) < -0.5) ?? null;
}

// ------------------------------------------------------------------ Puffer

export const SCHICHT_NAMEN = ["oben", "Mitte oben", "Mitte unten", "unten"] as const;

export interface SchichtZeile {
  name: string;
  temp_c: number | null;
  observed_at: string | null;
  frisch: boolean;
}

export function schichtZeilen(temps: Measurement[]): SchichtZeile[] {
  return temps.slice(0, 4).map((m, i) => ({
    name: SCHICHT_NAMEN[i] ?? `Fühler ${i + 1}`,
    temp_c: m.value,
    observed_at: m.observed_at,
    frisch: m.quality === "ok" || m.quality === "derived",
  }));
}

/** Das Wort zum Zustand des Puffers. */
export function statusWort(status: string | null | undefined): string {
  return { cold: "kalt", partial: "teilweise geladen", warm: "warm", full: "voll", unknown: "unbekannt" }[status ?? ""] ?? "unbekannt";
}

/** Wie der Ladestand gerechnet wurde, in Worten statt als Kennung. */
export function methodeText(method: string | null | undefined): string {
  if (!method) return "";
  if (method.startsWith("layered_energy")) return "Schichtenmodell: jede Schicht mit ihrem eigenen Anteil am Volumen";
  if (method.startsWith("weighted_mean")) return "gewichtetes Mittel der vier Fühler";
  return method;
}

// ------------------------------------------------------------------ Waermepumpe

export interface TagesLauf {
  /** Elektrische Arbeit seit Mitternacht, aus dem Minutenraster. */
  kwh: number;
  /** Minuten, in denen Leistung anlag. */
  minuten: number;
  /** Die hoechste Minutenleistung des Tages, fuer die Achse der Kurve. */
  max: number;
}

/** Ab welcher Leistung die Waermepumpe als laufend gilt. Darunter ist es Bereitschaft. */
export const LAEUFT_KW = 0.1;

/** Was die Waermepumpe heute getan hat, aus dem Minutenraster der Startseite. */
export function tagesLauf(history: HistoryPoint[]): TagesLauf {
  let kwh = 0;
  let minuten = 0;
  let max = 0;
  for (const p of history) {
    if (p.hp == null) continue;
    kwh += p.hp / 60;
    if (p.hp >= LAEUFT_KW) minuten += 1;
    if (p.hp > max) max = p.hp;
  }
  return { kwh, minuten, max };
}

/** Stunden und Minuten, wie man sie sagt: „3 h 10 min", „42 min". */
export function dauerText(minuten: number): string {
  const m = Math.max(0, Math.round(minuten));
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  const rest = m % 60;
  return rest === 0 ? `${h} h` : `${h} h ${rest} min`;
}

/** Wie lange etwas schon dauert, aus einem Zeitpunkt. `null`, wenn keiner vorliegt. */
export function seitText(iso: string | null | undefined, nowMs: number): string | null {
  if (!iso) return null;
  const ms = nowMs - new Date(iso).getTime();
  if (!Number.isFinite(ms) || ms < 0) return null;
  return dauerText(ms / 60000);
}

/**
 * Ein Pfad je zusammenhaengendem Stueck der Reihe, auf `b` mal `h` skaliert.
 *
 * **Luecken bleiben Luecken.** Eine durchgezogene Linie ueber eine Minute ohne Messwert waere eine
 * Behauptung ueber genau die Minute, in der nichts ankam. Dieselbe Regel wie auf der Raumseite.
 */
export function sparkPfade(werte: (number | null)[], b: number, h: number, max: number): string[] {
  if (werte.length < 2 || max <= 0) return [];
  const x = (i: number) => (i / (werte.length - 1)) * b;
  const y = (v: number) => h - (Math.min(v, max) / max) * (h - 1) - 0.5;
  const stuecke: string[] = [];
  let lauf: string[] = [];
  werte.forEach((v, i) => {
    if (v == null) {
      if (lauf.length > 1) stuecke.push(lauf.join(" "));
      lauf = [];
      return;
    }
    lauf.push(`${lauf.length === 0 ? "M" : "L"} ${x(i).toFixed(1)} ${y(v).toFixed(1)}`);
  });
  if (lauf.length > 1) stuecke.push(lauf.join(" "));
  return stuecke;
}

/** Die Reihe auf eine feste Zahl von Stuetzstellen verdichten, damit die Kurve im Fenster nicht
 *  aus tausend Punkten besteht. Je Fenster das Mittel der vorhandenen Werte. */
export function verdichte(werte: (number | null)[], stellen: number): (number | null)[] {
  if (werte.length <= stellen) return werte;
  const breite = werte.length / stellen;
  return Array.from({ length: stellen }, (_, i) => {
    const teil = werte.slice(Math.floor(i * breite), Math.max(Math.floor((i + 1) * breite), Math.floor(i * breite) + 1)).filter((v): v is number => v != null);
    return teil.length ? teil.reduce((a, c) => a + c, 0) / teil.length : null;
  });
}
