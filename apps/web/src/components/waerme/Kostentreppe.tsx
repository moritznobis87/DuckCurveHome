"use client";

import { useMemo } from "react";
import { C } from "@/components/charts/palette";
import type { Nachbetrachtung } from "@/lib/api/models";
import { achse, euro, euroMitVorzeichen, treppe, type Stufe } from "./nachbetrachtung";

/**
 * Die Kostentreppe: vom Versprechen des ersten Fahrplans zur Wirklichkeit, Stufe für Stufe.
 *
 * Eine Treppe und keine fünf Balken nebeneinander, weil die Frage nicht „wie hoch ist jede Linie"
 * heißt, sondern „wie kam es vom einen zum anderen". Jede Stufe beginnt, wo die vorige endet;
 * ihre Länge ist ihr Anteil am Abstand, und der Faden zwischen den Zeilen zeigt, dass es ein Weg
 * ist.
 *
 * **Die Farbe gehört der Sache, nicht der Richtung.** Der Fahrplan ist kühl, die Wirklichkeit
 * warm, die beiden Vergleichsrechnungen hell - dieselben Farben wie im Tagesvergleich darunter.
 * Ob eine Stufe teurer oder günstiger macht, steht an ihrem Vorzeichen und an der Pfeilspitze
 * ihres Balkens; eine zweite Farbbedeutung im selben Bild müsste man erst lernen.
 *
 * **Geschätztes ist umrandet, nicht gefüllt.** „Ohne Preisblick" ist eine Rechnung über einen
 * Tag, den es nicht gab. Sie steht daneben und sieht anders aus als das Gemessene.
 */

function farbe(s: Stufe): string {
  if (s.key === "wirklich") return C.heatPump;
  if (s.art === "bezug") return C.house;
  if (s.art === "stufe") return "rgba(255,255,255,.62)";
  return C.mist;
}

function Zeile({ s, min, max, faden, zusatz }: { s: Stufe; min: number; max: number; faden: boolean; zusatz?: string }) {
  const spanne = max - min || 1;
  const pct = (x: number) => ((x - min) / spanne) * 100;
  const links = pct(Math.min(s.von, s.bis));
  const breite = Math.abs(pct(s.bis) - pct(s.von));
  const teurer = s.bis >= s.von;
  const f = farbe(s);
  return (
    <div className={`nb-zeile nb-${s.art}`} title={s.satz || undefined}>
      <span className="nb-name">
        {s.name}
        {s.geschaetzt ? <span className="nb-klein"> · geschätzt</span> : null}
        {zusatz ? <span className="nb-zusatz">{zusatz}</span> : null}
      </span>
      <span className="nb-spur">
        <span
          // Die Pfeilspitze nur, wo es eine Richtung gibt: eine Stufe von null Cent zeigt nirgendhin.
          className={`nb-balken${s.art === "stufe" && Math.abs(s.eur) >= 0.005 ? (teurer ? " nb-teurer" : " nb-guenstiger") : ""}`}
          style={{
            left: `${links}%`,
            // Eine Stufe von null Cent bleibt als Strich sichtbar: sie ist eine Aussage.
            width: `max(${breite}%, 2px)`,
            background: s.geschaetzt ? "transparent" : f,
            border: s.geschaetzt ? `1.5px dashed ${f}` : undefined,
            color: f,
          }}
        />
        {/* Der Faden zur nächsten Zeile: dort, wo diese endet, beginnt die nächste. */}
        {faden ? <span className="nb-faden" style={{ left: `${pct(s.bis)}%` }} /> : null}
      </span>
      <span className="nb-wert mono">{s.art === "stufe" ? euroMitVorzeichen(s.eur) : euro(s.eur)}</span>
    </div>
  );
}

export function Kostentreppe({ d }: { d: Nachbetrachtung }) {
  const stufen = useMemo(() => treppe(d), [d]);
  const a = useMemo(() => achse(stufen), [stufen]);
  if (stufen.length === 0) return null;
  const eingriff = (d.abstaende ?? []).find((x) => x.key === "eingriff");
  const zerlegt =
    eingriff?.menge_eur != null && eingriff.zeit_eur != null
      ? `Menge ${euroMitVorzeichen(eingriff.menge_eur)} · Zeitpunkt ${euroMitVorzeichen(eingriff.zeit_eur)}${d.hat_ofen && eingriff.ofen_eur != null ? ` · Ofen ${euroMitVorzeichen(eingriff.ofen_eur)}` : ""}`
      : undefined;
  const kette = stufen.filter((s) => s.art !== "bezug");
  const bezug = stufen.filter((s) => s.art === "bezug");
  const spanne = a.max - a.min || 1;
  return (
    <div className="nb-treppe" role="group" aria-label="Kostentreppe vom Versprechen des Fahrplans zur Wirklichkeit">
      {kette.map((s, i) => (
        <Zeile key={s.key} s={s} min={a.min} max={a.max} faden={i < kette.length - 1 && kette[i + 1]?.art !== "summe"} zusatz={s.key === "eingriff" ? zerlegt : undefined} />
      ))}
      {bezug.length > 0 ? <div className="nb-trenner">zum Vergleich gerechnet</div> : null}
      {bezug.map((s) => (
        <Zeile key={s.key} s={s} min={a.min} max={a.max} faden={false} />
      ))}
      <div className="nb-zeile nb-achsenzeile" aria-hidden="true">
        <span />
        <span className="nb-achse">
          {a.marken.map((m, i) => (
            // Auf dem Telefon bleiben nur Anfang und Ende: sechs Beträge auf hundert Punkten lägen aufeinander.
            <span key={m} className={`mono${i > 0 && i < a.marken.length - 1 ? " wk-fein" : ""}`} style={{ left: `${((m - a.min) / spanne) * 100}%` }}>
              {m.toLocaleString("de-DE", { maximumFractionDigits: 2 })} €
            </span>
          ))}
        </span>
        <span />
      </div>
    </div>
  );
}
