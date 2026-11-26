"use client";

import { useState } from "react";
import { gruppentitel, laeuft, nachVersion, schonGescheitert, useUpdate, type UpdateStatus } from "./useUpdate";

/**
 * Der Bereich „Software“ auf der Seite Hausgerät: welche Fassung läuft, was neu ist, und
 * der Knopf zum Installieren. Installiert wird auf dem Gerät selbst (deploy/haus/dch): Sicherung,
 * Laden, Neustart, Prüfung - und kommt die neue Fassung nicht gesund hoch, zurück zur alten.
 */
const SCHRITTE: { schluessel: string; text: string }[] = [
  { schluessel: "Sicherung", text: "Datenbank sichern" },
  { schluessel: "Quelltext", text: "Einrichtung nachziehen" },
  { schluessel: "Laden", text: "Neue Fassung laden" },
  { schluessel: "Neustart", text: "Neu starten" },
  { schluessel: "Pruefung", text: "Prüfen, ob alles läuft" },
];

function zeit(iso: string | null | undefined): string {
  if (!iso) return "noch nie";
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleString("de-DE", { dateStyle: "medium", timeStyle: "short" });
}

export function ergebnisText(s: UpdateStatus): string | null {
  if (s.zustand === "fertig" && s.zuletzt) return `Zuletzt aktualisiert am ${zeit(s.zuletzt.am)}.`;
  if (s.zustand === "zurueckgerollt") return s.meldung ?? "Die neue Fassung kam nicht gesund hoch; die vorherige läuft wieder.";
  if (s.zustand === "fehlgeschlagen") return s.meldung ?? "Das Update ist fehlgeschlagen.";
  return s.meldung;
}

export function Software() {
  const { status, neustart, fehler, anfragen } = useUpdate(true);
  const [bestaetigen, setBestaetigen] = useState(false);

  if (status === null) return <p className="m-0 text-[15px] text-text-3">Lade …</p>;
  if (!status.unterstuetzt) {
    return (
      <p className="m-0 text-[15px] leading-[1.6] text-text-3">
        Updates aus der App gibt es auf dem Hausgerät. Diese Installation (etwa auf Railway) wird über ihre
        Plattform aktualisiert.
      </p>
    );
  }

  const imGang = laeuft(status) || neustart;
  const aktuellerSchritt = neustart ? "Neustart" : status.schritt;
  const ergebnis = ergebnisText(status);
  const gescheitert = schonGescheitert(status);

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-baseline gap-x-6 gap-y-1 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3 text-[14px]">
        <span>
          <span className="text-text-3">Läuft: </span>
          <span className="text-text-1">{status.aktuell || "unbekannt"}</span>
        </span>
        <span>
          <span className="text-text-3">Kanal: </span>
          <span className="mono text-text-1">{status.kanal ?? "?"}</span>
        </span>
        <span className="text-text-3">Zuletzt nachgesehen: {zeit(status.geprueft_am)}</span>
      </div>

      {imGang ? (
        <div className="flex flex-col gap-2 rounded-[3px] border border-amber px-4 py-3" aria-live="polite">
          <span className="text-[15px] font-semibold">Update läuft</span>
          <ol className="m-0 flex list-none flex-col gap-1 p-0 text-[14px]">
            {SCHRITTE.map((s) => {
              const index = SCHRITTE.findIndex((x) => x.schluessel === aktuellerSchritt);
              const eigener = SCHRITTE.indexOf(s);
              const zeichen = index < 0 ? "·" : eigener < index ? "✓" : eigener === index ? "…" : "·";
              return (
                <li key={s.schluessel} className={eigener === index ? "text-text-1" : "text-text-3"}>
                  {zeichen} {s.text}
                </li>
              );
            })}
            {aktuellerSchritt === "Zurueck" ? <li className="text-text-1">… Zur vorherigen Fassung zurück</li> : null}
          </ol>
          <span className="text-[13px] text-text-3">
            {neustart
              ? "Die Anwendung startet gerade neu und ist kurz nicht erreichbar. Diese Seite lädt von selbst neu."
              : "Das dauert meist ein bis drei Minuten."}
          </span>
        </div>
      ) : status.update_verfuegbar ? (
        <div className="flex flex-col gap-3 rounded-[3px] border border-line-2 px-4 py-3">
          <span className="text-[15px] font-semibold">
            Update bereit: {status.verfuegbar ?? "neue Fassung"}
          </span>
          {status.neuerungen.length ? (
            <div className="flex flex-col gap-2">
              {nachVersion(status.neuerungen).map((gruppe, _, alle) => (
                <div key={gruppe.version ?? "neu"} className="flex flex-col gap-1">
                  {alle.length > 1 ? <span className="text-[13px] text-text-3">{gruppentitel(gruppe.version)}</span> : null}
                  <ul className="m-0 flex list-disc flex-col gap-1 pl-5 text-[14px] text-text-2">
                    {gruppe.eintraege.map((n, i) => (
                      <li key={i}>
                        <span className="text-text-1">{n.bereich}:</span> {n.text}
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          ) : (
            <span className="text-[14px] text-text-3">Was sich geändert hat, ist nicht bekannt.</span>
          )}
          {gescheitert ? (
            <span className="text-[14px] leading-[1.5] text-text-2">
              Diese Fassung kam beim letzten Versuch nicht gesund hoch; das Gerät ist zur vorherigen zurückgekehrt.
              Meist kommt bald eine korrigierte. Ein zweiter Versuch schadet nicht.
            </span>
          ) : null}
          {bestaetigen ? (
            <div className="flex flex-col gap-2" role="alertdialog" aria-label="Update installieren?">
              <span className="text-[14px] leading-[1.5] text-text-2">
                Vorher wird die Datenbank gesichert. Während des Neustarts regelt Duck Curve etwa ein bis drei Minuten
                nicht; die Anlage läuft in dieser Zeit wie ohne Duck Curve. Kommt die neue Fassung nicht gesund hoch,
                kehrt das Gerät von selbst zur jetzigen zurück.
              </span>
              <span className="flex gap-2">
                <button type="button" autoFocus className="rounded-[8px] border border-line-2 px-3 py-2 text-[14px]" onClick={() => setBestaetigen(false)}>
                  Abbrechen
                </button>
                <button
                  type="button"
                  className="rounded-[8px] bg-amber px-3 py-2 text-[14px] font-semibold text-deep"
                  onClick={() => {
                    setBestaetigen(false);
                    void anfragen("installieren");
                  }}
                >
                  Jetzt installieren
                </button>
              </span>
            </div>
          ) : (
            <span>
              <button type="button" className="rounded-[8px] bg-amber px-3 py-2 text-[14px] font-semibold text-deep" onClick={() => setBestaetigen(true)}>
                {gescheitert ? "Erneut versuchen" : "Update installieren"}
              </button>
            </span>
          )}
        </div>
      ) : (
        <span className="text-[15px] text-text-2">Duck Curve ist auf dem neuesten Stand.</span>
      )}

      {ergebnis && !imGang ? <p className="m-0 text-[14px] leading-[1.5] text-text-2">{ergebnis}</p> : null}
      {fehler ? <p className="m-0 text-[14px] text-alert-text">{fehler}</p> : null}

      {imGang ? null : (
        <span>
          <button type="button" className="text-[14px] text-amber" onClick={() => void anfragen("pruefen")}>
            Jetzt nach Updates sehen
          </button>
        </span>
      )}
    </div>
  );
}
