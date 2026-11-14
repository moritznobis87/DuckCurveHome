"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { Waermepumpe as Daten } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { useIsMobile } from "@/lib/useIsMobile";
import { Stat } from "@/components/ui/Stat";
import { Bild } from "./Bild";
import { aufnahme, satz, zahl } from "./bild";

/**
 * Die Technikseite der Wärmepumpe (Nutzerwunsch 14.11.2026): Außen- und Inneneinheit, ihre Ein-
 * und Ausgänge bis zum Speicher, und jede Messung, die der Bus der Maschine hergibt, an ihrer
 * Stelle.
 *
 * **Nur der Augenblick.** Wie das Anlagenschema nebenan: was gerade ist. Geholt wird alle zehn
 * Sekunden, solange die Seite sichtbar ist; der Bus meldet seine Werte im Abstand von Sekunden
 * bis zu einer Minute.
 *
 * **Vier Zahlen oben, die Zeichnung darunter.** Die vier beantworten, was man von einer
 * Wärmepumpe wissen will: wie viel Wärme, aus wie viel Strom, mit welcher Arbeitszahl, bei
 * welcher Spreizung. Wärme und Arbeitszahl sind Abschätzungen, und so steht es an der Kachel.
 */
const LIVE_MS = 10_000;

export function Waermepumpe() {
  const [daten, setDaten] = useState<Daten | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [ruhig, setRuhig] = useState(false);
  const handy = useIsMobile();

  const laden = useCallback(async () => {
    try {
      setDaten(await api.waermepumpe());
      setFehler(null);
    } catch {
      setFehler("Die Wärmepumpe ist gerade nicht zu erreichen.");
    }
  }, []);

  useEffect(() => {
    setRuhig(window.matchMedia("(prefers-reduced-motion: reduce)").matches);
    void laden();
    const takt = setInterval(() => {
      if (document.visibilityState === "visible") void laden();
    }, LIVE_MS);
    const sichtbar = () => {
      if (document.visibilityState === "visible") void laden();
    };
    document.addEventListener("visibilitychange", sichtbar);
    return () => {
      clearInterval(takt);
      document.removeEventListener("visibilitychange", sichtbar);
    };
  }, [laden]);

  if (!daten) {
    return <p className="m-0 text-[15px] text-text-3">{fehler ?? "Die Wärmepumpe wird geladen …"}</p>;
  }
  const strom = aufnahme(daten);
  return (
    <section className="wp-seite">
      <div className="wp-kopf">
        <p className="wp-satz">{satz(daten)}</p>
        <span className="wp-stand">Stand {hhmm(daten.now)}{fehler ? ` · ${fehler}` : ""}</span>
      </div>

      {daten.bus_stumm_de ? (
        <p className="wp-stumm" role="status">
          <strong>Vom Bus der Wärmepumpe ist kein Wert da.</strong> {daten.bus_stumm_de}
        </p>
      ) : null}

      <div className="kpi-grid kpi-handy" style={{ "--cols": 4 } as React.CSSProperties}>
        <Stat label="Wärme, abgeschätzt" value={zahl(daten.waermeleistung_kw)} unit="kW" tone={daten.waermeleistung_kw != null ? "amber" : "muted"} hint={daten.laeuft ? "Durchfluss mal Spreizung" : "nur bei laufender Maschine"} />
        <Stat label={strom.quelle ? `Strom, ${strom.quelle}` : "Strom"} value={zahl(strom.kw, 2)} unit="kW" tone={strom.kw != null ? undefined : "muted"} />
        <Stat label="Arbeitszahl, abgeschätzt" value={zahl(daten.arbeitszahl)} tone={daten.arbeitszahl != null ? undefined : "muted"} hint="Wärme je Strom, im Augenblick" />
        <Stat label="Spreizung" value={zahl(daten.spreizung_k)} unit="K" tone={daten.spreizung_k != null ? undefined : "muted"} hint="Vorlauf minus Rücklauf" />
      </div>

      <div className="card wp-buehne">
        <Bild d={daten} lage={handy ? "hoch" : "breit"} ruhig={ruhig} />
      </div>

      <div className="wp-fuss">
        <p className="m-0">† Die Zuordnung dieses Werts ist begründet, am Gerät aber noch nicht bestätigt.</p>
        {daten.hinweise_de?.map((h) => <p key={h} className="m-0">{h}</p>)}
        <p className="m-0 wp-links">
          <Link href="/waerme/waermepumpe/kennlinie">Gemessene Kennlinie ›</Link>
          <Link href="/waerme/nachbetrachtung">Was die Wärme gekostet hat ›</Link>
          <Link href="/waerme/fahrplan">Fahrplan ›</Link>
          <Link href="/waerme/anlage">Die ganze Anlage ›</Link>
        </p>
      </div>
    </section>
  );
}
