"use client";

// Der Zustand des Hausgeräts (routers/geraet.py, deploy/haus/dch `zustand`).
//
// Das Gerät schreibt seinen Bericht jede Minute; die API prüft sich bei jeder Abfrage selbst. Im
// Ruhezustand genügt deshalb alle fünfzehn Sekunden. Solange eine Aktion läuft, alle zwei, damit
// „Neu gestartet“ nicht eine Viertelminute auf sich warten lässt. Startet die API selbst neu,
// schlägt die Abfrage eine Weile fehl: Das ist dann kein Fehler, sondern genau der Neustart.

import { useCallback, useEffect, useRef, useState } from "react";
import type { Geraet, GeraetProtokoll } from "@/lib/api/models";

const ADRESSE = "/api/dch/system/geraet";
const RUHIG_MS = 15_000;
const EILIG_MS = 2_000;

export type Handgriff = "neustart" | "sichern" | "protokoll" | "geraet_neustart" | "zustand";

export function beschaeftigt(g: Geraet | null): boolean {
  return Boolean(g && (g.beschaeftigt || g.letzte_aktion?.zustand === "laeuft"));
}

async function fehlerText(antwort: Response): Promise<string> {
  const daten = (await antwort.json().catch(() => null)) as { error?: { message?: string } } | null;
  return daten?.error?.message ?? `Die Anfrage ging nicht durch (${antwort.status}).`;
}

export function useGeraet() {
  const [geraet, setGeraet] = useState<Geraet | null>(null);
  const [unerreichbar, setUnerreichbar] = useState(false);
  const [fehler, setFehler] = useState<string | null>(null);
  const [eilig, setEilig] = useState(false);
  const angefragt = useRef(false);

  const laden = useCallback(async () => {
    try {
      const antwort = await fetch(ADRESSE, { cache: "no-store" });
      if (!antwort.ok) throw new Error(String(antwort.status));
      const neu = (await antwort.json()) as Geraet;
      setGeraet(neu);
      setUnerreichbar(false);
      // Eilig, solange das Gerät beschäftigt ist; die erste Antwort nach der Anfrage kann noch
      // „frei“ sagen, weil systemd die Datei erst abholt.
      const los = beschaeftigt(neu);
      if (los) angefragt.current = false;
      setEilig(los || angefragt.current);
    } catch {
      setUnerreichbar(true);
    }
  }, []);

  useEffect(() => {
    void laden();
    const timer = setInterval(() => void laden(), eilig || unerreichbar ? EILIG_MS : RUHIG_MS);
    return () => clearInterval(timer);
  }, [laden, eilig, unerreichbar]);

  const anfragen = useCallback(
    async (aktion: Handgriff, dienst?: string): Promise<boolean> => {
      setFehler(null);
      const antwort = await fetch(`${ADRESSE}/aktion`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(dienst ? { aktion, dienst } : { aktion }),
      }).catch(() => null);
      if (!antwort) {
        setFehler("Der Dienst ist gerade nicht erreichbar.");
        return false;
      }
      if (!antwort.ok) {
        setFehler(await fehlerText(antwort));
        return false;
      }
      angefragt.current = true;
      setEilig(true);
      void laden();
      return true;
    },
    [laden],
  );

  return { geraet, unerreichbar, fehler, anfragen, neuLaden: laden };
}

/** Holt ein frisches Protokoll: anfragen, dann warten, bis die Datei neuer ist als die Anfrage. */
export async function holeProtokoll(
  dienst: string,
  anfragen: (aktion: Handgriff, dienst?: string) => Promise<boolean>,
  warten: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms)),
): Promise<GeraetProtokoll | string> {
  const seit = Date.now() - 2_000; // Uhren von Browser und Gerät gehen nicht auf die Sekunde gleich
  if (!(await anfragen("protokoll", dienst))) return "Das Protokoll ließ sich nicht anfragen.";
  for (let i = 0; i < 20; i++) {
    await warten(1_500);
    const antwort = await fetch(`${ADRESSE}/protokoll/${encodeURIComponent(dienst)}`, { cache: "no-store" }).catch(() => null);
    if (!antwort?.ok) continue;
    const p = (await antwort.json()) as GeraetProtokoll;
    if (p.vorhanden && p.erstellt_am && new Date(p.erstellt_am).getTime() >= seit) return p;
  }
  return "Das Gerät hat das Protokoll nicht geliefert. Läuft dort der Anfrage-Dienst?";
}
