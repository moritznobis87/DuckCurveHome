"use client";

import { useMemo } from "react";
import type { EnergySnapshot, Measurement } from "@/lib/api/models";
import { ageLabel, kw } from "@/lib/format";
import { Card, CardHead } from "@/components/ui/Card";
import { Icon } from "@/components/ui/Icon";

type NodeKey = "pv" | "grid" | "house" | "bat" | "hp" | "ev";
const R = 34;
const W = 500;
const H = 340;
const NODES: Record<NodeKey, { x: number; y: number; label: string; icon: string; color: string }> = {
  pv: { x: 250, y: 40, label: "PV", icon: "sun", color: "var(--pv)" },
  grid: { x: 60, y: 160, label: "Netz", icon: "grid", color: "var(--grid-in)" },
  house: { x: 250, y: 160, label: "Haus", icon: "home", color: "var(--text-1)" },
  bat: { x: 440, y: 160, label: "Batterie", icon: "battery", color: "var(--battery)" },
  hp: { x: 130, y: 270, label: "Wärmepumpe", icon: "pump", color: "var(--heat-pump)" },
  ev: { x: 370, y: 270, label: "Wallbox", icon: "car", color: "var(--ev)" },
};

function Edge({ from, to, kwValue, color, minFlow = 0.05 }: { from: NodeKey; to: NodeKey; kwValue: number; color: string; minFlow?: number }) {
  const a = NODES[from];
  const b = NODES[to];
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const len = Math.hypot(dx, dy);
  const ux = dx / len;
  const uy = dy / len;
  const x1 = a.x + ux * (R + 2);
  const y1 = a.y + uy * (R + 2);
  const x2 = b.x - ux * (R + 2);
  const y2 = b.y - uy * (R + 2);
  const active = kwValue >= minFlow;
  const width = active ? Math.min(5, 2 + kwValue * 0.5) : 2;
  const dur = kwValue > 3 ? "1.8s" : kwValue > 0.5 ? "2.8s" : "4s";
  return (
    <g>
      <line x1={x1} y1={y1} x2={x2} y2={y2} stroke={color} strokeOpacity={0.22} strokeWidth={width} strokeLinecap="round" />
      {active ? (
        <line className="flow-dots" x1={x1} y1={y1} x2={x2} y2={y2} stroke={color} strokeWidth={width} strokeLinecap="round" strokeDasharray="6 10" style={{ "--flow-dur": dur } as React.CSSProperties} />
      ) : null}
    </g>
  );
}

function Node({ k, value, unit, m, nowMs, sub }: { k: NodeKey; value: string; unit: string; m: Measurement | null; nowMs: number; sub?: string }) {
  const n = NODES[k];
  const dim = !m || m.quality === "stale" || m.quality === "unavailable" || m.quality === "unknown";
  const age = m ? ageLabel(m.observed_at, nowMs) : null;
  const col = dim ? "var(--text-3)" : n.color;
  const right = k === "pv";
  const tx = right ? n.x + R + 14 : n.x;
  const anchor = right ? "start" : "middle";
  const ty1 = right ? n.y + 2 : n.y + R + 24;
  const ty2 = right ? n.y + 20 : n.y + R + 42;
  return (
    <g>
      <circle cx={n.x} cy={n.y} r={R} fill="var(--petrol)" stroke={col} strokeOpacity={dim ? 0.35 : 0.55} strokeWidth={2} />
      <g transform={`translate(${n.x - 11},${n.y - 11})`}>
        <Icon name={n.icon} size={22} color={col} />
      </g>
      <text x={tx} y={ty1} textAnchor={anchor} className="mono" style={{ fontSize: 22, letterSpacing: "-.02em" }} fill={dim ? "var(--text-3)" : "var(--text-1)"}>
        {m && m.value === null ? "–" : value}
        <tspan style={{ fontFamily: "var(--font-sans)", fontSize: 12 }} fill="var(--text-3)" dx={4}>{unit}</tspan>
      </text>
      <text x={tx} y={ty2} textAnchor={anchor} style={{ fontFamily: "var(--font-sans)", fontSize: 12 }} fill="var(--text-3)">
        {n.label}{sub ? ` · ${sub}` : ""}{age ? ` · ${age}` : ""}
      </text>
    </g>
  );
}

export function EnergyFlow({ snapshot, nowMs }: { snapshot: EnergySnapshot | null; nowMs: number }) {
  const v = useMemo(() => {
    const s = snapshot;
    const num = (m?: Measurement | null) => (m && m.value !== null && (m.quality === "ok" || m.quality === "derived") ? m.value : 0);
    const pv = num(s?.pv_power_kw);
    const grid = num(s?.grid_power_kw);
    const bat = num(s?.battery_power_kw);
    const hp = num(s?.heat_pump_power_kw);
    const ev = num(s?.ev_power_kw);
    const house = num(s?.house_power_kw);
    return {
      pvToHouse: Math.min(pv, house + Math.max(0, -bat)),
      exportKw: Math.max(0, -grid),
      importKw: Math.max(0, grid),
      charge: Math.max(0, -bat),
      discharge: Math.max(0, bat),
      hp,
      ev,
      house,
    };
  }, [snapshot]);
  const s = snapshot;
  const residual = s?.balance_residual_kw ?? 0;
  const consistent = Math.abs(residual) <= 0.3;
  return (
    <Card style={{ gridColumn: "span 5", minHeight: 0 }}>
      <CardHead title="Energiefluss" right={consistent ? `Bilanz konsistent · ±${kw(Math.abs(residual))} kW` : `Messabweichung ${kw(residual)} kW`} />
      <div className="mt-1.5 flex min-h-0 flex-1 items-center justify-center">
        <svg viewBox={`0 0 ${W} ${H}`} height="100%" style={{ display: "block", maxWidth: "100%", overflow: "visible" }} role="img" aria-label="Energiefluss zwischen PV, Netz, Haus, Batterie, Wärmepumpe und Wallbox">
          <Edge from="pv" to="house" kwValue={v.pvToHouse} color="var(--pv)" />
          {v.exportKw >= v.importKw ? (
            <Edge from="house" to="grid" kwValue={v.exportKw} color="var(--grid-out)" />
          ) : (
            <Edge from="grid" to="house" kwValue={v.importKw} color="var(--grid-in)" />
          )}
          {v.charge >= v.discharge ? (
            <Edge from="house" to="bat" kwValue={v.charge} color="var(--battery)" />
          ) : (
            <Edge from="bat" to="house" kwValue={v.discharge} color="var(--battery)" />
          )}
          <Edge from="house" to="hp" kwValue={v.hp} color="var(--heat-pump)" />
          <Edge from="house" to="ev" kwValue={v.ev} color="var(--ev)" />
          <text x={155} y={149} textAnchor="middle" className="mono" style={{ fontSize: 11, letterSpacing: ".1em" }} fill="var(--text-3)">
            {v.exportKw >= 0.05 && v.exportKw >= v.importKw ? "EINSPEISUNG" : v.importKw >= 0.05 ? "BEZUG" : ""}
          </text>
          <Node k="pv" value={kw(s?.pv_power_kw.value)} unit="kW" m={s?.pv_power_kw ?? null} nowMs={nowMs} />
          <Node k="grid" value={kw(s?.grid_power_kw.value)} unit="kW" m={s?.grid_power_kw ?? null} nowMs={nowMs} />
          <Node k="house" value={kw(s?.house_power_kw.value)} unit="kW" m={s?.house_power_kw ?? null} nowMs={nowMs} />
          <Node k="bat" value={s?.battery_soc.value != null ? String(Math.round(s.battery_soc.value * 100)) : "–"} unit="%" m={s?.battery_soc ?? null} nowMs={nowMs} sub={v.charge >= 0.05 ? `lädt ${kw(v.charge)} kW` : v.discharge >= 0.05 ? `entlädt ${kw(v.discharge)} kW` : undefined} />
          <Node k="hp" value={kw(s?.heat_pump_power_kw.value)} unit="kW" m={s?.heat_pump_power_kw ?? null} nowMs={nowMs} />
          <Node k="ev" value={kw(s?.ev_power_kw.value)} unit="kW" m={s?.ev_power_kw ?? null} nowMs={nowMs} />
        </svg>
      </div>
    </Card>
  );
}
