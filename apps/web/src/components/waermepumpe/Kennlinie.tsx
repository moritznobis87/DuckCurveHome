"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { Kennlinie as Daten } from "@/lib/api/models";
import { farbe } from "@/components/anlage/schema";
import { EChart } from "@/components/charts/EChart";
import { Stat } from "@/components/ui/Stat";
import { copNach, gesamt, mitte, optionAussen, optionFeld, optionVorlauf, vergleich, vergleichsVorlauf, zahl } from "./kennlinie";

/**
 * Die gemessene Kennlinie der Wärmepumpe (Nutzerwunsch 14.11.2026): Arbeitszahl in Abhängigkeit
 * von Außen- und Vorlauftemperatur, als Messpunkte, mit einer Ausgleichsfläche nach der Methode
 * der kleinsten Quadrate.
 *
 * Oben steht, was die Messung bisher sagt, in einem Satz. Darunter die Zahlen des Ausgleichs,
 * dann drei Ansichten derselben Punkte (warum drei, steht in `kennlinie.ts`), dann der Vergleich
 * mit der Kennlinie, mit der der Fahrplan heute rechnet. Übernommen wird nichts von selbst.
 */
const TAGE = [7, 30, 90, 180] as const;

export function Kennlinie() {
  const [tage, setTage] = useState<number>(30);
  const [daten, setDaten] = useState<Daten | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);

  const laden = useCallback(async (t: number) => {
    try {
      setDaten(await api.kennlinie(t));
      setFehler(null);
    } catch {
      setFehler("Die Kennlinie ist gerade nicht zu erreichen.");
    }
  }, []);

  useEffect(() => {
    void laden(tage);
  }, [laden, tage]);

  const aussen = useMemo(() => (daten ? optionAussen(daten) : null), [daten]);
  const vorlauf = useMemo(() => (daten ? optionVorlauf(daten) : null), [daten]);
  const feld = useMemo(() => (daten ? optionFeld(daten) : null), [daten]);

  if (!daten) {
    return <p className="m-0 text-[15px] text-text-3">{fehler ?? "Die Kennlinie wird geladen …"}</p>;
  }
  const f = daten.fit;
  const n = daten.punkte.length;
  const mittel = gesamt(daten.punkte);
  const ta = mitte(daten.punkte.map((p) => p.aussen_c));
  const tv = mitte(daten.punkte.map((p) => p.vorlauf_c));
  const zeilen = vergleich(daten);
  const beiVorlauf = vergleichsVorlauf(daten);
  const tvVon = n ? Math.min(...daten.punkte.map((p) => p.vorlauf_c)) : null;
  const tvBis = n ? Math.max(...daten.punkte.map((p) => p.vorlauf_c)) : null;

  let satz = "Noch gibt es keine Messpunkte.";
  if (f && ta != null && tv != null) {
    satz = `Nach ${f.n} Messpunkten macht die Wärmepumpe bei ${zahl(ta, 0)} °C draußen und ${zahl(tv, 0)} °C Vorlauf aus einer Kilowattstunde Strom ${zahl(copNach(f, ta, tv))} Kilowattstunden Wärme.`;
  } else if (n && mittel != null) {
    satz = `${n} ${n === 1 ? "Messpunkt" : "Messpunkte"} bisher, Arbeitszahl im Mittel ${zahl(mittel)}.`;
  }

  return (
    <section className="wp-seite">
      <div className="wp-kopf">
        <p className="wp-satz">{satz}</p>
        <span className="wp-stand">
          Letzte {daten.tage} Tage{fehler ? ` · ${fehler}` : ""}
        </span>
      </div>

      <div className="kl-wahl" role="group" aria-label="Rückblick">
        {TAGE.map((t) => (
          <button key={t} type="button" className="kl-knopf" aria-pressed={t === tage} onClick={() => setTage(t)}>
            {t} Tage
          </button>
        ))}
      </div>

      {daten.fehlt_de ? (
        <p className="wp-stumm" role="status">
          {daten.fehlt_de}
        </p>
      ) : null}

      <div className="kpi-grid kpi-handy" style={{ "--cols": 4 } as React.CSSProperties}>
        <Stat label="Messpunkte" value={String(n)} tone={n ? "amber" : "muted"} hint="je zehn Minuten Heizbetrieb" />
        <Stat label="Arbeitszahl im Mittel" value={mittel != null ? zahl(mittel) : "?"} tone={mittel != null ? undefined : "muted"} hint="Wärme durch Strom, alle Punkte" />
        <Stat
          label="Je Grad wärmer draußen"
          value={f && (f.art === "ebene" || f.art === "aussen") ? `${f.b_aussen >= 0 ? "+" : "−"}${zahl(Math.abs(f.b_aussen), 2)}` : "?"}
          tone={f && (f.art === "ebene" || f.art === "aussen") ? undefined : "muted"}
          hint="Arbeitszahl, nach Ausgleich"
        />
        <Stat
          label="Je Grad mehr Vorlauf"
          value={f && (f.art === "ebene" || f.art === "vorlauf") ? `${f.c_vorlauf >= 0 ? "+" : "−"}${zahl(Math.abs(f.c_vorlauf), 2)}` : "?"}
          tone={f && (f.art === "ebene" || f.art === "vorlauf") ? undefined : "muted"}
          hint="Arbeitszahl, nach Ausgleich"
        />
      </div>

      {f ? (
        <div className="card kl-formel">
          <span className="kicker">Ausgleich nach kleinsten Quadraten</span>
          <p className="kl-formel-zeile mono">{f.formel_de}</p>
          <p className="m-0 kl-klein">
            {f.n} Punkte · mittlere Abweichung ±{zahl(f.rmse, 2)}
            {f.r2 != null ? ` · erklärt ${Math.round(f.r2 * 100)} % der Streuung` : ""}. {f.geltung_de}
          </p>
        </div>
      ) : null}

      <div className="kl-paar">
        <div className="card kl-karte">
          <h2 className="kl-titel">Arbeitszahl über der Außentemperatur</h2>
          {aussen ? <div className="kl-chart"><EChart option={aussen} /></div> : null}
          {tvVon != null && tvBis != null ? (
            <div className="kl-skala" aria-label={`Farbe der Punkte: Vorlauf von ${zahl(tvVon, 0)} bis ${zahl(tvBis, 0)} Grad`}>
              <span>Vorlauf {zahl(tvVon, 0)} °C</span>
              <span className="kl-skala-band" style={{ background: `linear-gradient(90deg, ${[0, 0.25, 0.5, 0.75, 1].map((x) => farbe(tvVon + (tvBis - tvVon) * x)).join(", ")})` }} />
              <span>{zahl(tvBis, 0)} °C</span>
            </div>
          ) : null}
        </div>
        <div className="card kl-karte">
          <h2 className="kl-titel">Arbeitszahl über der Vorlauftemperatur</h2>
          {vorlauf ? <div className="kl-chart"><EChart option={vorlauf} /></div> : null}
        </div>
      </div>

      <div className="card kl-karte">
        <h2 className="kl-titel">Kennfeld: beide Temperaturen zugleich</h2>
        {feld ? (
          <>
            <div className="kl-chart kl-chart-feld"><EChart option={feld} /></div>
            <p className="m-0 kl-klein">Die Farbe ist die Arbeitszahl nach dem Ausgleich. Ein Kreis steht, wo gemessen wurde; je größer, desto mehr Punkte.</p>
          </>
        ) : (
          <p className="m-0 kl-klein">Das Kennfeld entsteht, sobald sich der Einfluss beider Temperaturen bestimmen lässt: wenn die Messpunkte draußen mindestens vier und im Vorlauf mindestens fünf Grad auseinanderliegen, und nicht im Gleichschritt.</p>
        )}
      </div>

      {zeilen.length && beiVorlauf != null ? (
        <div className="card kl-karte">
          <h2 className="kl-titel">Messung gegen die Annahme des Fahrplans</h2>
          <table className="kl-tabelle">
            <thead>
              <tr>
                <th scope="col">draußen</th>
                <th scope="col">Annahme{daten.annahme_vorlauf_c != null ? ` (${zahl(daten.annahme_vorlauf_c, 0)} °C Vorlauf)` : ""}</th>
                <th scope="col">Messung ({zahl(beiVorlauf, 0)} °C Vorlauf)</th>
                <th scope="col">Stand</th>
              </tr>
            </thead>
            <tbody>
              {zeilen.map((z) => (
                <tr key={z.aussen_c} data-gemessen={z.gemessen}>
                  <td className="mono">{zahl(z.aussen_c, 0)} °C</td>
                  <td className="mono">{zahl(z.annahme)}</td>
                  <td className="mono">{zahl(z.messung)}</td>
                  <td>{z.gemessen ? "gemessen" : "verlängert"}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="m-0 kl-klein">„Verlängert“ heißt: bei dieser Temperatur wurde noch nicht gemessen, die Zahl folgt aus der Formel. Der Fahrplan rechnet weiter mit seiner Annahme; übernommen wird nichts von selbst.</p>
        </div>
      ) : null}

      {n ? (
        <details className="kl-liste">
          <summary>Die Messpunkte als Tabelle ({n})</summary>
          <table className="kl-tabelle">
            <thead>
              <tr>
                <th scope="col">Zeit</th>
                <th scope="col">draußen</th>
                <th scope="col">Vorlauf</th>
                <th scope="col">Wärme</th>
                <th scope="col">Strom</th>
                <th scope="col">Arbeitszahl</th>
              </tr>
            </thead>
            <tbody>
              {[...daten.punkte]
                .reverse()
                .slice(0, 200)
                .map((p) => (
                  <tr key={p.at}>
                    <td className="mono">{new Date(p.at).toLocaleString("de-DE", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", timeZone: "Europe/Berlin" })}</td>
                    <td className="mono">{zahl(p.aussen_c)} °C</td>
                    <td className="mono">{zahl(p.vorlauf_c)} °C</td>
                    <td className="mono">{zahl(p.waerme_kw)} kW</td>
                    <td className="mono">{zahl(p.strom_kw, 2)} kW</td>
                    <td className="mono">{zahl(p.cop, 2)}</td>
                  </tr>
                ))}
            </tbody>
          </table>
        </details>
      ) : null}

      <div className="wp-fuss">
        {daten.hinweise_de?.map((h) => (
          <p key={h} className="m-0">
            {h}
          </p>
        ))}
        <p className="m-0 wp-links">
          <Link href="/waerme/waermepumpe">Die Wärmepumpe jetzt ›</Link>
          <Link href="/waerme/nachbetrachtung">Was die Wärme gekostet hat ›</Link>
        </p>
      </div>
    </section>
  );
}
