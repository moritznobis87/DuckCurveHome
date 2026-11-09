"use client";

import { memo, useCallback, useMemo, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent } from "react";
import { C } from "@/components/charts/palette";
import type { AnlageReplay } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { anteil, anteilAus, indexBei, laeufe, punkt, ringstueck, stufe, type Lauf } from "./tagesuhr";

/**
 * Die Tagesuhr: ein Ortstag als Ring, Mitternacht oben, im Uhrzeigersinn.
 *
 * **Wozu ein Kreis, wenn darunter schon ein Band liegt.** Die beiden beantworten verschiedene
 * Fragen. Das Band ist zum Ablesen da: wie viel Kilowatt, wie viele Cent, auf einer Achse mit
 * Zahlen. Die Uhr ist zum Zurechtfinden da: wo im Tag stehe ich, was lief da gerade, und was war
 * davor und danach. Ein Tag *ist* ein Kreis, und auf einer Uhr findet das Auge „kurz nach dem
 * Frühstück" ohne Achsenbeschriftung. Größen vergleicht man auf ihr schlecht - ein Ringstück außen
 * ist länger als dasselbe innen -, und deshalb stehen hier keine Größen, die man vergleichen
 * müsste: die beiden Stärkeringe kennen fünf Helligkeitsstufen, die übrigen nur an und aus.
 *
 * **Die Ringe, von außen nach innen**, in der Reihenfolge der Ursachen: der Preis, der den Plan
 * treibt; die Sonne, die ihn auch treibt; die Absicht des Fahrplans; und was die Wärmepumpe
 * wirklich tat. Absicht und Ausführung liegen unmittelbar aneinander, damit ihr Auseinanderfallen
 * ohne Suchen auffällt. Der Ofen bekommt den innersten Ring, wenn es ihn gibt.
 *
 * **Drei Zustände je Stelle, nicht zwei.** Farbe heißt „ja", die blasse Spur heißt „gemessen,
 * aber nein", und gar nichts heißt „keine Messung". Eine Lücke in der Erfassung bleibt ein Loch im
 * Ring. Dasselbe gilt für die Absicht: ohne aufbewahrten Fahrplan fehlt die Spur ganz, statt ein
 * Nein vorzutäuschen.
 *
 * **Die Uhr ist ein Griff.** Anfassen und drehen fährt durch den Tag; die Mitte zeigt beim
 * Überfahren die Zeit unter dem Zeiger. Für Tastatur und Vorleseprogramme bleibt der Schieber in
 * der Leiste das Bedienelement - ein Kreis, auf dem man zielen muss, ist keines.
 */

const GROESSE = 360;
const M = GROESSE / 2;
const STUNDE = 3_600_000;

/** Die Ringe. Zwischen je zweien bleiben drei Punkte frei: Flächen stoßen nicht aneinander. */
const R = {
  preis: [144, 158],
  sonne: [126, 141],
  geplant: [114, 123],
  gelaufen: [98, 111],
  ofen: [84, 95],
} as const;

/** Fünf Helligkeiten für die beiden Stärkeringe, von kaum bis voll. */
const STUFEN = [0.16, 0.32, 0.52, 0.76, 1] as const;
const SPUR = "rgba(255,255,255,.055)";

type Ringe = {
  von: number;
  bis: number;
  zeiten: number[];
  spur: Lauf<true>[];
  preis: Lauf<number>[];
  sonne: Lauf<number>[];
  geplant: Lauf<boolean>[];
  hatAbsicht: boolean;
  gelaufen: Lauf<boolean>[];
  ofen: Lauf<boolean>[];
  hatOfen: boolean;
  preisSpanne: [number, number] | null;
  sonneMax: number;
};

function ringeAus(d: AnlageReplay): Ringe {
  const von = new Date(d.von).getTime();
  const bis = new Date(d.bis).getTime();
  const schritt = d.step_min * 60_000;
  const zeiten = d.frames.map((f) => new Date(f.at).getTime());
  const preise = (d.preis_ct_kwh ?? []).filter((p): p is number => p != null);
  const preisSpanne: [number, number] | null = preise.length ? [Math.min(...preise), Math.max(...preise)] : null;
  const sonneMax = Math.max(0, ...d.frames.map((f) => f.strom.pv_kw ?? 0));
  const geplant = d.geplant_wp ?? [];
  return {
    von,
    bis,
    zeiten,
    spur: laeufe(
      d.frames.map(() => true as const),
      zeiten,
      schritt,
    ),
    preis: laeufe(
      d.frames.map((_, i) => {
        const p = d.preis_ct_kwh?.[i];
        return p == null || !preisSpanne ? null : stufe(p, preisSpanne[0], preisSpanne[1], STUFEN.length);
      }),
      zeiten,
      schritt,
    ),
    sonne: laeufe(
      d.frames.map((f) => {
        const kw = f.strom.pv_kw;
        return kw == null || kw <= 0.05 || sonneMax <= 0 ? null : stufe(kw, 0, sonneMax, STUFEN.length);
      }),
      zeiten,
      schritt,
    ),
    geplant: laeufe(
      d.frames.map((_, i) => geplant[i] ?? null),
      zeiten,
      schritt,
    ),
    hatAbsicht: geplant.some((g) => g != null),
    gelaufen: laeufe(
      d.frames.map((f) => f.waermepumpe.running),
      zeiten,
      schritt,
    ),
    ofen: laeufe(
      d.frames.map((f) => (f.ofen.present ? f.ofen.running : null)),
      zeiten,
      schritt,
    ),
    hatOfen: d.frames.some((f) => f.ofen.present),
    preisSpanne,
    sonneMax,
  };
}

function bogen(l: Lauf<unknown>, radien: readonly [number, number], von: number, bis: number): string {
  return ringstueck(M, M, radien[0], radien[1], anteil(l.von, von, bis), anteil(l.bis, von, bis));
}

/** Die Ringe selbst. Eigene Komponente mit `memo`, damit der wandernde Zeiger sie nicht neu zeichnet. */
const RingBild = memo(function RingBild({ r }: { r: Ringe }) {
  const { von, bis } = r;
  const stunden = Math.round((bis - von) / STUNDE);
  return (
    <g>
      {/* Stundenstriche. Alle sechs Stunden kräftiger und beschriftet, dazwischen nur ein Hauch. */}
      {Array.from({ length: stunden }, (_, h) => {
        const a = h / stunden;
        const stark = h % 6 === 0;
        const [x0, y0] = punkt(M, M, 161, a);
        const [x1, y1] = punkt(M, M, stark ? 167 : 164, a);
        return <line key={h} x1={x0} y1={y0} x2={x1} y2={y1} stroke="#fff" strokeOpacity={stark ? 0.42 : 0.14} strokeWidth={1} />;
      })}
      {[0, 6, 12, 18].map((h) => {
        const [x, y] = punkt(M, M, 175, h / stunden);
        return (
          <text key={h} x={x} y={y} className="uhr-stunde" textAnchor="middle" dominantBaseline="central">
            {h}
          </text>
        );
      })}

      {/* Die Spuren: wo gemessen wurde. Wo keine Spur ist, wurde nichts erfasst. */}
      {[R.preis, R.sonne, R.gelaufen, ...(r.hatOfen ? [R.ofen] : [])].map((radien) =>
        r.spur.map((l) => <path key={`${radien[0]}-${l.von}`} d={bogen(l, radien, von, bis)} fill={SPUR} />),
      )}

      {r.preis.map((l) => (
        <path key={`p${l.von}`} d={bogen(l, R.preis, von, bis)} fill={C.price} fillOpacity={STUFEN[l.wert]} />
      ))}
      {r.sonne.map((l) => (
        <path key={`s${l.von}`} d={bogen(l, R.sonne, von, bis)} fill={C.pv} fillOpacity={STUFEN[l.wert]} />
      ))}

      {/* Die Absicht: dieselbe Farbe wie die Ausführung, aber als Umriss. Dasselbe Ding in einem
          anderen Stand - geplant ist noch nicht geschehen, und ein Umriss ist noch nicht gefüllt. */}
      {r.geplant.map((l) =>
        l.wert ? (
          <path key={`g${l.von}`} d={bogen(l, R.geplant, von, bis)} fill={C.heatPump} fillOpacity={0.22} stroke={C.heatPump} strokeWidth={1} />
        ) : (
          <path key={`g${l.von}`} d={bogen(l, R.geplant, von, bis)} fill={SPUR} />
        ),
      )}
      {r.gelaufen.map((l) => (l.wert ? <path key={`w${l.von}`} d={bogen(l, R.gelaufen, von, bis)} fill={C.heatPump} /> : null))}
      {r.ofen.map((l) => (l.wert ? <path key={`o${l.von}`} d={bogen(l, R.ofen, von, bis)} fill={C.stove} /> : null))}
    </g>
  );
});

/** In der Zeit des Hauses, nicht des Geräts: sonst passt die Mitte nicht zum Zifferblatt. */
function uhrzeit(ms: number): string {
  return hhmm(new Date(ms));
}

function de(x: number, n = 1): string {
  return x.toLocaleString("de-DE", { minimumFractionDigits: n, maximumFractionDigits: n });
}

export function Tagesuhr({ daten, index, onSprung }: { daten: AnlageReplay; index: number; onSprung: (i: number) => void }) {
  const r = useMemo(() => ringeAus(daten), [daten]);
  const svg = useRef<SVGSVGElement>(null);
  const zieht = useRef(false);
  const [schwebt, setSchwebt] = useState<number | null>(null);

  /** Das Bild unter dem Zeiger, oder -1 in der Mitte und außerhalb der Ringe. */
  const bildUnter = useCallback(
    (e: ReactPointerEvent<SVGSVGElement>): number => {
      const el = svg.current;
      if (!el) return -1;
      const box = el.getBoundingClientRect();
      const mass = GROESSE / box.width;
      const dx = (e.clientX - box.left) * mass - M;
      const dy = (e.clientY - box.top) * mass - M;
      const abstand = Math.hypot(dx, dy);
      // Die Mitte gehört der Anzeige. Wer dort klickt, will lesen und nicht springen.
      if (abstand < 70 || abstand > 178) return -1;
      return indexBei(anteilAus(dx, dy), r.zeiten, r.von, r.bis);
    },
    [r],
  );

  const zeig = schwebt ?? index;
  const bild = daten.frames[zeig];
  const zeit = r.zeiten[zeig];
  const preis = daten.preis_ct_kwh?.[zeig];
  const absicht = daten.geplant_wp?.[zeig];

  const zeiger = (i: number, schwach: boolean) => {
    const t = r.zeiten[i];
    if (t === undefined) return null;
    const a = anteil(t, r.von, r.bis);
    const innen = r.hatOfen ? 78 : 92;
    const [x0, y0] = punkt(M, M, innen, a);
    const [x1, y1] = punkt(M, M, 160, a);
    return (
      <g pointerEvents="none">
        {/* Ein dunkler Hof unter dem Zeiger, damit er über hellen Ringstücken lesbar bleibt. */}
        {schwach ? null : <line x1={x0} y1={y0} x2={x1} y2={y1} stroke={C.deep} strokeWidth={5} strokeLinecap="round" />}
        <line x1={x0} y1={y0} x2={x1} y2={y1} stroke="#fff" strokeOpacity={schwach ? 0.45 : 1} strokeWidth={schwach ? 1 : 2} strokeLinecap="round" />
        {schwach ? null : <circle cx={x1} cy={y1} r={4} fill="#fff" stroke={C.deep} strokeWidth={2} />}
      </g>
    );
  };

  return (
    <div className="uhr">
      <svg
        ref={svg}
        viewBox={`0 0 ${GROESSE} ${GROESSE}`}
        className="uhr-bild"
        role="img"
        aria-label="Tagesuhr: der Tag als Ring, Mitternacht oben. Bedienung über den Schieber in der Leiste."
        onPointerDown={(e) => {
          const i = bildUnter(e);
          if (i < 0) return;
          zieht.current = true;
          e.currentTarget.setPointerCapture(e.pointerId);
          onSprung(i);
        }}
        onPointerMove={(e) => {
          const i = bildUnter(e);
          if (zieht.current) {
            if (i >= 0) onSprung(i);
            return;
          }
          setSchwebt(i >= 0 ? i : null);
        }}
        onPointerUp={(e) => {
          zieht.current = false;
          if (e.currentTarget.hasPointerCapture(e.pointerId)) e.currentTarget.releasePointerCapture(e.pointerId);
        }}
        onPointerLeave={() => {
          if (!zieht.current) setSchwebt(null);
        }}
      >
        <RingBild r={r} />
        {schwebt !== null && schwebt !== index ? zeiger(schwebt, true) : null}
        {zeiger(index, false)}

        {/* Die Mitte: die Zeit unter dem Zeiger, und was dort galt. Schrift in Textfarbe; die
            Farbe gehört den Ringen. */}
        {zeit !== undefined && bild ? (
          <g pointerEvents="none">
            <text x={M} y={M - 14} className="uhr-zeit" textAnchor="middle" dominantBaseline="central">
              {uhrzeit(zeit)}
            </text>
            <text x={M} y={M + 16} className="uhr-wert" textAnchor="middle" dominantBaseline="central">
              {bild.strom.pv_kw != null ? `Sonne ${de(bild.strom.pv_kw)} kW` : "Sonne ?"}
              {preis != null ? ` · ${de(preis, 0)} ct` : ""}
            </text>
            <text x={M} y={M + 34} className="uhr-wert" textAnchor="middle" dominantBaseline="central">
              {bild.waermepumpe.running ? "Wärmepumpe läuft" : "Wärmepumpe steht"}
              {absicht == null ? "" : absicht ? " · geplant" : " · nicht geplant"}
            </text>
          </g>
        ) : null}
      </svg>

      {/* Die Legende folgt der Reihenfolge der Ringe, von außen nach innen. Jede Zeile ist eine
          Farbmarke und ein Wort in Textfarbe; farbige Schrift wäre Kennung ohne Lesbarkeit. */}
      <ul className="uhr-legende">
        <li>
          <span className="uhr-marke" style={{ background: C.price }} />
          Preis{r.preisSpanne ? ` · ${de(r.preisSpanne[0], 0)} bis ${de(r.preisSpanne[1], 0)} ct, heller ist teurer` : " · nicht erfasst"}
        </li>
        <li>
          <span className="uhr-marke" style={{ background: C.pv }} />
          Sonne{r.sonneMax > 0 ? ` · bis ${de(r.sonneMax)} kW, heller ist mehr` : " · keine an diesem Tag"}
        </li>
        <li>
          <span className="uhr-marke uhr-marke-umriss" style={{ borderColor: C.heatPump }} />
          Wärmepumpe geplant{r.hatAbsicht ? "" : " · kein Fahrplan aufbewahrt"}
        </li>
        <li>
          <span className="uhr-marke" style={{ background: C.heatPump }} />
          Wärmepumpe gelaufen
        </li>
        {r.hatOfen ? (
          <li>
            <span className="uhr-marke" style={{ background: C.stove }} />
            Pelletofen gebrannt
          </li>
        ) : null}
      </ul>
    </div>
  );
}
