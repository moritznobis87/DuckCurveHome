"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { Anlage as AnlageDaten } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { Schema } from "./Schema";
import { erzeugerSatz, mischung } from "./schema";

/**
 * Die Seite „Anlage": das Schema im Augenblick, dazu der Satz darüber und die Lesehilfe darunter.
 *
 * **Nur der Augenblick.** Keine Zeitraumwahl, keine Szenarien: Die Zeitreihen stehen auf den
 * Nachbarseiten, hier steht, was gerade fließt. Geholt wird alle 20 Sekunden, solange die Seite
 * sichtbar ist. Das ist langsamer als die Startseite, und mit Absicht: Die Pufferfühler melden
 * minütlich, und eine Zahl, die sich öfter ändert als ihre Quelle, lügt mit der Nachkommastelle.
 */
const LIVE_MS = 20_000;

function ruhigGewuenscht(): boolean {
  return typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export function Anlage() {
  const [daten, setDaten] = useState<AnlageDaten | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [nowMs, setNowMs] = useState(0);
  const [ruhig, setRuhig] = useState(false);

  const laden = useCallback(async () => {
    try {
      const a = await api.anlage();
      setDaten(a);
      setFehler(null);
    } catch (e) {
      setFehler(e instanceof Error ? e.message : "Die Anlage ist gerade nicht zu erreichen.");
    } finally {
      setNowMs(Date.now());
    }
  }, []);

  useEffect(() => {
    setRuhig(ruhigGewuenscht());
    void laden();
    const t = setInterval(() => {
      if (document.visibilityState === "visible") void laden();
    }, LIVE_MS);
    const sichtbar = () => {
      if (document.visibilityState === "visible") void laden();
    };
    document.addEventListener("visibilitychange", sichtbar);
    return () => {
      clearInterval(t);
      document.removeEventListener("visibilitychange", sichtbar);
    };
  }, [laden]);

  const mix = daten ? mischung(daten.strom) : null;

  return (
    <section className="anlage">
      <div className="anlage-kopf">
        <p className="anlage-satz">
          {daten ? (
            <>
              {daten.outdoor_c != null ? <>{Math.round(daten.outdoor_c)}{"\u00a0"}°C draußen · </> : null}
              <b>{erzeugerSatz(daten, nowMs)}</b>
              {mix?.text ? <> · Strom aus {mix.text}</> : null}
            </>
          ) : (
            "Anlage"
          )}
        </p>
        {daten ? <span className="anlage-stand">Stand {hhmm(daten.at)} · alle 20 s</span> : null}
      </div>

      {fehler ? <p className="anlage-fehler">{fehler}</p> : null}

      {daten ? (
        <div className="anlage-buehne">
          <div className="anlage-innen">
            <div className="anlage-scroll">
              <Schema a={daten} nowMs={nowMs} ruhig={ruhig} />
            </div>
          </div>
        </div>
      ) : (
        <div className="anlage-warten">{fehler ? "" : "Die Anlage wird geholt."}</div>
      )}

      <footer className="anlage-fuss">
        <div>
          <h2>Lesen</h2>
          <p>
            Licht wandert in Flussrichtung, sein Tempo ist die Leistung. Die Farbe eines Rohrs ist die
            Temperatur seines Wassers, auf derselben Skala wie das Glas. Ein ruhender Punkt auf dem Rohr
            ist eine Pumpe; sie leuchtet, wenn sie läuft.
          </p>
        </div>
        <div>
          <h2>Vier getrennte Systeme</h2>
          <p>
            Sie berühren sich nur im Speicher. Der <span className="m">Ofen</span> speist ganz oben ein und
            holt unten zurück. Die <span className="m">Wärmepumpe</span> speist in der Mitte ein und holt unten
            zurück. Der <span className="m">Heizkreis</span> nimmt aus der Mitte und gibt unten zurück. Das{" "}
            <span className="m">Trinkwasser</span> läuft unten kalt nach und wird ganz oben warm entnommen; es
            hat keine Pumpe, der Leitungsdruck treibt es. Ofen und Wärmepumpe holen ihren Rücklauf{" "}
            <span className="m">gemeinsam</span> an der untersten Spitze und teilen ihn erst danach.
          </p>
        </div>
        <div>
          <h2>Gemessen und gerechnet</h2>
          <p>
            Die Wärmepumpe zeigt ihren Strom; ihre Wärme misst heute niemand, Vorlauf und COP kommen mit dem
            Bus. Der Ofen wird aus seiner Stufe nach Datenblatt geschätzt. Die{" "}
            <span className="m">Nettoleistung des Speichers</span> ist aus den vier Fühlern gerechnet: die
            Änderung des Energieinhalts über die letzte Viertelstunde, lädt oder entlädt. Beim Warmwasser
            wird nicht gemessen, sondern <span className="m">erkannt</span>: Ein Anlegefühler am Auslass
            springt an, sobald warmes Wasser durch die Leitung läuft. Das sagt, dass gezapft wird und seit
            wann, nicht wie viel.
          </p>
        </div>
      </footer>
    </section>
  );
}
