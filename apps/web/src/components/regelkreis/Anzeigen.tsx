"use client";

import type { RegelkreisGlied, RegelkreisHerkunft } from "@/lib/api/models";

/**
 * Die Instrumente der Regelkreis-Seite: Zeiger, Pegel, Schieber, Sprungantwort.
 *
 * **Warum Instrumente und nicht Zahlen.** Eine Phasenreserve von 38° ist eine Zahl, die man lesen
 * und einordnen muss; ein Zeiger im roten Feld ist eine Lage, die man sieht. Dieselbe Auskunft,
 * ein Bruchteil der Zeit - und bei dreißig Parametern auf einer Seite ist das der Unterschied
 * zwischen einer Tafel, die man überfliegt, und einer, die man liest.
 *
 * **Jedes Instrument zeigt seinen Maßstab mit.** Ein Pegel ohne Skala ist Dekoration. Der Schieber
 * trägt deshalb seine Plausibilitätsgrenzen, der Zeiger seine Felder, der Pegel seine Schwelle -
 * sonst sagt der Ausschlag nichts darüber, ob er groß ist.
 *
 * Alle Farben kommen aus den Tokens des Hauses; die Instrumente erfinden keine eigenen.
 */

const de = (v: number, stellen = 2) =>
  v.toLocaleString("de-DE", { minimumFractionDigits: stellen, maximumFractionDigits: stellen });

export const HERKUNFT_FARBE: Record<RegelkreisHerkunft, string> = {
  gemessen: "var(--amber)",
  geschaetzt: "var(--amber-soft)",
  annahme: "var(--text-3)",
  fest: "var(--text-3)",
  entwurf: "var(--mist)",
  uebersteuert: "var(--alert)",
};

/* ------------------------------------------------------------------ Sprungantwort */

/**
 * Das Bild eines Übertragungsglieds, wie es seit jeher im Kästchen steht: die Antwort auf einen
 * Sprung, oder bei statischen Gliedern die Kennlinie.
 *
 * Die Kurve kommt gerechnet aus dem Kern. Hier wird sie nur in den Rahmen gelegt.
 */
export function Sprungantwort({ g, breite = 42, hoehe = 26, dick = false }: { g: RegelkreisGlied; breite?: number; hoehe?: number; dick?: boolean }) {
  const pad = 2.5;
  const x = (u: number) => pad + u * (breite - 2 * pad);
  const y = (v: number) => hoehe - pad - v * (hoehe - 2 * pad);
  const pfad = (punkte: [number, number][]) => punkte.map((p, i) => `${i ? "L" : "M"}${x(p[0]).toFixed(1)} ${y(p[1]).toFixed(1)}`).join(" ");
  return (
    <g className="rk-sprung">
      <rect x={0.5} y={0.5} width={breite - 1} height={hoehe - 1} rx={2} className="rk-sprung-feld" />
      {/* Die Achsen: ohne sie ist eine Kurve nur ein Gekritzel. */}
      <line x1={x(0)} y1={y(0)} x2={x(1)} y2={y(0)} className="rk-sprung-achse" />
      <line x1={x(0)} y1={y(0)} x2={x(0)} y2={y(1)} className="rk-sprung-achse" />
      {g.kurve2.length ? <path d={pfad(g.kurve2 as [number, number][])} className="rk-sprung-kurve rk-sprung-blass" /> : null}
      <path d={pfad(g.kurve as [number, number][])} className={`rk-sprung-kurve${dick ? " rk-sprung-dick" : ""}`} />
    </g>
  );
}

/** Dasselbe Bild als eigenständige Grafik, für Katalog und Detailblatt. */
export function SprungantwortBild({ g, breite = 96, hoehe = 58 }: { g: RegelkreisGlied; breite?: number; hoehe?: number }) {
  return (
    <svg viewBox={`0 0 ${breite} ${hoehe}`} width={breite} height={hoehe} role="img" aria-label={`Kennbild: ${g.erkennen}`}>
      <Sprungantwort g={g} breite={breite} hoehe={hoehe} dick />
    </svg>
  );
}

/* ------------------------------------------------------------------ Schieber */

/**
 * Ein Parameter als Schieber über seinem Plausibilitätsbereich - wie der Fader eines Mischpults.
 *
 * Zu sehen ist auf einen Blick, was eine Zahl allein nicht sagt: wo der Wert zwischen seinen
 * Grenzen steht, wie weit er vom Startwert fortgewandert ist, und wie breit die Unsicherheit um
 * ihn herum liegt. Ein Wert dicht an der Grenze ist ein Grund, nachzusehen.
 */
export function Schieber({
  wert,
  unten,
  oben,
  startwert,
  sigma,
  herkunft,
  breite = 132,
}: {
  wert: number;
  unten: number;
  oben: number;
  startwert?: number;
  sigma?: number | null;
  herkunft: RegelkreisHerkunft;
  breite?: number;
}) {
  const hoehe = 16;
  const spanne = Math.max(1e-9, oben - unten);
  const anteil = (v: number) => Math.max(0, Math.min(1, (v - unten) / spanne));
  const x = (v: number) => 2 + anteil(v) * (breite - 4);
  const farbe = HERKUNFT_FARBE[herkunft];
  const bandL = sigma ? x(wert - 2 * sigma) : null;
  const bandR = sigma ? x(wert + 2 * sigma) : null;
  return (
    <svg viewBox={`0 0 ${breite} ${hoehe}`} width={breite} height={hoehe} className="rk-schieber" role="img" aria-label={`Wert ${de(wert, 3)} zwischen ${de(unten, 3)} und ${de(oben, 3)}`}>
      <rect x={2} y={hoehe / 2 - 3} width={breite - 4} height={6} rx={3} className="rk-schieber-bahn" />
      {bandL !== null && bandR !== null ? <rect x={bandL} y={hoehe / 2 - 3} width={Math.max(1.5, bandR - bandL)} height={6} rx={3} fill="var(--mist)" opacity={0.42} /> : null}
      {/* Die Teilung: Viertel des Bereichs, damit die Lage ablesbar ist. */}
      {[0.25, 0.5, 0.75].map((t) => (
        <line key={t} x1={2 + t * (breite - 4)} x2={2 + t * (breite - 4)} y1={hoehe / 2 - 5} y2={hoehe / 2 + 5} className="rk-schieber-teil" />
      ))}
      {startwert !== undefined ? <line x1={x(startwert)} x2={x(startwert)} y1={2} y2={hoehe - 2} className="rk-schieber-start" /> : null}
      <g className="rk-schieber-griff" style={{ color: farbe }}>
        <rect x={x(wert) - 3} y={1.5} width={6} height={hoehe - 3} rx={2} fill={farbe} />
        <rect x={x(wert) - 0.6} y={3.5} width={1.2} height={hoehe - 7} fill="var(--deep)" opacity={0.5} />
      </g>
    </svg>
  );
}

/* ------------------------------------------------------------------ Rundinstrument */

type Feld = { bis: number; farbe: string };

/**
 * Ein Zeigerinstrument mit farbigen Feldern: der Wert als Lage, nicht als Zahl.
 *
 * Für die Phasenreserve gebaut, aber allgemein: `felder` gibt die Bereiche an, `warnbis` sagt, bis
 * wo es eng ist. Die Zahl steht trotzdem in der Mitte - wer rechnen will, soll nicht schätzen
 * müssen.
 */
export function Rundinstrument({
  wert,
  von,
  bis,
  felder,
  einheit,
  titel,
  stellen = 0,
  groesse = 92,
}: {
  wert: number | null;
  von: number;
  bis: number;
  felder: Feld[];
  einheit?: string;
  titel: string;
  stellen?: number;
  groesse?: number;
}) {
  const r = groesse / 2 - 9;
  const cx = groesse / 2;
  const cy = groesse / 2 + 4;
  const a0 = 150;
  const a1 = 390; // 240° Skala, unten offen - die klassische Lage
  const winkel = (v: number) => a0 + ((Math.max(von, Math.min(bis, v)) - von) / (bis - von)) * (a1 - a0);
  const punkt = (grad: number, radius: number): [number, number] => {
    const b = (grad * Math.PI) / 180;
    return [cx + radius * Math.cos(b), cy + radius * Math.sin(b)];
  };
  const bogen = (gradVon: number, gradBis: number, radius: number) => {
    const [x0, y0] = punkt(gradVon, radius);
    const [x1, y1] = punkt(gradBis, radius);
    const gross = gradBis - gradVon > 180 ? 1 : 0;
    return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${radius} ${radius} 0 ${gross} 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`;
  };
  let letzter = von;
  const zeiger = wert === null ? null : winkel(wert);
  return (
    <span className="rk-rund-feldchen">
    <svg viewBox={`0 0 ${groesse} ${groesse + 2}`} width={groesse} height={groesse + 2} className="rk-rund" role="img" aria-label={`${titel}: ${wert === null ? "kein Wert" : de(wert, stellen) + (einheit ?? "")}`}>
      {felder.map((f) => {
        const d = bogen(winkel(letzter), winkel(f.bis), r);
        letzter = f.bis;
        return <path key={f.bis} d={d} stroke={f.farbe} strokeWidth={5} fill="none" strokeLinecap="butt" opacity={0.85} />;
      })}
      {/* Teilstriche */}
      {[0, 0.25, 0.5, 0.75, 1].map((t) => {
        const g = a0 + t * (a1 - a0);
        const [x0, y0] = punkt(g, r - 5);
        const [x1, y1] = punkt(g, r - 9);
        return <line key={t} x1={x0} y1={y0} x2={x1} y2={y1} className="rk-rund-teil" />;
      })}
      {zeiger !== null ? (
        <>
          <line x1={cx} y1={cy} x2={punkt(zeiger, r - 6)[0]} y2={punkt(zeiger, r - 6)[1]} className="rk-rund-zeiger" />
          <circle cx={cx} cy={cy} r={3.2} className="rk-rund-nabe" />
        </>
      ) : null}
      <text x={cx} y={cy + 20} textAnchor="middle" className="rk-rund-zahl">
        {wert === null ? "—" : de(wert, stellen)}
        {einheit ? <tspan className="rk-rund-einheit">{einheit}</tspan> : null}
      </text>
    </svg>
    <i>{titel}</i>
    </span>
  );
}

/* ------------------------------------------------------------------ Pegel */

/**
 * Ein stehender Pegel in Segmenten, wie an einem Mischpult.
 *
 * Gebaut für den Vergleich zweier Größen nebeneinander - zwei Pegel und eine Schwelle dazwischen
 * sagen in einem Blick, welche Wärme gerade die billigere ist.
 */
export function Pegel({
  wert,
  max,
  schwelle,
  titel,
  zahl,
  farbe = "var(--amber)",
  hoehe = 104,
  segmente = 16,
}: {
  wert: number;
  max: number;
  schwelle?: number;
  titel: string;
  zahl: string;
  farbe?: string;
  hoehe?: number;
  segmente?: number;
}) {
  const breite = 26;
  const anteil = Math.max(0, Math.min(1, wert / max));
  const voll = Math.round(anteil * segmente);
  const segH = (hoehe - 4) / segmente - 1.6;
  return (
    <span className="rk-pegel-feldchen">
    <svg viewBox={`0 0 ${breite + 4} ${hoehe + 16}`} width={breite + 4} height={hoehe + 16} className="rk-pegel" role="img" aria-label={`${titel}: ${zahl}`}>
      <rect x={1} y={1} width={breite + 2} height={hoehe + 2} rx={3} className="rk-pegel-feld" />
      {Array.from({ length: segmente }, (_, i) => {
        const y = hoehe - 2 - (i + 1) * (segH + 1.6) + 1.6;
        const an = i < voll;
        return <rect key={i} x={4} y={y} width={breite - 4} height={segH} rx={1} fill={an ? farbe : "var(--line-1)"} opacity={an ? 1 : 0.5} />;
      })}
      {schwelle !== undefined ? (
        <g>
          <line x1={1} x2={breite + 3} y1={hoehe + 2 - (schwelle / max) * hoehe} y2={hoehe + 2 - (schwelle / max) * hoehe} className="rk-pegel-schwelle" />
        </g>
      ) : null}
      <text x={(breite + 4) / 2} y={hoehe + 14} textAnchor="middle" className="rk-pegel-zahl">
        {zahl}
      </text>
    </svg>
    <i>{titel}</i>
    </span>
  );
}

/* ------------------------------------------------------------------ Lernfortschritt */

/** Ein Ring, der sich füllt: wie viele Stützstellen von denen, die eine Übernahme braucht. */
export function Ring({ anteil, mitte, titel, groesse = 64, farbe = "var(--amber)" }: { anteil: number; mitte: string; titel?: string; groesse?: number; farbe?: string }) {
  const r = groesse / 2 - 6;
  const u = 2 * Math.PI * r;
  const a = Math.max(0, Math.min(1, anteil));
  return (
    <span className="rk-rund-feldchen">
    <svg viewBox={`0 0 ${groesse} ${groesse}`} width={groesse} height={groesse} className="rk-ring" role="img" aria-label={`${titel ?? "Fortschritt"}: ${Math.round(a * 100)} Prozent`}>
      <circle cx={groesse / 2} cy={groesse / 2} r={r} className="rk-ring-bahn" />
      <circle
        cx={groesse / 2}
        cy={groesse / 2}
        r={r}
        fill="none"
        stroke={farbe}
        strokeWidth={4}
        strokeLinecap="round"
        strokeDasharray={`${(a * u).toFixed(1)} ${u.toFixed(1)}`}
        transform={`rotate(-90 ${groesse / 2} ${groesse / 2})`}
      />
      <text x={groesse / 2} y={groesse / 2 + 4} textAnchor="middle" className="rk-ring-zahl">
        {mitte}
      </text>
    </svg>
    {titel ? <i>{titel}</i> : null}
    </span>
  );
}

/* ------------------------------------------------------------------ Leuchten */

/** Eine Reihe Meldeleuchten: an, aus, warnend. Für Zustände, die man zählt, nicht misst. */
export function Leuchte({ an, farbe = "var(--amber)", titel }: { an: boolean; farbe?: string; titel: string }) {
  return (
    <span className="rk-leuchte" title={titel}>
      <i style={{ background: an ? farbe : "var(--line-2)", boxShadow: an ? `0 0 7px ${farbe}` : "none" }} />
      {titel}
    </span>
  );
}
