import type { ReglerEinstellung } from "@/lib/api/models";

/**
 * Die Einstellungen des Reglers: die Rechnungen hinter der Seite „Regler“.
 *
 * **Lesen.** Eine Einstellung, die nicht gelesen wurde oder zu alt ist, steht als Fragezeichen
 * da, nie als Null: null Grad Verschiebung ist eine Einstellung, kein fehlender Wert.
 *
 * **Stellen.** Die Seite sammelt Änderungen als Entwurf und schickt sie erst auf Knopfdruck ab.
 * Was sich bewegen lässt, entscheidet `bedienbar`: die Einstellung muss stellbar, gelesen und mit
 * dem Bediengerät verglichen sein, und der Dienst muss einen Stellbefehl loswerden können.
 * Dieselben Bedingungen prüft der Dienst noch einmal; hier sorgen sie dafür, dass ein Regler,
 * der nichts bewirken würde, sich gar nicht erst bewegt.
 *
 * **Die Heizkurve** ist eine Näherung, und so steht es auf der Seite:
 * Vorlauf = Raum + Steilheit × (Raum − außen) + Verschiebung, begrenzt auf den kleinsten und
 * größten Vorlauf. Sie zeigt, in welche Richtung und ungefähr wie weit sich die Kurve mit einer
 * Änderung bewegt. Was der Regler wirklich verlangt, zeigen die gemessenen Stunden daneben.
 */
export type Gruppe = { name: string; werte: ReglerEinstellung[] };
export type Entwurf = Record<string, number>;

export function gruppen(werte: ReglerEinstellung[]): Gruppe[] {
  const aus: Gruppe[] = [];
  for (const w of werte) {
    const g = aus.find((x) => x.name === w.gruppe_de);
    if (g) g.werte.push(w);
    else aus.push({ name: w.gruppe_de, werte: [w] });
  }
  return aus;
}

export function gelesen(w: ReglerEinstellung): boolean {
  return w.wert.value != null && (w.wert.quality === "ok" || w.wert.quality === "derived");
}

/** Eine Zahl dieser Einstellung mit deutschem Komma und Einheit, eine Verschiebung mit Vorzeichen. */
export function zahlText(w: ReglerEinstellung, v: number): string {
  const zahl = Math.abs(v).toFixed(w.stellen ?? 1).replace(".", ",");
  const vorzeichen = v < 0 ? "−" : w.einheit === "K" && v > 0 ? "+" : "";
  return `${vorzeichen}${zahl}${w.einheit ? ` ${w.einheit}` : ""}`;
}

export function wertText(w: ReglerEinstellung): string {
  if (!gelesen(w) || w.wert.value == null) return "?";
  return zahlText(w, w.wert.value);
}

/** Wann gelesen, als Uhrzeit am Ort. */
export function standText(w: ReglerEinstellung): string {
  if (!gelesen(w) || !w.wert.observed_at) return "nicht gelesen";
  return new Date(w.wert.observed_at).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Berlin" });
}

/** Warum sich diese Einstellung gerade nicht bewegen lässt, als kurzes Wort. `null`: sie lässt sich. */
export function sperre(w: ReglerEinstellung, stellenMoeglich: boolean): string | null {
  if (!w.stellbar) return "nur lesen";
  if (!gelesen(w)) return "nicht gelesen";
  if (!w.bestaetigt) return "nicht verglichen";
  if (!stellenMoeglich) return "Stellen nicht möglich";
  return null;
}

export const bedienbar = (w: ReglerEinstellung, stellenMoeglich: boolean): boolean => sperre(w, stellenMoeglich) === null;

/** Der Wert auf dem Raster der Einstellung, innerhalb ihrer Grenzen. */
export function raster(w: ReglerEinstellung, wert: number): number {
  const von = w.von ?? 0;
  const bis = w.bis ?? von;
  const schritt = w.schritt ?? 1;
  const g = Math.min(bis, Math.max(von, wert));
  return Number((von + Math.round((g - von) / schritt) * schritt).toFixed(4));
}

/** Wo ein Wert auf der Skala seiner Einstellung liegt, 0 (unten) bis 1 (oben). */
export function anteil(w: ReglerEinstellung, wert: number): number {
  const von = w.von ?? 0;
  const bis = w.bis ?? von + 1;
  return Math.min(1, Math.max(0, (wert - von) / (bis - von)));
}

/** Der Wert an einer Stelle der Skala, auf dem Raster. */
export function wertBei(w: ReglerEinstellung, a: number): number {
  const von = w.von ?? 0;
  const bis = w.bis ?? von + 1;
  return raster(w, von + Math.min(1, Math.max(0, a)) * (bis - von));
}

/** Der Wert, den die Seite gerade zeigt: der Entwurf, sonst der gelesene. */
export function sichtbar(w: ReglerEinstellung, entwurf: Entwurf): number | null {
  const e = entwurf[w.schluessel];
  if (e != null) return e;
  return gelesen(w) ? (w.wert.value ?? null) : null;
}

export type Aenderung = { w: ReglerEinstellung; alt: number; neu: number };

/** Was der Entwurf gegenüber dem Gelesenen ändert. Ein Entwurf, der dem gelesenen Wert gleicht,
 *  ist keine Änderung. */
export function aenderungen(werte: ReglerEinstellung[], entwurf: Entwurf): Aenderung[] {
  const aus: Aenderung[] = [];
  for (const w of werte) {
    const neu = entwurf[w.schluessel];
    if (neu == null || !gelesen(w) || w.wert.value == null) continue;
    if (Math.abs(neu - w.wert.value) > 1e-6) aus.push({ w, alt: w.wert.value, neu });
  }
  return aus;
}

// --- Die Heizkurve

export type Kurve = { steilheit: number; verschiebung: number; raum: number; min: number; max: number };

export const KURVE = {
  steilheit: "heat_pump_set_slope",
  verschiebung: "heat_pump_set_offset_k",
  raum: "heat_pump_set_room_day_c",
  min: "heat_pump_set_flow_min_c",
  max: "heat_pump_set_flow_max_c",
} as const;

/** Die Größen der Kurve aus den Einstellungen, mit dem Entwurf darüber. `null`, wenn eine fehlt. */
export function kurveAus(werte: ReglerEinstellung[], entwurf: Entwurf = {}): Kurve | null {
  const zahl = (key: string): number | null => {
    const w = werte.find((x) => x.schluessel === key);
    return w ? sichtbar(w, entwurf) : null;
  };
  const steilheit = zahl(KURVE.steilheit);
  const verschiebung = zahl(KURVE.verschiebung);
  const raum = zahl(KURVE.raum);
  const min = zahl(KURVE.min);
  const max = zahl(KURVE.max);
  if (steilheit == null || verschiebung == null || raum == null || min == null || max == null) return null;
  return { steilheit, verschiebung, raum, min, max };
}

/** Der Vorlauf, den die Näherung bei einer Außentemperatur ergibt, ohne die Grenzen. */
export const vorlaufFrei = (k: Kurve, aussen: number): number => k.raum + k.steilheit * (k.raum - aussen) + k.verschiebung;

/** Derselbe, begrenzt auf den kleinsten und größten Vorlauf. */
export const vorlauf = (k: Kurve, aussen: number): number => Math.min(k.max, Math.max(k.min, vorlaufFrei(k, aussen)));

/** Die Steilheit, mit der die Kurve bei dieser Außentemperatur durch diesen Vorlauf geht. */
export function steilheitDurch(k: Kurve, aussen: number, ziel: number): number {
  const hebel = k.raum - aussen;
  return hebel === 0 ? k.steilheit : (ziel - k.raum - k.verschiebung) / hebel;
}

/** Die Verschiebung, mit der die Kurve bei dieser Außentemperatur durch diesen Vorlauf geht. */
export const verschiebungDurch = (k: Kurve, aussen: number, ziel: number): number => ziel - k.raum - k.steilheit * (k.raum - aussen);

/** Die Kurve als Punkte von kalt nach warm, je ganzem Grad. */
export function kurvenPunkte(k: Kurve, von: number, bis: number): [number, number][] {
  const aus: [number, number][] = [];
  for (let t = von; t <= bis; t += 1) aus.push([t, vorlauf(k, t)]);
  return aus;
}
