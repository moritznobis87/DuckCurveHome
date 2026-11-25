"use client";

import { useCallback, useEffect, useState } from "react";
import { STARTBILD_MERKER, startbildAus, type Startbild } from "./startbild";

const EREIGNIS = "dch-startbild";

/**
 * Das gewählte Bild der Startseite auf diesem Gerät.
 *
 * `null`, solange der Speicher noch nicht gelesen ist: Der Server kennt die Wahl nicht, und eine
 * Wand, die erst die Bühne zeigt und dann zur Uhr springt, wäre ein Flackern bei jedem Laden.
 */
export function useStartbild(): [Startbild | null, (bild: Startbild) => void] {
  const [bild, setBild] = useState<Startbild | null>(null);
  useEffect(() => {
    const lies = () => {
      let wert: string | null = null;
      try {
        wert = window.localStorage.getItem(STARTBILD_MERKER);
      } catch {
        // Ohne Speicher (privates Fenster) bleibt es bei der Vorgabe.
      }
      setBild(startbildAus(wert));
    };
    lies();
    window.addEventListener("storage", lies);
    window.addEventListener(EREIGNIS, lies);
    return () => {
      window.removeEventListener("storage", lies);
      window.removeEventListener(EREIGNIS, lies);
    };
  }, []);
  const waehle = useCallback((neu: Startbild) => {
    try {
      window.localStorage.setItem(STARTBILD_MERKER, neu);
    } catch {
      // Dann gilt die Wahl nur, solange die Seite offen ist.
    }
    setBild(neu);
    window.dispatchEvent(new Event(EREIGNIS));
  }, []);
  return [bild, waehle];
}
