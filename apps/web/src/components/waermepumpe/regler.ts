import type { ReglerEinstellung } from "@/lib/api/models";

/**
 * Die Einstellungen des Reglers als Liste: Gruppen in der Reihenfolge, in der der Dienst sie
 * liefert, und der Wert so, wie er am Bediengerät steht.
 *
 * Eine Einstellung, die nicht gelesen wurde oder älter als eine halbe Stunde ist, steht als
 * Fragezeichen da, nie als Null: null Grad Verschiebung ist eine Einstellung, kein fehlender Wert.
 */
export type Gruppe = { name: string; werte: ReglerEinstellung[] };

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

/** Der Wert mit deutschem Komma und Einheit, eine Verschiebung mit Vorzeichen. */
export function wertText(w: ReglerEinstellung): string {
  if (!gelesen(w) || w.wert.value == null) return "?";
  const v = w.wert.value;
  const zahl = Math.abs(v).toFixed(w.stellen ?? 1).replace(".", ",");
  const vorzeichen = v < 0 ? "−" : w.einheit === "K" && v > 0 ? "+" : "";
  return `${vorzeichen}${zahl}${w.einheit ? ` ${w.einheit}` : ""}`;
}

/** Wann gelesen, als Uhrzeit am Ort. */
export function standText(w: ReglerEinstellung): string {
  if (!gelesen(w) || !w.wert.observed_at) return "nicht gelesen";
  return new Date(w.wert.observed_at).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Berlin" });
}
