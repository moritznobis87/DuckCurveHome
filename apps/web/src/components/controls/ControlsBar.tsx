"use client";

import { useEffect, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { LiveState } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { Icon } from "@/components/ui/Icon";

const TILES: Array<{ key: string; label: string; icon: string; durationMin?: number }> = [
  { key: "coffee_machine", label: "Kaffeemaschine", icon: "coffee", durationMin: 120 },
  { key: "terrace_light", label: "Licht Terrasse", icon: "bulb" },
  { key: "courtyard_light", label: "Licht Innenhof", icon: "lights" },
  { key: "garden_fence_light", label: "Licht Gartenzaun", icon: "fence" },
];

type TileStatus = "idle" | "pending" | "error";

function ControlTile({ tile, on, onToggle }: { tile: (typeof TILES)[number]; on: boolean | null; onToggle: (next: boolean) => Promise<void> }) {
  const [status, setStatus] = useState<TileStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);
  const [optimistic, setOptimistic] = useState<boolean | null>(null);
  const shown = optimistic ?? on;
  useEffect(() => {
    if (optimistic !== null && on === optimistic) setOptimistic(null);
  }, [on, optimistic]);
  const click = async () => {
    const next = !(shown ?? false);
    setOptimistic(next);
    setStatus("pending");
    setMessage(null);
    try {
      await onToggle(next);
      setStatus("idle");
    } catch (e) {
      setOptimistic(null);
      setStatus("error");
      setMessage(e instanceof ApiError ? e.message : "Schaltung nicht bestätigt.");
      setTimeout(() => setStatus("idle"), 4000);
    }
  };
  const color = status === "error" ? "var(--alert)" : shown ? "var(--amber)" : "var(--text-3)";
  return (
    <button onClick={click} aria-pressed={shown ?? undefined} className="flex h-20 min-w-0 items-center gap-3 rounded-[3px] border border-line-1 bg-surface-2 px-3 text-left transition-transform duration-[var(--dur)] active:scale-[.99]" style={{ borderRight: `3px solid ${status === "error" ? "var(--alert)" : shown ? "var(--amber)" : "transparent"}` }}>
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-line-2 bg-petrol">
        <Icon name={tile.icon} size={22} color={color} />
      </span>
      <span className="flex min-w-0 flex-col gap-[5px]">
        <span className="truncate text-[13px] text-text-1">{tile.label}</span>
        <span className="mono truncate text-[12px] uppercase tracking-[.1em]" style={{ color }}>
          {status === "pending" ? "schalte …" : status === "error" ? message ?? "Fehler" : shown === null ? "–" : shown ? "an" : "aus"}
        </span>
      </span>
    </button>
  );
}

const DURATIONS = [30, 120, 360];

function ModeSegment({ state }: { state: LiveState | null }) {
  const mode = state?.operating_mode;
  const override = mode?.override;
  const active: "auto" | "on" | "off" = override ? (override.kind === "force_release" ? "on" : "off") : mode?.system_mode === "off" ? "off" : "auto";
  const [picker, setPicker] = useState<"on" | "off" | null>(null);
  const [busy, setBusy] = useState(false);
  const hp = state?.heat_pump;
  const send = async (body: Parameters<typeof api.setHeatPumpMode>[0]) => {
    setBusy(true);
    try {
      await api.setHeatPumpMode(body);
    } finally {
      setBusy(false);
      setPicker(null);
    }
  };
  const status = override ? `${override.kind === "force_release" ? "manuell an" : "manuell aus"} bis ${hhmm(override.ends_at)}` : hp?.running ? `läuft · ${state?.decision?.reasons[0]?.replace(/_/g, " ") ?? ""}` : "bereit";
  const Btn = ({ v, label }: { v: "auto" | "on" | "off"; label: string }) => (
    <button
      disabled={busy}
      onClick={() => (v === "auto" ? void send({ system_mode: "auto", duration_min: 120 }) : setPicker(v))}
      className="mono flex h-full flex-1 items-center justify-center border-l border-line-1 text-[13px] uppercase tracking-[.1em] transition-colors duration-[var(--dur)]"
      style={{ background: active === v ? "var(--amber)" : "transparent", color: active === v ? "var(--petrol)" : "var(--text-2)" }}
    >
      {label}
    </button>
  );
  return (
    <div className="controls-hp relative flex h-20 min-w-0 items-center gap-3 overflow-visible rounded-[3px] border border-line-1 bg-surface-2 pl-4">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-line-2 bg-petrol">
        <Icon name="pump" size={22} color={hp?.running ? "var(--heat-pump)" : "var(--text-3)"} />
      </span>
      <span className="flex w-[124px] shrink-0 flex-col gap-[5px] overflow-hidden">
        <span className="text-[14px] text-text-1">Wärmepumpe</span>
        <span className="mono truncate text-[12px] uppercase tracking-[.1em]" style={{ color: override ? "var(--amber-soft)" : hp?.running ? "var(--amber)" : "var(--text-3)" }}>{status}</span>
      </span>
      <div className="ml-2 flex h-full flex-1 overflow-hidden rounded-r-[3px]">
        <Btn v="auto" label="Auto" />
        <Btn v="on" label="An" />
        <Btn v="off" label="Aus" />
      </div>
      {picker ? (
        <div className="absolute bottom-[calc(100%+8px)] right-0 z-10 flex items-center gap-2 rounded-[3px] border border-line-2 p-2" style={{ background: "#07202c", boxShadow: "var(--shadow-sheet)" }}>
          <span className="kicker px-2" style={{ fontSize: 11 }}>{picker === "on" ? "Manuell an für" : "Manuell aus für"}</span>
          {DURATIONS.map((m) => (
            <button key={m} onClick={() => void send({ system_mode: "manual", manual_state: picker, duration_min: m })} className="mono h-11 min-w-[64px] rounded-[2px] border border-line-2 px-3 text-[13px] text-text-1 hover:bg-surface-3">
              {m < 60 ? `${m} min` : `${m / 60} h`}
            </button>
          ))}
          <button onClick={() => setPicker(null)} className="h-11 px-3 text-[13px] text-text-3">Abbrechen</button>
        </div>
      ) : null}
    </div>
  );
}

export function ControlsBar({ state }: { state: LiveState | null }) {
  const act = state?.snapshot.actuators ?? {};
  return (
    <div className="controls-grid grid shrink-0 gap-4">
      <ModeSegment state={state} />
      {TILES.map((t) => {
        const m = act[t.key];
        const on = m && m.value !== null ? m.value >= 0.5 : null;
        return (
          <ControlTile
            key={t.key}
            tile={t}
            on={on}
            onToggle={async (next) => {
              const r = await api.switchActuator(t.key, next, next ? t.durationMin : undefined);
              if (!r.ok) throw new ApiError("not_confirmed", r.message_de, 200);
            }}
          />
        );
      })}
    </div>
  );
}
