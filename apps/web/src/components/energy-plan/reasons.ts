import type { Decision } from "@/lib/api/models";
import { hhmm, kw } from "@/lib/format";

/** Deutsche Ein-Zeilen-Begründungen aus Reason-Codes und Eingangsgrößen. */
export function reasonLines(d: Decision, minOfftimeMin = 20, minRuntimeMin = 30): string[] {
  const i = d.inputs;
  const soc = i.buffer_soc != null ? `${Math.round(i.buffer_soc * 100)} %` : "unbekannt";
  const surplus = i.surplus_ewma_kw != null ? `${kw(i.surplus_ewma_kw)} kW` : "–";
  const imp = i.import_ewma_kw != null ? `${kw(i.import_ewma_kw)} kW` : "–";
  const sinceStop = i.seconds_since_stop != null ? Math.round(i.seconds_since_stop / 60) : null;
  const sinceStart = i.seconds_since_start != null ? Math.round(i.seconds_since_start / 60) : null;
  const price = i.price_ct_kwh != null ? `${i.price_ct_kwh.toFixed(1).replace(".", ",")} ct/kWh` : "–";
  const rank = i.price_rank != null ? `${Math.round(i.price_rank * 100)}. Perzentil` : "";
  const map: Record<string, string> = {
    pv_surplus: `PV-Überschuss ${surplus} im Mittel (Schwelle 4,0 kW)`,
    pv_surplus_fading: `Überschuss reicht nicht mehr – Bezug ${imp} im Mittel`,
    price_negative: `Strompreis negativ (${price})`,
    price_cheap_window: `Strompreis ${price} im günstigsten Tagesfenster${rank ? ` (${rank})` : ""}`,
    planned_window: "Geplantes Zeitfenster laut Energieplan",
    heat_demand_forced: "Heizbedarf hat Vorrang",
    hp_running_own_control: "Wärmepumpe läuft in eigener Regelung",
    min_runtime_hold: `Mindestlaufzeit ${minRuntimeMin} min – läuft seit ${sinceStart ?? "?"} min`,
    min_offtime_pending: `Mindeststillstandszeit ${minOfftimeMin} min – steht seit ${sinceStop ?? "?"} min`,
    on_delay_pending: "Bedingung muss 5 Minuten stabil bleiben",
    off_delay_pending: "Ausschaltverzögerung läuft (10 min)",
    buffer_full: `Pufferspeicher voll (${soc})`,
    buffer_no_headroom: `Pufferspeicher fast voll (${soc}) – zu wenig Ladehub`,
    max_starts_reached: `Maximale Starts heute erreicht (${i.starts_today})`,
    no_trigger: `Kein nutzbarer Überschuss (${surplus}) · Preis nicht günstig`,
    import_too_high: `Netzbezug ${imp} über 1,5 kW`,
    manual_override: "Manuelle Übersteuerung aktiv",
    mode_off: "Modus AUS – nur beobachten",
    sensor_stale: "Messwerte veraltet",
    sensor_unavailable: "Messwerte nicht verfügbar",
    price_data_stale: "Strompreise veraltet – Preisregeln pausiert",
    hp_not_responding: "Wärmepumpe hat auf Freigabe nicht reagiert",
    failsafe: "Sicherheitsmodus aktiv",
    toggle_rate_exceeded: "Zu viele Schaltvorgänge pro Stunde",
  };
  const codes = [...d.reasons, ...d.blocked_by.filter((c) => !d.reasons.includes(c))];
  const lines = codes.map((c) => map[c] ?? c);
  const extra: string[] = [];
  if (i.buffer_soc != null && !codes.some((c) => c.startsWith("buffer"))) extra.push(`Pufferspeicher ${soc}`);
  return [...new Set([...lines, ...extra])].slice(0, 4);
}

export function nextExpectedLine(d: Decision): string | null {
  const n = d.next_expected;
  if (!n) return null;
  const at = n.at ? hhmm(n.at) : null;
  const verb: Record<string, string> = { start: "Start", stop: "Ende", window_start: "Preistief ab", release_ends: "Freigabe endet" };
  return at ? `${verb[n.action] ?? n.action} ≈ ${at}` : n.text_de;
}

export const STATE_DE: Record<string, string> = {
  off: "beobachtet",
  idle: "bereit",
  arming: "startet gleich",
  released: "Freigabe gesetzt",
  running_released: "läuft mit Freigabe",
  cooldown: "Nachlauf",
  manual: "manuell",
  failsafe: "Sicherheitsmodus",
};
