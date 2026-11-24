import type { components } from "@/lib/api/types";

type Bild = components["schemas"]["UebersichtBildOut"];

/**
 * Das kleine Bild einer Kachel der Übersicht: eine Form, die sich auf einen Blick lesen lässt.
 *
 * Vier Arten, wie der Dienst sie liefert (`UebersichtBildOut`): der Verlauf des Tages als Balken,
 * ein Füllstand, eine Abweichung nach unten oder oben, und der Horizont des Fahrplans als
 * Streifen. Gezeichnet wird in der Farbe der Sache (`--kachelfarbe`). Dieselbe Rechnung zeichnet
 * die App (`apps/ios/DuckCurveKit/.../Kachelbild.swift`); wer hier eine Zahl ändert, ändert sie
 * dort mit.
 *
 * Das Bild trägt keine Zahl, die nicht auch als Leitzahl dasteht. Für die Vorlesehilfe ist es
 * deshalb stumm.
 */

/** So viele Plätze hat der Tag. Eine Stunde, die noch nicht war, bleibt ein leerer Platz. */
export const STUNDEN = 24;

/**
 * Die Balken eines Tages als Höhen von 0 bis 1, immer `STUNDEN` Plätze. Die größte Stunde ist 1;
 * `null` heißt, die Stunde war noch nicht. Ohne einen einzigen Wert über null bleiben alle 0.
 */
export function balkenhoehen(werte: number[]): (number | null)[] {
  const gross = Math.max(0, ...werte);
  return Array.from({ length: STUNDEN }, (_, i) => {
    const wert = werte[i];
    if (wert === undefined) return null;
    return gross > 0 ? Math.max(0, wert) / gross : 0;
  });
}

/**
 * Die Läufe eines Streifens: zusammenhängende Abschnitte mit einem Wert über null, je als Anfang
 * und Ende zwischen 0 und 1 der ganzen Länge.
 */
export function laeufe(werte: number[]): { von: number; bis: number }[] {
  const aus: { von: number; bis: number }[] = [];
  const n = werte.length;
  let anfang: number | null = null;
  for (let i = 0; i <= n; i++) {
    const an = i < n && (werte[i] ?? 0) > 0;
    if (an && anfang === null) anfang = i;
    if (!an && anfang !== null) {
      aus.push({ von: anfang / n, bis: i / n });
      anfang = null;
    }
  }
  return aus;
}

const BREITE = 96;
const HOEHE = 28;

function Balken({ werte }: { werte: number[] }) {
  const schritt = BREITE / STUNDEN;
  return (
    <>
      {balkenhoehen(werte).map((h, i) => {
        // Ein Platz ohne Wert und eine Stunde mit null stehen als feiner Strich auf der
        // Grundlinie: man sieht, dass der Tag 24 Stunden hat und wo er gerade ist.
        const hoch = h === null ? 1.5 : Math.max(1.5, h * HOEHE);
        return (
          <rect
            key={i}
            x={i * schritt + 0.5}
            y={HOEHE - hoch}
            width={schritt - 1}
            height={hoch}
            rx={0.8}
            fill="var(--kachelfarbe)"
            opacity={h === null ? 0.16 : h === 0 ? 0.3 : 0.9}
          />
        );
      })}
    </>
  );
}

function Spur({ children }: { children: React.ReactNode }) {
  return (
    <>
      <rect x={0} y={HOEHE - 8} width={BREITE} height={6} rx={3} fill="var(--kachelfarbe)" opacity={0.16} />
      {children}
    </>
  );
}

function Fuellung({ anteil }: { anteil: number }) {
  const a = Math.min(1, Math.max(0, anteil));
  return (
    <Spur>
      {a > 0 ? <rect x={0} y={HOEHE - 8} width={Math.max(3, a * BREITE)} height={6} rx={3} fill="var(--kachelfarbe)" /> : null}
    </Spur>
  );
}

function Abweichung({ anteil }: { anteil: number }) {
  const a = Math.min(1, Math.max(-1, anteil));
  const mitte = BREITE / 2;
  const breite = Math.abs(a) * mitte;
  return (
    <Spur>
      {breite > 0 ? <rect x={a < 0 ? mitte - breite : mitte} y={HOEHE - 8} width={breite} height={6} rx={3} fill="var(--kachelfarbe)" /> : null}
      {/* Die Mitte ist die Vorhersage; der Balken zeigt, wie weit der Ertrag davon lag. */}
      <rect x={mitte - 0.6} y={HOEHE - 12} width={1.2} height={14} rx={0.6} fill="var(--text-2)" />
    </Spur>
  );
}

function Streifen({ werte }: { werte: number[] }) {
  return (
    <Spur>
      {laeufe(werte).map((l) => (
        <rect key={l.von} x={l.von * BREITE} y={HOEHE - 8} width={Math.max(1.5, (l.bis - l.von) * BREITE)} height={6} rx={1.5} fill="var(--kachelfarbe)" />
      ))}
    </Spur>
  );
}

export function Kachelbild({ bild }: { bild: Bild }) {
  const werte = bild.werte ?? [];
  return (
    <svg className="uebersicht-bild" viewBox={`0 0 ${BREITE} ${HOEHE}`} preserveAspectRatio="none" aria-hidden="true" data-art={bild.art}>
      {bild.art === "balken" ? <Balken werte={werte} /> : null}
      {bild.art === "fuellung" && bild.anteil != null ? <Fuellung anteil={bild.anteil} /> : null}
      {bild.art === "abweichung" && bild.anteil != null ? <Abweichung anteil={bild.anteil} /> : null}
      {bild.art === "streifen" ? <Streifen werte={werte} /> : null}
    </svg>
  );
}
