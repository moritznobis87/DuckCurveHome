/**
 * Das Zeichen eines Zustands: Farbe und Form zugleich.
 *
 * Der Hausherr hat am 24.11.2026 entschieden, dass „in Ordnung“ ein eigenes Grün bekommt und
 * jeder Zustand eine eigene Form. Vorher war es ein Punkt in drei Farben, und der gute Zustand
 * trug das Nebelgrau, das auch den Strompreis und jede Stichwortzeile färbt. Mit der Form bleibt
 * der Zustand auch ohne Farbsehen lesbar: Bei Rot-Grün-Schwäche rücken Grün und Rot auf einen
 * Abstand von 18,8 zusammen, Haken und Achteck bleiben verschieden
 * (`docs/design/werkstatt/LIESMICH.md`).
 *
 * Die Zeichnung steht in einem Feld von 18 mal 18. Dieselben Zahlen zeichnet die App
 * (`apps/ios/DuckCurveHome/Bausteine/Zustandszeichen.swift`); wer hier eine ändert, ändert sie
 * dort mit.
 */
export type Zustand = "gut" | "warn" | "schlecht" | "aus";

export const ZUSTANDSWORT: Record<Zustand, string> = {
  gut: "in Ordnung",
  warn: "Hinweis",
  schlecht: "Störung",
  aus: "keine Angabe",
};

const STRICH = { fill: "none", strokeWidth: 2, strokeLinecap: "round", strokeLinejoin: "round" } as const;

function Zeichnung({ zustand }: { zustand: Zustand }) {
  switch (zustand) {
    case "gut":
      return (
        <>
          <circle cx="9" cy="9" r="8" fill="var(--ok)" />
          <path d="M5.2 9.4l2.6 2.5 5-5.4" stroke="var(--deep)" {...STRICH} />
        </>
      );
    case "warn":
      return (
        <>
          <path d="M9 2.2L16.4 15H1.6z" fill="var(--amber-soft)" stroke="var(--amber-soft)" strokeWidth="2" strokeLinejoin="round" />
          <path d="M9 6.6v4" stroke="var(--deep)" {...STRICH} />
          <circle cx="9" cy="13" r="1.1" fill="var(--deep)" />
        </>
      );
    case "schlecht":
      return (
        <>
          <path d="M6 1.2h6L16.8 6v6L12 16.8H6L1.2 12V6z" fill="var(--alert)" />
          <path d="M9 5v4.6" stroke="var(--paper)" {...STRICH} />
          <circle cx="9" cy="12.6" r="1.1" fill="var(--paper)" />
        </>
      );
    case "aus":
      return <circle cx="9" cy="9" r="6.5" stroke="var(--text-3)" fill="none" strokeWidth="2" />;
  }
}

/**
 * @param gross Das Zeichen über einer ganzen Seite (20 Pixel) statt in einer Zeile (16 Pixel).
 * @param stumm Der Zustand steht daneben schon als Wort; das Zeichen wird dann nicht vorgelesen.
 * @param className Abstände der Stelle, an der das Zeichen steht, etwa der Versatz zur ersten Textzeile.
 */
export function Zustandszeichen({
  zustand,
  gross = false,
  stumm = false,
  className = "",
}: {
  zustand: Zustand;
  gross?: boolean;
  stumm?: boolean;
  className?: string;
}) {
  const s = gross ? 20 : 16;
  return (
    <svg
      viewBox="0 0 18 18"
      width={s}
      height={s}
      className={`zustandszeichen shrink-0 ${className}`.trim()}
      data-zustand={zustand}
      {...(stumm ? { "aria-hidden": true } : { role: "img", "aria-label": ZUSTANDSWORT[zustand] })}
    >
      <Zeichnung zustand={zustand} />
    </svg>
  );
}
