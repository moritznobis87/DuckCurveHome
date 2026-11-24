"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Zustandszeichen } from "@/components/ui/Zustandszeichen";
import { api } from "@/lib/api/client";
import type { Uebersichtskarte } from "@/lib/api/models";
import { AREAS, hatUebersicht, tabsDerGruppe, type Area } from "@/lib/areas";
import { useSitzung } from "@/lib/live/useRole";
import { AreaShell } from "./AreaShell";

/** Wie oft die Karten ihre Zahlen neu holen. Die Übersicht steht auch an der Wand. */
const ERNEUERN_MS = 60_000;

/**
 * Die Karten des Dienstes zu einem Bereich, nach Adresse. Leer, solange nichts geladen ist oder
 * der Dienst nicht antwortet: dann stehen die Karten ohne Zahl da, mit ihrem festen Satz.
 */
function useKarten(bereich: string): Record<string, Uebersichtskarte> {
  const [karten, setKarten] = useState<Record<string, Uebersichtskarte>>({});
  useEffect(() => {
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
  }, [bereich]);
  return karten;
}

/**
 * Die Übersicht eines Bereichs: jede Karte eine Seite. Hat der Bereich Gruppen, steht je Gruppe
 * eine Spalte Karten unter ihrem Namen; hat er keine, stehen alle Karten in einem Raster.
 *
 * Sie ersetzt die lange Reiterzeile als Einstieg. Wer den Bereich öffnet, sieht zuerst, welche
 * Seiten es gibt und wovon jede handelt, und muss dafür keine Zeile durchrollen. Den Satz auf
 * der Karte trägt der Seitenbaum (`beschreibung`), damit er im Dashboard und in der App
 * derselbe ist.
 *
 * Was nur der Hausherr sieht, fehlt einem Gast hier wie in der Reiterzeile. Eine Gruppe, von
 * der danach nichts übrig ist, wird nicht gezeichnet.
 *
 * **Leitzahl und Ampel kommen vom Dienst** (`GET /uebersicht/{bereich}`): je Seite ihre
 * wichtigste Zahl und ein Zustand, fertig formuliert, damit das Dashboard und die App dasselbe
 * zeigen. Eine Ampel, die nicht gut ist, bringt ihren Grund als Satz mit; er steht auf der Karte.
 * Eine Seite ohne Karte des Dienstes (die Annahmen, die Jahreskarte) zeigt nur ihren festen Satz.
 */
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
                {seiten.map((seite) => {
                  const karte = karten[seite.href];
                  return (
                    <Link key={seite.href} href={seite.href} className="uebersicht-karte" data-ampel={karte?.ampel}>
                      <span className="uebersicht-kopfzeile">
                        <span className="uebersicht-titel">{seite.label}</span>
                        {karte ? <Zustandszeichen zustand={karte.ampel ?? "aus"} /> : null}
                      </span>
                      {karte?.leitzahl_de ? (
                        <span className="uebersicht-zahl">
                          <span className="mono uebersicht-leitzahl">{karte.leitzahl_de}</span>
                          <span className="uebersicht-dazu">{karte.dazu_de}</span>
                        </span>
                      ) : null}
                      {karte?.grund_de ? <span className="uebersicht-grund">{karte.grund_de}</span> : null}
                      <span className="uebersicht-satz">{seite.beschreibung}</span>
                      {seite.unter ? <span className="uebersicht-ansichten">{seite.unter.map((u) => u.label).join(" · ")}</span> : null}
                    </Link>
                  );
                })}
              </div>
            </section>
          );
        })}
      </div>
    </AreaShell>
  );
}
