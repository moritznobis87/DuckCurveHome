"use client";

import Link from "next/link";
import type { LiveState, Plan } from "@/lib/api/models";
import { celsius } from "@/lib/format";
import { planZeilen } from "./fahrplan";
import { FUEHLER_POS, heatColor, pufferZustand, SCHICHT_GRENZEN } from "./puffer";

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
export function Rail({ state, plan, nowMs, kompakt = false }: { state: LiveState | null; plan: Plan | null; nowMs: number; kompakt?: boolean }) {
  const s = state?.snapshot;
  const buffer = state?.buffer;
  const temps = s ? [s.buffer_temps_c.top, s.buffer_temps_c.mid_top, s.buffer_temps_c.mid_bottom, s.buffer_temps_c.bottom] : [];
  // **Eine Zahl steht ueber ihrer Farbe.** Der Tank ist in vier gleich hohe Schichten geteilt,
  // je ein Fuehler in der Mitte seiner Schicht: 12,5 / 37,5 / 62,5 / 87,5 Prozent. Dieselben vier
  // Werte tragen den Farbverlauf, die Beschriftung und - als Grenzen dazwischen - die
  // Trennlinien. Vorher lagen die Farbstopps bei 8/37/63/92, die Linien bei 25/50/75 und die
  // Zahlen gleichmaessig verteilt mit der Einheit als fuenftem Posten, der sie alle nach links
  // schob: die 28 stand bei 69 Prozent, waehrend ihre Farbe bei 92 lag (gesehen am 26.10.2026).
  const stufen = temps.map((m, i) => `${heatColor(m.value ?? 20)} ${FUEHLER_POS[i]}%`).join(", ");
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
  // Vier Fuehler, von oben nach unten. Ohne Worte: der Tank selbst sagt, wo oben ist.
  const fuehler = temps.map((m) => m.value);
  const soc = buffer?.soc ?? null;

  const zeilen = planZeilen(plan, nowMs);

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
            {SCHICHT_GRENZEN.map((x) => <span key={x} className="home-tank-marke-quer" style={{ left: `${x}%` }} />)}
          </span>
          {/* Jede Zahl steht ueber ihrer Farbe, nicht in einer gleichmaessigen Reihe. Die Einheit
              steht einmal, ganz rechts, und nimmt keinen Platz in der Verteilung ein. */}
          <span className="home-puffer-fuehler" aria-hidden>
            {fuehler.map((v, i) => (
              <span key={i} className="mono home-puffer-wert" style={{ left: `${FUEHLER_POS[i]}%` }}>
                {v == null ? "-" : Math.round(v)}
              </span>
            ))}
            <span className="home-puffer-einheit">°C</span>
          </span>
          <span className="home-puffer-orte" aria-hidden>
            <span className="home-puffer-ort" style={{ left: `${FUEHLER_POS[0]}%` }}>oben</span>
            <span className="home-puffer-ort" style={{ left: `${FUEHLER_POS[3]}%` }}>unten</span>
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
          {SCHICHT_GRENZEN.map((y) => <span key={y} className="home-tank-marke" style={{ top: `${y}%` }} />)}
        </span>
        {/* Auch hier: jede Zahl auf der Hoehe, auf der ihre Farbe steht. */}
        <span className="home-tank-fuehler" aria-hidden>
          {fuehler.map((v, i) => (
            <span key={i} className="mono home-tank-wert" style={{ top: `${FUEHLER_POS[i]}%` }}>
              {v == null ? "-" : `${Math.round(v)} °C`}
            </span>
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
