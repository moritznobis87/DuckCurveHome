"use client";

import { useEffect, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { LiveState, Measurement } from "@/lib/api/models";
import { ageLabel, hhmm } from "@/lib/format";
import { Icon } from "@/components/ui/Icon";

const TILES: Array<{ key: string; label: string; icon: string; durationMin?: number }> = [
  { key: "coffee_machine", label: "Kaffeemaschine", icon: "coffee", durationMin: 120 },
  { key: "terrace_light", label: "Licht Terrasse", icon: "bulb" },
  { key: "courtyard_light", label: "Licht Innenhof", icon: "bulb" },
  { key: "garden_fence_light", label: "Licht Gartenzaun", icon: "bulb" },
];

type TileStatus = "idle" | "pending" | "error";

function ControlTile({ tile, on, m, readOnly, onToggle }: { tile: (typeof TILES)[number]; on: boolean | null; m: Measurement | null; readOnly: boolean; onToggle: (next: boolean) => Promise<void> }) {
  const [status, setStatus] = useState<TileStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);
  const [optimistic, setOptimistic] = useState<boolean | null>(null);
  const shown = optimistic ?? on;
  useEffect(() => {
    if (optimistic !== null && on === optimistic) setOptimistic(null);
  }, [on, optimistic]);
  const click = async () => {
    // Gäste sehen den Zustand, schalten aber nicht. Die Kachel bleibt bedienbar und sagt, warum nichts
    // passiert - ein toter Knopf ohne Erklärung ist ärgerlicher als eine kurze Auskunft.
    if (readOnly) {
      setStatus("error");
      setMessage("Gastzugang · nur Ansicht");
      setTimeout(() => setStatus("idle"), 2500);
      return;
    }
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
      setTimeout(() => setStatus("idle"), 12000);
    }
  };
  const color = status === "error" ? "var(--alert)" : shown ? "var(--amber)" : "var(--text-3)";
  // Woher der Zustand stammt und wie alt er ist. Ohne das lässt sich eine falsch wirkende Kachel nicht
  // von einer eingefrorenen unterscheiden - „aus“ sieht gleich aus, ob gerade gemessen oder Stunden alt.
  const age = m ? ageLabel(m.observed_at, Date.now()) : null;
  const stale = m ? m.quality === "stale" || m.quality === "unavailable" || m.quality === "unknown" : true;
  const origin = m?.source ?? "keine Quelle";
  return (
    <button onClick={click} aria-pressed={shown ?? undefined} title={`${tile.label}: Quelle ${origin}${age ? `, Stand ${age}` : ", gerade gemessen"}`} className="flex min-h-20 min-w-0 items-center gap-3 rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2 text-left transition-transform duration-[var(--dur)] active:scale-[.99]" style={{ borderRight: `3px solid ${status === "error" ? "var(--alert)" : shown ? "var(--amber)" : "transparent"}` }}>
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-line-2 bg-petrol">
        <Icon name={tile.icon} size={22} color={color} />
      </span>
      <span className="flex min-w-0 flex-col gap-[5px]">
        <span className="truncate text-[13px] text-text-1">{tile.label}</span>
        {/* Im Fehlerfall zählt der Grund: bis zu drei Zeilen, vollständig im title-Attribut. */}
        <span
          className={`mono text-[12px] uppercase tracking-[.1em] ${status === "error" ? "line-clamp-3 leading-[1.25]" : "truncate"}`}
          style={{ color }}
          title={status === "error" ? message ?? "Fehler" : undefined}
        >
          {status === "pending" ? "schalte …" : status === "error" ? message ?? "Fehler" : shown === null ? "-" : shown ? "an" : "aus"}
          {status === "idle" && age ? <span style={{ color: stale ? "var(--alert)" : "var(--text-3)" }}> · {age}</span> : null}
        </span>
      </span>
    </button>
  );
}

/**
 * Ein Gerät, das DCH führen kann: Symbol, Zustandszeile, darunter Auto | An | Aus.
 *
 * Zwei davon passen nur nebeneinander, weil der ausgeschriebene Gerätename der Zustandszeile weicht.
 * Das ist kein reiner Platzgewinn: der Name ändert sich nie, der Zustand dauernd, und die Leiste soll
 * im Vorbeigehen lesbar sein. Wer den Namen braucht, findet ihn im Titel des Symbols und in der
 * Vorlesehilfe.
 */
type Mode = "auto" | "on" | "off";

function DeviceSegment({
  icon,
  label,
  active,
  activeColor,
  status,
  statusColor,
  title,
  disabled,
  disabledNote,
  durations,
  pickerLabel,
  onSet,
}: {
  icon: string;
  label: string;
  active: Mode;
  activeColor: string;
  status: string;
  statusColor: string;
  title: string;
  disabled?: boolean;
  disabledNote?: string;
  durations: number[];
  pickerLabel: (m: Mode) => string;
  onSet: (mode: Mode, durationMin: number) => Promise<void>;
}) {
  const [picker, setPicker] = useState<Mode | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const run = async (mode: Mode, durationMin: number) => {
    setBusy(true);
    setError(null);
    try {
      await onSet(mode, durationMin);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Umschalten nicht bestätigt.");
      setTimeout(() => setError(null), 12000);
    } finally {
      setBusy(false);
      setPicker(null);
    }
  };
  const Btn = ({ v, text }: { v: Mode; text: string }) => (
    <button
      disabled={busy || disabled}
      aria-pressed={active === v}
      onClick={() => (v === "auto" ? void run("auto", 0) : setPicker(v))}
      className="mono flex h-full flex-1 items-center justify-center border-l border-line-1 text-[13px] uppercase tracking-[.1em] transition-colors duration-[var(--dur)] first:border-l-0 disabled:opacity-45"
      style={{ background: active === v ? activeColor : "transparent", color: active === v ? "var(--petrol)" : "var(--text-2)" }}
    >
      {text}
    </button>
  );
  const line = error ?? (disabled ? disabledNote ?? status : status);
  return (
    <div className="controls-device relative flex h-20 min-w-0 flex-col overflow-visible rounded-[3px] border border-line-1 bg-surface-2">
      <div className="flex min-w-0 flex-1 items-center gap-2 px-3">
        <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-line-2 bg-petrol" title={title} aria-label={label} role="img">
          <Icon name={icon} size={17} color={activeColor} />
        </span>
        <span className="mono truncate text-[12px] uppercase tracking-[.1em]" style={{ color: error ? "var(--alert)" : statusColor }} title={error ?? title}>
          {busy ? "schalte …" : line}
        </span>
      </div>
      <div className="flex h-11 shrink-0 overflow-hidden rounded-b-[3px] border-t border-line-1">
        <Btn v="auto" text="Auto" />
        <Btn v="on" text="An" />
        <Btn v="off" text="Aus" />
      </div>
      {picker ? (
        <div className="absolute bottom-[calc(100%+8px)] left-0 z-10 flex items-center gap-2 rounded-[3px] border border-line-2 p-2" style={{ background: "#07202c", boxShadow: "var(--shadow-sheet)" }}>
          <span className="kicker whitespace-nowrap px-2" style={{ fontSize: 11 }}>{pickerLabel(picker)}</span>
          {durations.map((m) => (
            <button key={m} onClick={() => void run(picker, m)} className="mono h-11 min-w-[64px] rounded-[2px] border border-line-2 px-3 text-[13px] text-text-1 hover:bg-surface-3">
              {m < 60 ? `${m} min` : `${m / 60} h`}
            </button>
          ))}
          <button onClick={() => setPicker(null)} className="h-11 px-3 text-[13px] text-text-3">Abbrechen</button>
        </div>
      ) : null}
    </div>
  );
}

const HP_DURATIONS = [30, 120, 360];

function HeatPumpSegment({ state, readOnly = false }: { state: LiveState | null; readOnly?: boolean }) {
  const mode = state?.operating_mode;
  const override = mode?.override;
  const active: Mode = override ? (override.kind === "force_release" ? "on" : "off") : mode?.system_mode === "off" ? "off" : "auto";
  const hp = state?.heat_pump;
  const running = override
    ? `${override.kind === "force_release" ? "manuell an" : "manuell aus"} bis ${hhmm(override.ends_at)}`
    : hp?.running
      ? `läuft · ${state?.decision?.reasons[0]?.replace(/_/g, " ") ?? ""}`
      : "bereit";
  return (
    <DeviceSegment
      icon="pump"
      label="Wärmepumpe"
      active={active}
      activeColor={hp?.running ? "var(--heat-pump)" : "var(--amber)"}
      status={readOnly ? `${running} · nur Ansicht` : running}
      statusColor={override ? "var(--amber-soft)" : hp?.running ? "var(--amber)" : "var(--text-3)"}
      title={`Wärmepumpe: ${running}`}
      disabled={readOnly}
      disabledNote={`${running} · nur Ansicht`}
      durations={HP_DURATIONS}
      pickerLabel={(m) => (m === "on" ? "Manuell an für" : "Manuell aus für")}
      onSet={async (m, duration_min) => {
        if (m === "auto") await api.setHeatPumpMode({ system_mode: "auto", duration_min: 120 });
        else await api.setHeatPumpMode({ system_mode: "manual", manual_state: m, duration_min });
      }}
    />
  );
}

// Zwei Stunden ist die kleinste sinnvolle Anforderung: darunter verbrennt der Ofen mehr Pellets im
// Zünden und Ausbrennen, als er nutzbar in den Puffer bringt. Deshalb beginnt die Auswahl dort und
// nicht bei 30 Minuten wie an der Wärmepumpe.
const STOVE_DURATIONS = [120, 240, 480];

function StoveSegment({ state, readOnly = false }: { state: LiveState | null; readOnly?: boolean }) {
  const stove = state?.stove;
  if (!stove?.present) return null;
  const brennt = stove.running === null ? "keine Verbindung" : stove.running ? (stove.power_level ? `brennt · Stufe ${Math.round(stove.power_level)}` : "brennt") : "aus";
  // Wunsch und Wirklichkeit stehen nebeneinander, sobald sie auseinanderlaufen: zwischen Befehl und
  // Feuer liegen Minuten, und beim Abschalten meldet der Ofen die ganze Ausbrandphase über „läuft“.
  // „Aus“ ohne Frist ist die Vorgabe und kein Eingriff: DCH lässt den Ofen dann in Ruhe, in beide
  // Richtungen. Das ist etwas anderes als ein „manuell aus bis 21:00“, und es soll auch anders heißen.
  const wunsch = stove.mode === "auto" ? "" : stove.ends_at ? ` · manuell ${stove.mode === "on" ? "an" : "aus"} bis ${hhmm(stove.ends_at)}` : " · Planer aus";
  // Im Automatikbetrieb zählt, was der Planer vorhat - und zwar auch dann, wenn der Ofen es noch
  // nicht umgesetzt hat. „aus · Plan an bis 21:00“ heißt: er zündet gerade.
  const plan = stove.mode === "auto" && stove.planned_on != null ? ` · Plan ${stove.planned_on ? "an" : "aus"}${stove.plan_until ? ` bis ${hhmm(stove.plan_until)}` : ""}` : "";
  const status = readOnly ? `${brennt} · nur Ansicht` : `${brennt}${wunsch}${plan}`;
  const color = stove.running === null ? "var(--alert)" : stove.running ? "var(--stove)" : "var(--text-3)";
  return (
    <DeviceSegment
      icon="stove"
      label="Pelletofen"
      active={stove.mode}
      activeColor={stove.running ? "var(--stove)" : "var(--amber)"}
      status={status}
      statusColor={stove.mode === "auto" ? color : "var(--amber-soft)"}
      title={[stove.note_de, stove.plan_note_de].filter(Boolean).join(" ") || "Pelletofen"}
      disabled={readOnly || !stove.control_enabled}
      disabledNote={readOnly ? `${brennt} · nur Ansicht` : `${brennt} · nicht freigegeben`}
      durations={STOVE_DURATIONS}
      pickerLabel={(m) => (m === "on" ? "Ofen an für" : "Ofen aus für")}
      onSet={async (mode, duration_min) => {
        await api.setStoveMode({ mode, duration_min: duration_min || 180 });
      }}
    />
  );
}

export function ControlsBar({ state, readOnly = false }: { state: LiveState | null; readOnly?: boolean }) {
  const act = state?.snapshot.actuators ?? {};
  const withStove = Boolean(state?.stove?.present);
  return (
    <div className={`controls-grid grid shrink-0 gap-4${withStove ? " has-stove" : ""}`}>
      <HeatPumpSegment state={state} readOnly={readOnly} />
      <StoveSegment state={state} readOnly={readOnly} />
      {TILES.map((t) => {
        const m = act[t.key];
        const on = m && m.value !== null ? m.value >= 0.5 : null;
        return (
          <ControlTile
            key={t.key}
            tile={t}
            on={on}
            m={m ?? null}
            readOnly={readOnly}
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
