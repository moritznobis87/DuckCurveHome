"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import { Dot } from "@/components/ui/Dot";
import type { LiveState } from "@/lib/api/models";

/**
 * Liefert gerade, was liefern soll?
 *
 * **Warum das neben der Verfügbarkeitskarte steht und nicht statt ihr.** Die Karte zählt Stunden
 * und braucht deshalb bis zu einer Stunde, bevor sie einen Ausfall zeigt. Für die Frage „läuft es
 * jetzt" ist sie zu träge; für die Frage „lief es letzte Woche" ist sie das einzige Werkzeug. Beide
 * Fragen stellt man an derselben Stelle, also stehen beide Antworten dort.
 *
 * **Online ist die schwächere Auskunft.** Eine Quelle, die antwortet und dabei seit einer Stunde
 * denselben Wert liefert, steht hier auf grün. Deshalb nennt die Zeile das Alter des letzten
 * Messwerts mit - die API stellt es dafür schon zusammen.
 */
const LABELS: Record<string, string> = {
  bridge: "Haus (Bridge)",
  myenergi: "myenergi (Libbi, Wallbox)",
  inexogy: "Zähler (inexogy)",
};

const REFRESH_MS = 30_000;

export function Sources() {
  const [state, setState] = useState<LiveState | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    let alive = true;
    const load = () =>
      api
        .liveState()
        .then((s) => alive && (setState(s), setError(false)))
        .catch(() => alive && setError(true));
    void load();
    const timer = setInterval(load, REFRESH_MS);
    return () => {
      alive = false;
      clearInterval(timer);
    };
  }, []);

  const sources = state?.system.sources ?? [];
  if (error && !state) return <p className="m-0 text-[14px] text-text-3">Der Zustand der Quellen ist gerade nicht abrufbar.</p>;
  if (!state) return <p className="m-0 text-[14px] text-text-3">lädt …</p>;

  return (
    <div className="flex flex-col gap-2">
      {sources.map((s) => (
        <div
          key={s.name}
          className="flex flex-wrap items-baseline gap-x-3 gap-y-1 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3"
        >
          <span className="flex items-center gap-2">
            <Dot tone={s.online ? "ok" : "alert"} />
            <span className="text-[14px] text-text-1">{LABELS[s.name] ?? s.name}</span>
          </span>
          {/* Der Satz kommt fertig aus der API. Er kennt den Zähler, die Zahl der Abfragen und das
              Alter des letzten Messwerts; die Oberfläche soll das nicht noch einmal wissen. */}
          <span className="mono w-full text-[13px] leading-[1.5] text-text-3 sm:w-auto">{s.detail_de}</span>
        </div>
      ))}
    </div>
  );
}
