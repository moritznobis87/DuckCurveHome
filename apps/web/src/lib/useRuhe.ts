"use client";

import { useCallback, useEffect, useRef, useState } from "react";

/**
 * Ruhe: niemand hat die Anzeige eine Weile berührt.
 *
 * **Wozu.** Die Wandanzeige in der Küche steht den ganzen Tag allein da. Nach ein paar Minuten
 * ohne Berührung soll aus der Bedienung ein Bild werden (siehe `Ambiente`), und beim ersten
 * Antippen wieder die Bedienung. Genau das sagt dieser Haken: ob gerade niemand da ist.
 *
 * **Was als Berührung zählt.** Tippen, Tasten, Rollen, der Wechsel zurück in den Vordergrund.
 * Bewegungen des Mauszeigers nicht: Ein Zeiger, der irgendwo in der Küche liegt, wackelt bei
 * jeder Erschütterung, und die Anzeige käme nie zur Ruhe.
 */
const EREIGNISSE = ["pointerdown", "keydown", "wheel", "touchstart"] as const;

export function useRuhe(ms: number, aktiv = true): { ruhe: boolean; wecken: () => void } {
  const [ruhe, setRuhe] = useState(false);
  const neu = useRef<() => void>(() => undefined);

  useEffect(() => {
    if (!aktiv) {
      setRuhe(false);
      neu.current = () => undefined;
      return;
    }
    let t: ReturnType<typeof setTimeout> | undefined;
    const wach = () => {
      // setState mit demselben Wert zeichnet nicht neu; das darf hier also bei jedem Tippen
      // laufen, ohne die Seite zu beschäftigen.
      setRuhe(false);
      if (t) clearTimeout(t);
      t = setTimeout(() => setRuhe(true), ms);
    };
    neu.current = wach;
    wach();
    for (const e of EREIGNISSE) window.addEventListener(e, wach, { passive: true });
    document.addEventListener("visibilitychange", wach);
    return () => {
      if (t) clearTimeout(t);
      for (const e of EREIGNISSE) window.removeEventListener(e, wach);
      document.removeEventListener("visibilitychange", wach);
    };
  }, [ms, aktiv]);

  return { ruhe, wecken: useCallback(() => neu.current(), []) };
}
