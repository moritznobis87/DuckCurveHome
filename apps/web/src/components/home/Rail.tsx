"use client";

import Link from "next/link";
import type { LiveState, Plan, PlanInterval, RoomsLive } from "@/lib/api/models";
import { celsius, hhmm } from "@/lib/format";
import { BAND_K } from "@/components/rooms/palette";

/**
 * Die Leiste rechts neben dem Fluss: drei Dinge, die nicht Strom sind, und der Plan.
 *
 * Puffer, Raeume, Strompreis. Dazu die naechsten 24 Stunden in drei Zeilen, weil die Frage
 * „was hat das Haus vor" sonst nur im Satz oben beantwortet waere, und der sagt nur das Naechste.
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

function priceWort(rank: number | null | undefined): string {
  if (rank == null) return "kein Preisrang";
  if (rank <= 0.25) return "günstigstes Viertel";
  if (rank <= 0.5) return "eher günstig";
  if (rank <= 0.75) return "eher teuer";
  return "teuerstes Viertel";
}

function Kachel({ href, kicker, value, unit, wort, children }: { href?: string; kicker: string; value: string; unit: string; wort: string; children?: React.ReactNode }) {
  const inner = (
    <>
      {children}
      <span className="flex min-w-0 flex-col gap-1">
        <span className="kicker" style={{ fontSize: 11 }}>{kicker}</span>
        <span className="mono home-rail-zahl text-text-1">
          {value} <span className="home-einheit">{unit}</span>
        </span>
        <span className="truncate text-[12px] text-text-2">{wort}</span>
      </span>
    </>
  );
  const cls = "home-kachel flex items-center gap-3.5";
  return href ? <Link href={href} className={cls}>{inner}</Link> : <div className={cls}>{inner}</div>;
}

export function Rail({ state, plan, rooms, nowMs }: { state: LiveState | null; plan: Plan | null; rooms: RoomsLive | null; nowMs: number }) {
  const s = state?.snapshot;
  const buffer = state?.buffer;
  const temps = s ? [s.buffer_temps_c.top, s.buffer_temps_c.mid_top, s.buffer_temps_c.mid_bottom, s.buffer_temps_c.bottom] : [];
  const haveTemps = temps.length > 0 && temps.every((m) => m.value !== null);
  const verlauf = haveTemps ? `linear-gradient(180deg, ${temps.map((m, i) => `${heatColor(m.value ?? 20)} ${[8, 37, 63, 92][i]}%`).join(", ")})` : "var(--surface-3)";
  const fuehler: Array<[string, number | null]> = [["oben", temps[0]?.value ?? null], ["", temps[1]?.value ?? null], ["", temps[2]?.value ?? null], ["unten", temps[3]?.value ?? null]];
  const soc = buffer?.soc ?? null;
  const pufferWort = `${celsius(s?.buffer_temps_c.top.value)} oben${state?.heat_pump.running ? ", lädt" : buffer?.status === "full" ? ", voll" : ""}`;

  // Raeume: Mittel der gemessenen, und der Raum, der am weitesten unter seinem Ziel liegt.
  const gemessen = (rooms?.rooms ?? []).filter((r) => r.temp_c != null);
  const mittel = gemessen.length ? gemessen.reduce((a, r) => a + (r.temp_c as number), 0) / gemessen.length : null;
  const kaeltester = gemessen.filter((r) => r.deviation_k != null && r.deviation_k < -BAND_K).sort((a, b) => (a.deviation_k as number) - (b.deviation_k as number))[0];
  const raeumeWort = !rooms || gemessen.length === 0 ? "keine Raumwerte" : kaeltester ? `${kaeltester.name} ${Math.abs(kaeltester.deviation_k as number).toFixed(1).replace(".", ",")} K unter Ziel` : "alle am Ziel";

  const price = s?.electricity_price_ct_kwh.value ?? null;
  const tief = plan?.next_cheap_window;
  const preisWort = tief ? `Preistief ${new Date(tief.start).getTime() <= nowMs ? "bis" : "ab"} ${hhmm(new Date(tief.start).getTime() <= nowMs ? tief.end : tief.start)}${tief.avg_ct_kwh != null ? ` · ${tief.avg_ct_kwh.toFixed(1).replace(".", ",")} ct` : ""}` : priceWort(state?.price_rank);

  const end = nowMs + 24 * 3600_000;
  const wp = phasen(plan, nowMs, end, (iv) => iv.reason_code === "planned_optimizer" && iv.planned_hp_state === "release");
  const hatWp = (plan?.intervals ?? []).some((iv) => iv.reason_code === "planned_optimizer");
  const ofen = phasen(plan, nowMs, end, (iv) => iv.planned_stove_on);
  const hatOfen = (plan?.intervals ?? []).some((iv) => iv.planned_stove_on != null);
  const zeilen: Array<[string, string]> = [];
  if (hatWp) zeilen.push(["Wärmepumpe", wp[0] ? spanne(wp[0], nowMs) : "bleibt aus"]);
  if (hatOfen) zeilen.push(["Pelletofen", ofen[0] ? spanne(ofen[0], nowMs) : "bleibt aus"]);
  if (tief) zeilen.push(["Preistief", `${hhmm(tief.start)} bis ${hhmm(tief.end)}`]);

  return (
    <div className="home-rail">
      <Link href="/waerme" className="home-kachel home-kachel-puffer" aria-label={`Puffer ${soc != null ? Math.round(soc * 100) : "-"} %, ${pufferWort}`}>
        <span className="home-tank" style={{ background: verlauf, opacity: haveTemps ? 1 : 0.5 }} aria-hidden>
          {[25, 50, 75].map((y) => <span key={y} className="home-tank-marke" style={{ top: `${y}%` }} />)}
        </span>
        <span className="home-tank-fuehler" aria-hidden>
          {fuehler.map(([wort, v], i) => (
            <span key={i} className="flex items-baseline gap-1.5">
              <span className="mono">{celsius(v, 0)}</span>
              {wort ? <span className="text-[10px] text-text-3">{wort}</span> : null}
            </span>
          ))}
        </span>
        <span className="flex min-w-0 flex-col justify-center gap-1">
          <span className="kicker" style={{ fontSize: 11 }}>Puffer</span>
          <span className="mono home-rail-zahl text-text-1">
            {soc != null ? String(Math.round(soc * 100)) : "-"} <span className="home-einheit">%</span>
          </span>
          <span className="text-[12px] text-text-2">{state?.heat_pump.running ? "lädt" : buffer?.status === "full" ? "voll" : buffer?.status === "cold" ? "kalt" : buffer?.status === "warm" ? "warm" : "hält"}</span>
        </span>
      </Link>
      <Kachel href="/waerme/raeume" kicker="Räume" value={mittel != null ? mittel.toFixed(1).replace(".", ",") : "-"} unit="°C" wort={raeumeWort} />
      <Kachel href="/strom" kicker="Strompreis" value={price != null ? price.toFixed(1).replace(".", ",") : "-"} unit="ct" wort={preisWort} />
      {zeilen.length ? (
        <div className="home-kachel home-kachel-plan flex flex-col gap-1.5">
          <span className="kicker" style={{ fontSize: 11 }}>Nächste 24 h</span>
          {zeilen.map(([k, v]) => (
            <span key={k} className="flex justify-between gap-2 text-[12px] text-text-2">
              <span>{k}</span>
              <span className="mono text-text-1">{v}</span>
            </span>
          ))}
          {plan?.planner_warn_de ? <span className="text-[11px]" style={{ color: "var(--amber-soft)" }}>{plan.planner_warn_de}</span> : null}
        </div>
      ) : null}
    </div>
  );
}
