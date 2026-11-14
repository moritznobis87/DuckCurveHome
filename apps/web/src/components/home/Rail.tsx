"use client";

import Link from "next/link";
import type { LiveState, Plan } from "@/lib/api/models";
import { celsius } from "@/lib/format";
import { Ausblick } from "./Ausblick";
import { planZeilen } from "./fahrplan";
import { PufferGlasBild } from "@/components/puffer/Glas";
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
export function Rail({ state, plan, nowMs, kompakt = false }: { state: LiveState | null; plan: Plan | null; nowMs: number; kompakt?: boolean }) {
  const s = state?.snapshot;
  const buffer = state?.buffer;
  const temps = s ? [s.buffer_temps_c.top, s.buffer_temps_c.mid_top, s.buffer_temps_c.mid_bottom, s.buffer_temps_c.bottom] : [];
  // Das Wort unter dem Fuellstand und die Frage, ob die Werte ueberhaupt frisch sind: in
  // `puffer.ts`, weil genau daran am 25.10.2026 eine Stunde Suche haengen blieb.
  const { vollstaendig, veraltet, wort: zustand } = pufferZustand(
    temps,
    nowMs,
    !!state?.heat_pump.running,
    buffer?.status,
  );
  // Vier Fuehler, von oben nach unten. Ohne Worte: das Glas selbst sagt, wo oben ist.
  const fuehler = temps.map((m) => m.value);
  const soc = buffer?.soc ?? null;

  const zeilen = planZeilen(plan, nowMs);

  const pufferWort = `${celsius(s?.buffer_temps_c.top.value)} oben, ${zustand}`;

  // **Der Speicher sieht ueberall gleich aus** (Nutzerwunsch 14.11.2026): das Glas aus dem
  // Anlagenschema, stehend, mit den vier Fuehlern auf ihrer Hoehe (`puffer/Glas`). Am Telefon lag
  // er bis dahin als Balken quer; jetzt steht dort dasselbe Glas, nur kleiner.
  const gedimmt = !vollstaendig || veraltet;
  if (kompakt) {
    return (
      <div className="home-rail">
        <Link href="/waerme" className="home-puffer-flach home-puffer-steht" aria-label={`Puffer ${soc != null ? Math.round(soc * 100) : "-"} %, ${pufferWort}`}>
          <PufferGlasBild className="home-glas-handy" temps={fuehler} breite={36} hoehe={128} schrift={13} gedimmt={gedimmt} />
          <span className="home-puffer-text">
            <span className="kicker" style={{ fontSize: 11 }}>Puffer</span>
            <span className="mono home-puffer-zahl">
              {soc != null ? String(Math.round(soc * 100)) : "-"} <span className="home-einheit">%</span>
            </span>
            <span className="home-puffer-wort">{zustand}</span>
          </span>
        </Link>
        {/* Am Handy das Bild der nächsten 24 Stunden statt dreier Uhrzeiten untereinander. */}
        <Ausblick plan={plan} nowMs={nowMs} warnung={plan?.planner_warn_de} />
      </div>
    );
  }

  return (
    <div className="home-rail">
      <Link href="/waerme" className="home-kachel home-kachel-puffer" aria-label={`Puffer ${soc != null ? Math.round(soc * 100) : "-"} %, ${pufferWort}`}>
        <PufferGlasBild className="home-glas" temps={fuehler} breite={64} hoehe={300} schrift={15} gedimmt={gedimmt} />
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
