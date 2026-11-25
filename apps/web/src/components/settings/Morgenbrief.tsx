"use client";

import { useCallback, useEffect, useState } from "react";
import { Systemkarte } from "@/components/ui/Systemkarte";
import { api } from "@/lib/api/client";
import type { Morgenbrief as Stand } from "@/lib/api/models";

/**
 * Das Morning Briefing: eine Mitteilung am Morgen mit dem, was der Tag bringt.
 *
 * Vier kurze Zeilen: erwartete Sonne, Strompreis, Wärme und was die Wärme kostet, geteilt in
 * Strom und Pellets. Es kommt von selbst, bevor jemand das Haus verlässt.
 *
 * Die Seite zeigt das aktuelle Briefing, auch wenn es ausgeschaltet ist: wer es einschalten soll,
 * muss sehen können, was er bekommt. Dasselbe schicken beide Probeknöpfe der Seite (Nutzerwunsch
 * 13.11.2026: die Probe soll das aktuelle Briefing sein, kein fester Satz). Es geht an alle
 * Geräte, die oben für Mitteilungen angemeldet sind; ein eigenes Abonnement gibt es nicht.
 */

export function Morgenbrief() {
  const [stand, setStand] = useState<Stand | null>(null);
  const [laeuft, setLaeuft] = useState(false);
  const [meldung, setMeldung] = useState<string | null>(null);
  const [details, setDetails] = useState<string[]>([]);

  const lade = useCallback(async () => {
    try {
      setStand(await api.morgenbrief());
    } catch {
      setMeldung("Das Morning Briefing ist gerade nicht zu erreichen.");
    }
  }, []);
  useEffect(() => {
    void lade();
  }, [lade]);

  const schalte = async (an: boolean) => {
    setLaeuft(true);
    setMeldung(null);
    try {
      setStand(await api.setMorgenbrief(an));
    } catch {
      setMeldung("Das hat nicht geklappt. Die Einstellung ist unverändert.");
    } finally {
      setLaeuft(false);
    }
  };

  const sende = async () => {
    setLaeuft(true);
    setMeldung(null);
    setDetails([]);
    try {
      const antwort = await api.morgenbriefSenden();
      setMeldung(antwort.message_de);
      setDetails(antwort.details_de ?? []);
    } catch {
      setMeldung("Das Briefing ließ sich nicht verschicken.");
    } finally {
      setLaeuft(false);
    }
  };

  return (
    <Systemkarte zeichen="sun" titel="Morning Briefing" satz={briefsatz(stand?.uhrzeit)}>
      {stand ? (
        <>
          <span className="konto-leise">{stand.fuer_de === "morgen" ? "So sähe das Briefing morgen früh aus:" : "Das Briefing für heute:"}</span>
          <div className="morgenbrief-vorschau">
            <span className="morgenbrief-titel">{stand.titel ?? "Morning Briefing"}</span>
            {stand.zeilen && stand.zeilen.length > 0 ? stand.zeilen.map((z) => <span key={z}>{z}</span>) : <span className="text-text-3">{stand.hinweis_de}</span>}
          </div>
          <div className="konto-reihe">
            <span className="zustand-marke" data-an={stand.enabled ? "" : undefined}>{stand.enabled ? "eingeschaltet" : "ausgeschaltet"}</span>
            <button type="button" className="zugang-knopf" onClick={() => void schalte(!stand.enabled)} disabled={laeuft}>
              {stand.enabled ? "Ausschalten" : "Einschalten"}
            </button>
            <button type="button" className="zugang-knopf" onClick={() => void sende()} disabled={laeuft || !stand.zeilen || stand.zeilen.length === 0}>
              Jetzt senden
            </button>
          </div>
        </>
      ) : null}
      {stand && stand.enabled && (stand.geraete ?? 0) === 0 ? (
        <p className="m-0 text-[14px] leading-[1.5] text-amber-soft">Kein Gerät angemeldet. Das Briefing geht an niemanden.</p>
      ) : null}
      {stand?.zuletzt_de ? <p className="konto-leise">{stand.zuletzt_de}</p> : null}
      {meldung ? <p className="m-0 text-[14px] leading-[1.5] text-text-2">{meldung}</p> : null}
      {details.length > 0 ? (
        <ul className="m-0 flex list-none flex-col gap-1 p-0 text-[14px] leading-[1.5] text-text-2">
          {details.map((d) => <li key={d}>{d}</li>)}
        </ul>
      ) : null}
    </Systemkarte>
  );
}

/** Der Satz unter dem Titel; derselbe in der App (`Mitteilungsstand.briefsatz`). */
export const briefsatz = (uhrzeit?: string | null): string =>
  `Jeden Morgen um ${uhrzeit || "07:00"} Uhr: Sonne, Strompreis und Wärme des Tages.`;
