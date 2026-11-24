"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";

import { Icon } from "@/components/ui/Icon";
import { Zustandszeichen } from "@/components/ui/Zustandszeichen";
import { Kachel, useKarten } from "@/components/layout/Bereichsuebersicht";
import { api, ApiError } from "@/lib/api/client";
import type { Handeingriff, Handeingriffe } from "@/lib/api/models";
import { AREAS, EINSTELLUNGEN, SEITENFARBE, STUFEN, nurHausherr, sucheEinstellungen, type Einstellung } from "@/lib/areas";
import { useSitzung } from "@/lib/live/useRole";

/**
 * Die Seite „Einstellen“, hinter dem Zahnrad.
 *
 * Der Hausherr hat sie am 24.11.2026 so entschieden: oben, was gerade von Hand gestellt ist, mit
 * „Alles zurück auf Automatik“; darunter die Einstellungen in drei Stufen, von leicht nach
 * schwer; zuletzt die Seiten des Systems. **Die Einstellungen bleiben bei ihrem Gegenstand**:
 * Hier steht nur, wo man sie findet, und die Suche findet sie auch unter einem anderen Wort.
 *
 * Jeder, der im Haus stellen darf, sieht die Seite. „Abstimmen“ und die Systemseiten bleiben dem
 * Hausherrn. Dieselbe Seite baut die App (`EinstellenSeite.swift`) aus demselben Katalog
 * (`docs/seitenbaum.json`, `stufen` und `einstellungen`).
 *
 * **Das Bild der Übersichten.** Seit dem 24.11.2026 trägt die Seite dieselbe Bildsprache wie
 * die Übersichten der Bereiche: Oben steht eine Zustandskarte, grün, wenn alles die Automatik
 * regelt, und bernsteinfarben mit den Eingriffen und dem Knopf, wenn etwas von Hand gestellt ist.
 * Jede Stufe ist eine Karte mit eigenem Zeichen und eigener Farbe, und jede Einstellung hat ihr
 * Zeichen. Zeichen und Farben stehen im Seitenbaum, damit die App dieselben zeigt.
 */

const ZEICHEN: Record<Handeingriff["art"], string> = {
  waermepumpe: "pump",
  ofen: "stove",
  speicher: "battery",
  raum: "thermo",
};

/** Die Sätze der Zustandskarte; dieselben stehen in der App (`Einstellworte.swift`). */
export function zustandssatz(anzahl: number | null): { titel: string; satz: string } {
  if (anzahl == null) return { titel: "Automatik", satz: "Der Stand wird abgefragt." };
  if (anzahl === 0) return { titel: "Alles auf Automatik", satz: "Nichts ist gerade von Hand gestellt." };
  return {
    titel: anzahl === 1 ? "1 Eingriff von Hand" : `${anzahl} Eingriffe von Hand`,
    satz: "Jeder endet von selbst, wenn seine Frist abläuft.",
  };
}

function Zeile({ einstellung }: { einstellung: Einstellung }) {
  return (
    <Link href={einstellung.weg} className="einstellen-zeile">
      <span className="einstellen-zeile-zeichen" aria-hidden="true">
        <Icon name={einstellung.zeichen} size={17} />
      </span>
      <span className="einstellen-zeile-name">{einstellung.name}</span>
      <span aria-hidden="true" className="einstellen-pfeil">›</span>
    </Link>
  );
}

function Zustandskarte({ darfStellen }: { darfStellen: boolean }) {
  const [stand, setStand] = useState<Handeingriffe | null>(null);
  const [fehler, setFehler] = useState<string>();
  const [meldung, setMeldung] = useState<string>();
  const [fragt, setFragt] = useState(false);
  const [laeuft, setLaeuft] = useState(false);

  const laden = useCallback(() => {
    void api
      .handeingriffe()
      .then((s) => {
        setStand(s);
        setFehler(undefined);
      })
      .catch(() => setFehler("Was gerade von Hand gestellt ist, lässt sich gerade nicht abfragen."));
  }, []);

  useEffect(() => {
    laden();
    const takt = setInterval(laden, 60_000);
    return () => clearInterval(takt);
  }, [laden]);

  const eingriffe = stand?.eingriffe ?? [];
  const zurueck = eingriffe.filter((e) => e.zuruecksetzbar);
  const { titel, satz } = zustandssatz(stand ? eingriffe.length : null);
  const zustand = !stand ? "offen" : eingriffe.length ? "hand" : "automatik";

  async function zuruecksetzen() {
    setLaeuft(true);
    setMeldung(undefined);
    try {
      const antwort = await api.automatikZurueck();
      setStand(antwort.handeingriffe);
      setMeldung(antwort.meldung_de);
    } catch (e) {
      setMeldung(e instanceof ApiError ? e.message : "Das Zurückstellen ging nicht durch.");
    } finally {
      setLaeuft(false);
      setFragt(false);
    }
  }

  return (
    <section className="einstellen-status" data-zustand={zustand} aria-label="Gerade von Hand gestellt">
      <div className="einstellen-status-kopf">
        <span className="einstellen-status-zeichen" aria-hidden="true">
          {zustand === "hand" ? <Icon name="sliders" size={22} /> : <Zustandszeichen zustand={zustand === "automatik" ? "gut" : "aus"} gross stumm />}
        </span>
        <div className="min-w-0">
          <h2 className="einstellen-status-titel">{titel}</h2>
          <p className="einstellen-status-satz">{fehler ?? satz}</p>
        </div>
      </div>
      {eingriffe.length > 0 ? (
        <ul className="einstellen-eingriffe">
          {eingriffe.map((e) => (
            <li key={`${e.art}-${e.satz_de}`}>
              <Link href={e.weg} className="einstellen-eingriff">
                <span className="einstellen-eingriff-zeichen" aria-hidden="true">
                  <Icon name={ZEICHEN[e.art]} size={18} />
                </span>
                <span className="min-w-0 flex-1">{e.satz_de}</span>
                <span aria-hidden="true" className="einstellen-pfeil">›</span>
              </Link>
            </li>
          ))}
        </ul>
      ) : null}
      {meldung ? <p className="einstellen-status-satz">{meldung}</p> : null}
      {darfStellen && zurueck.length > 0 ? (
        fragt ? (
          <div className="einstellen-rueckfrage" role="alertdialog" aria-label="Alles zurück auf Automatik?">
            <p className="m-0">Zurück auf Automatik gehen:</p>
            <ul>
              {zurueck.map((e) => (
                <li key={e.satz_de}>{e.satz_de}</li>
              ))}
            </ul>
            {eingriffe.length > zurueck.length ? (
              <p className="m-0 einstellen-leise">Räume, die jemand von Hand gestellt hat, bleiben, wie sie sind.</p>
            ) : null}
            <div className="flex flex-wrap gap-3">
              <button type="button" className="einstellen-knopf einstellen-knopf-an" disabled={laeuft} onClick={() => void zuruecksetzen()}>
                {laeuft ? "Stelle zurück…" : "Zurückstellen"}
              </button>
              <button type="button" className="einstellen-knopf" onClick={() => setFragt(false)}>
                Abbrechen
              </button>
            </div>
          </div>
        ) : (
          <button type="button" className="einstellen-knopf einstellen-knopf-an" onClick={() => setFragt(true)}>
            <Icon name="loop" size={17} />
            Alles zurück auf Automatik
          </button>
        )
      ) : null}
    </section>
  );
}

export function Einstellen() {
  const sitzung = useSitzung();
  // Abstimmen und System erst zeigen, wenn feststeht, dass hier der Hausherr sitzt: Ein Bewohner
  // sähe sie sonst eine Sekunde lang, und die Karten des Systems kämen für ihn als Absage zurück.
  const hausherr = sitzung.bekannt && sitzung.hausherr;
  const role = sitzung.role;
  const darfStellen = role === "owner";
  const [suche, setSuche] = useState("");
  const treffer = useMemo(() => sucheEinstellungen(suche, hausherr), [suche, hausherr]);
  const system = AREAS.find((a) => a.key === "system");
  const karten = useKarten("system", hausherr);

  return (
    <div className="einstellen">
      <label className="einstellen-suche">
        <span className="sr-only">Einstellung suchen</span>
        <span className="einstellen-suche-zeichen" aria-hidden="true">
          <Icon name="search" size={18} />
        </span>
        <input
          type="search"
          value={suche}
          onChange={(e) => setSuche(e.target.value)}
          placeholder="Einstellung suchen, etwa „Heizkurve“"
          autoComplete="off"
        />
      </label>
      {suche.trim() ? (
        <section className="einstellen-abschnitt" aria-label="Gefunden">
          {treffer.length > 0 ? (
            <div className="einstellen-zeilen einstellen-treffer">
              {treffer.map((e) => (
                <Zeile key={e.name} einstellung={e} />
              ))}
            </div>
          ) : (
            <p className="einstellen-hinweis">Dazu gibt es keine Einstellung.</p>
          )}
        </section>
      ) : null}

      <Zustandskarte darfStellen={darfStellen} />

      <div className="einstellen-stufen">
        {STUFEN.filter((s) => hausherr || !s.nurHausherr).map((stufe) => {
          const einstellungen = EINSTELLUNGEN.filter((e) => e.stufe === stufe.schluessel).filter(
            (e) => hausherr || !nurHausherr(e.weg),
          );
          if (einstellungen.length === 0) return null;
          return (
            <section
              key={stufe.schluessel}
              className="einstellen-stufe"
              aria-label={stufe.name}
              style={{ "--kachelfarbe": SEITENFARBE[stufe.farbe] } as React.CSSProperties}
            >
              <header className="einstellen-stufe-kopf">
                <span className="uebersicht-zeichen" aria-hidden="true">
                  <Icon name={stufe.zeichen} size={20} />
                </span>
                <div className="min-w-0">
                  <h2 className="einstellen-stufe-name">{stufe.name}</h2>
                  <p className="einstellen-stufe-wort">{stufe.wort}</p>
                </div>
              </header>
              <div className="einstellen-zeilen">
                {einstellungen.map((e) => (
                  <Zeile key={e.name} einstellung={e} />
                ))}
              </div>
            </section>
          );
        })}
      </div>

      {hausherr && system ? (
        <section className="einstellen-abschnitt" aria-label="System">
          <header className="uebersicht-kopf">
            <h2 className="uebersicht-name">System</h2>
            <span className="uebersicht-wort">was das Haus am Laufen hält</span>
          </header>
          <div className="uebersicht-karten">
            {system.tabs.map((seite) => (
              <Kachel key={seite.href} seite={seite} karte={karten[seite.href]} />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
