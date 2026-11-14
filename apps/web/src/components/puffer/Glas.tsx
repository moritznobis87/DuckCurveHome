"use client";

import { useEffect, useId, useState } from "react";
import { FUEHLER, type Temperaturen, gradzahl, randBreite, stufen } from "./glas";

/**
 * Der Pufferspeicher als Glas. Die einzige Zeichnung des Speichers in der Anwendung; warum,
 * steht in `glas.ts`.
 *
 * `PufferGlas` ist ein Stück SVG für eine größere Zeichnung (Anlagenschema, Wärmepumpe),
 * `PufferGlasBild` dasselbe als eigenes Bild für eine Kachel (Startseite, Ambiente).
 */
type Seite = "rechts" | "links" | "keine";

interface GlasProps {
  /** Vier Temperaturen, von oben nach unten. */
  temps: Temperaturen;
  x?: number;
  y?: number;
  breite: number;
  hoehe: number;
  /** Auf welcher Seite die vier Zahlen stehen. */
  werte?: Seite;
  schrift?: number;
  /** Ohne den wandernden Lichtschein (`prefers-reduced-motion`). */
  ruhig?: boolean;
  /** Werte veraltet oder unvollständig: das Glas tritt zurück. */
  gedimmt?: boolean;
  /** Klasse für den Rand, damit ein Schema ihn beim Überfahren hervorheben kann. */
  randKlasse?: string;
}

export function PufferGlas({ temps, x = 0, y = 0, breite, hoehe, werte = "rechts", schrift = 13, ruhig = false, gedimmt = false, randKlasse }: GlasProps) {
  const id = useId().replace(/[^a-zA-Z0-9]/g, "");
  const s = stufen(temps);
  const r = breite / 2;
  const links = werte === "links";
  const kante = links ? x : x + breite;
  const richtung = links ? -1 : 1;
  return (
    <g opacity={gedimmt ? 0.5 : 1}>
      <defs>
        <linearGradient id={`${id}v`} gradientUnits="userSpaceOnUse" x1={x} y1={y} x2={x} y2={y + hoehe}>
          {s.length ? s.map((st) => <stop key={st.bei} offset={st.bei} stopColor={st.farbe} />) : <stop offset="0" stopColor="#1c3d4f" />}
        </linearGradient>
        <linearGradient id={`${id}r`} gradientUnits="userSpaceOnUse" x1={x} y1={y} x2={x + breite} y2={y}>
          <stop offset="0" stopColor="#fff" stopOpacity=".22" />
          <stop offset=".18" stopColor="#fff" stopOpacity=".05" />
          <stop offset=".55" stopColor="#fff" stopOpacity="0" />
          <stop offset="1" stopColor="#000" stopOpacity=".18" />
        </linearGradient>
        {/* Der wandernde Lichtschein läuft oben und unten weich aus. Als Rechteck mit Kanten stand
            er als Stufe im Verlauf, wo keine Schichtgrenze ist. */}
        <linearGradient id={`${id}s`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0" />
          <stop offset=".5" stopColor="#fff" stopOpacity=".1" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
        <clipPath id={`${id}c`}>
          <rect x={x} y={y} width={breite} height={hoehe} rx={r} />
        </clipPath>
      </defs>
      <g clipPath={`url(#${id}c)`}>
        <rect x={x} y={y} width={breite} height={hoehe} fill={`url(#${id}v)`} />
        {!ruhig && s.length ? (
          <rect x={x} y={y - hoehe * 0.07} width={breite} height={hoehe * 0.3} fill={`url(#${id}s)`}>
            <animate attributeName="y" values={`${y - hoehe * 0.07};${y + hoehe * 0.87};${y - hoehe * 0.07}`} dur="14s" repeatCount="indefinite" calcMode="spline" keySplines=".4 0 .6 1;.4 0 .6 1" />
          </rect>
        ) : null}
        <rect x={x} y={y} width={breite} height={hoehe} fill={`url(#${id}r)`} />
      </g>
      <rect className={randKlasse} x={x} y={y} width={breite} height={hoehe} rx={r} fill="none" stroke="rgba(255,255,255,.28)" strokeWidth="1.2" />
      <rect x={x + 2} y={y + 2} width={breite - 4} height={hoehe - 4} rx={r - 2} fill="none" stroke="rgba(255,255,255,.08)" strokeWidth="1" />
      {werte === "keine"
        ? null
        : FUEHLER.map((bei, i) => {
            const hy = y + hoehe * bei;
            const zahl = gradzahl(temps[i]);
            return (
              <g key={bei}>
                <line x1={kante + richtung * 4} y1={hy} x2={kante + richtung * 14} y2={hy} stroke="rgba(255,255,255,.3)" />
                <text x={kante + richtung * 20} y={hy} dominantBaseline="central" textAnchor={links ? "end" : "start"} fontSize={schrift} fill="var(--text-1)" style={{ fontFamily: "var(--font-mono)", fontVariantNumeric: "tabular-nums" }}>
                  {zahl ?? "-"}
                  {zahl != null ? <tspan dx={schrift * 0.12} fill="var(--text-3)">°</tspan> : null}
                </text>
              </g>
            );
          })}
    </g>
  );
}

/** Das Glas als eigenes Bild. Die Größe kommt aus dem Stylesheet; das Seitenverhältnis bleibt. */
export function PufferGlasBild({ className, breite = 56, hoehe = 300, werte = "rechts", schrift = 14, ...rest }: Omit<GlasProps, "x" | "y" | "breite" | "hoehe" | "ruhig"> & { className?: string; breite?: number; hoehe?: number }) {
  // Eine Kachel weiß nichts von der Einstellung „Bewegung reduzieren"; das Bild fragt selbst.
  const [ruhig, setRuhig] = useState(false);
  useEffect(() => setRuhig(window.matchMedia("(prefers-reduced-motion: reduce)").matches), []);
  const rand = werte === "keine" ? 0 : randBreite(schrift);
  const x = werte === "links" ? rand + 1 : 1;
  const w = breite + rand + 2;
  const h = hoehe + 2;
  return (
    <svg className={`puffer-glas${className ? ` ${className}` : ""}`} viewBox={`0 0 ${w} ${h}`} style={{ aspectRatio: `${w} / ${h}` }} aria-hidden>
      <PufferGlas {...rest} x={x} y={1} breite={breite} hoehe={hoehe} werte={werte} schrift={schrift} ruhig={ruhig} />
    </svg>
  );
}
