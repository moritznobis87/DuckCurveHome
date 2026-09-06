"use client";

import { useEffect, useState } from "react";
import { useLiveStore } from "@/lib/live/store";
import { hhmm, longDate } from "@/lib/format";
import { Pill } from "@/components/ui/Pill";
import { Dot } from "@/components/ui/Dot";
import { Icon } from "@/components/ui/Icon";
import { useIsMobile } from "@/lib/useIsMobile";

function Mark({ height = 26 }: { height?: number }) {
  const bars: Array<[number, number]> = [[54,202],[76,196],[98,195],[120,198],[142,204],[164,211],[186,216],[208,218],[230,216],[252,211],[274,201],[296,188],[318,171],[340,151],[362,130],[384,113],[406,101],[428,111],[450,124],[472,136],[494,123],[516,109],[538,119],[560,126]];
  const width = Math.round((height * 520) / 275);
  return (
    <svg width={width} height={height} viewBox="40 -5 530 280" aria-label="Duck Curve">
      <g stroke="var(--mist)" strokeWidth={7} strokeLinecap="round" opacity={0.96}>
        {bars.map(([x, y]) => <line key={x} x1={x} y1={y} x2={x} y2={270} />)}
      </g>
      <path d="M48 171 C104 118 146 181 206 183 C300 186 316 112 369 37 C395 0 437 7 447 42 C453 63 470 67 499 72 C478 83 460 84 441 94" fill="none" stroke="var(--amber)" strokeWidth={16} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export function Header() {
  const state = useLiveStore((s) => s.state);
  const connection = useLiveStore((s) => s.connection);
  const offset = useLiveStore((s) => s.serverOffsetMs);
  const [now, setNow] = useState<Date | null>(null);
  const isMobile = useIsMobile();
  useEffect(() => {
    const t = setInterval(() => setNow(new Date(Date.now() + offset)), 1000);
    setNow(new Date(Date.now() + offset));
    return () => clearInterval(t);
  }, [offset]);

  const mode = state?.operating_mode;
  const override = mode?.override;
  const modeLabel = override
    ? `Manuell bis ${hhmm(override.ends_at)}`
    : mode?.system_mode === "off"
      ? "Aus · Beobachten"
      : `Auto · ${mode?.auto_profile ?? "smart"}`;
  const conn = { live: ["ok", "live"], connecting: ["muted", "verbinde"], reconnecting: ["warn", "verbindung…"], offline: ["alert", "offline"] }[connection] as ["ok" | "warn" | "alert" | "muted", string];
  const speed = state?.system.sim_speed ?? 1;

  return (
    <header className="dash-header flex h-14 shrink-0 items-center justify-between rounded-[3px] border border-line-2 px-5" style={{ background: "var(--surface-glass)", backdropFilter: "blur(18px)" }}>
      <div className="flex items-center gap-3.5">
        <Mark />
        <div className="flex items-baseline gap-2.5">
          <span className="text-[17px] font-semibold tracking-[-.02em] text-text-1">Duck Curve</span>
          <span className="kicker" style={{ fontSize: 12 }}>Home</span>
        </div>
      </div>
      <div className="mono text-[15px] text-text-2 tracking-[.02em]" suppressHydrationWarning>
        {now ? (isMobile ? hhmm(now) : `${longDate(now)} · ${hhmm(now)}`) : ""}
        {state?.system.mode === "demo" ? <span className="ml-3 text-text-3 text-[12px] uppercase tracking-[.1em]">Demo{speed !== 1 ? ` · ${speed}×` : ""}</span> : null}
      </div>
      <div className="dash-header-actions flex items-center gap-4">
        <div className="flex items-center gap-2.5">
          <Dot tone={conn[0]} pulse={connection === "live"} />
          <span className="kicker" style={{ fontSize: 12, color: "var(--text-3)" }}>{conn[1]}</span>
        </div>
        <Pill tone={override ? "alert" : mode?.system_mode === "off" ? "neutral" : "amber"}>{modeLabel}</Pill>
        <a href="/prognose" aria-label="Prognose-Auswertung" title="Prognose-Auswertung" className="flex h-9 w-9 items-center justify-center rounded-[3px] border border-line-2">
          <Icon name="chart" size={18} color="var(--text-3)" />
        </a>
        <a href="/settings" aria-label="Einstellungen" className="flex h-9 w-9 items-center justify-center rounded-[3px] border border-line-2">
          <Icon name="gear" size={18} color="var(--text-3)" />
        </a>
      </div>
    </header>
  );
}
