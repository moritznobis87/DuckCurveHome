"use client";

import Link from "next/link";
import { useMemo } from "react";
import type { EnergySnapshot, Measurement } from "@/lib/api/models";
import { ageLabel, hhmm, kw } from "@/lib/format";
import { useGroesse } from "@/lib/useGroesse";
import { Icon } from "@/components/ui/Icon";
import type { Sonnenlauf } from "./ambiente";
import { FLUSS_AB_KW, bandbreite, buehnenmass, sonnenort } from "./buehne";
import { flusswerte, frisch, grundlast, wpWort } from "./fluss";

/**
 * Die Bühne: das Haus unter seinem Himmel.
 *
 * Die Sonne steht auf ihrem Bogen an der Stelle, an der sie gerade ist; nachts stehen Mond und
 * Sterne da. Strom fließt als leuchtendes Band, dessen Breite die Leistung zeigt. Das Kabel vom
 * Netz und das Rohr zur Wärmepumpe laufen unter der Erde, und das Haus in der Mitte trägt die
 * Summe. Jede Sache führt auf ihre Seite; die Wärmepumpe öffnet ihre Auswahl.
 *
 * Gezeichnet wird in der Größe des Platzes, nicht gestreckt: die Maße kommen aus `buehne.ts`,
 * dieselben wie in der App.
 */
export function Buehne({ snapshot, nowMs, wpLaeuft, nacht, stand, lauf, sonneAb, vonEben, onPumpe }: {
  snapshot: EnergySnapshot | null;
  nowMs: number;
  wpLaeuft?: boolean;
  /** Mond und Sterne statt der Sonne. */
  nacht: boolean;
  /** Wie weit die Sonne auf dem Bogen ist, von 0 bis 1. */
  stand: number;
  /** Aufgang und Untergang des Tages für die Enden des Bogens. */
  lauf: Sonnenlauf | null;
  /** Wann die Sonne wiederkommt, als Uhrzeit. */
  sonneAb: string | null;
  /** Die Verbindung ist unterbrochen: von wann das Bild ist. */
  vonEben: string | null;
  onPumpe: () => void;
}) {
  const [ref, groesse] = useGroesse<HTMLDivElement>();
  const v = useMemo(() => flusswerte(snapshot), [snapshot]);
  const schmal = groesse != null && buehnenmass(groesse.breite, groesse.hoehe).schmal;
  return (
    <div className="start-mitte">
      <div className="start-buehne" data-nacht={nacht} data-gestoert={vonEben != null}>
        <div ref={ref} className="buehne-flaeche">
          {groesse && groesse.breite > 0 && groesse.hoehe > 0 ? (
            <Szene W={groesse.breite} H={groesse.hoehe} s={snapshot} nowMs={nowMs} wpLaeuft={wpLaeuft} nacht={nacht} stand={stand} lauf={lauf} sonneAb={sonneAb} onPumpe={onPumpe} />
          ) : null}
        </div>
        {vonEben ? <span className="start-von-eben"><Icon name="clock" size={16} />Das Bild ist von {vonEben}.</span> : null}
      </div>
      {schmal ? (
        <div className="start-unterhaus">
          <Link href="/strom/wallbox" className="start-karte start-ding" data-an={v.ev >= FLUSS_AB_KW} style={{ "--kartenfarbe": "var(--ev)" } as React.CSSProperties}>
            <span className="konto-zeichen start-zeichen"><Icon name="car" size={20} /></span>
            <span className="start-ding-text">
              <span className="mono start-ding-zahl">{kw(snapshot?.ev_power_kw.value)}<small>kW</small></span>
              <span className="start-ding-name">Wallbox {v.ev >= FLUSS_AB_KW ? "lädt" : "steht"}</span>
            </span>
          </Link>
          <button type="button" className="start-karte start-ding" data-an={!!wpLaeuft} aria-haspopup="dialog" onClick={onPumpe} style={{ "--kartenfarbe": "var(--heat-pump)" } as React.CSSProperties}>
            <span className="konto-zeichen start-zeichen"><Icon name="pump" size={20} /></span>
            <span className="start-ding-text">
              <span className="mono start-ding-zahl">{kw(snapshot?.heat_pump_power_kw.value)}<small>kW</small></span>
              <span className="start-ding-name">Wärmepumpe {wpWort(v.hp, wpLaeuft)}</span>
            </span>
          </button>
        </div>
      ) : null}
    </div>
  );
}

/** Ein Band: breit nach Leistung, in der Farbe der Sache, mit Lichtpunkten in Flussrichtung. */
export function Band({ d, kwJetzt, farbe, rueck = false }: { d: string; kwJetzt: number; farbe: string; rueck?: boolean }) {
  if (kwJetzt < FLUSS_AB_KW) return <path d={d} fill="none" stroke="var(--paper)" strokeOpacity={0.22} strokeWidth={1.5} strokeDasharray="3 6" strokeLinecap="round" />;
  const w = bandbreite(kwJetzt);
  return (
    <>
      <path d={d} fill="none" stroke={farbe} strokeWidth={w} strokeLinecap="round" strokeOpacity={0.92} style={{ filter: `drop-shadow(0 0 9px ${farbe})` }} />
      <path className={`bild-fliessen${rueck ? " bild-rueck" : ""}`} d={d} fill="none" stroke="var(--paper)" strokeOpacity={0.85} strokeWidth={Math.max(2, w * 0.28)} strokeLinecap="round" strokeDasharray="8 30" />
    </>
  );
}

function alter(m: Measurement | null | undefined, nowMs: number): string | undefined {
  const a = m ? ageLabel(m.observed_at, nowMs) : null;
  return a ? `Stand ${a}` : undefined;
}

/** Zahl und Name über einer Sache. Was ruht oder nicht gemessen ist, steht leiser da. */
function Schild({ x, y, zahl, einheit, name, anker, farbe, leise, schmal }: { x: number; y: number; zahl: string; einheit: string; name: string; anker: "start" | "middle" | "end"; farbe?: string; leise?: boolean; schmal: boolean }) {
  const hof = schmal ? " bild-hof" : "";
  return (
    <>
      <text x={x} y={y} textAnchor={anker} className={`bild-zahl${hof}`} fontSize={schmal ? 26 : 30} fillOpacity={leise ? 0.5 : 1} style={farbe && !leise ? { fill: farbe } : undefined}>
        {zahl}
        <tspan className="bild-einheit" fontSize={13} dx={4}>{einheit}</tspan>
      </text>
      <text x={x} y={y + 18} textAnchor={anker} className={`bild-name${hof}`} fontSize={12.5}>{name}</text>
    </>
  );
}

function Szene({ W, H, s, nowMs, wpLaeuft, nacht, stand, lauf, sonneAb, onPumpe }: { W: number; H: number; s: EnergySnapshot | null; nowMs: number; wpLaeuft?: boolean; nacht: boolean; stand: number; lauf: Sonnenlauf | null; sonneAb: string | null; onPumpe: () => void }) {
  const m = useMemo(() => buehnenmass(W, H), [W, H]);
  const v = useMemo(() => flusswerte(s), [s]);
  const sterne = useMemo(() => sternenhimmel(W, m.boden - 70, m.schmal ? 34 : 70), [W, m.boden, m.schmal]);
  const { schmal, boden: G, mitte: cx, hausHalb: hb, hausHoch: hh, dach, ueber } = m;
  const sonne = sonnenort(m, stand);
  const x0 = m.bogenRand;
  const spitze = G - hh - dach;
  const dx = hb + ueber;
  const lang = Math.sqrt(dx * dx + dach * dach);
  const ertrag = !nacht && v.pv >= FLUSS_AB_KW;
  const bezug = !v.einspeisung;
  const netzfarbe = bezug ? "var(--grid-in)" : "var(--grid-out)";
  const laedt = v.speicherWort === "lädt";
  const an = !!wpLaeuft || v.hp >= FLUSS_AB_KW;
  const pumpenfarbe = wpLaeuft ? "var(--heat-pump)" : "var(--text-3)";
  const soc = v.soc != null ? Math.max(0, Math.min(1, v.soc)) : 0;
  const kabel = `M${m.netzX},${G + 2} V${m.tief - 16} q0,16 16,16 H${cx - hb * (schmal ? 0.8 : 0.5) - 16} q16,0 16,-16 V${G + 2}`;
  const rohr = `M${cx + hb * 0.5},${G + 2} V${m.tief - 16} q0,16 16,16 H${m.pumpeX - 16} q16,0 16,-16 V${G + 2}`;
  const halb = Math.min(dx - 6, 18 + v.pv * 14);
  const kegelY = G - hh - dach * (1 - halb / dx) - 3;
  // Eine Solarplatte liegt auf jeder Dachseite, um fünf Pixel über die Dachhaut gehoben.
  const platte = (seite: 1 | -1) => {
    const nx = (seite * dach) / lang * 5;
    const ny = (-dx / lang) * 5;
    return <line x1={cx + seite * dx * 0.16 + nx} y1={spitze + dach * 0.16 + ny} x2={cx + seite * dx * 0.88 + nx} y2={spitze + dach * 0.88 + ny} stroke={ertrag ? "var(--amber)" : "var(--mist)"} strokeOpacity={ertrag ? 1 : 0.55} strokeWidth={6} strokeLinecap="round" style={ertrag ? { filter: "drop-shadow(0 0 8px var(--amber))" } : undefined} />;
  };
  const treffer = (x: number, breit: number) => <rect x={x - breit / 2} y={G - 112} width={breit} height={112} fill="transparent" />;
  const mond = { x: W * (schmal ? 0.76 : 0.7), y: schmal ? 40 : 54, r: 15 };
  const oben = { x: schmal ? 16 : 24, y: schmal ? 44 : 58 };

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width={W} height={H} role="group" aria-label="Das Haus unter seinem Himmel: woher der Strom gerade kommt und wohin er fließt">
      <defs>
        <radialGradient id="bue-schein"><stop offset="0" stopColor="var(--amber)" stopOpacity={0.55} /><stop offset="1" stopColor="var(--amber)" stopOpacity={0} /></radialGradient>
        <linearGradient id="bue-strahl" gradientUnits="userSpaceOnUse" x1={sonne.x} y1={sonne.y} x2={cx} y2={G - hh}><stop offset="0" stopColor="var(--amber)" stopOpacity={0.62} /><stop offset="1" stopColor="var(--amber)" stopOpacity={0.16} /></linearGradient>
        <linearGradient id="bue-boden" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="var(--deep)" stopOpacity={0.9} /><stop offset="1" stopColor="var(--deep)" stopOpacity={0.55} /></linearGradient>
      </defs>

      {/* Himmel */}
      {nacht ? sterne.map((p, i) => <circle key={i} className={i % 9 === 0 ? "bild-stern" : undefined} cx={p.x} cy={p.y} r={p.r} fill="var(--paper)" fillOpacity={0.25 + p.r * 0.35} />) : null}
      <path d={`M${x0},${G} A${m.rx},${m.ry} 0 0 1 ${W - x0},${G}`} fill="none" stroke="var(--paper)" strokeOpacity={nacht ? 0.16 : 0.3} strokeWidth={1.5} strokeDasharray="2 7" strokeLinecap="round" />
      {nacht ? (
        <>
          <circle cx={mond.x} cy={mond.y} r={62} fill="var(--amber-soft)" fillOpacity={0.07} />
          <path transform={`rotate(-28 ${mond.x} ${mond.y})`} d={`M${mond.x},${mond.y - mond.r} A${mond.r},${mond.r} 0 0 0 ${mond.x},${mond.y + mond.r} A${mond.r * 1.55},${mond.r * 1.55} 0 0 1 ${mond.x},${mond.y - mond.r} Z`} fill="var(--amber-soft)" style={{ filter: "drop-shadow(0 0 10px var(--amber-soft))" }} />
          {sonneAb ? (
            <Link href="/strom/pv" aria-label={`Sonne: Die Sonne geht um ${sonneAb} auf. Details öffnen`}>
              <text x={oben.x} y={oben.y - (schmal ? 10 : 16)} fontSize={schmal ? 14 : 15.5} className="bild-name">Die Sonne geht um {sonneAb} auf.</text>
            </Link>
          ) : null}
        </>
      ) : (
        <>
          <path d={`M${x0},${G} A${m.rx},${m.ry} 0 0 1 ${sonne.x},${sonne.y}`} fill="none" stroke="var(--amber)" strokeOpacity={0.85} strokeWidth={2} strokeLinecap="round" />
          <circle cx={sonne.x} cy={sonne.y} r={schmal ? 78 : 104} fill="url(#bue-schein)" />
          {ertrag ? (
            <>
              <path d={`M${sonne.x - 9},${sonne.y + 6} L${sonne.x + 9},${sonne.y + 6} L${cx + halb},${kegelY} L${cx},${spitze - 3} L${cx - halb},${kegelY} Z`} fill="url(#bue-strahl)" />
              <path className="bild-fliessen" d={`M${sonne.x},${sonne.y + 20} L${cx},${spitze - 6}`} fill="none" stroke="var(--paper)" strokeOpacity={0.8} strokeWidth={3} strokeLinecap="round" strokeDasharray="8 30" />
            </>
          ) : null}
          <circle cx={sonne.x} cy={sonne.y} r={16} fill="var(--amber-soft)" style={{ filter: "drop-shadow(0 0 14px var(--amber))" }} />
          <Link href="/strom/pv" aria-label={`Sonne: ${kw(s?.pv_power_kw.value)} kW. Details öffnen`}>
            <title>{alter(s?.pv_power_kw, nowMs)}</title>
            <text x={oben.x} y={oben.y} className="bild-zahl" fontSize={schmal ? 30 : 40} style={{ fill: frisch(s?.pv_power_kw) ? "var(--amber)" : "var(--text-3)" }}>
              {kw(s?.pv_power_kw.value)}
              <tspan className="bild-einheit" fontSize={14} dx={5}>kW Sonne</tspan>
            </text>
          </Link>
        </>
      )}

      {/* Boden, mit Aufgang und Untergang an den Enden des Bogens */}
      <path d={`M0,${G - 10} C${W * 0.18},${G - 30} ${W * 0.32},${G - 4} ${W * 0.5},${G - 14} S${W * 0.82},${G - 34} ${W},${G - 8} V${G} H0 Z`} fill="var(--deep)" fillOpacity={0.45} />
      <rect x={0} y={G} width={W} height={H - G} fill="url(#bue-boden)" />
      <line x1={0} x2={W} y1={G} y2={G} stroke="var(--line-2)" />
      {lauf ? (
        <>
          <text x={x0} y={H - 10} fontSize={10.5} className="bild-zahl bild-einheit">{hhmm(new Date(lauf.von))}</text>
          <text x={W - x0} y={H - 10} textAnchor="end" fontSize={10.5} className="bild-zahl bild-einheit">{hhmm(new Date(lauf.bis))}</text>
        </>
      ) : null}

      {/* Netz: das Kabel läuft unter der Erde ins Haus. */}
      <Band d={kabel} kwJetzt={v.netz} farbe={netzfarbe} rueck={!bezug} />
      <Link href="/strom" aria-label={`Netz: ${kw(v.netz)} kW ${bezug ? "Bezug" : "Einspeisung"}. Details öffnen`}>
        <title>{alter(s?.grid_power_kw, nowMs)}</title>
        {treffer(m.netzX, 80)}
        <g transform={`translate(${m.netzX - (schmal ? 23 : 26.5)},${G - (schmal ? 41 : 48)})`}><Icon name="grid" size={schmal ? 46 : 53} color={frisch(s?.grid_power_kw) ? netzfarbe : "var(--text-3)"} strokeWidth={1.4} /></g>
        <Schild x={schmal ? 10 : m.netzX} y={m.schildY} zahl={kw(v.netz)} einheit="kW" name={bezug ? "Netzbezug" : "Einspeisung"} anker={schmal ? "start" : "middle"} leise={!frisch(s?.grid_power_kw)} schmal={schmal} />
      </Link>

      {/* Speicher: eine Batterie neben dem Haus, gefüllt nach Ladestand. */}
      <Band d={`M${cx + hb},${G - 26} H${m.speicherX - 20}`} kwJetzt={v.speicherWort === "hält" ? 0 : v.speicher} farbe="var(--battery)" rueck={!laedt} />
      <Link href="/strom/speicher" aria-label={`Speicher: ${v.soc != null ? Math.round(v.soc * 100) : "-"} %, ${v.speicherWort}. Details öffnen`}>
        <title>{alter(s?.battery_soc, nowMs)}</title>
        {treffer(m.speicherX, 80)}
        <rect x={m.speicherX - 7} y={G - 67} width={14} height={6} rx={2} fill="var(--battery)" />
        <rect x={m.speicherX - 19} y={G - 62} width={38} height={60} rx={8} fill="var(--surface-1)" stroke="var(--battery)" strokeWidth={2} />
        <rect x={m.speicherX - 14} y={G - 7 - 50 * soc} width={28} height={50 * soc} rx={4} fill="var(--battery)" />
        <Schild x={schmal ? W - 10 : m.speicherX} y={m.schildY} zahl={v.soc != null ? String(Math.round(v.soc * 100)) : "-"} einheit="%" name={`Speicher ${v.speicherWort}`} anker={schmal ? "end" : "middle"} leise={!frisch(s?.battery_soc)} schmal={schmal} />
      </Link>

      {schmal ? (
        <>
          {/* Am Telefon hängen Wallbox und Wärmepumpe als zwei Kacheln unter der Bühne. */}
          <Band d={`M${cx - 22},${G + 2} V${G + 16} q0,14 -14,14 H${W * 0.25 + 14} q-14,0 -14,14 V${H}`} kwJetzt={v.ev} farbe="var(--ev)" />
          <Band d={`M${cx + 22},${G + 2} V${G + 16} q0,14 14,14 H${W * 0.75 - 14} q14,0 14,14 V${H}`} kwJetzt={v.hp} farbe="var(--heat-pump)" />
        </>
      ) : (
        <>
          <Band d={`M${cx - hb},${G - 20} H${m.wallboxX + 26}`} kwJetzt={v.ev} farbe="var(--ev)" />
          <Link href="/strom/wallbox" aria-label={`Wallbox: ${kw(s?.ev_power_kw.value)} kW, ${v.ev >= FLUSS_AB_KW ? "lädt" : "steht"}. Details öffnen`}>
            <title>{alter(s?.ev_power_kw, nowMs)}</title>
            {treffer(m.wallboxX, 90)}
            <g transform={`translate(${m.wallboxX - 25},${G - 45})`}><Icon name="car" size={50} color={v.ev >= FLUSS_AB_KW ? "var(--ev)" : "var(--text-3)"} strokeWidth={1.45} /></g>
            <Schild x={m.wallboxX} y={m.schildY} zahl={kw(s?.ev_power_kw.value)} einheit="kW" name={`Wallbox ${v.ev >= FLUSS_AB_KW ? "lädt" : "steht"}`} anker="middle" leise={v.ev < FLUSS_AB_KW} schmal={schmal} />
          </Link>
          <Band d={rohr} kwJetzt={v.hp} farbe="var(--heat-pump)" />
          <a href="/waerme/waermepumpe" className={wpLaeuft ? "bild-laeuft" : undefined} aria-haspopup="dialog" aria-label={`Wärmepumpe: ${kw(s?.heat_pump_power_kw.value)} kW, ${wpWort(v.hp, wpLaeuft)}. Auswahl öffnen`} onClick={(e) => { e.preventDefault(); onPumpe(); }}>
            <title>{alter(s?.heat_pump_power_kw, nowMs)}</title>
            {treffer(m.pumpeX, 96)}
            <rect x={m.pumpeX - 31} y={G - 50} width={62} height={48} rx={8} fill="var(--surface-1)" stroke={pumpenfarbe} strokeWidth={2} />
            <circle cx={m.pumpeX - 9} cy={G - 26} r={15} fill="none" stroke={pumpenfarbe} strokeWidth={1.6} />
            <g className="bild-luefter" stroke={pumpenfarbe} strokeWidth={2.4} strokeLinecap="round">
              <line x1={m.pumpeX - 9} y1={G - 37} x2={m.pumpeX - 9} y2={G - 15} />
              <line x1={m.pumpeX - 20} y1={G - 26} x2={m.pumpeX + 2} y2={G - 26} />
            </g>
            <path d={`M${m.pumpeX + 15},${G - 38} h9 M${m.pumpeX + 15},${G - 30} h9 M${m.pumpeX + 15},${G - 22} h9 M${m.pumpeX + 15},${G - 14} h9`} stroke={pumpenfarbe} strokeWidth={1.6} strokeLinecap="round" />
            <Schild x={m.pumpeX} y={m.schildY} zahl={kw(s?.heat_pump_power_kw.value)} einheit="kW" name={`Wärmepumpe ${wpWort(v.hp, wpLaeuft)}`} anker="middle" farbe={wpLaeuft ? "var(--heat-pump)" : undefined} leise={!an} schmal={schmal} />
          </a>
        </>
      )}

      {/* Das Haus in der Mitte, mit der Summe */}
      <Link href="/strom" aria-label={`Haus: ${kw(s?.house_power_kw.value)} kW. Details öffnen`}>
        <title>{alter(s?.house_power_kw, nowMs)}</title>
        <path d={`M${cx - dx},${G - hh} L${cx},${spitze} L${cx + dx},${G - hh} Z`} fill="var(--surface-3)" stroke="var(--line-2)" strokeWidth={1.5} strokeLinejoin="round" />
        <rect x={cx - hb} y={G - hh} width={2 * hb} height={hh} fill="var(--surface-2)" stroke="var(--line-2)" strokeWidth={1.5} />
        {platte(-1)}
        {platte(1)}
        <circle cx={cx} cy={spitze + dach * 0.6} r={8} fill={nacht ? "var(--amber-soft)" : "var(--surface-1)"} stroke="var(--line-2)" style={nacht ? { filter: "drop-shadow(0 0 9px var(--amber-soft))" } : undefined} />
        <text x={cx} y={G - hh / 2 + 9} textAnchor="middle" className="bild-zahl" fontSize={schmal ? 34 : 40} fillOpacity={frisch(s?.house_power_kw) ? 1 : 0.5}>
          {kw(s?.house_power_kw.value)}
          <tspan className="bild-einheit" fontSize={13} dx={4}>kW</tspan>
        </text>
        <text x={cx} y={G - 11} textAnchor="middle" className="bild-name" fontSize={12.5}>{grundlast(v.rest, v.hp + v.ev) ?? "braucht das Haus"}</text>
      </Link>
    </svg>
  );
}

/** Feste Sterne: derselbe Himmel bei jedem Laden, aus einem einfachen Zähler statt aus dem Zufall. */
function sternenhimmel(breite: number, hoehe: number, zahl: number): Array<{ x: number; y: number; r: number }> {
  const out: Array<{ x: number; y: number; r: number }> = [];
  let saat = 7;
  const naechste = () => (saat = (saat * 16807) % 2147483647);
  for (let i = 0; i < zahl; i++) {
    const x = ((naechste() % 1000) / 1000) * breite;
    const y = ((naechste() % 1000) / 1000) * Math.max(0, hoehe) + 6;
    const r = 0.5 + (naechste() % 100) / 100;
    out.push({ x: Math.round(x * 10) / 10, y: Math.round(y * 10) / 10, r: Math.round(r * 100) / 100 });
  }
  return out;
}
