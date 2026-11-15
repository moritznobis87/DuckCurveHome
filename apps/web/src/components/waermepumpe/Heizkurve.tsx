"use client";

import { useRef, useState } from "react";
import type { ReglerEinstellung } from "@/lib/api/models";
import { type Entwurf, KURVE, type Kurve, bedienbar, kurveAus, kurvenPunkte, raster, sichtbar, steilheitDurch, verschiebungDurch, vorlauf, zahlText } from "./regler";

/**
 * Die Heizkurve zum Anfassen: Vorlauf über der Außentemperatur, mit vier Griffen.
 *
 * - Der runde Griff links (bei −10 °C) dreht die Kurve: das ist die Steilheit.
 * - Der eckige Griff rechts (bei 18 °C) hebt und senkt sie als Ganzes: die Verschiebung.
 * - Die beiden Linien oben und unten sind der größte und der kleinste Vorlauf; ihr Griff sitzt
 *   am rechten Rand.
 *
 * Gezeichnet wird die Näherung aus `regler.ts`. Hell und dick ist der Entwurf, dünn und
 * gestrichelt, was am Regler gerade steht, und die Punkte sind die Stunden, in denen der Regler
 * wirklich einen Vorlauf verlangt hat (von der Seite „Betrieb“). Ein Griff, dessen Einstellung
 * sich nicht stellen lässt, ist blass und bewegt sich nicht.
 */
const B = 760;
const H = 360;
const RAND = { l: 46, r: 22, o: 16, u: 40 };
const X = { von: -15, bis: 22 };
const Y = { von: 15, bis: 65 };
const GRIFF_STEIL = -10;
const GRIFF_VERSCH = 18;

const px = (t: number) => RAND.l + ((t - X.von) / (X.bis - X.von)) * (B - RAND.l - RAND.r);
const py = (v: number) => RAND.o + ((Y.bis - v) / (Y.bis - Y.von)) * (H - RAND.o - RAND.u);
const klemme = (v: number) => Math.min(Y.bis, Math.max(Y.von, v));
const linie = (punkte: [number, number][]) => punkte.map(([t, v], i) => `${i ? "L" : "M"}${px(t).toFixed(1)} ${py(klemme(v)).toFixed(1)}`).join(" ");

type Griff = "steilheit" | "verschiebung" | "min" | "max";
export type Stunde = { aussen_c: number; soll_c: number };

export function Heizkurve({ werte, entwurf, setze, stellenMoeglich, stunden }: { werte: ReglerEinstellung[]; entwurf: Entwurf; setze: (key: string, wert: number) => void; stellenMoeglich: boolean; stunden: Stunde[] }) {
  const svg = useRef<SVGSVGElement>(null);
  const [zieht, setZieht] = useState<Griff | null>(null);
  const ist = kurveAus(werte);
  const soll = kurveAus(werte, entwurf);
  if (!ist || !soll) {
    return <p className="m-0 kl-klein">Für die Kurve fehlt eine der fünf Einstellungen: Steilheit, Verschiebung, Raumtemperatur Tag, kleinster oder größter Vorlauf.</p>;
  }
  const w = (griff: Griff) => werte.find((x) => x.schluessel === KURVE[griff])!;
  const frei = (griff: Griff) => bedienbar(w(griff), stellenMoeglich);
  const geaendert = (Object.keys(KURVE) as (keyof typeof KURVE)[]).some((g) => entwurf[KURVE[g]] != null && entwurf[KURVE[g]] !== sichtbar(werte.find((x) => x.schluessel === KURVE[g])!, {}));

  // Vom Zeiger zur Vorlauftemperatur: die Zeichnung streckt sich mit der Breite, also über das
  // Rechteck des Bildes umrechnen und nicht über Bildpunkte.
  const vorlaufAm = (clientY: number): number => {
    const r = svg.current?.getBoundingClientRect();
    if (!r) return soll.min;
    const y = ((clientY - r.top) / r.height) * H;
    return klemme(Y.bis - ((y - RAND.o) / (H - RAND.o - RAND.u)) * (Y.bis - Y.von));
  };
  const stelle = (griff: Griff, k: Kurve, ziel: number) => {
    const e = w(griff);
    if (griff === "steilheit") setze(e.schluessel, raster(e, steilheitDurch(k, GRIFF_STEIL, ziel)));
    else if (griff === "verschiebung") setze(e.schluessel, raster(e, verschiebungDurch(k, GRIFF_VERSCH, ziel)));
    else setze(e.schluessel, raster(e, ziel));
  };
  const griffProps = (griff: Griff, name: string) => {
    const e = w(griff);
    const wert = sichtbar(e, entwurf) ?? 0;
    const an = frei(griff);
    return {
      role: "slider" as const,
      tabIndex: an ? 0 : -1,
      "aria-label": name,
      "aria-valuemin": e.von ?? undefined,
      "aria-valuemax": e.bis ?? undefined,
      "aria-valuenow": wert,
      "aria-valuetext": zahlText(e, wert),
      "aria-disabled": !an,
      "data-frei": an,
      "data-zieht": zieht === griff,
      className: "rg-griff",
      onPointerDown: (ev: React.PointerEvent<SVGGElement>) => {
        if (!an) return;
        ev.currentTarget.setPointerCapture(ev.pointerId);
        setZieht(griff);
      },
      onPointerMove: (ev: React.PointerEvent<SVGGElement>) => {
        if (zieht === griff) stelle(griff, soll, vorlaufAm(ev.clientY));
      },
      onPointerUp: () => setZieht(null),
      onPointerCancel: () => setZieht(null),
      onKeyDown: (ev: React.KeyboardEvent<SVGGElement>) => {
        if (!an) return;
        const hoch = ev.key === "ArrowUp" || ev.key === "ArrowRight";
        const runter = ev.key === "ArrowDown" || ev.key === "ArrowLeft";
        if (!hoch && !runter) return;
        ev.preventDefault();
        setze(e.schluessel, raster(e, wert + (hoch ? 1 : -1) * (e.schritt ?? 1)));
      },
    };
  };

  const steilX = px(GRIFF_STEIL);
  const steilY = py(klemme(vorlauf(soll, GRIFF_STEIL)));
  const verschX = px(GRIFF_VERSCH);
  const verschY = py(klemme(vorlauf(soll, GRIFF_VERSCH)));
  const rechts = B - RAND.r;

  return (
    <div className="rg-kurve">
      <svg ref={svg} viewBox={`0 0 ${B} ${H}`} role="group" aria-label="Heizkurve: Vorlauf über der Außentemperatur" data-zieht={zieht != null}>
        {/* Raster und Achsen */}
        {[20, 30, 40, 50, 60].map((v) => (
          <g key={v}>
            <line x1={RAND.l} x2={rechts} y1={py(v)} y2={py(v)} className="rg-raster" />
            <text x={RAND.l - 8} y={py(v) + 4} textAnchor="end" className="rg-achse">{v}</text>
          </g>
        ))}
        {[-15, -10, -5, 0, 5, 10, 15, 20].map((t) => (
          <g key={t}>
            <line x1={px(t)} x2={px(t)} y1={RAND.o} y2={H - RAND.u} className="rg-raster" />
            <text x={px(t)} y={H - RAND.u + 16} textAnchor="middle" className="rg-achse">{t}</text>
          </g>
        ))}
        <text x={(RAND.l + rechts) / 2} y={H - 6} textAnchor="middle" className="rg-achse">Außentemperatur °C</text>
        <text x={12} y={RAND.o + 8} className="rg-achse">Vorlauf °C</text>

        {/* Was außerhalb des kleinsten und größten Vorlaufs liegt, ist abgedunkelt. */}
        <rect x={RAND.l} y={RAND.o} width={rechts - RAND.l} height={Math.max(0, py(soll.max) - RAND.o)} className="rg-aussen" />
        <rect x={RAND.l} y={py(soll.min)} width={rechts - RAND.l} height={Math.max(0, H - RAND.u - py(soll.min))} className="rg-aussen" />

        {/* Was der Regler wirklich verlangt hat. */}
        {stunden.map((s, i) => (s.aussen_c >= X.von && s.aussen_c <= X.bis ? <circle key={i} cx={px(s.aussen_c)} cy={py(klemme(s.soll_c))} r={2.6} className="rg-gemessen" /> : null))}

        {/* Was am Regler steht, sobald der Entwurf davon abweicht. */}
        {geaendert ? <path d={linie(kurvenPunkte(ist, X.von, X.bis))} className="rg-ist-linie" /> : null}
        <path d={linie(kurvenPunkte(soll, X.von, X.bis))} className="rg-soll-linie" data-geaendert={geaendert} />

        {/* Größter und kleinster Vorlauf mit ihrem Griff am rechten Rand. */}
        {(["max", "min"] as const).map((g) => {
          const v = g === "max" ? soll.max : soll.min;
          return (
            <g key={g} {...griffProps(g, g === "max" ? "Vorlauf höchstens" : "Vorlauf mindestens")}>
              <line x1={RAND.l} x2={rechts} y1={py(v)} y2={py(v)} className="rg-grenze" />
              <rect x={rechts - 54} y={py(v) - 10} width={54} height={20} rx={6} className="rg-griff-flaeche" />
              <text x={rechts - 27} y={py(v) + 4} textAnchor="middle" className="rg-griff-text">{g === "max" ? "max" : "min"} {v.toFixed(0)}°</text>
            </g>
          );
        })}

        {/* Steilheit: der runde Griff, links, wo sie am meisten bewirkt. */}
        <g {...griffProps("steilheit", "Steilheit der Heizkurve")}>
          <circle cx={steilX} cy={steilY} r={22} fill="transparent" />
          <circle cx={steilX} cy={steilY} r={11} className="rg-griff-flaeche" />
          <path d={`M${steilX - 4} ${steilY + 3} L${steilX} ${steilY - 4} L${steilX + 4} ${steilY + 3}`} className="rg-griff-zeichen" />
        </g>
        <text x={steilX + 18} y={steilY - 12} className="rg-beschriftung">Steilheit {zahlText(w("steilheit"), soll.steilheit)}</text>

        {/* Verschiebung: der eckige Griff, rechts, nahe am Drehpunkt. */}
        <g {...griffProps("verschiebung", "Verschiebung der Heizkurve")}>
          <rect x={verschX - 22} y={verschY - 22} width={44} height={44} fill="transparent" />
          <rect x={verschX - 10} y={verschY - 10} width={20} height={20} rx={5} className="rg-griff-flaeche" />
          <path d={`M${verschX} ${verschY - 5} V${verschY + 5} M${verschX - 3} ${verschY - 2} L${verschX} ${verschY - 5} L${verschX + 3} ${verschY - 2} M${verschX - 3} ${verschY + 2} L${verschX} ${verschY + 5} L${verschX + 3} ${verschY + 2}`} className="rg-griff-zeichen" />
        </g>
        <text x={verschX - 16} y={verschY - 16} textAnchor="end" className="rg-beschriftung">Verschiebung {zahlText(w("verschiebung"), soll.verschiebung)}</text>
      </svg>
      <div className="rg-kurve-fuss">
        <span><i className="rg-legende rg-legende-soll" />{geaendert ? "Entwurf" : "eingestellt"}</span>
        {geaendert ? <span><i className="rg-legende rg-legende-ist" />am Regler</span> : null}
        {stunden.length ? <span><i className="rg-legende rg-legende-gemessen" />vom Regler verlangt, je Stunde</span> : null}
        <span className="rg-kurve-werte mono">
          bei −10 °C {vorlauf(soll, -10).toFixed(1).replace(".", ",")} °C · bei 0 °C {vorlauf(soll, 0).toFixed(1).replace(".", ",")} °C · bei 10 °C {vorlauf(soll, 10).toFixed(1).replace(".", ",")} °C
        </span>
      </div>
    </div>
  );
}
