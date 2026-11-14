"use client";

import type { Measurement, Waermepumpe } from "@/lib/api/models";
import { farbe } from "@/components/anlage/schema";
import { PufferGlas } from "@/components/puffer/Glas";
import { BLOCK, PLAN, SCHILD, TANK, type Lage, type Punkt, aufnahme, brauchbar, messwert, pfad, zahl } from "./bild";

/**
 * Die Wärmepumpe als Zeichnung: Außengerät, Innengerät, Speicher und die vier Leitungen dazwischen,
 * jeder Messwert an der Stelle, an der er entsteht.
 *
 * **Was die Zeichnung zeigt und was nicht.** Sie ist ein Funktionsbild, kein Hydraulikplan:
 * drei Kästen und vier Leitungen, damit die Zahlen einen Ort haben. Heißgas und
 * Flüssigkeitsleitung sind der Kältekreis zwischen Außen- und Innengerät, Vorlauf und Rücklauf
 * der Wasserkreis zum Speicher. Mehr behauptet sie nicht.
 *
 * **Bewegung heißt: es fließt.** Die Leitungen des Kältekreises laufen, wenn der Verdichter
 * arbeitet, die des Wasserkreises, wenn der Durchflussgeber etwas meldet. Der Lüfter dreht mit
 * dem Verdichter. Steht alles, steht auch die Zeichnung.
 *
 * **Farbe ist Temperatur**, mit derselben Skala wie das Anlagenschema. Text steht immer in den
 * Textfarben; ein Wert, der fehlt oder veraltet ist, steht blass da und als Fragezeichen.
 *
 * **Das Kreuz** hinter „Rücklauf" und „Fühler WP" heißt: Diese Zuordnung ist begründet, aber am
 * Gerät noch nicht bestätigt (docs/SENSORIK.md).
 */
const UNSICHER = "†";

function Schild({ x, y, w = SCHILD.w, h = SCHILD.h, name, wert, einheit, m, gross = false }: { x: number; y: number; w?: number; h?: number; name: string; wert: string; einheit: string; m?: Measurement | null; gross?: boolean }) {
  const da = m === undefined ? wert !== "?" : brauchbar(m);
  return (
    <g transform={`translate(${x} ${y})`} opacity={da ? 1 : 0.55}>
      <rect width={w} height={h} rx={8} fill="var(--surface-3)" stroke="var(--line-2)" />
      <text x={10} y={14} fontSize={10.5} fill="var(--text-3)">{name}</text>
      <text x={10} y={h - 8} fontSize={gross ? 19 : 15} fill="var(--text-1)" fontFamily="var(--font-mono)">
        {wert}
        <tspan dx={4} fontSize={10.5} fill="var(--text-3)" fontFamily="var(--font-sans)">{einheit}</tspan>
      </text>
    </g>
  );
}

function Leitung({ punkte, temperatur, fliesst, dick = 7, ruhig, name }: { punkte: Punkt[]; temperatur: number | null | undefined; fliesst: boolean; dick?: number; ruhig: boolean; name: string }) {
  const d = pfad(punkte);
  return (
    <g aria-label={name}>
      <path d={d} fill="none" stroke={farbe(temperatur)} strokeWidth={dick} strokeLinecap="round" strokeLinejoin="round" opacity={fliesst ? 0.95 : 0.4} />
      {fliesst && !ruhig ? <path d={d} fill="none" stroke="rgba(255,255,255,.75)" strokeWidth={Math.max(2, dick - 4)} strokeLinecap="round" strokeLinejoin="round" className="wp-fluss" /> : null}
    </g>
  );
}

function Aussengeraet({ d, ruhig }: { d: Waermepumpe; ruhig: boolean }) {
  const { w, h } = BLOCK.aussen;
  const strom = aufnahme(d);
  const dreht = d.laeuft && !ruhig;
  return (
    <g>
      <rect width={w} height={h} rx={14} fill="var(--surface-2)" stroke="var(--line-2)" />
      <text x={16} y={26} fontSize={13} fontWeight={600} fill="var(--text-1)">Außengerät</text>
      <Schild x={14} y={40} w={140} name="Außenluft" wert={messwert(d.aussen_c)} einheit="°C" m={d.aussen_c} />
      <Schild x={176} y={40} w={140} name="Sauggas" wert={messwert(d.sauggas_c)} einheit="°C" m={d.sauggas_c} />
      {/* Der Lüfter: ein Ring und drei Flügel. Er dreht, wenn der Verdichter arbeitet. */}
      <circle cx={95} cy={142} r={50} fill="var(--deep)" stroke="var(--line-2)" strokeWidth={2} />
      <g className={dreht ? "wp-dreht" : undefined} style={{ transformOrigin: "95px 142px" }}>
        {[0, 120, 240].map((winkel) => (
          <path key={winkel} d="M95 142 C 108 122, 126 112, 136 118 C 130 136, 114 146, 95 142 Z" fill={d.laeuft ? "var(--mist)" : "var(--line-2)"} opacity={0.85} transform={`rotate(${winkel} 95 142)`} />
        ))}
        <circle cx={95} cy={142} r={7} fill="var(--surface-3)" stroke="var(--line-2)" />
      </g>
      {/* Der Verdichter mit seiner Frequenz. */}
      <circle cx={246} cy={136} r={36} fill="var(--deep)" stroke={d.laeuft ? "var(--heat-pump)" : "var(--line-2)"} strokeWidth={2.5} />
      <text x={246} y={134} textAnchor="middle" fontSize={20} fill="var(--text-1)" fontFamily="var(--font-mono)" opacity={brauchbar(d.verdichter_hz) ? 1 : 0.55}>{messwert(d.verdichter_hz, 0)}</text>
      <text x={246} y={150} textAnchor="middle" fontSize={10.5} fill="var(--text-3)">Hz</text>
      <text x={246} y={190} textAnchor="middle" fontSize={10.5} fill="var(--text-3)">Verdichter</text>
      <Schild x={14} y={204} w={140} name="Verdampfer" wert={messwert(d.verdampfer_c)} einheit="°C" m={d.verdampfer_c} />
      <Schild x={176} y={204} w={140} name={strom.quelle ? `Strom, ${strom.quelle}` : "Strom"} wert={zahl(strom.kw, 2)} einheit="kW" />
    </g>
  );
}

function Innengeraet({ d, ruhig }: { d: Waermepumpe; ruhig: boolean }) {
  const { w, h } = BLOCK.innen;
  const dreht = d.pumpe_laeuft && !ruhig;
  return (
    <g>
      <rect width={w} height={h} rx={14} fill="var(--surface-2)" stroke="var(--line-2)" />
      <text x={16} y={26} fontSize={13} fontWeight={600} fill="var(--text-1)">Innengerät</text>
      {/* Die Kennzahl des Reglers. Ein Wort steht nur da, wo es im Haus bestätigt ist. */}
      <Schild x={14} y={40} w={128} name="Regler meldet" wert={d.kreis_de ?? "?"} einheit="" />
      <Schild x={150} y={40} w={136} name="Vorlauf soll" wert={messwert(d.vorlauf_soll_c)} einheit="°C" m={d.vorlauf_soll_c} />
      {/* Der Wärmetauscher: hier geht die Wärme vom Kältemittel ins Wasser. */}
      <rect x={30} y={92} width={56} height={84} rx={6} fill="var(--deep)" stroke="var(--line-2)" />
      <path d="M38 104 L78 114 L38 124 L78 134 L38 144 L78 154 L38 164" fill="none" stroke={d.laeuft ? "var(--heat-pump)" : "var(--line-2)"} strokeWidth={2.5} strokeLinejoin="round" />
      <text x={58} y={192} textAnchor="middle" fontSize={10.5} fill="var(--text-3)">Wärmetauscher</text>
      <Schild x={100} y={92} w={186} h={56} name="Wärme, abgeschätzt" wert={zahl(d.waermeleistung_kw)} einheit="kW" gross />
      {/* Die Umwälzpumpe. Sie dreht, wenn der Durchflussgeber etwas meldet. */}
      <circle cx={262} cy={176} r={16} fill="var(--deep)" stroke={d.pumpe_laeuft ? "var(--mist)" : "var(--line-2)"} strokeWidth={2} />
      <g className={dreht ? "wp-dreht" : undefined} style={{ transformOrigin: "262px 176px" }}>
        <path d="M255 168 L272 176 L255 184 Z" fill={d.pumpe_laeuft ? "var(--mist)" : "var(--line-2)"} />
      </g>
      <text x={238} y={180} textAnchor="end" fontSize={10.5} fill="var(--text-3)">Pumpe</text>
      <Schild x={100} y={204} w={186} name="Durchfluss" wert={messwert(d.durchfluss_l_min)} einheit="l/min" m={d.durchfluss_l_min} />
    </g>
  );
}

function Speicher({ d, ruhig }: { d: Waermepumpe; ruhig: boolean }) {
  const fuehler = d.puffer_c ?? [];
  return (
    <g>
      {/* Rechts von der Mitte: in der Mitte kommt in beiden Lagen der Vorlauf von oben an. */}
      <text x={TANK.x + TANK.w / 2 + 14} y={26} fontSize={13} fontWeight={600} fill="var(--text-1)">Speicher</text>
      <Schild x={0} y={0} w={98} name={`Fühler WP ${UNSICHER}`} wert={messwert(d.speicherfuehler_c)} einheit="°C" m={d.speicherfuehler_c} />
      {/* Der Speicher sieht überall gleich aus: das Glas mit den vier Fühlern auf ihrer Höhe. */}
      <PufferGlas temps={fuehler.map((m) => m?.value)} x={TANK.x} y={TANK.y} breite={TANK.w} hoehe={TANK.h} werte="links" schrift={13} ruhig={ruhig} gedimmt={fuehler.length > 0 && !fuehler.every((m) => brauchbar(m))} />
    </g>
  );
}

export function Bild({ d, lage, ruhig }: { d: Waermepumpe; lage: Lage; ruhig: boolean }) {
  const p = PLAN[lage];
  const kaelte = d.laeuft;
  const wasser = d.pumpe_laeuft;
  const tiefer = d.einspeisung === "tiefer";
  return (
    <svg className="wp-bild" data-lage={lage} viewBox={p.viewBox} role="img" aria-label={`Die Wärmepumpe ${d.zustand_de}. Vorlauf ${messwert(d.vorlauf_c)} Grad, Rücklauf ${messwert(d.ruecklauf_c)} Grad, Durchfluss ${messwert(d.durchfluss_l_min)} Liter je Minute.`}>
      {/* Erst die Leitungen, dann die Kästen: die Enden verschwinden unter den Rändern. */}
      <Leitung punkte={p.heissgas} temperatur={d.heissgas_c.value} fliesst={kaelte} dick={5} ruhig={ruhig} name="Heißgas vom Außengerät zum Innengerät" />
      <Leitung punkte={p.fluessig} temperatur={d.fluessig_c.value} fliesst={kaelte} dick={5} ruhig={ruhig} name="Flüssigkeitsleitung zurück zum Außengerät" />
      {/* Wohin der Vorlauf führt, sagt die Betriebsart des Reglers: bei Warmwasser oben in den
          Speicher, im Heizbetrieb tiefer. Ohne Auskunft bleibt die Leitung oben, wie gezeichnet. */}
      <Leitung punkte={tiefer ? p.vorlaufTiefer : p.vorlauf} temperatur={d.vorlauf_c.value} fliesst={wasser} ruhig={ruhig} name={tiefer ? "Vorlauf, speist auf halber Höhe in den Speicher" : "Vorlauf zum Speicher"} />
      <Leitung punkte={p.ruecklauf} temperatur={d.ruecklauf_c.value} fliesst={wasser} ruhig={ruhig} name="Rücklauf vom Speicher" />
      <g transform={`translate(${p.aussen[0]} ${p.aussen[1]})`}><Aussengeraet d={d} ruhig={ruhig} /></g>
      <g transform={`translate(${p.innen[0]} ${p.innen[1]})`}><Innengeraet d={d} ruhig={ruhig} /></g>
      <g transform={`translate(${p.speicher[0]} ${p.speicher[1]})`}><Speicher d={d} ruhig={ruhig} /></g>
      <Schild x={p.schild.heissgas[0]} y={p.schild.heissgas[1]} name="Heißgas" wert={messwert(d.heissgas_c)} einheit="°C" m={d.heissgas_c} />
      <Schild x={p.schild.fluessig[0]} y={p.schild.fluessig[1]} name="Flüssigkeit" wert={messwert(d.fluessig_c)} einheit="°C" m={d.fluessig_c} />
      <Schild x={p.schild.vorlauf[0]} y={p.schild.vorlauf[1]} name="Vorlauf" wert={messwert(d.vorlauf_c)} einheit="°C" m={d.vorlauf_c} />
      <Schild x={p.schild.ruecklauf[0]} y={p.schild.ruecklauf[1]} name={`Rücklauf ${UNSICHER}`} wert={messwert(d.ruecklauf_c)} einheit="°C" m={d.ruecklauf_c} />
    </svg>
  );
}
