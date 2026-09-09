"use client";

import { useCallback, useEffect, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { BatteryLive, BatteryMode } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Note } from "./ReportShell";

/**
 * Steuerung des Speichers: Betriebsart und Untergrenze des Ladestands.
 *
 * **Warum hier und nicht in der unteren Leiste des Dashboards.** Die Leiste ist für Dinge, die man
 * im Vorbeigehen drückt. Das hier ist eine Einstellung, die man einmal trifft und dann an ihren
 * Folgen misst - und die Folgen stehen auf genau dieser Seite: Netzladung, Ladung bei Dunkelheit,
 * Vollzyklen. Außerdem hat die Leiste bereits zwei Geräte und vier Kacheln; ein drittes Gerät
 * würde sie quetschen.
 *
 * **Wozu die Untergrenze.** Der Libbi entlädt bis zu seiner eigenen Grenze, meldet dann 0 %, und
 * wenn dieser Stand eine Stunde steht, holt er sich rund 6 % aus dem Netz zurück. Diese Energie
 * erreicht das Haus nicht: gemessen am 03.09.2026 war sie drei Stunden später wieder verschwunden,
 * ohne dass der Speicher etwas abgegeben hätte. Die letzten Prozent zu fahren kostet also
 * Netzstrom, Wirkungsgrad und Zyklen und bringt nichts.
 */
const MODES: Array<{ v: BatteryMode; text: string; hint: string }> = [
  { v: "auto", text: "Auto", hint: "Untergrenze aktiv: DCH hält den Speicher an, bevor er leer läuft." },
  { v: "normal", text: "Frei", hint: "Speicher freigegeben; DCH greift nicht ein." },
  { v: "hold", text: "Halten", hint: "Speicher befristet anhalten (hält auch das Laden an)." },
];
const RESERVES = [0, 0.06, 0.1, 0.15, 0.2];

export function BatteryControl() {
  const [state, setState] = useState<BatteryLive | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setState(await api.batteryState());
    } catch {
      setState(null);
    }
  }, []);

  useEffect(() => {
    void load();
    const t = setInterval(() => void load(), 60_000);
    return () => clearInterval(t);
  }, [load]);

  const send = async (mode: BatteryMode, reserve?: number) => {
    setBusy(true);
    setError(null);
    try {
      setState(await api.setBatteryMode({ mode, duration_min: 120, reserve_soc: reserve ?? null }));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Umschalten nicht bestätigt.");
      setTimeout(() => setError(null), 12000);
    } finally {
      setBusy(false);
    }
  };

  if (!state) return null;
  // `off` ist die Vorgabe und heißt: DCH sendet gar nichts. Für die Anzeige ist das dasselbe wie
  // „frei"; der Unterschied steht in der Zeile darunter, nicht in der Schaltfläche.
  const active: BatteryMode = state.mode === "off" ? "normal" : state.mode;
  const disabled = busy || !state.control_enabled;
  const reserve = state.reserve_soc ?? 0;
  const line =
    error ??
    (state.control_enabled
      ? [
          state.note_de,
          state.command ? `Zuletzt gesendet: ${state.command === "stopped" ? "angehalten" : "normal"}.` : "",
          state.last_error ? `Fehler: ${state.last_error}` : "",
        ]
          .filter(Boolean)
          .join(" ")
      : "Die Steuerung des Speichers ist in der Konfiguration nicht freigegeben.");

  return (
    <Card style={{ padding: 16 }}>
      <CardHead
        title="Speicher steuern"
        right={state.soc != null ? `Ladestand ${Math.round(state.soc * 100)} %` : "Ladestand unbekannt"}
      />
      <div className="mt-3 flex flex-wrap items-center gap-4">
        <div className="flex h-11 overflow-hidden rounded-[3px] border border-line-1">
          {MODES.map((m) => (
            <button
              key={m.v}
              disabled={disabled}
              aria-pressed={active === m.v}
              title={m.hint}
              onClick={() => void send(m.v)}
              className="mono flex h-full min-w-[92px] items-center justify-center border-l border-line-1 px-3 text-[13px] uppercase tracking-[.1em] transition-colors first:border-l-0 disabled:opacity-45"
              style={{ background: active === m.v ? "var(--amber)" : "transparent", color: active === m.v ? "var(--petrol)" : "var(--text-2)" }}
            >
              {m.text}
            </button>
          ))}
        </div>
        <div className="flex items-center gap-2">
          <span className="kicker" style={{ fontSize: 11 }}>Untergrenze</span>
          {RESERVES.map((r) => (
            <button
              key={r}
              disabled={disabled}
              aria-pressed={Math.abs(reserve - r) < 0.001}
              onClick={() => void send(state.mode === "off" ? "auto" : state.mode, r)}
              className="mono h-11 min-w-[56px] rounded-[2px] border border-line-2 px-2 text-[13px] disabled:opacity-45"
              style={{ background: Math.abs(reserve - r) < 0.001 ? "var(--amber-soft)" : "transparent", color: Math.abs(reserve - r) < 0.001 ? "var(--petrol)" : "var(--text-2)" }}
            >
              {r === 0 ? "aus" : `${Math.round(r * 100)} %`}
            </button>
          ))}
        </div>
      </div>
      <div className="mt-3">
        <Note>{busy ? "schalte …" : line}</Note>
      </div>
    </Card>
  );
}
