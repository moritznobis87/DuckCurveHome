"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Zustandszeichen } from "@/components/ui/Zustandszeichen";
import { api } from "@/lib/api/client";
import type { Uebersichtskarte } from "@/lib/api/models";
import { Icon } from "@/components/ui/Icon";
import { AREAS, SEITENFARBE, hatUebersicht, tabsDerGruppe, type Area, type Tab } from "@/lib/areas";
import { useSitzung } from "@/lib/live/useRole";
import { AreaShell } from "./AreaShell";
import { Kachelbild } from "./Kachelbild";

/** Wie oft die Karten ihre Zahlen neu holen. Die Übersicht steht auch an der Wand. */
const ERNEUERN_MS = 60_000;

/**
 * Die Karten des Dienstes zu einem Bereich, nach Adresse. Leer, solange nichts geladen ist oder
 * der Dienst nicht antwortet: dann stehen die Karten ohne Zahl da, mit ihrem festen Satz.
 */
export function useKarten(bereich: string, an = true): Record<string, Uebersichtskarte> {
  const [karten, setKarten] = useState<Record<string, Uebersichtskarte>>({});
  useEffect(() => {
    // Wer die Karten nicht sehen darf, fragt nicht danach (die Übersicht des Systems ist eine Akte).
    if (!an) return;
    let lebt = true;
    const holen = () =>
      api
        .uebersicht(bereich)
        .then((antwort) => {
          if (lebt) setKarten(Object.fromEntries((antwort.karten ?? []).map((k) => [k.weg, k])));
        })
        .catch(() => {
          // Die Übersicht bleibt benutzbar; alte Zahlen stehen zu lassen wäre schlechter als keine.
          if (lebt) setKarten({});
        });
    void holen();
    const takt = setInterval(holen, ERNEUERN_MS);
    return () => {
      lebt = false;
      clearInterval(takt);
    };
  }, [bereich, an]);
  return karten;
}

/**
 * Die Leitzahl in Zahl und Einheit zerlegt: „19,1 kWh“ wird zu „19,1“ und „kWh“.
 *
 * Der Dienst liefert sie als einen Text. Auf der Kachel steht die Zahl groß und die Einheit
 * klein dahinter; das ist die ganze Zerlegung, gerechnet wird hier nichts. Ein Text ohne
 * Leerzeichen bleibt ganz die Zahl.
 */
export function zahlUndEinheit(leitzahl: string): { zahl: string; einheit: string } {
  const schnitt = leitzahl.lastIndexOf(" ");
  if (schnitt < 0) return { zahl: leitzahl, einheit: "" };
  return { zahl: leitzahl.slice(0, schnitt), einheit: leitzahl.slice(schnitt + 1) };
}

/**
 * Die Übersicht eines Bereichs: jede Kachel eine Seite. Hat der Bereich Gruppen, steht je Gruppe
 * eine Reihe Kacheln unter ihrem Namen; hat er keine, stehen alle in einem Raster.
 *
 * **Eine Kachel zeigt, sie erklärt nicht.** Bis zum 24.11.2026 stand auf jeder Karte ein Satz
 * darüber, wovon die Seite handelt, und darunter ihre Ansichten. Am Telefon waren das sechs
 * Kästen voll Text, und der Hausherr hat es so genannt: grafisch schwach, viel zu viel Text.
 * Jetzt trägt jede Kachel das Zeichen der Seite in der Farbe ihrer Sache, den Namen, die
 * Leitzahl groß und ein Wort dazu. Der Satz steht weiter da, für die Vorlesehilfe und als
 * Hinweis unter dem Zeiger, und sichtbar nur dort, wo eine Seite keine Zahl hat.
 *
 * Was nur der Hausherr sieht, fehlt den anderen hier wie in der Reiterzeile. Eine Gruppe, von
 * der danach nichts übrig ist, wird nicht gezeichnet.
 *
 * **Leitzahl und Ampel kommen vom Dienst** (`GET /uebersicht/{bereich}`): je Seite ihre
 * wichtigste Zahl und ein Zustand, fertig formuliert, damit das Dashboard und die App dasselbe
 * zeigen. Eine Ampel, die nicht gut ist, bringt ihren Grund als Satz mit; er steht auf der
 * Kachel an der Stelle des Wortes. Zeichen und Farbe trägt der Seitenbaum.
 */
/** Eine Seite als Kachel: Zeichen in der Farbe ihrer Sache, Zustand, Name, Leitzahl, Wort, Bild. */
export function Kachel({ seite, karte }: { seite: Tab; karte?: Uebersichtskarte }) {
  const leitzahl = karte?.leitzahl_de ? zahlUndEinheit(karte.leitzahl_de) : null;
  return (
    <Link
      href={seite.href}
      className="uebersicht-karte"
      data-ampel={karte?.ampel}
      title={seite.beschreibung}
      style={{ "--kachelfarbe": SEITENFARBE[seite.farbe] } as React.CSSProperties}
    >
      <span className="uebersicht-kopfzeile">
        <span className="uebersicht-zeichen" aria-hidden="true">
          <Icon name={seite.icon} size={22} />
        </span>
        {karte ? <Zustandszeichen zustand={karte.ampel ?? "aus"} /> : null}
      </span>
      <span className="uebersicht-titel">{seite.label}</span>
      {leitzahl ? (
        <span className="uebersicht-zahl">
          <span className="mono uebersicht-leitzahl">{leitzahl.zahl}</span>
          {leitzahl.einheit ? <span className="mono uebersicht-einheit">{leitzahl.einheit}</span> : null}
        </span>
      ) : null}
      {karte?.grund_de ? (
        <span className="uebersicht-grund">{karte.grund_de}</span>
      ) : karte?.dazu_de ? (
        <span className="uebersicht-dazu">{karte.dazu_de}</span>
      ) : !leitzahl && seite.beschreibung ? (
        <span className="uebersicht-satz">{seite.beschreibung}</span>
      ) : null}
      {karte?.bild ? <Kachelbild bild={karte.bild} /> : null}
    </Link>
  );
}

export function Bereichsuebersicht({ bereich }: { bereich: Area["key"] }) {
  const { hausherr } = useSitzung();
  const area = AREAS.find((a) => a.key === bereich);
  const karten = useKarten(bereich);
  if (!area || !hatUebersicht(area)) return null;
  // Ein Bereich ohne Gruppen ist eine einzige Gruppe ohne Namen.
  const gruppen = area.gruppen ?? [null];
  return (
    <AreaShell kicker={`Alle Seiten im Bereich ${area.label}`}>
      <div className={`uebersicht${area.gruppen ? "" : " uebersicht-flach"}`}>
        {gruppen.map((gruppe) => {
          const seiten = (gruppe ? tabsDerGruppe(area, gruppe.name) : area.tabs).filter((t) => !t.ownerOnly || hausherr);
          if (seiten.length === 0) return null;
          return (
            <section key={gruppe?.name ?? area.key} className="uebersicht-gruppe" aria-label={gruppe?.name ?? `Seiten im Bereich ${area.label}`}>
              {gruppe ? (
                <header className="uebersicht-kopf">
                  <h2 className="uebersicht-name">{gruppe.name}</h2>
                  <span className="uebersicht-wort">{gruppe.wort}</span>
                </header>
              ) : null}
              <div className="uebersicht-karten">
                {seiten.map((seite) => (
                  <Kachel key={seite.href} seite={seite} karte={karten[seite.href]} />
                ))}
              </div>
            </section>
          );
        })}
      </div>
    </AreaShell>
  );
}
