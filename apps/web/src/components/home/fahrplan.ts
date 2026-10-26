import type { Plan, PlanInterval } from "@/lib/api/models";
import { hhmm } from "@/lib/format";

/**
 * Was das Haus in den nächsten 24 Stunden vorhat, in Zeilen.
 *
 * **Warum eigenes Modul.** Dieselben Zeilen stehen an drei Stellen: in der Leiste neben dem
 * Energiefluss, im Ambiente am Abend und - wenn es eng wird - nirgends. Vorher standen sie in
 * `Rail.tsx`, und das Ambiente hätte sie ein zweites Mal gerechnet.
 *
 * **Eine Phase ist eine Folge von Viertelstunden.** Der Fahrplan kommt als Raster; was ihn
 * interessant macht, sind die zusammenhängenden Stücke darin („23:15 bis 02:00"), nicht die
 * einzelnen Schritte. Eine Zeile entsteht nur, wenn der Plan die Sache überhaupt kennt: Steht
 * nichts über den Pelletofen darin, ist „bleibt aus" eine Behauptung, nicht eine Auskunft.
 */
const STEP_MS = 15 * 60_000;

export interface Phase {
  start: number;
  end: number;
}

/** Zusammenhängende Phasen aus den Viertelstundenschritten des Fahrplans. */
export function phasen(plan: Plan | null, nowMs: number, end: number, an: (iv: PlanInterval) => boolean | null | undefined): Phase[] {
  const out: Phase[] = [];
  let offen: Phase | null = null;
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

/** „bis 02:00", solange die Phase läuft, sonst „23:15 bis 02:00". */
export function spanne(p: Phase, nowMs: number): string {
  return p.start <= nowMs ? `bis ${hhmm(new Date(p.end))}` : `${hhmm(new Date(p.start))} bis ${hhmm(new Date(p.end))}`;
}

export function planZeilen(plan: Plan | null, nowMs: number): Array<[string, string]> {
  const end = nowMs + 24 * 3600_000;
  const wp = phasen(plan, nowMs, end, (iv) => iv.reason_code === "planned_optimizer" && iv.planned_hp_state === "release");
  const hatWp = (plan?.intervals ?? []).some((iv) => iv.reason_code === "planned_optimizer");
  const ofen = phasen(plan, nowMs, end, (iv) => iv.planned_stove_on);
  const hatOfen = (plan?.intervals ?? []).some((iv) => iv.planned_stove_on != null);
  const tief = plan?.next_cheap_window;
  const zeilen: Array<[string, string]> = [];
  if (hatWp) zeilen.push(["Wärmepumpe", wp[0] ? spanne(wp[0], nowMs) : "bleibt aus"]);
  if (hatOfen) zeilen.push(["Pelletofen", ofen[0] ? spanne(ofen[0], nowMs) : "bleibt aus"]);
  if (tief) zeilen.push(["Preistief", `${hhmm(tief.start)} bis ${hhmm(tief.end)}`]);
  return zeilen;
}
