"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Die Größe eines Elements in ganzen Pixeln, für Zeichnungen, die in der Größe ihres Platzes
 * gezeichnet werden statt gestreckt. `null`, solange noch nicht gemessen ist.
 */
export function useGroesse<T extends Element>() {
  const ref = useRef<T | null>(null);
  const [groesse, setGroesse] = useState<{ breite: number; hoehe: number } | null>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver((eintraege) => {
      const r = eintraege[0]?.contentRect;
      if (!r) return;
      const breite = Math.round(r.width);
      const hoehe = Math.round(r.height);
      setGroesse((alt) => (alt && alt.breite === breite && alt.hoehe === hoehe ? alt : { breite, hoehe }));
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, groesse] as const;
}
