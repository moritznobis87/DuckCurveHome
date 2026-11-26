"use client";

// Der Stand des Update-Dienstes auf dem Hausgerät (deploy/haus/dch, routers/update.py).
//
// Die Oberfläche fragt nur; installiert wird auf dem Gerät. Während eines Updates startet der Dienst
// API und Oberfläche neu, dann schlägt die Abfrage eine Weile fehl. Das ist kein Fehler, sondern der
// Neustart: In dieser Zeit gilt `neustart`, und sobald die neue Fassung antwortet, lädt die Seite neu.

import { useCallback, useEffect, useRef, useState } from "react";

export type Neuerung = { version?: string | null; bereich: string; text: string };

export type UpdateStatus = {
  unterstuetzt: boolean;
  kanal: string | null;
  aktuell: string | null;
  verfuegbar: string | null;
  update_verfuegbar: boolean;
  /** Aus docs/versionen.json, für Außenstehende geschrieben; `version` leer = noch keiner Version zugeordnet. */
  neuerungen: Neuerung[];
  geprueft_am: string | null;
  zustand: string;
  schritt: string | null;
  meldung: string | null;
  zuletzt: { am: string | null; ergebnis: string | null; von: string | null; nach: string | null } | null;
  anfrage_offen: boolean;
  /** Welche Anfrage wartet: `installieren`, `pruefen` oder eine Aktion der Seite Hausgerät. */
  anfrage?: string | null;
};

const ADRESSE = "/api/dch/system/update";
/** Im Ruhezustand alle fünf Minuten; der Dienst selbst prüft ohnehin nur alle sechs Stunden. */
const RUHIG_MS = 5 * 60_000;
/** Während eines Updates alle drei Sekunden, damit der Fortschritt mitläuft. */
const EILIG_MS = 3_000;

/**
 * Die Neuerungen in Gruppen derselben Version, in der Reihenfolge des Dienstes (neueste zuerst).
 * Eine Überschrift braucht es erst ab zwei Gruppen; die App gruppiert genauso
 * (`Hausgeraet.neuerungenNachVersion`).
 */
export function nachVersion(neuerungen: Neuerung[]): { version: string | null; eintraege: Neuerung[] }[] {
  const gruppen: { version: string | null; eintraege: Neuerung[] }[] = [];
  for (const n of neuerungen) {
    const version = n.version ?? null;
    const letzte = gruppen[gruppen.length - 1];
    if (letzte && letzte.version === version) letzte.eintraege.push(n);
    else gruppen.push({ version, eintraege: [n] });
  }
  return gruppen;
}

export function gruppentitel(version: string | null): string {
  return version ? `Version ${version}` : "Seit der letzten Version";
}

/**
 * Ob ein Update läuft oder angefragt ist. Nur die Anfrage `installieren` zählt: Alle Anfragen
 * an das Gerät teilen sich eine Datei, und vorher zeigte „Jetzt nach Updates sehen“ hier
 * „Update läuft“. Die App entscheidet genauso (`Hausgeraet.updateLaeuft`).
 */
export function laeuft(s: UpdateStatus | null): boolean {
  return Boolean(s && (s.zustand === "laeuft" || s.anfrage === "installieren"));
}

/** Ob das Gerät gerade auf Wunsch nach Updates sieht (`Hausgeraet.suchtUpdates` in der App). */
export function sucht(s: UpdateStatus | null): boolean {
  return Boolean(s && s.anfrage === "pruefen");
}

/**
 * Ob die angebotene Fassung genau die ist, die beim letzten Versuch nicht gesund hochkam. Dann
 * drängt der Hinweis nicht mehr; auf der Seite „Software“ bleibt sie zum erneuten Versuch stehen.
 */
export function schonGescheitert(s: UpdateStatus | null): boolean {
  return Boolean(s?.verfuegbar && s.zuletzt && s.zuletzt.ergebnis !== "ok" && s.zuletzt.nach === s.verfuegbar);
}

export function useUpdate(aktiv = true) {
  const [status, setStatus] = useState<UpdateStatus | null>(null);
  const [neustart, setNeustart] = useState(false);
  const [fehler, setFehler] = useState<string | null>(null);
  const warLaufend = useRef(false);

  const laden = useCallback(async () => {
    try {
      const antwort = await fetch(ADRESSE, { cache: "no-store" });
      if (!antwort.ok) throw new Error(String(antwort.status));
      const neu = (await antwort.json()) as UpdateStatus;
      // Lief eben noch ein Update, ist es jetzt zu Ende und hat die Fassung gewechselt: neu laden,
      // damit Browser und neue Oberfläche zusammenpassen.
      if (warLaufend.current && !laeuft(neu)) {
        warLaufend.current = false;
        if (neu.zustand === "fertig") window.location.reload();
      }
      if (laeuft(neu)) warLaufend.current = true;
      setNeustart(false);
      setStatus(neu);
    } catch {
      // Während eines Updates ist das der Neustart, sonst schlicht keine Auskunft.
      if (warLaufend.current) setNeustart(true);
    }
  }, []);

  // Abhaengig nur vom Takt, nicht vom Status selbst: Jede Antwort ist ein neues Objekt, und ein
  // Effekt, der daran haengt, fragte sofort wieder - ohne Pause, endlos.
  const eilig = laeuft(status) || sucht(status) || neustart;
  useEffect(() => {
    if (!aktiv) return;
    void laden();
    const timer = setInterval(() => void laden(), eilig ? EILIG_MS : RUHIG_MS);
    return () => clearInterval(timer);
  }, [aktiv, laden, eilig]);

  const anfragen = useCallback(
    async (aktion: "installieren" | "pruefen") => {
      setFehler(null);
      try {
        const antwort = await fetch(ADRESSE, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ aktion }),
        });
        const daten = (await antwort.json().catch(() => null)) as (UpdateStatus & { error?: { message?: string } }) | null;
        if (!antwort.ok || !daten) throw new Error(daten?.error?.message ?? "Die Anfrage ging nicht durch.");
        warLaufend.current = aktion === "installieren";
        setStatus(daten);
      } catch (e) {
        setFehler(e instanceof Error ? e.message : "Die Anfrage ging nicht durch.");
      }
    },
    [],
  );

  return { status, neustart, fehler, anfragen, neu_laden: laden };
}
