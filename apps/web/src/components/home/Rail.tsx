"use client";

import Link from "next/link";
import type { LiveState, Plan, PlanInterval } from "@/lib/api/models";
import { celsius, hhmm } from "@/lib/format";
import { pufferZustand } from "./puffer";

/**
 * Die Leiste rechts neben dem Fluss: der Puffer und der Plan.
 *
 * Der Puffer bekommt die ganze Hoehe, weil er das zweite Bild der Seite ist: ein Tank, der von
 * oben nach unten die Farbe der vier Fuehler zeigt. Raeume und Strompreis standen hier als zwei
 * weitere Kacheln und sind weg (Nutzerwunsch 22.10.2026): der Strompreis steht ohnehin in der
 * Tageskurve, die Raeume haben ihre Seite. Dazu die naechsten 24 Stunden in drei Zeilen, weil
 * die Frage „was hat das Haus vor" sonst nur im Satz oben beantwortet waere, und der sagt nur das
 * Naechste.
 */
const STOPS: Array<[number, [number, number, number]]> = [
  [25, [0x1f, 0x4c, 0x66]],
  [40, [0x7f, 0xa3, 0xb3]],
  [50, [0xff, 0xd7, 0x78]],
  [60, [0xf2, 0xa9, 0x00]],
  [70, [0xe0, 0x53, 0x3d]],
];
const rgb = (c: [number, number, number]) => `rgb(${c[0]},${c[1]},${c[2]})`;

/** Farbe einer Puffertemperatur, von kalt-petrol bis heiss-rot. */
export function heatColor(t: number): string {
  const first = STOPS[0]!;
  const last = STOPS[STOPS.length - 1]!;
  if (t <= first[0]) return rgb(first[1]);
  if (t >= last[0]) return rgb(last[1]);
  for (let i = 0; i < STOPS.length - 1; i++) {
    const [t0, c0] = STOPS[i]!;
    const [t1, c1] = STOPS[i + 1]!;
    if (t >= t0 && t <= t1) {
      const f = (t - t0) / (t1 - t0);
      return rgb([0, 1, 2].map((k) => Math.round(c0[k]! + (c1[k]! - c0[k]!) * f)) as [number, number, number]);
    }
  }
  return rgb(last[1]);
}

const STEP_MS = 15 * 60_000;

/** Zusammenhaengende Phasen aus den Viertelstundenschritten des Fahrplans. */
function phasen(plan: Plan | null, nowMs: number, end: number, an: (iv: PlanInterval) => boolean | null | undefined): Array<{ start: number; end: number }> {
  const out: Array<{ start: number; end: number }> = [];
  let offen: { start: number; end: number } | null = null;
  for (const iv of plan?.intervals ?? []) {
    const t = new Date(iv.ts).getTime();
    if (t + STEP_MS <= nowMs || t >= end) continue;
    if (an(iv)) {
      if (offen && offen.end === t) offen.end = t + STEP_MS;
      else {
        offen = { start: t, end: t + STEP_MS };
        out.push(offen);
      }
    } else offen = null;
  }
  return out;
}

function spanne(p: { start: number; end: number }, nowMs: number): string {
  return p.start <= nowMs ? `bis ${hhmm(new Date(p.end))}` : `${hhmm(new Date(p.start))} bis ${hhmm(new Date(p.end))}`;
}

export function Rail({ state, plan, nowMs, kompakt = false }: { state: LiveState | null; plan: Plan | null; nowMs: number; kompakt?: boolean }) {
  const s = state?.snapshot;
  const buffer = state?.buffer;
  const temps = s ? [s.buffer_temps_c.top, s.buffer_temps_c.mid_top, s.buffer_temps_c.mid_bottom, s.buffer_temps_c.bottom] : [];
  // Derselbe Farbverlauf in zwei Richtungen: hochkant neben der Zahl (iPad), liegend unter ihr
  // (Telefon). Oben ist links.
  const stufen = temps.map((m, i) => `${heatColor(m.value ?? 20)} ${[8, 37, 63, 92][i]}%`).join(", ");
  // Das Wort unter dem Fuellstand und die Frage, ob die Werte ueberhaupt frisch sind: in
  // `puffer.ts`, weil genau daran am 25.10.2026 eine Stunde Suche haengen blieb.
  const { vollstaendig, veraltet, wort: zustand } = pufferZustand(
    temps,
    nowMs,
    !!state?.heat_pump.running,
    buffer?.status,
  );
  const verlauf = vollstaendig ? `linear-gradient(180deg, ${stufen})` : "var(--surface-3)";
  const verlaufQuer = vollstaendig ? `linear-gradient(90deg, ${stufen})` : "var(--surface-3)";
  // Vier Fuehler, von oben nach unten, neben dem Tank auf gleicher Hoehe. Ohne Worte: der Tank
  // selbst sagt, wo oben ist, und die Kachel hat keine Breite fuer ein drittes Wort je Zeile.
  const fuehler = temps.map((m) => m.value);
  const soc = buffer?.soc ?? null;

  const tief = plan?.next_cheap_window;
  const end = nowMs + 24 * 3600_000;
  const wp = phasen(plan, nowMs, end, (iv) => iv.reason_code === "planned_optimizer" && iv.planned_hp_state === "release");
  const hatWp = (plan?.intervals ?? []).some((iv) => iv.reason_code === "planned_optimizer");
  const ofen = phasen(plan, nowMs, end, (iv) => iv.planned_stove_on);
  const hatOfen = (plan?.intervals ?? []).some((iv) => iv.planned_stove_on != null);
  const zeilen: Array<[string, string]> = [];
  if (hatWp) zeilen.push(["Wärmepumpe", wp[0] ? spanne(wp[0], nowMs) : "bleibt aus"]);
  if (hatOfen) zeilen.push(["Pelletofen", ofen[0] ? spanne(ofen[0], nowMs) : "bleibt aus"]);
  if (tief) zeilen.push(["Preistief", `${hhmm(tief.start)} bis ${hhmm(tief.end)}`]);


  const pufferWort = `${celsius(s?.buffer_temps_c.top.value)} oben, ${zustand}`;

  // **Auf dem Telefon liegt der Puffer.** Die hohe Kachel vom iPad sass dort zwischen Kurve und
  // Fahrplan wie ein Fremdkoerper: ein stehender Tank neben einer Zahlenspalte, waehrend alles
  // andere flach und zweispaltig ist. Liegend hat er dieselbe Hoehe wie die Kacheln darueber,
  // und die vier Fuehler stehen dort, wo ihre Farbe steht.
  if (kompakt) {
    return (
      <div className="home-rail">
        <Link href="/waerme" className="home-puffer-flach" aria-label={`Puffer ${soc != null ? Math.round(soc * 100) : "-"} %, ${pufferWort}`}>
          <span className="home-puffer-kopf">
            <span className="kicker" style={{ fontSize: 11 }}>Puffer</span>
            <span className="mono home-puffer-zahl">
              {soc != null ? String(Math.round(soc * 100)) : "-"} <span className="home-einheit">%</span>
              <span className="home-puffer-wort">{zustand}</span>
            </span>
          </span>
          <span className="home-tank-quer" style={{ background: verlaufQuer, opacity: vollstaendig && !veraltet ? 1 : 0.45 }} aria-hidden>
            {[25, 50, 75].map((x) => <span key={x} className="home-tank-marke-quer" style={{ left: `${x}%` }} />)}
          </span>
          <span className="home-puffer-fuehler" aria-hidden>
            {fuehler.map((v, i) => (
              <span key={i} className="flex flex-col items-start gap-[2px]">
                <span className="mono">{v == null ? "-" : `${Math.round(v)} °C`}</span>
                {i === 0 ? <span className="home-puffer-ort">oben</span> : i === 3 ? <span className="home-puffer-ort">unten</span> : null}
              </span>
            ))}
          </span>
        </Link>
        {zeilen.length ? <Plan zeilen={zeilen} warnung={plan?.planner_warn_de} /> : null}
      </div>
    );
  }

  return (
    <div className="home-rail">
      <Link href="/waerme" className="home-kachel home-kachel-puffer" aria-label={`Puffer ${soc != null ? Math.round(soc * 100) : "-"} %, ${pufferWort}`}>
        <span className="home-tank" style={{ background: verlauf, opacity: vollstaendig && !veraltet ? 1 : 0.45 }} aria-hidden>
          {[25, 50, 75].map((y) => <span key={y} className="home-tank-marke" style={{ top: `${y}%` }} />)}
        </span>
        <span className="home-tank-fuehler" aria-hidden>
          {fuehler.map((v, i) => (
            <span key={i} className="mono">{v == null ? "-" : `${Math.round(v)} °C`}</span>
          ))}
        </span>
        <span className="flex min-w-0 flex-1 flex-col justify-center gap-1">
          <span className="kicker" style={{ fontSize: 11 }}>Puffer</span>
          <span className="mono home-rail-zahl text-text-1">
            {soc != null ? String(Math.round(soc * 100)) : "-"} <span className="home-einheit">%</span>
          </span>
          <span className="text-[12px] text-text-2">{zustand}</span>
        </span>
      </Link>
      {zeilen.length ? <Plan zeilen={zeilen} warnung={plan?.planner_warn_de} /> : null}
    </div>
  );
}

/** Die naechsten 24 Stunden in drei Zeilen - in beiden Ansichten dieselben. */
function Plan({ zeilen, warnung }: { zeilen: Array<[string, string]>; warnung?: string }) {
  return (
    <div className="home-kachel home-kachel-plan flex flex-col gap-1.5">
      <span className="kicker" style={{ fontSize: 11 }}>Nächste 24 h</span>
      {zeilen.map(([k, v]) => (
        <span key={k} className="flex justify-between gap-2 text-[12px] text-text-2">
          <span>{k}</span>
          <span className="mono text-text-1">{v}</span>
        </span>
      ))}
      {warnung ? <span className="text-[11px]" style={{ color: "var(--amber-soft)" }}>{warnung}</span> : null}
    </div>
  );
}
