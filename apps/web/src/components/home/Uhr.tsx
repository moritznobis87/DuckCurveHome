"use client";

import Link from "next/link";
import { useMemo } from "react";
import type { EnergySnapshot, Measurement } from "@/lib/api/models";
import { hhmm, kw } from "@/lib/format";
import { useGroesse } from "@/lib/useGroesse";
import { Icon, type IconName } from "@/components/ui/Icon";
import type { Ausblick } from "./ausblick";
import { Band } from "./Buehne";
import { FLUSS_AB_KW } from "./buehne";
import { flusswerte, frisch, grundlast, wpWort } from "./fluss";
import { preislaenge, ringmass, stunden24, stundenwinkel } from "./stundenring";

/**
 * Die Uhr: ein Ring über 24 Stunden mit 00 Uhr oben.
 *
 * Außen zeigen Speichen den Strompreis, innen leuchtet ein Bogen, wo Sonne erwartet wird, und
 * kurze Striche zeigen die geplanten Läufe der Wärmepumpe. Ein Zeiger steht auf jetzt; vom Zeiger
 * an im Uhrzeigersinn liest man den kommenden Tag. In der Mitte steht, was das Haus gerade
 * braucht. Links stehen Sonne und Netz, rechts Speicher, Wärmepumpe und Wallbox, jede Sache mit
 * einem Band zum Ring; am Telefon stehen die fünf als Liste darunter.
 *
 * Die Maße kommen aus `stundenring.ts`, dieselben wie in der App.
 */
interface Ding {
  schluessel: string;
  /** Links stehen die Quellen, rechts die Verbraucher. */
  seite: -1 | 1;
  farbe: string;
  zeichen: IconName;
  zahl: string;
  einheit: string;
  name: string;
  /** Die Leistung des Bandes; darunter ruht die Sache. */
  kwJetzt: number;
  /** Der Strom fließt zum Ring hin, nicht von ihm weg. */
  zumRing: boolean;
  an: boolean;
  messwert: Measurement | null | undefined;
  href: string;
  /** Öffnet eine Auswahl, statt auf die Seite zu führen. */
  auswahl?: boolean;
}

export function Uhr({ snapshot, nowMs, wpLaeuft, nacht, blick, sonneAb, vonEben, onPumpe }: {
  snapshot: EnergySnapshot | null;
  nowMs: number;
  wpLaeuft?: boolean;
  nacht: boolean;
  blick: Ausblick;
  /** Wann die Sonne wiederkommt, als Uhrzeit. */
  sonneAb: string | null;
  /** Die Verbindung ist unterbrochen: von wann das Bild ist. */
  vonEben: string | null;
  onPumpe: () => void;
}) {
  const [ref, groesse] = useGroesse<HTMLDivElement>();
  const s = snapshot;
  const v = useMemo(() => flusswerte(s), [s]);
  const dinge: Ding[] = [
    { schluessel: "sonne", seite: -1, farbe: "var(--pv)", zeichen: nacht ? "moon" : "sun", zahl: kw(s?.pv_power_kw.value), einheit: "kW", name: nacht && sonneAb ? `Sonne ab ${sonneAb}` : "Sonne", kwJetzt: v.pv, zumRing: true, an: v.pv >= FLUSS_AB_KW, messwert: s?.pv_power_kw, href: "/strom/pv" },
    { schluessel: "netz", seite: -1, farbe: v.einspeisung ? "var(--grid-out)" : "var(--grid-in)", zeichen: "grid", zahl: kw(v.netz), einheit: "kW", name: v.einspeisung ? "Einspeisung" : "Netzbezug", kwJetzt: v.netz, zumRing: !v.einspeisung, an: v.netz >= FLUSS_AB_KW, messwert: s?.grid_power_kw, href: "/strom" },
    { schluessel: "speicher", seite: 1, farbe: "var(--battery)", zeichen: "battery", zahl: v.soc != null ? String(Math.round(v.soc * 100)) : "-", einheit: "%", name: `Speicher ${v.speicherWort}`, kwJetzt: v.speicherWort === "hält" ? 0 : v.speicher, zumRing: v.speicherWort === "entlädt", an: v.speicherWort !== "hält", messwert: s?.battery_soc, href: "/strom/speicher" },
    { schluessel: "pumpe", seite: 1, farbe: "var(--heat-pump)", zeichen: "pump", zahl: kw(s?.heat_pump_power_kw.value), einheit: "kW", name: `Wärmepumpe ${wpWort(v.hp, wpLaeuft)}`, kwJetzt: v.hp, zumRing: false, an: !!wpLaeuft, messwert: s?.heat_pump_power_kw, href: "/waerme/waermepumpe", auswahl: true },
    { schluessel: "wallbox", seite: 1, farbe: "var(--ev)", zeichen: "car", zahl: kw(s?.ev_power_kw.value), einheit: "kW", name: `Wallbox ${v.ev >= FLUSS_AB_KW ? "lädt" : "steht"}`, kwJetzt: v.ev, zumRing: false, an: v.ev >= FLUSS_AB_KW, messwert: s?.ev_power_kw, href: "/strom/wallbox" },
  ];
  const schmal = groesse != null && groesse.breite < 520;
  const klick = (d: Ding) => (d.auswahl ? (e: React.MouseEvent) => { e.preventDefault(); onPumpe(); } : undefined);
  return (
    <div className="start-mitte">
      <div className="start-buehne start-uhrbild" data-nacht={nacht} data-gestoert={vonEben != null}>
        <div ref={ref} className="buehne-flaeche">
          {groesse && groesse.breite > 0 && groesse.hoehe > 0 ? (
            <Ring W={groesse.breite} H={groesse.hoehe} s={s} nowMs={nowMs} blick={blick} dinge={schmal ? [] : dinge} hausZeile={grundlast(v.rest, v.hp + v.ev) ?? "braucht das Haus"} klick={klick} />
          ) : null}
        </div>
        {vonEben ? <span className="start-von-eben"><Icon name="clock" size={16} />Das Bild ist von {vonEben}.</span> : null}
      </div>
      {schmal ? (
        <div className="start-karte start-dinge">
          {dinge.map((d) => (
            <Link key={d.schluessel} href={d.href} className="start-dingzeile" data-an={d.an} aria-haspopup={d.auswahl ? "dialog" : undefined} onClick={klick(d)} style={{ "--kartenfarbe": d.farbe } as React.CSSProperties}>
              <span className="konto-zeichen start-zeichen"><Icon name={d.zeichen} size={20} /></span>
              <span className="start-dingzeile-name">{d.name}</span>
              <span className="mono start-dingzeile-zahl">{d.zahl}<small>{d.einheit}</small></span>
            </Link>
          ))}
        </div>
      ) : null}
    </div>
  );
}

const LEGENDE: Array<[string, string]> = [["var(--mist)", "Strompreis"], ["var(--pv)", "Sonne erwartet"], ["var(--heat-pump)", "Wärmepumpe"]];
// Wo die Sachen neben dem Ring stehen (Anteil der Höhe) und unter welchem Winkel ihr Band ankommt.
const PLATZ: Record<string, [number, number]> = { sonne: [0.3, 202], netz: [0.7, 158], speicher: [0.2, -34], pumpe: [0.5, 0], wallbox: [0.8, 34] };

function Ring({ W, H, s, nowMs, blick, dinge, hausZeile, klick }: { W: number; H: number; s: EnergySnapshot | null; nowMs: number; blick: Ausblick; dinge: Ding[]; hausZeile: string; klick: (d: Ding) => ((e: React.MouseEvent) => void) | undefined }) {
  const m = useMemo(() => ringmass(W, H), [W, H]);
  const stunden = useMemo(() => stunden24(blick.zellen, blick.guenstig), [blick]);
  const schmal = W < 520;
  const cx = m.mitteX;
  const cy = m.mitteY;
  const R = m.radius;
  const pol = (r: number, a: number) => `${(cx + r * Math.cos(a)).toFixed(1)},${(cy + r * Math.sin(a)).toFixed(1)}`;
  const bogen = (r: number, h1: number, h2: number) => `M${pol(r, stundenwinkel(h1))} A${r},${r} 0 0 1 ${pol(r, stundenwinkel(h2))}`;
  const sonneMax = Math.max(blick.pvMax, 3);
  const [std, min] = hhmm(new Date(nowMs)).split(":").map(Number);
  const jetzt = stundenwinkel((std ?? 0) + (min ?? 0) / 60);
  const bw = 166;
  const bh = 62;
  let lx = schmal ? 14 : 22;

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width={W} height={H} role="group" aria-label="Ein Ring über 24 Stunden mit Strompreis, erwarteter Sonne und den Läufen der Wärmepumpe; in der Mitte der Verbrauch des Hauses">
      {/* Der Ring: außen der Preis als Speichen, innen die erwartete Sonne und die Wärmepumpe */}
      <circle cx={cx} cy={cy} r={R + 8} fill="var(--deep)" fillOpacity={0.42} stroke="var(--line-1)" />
      <circle cx={cx} cy={cy} r={m.sonne} fill="none" stroke="var(--paper)" strokeOpacity={0.07} strokeWidth={9} />
      {stunden.map((st) => {
        const a = stundenwinkel(st.stunde + 0.5);
        return (
          <g key={st.start}>
            {st.preis != null
              ? <path d={`M${pol(m.preis, a)} L${pol(m.preis + 6 + preislaenge(st.preis, blick.preisMax) * 34, a)}`} stroke="var(--mist)" strokeOpacity={st.tief ? 1 : 0.42} strokeWidth={schmal ? 8 : 10} strokeLinecap="round" />
              : <path d={`M${pol(m.preis, a)} L${pol(m.preis + 14, a)}`} stroke="var(--mist)" strokeOpacity={0.5} strokeWidth={2} strokeDasharray="0.1 5" strokeLinecap="round" />}
            {st.sonneKw > FLUSS_AB_KW ? <path d={bogen(m.sonne, st.stunde - 0.02, st.stunde + 1.02)} fill="none" stroke="var(--pv)" strokeOpacity={Math.min(1, 0.15 + (st.sonneKw / sonneMax) * 0.85)} strokeWidth={9} /> : null}
            {st.wp ? <path d={bogen(m.pumpe, st.stunde + 0.08, st.stunde + 0.92)} fill="none" stroke="var(--heat-pump)" strokeWidth={5} strokeLinecap="round" /> : null}
            {st.ofen ? <path d={bogen(m.pumpe - 8, st.stunde + 0.08, st.stunde + 0.92)} fill="none" stroke="var(--stove)" strokeWidth={5} strokeLinecap="round" /> : null}
          </g>
        );
      })}
      {/* 00 Uhr oben und 12 Uhr unten als Zahl; links und rechts bleibt die Mitte dem Haus. */}
      {[0, 12].map((h) => {
        const a = stundenwinkel(h);
        return <text key={h} x={cx + m.zahl * Math.cos(a)} y={cy + m.zahl * Math.sin(a) + 4} textAnchor="middle" fontSize={11} className="bild-zahl bild-einheit">{String(h).padStart(2, "0")} Uhr</text>;
      })}
      {/* Der Zeiger für jetzt */}
      <path d={`M${pol(m.pumpe - 8, jetzt)} L${pol(R + 8, jetzt)}`} stroke="var(--paper)" strokeWidth={2.5} strokeLinecap="round" />
      <circle cx={cx + (R + 8) * Math.cos(jetzt)} cy={cy + (R + 8) * Math.sin(jetzt)} r={5.5} fill="var(--paper)" style={{ filter: "drop-shadow(0 0 8px var(--paper))" }} />

      {/* Die Mitte: was das Haus gerade braucht */}
      <Link href="/strom" aria-label={`Haus: ${kw(s?.house_power_kw.value)} kW. Details öffnen`}>
        <circle cx={cx} cy={cy} r={m.zahl - 8} fill="transparent" />
        <text x={cx} y={cy + 8} textAnchor="middle" className="bild-zahl" fontSize={schmal ? 42 : 48} fillOpacity={frisch(s?.house_power_kw) ? 1 : 0.5}>
          {kw(s?.house_power_kw.value)}
          <tspan className="bild-einheit" fontSize={14} dx={4}>kW</tspan>
        </text>
        <text x={cx} y={cy + 30} textAnchor="middle" className="bild-name" fontSize={12.5}>{hausZeile}</text>
      </Link>

      {/* Die Sachen links und rechts, mit Bändern zum Ring */}
      {dinge.map((d) => {
        const [anteil, grad] = PLATZ[d.schluessel]!;
        const y = H * anteil;
        const x = d.seite < 0 ? 20 : W - 20 - bw;
        const a = (grad * Math.PI) / 180;
        const zx = cx + (R + 12) * Math.cos(a);
        const zy = cy + (R + 12) * Math.sin(a);
        const kx = d.seite < 0 ? x + bw : x;
        const mitte = (kx + zx) / 2;
        const pfad = d.zumRing ? `M${kx},${y} C${mitte},${y} ${mitte},${zy.toFixed(1)} ${zx.toFixed(1)},${zy.toFixed(1)}` : `M${zx.toFixed(1)},${zy.toFixed(1)} C${mitte},${zy.toFixed(1)} ${mitte},${y} ${kx},${y}`;
        const ton = d.an ? d.farbe : "var(--text-3)";
        return (
          <g key={d.schluessel}>
            <Band d={pfad} kwJetzt={d.kwJetzt} farbe={d.farbe} />
            <Link href={d.href} aria-label={`${d.name}: ${d.zahl} ${d.einheit}. ${d.auswahl ? "Auswahl öffnen" : "Details öffnen"}`} aria-haspopup={d.auswahl ? "dialog" : undefined} onClick={klick(d)}>
              <rect x={x} y={y - bh / 2} width={bw} height={bh} rx={15} fill={d.an ? `color-mix(in srgb, ${d.farbe} 15%, var(--surface-1))` : "var(--surface-1)"} fillOpacity={d.an ? 1 : 0.7} stroke={d.an ? `color-mix(in srgb, ${d.farbe} 50%, transparent)` : "var(--line-1)"} />
              <rect x={x + 12} y={y - 17} width={34} height={34} rx={10} fill={ton} fillOpacity={0.16} />
              <g transform={`translate(${x + 19},${y - 10})`}><Icon name={d.zeichen} size={20} color={ton} /></g>
              <text x={x + 58} y={y + 3} className="bild-zahl" fontSize={26} fillOpacity={d.an && frisch(d.messwert) ? 1 : 0.5}>
                {d.zahl}
                <tspan className="bild-einheit" fontSize={12.5} dx={4}>{d.einheit}</tspan>
              </text>
              <text x={x + 58} y={y + 20} className="bild-name" fontSize={12}>{d.name}</text>
            </Link>
          </g>
        );
      })}

      {/* Die Legende am Fuß */}
      {LEGENDE.map(([farbe, wort]) => {
        const x = lx;
        lx += 30 + wort.length * 6.3;
        return (
          <g key={wort}>
            <rect x={x} y={H - 21} width={12} height={5} rx={2.5} fill={farbe} />
            <text x={x + 18} y={H - 14} fontSize={11.5} className="bild-name">{wort}</text>
          </g>
        );
      })}
    </svg>
  );
}
