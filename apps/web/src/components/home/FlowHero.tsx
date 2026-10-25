"use client";

import Link from "next/link";
import { useMemo } from "react";
import type { EnergySnapshot, Measurement } from "@/lib/api/models";
import { ageLabel, kw } from "@/lib/format";
import { Icon } from "@/components/ui/Icon";

/**
 * Der Energiefluss als Bild der Startseite.
 *
 * **Die Kreise sind die Ziele.** Jede Leitung laeuft von Kreismitte zu Kreismitte; der Kreis
 * liegt ueber dem SVG und deckt ihr Ende ab, die Beschriftung steht auf der Seite, von der keine
 * Leitung kommt. So endet kein Strich zwischen Zahl und Zeichen und keiner kreuzt ein Wort.
 *
 * **Knoten sind Text, Leitungen sind Striche.** Vorher war alles ein SVG, und die Zahlen
 * skalierten mit der Karte: je groesser der Bildschirm, desto groesser die Schrift, bis sie
 * hinter die Nachbarkreise lief. Jetzt stehen die Knoten als gewoehnliche Elemente an festen
 * Prozentpositionen, die Schrift folgt der Breite in Grenzen (`clamp`), und nur die Leitungen
 * dahinter sind ein SVG, das die Flaeche fuellt. Der Strich skaliert nicht mit
 * (`vector-effect`), er bleibt so dick, wie die Leistung ihn macht.
 *
 * **Der Sonnenschein ist ein Messwert.** Der Lichtschein hinter der Sonne hat die Staerke der
 * PV-Leistung. An einem grauen Tag ist er fast aus; das ist kein Schmuck, sondern die Auskunft.
 */
type Key = "pv" | "grid" | "house" | "bat" | "hp" | "ev";

const POS: Record<Key, { x: number; y: number }> = {
  pv: { x: 50, y: 13 },
  grid: { x: 11, y: 48 },
  house: { x: 50, y: 48 },
  bat: { x: 89, y: 48 },
  hp: { x: 20, y: 78 },
  ev: { x: 80, y: 78 },
};

const FARBE: Record<Key, string> = {
  pv: "var(--pv)",
  grid: "var(--grid-in)",
  house: "var(--text-1)",
  bat: "#9fd0df",
  hp: "var(--heat-pump)",
  ev: "#8fc3d6",
};

function kante(a: Key, b: Key, kwValue: number, umkehren: boolean, farbe: string) {
  const an = kwValue >= 0.05;
  const breite = an ? Math.min(6, 2.2 + kwValue * 0.6) : 2;
  const dauer = kwValue > 3 ? "1.4s" : kwValue > 0.8 ? "2.2s" : "3.4s";
  const p = umkehren ? [POS[b], POS[a]] : [POS[a], POS[b]];
  return { x1: p[0]!.x, y1: p[0]!.y, x2: p[1]!.x, y2: p[1]!.y, an, breite, dauer, farbe };
}

function frisch(m: Measurement | null | undefined): boolean {
  return !!m && m.value !== null && (m.quality === "ok" || m.quality === "derived");
}

/**
 * Ein Knoten: der Kreis sitzt genau auf dem Ankerpunkt, auf den die Leitungen zielen, und deckt
 * ihre Enden ab. Der Text haengt an der Seite, von der keine Leitung kommt: bei der Sonne rechts
 * (die Leitung geht nach unten), sonst unten (die Leitungen kommen von der Seite oder von oben).
 * Die Leitungen vom Haus zu Waermepumpe und Wallbox laufen flach genug, dass sie am Text unter
 * dem Haus vorbeigehen; die Positionen oben sind darauf abgestimmt.
 */
const SEITE: Record<Key, "unten" | "rechts"> = { pv: "rechts", grid: "unten", house: "unten", bat: "unten", hp: "unten", ev: "unten" };

function Knoten({ k, href, value, unit, label, sub, m, nowMs, gross = false, fuell }: { k: Key; href: string; value: string; unit: string; label: string; sub?: string; m: Measurement | null | undefined; nowMs: number; gross?: boolean; fuell?: number | null }) {
  const pos = POS[k];
  const ok = frisch(m);
  const age = m ? ageLabel(m.observed_at, nowMs) : null;
  const farbe = ok ? FARBE[k] : "var(--text-3)";
  return (
    <Link
      href={href}
      className={`home-knoten home-knoten-${SEITE[k]} ${gross ? "home-knoten-gross" : ""}`}
      style={{ left: `${pos.x}%`, top: `${pos.y}%` }}
      aria-label={`${label}: ${value} ${unit}${sub ? `, ${sub}` : ""}. Details oeffnen`}
      title={age ? `Stand ${age}` : undefined}
    >
      <span className="home-ring" style={{ borderColor: farbe, background: `linear-gradient(color-mix(in srgb, ${farbe} 14%, transparent), color-mix(in srgb, ${farbe} 14%, transparent)), var(--petrol)` }}>
        {typeof fuell === "number" ? <span className="home-fuell" style={{ height: `${Math.round(fuell * 100)}%` }} /> : null}
        <Icon name={k === "pv" ? "sun" : k === "grid" ? "grid" : k === "house" ? "home" : k === "bat" ? "battery" : k === "hp" ? "pump" : "car"} size={gross ? 44 : 26} color={farbe} />
      </span>
      <span className="home-knoten-text">
        <span className="mono home-zahl" style={{ color: ok ? "var(--text-1)" : "var(--text-3)" }}>
          {value} <span className="home-einheit">{unit}</span>
        </span>
        <span className="home-wort">
          {label}
          {sub ? ` · ${sub}` : ""}
          {!ok && age ? ` · ${age}` : ""}
        </span>
      </span>
    </Link>
  );
}

export function FlowHero({ snapshot, nowMs, pvPeakKw }: { snapshot: EnergySnapshot | null; nowMs: number; pvPeakKw: number }) {
  const s = snapshot;
  const v = useMemo(() => {
    const num = (m?: Measurement | null) => (frisch(m) ? (m!.value as number) : 0);
    const pv = num(s?.pv_power_kw);
    const grid = num(s?.grid_power_kw);
    const bat = num(s?.battery_power_kw);
    const hp = num(s?.heat_pump_power_kw);
    const ev = num(s?.ev_power_kw);
    const house = num(s?.house_power_kw);
    return {
      pv,
      pvToHouse: Math.min(pv, house + Math.max(0, -bat)),
      exportKw: Math.max(0, -grid),
      importKw: Math.max(0, grid),
      charge: Math.max(0, -bat),
      discharge: Math.max(0, bat),
      hp,
      ev,
      house,
    };
  }, [s]);
  const einspeisung = v.exportKw >= v.importKw;
  const laedt = v.charge >= v.discharge;
  const kanten = [
    kante("pv", "house", v.pvToHouse, false, "var(--pv)"),
    kante("grid", "house", einspeisung ? v.exportKw : v.importKw, einspeisung, einspeisung ? "var(--grid-out)" : "var(--grid-in)"),
    kante("house", "bat", laedt ? v.charge : v.discharge, !laedt, "#7fb7c8"),
    kante("house", "hp", v.hp, false, "var(--heat-pump)"),
    kante("house", "ev", v.ev, false, "#8fc3d6"),
  ];
  const sonne = Math.max(0, Math.min(1, v.pv / Math.max(1, pvPeakKw)));
  const soc = s?.battery_soc.value ?? null;

  return (
    <div className="home-fluss" role="group" aria-label="Energiefluss zwischen Sonne, Netz, Haus, Speicher, Waermepumpe und Wallbox">
      <div className="home-sonnenschein" aria-hidden style={{ opacity: sonne }} />
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden className="home-leitungen">
        {kanten.map((e, i) => (
          <g key={i}>
            <line x1={e.x1} y1={e.y1} x2={e.x2} y2={e.y2} stroke={e.farbe} strokeOpacity={0.18} strokeWidth={e.breite} strokeLinecap="round" vectorEffect="non-scaling-stroke" />
            {e.an ? <line className="home-fluss-strich" x1={e.x1} y1={e.y1} x2={e.x2} y2={e.y2} stroke={e.farbe} strokeOpacity={0.95} strokeWidth={e.breite} strokeLinecap="round" strokeDasharray="5 12" vectorEffect="non-scaling-stroke" style={{ "--dauer": e.dauer } as React.CSSProperties} /> : null}
          </g>
        ))}
      </svg>
      <Knoten k="pv" href="/strom/pv" value={kw(s?.pv_power_kw.value)} unit="kW" label="Sonne" m={s?.pv_power_kw} nowMs={nowMs} />
      <Knoten k="grid" href="/strom" value={kw(einspeisung ? v.exportKw : v.importKw)} unit="kW" label="Netz" sub={einspeisung && v.exportKw >= 0.05 ? "Einspeisung" : v.importKw >= 0.05 ? "Bezug" : undefined} m={s?.grid_power_kw} nowMs={nowMs} />
      <Knoten k="house" href="/strom" value={kw(s?.house_power_kw.value)} unit="kW" label="Haus" m={s?.house_power_kw} nowMs={nowMs} gross />
      <Knoten k="bat" href="/strom/speicher" value={soc != null ? String(Math.round(soc * 100)) : "-"} unit="%" label="Speicher" sub={v.charge >= 0.05 ? `lädt ${kw(v.charge)} kW` : v.discharge >= 0.05 ? `gibt ${kw(v.discharge)} kW` : undefined} m={s?.battery_soc} nowMs={nowMs} fuell={soc} />
      <Knoten k="hp" href="/waerme" value={kw(s?.heat_pump_power_kw.value)} unit="kW" label="Wärmepumpe" sub={v.hp >= 0.05 ? "läuft" : undefined} m={s?.heat_pump_power_kw} nowMs={nowMs} />
      <Knoten k="ev" href="/strom/wallbox" value={kw(s?.ev_power_kw.value)} unit="kW" label="Wallbox" sub={v.ev >= 0.05 ? "lädt" : undefined} m={s?.ev_power_kw} nowMs={nowMs} />
    </div>
  );
}

/**
 * Das Jetzt auf dem Telefon: zwei grosse Zahlen und vier Kacheln.
 *
 * **Warum nicht die Zeichnung.** Auf 390 Punkten Breite ueberlappen sechs Knoten mit Zahlen; die
 * Geometrie geht, die Zahlen bleiben.
 *
 * **Warum nicht die Liste von vorher.** Sechs gleich hohe Zeilen mit Balken sahen aus wie eine
 * Tabelle und fuellten den halben Bildschirm, bevor die Tageskurve ueberhaupt anfing (gesehen am
 * 25.10.2026 auf dem iPhone). Jetzt fuehren die beiden Zahlen, um die es geht - was die Sonne
 * gibt und was das Haus nimmt -, und der Rest steht als kompaktes Raster darunter. Was dazu
 * gehoert, steht beieinander: Die Farbe des Netzes sagt, in welche Richtung es fliesst.
 */
export function FlowList({ snapshot }: { snapshot: EnergySnapshot | null }) {
  const s = snapshot;
  const soc = s?.battery_soc.value ?? null;
  const num = (m?: Measurement | null) => (frisch(m) ? (m!.value as number) : 0);
  const grid = num(s?.grid_power_kw);
  const bat = num(s?.battery_power_kw);
  const einspeisung = grid < -0.05;

  const Gross = ({ k, href, wert, wort }: { k: Key; href: string; wert: string; wort: string }) => (
    <Link href={href} className="home-jetzt-gross">
      <span className="home-jetzt-kopf">
        <Icon name={k === "pv" ? "sun" : "home"} size={16} color={FARBE[k]} />
        <span>{wort}</span>
      </span>
      <span className="mono home-jetzt-zahl" style={{ color: k === "pv" ? FARBE.pv : "var(--text-1)" }}>
        {wert} <span className="home-einheit">kW</span>
      </span>
    </Link>
  );

  const Klein = ({ k, href, wert, einheit, name, wort, farbe }: { k: Key; href: string; wert: string; einheit: string; name: string; wort: string; farbe?: string }) => (
    <Link href={href} className="home-jetzt-klein">
      <span className="home-jetzt-kopf">
        <Icon name={k === "grid" ? "grid" : k === "bat" ? "battery" : k === "hp" ? "pump" : "car"} size={15} color={farbe ?? FARBE[k]} />
        <span>{name}</span>
      </span>
      <span className="mono home-jetzt-klein-zahl">
        {wert} <span className="home-einheit">{einheit}</span>
      </span>
      <span className="home-jetzt-wort">{wort}</span>
    </Link>
  );

  return (
    <div className="home-jetzt">
      <div className="home-jetzt-reihe">
        <Gross k="pv" href="/strom/pv" wert={kw(s?.pv_power_kw.value)} wort="Sonne" />
        <Gross k="house" href="/strom" wert={kw(s?.house_power_kw.value)} wort="Haus" />
      </div>
      <div className="home-jetzt-raster">
        <Klein
          k="grid"
          href="/strom"
          wert={kw(Math.abs(grid))}
          einheit="kW"
          name="Netz"
          wort={einspeisung ? "Einspeisung" : grid > 0.05 ? "Bezug" : "nichts"}
          farbe={einspeisung ? "var(--grid-out)" : "var(--grid-in)"}
        />
        <Klein
          k="bat"
          href="/strom/speicher"
          wert={soc != null ? String(Math.round(soc * 100)) : "-"}
          einheit="%"
          name="Speicher"
          wort={bat < -0.05 ? `lädt ${kw(-bat)} kW` : bat > 0.05 ? `gibt ${kw(bat)} kW` : "hält"}
        />
        <Klein
          k="hp"
          href="/waerme"
          wert={kw(s?.heat_pump_power_kw.value)}
          einheit="kW"
          name="Wärmepumpe"
          wort={num(s?.heat_pump_power_kw) >= 0.05 ? "läuft" : "steht"}
        />
        <Klein
          k="ev"
          href="/strom/wallbox"
          wert={kw(s?.ev_power_kw.value)}
          einheit="kW"
          name="Wallbox"
          wort={num(s?.ev_power_kw) >= 0.05 ? "lädt" : "steht"}
        />
      </div>
    </div>
  );
}
