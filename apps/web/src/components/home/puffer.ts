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

// ----------------------------------------------------------------- Der Tank als Bild

/**
 * Wo die vier Fuehler sitzen: in der Mitte ihrer Schicht, in Prozent vom oberen Ende.
 *
 * Dieselben vier Zahlen tragen den Farbverlauf, die Beschriftung und - als Grenzen dazwischen -
 * die Trennlinien. Sie stehen hier und nicht in der Zeichnung, weil es drei Zeichnungen gibt:
 * den stehenden Tank am iPad, den liegenden am Telefon und den grossen im Ambiente.
 */
export const FUEHLER_POS = [12.5, 37.5, 62.5, 87.5] as const;
/** Die Grenzen zwischen den Schichten. */
export const SCHICHT_GRENZEN = [25, 50, 75] as const;

const STOPS: Array<[number, [number, number, number]]> = [
  [25, [0x1f, 0x4c, 0x66]],
  [40, [0x7f, 0xa3, 0xb3]],
  [50, [0xff, 0xd7, 0x78]],
  [60, [0xf2, 0xa9, 0x00]],
  [70, [0xe0, 0x53, 0x3d]],
];
const rgb = (c: [number, number, number]) => `rgb(${c[0]},${c[1]},${c[2]})`;

/** Farbe einer Puffertemperatur, von kalt-petrol bis heiss-rot. */
export function heatColor(t: number): string {
  const first = STOPS[0]!;
  const last = STOPS[STOPS.length - 1]!;
  if (t <= first[0]) return rgb(first[1]);
  if (t >= last[0]) return rgb(last[1]);
  for (let i = 0; i < STOPS.length - 1; i++) {
    const [t0, c0] = STOPS[i]!;
    const [t1, c1] = STOPS[i + 1]!;
    if (t >= t0 && t <= t1) {
      const f = (t - t0) / (t1 - t0);
      return rgb([0, 1, 2].map((k) => Math.round(c0[k]! + (c1[k]! - c0[k]!) * f)) as [number, number, number]);
    }
  }
  return rgb(last[1]);
}
