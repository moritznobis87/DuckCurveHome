"use client";

import type { Decision, LiveState, Plan } from "@/lib/api/models";
import { celsius, hhmm, kw, kwh } from "@/lib/format";
import { Card, CardHead } from "@/components/ui/Card";
import { STATE_DE, nextExpectedLine, reasonLines } from "./reasons";

function Block({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-[5px]">
      <div className="kicker" style={{ fontSize: 11 }}>{title}</div>
      {children}
    </div>
  );
}

function Pair({ k, v }: { k: string; v: string }) {
  return (
    <span className="whitespace-nowrap">
      <span className="text-text-3">{k}</span> <span className="mono text-text-1">{v}</span>
    </span>
  );
}

function Row({ k, v, href }: { k: string; v: string; href?: string }) {
  const label = href ? (
    <a href={href} className="text-[13px] text-text-3 underline decoration-line-2 underline-offset-[3px]">
      {k} ›
    </a>
  ) : (
    <span className="text-[13px] text-text-3">{k}</span>
  );
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-line-1 pb-[2px]">
      {label}
      <span className="mono whitespace-nowrap text-[14px] text-text-1">{v}</span>
    </div>
  );
}

export function EnergyPlanCard({ state, plan }: { state: LiveState | null; plan: Plan | null }) {
  const d: Decision | null = state?.decision ?? null;
  const s = state?.snapshot;
  const override = state?.operating_mode.override;
  const running = state?.heat_pump.running;
  const nextCheap = plan?.next_cheap_window;
  const batKw = s?.battery_power_kw.value != null && (s.battery_power_kw.quality === "ok" || s.battery_power_kw.quality === "derived") ? -s.battery_power_kw.value : 0;
  const nextPv = plan?.windows.find((w) => w.kind === "pv_surplus" && new Date(w.end).getTime() > Date.now());
  const decisionKicker = override ? `Manuell bis ${hhmm(override.ends_at)}` : "Entscheidung";
  return (
    <Card accent style={{ gridColumn: "span 4", minHeight: 0 }}>
      <CardHead title="Energy Plan" right={d ? `Entscheidung ${hhmm(d.at)}` : "–"} />
      <div className="plan-blocks mt-2.5 flex min-h-0 flex-col overflow-hidden">
        <Block title="Jetzt">
          <div className="flex gap-3 overflow-hidden text-[12px]">
            <Pair k="PV" v={`${kw(s?.pv_power_kw.value)} kW`} />
            <Pair k="Haus" v={`${kw(s?.house_power_kw.value)} kW`} />
            <Pair k="Netz" v={`${kw(s?.grid_power_kw.value)} kW`} />
            <Pair k="Batterie" v={s?.battery_soc.value != null ? `${Math.round(s.battery_soc.value * 100)} %` : "–"} />
            <span className="hidden min-[1400px]:inline">{batKw >= 0.05 ? <Pair k="lädt" v={`${kw(batKw)} kW`} /> : batKw <= -0.05 ? <Pair k="entlädt" v={`${kw(-batKw)} kW`} /> : null}</span>
          </div>
        </Block>
        <Block title={decisionKicker}>
          <div className="plan-decision font-semibold leading-[1.2] tracking-[-.02em] text-text-1" style={{ color: override ? "var(--amber-soft)" : undefined }}>
            {d?.explanation_de ?? "Warte auf erste Entscheidung …"}
          </div>
          <div className="mono whitespace-nowrap text-[12px] text-text-3">
            {running && state?.heat_pump.running_since ? `läuft seit ${hhmm(state.heat_pump.running_since)}` : state?.heat_pump.stopped_since ? `steht seit ${hhmm(state.heat_pump.stopped_since)}` : ""}
            {d?.controller_state ? ` · ${STATE_DE[d.controller_state] ?? d.controller_state}` : ""}
          </div>
        </Block>
        <Block title="Grund">
          <div className="flex flex-col gap-[3px]">
            {(d ? reasonLines(d) : []).map((t) => (
              <div key={t} className="flex items-start gap-2.5">
                <span className="mt-[9px] h-px w-[11px] shrink-0 bg-amber" />
                <span className="truncate text-[13px] leading-[1.4] text-text-2">{t}</span>
              </div>
            ))}
          </div>
        </Block>
        <Block title="Ziel & Ausblick">
          <div className="flex flex-col gap-1">
            {d && nextExpectedLine(d) ? <Row k="Nächster Schritt" v={nextExpectedLine(d)!} /> : null}
            {nextPv ? <Row k="PV-Überschuss erwartet" v={`${hhmm(nextPv.start)}–${hhmm(nextPv.end)}`} /> : null}
            {nextCheap ? <Row k="Nächstes Preistief" v={`${hhmm(nextCheap.start)}–${hhmm(nextCheap.end)} · ${nextCheap.avg_ct_kwh?.toFixed(1).replace(".", ",")} ct`} /> : null}
            <Row k="PV-Prognose heute · Außen" href="/prognose" v={`${plan ? kwh(plan.pv_forecast_today_kwh) : "–"} · ${celsius(s?.outdoor_temp_c.value, 1)}`} />
          </div>
        </Block>
      </div>
    </Card>
  );
}
