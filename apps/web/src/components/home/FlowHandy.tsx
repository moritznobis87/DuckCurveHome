"use client";

import Link from "next/link";
import { useMemo } from "react";
import type { EnergySnapshot, Measurement } from "@/lib/api/models";
import { kw } from "@/lib/format";
import { Icon } from "@/components/ui/Icon";
import { FARBE, frisch, grundlast, kante, type Key } from "./FlowHero";

/**
 * Der Energiefluss als Bild, für das Handy gezeichnet.
 *
 * **Warum doch die Zeichnung.** Am 25.10.2026 wich sie am Handy sechs Kacheln, weil sechs Knoten
 * mit Zahlen auf 390 Punkten Breite ineinanderliefen. Das lag an der Anordnung der Wandanzeige,
 * die für das Querformat gemacht ist: Netz, Haus und Speicher in einer Reihe. Die Kacheln sagten
 * die Zahlen, aber nicht mehr, was wohin fließt, und die Seite begann mit einer Tabelle.
 *
 * **Die Anordnung folgt hier dem Hochformat.** Oben, woher der Strom kommt: Sonne links, Netz
 * rechts. In der Mitte das Haus, groß, mit seiner Zahl im Kreis, damit unter ihm Platz für die
 * Leitungen bleibt. Unten, wohin er geht: Speicher, Wärmepumpe, Wallbox, je in einem Drittel der
 * Breite, die Beschriftung darunter. So kreuzt keine Leitung ein Wort, und drei Namen
 * nebeneinander haben je 119 Punkte.
 *
 * Leitungen, Farben und Schwellen sind dieselben wie in der Wandanzeige (`FlowHero`): eine Leitung
 * läuft ab 0,05 kW, ihre Dicke folgt der Leistung, die Laufrichtung der Striche ist die Richtung
 * des Stroms.
 */
const LAGE: Record<Key, { x: number; y: number }> = {
  pv: { x: 17, y: 14 },
  grid: { x: 83, y: 14 },
  house: { x: 50, y: 46 },
  bat: { x: 17, y: 78 },
  hp: { x: 50, y: 78 },
  ev: { x: 83, y: 78 },
};

const ZEICHEN: Record<Key, string> = { pv: "sun", grid: "grid", house: "home", bat: "battery", hp: "pump", ev: "car" };

function Knoten({
  k,
  href,
  wert,
  einheit,
  name,
  wort,
  m,
  seite,
  farbe,
  fuell,
}: {
  k: Key;
  href: string;
  wert: string;
  einheit: string;
  name: string;
  wort?: string;
  m: Measurement | null | undefined;
  seite: "rechts" | "links" | "unten";
  farbe?: string;
  fuell?: number | null;
}) {
  const ok = frisch(m);
  const f = ok ? (farbe ?? FARBE[k]) : "var(--text-3)";
  return (
    <Link
      href={href}
      className={`fluss-h-knoten fluss-h-${seite}`}
      style={{ left: `${LAGE[k].x}%`, top: `${LAGE[k].y}%` }}
      aria-label={`${name}: ${wert} ${einheit}${wort ? `, ${wort}` : ""}. Details öffnen`}
    >
      <span className="fluss-h-ring" style={{ borderColor: f, background: `linear-gradient(color-mix(in srgb, ${f} 16%, transparent), color-mix(in srgb, ${f} 16%, transparent)), var(--deep)` }}>
        {typeof fuell === "number" ? <span className="fluss-h-fuell" style={{ height: `${Math.round(fuell * 100)}%` }} /> : null}
        <Icon name={ZEICHEN[k]} size={24} color={f} />
      </span>
      <span className="fluss-h-text">
        <span className="mono fluss-h-zahl" style={{ color: ok ? "var(--text-1)" : "var(--text-3)" }}>
          {wert}
          <span className="fluss-h-einheit">{einheit}</span>
        </span>
        <span className="fluss-h-name">{name}</span>
        {wort ? <span className="fluss-h-wort">{wort}</span> : null}
      </span>
    </Link>
  );
}

export function FlowHandy({ snapshot, pvPeakKw }: { snapshot: EnergySnapshot | null; pvPeakKw: number }) {
  const s = snapshot;
  const v = useMemo(() => {
    const num = (m?: Measurement | null) => (frisch(m) ? (m!.value as number) : 0);
    const pv = num(s?.pv_power_kw);
    const grid = num(s?.grid_power_kw);
    const bat = num(s?.battery_power_kw);
    const house = num(s?.house_power_kw);
    return {
      pv,
      pvToHouse: Math.min(pv, house + Math.max(0, -bat)),
      exportKw: Math.max(0, -grid),
      importKw: Math.max(0, grid),
      charge: Math.max(0, -bat),
      discharge: Math.max(0, bat),
      hp: num(s?.heat_pump_power_kw),
      ev: num(s?.ev_power_kw),
      rest: frisch(s?.base_load_kw) ? (s!.base_load_kw.value as number) : null,
    };
  }, [s]);
  const einspeisung = v.exportKw >= v.importKw && v.exportKw >= 0.05;
  const laedt = v.charge >= v.discharge;
  const netzFarbe = einspeisung ? "var(--grid-out)" : "var(--grid-in)";
  const kanten = [
    kante("pv", "house", v.pvToHouse, false, "var(--pv)", LAGE),
    kante("grid", "house", einspeisung ? v.exportKw : v.importKw, einspeisung, netzFarbe, LAGE),
    kante("house", "bat", laedt ? v.charge : v.discharge, !laedt, "#7fb7c8", LAGE),
    kante("house", "hp", v.hp, false, "var(--heat-pump)", LAGE),
    kante("house", "ev", v.ev, false, "#8fc3d6", LAGE),
  ];
  const sonne = Math.max(0, Math.min(1, v.pv / Math.max(1, pvPeakKw)));
  const soc = s?.battery_soc.value ?? null;
  const hausOk = frisch(s?.house_power_kw);
  const davon = grundlast(v.rest, v.hp + v.ev);

  return (
    <div className="fluss-h" role="group" aria-label="Energiefluss zwischen Sonne, Netz, Haus, Speicher, Wärmepumpe und Wallbox">
      <div className="fluss-h-schein" aria-hidden style={{ opacity: sonne }} />
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden className="fluss-h-leitungen">
        {kanten.map((e, i) => (
          <g key={i}>
            <line x1={e.x1} y1={e.y1} x2={e.x2} y2={e.y2} stroke={e.farbe} strokeOpacity={e.an ? 0.22 : 0.14} strokeWidth={e.breite} strokeLinecap="round" vectorEffect="non-scaling-stroke" />
            {e.an ? (
              <line
                className="home-fluss-strich"
                x1={e.x1}
                y1={e.y1}
                x2={e.x2}
                y2={e.y2}
                stroke={e.farbe}
                strokeOpacity={0.95}
                strokeWidth={e.breite}
                strokeLinecap="round"
                strokeDasharray="5 12"
                vectorEffect="non-scaling-stroke"
                style={{ "--dauer": e.dauer } as React.CSSProperties}
              />
            ) : null}
          </g>
        ))}
      </svg>

      <Knoten k="pv" href="/strom/pv" wert={kw(s?.pv_power_kw.value)} einheit="kW" name="Sonne" m={s?.pv_power_kw} seite="rechts" />
      <Knoten
        k="grid"
        href="/strom"
        wert={kw(einspeisung ? v.exportKw : v.importKw)}
        einheit="kW"
        name="Netz"
        wort={einspeisung ? "Einspeisung" : v.importKw >= 0.05 ? "Bezug" : undefined}
        m={s?.grid_power_kw}
        seite="links"
        farbe={netzFarbe}
      />

      {/* Das Haus: die Zahl steht im Kreis. Unter ihm laufen drei Leitungen, da ist kein Platz für Text. */}
      <Link href="/strom" className="fluss-h-haus" style={{ left: `${LAGE.house.x}%`, top: `${LAGE.house.y}%` }} aria-label={`Haus: ${kw(s?.house_power_kw.value)} kW${davon ? `, ${davon}` : ""}. Details öffnen`}>
        <span className="fluss-h-haus-ring" style={{ borderColor: hausOk ? "var(--text-1)" : "var(--text-3)" }}>
          <Icon name="home" size={20} color={hausOk ? "var(--text-2)" : "var(--text-3)"} />
          <span className="mono fluss-h-haus-zahl" style={{ color: hausOk ? "var(--text-1)" : "var(--text-3)" }}>{kw(s?.house_power_kw.value)}</span>
          <span className="fluss-h-haus-einheit">kW</span>
        </span>
      </Link>
      {davon ? (
        <span className="fluss-h-davon" style={{ top: `${LAGE.house.y}%` }}>
          {davon}
        </span>
      ) : null}

      <Knoten
        k="bat"
        href="/strom/speicher"
        wert={soc != null ? String(Math.round(soc * 100)) : "-"}
        einheit="%"
        name="Speicher"
        wort={v.charge >= 0.05 ? `lädt ${kw(v.charge)} kW` : v.discharge >= 0.05 ? `gibt ${kw(v.discharge)} kW` : "hält"}
        m={s?.battery_soc}
        seite="unten"
        fuell={soc}
      />
      <Knoten k="hp" href="/waerme" wert={kw(s?.heat_pump_power_kw.value)} einheit="kW" name="Wärmepumpe" wort={v.hp >= 0.05 ? "läuft" : "steht"} m={s?.heat_pump_power_kw} seite="unten" />
      <Knoten k="ev" href="/strom/wallbox" wert={kw(s?.ev_power_kw.value)} einheit="kW" name="Wallbox" wort={v.ev >= 0.05 ? "lädt" : "steht"} m={s?.ev_power_kw} seite="unten" />
    </div>
  );
}
