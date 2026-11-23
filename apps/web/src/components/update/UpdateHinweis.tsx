"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useRole } from "@/lib/live/useRole";
import { laeuft, schonGescheitert, useUpdate } from "./useUpdate";

/**
 * Sagt dem Hausherrn, dass für das Hausgerät ein Update bereitsteht, und führt zur Seite, auf der es
 * installiert wird. Nur mit Vollzugriff und nur auf einem Hausgerät (`unterstuetzt`); auf Railway
 * steht hier nie etwas.
 *
 * „Nicht jetzt“ gilt für genau diese Fassung: Kommt eine neuere, erscheint der Hinweis wieder.
 * Gemerkt wird das im Gerät, wie beim Hinweis zu den Mitteilungen.
 */
const MERKER = "dch-update-weg";

export function UpdateHinweis() {
  const rolle = useRole();
  const { status, neustart } = useUpdate(rolle === "owner");
  const [weg, setWeg] = useState<string | null>(null);

  useEffect(() => {
    try {
      setWeg(window.localStorage.getItem(MERKER));
    } catch {
      // Ohne Speicher erscheint der Hinweis eben jedes Mal.
    }
  }, []);

  if (rolle !== "owner" || !status?.unterstuetzt) return null;
  const imGang = laeuft(status) || neustart;
  if (!imGang && (!status.update_verfuegbar || weg === status.verfuegbar || schonGescheitert(status))) return null;

  const schliessen = () => {
    setWeg(status.verfuegbar);
    try {
      if (status.verfuegbar) window.localStorage.setItem(MERKER, status.verfuegbar);
    } catch {
      // siehe oben
    }
  };

  return (
    <div className="mitteil-hinweis update-hinweis" role="note">
      <span className="mitteil-hinweis-text">
        {imGang
          ? "Duck Curve wird gerade aktualisiert. Die Anwendung startet dabei einmal neu."
          : `Für Duck Curve steht ein Update bereit${status.neuerungen.length ? ` mit ${status.neuerungen.length} ${status.neuerungen.length === 1 ? "Neuerung" : "Neuerungen"}` : ""}.`}
      </span>
      <span className="mitteil-hinweis-knoepfe">
        <Link href="/system/geraet#software" className="mitteil-hinweis-los">
          {imGang ? "Ansehen" : "Ansehen und installieren"}
        </Link>
        {imGang ? null : (
          <button type="button" className="mitteil-hinweis-zu" onClick={schliessen}>
            Nicht jetzt
          </button>
        )}
      </span>
    </div>
  );
}
