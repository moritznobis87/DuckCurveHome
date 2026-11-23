"use client";

import Link from "next/link";
import { AREAS, tabsDerGruppe, type Area } from "@/lib/areas";
import { useRole } from "@/lib/live/useRole";
import { AreaShell } from "./AreaShell";

/**
 * Die Übersicht eines Bereichs mit Gruppen: je Gruppe eine Reihe Karten, jede Karte eine Seite.
 *
 * Sie ersetzt die lange Reiterzeile als Einstieg. Wer den Bereich öffnet, sieht zuerst, welche
 * Seiten es gibt und wovon jede handelt, und muss dafür keine Zeile durchrollen. Den Satz auf
 * der Karte trägt der Seitenbaum (`beschreibung`), damit er im Dashboard und in der App
 * derselbe ist.
 *
 * Was nur der Hausherr sieht, fehlt einem Gast hier wie in der Reiterzeile. Eine Gruppe, von
 * der danach nichts übrig ist, wird nicht gezeichnet.
 */
export function Bereichsuebersicht({ bereich }: { bereich: Area["key"] }) {
  const role = useRole();
  const area = AREAS.find((a) => a.key === bereich);
  if (!area?.gruppen) return null;
  return (
    <AreaShell kicker={`Alle Seiten im Bereich ${area.label}`}>
      <div className="uebersicht">
        {area.gruppen.map((gruppe) => {
          const seiten = tabsDerGruppe(area, gruppe.name).filter((t) => !t.ownerOnly || role === "owner");
          if (seiten.length === 0) return null;
          return (
            <section key={gruppe.name} className="uebersicht-gruppe" aria-label={gruppe.name}>
              <header className="uebersicht-kopf">
                <h2 className="uebersicht-name">{gruppe.name}</h2>
                <span className="uebersicht-wort">{gruppe.wort}</span>
              </header>
              <div className="uebersicht-karten">
                {seiten.map((seite) => (
                  <Link key={seite.href} href={seite.href} className="uebersicht-karte">
                    <span className="uebersicht-titel">{seite.label}</span>
                    <span className="uebersicht-satz">{seite.beschreibung}</span>
                    {seite.unter ? <span className="uebersicht-ansichten">{seite.unter.map((u) => u.label).join(" · ")}</span> : null}
                  </Link>
                ))}
              </div>
            </section>
          );
        })}
      </div>
    </AreaShell>
  );
}
