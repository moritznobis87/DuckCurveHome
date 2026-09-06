"use client";

import { useRouter } from "next/navigation";
import { useMemo } from "react";
import type { EnergySnapshot, Measurement } from "@/lib/api/models";
import { ageLabel, kw } from "@/lib/format";
import { Card, CardHead } from "@/components/ui/Card";
import { Icon } from "@/components/ui/Icon";

type NodeKey = "pv" | "grid" | "house" | "bat" | "hp" | "ev";
// Die Zeichenfläche wird auf die verfügbare Höhe skaliert. Je kleiner die Einheiten gegenüber der
// Zeichenfläche, desto kleiner die Schrift auf dem Schirm – deshalb sind Knoten und Beschriftung
// bewusst groß gegenüber W/H gehalten, und die Zeilen liegen weit genug auseinander dafür.
const R = 40;
const W = 500;
const H = 410;
const ICON = 26;
const NODES: Record<NodeKey, { x: number; y: number; label: string; icon: string; color: string; href: string }> = {
  pv: { x: 250, y: 48, label: "PV", icon: "sun", color: "var(--pv)", href: "/pv" },
  grid: { x: 60, y: 170, label: "Netz", icon: "grid", color: "var(--grid-in)", href: "/haus" },
  house: { x: 250, y: 170, label: "Haus", icon: "home", color: "var(--text-1)", href: "/haus" },
  bat: { x: 440, y: 170, label: "Batterie", icon: "battery", color: "var(--battery)", href: "/batterie" },
  hp: { x: 130, y: 310, label: "Wärmepumpe", icon: "pump", color: "var(--heat-pump)", href: "/waerme" },
  ev: { x: 370, y: 310, label: "Wallbox", icon: "car", color: "var(--ev)", href: "/wallbox" },
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
  const width = active ? Math.min(6, 2.5 + kwValue * 0.5) : 2.5;
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

function Node({ k, value, unit, m, nowMs, sub, onOpen }: { k: NodeKey; value: string; unit: string; m: Measurement | null; nowMs: number; sub?: string; onOpen: (href: string) => void }) {
  const n = NODES[k];
  const dim = !m || m.quality === "stale" || m.quality === "unavailable" || m.quality === "unknown";
  const age = m ? ageLabel(m.observed_at, nowMs) : null;
  const col = dim ? "var(--text-3)" : n.color;
  const right = k === "pv";
  const tx = right ? n.x + R + 16 : n.x;
  const anchor = right ? "start" : "middle";
  const ty1 = right ? n.y - 2 : n.y + R + 28;
  const ty2 = right ? n.y + 22 : n.y + R + 52;
  return (
    <g className="flow-node" role="link" tabIndex={0} aria-label={`${n.label} – Details öffnen`} style={{ cursor: "pointer" }} onClick={() => onOpen(n.href)} onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") onOpen(n.href); }}>
      <circle cx={n.x} cy={n.y} r={R + 10} fill="transparent" />
      <circle cx={n.x} cy={n.y} r={R} fill="var(--petrol)" stroke={col} strokeOpacity={dim ? 0.35 : 0.55} strokeWidth={2} />
      <g transform={`translate(${n.x - ICON / 2},${n.y - ICON / 2})`}>
        <Icon name={n.icon} size={ICON} color={col} />
      </g>
      <text x={tx} y={ty1} textAnchor={anchor} className="mono" style={{ fontSize: 28, letterSpacing: "-.02em" }} fill={dim ? "var(--text-3)" : "var(--text-1)"}>
        {m && m.value === null ? "–" : value}
        <tspan style={{ fontFamily: "var(--font-sans)", fontSize: 15 }} fill="var(--text-3)" dx={5}>{unit}</tspan>
      </text>
      <text x={tx} y={ty2} textAnchor={anchor} style={{ fontFamily: "var(--font-sans)", fontSize: 15 }} fill="var(--text-3)">
        {n.label}{sub ? ` · ${sub}` : ""}{age ? ` · ${age}` : ""}
        <tspan fill="var(--amber)" dx={4}>›</tspan>
      </text>
    </g>
  );
}

export function EnergyFlow({ snapshot, nowMs }: { snapshot: EnergySnapshot | null; nowMs: number }) {
  const router = useRouter();
  const open = (href: string) => router.push(href);
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
    <Card className="dash-flow" style={{ gridColumn: "span 5", minHeight: 0 }}>
      <CardHead title="Energiefluss" right={consistent ? `Bilanz konsistent · ±${kw(Math.abs(residual))} kW` : `Messabweichung ${kw(residual)} kW`} />
      <div className="mt-1.5 flex min-h-0 flex-1 items-center justify-center">
        <svg viewBox={`0 0 ${W} ${H}`} width="100%" height="100%" preserveAspectRatio="xMidYMid meet" style={{ display: "block", overflow: "visible" }} role="img" aria-label="Energiefluss zwischen PV, Netz, Haus, Batterie, Wärmepumpe und Wallbox">
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
          <text x={155} y={157} textAnchor="middle" className="mono" style={{ fontSize: 13, letterSpacing: ".1em" }} fill="var(--text-3)">
            {v.exportKw >= 0.05 && v.exportKw >= v.importKw ? "EINSPEISUNG" : v.importKw >= 0.05 ? "BEZUG" : ""}
          </text>
          <Node k="pv" value={kw(s?.pv_power_kw.value)} unit="kW" m={s?.pv_power_kw ?? null} nowMs={nowMs} onOpen={open} />
          <Node k="grid" value={kw(s?.grid_power_kw.value)} unit="kW" m={s?.grid_power_kw ?? null} nowMs={nowMs} onOpen={open} />
          <Node k="house" value={kw(s?.house_power_kw.value)} unit="kW" m={s?.house_power_kw ?? null} nowMs={nowMs} onOpen={open} />
          <Node k="bat" value={s?.battery_soc.value != null ? String(Math.round(s.battery_soc.value * 100)) : "–"} unit="%" m={s?.battery_soc ?? null} nowMs={nowMs} sub={v.charge >= 0.05 ? `lädt ${kw(v.charge)} kW` : v.discharge >= 0.05 ? `entlädt ${kw(v.discharge)} kW` : undefined} onOpen={open} />
          <Node k="hp" value={kw(s?.heat_pump_power_kw.value)} unit="kW" m={s?.heat_pump_power_kw ?? null} nowMs={nowMs} onOpen={open} />
          <Node k="ev" value={kw(s?.ev_power_kw.value)} unit="kW" m={s?.ev_power_kw ?? null} nowMs={nowMs} onOpen={open} />
        </svg>
      </div>
    </Card>
  );
}
