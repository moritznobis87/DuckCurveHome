"use client";

import Link from "next/link";
import { useMemo } from "react";
import { C } from "@/components/charts/palette";
import type { Kontaktwirkung } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { achsenText, betrieb, ergebnisText, geordnet, kurzDatum, wiedergabeZiel, type Ereignis } from "./wirkung";

/**
 * Das Ereignisraster: jeder Schließvorgang eine Zeile, alle am selben Nullpunkt.
 *
 * Der Fächer darüber zeigt die Mitte und die Streuung, dieses Raster die einzelnen Fälle. Jede
 * Zeile ist derselbe Ausschnitt wie im Fächer, von einer halben Stunde vor dem Schließen bis zwei
 * Stunden danach: gefüllt, wo die Wärmepumpe lief; ein schwacher Grund, wo sie gemessen stand;
 * nichts, wo die Messung fehlt. Der schmale Strich darunter zeigt, wie lange der Kontakt
 * geschlossen blieb.
 *
 * **Sortiert nach Verzögerung, nicht nach Datum.** So bekommt das Raster eine Form: reagiert die
 * Maschine, steht eine Treppe dicht hinter dem Nullpunkt. Das Datum steht links an jeder Zeile.
 *
 * **Jede Zeile ist ein Sprung in die Wiedergabe** dieses Tages zu dieser Stunde. Das Raster sagt,
 * dass die Maschine am Dienstag nicht folgte; warum, zeigt das Anlagenschema von Dienstag.
 */

/** Mehr Zeilen zeigt das Raster nicht; darüber wird es eine Liste, die niemand mehr liest. */
const MAX_ZEILEN = 80;
/** Die Höhe einer Zeile in den Einheiten ihres Bildes. Die Breite ist die Zahl der Minuten. */
const H = 10;

function Zeile({ e, daten }: { e: Ereignis; daten: Kontaktwirkung }) {
  const breite = daten.vor_min + daten.nach_min + 1;
  const b = useMemo(() => betrieb(e.kw, daten.schwelle_kw), [e.kw, daten.schwelle_kw]);
  const ergebnis = ergebnisText(e, daten.folge_min);
  const wann = `${kurzDatum(e.at)} ${hhmm(e.at)}`;
  return (
    <Link href={wiedergabeZiel(e.at)} className="wk-zeile" title={`${wann} · ${ergebnis} · ${e.kontakt_min} min angefordert. Öffnet die Wiedergabe.`}>
      <span className="wk-zeit mono">{wann}</span>
      <svg className="wk-balken" viewBox={`0 0 ${breite} ${H}`} preserveAspectRatio="none" aria-hidden="true">
        {b.steht.map(([von, bis]) => (
          <rect key={`s${von}`} x={von} y={0} width={bis - von} height={H - 3} fill="rgba(255,255,255,.07)" />
        ))}
        {b.laeuft.map(([von, bis]) => (
          <rect key={`l${von}`} x={von} y={0} width={bis - von} height={H - 3} fill={C.heatPump} />
        ))}
        {e.kontakt_min > 0 ? <rect x={daten.vor_min} y={H - 2} width={Math.min(e.kontakt_min, daten.nach_min + 1)} height={2} fill={C.mist} /> : null}
        {/* Der Nullpunkt. `non-scaling-stroke`, weil das Bild in der Breite gestreckt wird und
            die Linie sonst mit in die Breite ginge. */}
        <line x1={daten.vor_min} x2={daten.vor_min} y1={0} y2={H} stroke="rgba(255,255,255,.75)" strokeWidth={1.5} vectorEffect="non-scaling-stroke" />
      </svg>
      <span className="wk-ergebnis">{ergebnis}</span>
    </Link>
  );
}

export function Ereignisraster({ daten }: { daten: Kontaktwirkung }) {
  const alle = daten.ereignisse ?? [];
  // Die jüngsten, nicht die ersten: was die Maschine letzte Woche tat, sagt mehr über heute.
  const gezeigt = useMemo(() => geordnet(alle.slice(-MAX_ZEILEN)), [alle]);
  const breite = daten.vor_min + daten.nach_min + 1;
  const marken = [-daten.vor_min, 0, 30, 60, 90, daten.nach_min].filter((m, i, a) => a.indexOf(m) === i);
  if (alle.length === 0) return null;
  return (
    <div className="wk-raster">
      <div className="wk-zeile wk-kopfzeile" aria-hidden="true">
        <span />
        <div className="wk-achse">
          {marken.map((m) => (
            // Auf schmalen Schirmen bleiben nur der Nullpunkt und das Ende: dort ist der Balken
            // hundert Punkte breit, und sechs Beschriftungen lägen aufeinander.
            <span key={m} className={`mono${m !== 0 && m !== daten.nach_min ? " wk-fein" : ""}`} style={{ left: `${((m + daten.vor_min) / breite) * 100}%` }}>
              {m === 0 ? (
                <>
                  Anforderung
                </>
              ) : m === daten.nach_min ? (
                achsenText(m)
              ) : (
                `${m > 0 ? "+" : "−"}${Math.abs(m)}`
              )}
            </span>
          ))}
        </div>
        <span />
      </div>
      {gezeigt.map((g) => (
        <div key={g.key} className="wk-gruppe">
          <h3 className="kicker wk-gruppentitel">
            {g.titel} · {g.ereignisse.length}
          </h3>
          {g.ereignisse.map((e) => (
            <Zeile key={e.at} e={e} daten={daten} />
          ))}
        </div>
      ))}
      <ul className="uhr-legende wk-legende">
        <li>
          <span className="uhr-marke" style={{ background: C.heatPump }} />
          Wärmepumpe läuft
        </li>
        <li>
          <span className="uhr-marke" style={{ background: "rgba(255,255,255,.12)" }} />
          gemessen, steht
        </li>
        <li>
          <span className="uhr-marke wk-marke-strich" style={{ background: C.mist }} />
          angefordert
        </li>
        <li>leer: keine Messung</li>
        {alle.length > MAX_ZEILEN ? (
          <li>
            gezeigt sind die jüngsten {MAX_ZEILEN} von {alle.length} Anforderungen
          </li>
        ) : null}
      </ul>
    </div>
  );
}
