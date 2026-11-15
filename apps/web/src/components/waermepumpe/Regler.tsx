"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { ReglerEinstellungen } from "@/lib/api/models";
import { gelesen, gruppen, standText, wertText } from "./regler";

/**
 * Was am Regler der Wärmepumpe eingestellt ist (15.11.2026): Heizkurve, Raumtemperaturen,
 * Warmwasser, über den Bus gelesen.
 *
 * Die Seite verstellt nichts. Sie ist dafür da, dass jemand ihre Zahlen mit dem Bediengerät
 * vergleicht: erst wenn eine Kennung nachweislich die Einstellung ist, für die die Liste sie
 * hält, kommt in Frage, sie von hier aus zu ändern.
 */
export function Regler() {
  const [daten, setDaten] = useState<ReglerEinstellungen | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);

  const laden = useCallback(async () => {
    try {
      setDaten(await api.reglerEinstellungen());
      setFehler(null);
    } catch {
      setFehler("Die Einstellungen sind gerade nicht zu erreichen.");
    }
  }, []);

  useEffect(() => {
    void laden();
    const takt = setInterval(() => void laden(), 60_000);
    return () => clearInterval(takt);
  }, [laden]);

  if (!daten) {
    return <p className="m-0 text-[15px] text-text-3">{fehler ?? "Die Einstellungen werden gelesen …"}</p>;
  }

  return (
    <section className="wp-seite">
      <div className="wp-kopf">
        <p className="wp-satz">{daten.satz_de}</p>
        <span className="wp-stand">
          Gelesen, nicht gestellt{fehler ? ` · ${fehler}` : ""}
        </span>
      </div>

      <div className="rg-gruppen">
        {gruppen(daten.werte).map((g) => (
          <div key={g.name} className="card kl-karte">
            <h2 className="kl-titel">{g.name}</h2>
            <table className="kl-tabelle rg-tabelle">
              <thead>
                <tr>
                  <th scope="col">Einstellung</th>
                  <th scope="col">Wert</th>
                  <th scope="col">gelesen</th>
                  <th scope="col">Kennung</th>
                </tr>
              </thead>
              <tbody>
                {g.werte.map((w) => (
                  <tr key={w.schluessel} data-gemessen={gelesen(w)}>
                    <td>
                      {w.name_de}
                      {w.lesart_de ? <span className="rg-lesart">laut Busbeschreibung: {w.lesart_de}</span> : null}
                    </td>
                    <td className="mono rg-wert">{wertText(w)}</td>
                    <td className="mono">{standText(w)}</td>
                    <td className="mono">{w.kennung}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))}
      </div>

      <div className="wp-fuss">
        {daten.hinweise_de.map((h) => (
          <p key={h} className="m-0">
            {h}
          </p>
        ))}
        <p className="m-0 wp-links">
          <Link href="/waerme/waermepumpe/betrieb">Die Heizkurve, wie sie gefahren wird ›</Link>
          <Link href="/waerme/waermepumpe">Die Wärmepumpe jetzt ›</Link>
        </p>
      </div>
    </section>
  );
}
