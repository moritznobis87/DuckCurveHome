"use client";

import Link from "next/link";
import { useMemo } from "react";
import type { Plan } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { C } from "@/components/charts/palette";
import { hausStunde, hausTag } from "@/components/waerme/wirkung";
import { abschnitte, ausblick, SCHRITT_MS, ZELLEN, type Fenster, type Zelle } from "./ausblick";

/**
 * Der Ausblick der Startseite am Handy: die nächsten 24 Stunden als Bild und in drei Sätzen.
 *
 * Er ersetzt die Kachel „Nächste 24 h", die drei Uhrzeiten untereinander zeigte. Oben steht, was
 * der Strom gerade kostet und ob das viel ist; darunter drei Bänder an einer Zeitachse, die bei
 * jetzt beginnt (Preis, Sonne, Wärmepumpe); darunter das, was man daraus macht.
 *
 * **Gerechnet wird in `ausblick.ts`.** Hier wird gezeichnet und formuliert. Die Bänder teilen
 * sich eine Achse; jedes hat seine eigene Höhe und seine eigene Skala, deshalb drei Flächen und
 * nicht drei Kurven in einer.
 */
const B = ZELLEN; // Breite der Zeichnung in Zellen

function de(x: number, n = 0): string {
  return x.toLocaleString("de-DE", { minimumFractionDigits: n, maximumFractionDigits: n });
}

/** „11:30" heute, „morgen 11:30" am nächsten Tag. */
function wann(ts: number, nowMs: number): string {
  const morgen = hausTag(new Date(ts).toISOString()) !== hausTag(new Date(nowMs).toISOString());
  return `${morgen ? "morgen " : ""}${hhmm(new Date(ts))}`;
}

function vonBis(f: { start: number; end: number }, nowMs: number): string {
  return `${wann(f.start, nowMs)} bis ${hhmm(new Date(f.end))}`;
}

/** Stufenlinie über die Zellen, als Fläche bis zum Boden geschlossen. Lücken unterbrechen sie. */
function stufen(zellen: Zelle[], y: (z: Zelle) => number | null, boden: number): { linie: string; flaeche: string } {
  let linie = "";
  let flaeche = "";
  let offen = false;
  let x0 = 0;
  zellen.forEach((z, i) => {
    const h = y(z);
    if (h == null) {
      if (offen) flaeche += `L${i} ${boden} L${x0} ${boden} Z`;
      offen = false;
      return;
    }
    if (!offen) {
      x0 = i;
      linie += `M${i} ${h} `;
      flaeche += `M${i} ${h} `;
      offen = true;
    } else {
      linie += `L${i} ${h} `;
      flaeche += `L${i} ${h} `;
    }
    linie += `L${i + 1} ${h} `;
    flaeche += `L${i + 1} ${h} `;
    if (i === zellen.length - 1) flaeche += `L${i + 1} ${boden} L${x0} ${boden} Z`;
  });
  return { linie, flaeche };
}

function Band({ titel, rechts, hoehe, children }: { titel: string; rechts?: string; hoehe: number; children: React.ReactNode }) {
  return (
    <div className="ausblick-band">
      <div className="ausblick-band-kopf">
        <span>{titel}</span>
        {rechts ? <span className="mono">{rechts}</span> : null}
      </div>
      <svg viewBox={`0 0 ${B} ${hoehe}`} preserveAspectRatio="none" style={{ height: hoehe }} aria-hidden>
        {children}
      </svg>
    </div>
  );
}

const LAGE_SATZ: Record<string, string> = {
  günstig: "Strom ist gerade günstig",
  mittel: "Strom ist gerade weder günstig noch teuer",
  teuer: "Strom ist gerade teuer",
  gleichmäßig: "Der Preis ändert sich heute kaum",
};

export function Ausblick({ plan, nowMs, warnung }: { plan: Plan | null; nowMs: number; warnung?: string }) {
  const a = useMemo(() => ausblick(plan, nowMs), [plan, nowMs]);
  if (a.zellen.length < 8) return null;

  const { preisMin: lo, preisMax: hi } = a;
  const spanne = lo != null && hi != null ? Math.max(1, hi - lo) : 1;
  const H_PREIS = 46;
  const H_SONNE = 34;
  const preis = stufen(a.zellen, (z) => (z.preis == null || lo == null ? null : H_PREIS - 3 - ((z.preis - lo) / spanne) * (H_PREIS - 8)), H_PREIS);
  const pvMax = Math.max(1, a.pvMax);
  const sonne = stufen(a.zellen, (z) => H_SONNE - 1 - (z.pv / pvMax) * (H_SONNE - 5), H_SONNE);
  const laeufe = abschnitte(a.zellen, (z) => z.wp);
  const braende = abschnitte(a.zellen, (z) => z.ofen);
  const hatFahrplan = (plan?.intervals ?? []).some((iv) => iv.reason_code === "planned_optimizer");
  const zelleVon = (f: Fenster) => [(f.start - a.zellen[0]!.ts) / SCHRITT_MS, (f.end - a.zellen[0]!.ts) / SCHRITT_MS] as const;

  // Die Achse: jede volle sechste Stunde der Hausuhr. Die erste Marke ist „jetzt".
  const marken = a.zellen
    .map((z, i) => ({ i, stunde: hausStunde(new Date(z.ts).toISOString()), minute: new Date(z.ts).getUTCMinutes() }))
    .filter((m) => m.minute === 0 && m.stunde % 6 === 0 && m.i >= 6 && m.i <= B - 4);

  const lauf = laeufe[0];
  const laufSatz = !hatFahrplan
    ? null
    : !lauf
      ? "Die Wärmepumpe hat in den nächsten 24 Stunden keinen geplanten Lauf."
      : lauf[0] === 0
        ? `Die Wärmepumpe soll bis ${hhmm(new Date(a.zellen[0]!.ts + lauf[1] * SCHRITT_MS))} laufen.`
        : `Die Wärmepumpe soll von ${vonBis({ start: a.zellen[lauf[0]]!.ts, end: a.zellen[0]!.ts + lauf[1] * SCHRITT_MS }, nowMs)} laufen.`;
  const brand = braende[0];
  const lage = a.lage ? LAGE_SATZ[a.lage] : null;
  const stelle = a.preisJetzt != null && lo != null && hi != null && hi > lo ? (a.preisJetzt - lo) / (hi - lo) : null;

  return (
    <section className="ausblick" aria-label="Die nächsten 24 Stunden">
      <div className="ausblick-kopf">
        <h2>Die nächsten 24 Stunden</h2>
        <Link href="/waerme/fahrplan">Fahrplan ›</Link>
      </div>

      {a.preisJetzt != null ? (
        <div className="ausblick-preis">
          <div className="ausblick-preis-zeile">
            <span className="mono ausblick-preis-zahl">
              {de(a.preisJetzt, 1)}
              <span>ct/kWh</span>
            </span>
            {lage ? <span className="ausblick-preis-wort">{lage}</span> : null}
          </div>
          {stelle != null && lo != null && hi != null ? (
            <div className="ausblick-skala" role="img" aria-label={`Der Preis liegt in den nächsten 24 Stunden zwischen ${de(lo)} und ${de(hi)} Cent, jetzt bei ${de(a.preisJetzt, 1)} Cent.`}>
              <span className="mono">{de(lo)}</span>
              <span className="ausblick-skala-spur">
                <span className="ausblick-skala-punkt" style={{ left: `${Math.max(0, Math.min(1, stelle)) * 100}%` }} />
              </span>
              <span className="mono">{de(hi)} ct</span>
            </div>
          ) : null}
        </div>
      ) : null}

      <div className="ausblick-bild">
        <Band titel="Strompreis" rechts={lo != null && hi != null ? `${de(lo)} bis ${de(hi)} ct` : undefined} hoehe={H_PREIS}>
          {a.guenstig ? <rect x={zelleVon(a.guenstig)[0]} y={0} width={zelleVon(a.guenstig)[1] - zelleVon(a.guenstig)[0]} height={H_PREIS} fill="rgba(255,215,120,.16)" /> : null}
          <path d={preis.flaeche} fill="rgba(127,163,179,.16)" />
          <path d={preis.linie} fill="none" stroke={C.price} strokeWidth={1.6} vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
        </Band>
        <Band titel="Sonne erwartet" rechts={a.pvMax >= 0.1 ? `bis ${de(a.pvMax, 1)} kW` : "keine"} hoehe={H_SONNE}>
          {a.sonne ? <rect x={zelleVon(a.sonne)[0]} y={0} width={zelleVon(a.sonne)[1] - zelleVon(a.sonne)[0]} height={H_SONNE} fill="rgba(242,169,0,.10)" /> : null}
          <path d={sonne.flaeche} fill="rgba(242,169,0,.38)" />
          <path d={sonne.linie} fill="none" stroke={C.pv} strokeWidth={1.4} vectorEffect="non-scaling-stroke" strokeLinejoin="round" />
        </Band>
        {hatFahrplan ? (
          <Band titel={braende.length ? "Wärmepumpe und Ofen geplant" : "Wärmepumpe geplant"} hoehe={braende.length ? 22 : 12}>
            <rect x={0} y={0} width={B} height={10} rx={1} fill="rgba(255,255,255,.06)" />
            {laeufe.map(([von, bis]) => (
              <rect key={von} x={von} y={0} width={bis - von} height={10} fill={C.heatPump} />
            ))}
            {braende.length ? <rect x={0} y={12} width={B} height={10} rx={1} fill="rgba(255,255,255,.06)" /> : null}
            {braende.map(([von, bis]) => (
              <rect key={von} x={von} y={12} width={bis - von} height={10} fill={C.stove} />
            ))}
          </Band>
        ) : null}
        <div className="ausblick-achse mono" aria-hidden>
          <span style={{ left: 0 }} className="ausblick-jetzt">
            jetzt
          </span>
          {marken.map((m) => (
            <span key={m.i} style={{ left: `${(m.i / B) * 100}%` }}>
              {m.stunde} Uhr
            </span>
          ))}
        </div>
      </div>

      <ul className="ausblick-saetze">
        {laufSatz ? (
          <li>
            <span className="ausblick-marke" style={{ background: C.heatPump }} />
            {laufSatz}
          </li>
        ) : null}
        {brand ? (
          <li>
            <span className="ausblick-marke" style={{ background: C.stove }} />
            Der Pelletofen soll von {vonBis({ start: a.zellen[brand[0]]!.ts, end: a.zellen[0]!.ts + brand[1] * SCHRITT_MS }, nowMs)} brennen.
          </li>
        ) : null}
        {a.guenstig ? (
          <li>
            <span className="ausblick-marke" style={{ background: "#ffd778" }} />
            Am günstigsten ist Netzstrom von {vonBis(a.guenstig, nowMs)}, im Mittel {de(a.guenstig.mittel)} ct.
          </li>
        ) : null}
        {a.sonne ? (
          <li>
            <span className="ausblick-marke" style={{ background: C.pv }} />
            Die meiste Sonne gibt es von {vonBis(a.sonne, nowMs)}.
          </li>
        ) : null}
      </ul>
      {a.guenstig || a.sonne ? <p className="ausblick-fuss">Die beiden Zeiten sind die besten für alles, was warten kann: Waschmaschine, Spülmaschine, Trockner.</p> : null}
      {a.preiseBis ? <p className="ausblick-fuss">Preise sind bis {wann(a.preiseBis, nowMs)} bekannt; die für morgen kommen am frühen Nachmittag.</p> : null}
      {warnung ? <p className="ausblick-fuss ausblick-warnung">{warnung}</p> : null}
    </section>
  );
}
