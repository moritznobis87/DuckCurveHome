import type { Measurement } from "@/lib/api/models";
import { ageLabel } from "@/lib/format";

/**
 * Was unter dem Puffer steht - und wann es eine Entschuldigung statt eines Zustands ist.
 *
 * **Der Anlass.** Am 25.10.2026 zeigte die Wandanzeige vier satte Temperaturen, einen vollen
 * Farbverlauf und als Füllstand einen Strich. Der Dienst rechnet den Füllstand nur aus frischen
 * Fühlern; einer war veraltet (der MQTT-Broker war abgemeldet), also kam nichts heraus. Zu sehen
 * war davon nichts: Die Kachel sah aus wie immer, nur ohne Zahl.
 *
 * Jetzt sagt sie, wie alt die Werte sind. Eine Anzeige, die eine fehlende Zahl nicht erklärt,
 * schickt den Betrachter zum Raten - und in diesem Fall lag die Ursache zwei Tage zurück.
 */
export interface PufferZustand {
  /** Alle vier Fühler haben einen Wert. */
  vollstaendig: boolean;
  /** Mindestens ein Wert ist nicht mehr frisch. */
  veraltet: boolean;
  /** Das Wort unter dem Füllstand. */
  wort: string;
}

const FRISCH = new Set(["ok", "derived"]);

export function pufferZustand(
  temps: Measurement[],
  nowMs: number,
  laedt: boolean,
  status: string | null | undefined,
): PufferZustand {
  const vollstaendig = temps.length > 0 && temps.every((m) => m.value !== null);
  const veraltet = temps.some((m) => m.value !== null && !FRISCH.has(m.quality));
  if (veraltet) {
    // Der älteste der vier bestimmt das Alter: Er ist der Grund, warum nichts gerechnet wird.
    const aeltester = temps.reduce<string | null>(
      (alt, m) => (m.observed_at && (alt === null || m.observed_at < alt) ? m.observed_at : alt),
      null,
    );
    const alter = aeltester ? ageLabel(aeltester, nowMs) : null;
    return { vollstaendig, veraltet, wort: alter ? `Werte ${alter}` : "Werte veraltet" };
  }
  if (!vollstaendig) return { vollstaendig, veraltet, wort: "keine Werte" };
  if (laedt) return { vollstaendig, veraltet, wort: "lädt" };
  if (status === "full") return { vollstaendig, veraltet, wort: "voll" };
  if (status === "cold") return { vollstaendig, veraltet, wort: "kalt" };
  if (status === "warm") return { vollstaendig, veraltet, wort: "warm" };
  return { vollstaendig, veraltet, wort: "hält" };
}
