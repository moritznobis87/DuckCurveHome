"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { Morgenbrief as Stand } from "@/lib/api/models";

/**
 * Der Morgenbrief: eine Mitteilung am Morgen mit dem, was der Tag bringt.
 *
 * Erwartete Sonne, günstigste und teuerste Zeit für Netzstrom, geplante Läufe der Wärmepumpe.
 * Dasselbe steht im Ausblick der Startseite; der Brief kommt von selbst, bevor jemand das Haus
 * verlässt.
 *
 * Die Seite zeigt den Brief, wie er jetzt verschickt würde, auch wenn er ausgeschaltet ist: wer
 * ihn einschalten soll, muss sehen können, was er bekommt. Er geht an alle Geräte, die oben für
 * Mitteilungen angemeldet sind; ein eigenes Abonnement gibt es nicht.
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
      setMeldung("Der Morgenbrief ist gerade nicht zu erreichen.");
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
      setMeldung("Das hat nicht geklappt. Der Brief ist unverändert.");
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
      setMeldung("Der Brief ließ sich nicht verschicken.");
    } finally {
      setLaeuft(false);
    }
  };

  return (
    <div className="flex max-w-[760px] flex-col gap-4 rounded-[3px] border border-line-1 bg-surface-2 p-5">
      <div className="flex flex-col gap-1">
        <span className="kicker" style={{ fontSize: 11 }}>Morgenbrief</span>
        <span className="text-[15px] leading-[1.6] text-text-2">
          Jeden Morgen um {stand?.uhrzeit ?? "07:00"} Uhr eine Mitteilung mit dem, was der Tag bringt: wie viel Sonne zu erwarten ist, wann Strom am günstigsten ist und wann die
          Wärmepumpe laufen soll. Er geht an alle Geräte, die für Mitteilungen angemeldet sind.
        </span>
      </div>

      {stand ? <span className="text-[13px] text-text-3">So sähe der Brief {stand.fuer_de === "morgen" ? "morgen früh" : "heute"} aus:</span> : null}
      {stand ? (
        <div className="morgenbrief-vorschau">
          <span className="morgenbrief-titel">{stand.titel ?? "Heute im Haus"}</span>
          {stand.zeilen && stand.zeilen.length > 0 ? stand.zeilen.map((z) => <span key={z}>{z}</span>) : <span className="text-text-3">{stand.hinweis_de}</span>}
        </div>
      ) : null}

      <div className="flex flex-wrap items-center gap-3">
        {stand ? (
          <>
            <span className="text-[14px]" style={{ color: stand.enabled ? "var(--pv)" : "var(--text-3)" }}>{stand.enabled ? "Der Morgenbrief ist eingeschaltet." : "Der Morgenbrief ist ausgeschaltet."}</span>
            <button type="button" className={knopf} onClick={() => void schalte(!stand.enabled)} disabled={laeuft}>
              {stand.enabled ? "Ausschalten" : "Einschalten"}
            </button>
            <button type="button" className={knopf} onClick={() => void sende()} disabled={laeuft || !stand.zeilen || stand.zeilen.length === 0}>
              Jetzt zur Probe senden
            </button>
          </>
        ) : null}
      </div>
      {stand && stand.enabled && (stand.geraete ?? 0) === 0 ? (
        <p className="m-0 text-[14px] leading-[1.6]" style={{ color: "var(--amber-soft)" }}>
          Zurzeit ist kein Gerät für Mitteilungen angemeldet. Der Brief geht deshalb an niemanden; oben auf dieser Seite lässt sich dieses Gerät anmelden.
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
