"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";

import { Icon } from "@/components/ui/Icon";
import { Kachel, useKarten } from "@/components/layout/Bereichsuebersicht";
import { api, ApiError } from "@/lib/api/client";
import type { Handeingriff, Handeingriffe } from "@/lib/api/models";
import { AREAS, EINSTELLUNGEN, STUFEN, nurHausherr, sucheEinstellungen, type Einstellung } from "@/lib/areas";
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
 */

const ZEICHEN: Record<Handeingriff["art"], string> = {
  waermepumpe: "pump",
  ofen: "stove",
  speicher: "battery",
  raum: "thermo",
};

const LEER = "Alles regelt die Automatik. Nichts ist gerade von Hand gestellt.";

function Zeile({ einstellung }: { einstellung: Einstellung }) {
  return (
    <Link href={einstellung.weg} className="einstellen-zeile">
      <span>{einstellung.name}</span>
      <span aria-hidden="true" className="einstellen-pfeil">›</span>
    </Link>
  );
}

function Handeingriffsliste({ darfStellen }: { darfStellen: boolean }) {
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
    <section className="einstellen-abschnitt" aria-label="Gerade von Hand gestellt">
      <header className="uebersicht-kopf">
        <h2 className="uebersicht-name">Gerade von Hand gestellt</h2>
        {eingriffe.length > 0 ? <span className="uebersicht-wort">{eingriffe.length}</span> : null}
      </header>
      {fehler ? <p className="einstellen-hinweis">{fehler}</p> : null}
      {stand && eingriffe.length === 0 ? <p className="einstellen-hinweis">{LEER}</p> : null}
      {eingriffe.length > 0 ? (
        <ul className="einstellen-eingriffe">
          {eingriffe.map((e) => (
            <li key={`${e.art}-${e.satz_de}`}>
              <Link href={e.weg} className="einstellen-eingriff">
                <span className="einstellen-eingriff-zeichen" aria-hidden="true">
                  <Icon name={ZEICHEN[e.art]} size={18} />
                </span>
                <span>{e.satz_de}</span>
              </Link>
            </li>
          ))}
        </ul>
      ) : null}
      {meldung ? <p className="einstellen-hinweis">{meldung}</p> : null}
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
          <button type="button" className="einstellen-knopf" onClick={() => setFragt(true)}>
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
            <div className="einstellen-liste">
              {treffer.map((e) => (
                <Zeile key={e.name} einstellung={e} />
              ))}
            </div>
          ) : (
            <p className="einstellen-hinweis">Dazu gibt es keine Einstellung.</p>
          )}
        </section>
      ) : null}

      <Handeingriffsliste darfStellen={darfStellen} />

      <div className="einstellen-stufen">
        {STUFEN.filter((s) => hausherr || !s.nurHausherr).map((stufe) => {
          const einstellungen = EINSTELLUNGEN.filter((e) => e.stufe === stufe.schluessel).filter(
            (e) => hausherr || !nurHausherr(e.weg),
          );
          if (einstellungen.length === 0) return null;
          return (
            <section key={stufe.schluessel} className="einstellen-abschnitt" aria-label={stufe.name}>
              <header className="uebersicht-kopf">
                <h2 className="uebersicht-name">{stufe.name}</h2>
                <span className="uebersicht-wort">{stufe.wort}</span>
              </header>
              <div className="einstellen-liste">
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
