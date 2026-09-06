"use client";

import type { Decision, LiveState, Plan, PriceWindow } from "@/lib/api/models";
import { celsius, hhmm, kw, kwh } from "@/lib/format";
import { Card, CardHead } from "@/components/ui/Card";
import { STATE_DE, nextExpectedLine, reasonLines } from "./reasons";

const SURPLUS_TARGET_KW = 4.0;
const BUFFER_TARGET = 0.85;
const HORIZON_H = 24;

const WINDOW_STYLE: Record<PriceWindow["kind"], { color: string; label: string }> = {
  pv_surplus: { color: "rgba(242,169,0,.55)", label: "PV" },
  cheap: { color: "rgba(127,163,179,.6)", label: "günstig" },
  expensive: { color: "rgba(224,83,61,.5)", label: "teuer" },
  negative: { color: "rgba(224,83,61,.8)", label: "negativ" },
};

/** Kleine Kennzahl mit Balken: Wert, Kontext, Füllstand 0–1. */
function Gauge({ label, value, unit, hint, fill, tone }: { label: string; value: string; unit?: string; hint: string; fill: number | null; tone: "amber" | "mist" | "ember" | "muted" }) {
  const color = tone === "amber" ? "var(--amber)" : tone === "mist" ? "var(--mist)" : tone === "ember" ? "var(--alert)" : "var(--text-3)";
  return (
    <div className="flex min-w-0 flex-1 flex-col gap-1 rounded-[3px] border border-line-1 bg-surface-1/40 px-2.5 py-2">
      <span className="kicker truncate" style={{ fontSize: 10 }}>{label}</span>
      <span className="mono truncate text-[18px] leading-none tracking-[-.02em] text-text-1">
        {value}
        {unit ? <span className="ml-1 text-[11px] text-text-3" style={{ fontFamily: "var(--font-sans)" }}>{unit}</span> : null}
      </span>
      <span className="h-[3px] w-full overflow-hidden rounded-full bg-line-1">
        <span className="block h-full rounded-full transition-[width] duration-500" style={{ width: `${Math.round(Math.max(0, Math.min(1, fill ?? 0)) * 100)}%`, background: color }} />
      </span>
      <span className="truncate text-[11px] leading-tight text-text-3">{hint}</span>
    </div>
  );
}

function priceLabel(rank: number | null | undefined): string {
  if (rank == null) return "kein Preisrang";
  if (rank <= 0.25) return "günstigstes Viertel";
  if (rank <= 0.5) return "eher günstig";
  if (rank <= 0.75) return "eher teuer";
  return "teuerstes Viertel";
}

/** Zeitleiste der nächsten 24 h: PV-Fenster in der oberen, Preisfenster in der unteren Spur. */
function Timeline({ plan, nowMs }: { plan: Plan | null; nowMs: number }) {
  const end = nowMs + HORIZON_H * 3600_000;
  const span = end - nowMs;
  const windows = (plan?.windows ?? []).filter((w) => new Date(w.end).getTime() > nowMs && new Date(w.start).getTime() < end);
  const lanes: Array<{ name: string; items: PriceWindow[] }> = [
    { name: "PV", items: windows.filter((w) => w.kind === "pv_surplus") },
    { name: "Preis", items: windows.filter((w) => w.kind !== "pv_surplus") },
  ];
  const ticks = [6, 12, 18];
  return (
    <div className="flex flex-col gap-1">
      {lanes.map((lane) => (
        <div key={lane.name} className="flex items-center gap-2">
          <span className="kicker w-8 shrink-0" style={{ fontSize: 9 }}>{lane.name}</span>
          <div className="relative h-[14px] flex-1 overflow-hidden rounded-[2px] bg-surface-1/60">
            {lane.items.map((w, i) => {
              const s = Math.max(nowMs, new Date(w.start).getTime());
              const e = Math.min(end, new Date(w.end).getTime());
              const st = WINDOW_STYLE[w.kind];
              const widthPct = ((e - s) / span) * 100;
              return (
                <span key={i} className="absolute inset-y-0 flex items-center overflow-hidden px-1" style={{ left: `${(((s - nowMs) / span) * 100).toFixed(2)}%`, width: `${widthPct.toFixed(2)}%`, background: st.color }} title={w.label_de}>
                  {widthPct > 10 ? <span className="mono truncate text-[9px] uppercase tracking-[.06em] text-petrol">{st.label}</span> : null}
                </span>
              );
            })}
            {ticks.map((h) => (
              <span key={h} className="absolute inset-y-0 w-px bg-line-2/70" style={{ left: `${(h / HORIZON_H) * 100}%` }} />
            ))}
          </div>
        </div>
      ))}
      <div className="mono flex justify-between pl-10 text-[10px] text-text-3">
        <span>jetzt</span>
        {ticks.map((h) => (
          <span key={h}>+{h} h</span>
        ))}
        <span>+24 h</span>
      </div>
    </div>
  );
}

export function EnergyPlanCard({ state, plan }: { state: LiveState | null; plan: Plan | null }) {
  const d: Decision | null = state?.decision ?? null;
  const s = state?.snapshot;
  const hp = state?.heat_pump;
  const override = state?.operating_mode.override;
  const nowMs = state ? new Date(state.system.server_time).getTime() : Date.now();
  const inputs = d?.inputs;

  const running = hp?.running ?? false;
  const headline = override ? (override.kind === "force_release" ? "Wärmepumpe manuell AN" : "Wärmepumpe manuell AUS") : running ? "Wärmepumpe läuft" : "Wärmepumpe aus";
  const since = running && hp?.running_since ? `seit ${hhmm(hp.running_since)}` : !running && hp?.stopped_since ? `seit ${hhmm(hp.stopped_since)}` : "";
  const stateLabel = override ? `bis ${hhmm(override.ends_at)}` : d?.controller_state ? (STATE_DE[d.controller_state] ?? d.controller_state) : "";
  const reasons = d ? reasonLines(d).slice(0, 3) : [];

  const surplus = inputs?.surplus_ewma_kw ?? null;
  const price = inputs?.price_ct_kwh ?? s?.electricity_price_ct_kwh.value ?? null;
  const rank = inputs?.price_rank ?? state?.price_rank ?? null;
  const soc = state?.buffer.soc ?? null;

  const nextCheap = plan?.next_cheap_window;
  const nextPv = plan?.windows.find((w) => w.kind === "pv_surplus" && new Date(w.end).getTime() > nowMs);
  const nextStep = d ? nextExpectedLine(d) : null;

  return (
    <Card accent className="dash-plan" style={{ gridColumn: "span 4", minHeight: 0 }}>
      <CardHead title="Energy Plan" right={d ? `Entscheidung ${hhmm(d.at)}` : "–"} />
      <div className="plan-body mt-2 flex min-h-0 flex-1 flex-col overflow-hidden">
        {/* Status: was passiert, warum – in einem Blick */}
        <div className="flex items-start gap-3">
          <span className="mt-[6px] h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: override ? "var(--amber-soft)" : running ? "var(--amber)" : "var(--text-3)", boxShadow: running ? "0 0 0 4px rgba(242,169,0,.15)" : undefined }} />
          <div className="min-w-0 flex-1">
            <div className="flex items-baseline justify-between gap-3">
              <span className="truncate text-[17px] font-semibold tracking-[-.02em] text-text-1" style={{ color: override ? "var(--amber-soft)" : undefined }}>{headline}</span>
              <span className="mono shrink-0 text-[11px] uppercase tracking-[.08em] text-text-3">{[since, stateLabel].filter(Boolean).join(" · ")}</span>
            </div>
            <div className="mt-0.5 truncate text-[13px] leading-[1.4] text-text-2">{d?.explanation_de ?? "Warte auf erste Entscheidung …"}</div>
            {reasons.length ? (
              <div className="plan-chips mt-1.5 flex flex-wrap gap-1.5">
                {reasons.map((r) => (
                  <span key={r} className="max-w-full truncate rounded-[2px] border border-line-2 px-1.5 py-[2px] text-[11px] leading-tight text-text-2">{r}</span>
                ))}
              </div>
            ) : null}
          </div>
        </div>

        {/* Die drei Größen, die die Entscheidung bestimmen */}
        <div className="flex gap-2">
          <Gauge label="PV-Überschuss" value={surplus == null ? "–" : kw(surplus)} unit="kW" hint={`Freigabe ab ${kw(SURPLUS_TARGET_KW)} kW`} fill={surplus == null ? null : surplus / SURPLUS_TARGET_KW} tone={surplus != null && surplus >= SURPLUS_TARGET_KW ? "amber" : "muted"} />
          <Gauge label="Strompreis" value={price == null ? "–" : price.toFixed(1).replace(".", ",")} unit="ct" hint={priceLabel(rank)} fill={rank == null ? null : 1 - rank} tone={rank != null && rank <= 0.25 ? "mist" : rank != null && rank >= 0.75 ? "ember" : "muted"} />
          <Gauge label="Puffer" value={soc == null ? "–" : String(Math.round(soc * 100))} unit="%" hint={`Ziel ${Math.round(BUFFER_TARGET * 100)} % · ${celsius(inputs?.buffer_top_c ?? s?.buffer_temps_c.top.value)} oben`} fill={soc} tone={soc != null && soc >= BUFFER_TARGET ? "amber" : "muted"} />
        </div>

        {/* Nächste 24 h */}
        <div className="flex shrink-0 flex-col gap-1.5">
          <Timeline plan={plan} nowMs={nowMs} />
          <div className="plan-next flex flex-wrap gap-x-4 gap-y-0.5 overflow-hidden text-[12px] text-text-2">
            {nextStep ? <span><span className="text-text-3">Nächster Schritt</span> <span className="mono text-text-1">{nextStep}</span></span> : null}
            {nextPv ? <span><span className="text-text-3">PV-Fenster</span> <span className="mono text-text-1">{hhmm(nextPv.start)}–{hhmm(nextPv.end)}</span></span> : null}
            {nextCheap ? <span><span className="text-text-3">Preistief</span> <span className="mono text-text-1">{hhmm(nextCheap.start)}–{hhmm(nextCheap.end)}{nextCheap.avg_ct_kwh != null ? ` · ${nextCheap.avg_ct_kwh.toFixed(1).replace(".", ",")} ct` : ""}</span></span> : null}
          </div>
        </div>

        <div className="mt-auto flex shrink-0 items-baseline justify-between gap-3 border-t border-line-1 pt-1.5 text-[12px]">
          <a href="/prognose" className="text-text-3 underline decoration-line-2 underline-offset-[3px]">PV-Prognose heute ›</a>
          <span className="mono text-text-1">{plan ? kwh(plan.pv_forecast_today_kwh) : "–"} · {celsius(s?.outdoor_temp_c.value, 1)} außen</span>
        </div>
      </div>
    </Card>
  );
}
