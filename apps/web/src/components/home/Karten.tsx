"use client";

import Link from "next/link";
import type { LiveState } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { useGroesse } from "@/lib/useGroesse";
import { Icon, type IconName } from "@/components/ui/Icon";
import { PufferGlasBild } from "@/components/puffer/Glas";
import { FUEHLER, gradzahl, stufen } from "@/components/puffer/glas";
import { SCHRITT_MS, abschnitte, type Ausblick, type Zelle } from "./ausblick";
import { pufferZustand } from "./puffer";
import { preislaenge, stunden24 } from "./stundenring";
import { de } from "./tage";

/**
 * Die Karten rechts neben dem Bild der Startseite: der Puffer, die nächsten 24 Stunden als Bild
 * (zur Bühne) und der Strompreis in großer Zahl (zur Uhr, deren Ring die 24 Stunden selbst zeigt).
 */

/**
 * Der Puffer: Ladestand, Zustand als Marke und das Glas mit den vier Fühlern.
 *
 * **Dasselbe Glas wie überall** (Wunsch des Hausherrn vom 14.11.2026): an der Wand steht es, als
 * `PufferGlasBild` wie in der Anlage und im Ruhebild; am Telefon liegt es, weil ein stehendes
 * Glas die Seite unnötig streckt. Jede Zahl steht dann unter der Stelle ihres Fühlers.
 */
export function Pufferkarte({ state, nowMs }: { state: LiveState | null; nowMs: number }) {
  const s = state?.snapshot;
  const temps = s ? [s.buffer_temps_c.top, s.buffer_temps_c.mid_top, s.buffer_temps_c.mid_bottom, s.buffer_temps_c.bottom] : [];
  const { vollstaendig, veraltet, wort } = pufferZustand(temps, nowMs, !!state?.heat_pump.running, state?.buffer?.status);
  const fuehler = temps.map((m) => m.value);
  const soc = state?.buffer?.soc ?? null;
  const gedimmt = !vollstaendig || veraltet;
  const verlauf = stufen(fuehler);
  const quer = verlauf.length ? `linear-gradient(90deg, ${verlauf.map((st) => `${st.farbe} ${st.bei * 100}%`).join(", ")})` : "var(--surface-3)";
  const prozent = soc != null ? String(Math.round(soc * 100)) : "-";
  return (
    <Link href="/waerme" className="start-karte start-puffer" aria-label={`Puffer ${prozent} %, ${wort}. Details öffnen`}>
      <span className="start-puffer-links">
        <span className="start-karte-kopf">
          <span className="konto-zeichen start-zeichen"><Icon name="thermo" size={20} /></span>
          <span className="start-karte-titel">Puffer</span>
          <span className="start-marke" data-art={wort === "lädt" ? "an" : undefined}>{wort}</span>
        </span>
        <span className="mono start-grosszahl">{prozent}<small>%</small></span>
      </span>
      <PufferGlasBild className="start-glas" temps={fuehler} breite={60} hoehe={120} schrift={13} gedimmt={gedimmt} />
      <span className="start-glas-liegend" aria-hidden>
        <span className="start-glas-quer" style={{ background: quer, opacity: gedimmt ? 0.5 : 1 }} />
        <span className="start-puffer-fuehler">
          {fuehler.map((v, i) => {
            const zahl = gradzahl(v);
            return (
              <span key={i} className="mono start-puffer-wert" style={{ left: `${FUEHLER[i]! * 100}%` }}>
                {zahl ?? "-"}
                {zahl != null ? <span className="start-puffer-grad">°</span> : null}
              </span>
            );
          })}
        </span>
        <span className="start-puffer-orte">
          <span className="start-puffer-ort" style={{ left: `${FUEHLER[0] * 100}%` }}>oben</span>
          <span className="start-puffer-ort" style={{ left: `${FUEHLER[3] * 100}%` }}>unten</span>
        </span>
      </span>
    </Link>
  );
}

const lageArt = (lage: Ausblick["lage"]): string | undefined => (lage === "teuer" ? "teuer" : lage === "günstig" ? "guenstig" : undefined);

/** Preistief, beste Sonne und die nächsten Läufe als Zeitspannen statt als Sätze. */
function Zeitspannen({ blick }: { blick: Ausblick }) {
  const lauf = (an: (z: Zelle) => boolean): [number, number] | null => {
    const erster = abschnitte(blick.zellen, an)[0];
    return erster ? [blick.zellen[erster[0]]!.ts, blick.zellen[erster[1] - 1]!.ts + SCHRITT_MS] : null;
  };
  const wp = lauf((z) => z.wp);
  const ofen = lauf((z) => z.ofen);
  const spannen: Array<{ wort: string; zeichen: IconName; farbe: string; von: number; bis: number }> = [];
  if (blick.guenstig) spannen.push({ wort: "Preistief", zeichen: "euro", farbe: "var(--mist)", von: blick.guenstig.start, bis: blick.guenstig.end });
  if (blick.sonne) spannen.push({ wort: "Beste Sonne", zeichen: "sun", farbe: "var(--pv)", von: blick.sonne.start, bis: blick.sonne.end });
  if (wp) spannen.push({ wort: "Wärmepumpe", zeichen: "pump", farbe: "var(--heat-pump)", von: wp[0], bis: wp[1] });
  if (ofen) spannen.push({ wort: "Pelletofen", zeichen: "stove", farbe: "var(--stove)", von: ofen[0], bis: ofen[1] });
  if (!spannen.length) return null;
  return (
    <span className="start-zeiten">
      {spannen.map((sp) => (
        <span key={sp.wort} className="start-zeit">
          <span className="start-zeit-wort"><Icon name={sp.zeichen} size={14} color={sp.farbe} />{sp.wort}</span>
          <span className="mono start-zeit-uhr">{hhmm(new Date(sp.von))}–{hhmm(new Date(sp.bis))}</span>
        </span>
      ))}
    </span>
  );
}

/** Der Preis als Säulen, die erwartete Sonne dahinter, die Läufe als Striche darunter. */
function Stundenbild({ blick }: { blick: Ausblick }) {
  const [ref, groesse] = useGroesse<HTMLSpanElement>();
  const st = stunden24(blick.zellen, blick.guenstig);
  const W = groesse?.breite ?? 0;
  const ofen = st.some((s) => s.ofen);
  const boden = 84;
  const hoch = 66;
  const H = boden + 32 + (ofen ? 8 : 0);
  const b = W / 24;
  const sonneMax = Math.max(blick.pvMax, 3);
  const punkte = st.map((s, i) => `${((i + 0.5) * b).toFixed(1)},${(boden - Math.min(1, s.sonneKw / sonneMax) * hoch).toFixed(1)}`);
  return (
    <span ref={ref} className="start-stundenbild" style={{ height: H }}>
      {W > 0 && st.length ? (
        <svg viewBox={`0 0 ${W} ${H}`} width={W} height={H} role="img" aria-label="Strompreis, erwartete Sonne und geplante Läufe in den nächsten 24 Stunden">
          <defs>
            <linearGradient id="st-sonne" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="var(--pv)" stopOpacity={0.5} /><stop offset="1" stopColor="var(--pv)" stopOpacity={0.04} /></linearGradient>
          </defs>
          <path d={`M0,${boden} L${punkte.join(" L")} L${W},${boden} Z`} fill="url(#st-sonne)" />
          <path d={`M${punkte.join(" L")}`} fill="none" stroke="var(--pv)" strokeWidth={1.5} strokeOpacity={0.9} />
          {st.map((s, i) => {
            const x = i * b + 3.5;
            const w = Math.max(2, b - 7);
            const h = s.preis != null ? Math.max(3, preislaenge(s.preis, blick.preisMax) * hoch) : 20;
            return (
              <g key={s.start}>
                {s.preis != null
                  ? <rect x={x} y={boden - h} width={w} height={h} rx={w / 2} fill={i === 0 ? "var(--paper)" : "var(--mist)"} fillOpacity={i === 0 ? 0.95 : s.tief ? 1 : 0.42} />
                  : <rect x={x} y={boden - h} width={w} height={h} rx={w / 2} fill="none" stroke="var(--mist)" strokeOpacity={0.45} strokeDasharray="2 3" />}
                {s.wp ? <rect x={i * b + 1} y={boden + 6} width={Math.max(2, b - 2)} height={5} rx={2.5} fill="var(--heat-pump)" /> : null}
                {s.ofen ? <rect x={i * b + 1} y={boden + 14} width={Math.max(2, b - 2)} height={5} rx={2.5} fill="var(--stove)" /> : null}
                {i === 0 ? <text x={1} y={H - 2} className="start-achse" style={{ fill: "var(--text-1)" }}>jetzt</text> : null}
                {i > 2 && s.stunde % 6 === 0 ? <text x={(i + 0.5) * b} y={H - 2} textAnchor="middle" className="start-achse">{String(s.stunde).padStart(2, "0")} Uhr</text> : null}
              </g>
            );
          })}
        </svg>
      ) : null}
    </span>
  );
}

function Preis({ blick, gross = false }: { blick: Ausblick; gross?: boolean }) {
  return (
    <>
      <span className={gross ? "mono start-grosszahl" : "mono start-preis"}>{de(blick.preisJetzt, 1)}<small>{gross ? "ct je kWh" : "ct"}</small></span>
      {blick.lage ? <span className="start-marke" data-art={lageArt(blick.lage)}>{blick.lage}</span> : null}
    </>
  );
}

/** Die nächsten 24 Stunden als ein Bild mit Zeitspannen. Steht neben der Bühne. */
export function Ausblickkarte({ blick, warnung }: { blick: Ausblick; warnung?: string | null }) {
  return (
    <section className="start-karte start-ausblick" aria-label="Die nächsten 24 Stunden">
      <span className="start-karte-kopf">
        <span className="konto-zeichen start-zeichen"><Icon name="clock" size={20} /></span>
        <span className="start-karte-titel">Nächste 24 Stunden</span>
        <span className="start-karte-rechts"><Preis blick={blick} /></span>
      </span>
      <Stundenbild blick={blick} />
      <Zeitspannen blick={blick} />
      {warnung ? <span className="start-warnung">{warnung}</span> : null}
    </section>
  );
}

/** Der Strompreis in großer Zahl mit den Zeitspannen. Steht neben der Uhr. */
export function Stromkarte({ blick, warnung }: { blick: Ausblick; warnung?: string | null }) {
  return (
    <section className="start-karte start-strom" aria-label="Strom gerade">
      <span className="start-karte-kopf">
        <span className="konto-zeichen start-zeichen"><Icon name="euro" size={20} /></span>
        <span className="start-karte-titel">Strom gerade</span>
      </span>
      <span className="start-strom-zeile"><Preis blick={blick} gross /></span>
      <Zeitspannen blick={blick} />
      {warnung ? <span className="start-warnung">{warnung}</span> : null}
    </section>
  );
}
