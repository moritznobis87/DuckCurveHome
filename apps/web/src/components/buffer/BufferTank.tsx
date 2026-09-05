"use client";

import type { BufferState, EnergySnapshot } from "@/lib/api/models";
import { celsius } from "@/lib/format";
import { Card, CardHead } from "@/components/ui/Card";

const STOPS: Array<[number, [number, number, number]]> = [
  [25, [0x1f, 0x4c, 0x66]],
  [40, [0x7f, 0xa3, 0xb3]],
  [50, [0xff, 0xd7, 0x78]],
  [60, [0xf2, 0xa9, 0x00]],
  [70, [0xe0, 0x53, 0x3d]],
];

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
const rgb = (c: [number, number, number]) => `rgb(${c[0]},${c[1]},${c[2]})`;

const STATUS_DE: Record<string, string> = { cold: "kalt", partial: "teilgeladen", warm: "warm", full: "voll geladen", unknown: "unbekannt" };

export function BufferTank({ snapshot, buffer, targetSoc = 0.85 }: { snapshot: EnergySnapshot | null; buffer: BufferState | null; targetSoc?: number }) {
  const temps = snapshot ? [snapshot.buffer_temps_c.top, snapshot.buffer_temps_c.mid_top, snapshot.buffer_temps_c.mid_bottom, snapshot.buffer_temps_c.bottom] : [];
  const TW = 84;
  const TH = 176;
  const x0 = 14;
  const y0 = 8;
  const ys = [0.12, 0.37, 0.63, 0.88].map((f) => y0 + TH * f);
  const usable = temps.every((m) => m.value !== null && (m.quality === "ok" || m.quality === "derived"));
  const socPct = buffer?.soc != null ? Math.round(buffer.soc * 100) : null;
  return (
    <Card style={{ gridColumn: "span 3", minHeight: 0 }}>
      <CardHead title="Pufferspeicher" right="800 l" />
      <div className="mt-1 flex min-h-0 flex-1 items-center justify-center">
        <svg viewBox={`0 0 200 ${TH + 16}`} width="100%" height="100%" style={{ display: "block", maxWidth: 320 }} role="img" aria-label="Pufferspeicher mit vier Temperaturmesspunkten">
          <defs>
            <linearGradient id="tank" x1="0" y1="0" x2="0" y2="1">
              {temps.map((m, i) => (
                <stop key={i} offset={((ys[i]! - y0) / TH).toFixed(3)} stopColor={usable ? heatColor(m.value ?? 20) : "var(--surface-3)"} />
              ))}
            </linearGradient>
          </defs>
          <rect x={x0} y={y0} width={TW} height={TH} rx={6} fill="url(#tank)" />
          <rect x={x0} y={y0} width={TW} height={TH} rx={6} fill="none" stroke="var(--line-2)" strokeWidth={2} />
          <rect x={x0 + 8} y={y0 + 8} width={TW - 16} height={TH - 16} rx={3} fill="none" stroke="rgba(8,36,49,.35)" strokeWidth={1} />
          <line x1={x0 - 6} y1={y0 + TH * (1 - targetSoc)} x2={x0} y2={y0 + TH * (1 - targetSoc)} stroke="var(--amber)" strokeWidth={1.5} />
          {temps.map((m, i) => {
            const bad = m.value === null || m.quality !== "ok";
            return (
              <g key={i}>
                <line x1={x0 + TW} y1={ys[i]} x2={x0 + TW + 12} y2={ys[i]} stroke="var(--line-2)" strokeWidth={1} />
                <text x={x0 + TW + 18} y={ys[i]! + 7} className="mono" style={{ fontSize: 19 }} fill={bad ? "var(--text-3)" : "var(--text-1)"}>
                  {m.value === null ? "–" : Math.round(m.value)}
                  <tspan style={{ fontSize: 11 }} fill="var(--text-3)" dx={3}>°C</tspan>
                </text>
              </g>
            );
          })}
        </svg>
      </div>
      <div className="mt-1.5 flex items-baseline gap-2">
        <span className="mono text-[36px] leading-none tracking-[-.03em] text-text-1">{socPct ?? "–"}</span>
        <span className="text-[14px] text-text-3">%</span>
        <span className="mono ml-auto text-[12px] uppercase tracking-[.1em]" style={{ color: buffer?.status === "unknown" ? "var(--text-3)" : "var(--amber)" }}>
          {STATUS_DE[buffer?.status ?? "unknown"]}
        </span>
      </div>
      <div className="mt-2 flex justify-between text-[12px] text-text-3">
        <span>Nutzbar {buffer?.usable_energy_kwh != null ? `${buffer.usable_energy_kwh.toFixed(1).replace(".", ",")} kWh` : "–"}</span>
        <span>Ziel {Math.round(targetSoc * 100)} % · {celsius(50)}</span>
      </div>
    </Card>
  );
}
