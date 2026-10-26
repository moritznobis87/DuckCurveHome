import type { Plan } from "@/lib/api/models";
import { grenzen, pvSumme } from "./tage";

/**
 * Das Ambiente: was die Wand zeigt, wenn niemand sie berührt.
 *
 * **Die Idee.** Die Startseite ist eine Bedienung: Schalter, Reiter, Kacheln, ein Dock. Das ist
 * richtig, solange jemand davorsteht. Den ganzen Tag über steht niemand davor, und dann ist eine
 * Bedienung nur Unruhe in der Küche. Nach ein paar Minuten ohne Berührung bleibt deshalb das
 * übrig, was man aus drei Metern lesen kann: die Uhr, ein Satz, drei große Zahlen. Eine
 * Berührung holt die Bedienung zurück.
 *
 * **Zwei Bilder, und die Sonne entscheidet.** Am Tag ist die Sonne die Nachricht, am Abend der
 * Preis und der Puffer. Umgeschaltet wird nicht nach der Uhr, sondern nach dem Sonnenlauf aus
 * dem Fahrplan: Solange die Prognose Erzeugung kennt, gilt der Tag. Das wechselt zweimal am Tag
 * und nicht alle fünf Minuten, wie es eine Schwelle auf die gemessene Leistung täte - eine Wolke
 * um 13 Uhr ist kein Abend.
 *
 * Alles hier ist reine Rechnung, damit es Tests gibt; die Zeichnung steht in `Ambiente.tsx`.
 */
export type Bild = "tag" | "abend";

/** Ab dieser Leistung zählt eine Viertelstunde als Erzeugung. */
const SONNE_KW = 0.05;
/** Erzeugt die Anlage so viel, ist es Tag, auch wenn die Prognose nichts davon wusste. */
const TROTZDEM_TAG_KW = 0.3;
const SCHRITT_MS = 15 * 60_000;
/** So viel Luft links und rechts vom Sonnenlauf, damit der Bogen nicht am Rand klebt. */
const LUFT_MS = 30 * 60_000;

export interface Sonnenlauf {
  /** Die Prognose im Fenster der Erzeugung, mit etwas Luft an beiden Enden. */
  punkte: Array<{ ts: number; kw: number }>;
  /** Beginn und Ende der erwarteten Erzeugung. */
  von: number;
  bis: number;
}

/** Der Sonnenlauf des heutigen Tages aus dem Fahrplan. Null, wenn der Plan nichts dazu sagt. */
export function sonnenlauf(plan: Plan | null, nowMs: number): Sonnenlauf | null {
  const tag = grenzen("heute", nowMs);
  const alle = (plan?.intervals ?? [])
    .map((i) => ({ ts: new Date(i.ts).getTime(), kw: i.expected_pv_kw }))
    .filter((p) => p.ts >= tag.start && p.ts < tag.end)
    .sort((a, b) => a.ts - b.ts);
  const hell = alle.filter((p) => p.kw > SONNE_KW);
  if (!hell.length) return null;
  const von = hell[0]!.ts;
  const bis = hell[hell.length - 1]!.ts + SCHRITT_MS;
  return { punkte: alle.filter((p) => p.ts >= von - LUFT_MS && p.ts <= bis + LUFT_MS), von, bis };
}

export function bild(lauf: Sonnenlauf | null, nowMs: number, pvKw: number | null | undefined): Bild {
  if (lauf && nowMs >= lauf.von && nowMs <= lauf.bis) return "tag";
  return pvKw != null && pvKw >= TROTZDEM_TAG_KW ? "tag" : "abend";
}

export interface Aussicht {
  /** Was der ganze Tag bringen soll. */
  erwartetKwh: number | null;
  /** Was ab jetzt noch kommt. */
  restKwh: number | null;
  /** Wann die Erzeugung endet. */
  bis: number | null;
}

export function aussicht(plan: Plan | null, nowMs: number, lauf: Sonnenlauf | null): Aussicht {
  const tag = grenzen("heute", nowMs);
  return {
    erwartetKwh: pvSumme(plan?.intervals, tag.start, tag.end),
    restKwh: pvSumme(plan?.intervals, Math.max(nowMs, tag.start), tag.end),
    bis: lauf?.bis ?? null,
  };
}

export interface Bogen {
  /** Der ganze erwartete Verlauf als Linie. */
  linie: string;
  /** Derselbe Verlauf bis jetzt, als Linie. */
  bisJetzt: string;
  /** Dasselbe, geschlossen zur Grundlinie: die Fläche darunter. */
  flaeche: string;
  /** Wo die Marke „jetzt" steht, oder null, wenn jetzt außerhalb des Bogens liegt. */
  jetztX: number | null;
  breite: number;
  hoehe: number;
}

/**
 * Der Sonnenbogen des Tages: ein kleiner Verlauf ohne Achsen.
 *
 * Er sagt nicht, wie viel - das sagen die Zahlen daneben -, sondern **wo im Tag man steht**.
 * Gefüllt ist, was hinter einem liegt. Deshalb ist die Breite der Sonnenlauf und nicht der
 * Kalendertag: Ein Bogen, der von Mitternacht bis Mitternacht reicht, ist in der Mitte ein
 * Hügel und an den Rändern Leere.
 */
export function bogen(lauf: Sonnenlauf | null, nowMs: number, breite = 340, hoehe = 62): Bogen | null {
  const punkte = lauf?.punkte ?? [];
  if (punkte.length < 2) return null;
  const von = punkte[0]!.ts;
  const bis = punkte[punkte.length - 1]!.ts;
  if (bis <= von) return null;
  const spitze = Math.max(0.5, ...punkte.map((p) => p.kw));
  const x = (ts: number) => ((ts - von) / (bis - von)) * breite;
  const y = (kw: number) => hoehe - (kw / spitze) * (hoehe - 4);
  const zu = (p: { ts: number; kw: number }) => `${x(p.ts).toFixed(1)} ${y(p.kw).toFixed(1)}`;
  const linie = `M${punkte.map(zu).join(" L")}`;
  const jetztDrin = nowMs > von && nowMs < bis;
  const jetztX = jetztDrin ? x(nowMs) : null;
  const vorbei = punkte.filter((p) => p.ts <= nowMs);
  if (jetztDrin && vorbei.length) {
    // Der Punkt genau auf „jetzt": zwischen den beiden Viertelstunden interpoliert, damit die
    // Fläche an der Marke endet und nicht bis zu 15 Minuten davor.
    const a = vorbei[vorbei.length - 1]!;
    const b = punkte[vorbei.length] ?? a;
    const f = b.ts > a.ts ? (nowMs - a.ts) / (b.ts - a.ts) : 0;
    vorbei.push({ ts: nowMs, kw: a.kw + (b.kw - a.kw) * f });
  }
  // Die Linie des bisherigen Tages und die Fläche darunter sind zwei Pfade. Als einer gezeichnet
  // bekäme die Fläche beim Nachziehen der Linie auch ihre Grundlinie und die Kante bei „jetzt".
  const bisJetzt = vorbei.length > 1 ? `M${vorbei.map(zu).join(" L")}` : "";
  const flaeche = bisJetzt ? `${bisJetzt} L${x(vorbei[vorbei.length - 1]!.ts).toFixed(1)} ${hoehe} L${x(von).toFixed(1)} ${hoehe} Z` : "";
  return { linie, bisJetzt, flaeche, jetztX, breite, hoehe };
}
