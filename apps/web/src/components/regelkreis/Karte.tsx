"use client";

import { useMemo } from "react";
import type { Regelkreis, RegelkreisParameter } from "@/lib/api/models";
import { HERKUNFT_FARBE, Sprungantwort } from "./Anzeigen";
import { BESCHRIFTUNG, EBENEN, PLATZ, SICHT, WEGE, notplatz, type Punkt, type Rechteck } from "./layout";

/**
 * Das Blockschaltbild der Hausregelung.
 *
 * Gezeichnet wird aus zwei Quellen: die Topologie kommt aus der Antwort des Dienstes (welche
 * Blöcke, welche Signale, welche Störgrößen), die Geometrie aus `layout`. Diese Trennung ist der
 * Grund, warum die Karte nicht veraltet, wenn im Kern ein Signal dazukommt - sie zeichnet, was
 * die Antwort sagt, und nicht, was einmal hier eingetragen wurde.
 *
 * **Die Farbe am Parameter ist die Herkunft seiner Zahl.** Gemessen, geschätzt, angenommen, fest,
 * übersteuert. Das ist die wichtigste Auskunft der ganzen Seite: eine Karte, auf der eine Annahme
 * aussieht wie eine Messung, verleitet zu Schlüssen, die die Daten nicht tragen.
 */

const KANTE_KLASSE: Record<string, string> = {
  signal: "rk-kante",
  stoergroesse: "rk-kante rk-stoer",
  rueckfuehrung: "rk-kante rk-rueck",
  fuehrung: "rk-kante rk-fuehrung",
  parameter: "rk-kante rk-param",
};
const KANTE_SPITZE: Record<string, string> = {
  signal: "rk-pfeil",
  stoergroesse: "rk-pfeil-stoer",
  rueckfuehrung: "rk-pfeil-rueck",
  fuehrung: "rk-pfeil-fuehrung",
  parameter: "rk-pfeil-param",
};

function pfad(p: Punkt[], bogen?: Punkt): string {
  if (p.length < 2) return "";
  let d = `M${p[0]![0]} ${p[0]![1]}`;
  for (let i = 1; i < p.length; i++) {
    const [x, y] = p[i]!;
    const [vx, vy] = p[i - 1]!;
    // Der Sprungbogen an der einen Kreuzung des Bildes: ein Viertelkreis darüber hinweg.
    if (bogen && vx === x && x === bogen[0] && Math.min(vy, y) < bogen[1] && bogen[1] < Math.max(vy, y)) {
      const richtung = y > vy ? 1 : -1;
      d += ` L${x} ${bogen[1] - 6 * richtung} A6 6 0 0 ${richtung > 0 ? 1 : 0} ${x} ${bogen[1] + 6 * richtung}`;
    }
    d += ` L${x} ${y}`;
  }
  return d;
}

/** Ein Ersatzweg für eine Leitung ohne Eintrag: von Rand zu Rand, damit sie sichtbar fehlt. */
function ersatz(a: Rechteck, b: Rechteck): Punkt[] {
  const von: Punkt = [a.x + a.w, a.y + a.h / 2];
  const nach: Punkt = [b.x, b.y + b.h / 2];
  const mitte = (von[0] + nach[0]) / 2;
  return [von, [mitte, von[1]], [mitte, nach[1]], nach];
}

/** Umbruch an Wortgrenzen auf eine Zeichenzahl, die in die Breite passt. */
function teile(text: string, max: number): string[] {
  const worte = text.split(" ");
  const aus: string[] = [];
  let zeile = "";
  for (const w of worte) {
    if ((zeile + " " + w).trim().length > max && zeile) {
      aus.push(zeile);
      zeile = w;
    } else zeile = (zeile + " " + w).trim();
  }
  if (zeile) aus.push(zeile);
  return aus;
}

/** Auf eine Breite kürzen. Abgeschnitten mit Auslassung ist besser als über den Rand hinaus. */
function kuerze(text: string, breite: number, proZeichen: number): string {
  const max = Math.max(4, Math.floor(breite / proZeichen));
  return text.length > max ? text.slice(0, max - 1).trimEnd() + "…" : text;
}

type Zeile = { text: string; klasse: string; y: number; farbe?: string };

/**
 * Der Textstapel eines Kästchens: Name, Übertragungsglied, Parameter - von oben nach unten, und
 * was nicht mehr hineinpasst, wird weggelassen.
 *
 * Gestapelt statt an feste Höhen gesetzt: die Kästchen sind verschieden hoch, die Namen
 * verschieden lang, und eine Formel, die über einem Parameterwert liegt, ist schlimmer als eine
 * fehlende Zeile.
 */
function stapel(
  b: { name: string; kurz: string; kreis?: string | null; gibt_marke?: string | null; marke?: string | null },
  r: Rechteck,
  ps: RegelkreisParameter[],
  stoer: boolean,
  klein: boolean,
  oben: boolean,
  rechts: number,
  mitFormel: boolean,
): Zeile[] {
  const aus: Zeile[] = [];
  const unten = r.y + r.h - (b.kreis || b.marke ? 20 : 6);
  // Platz für die Lernmarke oder die Signalmarke oben rechts - aber nur, wo eine steht.
  const ersteBreite = r.w - (oben ? 34 : 20) - rechts;
  let y = r.y + (stoer ? 16 : 19);
  const namen = stoer ? [kuerze(b.name, ersteBreite, 6.2)] : teile(b.name, Math.floor(ersteBreite / 6.4)).slice(0, 2);
  for (const [i, n] of namen.entries()) {
    aus.push({ text: i === 0 ? kuerze(n, ersteBreite, 6.4) : kuerze(n, r.w - 20 - rechts, 6.4), klasse: stoer ? "rk-name-klein" : "rk-name", y });
    y += 14;
  }
  if (b.kurz && mitFormel) {
    const breit = r.w - 20 - rechts;
    const formeln = klein || stoer ? [kuerze(b.kurz, breit, 6.1)] : teile(b.kurz, Math.floor(breit / 6.1)).slice(0, 2);
    y += 3;
    for (const z of formeln) {
      if (y > unten) break;
      aus.push({ text: z, klasse: "rk-formel", y });
      y += 12;
    }
  }
  if (ps.length) {
    y += 3;
    for (const p of ps) {
      if (y > unten) break;
      aus.push({ text: `${p.symbol} = ${zahl(p)}`, klasse: "rk-wert", y, farbe: HERKUNFT_FARBE[p.herkunft] });
      y += 12.5;
    }
  }
  return aus;
}

function zahl(p: RegelkreisParameter): string {
  const n = p.wert.toLocaleString("de-DE", { minimumFractionDigits: p.stellen, maximumFractionDigits: p.stellen });
  return p.einheit === "—" ? n : `${n} ${p.einheit}`;
}

export function Karte({ d, sicht, gewaehlt, onWaehle }: { d: Regelkreis; sicht: string; gewaehlt: string | null; onWaehle: (id: string) => void }) {
  const box = SICHT[sicht]?.box ?? SICHT.alles!.box;
  const params = useMemo(() => {
    const nach: Record<string, RegelkreisParameter[]> = {};
    for (const p of d.parameter) (nach[p.block] ??= []).push(p);
    return nach;
  }, [d.parameter]);

  const glieder = useMemo(() => Object.fromEntries(d.glieder.map((g) => [g.id, g])), [d.glieder]);
  const ohnePlatz = d.bloecke.filter((b) => !PLATZ[b.id]);
  const platz: Record<string, Rechteck> = {};
  for (const b of d.bloecke) platz[b.id] = PLATZ[b.id]?.rect ?? notplatz(ohnePlatz.indexOf(b));

  return (
    <div className="rk-roller">
      <figure className="m-0">
        <svg
          className="rk-karte"
          viewBox={box.join(" ")}
          role="img"
          aria-label="Blockschaltbild der Hausregelung: ökonomische Führung, Pufferladung, Erzeuger, Vorlauftemperatur, Einzelraumregelung mit ihren Störgrößen."
        >
          <defs>
            {[
              ["rk-pfeil", "var(--text-2)"],
              ["rk-pfeil-stoer", "var(--alert)"],
              ["rk-pfeil-rueck", "var(--mist)"],
              ["rk-pfeil-fuehrung", "var(--amber-soft)"],
              ["rk-pfeil-param", "var(--amber)"],
            ].map(([id, farbe]) => (
              <marker key={id} id={id} viewBox="0 0 10 8" refX={9} refY={4} markerWidth={7} markerHeight={6} orient="auto">
                <polygon points="0,0 10,4 0,8" fill={farbe} />
              </marker>
            ))}
          </defs>

          {EBENEN.map((e) => (
            <text key={e.text} className="rk-ebene" x={e.x} y={e.y}>
              {e.text}
            </text>
          ))}

          {/* Leitungen zuerst, damit die Kästchen darüber liegen. */}
          {d.kanten.map((k) => {
            const schluessel = `${k.von}→${k.nach}`;
            const weg = WEGE[schluessel];
            const p = weg ? weg.p : ersatz(platz[k.von]!, platz[k.nach]!);
            if (p.length < 2) return null;
            const kl = KANTE_KLASSE[k.art] ?? "rk-kante";
            const hell = gewaehlt && (k.von === gewaehlt || k.nach === gewaehlt);
            return (
              <g key={schluessel}>
                <path className={`${kl}${hell ? " rk-hell" : ""}`} d={pfad(p, weg?.bogen)} markerEnd={`url(#${KANTE_SPITZE[k.art] ?? "rk-pfeil"})`} />
                {k.vorzeichen ? (
                  <text className="rk-vorzeichen" x={p[p.length - 1]![0] + 7} y={p[p.length - 1]![1] - 6}>
                    {k.vorzeichen === "-" ? "−" : "+"}
                  </text>
                ) : null}
              </g>
            );
          })}

          {/* Die Beschriftungen liegen auf ihrer Leitung; ein Feld in Flächenfarbe darunter hält
              die Linie von der Schrift ab. */}
          {BESCHRIFTUNG.map((b) => {
            const breite = b.text.length * 5.35 + 10;
            const links = b.anker === "middle" ? b.x - breite / 2 : b.anker === "end" ? b.x - breite : b.x - 5;
            return (
              <g key={b.text}>
                <rect x={links} y={b.y - 9} width={breite} height={12} fill="var(--surface-1)" />
                <text className="rk-leitung-text" x={b.x} y={b.y} textAnchor={b.anker ?? "start"}>
                  {b.text}
                </text>
              </g>
            );
          })}

          {/* Kästchen */}
          {d.bloecke.map((b) => {
            const haupt = platz[b.id]!;
            const rechtecke = [haupt, ...(PLATZ[b.id]?.wdh ?? [])];
            const ps = (params[b.id] ?? []).slice(0, 3);
            const klein = haupt.h <= 44;
            // Das Kennbild steht rechts im Kaestchen, wo Platz dafuer ist; sonst nur das
            // Kurzzeichen. Der Textstapel weicht ihm aus.
            const g = b.glied ? glieder[b.glied] : undefined;
            const bild = g && haupt.h >= 74 && haupt.w >= 150 ? g : undefined;
            const summe = b.rolle === "summierstelle";
            const stoer = b.rolle === "stoergroesse";
            const gelernt = (params[b.id] ?? []).some((p) => p.herkunft === "gemessen" || p.herkunft === "geschaetzt" || p.herkunft === "annahme");
            const ueber = (params[b.id] ?? []).some((p) => p.herkunft === "uebersteuert");
            return (
              <g key={b.id} className={`rk-blk rk-${b.rolle}${gewaehlt === b.id ? " rk-gewaehlt" : ""}`} onClick={() => onWaehle(b.id)} tabIndex={0} role="button" aria-label={b.name} onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onWaehle(b.id); } }}>
                {rechtecke.map((r, i) =>
                  summe ? (
                    <g key={i}>
                      <circle className="rk-summe" cx={r.x + r.w / 2} cy={r.y + r.h / 2} r={17} />
                      <text className="rk-summe-text" x={r.x + r.w / 2} y={r.y + r.h / 2 + 4}>
                        Σ
                      </text>
                    </g>
                  ) : (
                    <g key={i}>
                      {b.rolle === "teilkreise" ? (
                        <>
                          <rect className="rk-rahmen rk-blass" x={r.x + 12} y={r.y - 12} width={r.w} height={r.h} rx={4} />
                          <rect className="rk-rahmen rk-blass" x={r.x + 6} y={r.y - 6} width={r.w} height={r.h} rx={4} />
                        </>
                      ) : null}
                      <rect className="rk-rahmen" x={r.x} y={r.y} width={r.w} height={r.h} rx={stoer ? 10 : 4} />
                      {i > 0 ? (
                        <text className="rk-wdh" x={r.x + r.w - 7} y={r.y + 11} textAnchor="end">
                          ↗
                        </text>
                      ) : null}
                      {i > 0 ? (
                        <text className={stoer ? "rk-name-klein" : "rk-name"} x={r.x + 10} y={r.y + 21}>
                          {kuerze(b.name, r.w - 34, 6.4)}
                        </text>
                      ) : null}
                    </g>
                  ),
                )}
                {summe
                  ? null
                  : stapel(b, haupt, ps, stoer, klein, gelernt || !!b.gibt_marke, bild ? 54 : 0, !bild).map((z, i) => (
                      <text key={i} className={z.klasse} style={z.farbe ? { fill: z.farbe } : undefined} x={haupt.x + 11} y={z.y}>
                        {z.text}
                      </text>
                    ))}
                {bild ? (
                  <g transform={`translate(${haupt.x + haupt.w - 50} ${haupt.y + 22})`} className="rk-kennbild">
                    <Sprungantwort g={bild} />
                    <text x={21} y={36} textAnchor="middle" className="rk-glied-kurz">
                      {bild.kurz}
                    </text>
                  </g>
                ) : g && !summe ? (
                  <text x={haupt.x + haupt.w - 8} y={haupt.y + haupt.h - 7} textAnchor="end" className="rk-glied-kurz">
                    {g.kurz}
                  </text>
                ) : null}
                {summe ? null : (
                  <>
                    {b.kreis ? (
                      <text className="rk-marke" x={haupt.x + haupt.w - 8} y={haupt.y + haupt.h - 8} textAnchor="end">
                        {b.kreis}
                      </text>
                    ) : null}
                    {b.gibt_marke ? (
                      <text className="rk-marke" x={haupt.x + haupt.w - 8} y={haupt.y + 13} textAnchor="end">
                        {b.gibt_marke} ▸
                      </text>
                    ) : null}
                    {b.marke ? (
                      <text className="rk-marke" x={haupt.x + haupt.w - 8} y={haupt.y + haupt.h - 8} textAnchor="end">
                        ◂ {b.marke}
                      </text>
                    ) : null}
                    {gelernt ? (
                      <g>
                        <circle cx={haupt.x + haupt.w - 11} cy={haupt.y + 11} r={5.5} fill={ueber ? "var(--alert)" : "var(--amber)"} />
                        <text className="rk-theta" x={haupt.x + haupt.w - 11} y={haupt.y + 14.5} textAnchor="middle">
                          θ
                        </text>
                      </g>
                    ) : null}
                  </>
                )}
              </g>
            );
          })}
        </svg>
        <figcaption className="rk-bild-text">
          Die Kaskade von außen nach innen: ökonomische Führung, Speicherladung, Erzeuger, Vorlauftemperatur, Einzelraum. Störgrößen stehen am Ort ihrer Wirkung und werden dort wiederholt, wo sie mehrfach angreifen (↗).
          {ohnePlatz.length ? ` Ohne Platz in der Zeichnung: ${ohnePlatz.map((b) => b.name).join(", ")}.` : ""}
        </figcaption>
      </figure>
    </div>
  );
}
