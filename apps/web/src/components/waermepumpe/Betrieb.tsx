"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { Betrieb as Daten } from "@/lib/api/models";
import { EChart } from "@/components/charts/EChart";
import { Stat } from "@/components/ui/Stat";
import { dauer } from "./bilanz";
import { abtauAnteil, kurzAnteil, optionArbeitszahl, optionHeizkurve, optionLauflaengen, optionStunden, startsJeTag, tagName, zahl } from "./betrieb";

/**
 * Der Betrieb der Wärmepumpe über Tage (14.11.2026): wie oft und wie lange sie läuft, wie oft
 * sie abtaut, was das an Arbeitszahl kostet, und welche Heizkurve ihr Regler fährt.
 *
 * Oben steht in Sätzen, was die Auszählung zeigt. Darunter vier Diagramme, jedes zu einer
 * Frage (warum vier, steht in `betrieb.ts`), dann die Tage als Tabelle. Gesteuert wird von
 * hier nichts.
 */
const TAGE = [7, 14, 30, 90] as const;

export function Betrieb() {
  const [tage, setTage] = useState<number>(14);
  const [daten, setDaten] = useState<Daten | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);

  const laden = useCallback(async (t: number) => {
    try {
      setDaten(await api.betrieb(t));
      setFehler(null);
    } catch {
      setFehler("Die Auszählung ist gerade nicht zu erreichen.");
    }
  }, []);

  useEffect(() => {
    void laden(tage);
  }, [laden, tage]);

  const stunden = useMemo(() => (daten ? optionStunden(daten) : null), [daten]);
  const arbeitszahl = useMemo(() => (daten ? optionArbeitszahl(daten) : null), [daten]);
  const laengen = useMemo(() => (daten ? optionLauflaengen(daten) : null), [daten]);
  const heizkurve = useMemo(() => (daten ? optionHeizkurve(daten) : null), [daten]);

  if (!daten) {
    return <p className="m-0 text-[15px] text-text-3">{fehler ?? "Der Betrieb wird ausgezählt …"}</p>;
  }
  const lief = daten.lauf_min > 0;
  const starts = startsJeTag(daten);
  const abtau = abtauAnteil(daten);
  const kurz = kurzAnteil(daten);
  const [kopf, ...weitere] = daten.saetze_de;
  const laeufe = daten.klassen.reduce((s, k) => s + k.laeufe, 0);
  const g = daten.heizkurve;

  return (
    <section className="wp-seite">
      <div className="wp-kopf">
        <p className="wp-satz">{kopf ?? "Noch nichts auszuzählen."}</p>
        <span className="wp-stand">
          Letzte {daten.zeitraum_tage} Tage{fehler ? ` · ${fehler}` : ""}
        </span>
      </div>

      <div className="kl-wahl" role="group" aria-label="Rückblick">
        {TAGE.map((t) => (
          <button key={t} type="button" className="kl-knopf" aria-pressed={t === tage} onClick={() => setTage(t)}>
            {t} Tage
          </button>
        ))}
      </div>

      <div className="kpi-grid kpi-handy" style={{ "--cols": 4 } as React.CSSProperties}>
        <Stat label="Starts je Tag" value={starts != null ? zahl(starts) : "?"} tone={starts != null ? "amber" : "muted"} hint="an Tagen mit Betrieb" />
        <Stat label="Ein Lauf dauert" value={daten.lauf_median_min != null ? dauer(daten.lauf_median_min) : "?"} tone={daten.lauf_median_min != null ? undefined : "muted"} hint={kurz != null ? `${Math.round(kurz * 100)} % unter zehn Minuten` : "im Mittel"} />
        <Stat label="Abtauen" value={abtau != null ? zahl(abtau * 100) : "?"} unit="%" tone={abtau != null ? undefined : "muted"} hint={lief ? `der Laufzeit · ${daten.abtauungen}-mal` : "der Laufzeit"} />
        <Stat label="Arbeitszahl über alles" value={daten.cop_gesamt != null ? zahl(daten.cop_gesamt, 2) : "?"} tone={daten.cop_gesamt != null ? undefined : "muted"} hint={daten.cop_heizen != null ? `im Heizbetrieb ${zahl(daten.cop_heizen, 2)}` : "Wärme durch Strom"} />
      </div>

      {weitere.length ? (
        <div className="card kl-karte">
          <h2 className="kl-titel">Was die Auszählung zeigt</h2>
          <ul className="bt-saetze">
            {weitere.map((s) => (
              <li key={s}>{s}</li>
            ))}
          </ul>
        </div>
      ) : null}

      {lief ? (
        <>
          <div className="kl-paar">
            <div className="card kl-karte">
              <h2 className="kl-titel">Laufstunden je Tag</h2>
              {stunden ? <div className="kl-chart"><EChart option={stunden} /></div> : null}
            </div>
            <div className="card kl-karte">
              <h2 className="kl-titel">Arbeitszahl je Tag</h2>
              {arbeitszahl ? <div className="kl-chart"><EChart option={arbeitszahl} /></div> : null}
              <p className="m-0 kl-klein">„Über alles“ enthält jeden Anlauf, das Abtauen und den Heizstab; „im Heizbetrieb“ zählt nur eingeschwungene Fenster. Liegt die erste Linie darunter, ist der Abstand, was Takten und Abtauen an dem Tag gekostet haben.</p>
            </div>
          </div>

          <div className="kl-paar">
            <div className="card kl-karte">
              <h2 className="kl-titel">Wie lange ein Lauf dauert</h2>
              {laeufe ? (
                <>
                  {laengen ? <div className="kl-chart"><EChart option={laengen} /></div> : null}
                  <p className="m-0 kl-klein">{laeufe === 1 ? "1 vollständiger Lauf" : `${laeufe} vollständige Läufe`}. Die ersten zehn Minuten eines Laufs sind Anlauf; ein Lauf, der kürzer ist, kommt nie in den Bereich, in dem die Maschine gut arbeitet.</p>
                </>
              ) : (
                <p className="m-0 kl-klein">Noch kein vollständiger Lauf: ein Lauf zählt, wenn sein Anfang und sein Ende in den Daten liegen.</p>
              )}
            </div>
            <div className="card kl-karte">
              <h2 className="kl-titel">Die Heizkurve des Reglers</h2>
              {daten.stunden.length ? (
                <>
                  {heizkurve ? <div className="kl-chart"><EChart option={heizkurve} /></div> : null}
                  <p className="m-0 kl-klein">
                    {g ? <span className="mono">{g.formel_de}</span> : "Für eine Gerade braucht es mindestens sechs Stunden Heizbetrieb bei Außentemperaturen, die drei Grad auseinanderliegen."}
                    {g ? ` · aus ${g.n} Stunden${g.r2 != null ? `, erklärt ${Math.round(g.r2 * 100)} % der Streuung` : ""}. Jeder Punkt ist eine Stunde im Heizbetrieb. Liegen Punkte weit über der Geraden, hat der Regler dort für Warmwasser mehr verlangt.` : ""}
                  </p>
                </>
              ) : (
                <p className="m-0 kl-klein">Noch keine Stunde im Heizbetrieb mit Sollwert und Außentemperatur.</p>
              )}
            </div>
          </div>
        </>
      ) : null}

      {daten.tage.length ? (
        <details className="kl-liste">
          <summary>Die Tage als Tabelle ({daten.tage.length})</summary>
          <div className="kl-rollt">
            <table className="kl-tabelle">
              <thead>
                <tr>
                  <th scope="col">Tag</th>
                  <th scope="col">draußen</th>
                  <th scope="col">Starts</th>
                  <th scope="col">Lauf</th>
                  <th scope="col">Lauf im Mittel</th>
                  <th scope="col">Abtauen</th>
                  <th scope="col">Heizstab</th>
                  <th scope="col">Strom</th>
                  <th scope="col">Wärme</th>
                  <th scope="col">Arbeitszahl</th>
                  <th scope="col">im Heizbetrieb</th>
                </tr>
              </thead>
              <tbody>
                {[...daten.tage].reverse().map((t) => (
                  <tr key={t.tag}>
                    <td className="mono">{tagName(t.tag)}</td>
                    <td className="mono">{t.aussen_c != null ? `${zahl(t.aussen_c)} °C` : "?"}</td>
                    <td className="mono">{t.starts}</td>
                    <td className="mono">{dauer(t.lauf_min)}</td>
                    <td className="mono">{t.lauf_median_min != null ? dauer(t.lauf_median_min) : "?"}</td>
                    <td className="mono">{t.abtau_min ? `${dauer(t.abtau_min)} · ${t.abtauungen}-mal` : "0"}</td>
                    <td className="mono">{t.zusatz_min ? dauer(t.zusatz_min) : "0"}</td>
                    <td className="mono">{zahl(t.strom_kwh)} kWh</td>
                    <td className="mono">{t.waerme_kwh != null ? `${zahl(t.waerme_kwh)} kWh` : "?"}</td>
                    <td className="mono">{t.cop_tag != null ? zahl(t.cop_tag, 2) : "?"}</td>
                    <td className="mono">{t.cop_heizen != null ? zahl(t.cop_heizen, 2) : "?"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </details>
      ) : null}

      <div className="wp-fuss">
        {daten.hinweise_de.map((h) => (
          <p key={h} className="m-0">
            {h}
          </p>
        ))}
        <p className="m-0 wp-links">
          <Link href="/waerme/waermepumpe">Die Wärmepumpe jetzt ›</Link>
          <Link href="/waerme/waermepumpe/kennlinie">Gemessene Kennlinie ›</Link>
        </p>
      </div>
    </section>
  );
}
