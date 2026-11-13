"use client";

import { useCallback, useEffect, useState } from "react";
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
const knopf = "rounded-[3px] border border-line-2 px-3 py-2 text-[13px] text-text-1 disabled:opacity-50";

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
    <div className="flex max-w-[760px] flex-col gap-4 rounded-[3px] border border-line-1 bg-surface-2 p-5">
      <div className="flex flex-col gap-1">
        <span className="kicker" style={{ fontSize: 11 }}>Morning Briefing</span>
        <span className="text-[15px] leading-[1.6] text-text-2">
          Jeden Morgen um {stand?.uhrzeit ?? "07:00"} Uhr eine kurze Mitteilung: wie viel Sonne zu erwarten ist, was Strom kostet, wie viel Wärme das Haus braucht und was
          sie kostet, geteilt in Strom und Pellets. Sie geht an alle Geräte, die für Mitteilungen angemeldet sind.
        </span>
      </div>

      {stand ? (
        <span className="text-[13px] text-text-3">
          {stand.fuer_de === "morgen" ? "Vom heutigen Tag ist zu wenig übrig. So sähe das Briefing morgen früh aus:" : "Das aktuelle Briefing, für den Rest von heute:"}
        </span>
      ) : null}
      {stand ? (
        <div className="morgenbrief-vorschau">
          <span className="morgenbrief-titel">{stand.titel ?? "Morning Briefing"}</span>
          {stand.zeilen && stand.zeilen.length > 0 ? stand.zeilen.map((z) => <span key={z}>{z}</span>) : <span className="text-text-3">{stand.hinweis_de}</span>}
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-3">
        {stand ? (
          <>
            <span className="text-[14px]" style={{ color: stand.enabled ? "var(--pv)" : "var(--text-3)" }}>{stand.enabled ? "Das Morning Briefing ist eingeschaltet." : "Das Morning Briefing ist ausgeschaltet."}</span>
            <button type="button" className={knopf} onClick={() => void schalte(!stand.enabled)} disabled={laeuft}>
              {stand.enabled ? "Ausschalten" : "Einschalten"}
            </button>
            <button type="button" className={knopf} onClick={() => void sende()} disabled={laeuft || !stand.zeilen || stand.zeilen.length === 0}>
              Jetzt senden
            </button>
          </>
        ) : null}
      </div>
      {stand && stand.enabled && (stand.geraete ?? 0) === 0 ? (
        <p className="m-0 text-[14px] leading-[1.6]" style={{ color: "var(--amber-soft)" }}>
          Zurzeit ist kein Gerät für Mitteilungen angemeldet. Das Briefing geht deshalb an niemanden; oben auf dieser Seite lässt sich dieses Gerät anmelden.
        </p>
      ) : null}
      {stand?.zuletzt_de ? <p className="m-0 text-[13px] leading-[1.6] text-text-3">{stand.zuletzt_de}</p> : null}
      {meldung ? <p className="m-0 text-[14px] leading-[1.6] text-text-2">{meldung}</p> : null}
      {details.length > 0 ? (
        <ul className="m-0 flex list-none flex-col gap-1 p-0 text-[14px] leading-[1.6] text-text-2">
          {details.map((d) => <li key={d}>{d}</li>)}
        </ul>
      ) : null}
    </div>
  );
}
