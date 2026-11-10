import type { ReactNode } from "react";

/**
 * Der Methodentext einer Auswertung: zugeklappt, bis jemand ihn lesen will.
 *
 * Sechs Seiten endeten mit 150 bis 210 Wörtern darüber, wie gerechnet wird, immer aufgeklappt.
 * Das ist für den richtig, der eine Zahl zum ersten Mal sieht, und für jeden Blick danach Text,
 * an dem man vorbeirollt. Der Baustein steht deshalb am Ende der Seite, sagt in einer Zeile, was
 * darin steht, und öffnet sich auf einen Klick.
 *
 * **Was hinein gehört und was nicht.** Hinein gehört, wie eine Zahl entsteht und was sie nicht
 * sagt. Nicht hinein gehört, was eine Zahl *an diesem Tag* einschränkt - eine fehlende Linie,
 * eine Lücke, ein laufender Tag. Das steht neben der Zahl, denn zugeklappt wäre es verschwiegen.
 *
 * Ein `<details>` und kein Zustand: der Browser kann es ohne Skript, die Vorlesehilfe kennt es,
 * und die Seitensuche findet seinen Text.
 */
export function Methode({ title = "Wie gerechnet wird", kurz, children }: { title?: string; kurz?: string; children: ReactNode }) {
  return (
    <details className="card methode">
      <summary>
        <span className="kicker">{title}</span>
        {kurz ? <span className="methode-kurz">{kurz}</span> : null}
        <span className="methode-pfeil" aria-hidden="true" />
      </summary>
      <div className="methode-inhalt">{children}</div>
    </details>
  );
}

/** Ein Absatz im Methodentext. Begrenzte Zeilenlänge, damit das Auge den Zeilenanfang wiederfindet. */
export function MethodeAbsatz({ children }: { children: ReactNode }) {
  return <p className="methode-absatz">{children}</p>;
}
