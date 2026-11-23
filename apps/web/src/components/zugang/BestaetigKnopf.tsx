"use client";

import { useEffect, useState } from "react";

/**
 * Ein Knopf, der zweimal gedrückt werden will.
 *
 * Statt `confirm()`: ein Browserdialog sieht auf jedem System anders aus, lässt sich nicht
 * gestalten und steht in diesem Projekt sonst nirgends. Zwei Stufen am selben Knopf sagen
 * dasselbe, bleiben an der Stelle, an der man geklickt hat, und verschwinden von selbst wieder.
 */
export function BestaetigKnopf({
  frage,
  children,
  onBestaetigt,
  disabled,
  className,
}: {
  /** Was auf der zweiten Stufe dasteht, z. B. „Wirklich löschen?" */
  frage: string;
  children: React.ReactNode;
  onBestaetigt: () => void;
  disabled?: boolean;
  className?: string;
}) {
  const [gefragt, setGefragt] = useState(false);

  // Nach ein paar Sekunden zurück: ein Knopf, der dauerhaft „Wirklich?" sagt, wird irgendwann
  // versehentlich bestätigt.
  useEffect(() => {
    if (!gefragt) return;
    const t = setTimeout(() => setGefragt(false), 5000);
    return () => clearTimeout(t);
  }, [gefragt]);

  return (
    <button
      type="button"
      disabled={disabled}
      onClick={() => {
        if (gefragt) {
          setGefragt(false);
          onBestaetigt();
        } else {
          setGefragt(true);
        }
      }}
      className={className}
      style={gefragt ? { color: "var(--amber)", borderColor: "var(--amber)" } : undefined}
    >
      {gefragt ? frage : children}
    </button>
  );
}
