"use client";

import { useEffect, useRef, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { LiveState, Measurement } from "@/lib/api/models";
import { ageLabel, hhmm } from "@/lib/format";
import { Icon, type IconName } from "@/components/ui/Icon";

/**
 * Das Dock: sechs Schalter am unteren Rand, die leuchten, wenn sie an sind.
 *
 * **Kaffee und Lichter schalten beim Tippen.** Sie haben nur an und aus, und die Kachelleiste
 * von vorher sagte ihnen dasselbe in vier Zeilen. **Waermepumpe und Ofen oeffnen ein Blatt**, weil
 * sie mehr koennen als an und aus: Auto, An fuer eine Frist, Aus fuer eine Frist, und einen Satz,
 * warum der Optimierer gerade so entschieden hat.
 *
 * **Unter jedem Knopf steht ein Wort.** Drei Gluehbirnen nebeneinander sind nicht zu
 * unterscheiden (Rueckmeldung vom 22.10.2026, an der Wand); „Terrasse", „Hof", „Zaun" in
 * Kapitaelchen loesen das, und beim Tippen sagt die Zeile ueber dem Dock, was geschaltet wurde.
 *
 * **Gaeste sehen alles und schalten nichts.** Der Knopf bleibt bedienbar und sagt, warum nichts
 * passiert; ein toter Knopf ohne Erklaerung ist aergerlicher als ein kurzer Satz.
 */
const KACHELN: Array<{ key: string; label: string; kurz: string; icon: IconName; durationMin?: number }> = [
  { key: "coffee_machine", label: "Kaffeemaschine", kurz: "Kaffee", icon: "coffee", durationMin: 120 },
  { key: "terrace_light", label: "Licht Terrasse", kurz: "Terrasse", icon: "bulb" },
  { key: "courtyard_light", label: "Licht Innenhof", kurz: "Hof", icon: "bulb" },
  { key: "garden_fence_light", label: "Licht Gartenzaun", kurz: "Zaun", icon: "bulb" },
];

type Mode = "auto" | "on" | "off";
const HP_DAUERN = [30, 120, 360];
// Zwei Stunden sind die kleinste sinnvolle Anforderung an den Ofen: darunter verbrennt er mehr
// Pellets im Zuenden und Ausbrennen, als er nutzbar in den Puffer bringt.
const OFEN_DAUERN = [120, 240, 480];

function Knopf({ label, kurz, icon, an, farbe, busy, fehler, onClick, offen }: { label: string; kurz: string; icon: IconName; an: boolean | null; farbe: string; busy?: boolean; fehler?: boolean; onClick: () => void; offen?: boolean }) {
  const leuchtet = an === true;
  return (
    <span className="home-dock-item" data-an={leuchtet}>
      <button
        onClick={onClick}
        aria-label={label}
        title={label}
        aria-pressed={an ?? undefined}
        aria-expanded={offen}
        className="home-dock-knopf"
        style={{
          color: fehler ? "var(--alert)" : leuchtet ? farbe : "var(--text-3)",
          borderColor: fehler ? "var(--alert)" : leuchtet || offen ? farbe : "var(--line-2)",
          boxShadow: leuchtet ? `0 0 22px color-mix(in srgb, ${farbe} 35%, transparent)` : undefined,
          background: offen ? `color-mix(in srgb, ${farbe} 14%, transparent)` : undefined,
          opacity: busy ? 0.6 : 1,
        }}
      >
        <Icon name={icon} size={26} />
      </button>
      <span className="home-dock-wort" aria-hidden>{kurz}</span>
    </span>
  );
}

function Blatt({ titel, status, text, modus, dauern, dauerWort, disabled, onSet, onClose, farbe }: { titel: string; status: string; text: string; modus: Mode; dauern: number[]; dauerWort: (m: Mode) => string; disabled: boolean; onSet: (m: Mode, dauer: number) => Promise<void>; onClose: () => void; farbe: string }) {
  const [picker, setPicker] = useState<Mode | null>(null);
  const [busy, setBusy] = useState(false);
  const [fehler, setFehler] = useState<string | null>(null);
  const run = async (m: Mode, dauer: number) => {
    setBusy(true);
    setFehler(null);
    try {
      await onSet(m, dauer);
      setPicker(null);
    } catch (e) {
      setFehler(e instanceof ApiError ? e.message : "Umschalten nicht bestätigt.");
    } finally {
      setBusy(false);
    }
  };
  const Modus = ({ v, text: t }: { v: Mode; text: string }) => (
    <button
      disabled={busy || disabled}
      aria-pressed={modus === v}
      onClick={() => (v === "auto" ? void run("auto", 0) : setPicker(picker === v ? null : v))}
      className="home-modus"
      style={{ background: modus === v ? farbe : "transparent", color: modus === v ? "var(--deep)" : "var(--text-2)", borderColor: modus === v ? farbe : "var(--line-2)" }}
    >
      {t}
    </button>
  );
  return (
    <div role="dialog" aria-label={`${titel} stellen`} className="home-blatt">
      <div className="flex items-baseline justify-between gap-3">
        <span className="flex items-baseline gap-3">
          <span className="text-[18px] font-semibold tracking-[-.01em]">{titel}</span>
          <span className="mono text-[11px] uppercase tracking-[.08em]" style={{ color: farbe }}>{status}</span>
        </span>
        <button onClick={onClose} className="text-[13px] text-text-3" aria-label="Schließen">schließen</button>
      </div>
      <p className="m-0 text-[13px] leading-[1.45] text-text-2">{text}</p>
      <div className="flex gap-2">
        <Modus v="auto" text="Auto" />
        <Modus v="on" text="An" />
        <Modus v="off" text="Aus" />
      </div>
      {picker ? (
        <div className="flex flex-wrap items-center gap-2">
          <span className="kicker min-w-[90px]" style={{ fontSize: 11, color: "var(--text-3)" }}>{dauerWort(picker)}</span>
          {dauern.map((m) => (
            <button key={m} onClick={() => void run(picker, m)} disabled={busy} className="mono h-11 min-w-[72px] rounded-[6px] border border-line-2 px-3 text-[13px] text-text-1 hover:bg-surface-3">
              {m < 60 ? `${m} min` : `${m / 60} h`}
            </button>
          ))}
        </div>
      ) : null}
      {disabled ? <p className="m-0 text-[12px] text-text-3">{busy ? "schalte …" : "Nur Ansicht: dieses Gerät sieht zu, schaltet aber nicht."}</p> : null}
      {fehler ? <p className="m-0 text-[12px]" style={{ color: "var(--alert)" }}>{fehler}</p> : null}
    </div>
  );
}

/**
 * Das Blatt der Alarmanlage: zwei Knoepfe zum Schaerfen, keiner zum Entschaerfen.
 *
 * Das ist keine Luecke. Die Anzeige haengt in der Kueche, Gaeste gehen daran vorbei, und ihr
 * Zugang ist ein Sitzungskeks auf einem Geraet - genug, um eine Anlage scharf zu schalten, zu
 * wenig, um sie abzuschalten. Der Satz unten sagt das, damit niemand sucht.
 */
function AlarmBlatt({ alarm, disabled, onClose }: { alarm: NonNullable<LiveState["alarm"]>; disabled: boolean; onClose: () => void }) {
  const [busy, setBusy] = useState(false);
  const [fehler, setFehler] = useState<string | null>(null);
  const [fertig, setFertig] = useState<string | null>(null);
  const scharf = async (mode: "home" | "away") => {
    setBusy(true);
    setFehler(null);
    try {
      const r = await api.armAlarm(mode);
      setFertig(r.message_de);
    } catch (e) {
      setFehler(e instanceof ApiError ? e.message : "Die Anlage hat nicht bestätigt.");
    } finally {
      setBusy(false);
    }
  };
  const Knopf = ({ mode, text }: { mode: "home" | "away"; text: string }) => (
    <button
      disabled={busy || disabled || !alarm.can_arm}
      onClick={() => void scharf(mode)}
      className="home-modus"
      style={{ borderColor: "var(--mist)", color: "var(--text-1)" }}
    >
      {text}
    </button>
  );
  return (
    <div role="dialog" aria-label="Alarmanlage" className="home-blatt">
      <div className="flex items-baseline justify-between gap-3">
        <span className="flex items-baseline gap-3">
          <span className="text-[18px] font-semibold tracking-[-.01em]">Alarmanlage</span>
          <span className="mono text-[11px] uppercase tracking-[.08em]" style={{ color: "var(--mist)" }}>{alarm.state_de}</span>
        </span>
        <button onClick={onClose} className="text-[13px] text-text-3" aria-label="Schließen">schließen</button>
      </div>
      <div className="flex gap-2">
        <Knopf mode="home" text="Zu Hause" />
        <Knopf mode="away" text="Unterwegs" />
      </div>
      <p className="m-0 text-[12px] leading-[1.45] text-text-3">
        Unscharf wird am Bedienteil geschaltet, nicht hier. Diese Anzeige hängt in der Küche, und
        wer an ihr vorbeigeht, soll eine Alarmanlage einschalten können, nicht ausschalten.
      </p>
      {disabled ? <p className="m-0 text-[12px] text-text-3">Nur Ansicht: dieses Gerät schaltet nichts.</p> : null}
      {!alarm.can_arm && !disabled ? <p className="m-0 text-[12px] text-text-3">Gerade nicht erreichbar.</p> : null}
      {fehler ? <p className="m-0 text-[12px]" style={{ color: "var(--alert)" }}>{fehler}</p> : null}
      {fertig ? <p className="m-0 text-[12px]" style={{ color: "var(--pv)" }}>{fertig}</p> : null}
    </div>
  );
}

export function Dock({ state, readOnly }: { state: LiveState | null; readOnly: boolean }) {
  const [offen, setOffen] = useState<"hp" | "stove" | "alarm" | null>(null);
  const [meldung, setMeldung] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [fehlerKey, setFehlerKey] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const sag = (text: string, ms = 4000) => {
    setMeldung(text);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => setMeldung(null), ms);
  };
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);

  const act = state?.snapshot.actuators ?? {};
  const nowMs = state ? new Date(state.system.server_time).getTime() : Date.now();

  const schalte = async (key: string, label: string, durationMin?: number) => {
    if (readOnly) {
      sag("Gastzugang · nur Ansicht");
      return;
    }
    const m: Measurement | undefined = act[key];
    const an = m && m.value !== null ? m.value >= 0.5 : false;
    setBusy(key);
    setFehlerKey(null);
    try {
      const r = await api.switchActuator(key, !an, !an ? durationMin : undefined);
      if (!r.ok) throw new ApiError("not_confirmed", r.message_de, 200);
      sag(`${label} ${an ? "aus" : "an"}${!an && durationMin ? ` für ${durationMin / 60} h` : ""}`);
    } catch (e) {
      setFehlerKey(key);
      sag(`${label}: ${e instanceof ApiError ? e.message : "Schaltung nicht bestätigt."}`, 8000);
    } finally {
      setBusy(null);
    }
  };

  const alarm = state?.alarm;
  const hp = state?.heat_pump;
  const mode = state?.operating_mode;
  const override = mode?.override;
  const hpModus: Mode = override ? (override.kind === "force_release" ? "on" : "off") : mode?.system_mode === "off" ? "off" : "auto";
  const hpStatus = override ? `${override.kind === "force_release" ? "manuell an" : "manuell aus"} bis ${hhmm(override.ends_at)}` : hp?.running ? `läuft${hp.running_since ? ` seit ${hhmm(hp.running_since)}` : ""}` : "bereit";

  const stove = state?.stove;
  const brennt = stove?.running === null || stove?.running === undefined ? "keine Verbindung" : stove.running ? (stove.power_level ? `brennt · Stufe ${Math.round(stove.power_level)}` : "brennt") : "aus";
  const ofenPlan = stove?.mode === "auto" && stove.planned_on != null ? ` · Plan ${stove.planned_on ? "an" : "aus"}${stove.plan_until ? ` bis ${hhmm(stove.plan_until)}` : ""}` : "";
  const ofenStatus = stove?.mode && stove.mode !== "auto" ? `${brennt}${stove.ends_at ? ` · manuell bis ${hhmm(stove.ends_at)}` : " · Planer aus"}` : `${brennt}${ofenPlan}`;

  return (
    <div className="home-dock">
      {meldung ? <span className="home-dock-meldung mono">{meldung}</span> : null}
      <div className="home-dock-reihe">
        {KACHELN.map((k) => {
          const m = act[k.key];
          const an = m && m.value !== null ? m.value >= 0.5 : null;
          const age = m ? ageLabel(m.observed_at, nowMs) : null;
          return <Knopf key={k.key} label={`${k.label}${an == null ? "" : an ? " · an" : " · aus"}${age ? ` · ${age}` : ""}`} kurz={k.kurz} icon={k.icon} an={an} farbe="var(--amber)" busy={busy === k.key} fehler={fehlerKey === k.key} onClick={() => void schalte(k.key, k.label, k.durationMin)} />;
        })}
        <span className="home-dock-trenner" aria-hidden />
        <Knopf label={`Wärmepumpe · ${hpStatus}`} kurz="Wärmepumpe" icon="pump" an={hp?.running ?? null} farbe="var(--heat-pump)" offen={offen === "hp"} onClick={() => setOffen(offen === "hp" ? null : "hp")} />
        {stove?.present ? <Knopf label={`Pelletofen · ${ofenStatus}`} kurz="Ofen" icon="stove" an={stove.running ?? null} farbe="var(--stove)" offen={offen === "stove"} onClick={() => setOffen(offen === "stove" ? null : "stove")} /> : null}
        {/* Die Alarmanlage leuchtet, wenn sie scharf ist - rot nur, wenn sie ausgelöst hat. */}
        {alarm?.present ? (
          <Knopf
            label={`Alarmanlage · ${alarm.state_de}`}
            kurz="Alarm"
            icon="shield"
            an={alarm.state != null && alarm.state > 0}
            farbe={alarm.state === 4 ? "var(--alert)" : "var(--mist)"}
            offen={offen === "alarm"}
            onClick={() => setOffen(offen === "alarm" ? null : "alarm")}
          />
        ) : null}
      </div>
      {offen === "hp" ? (
        <Blatt
          titel="Wärmepumpe"
          status={hpStatus}
          text={state?.decision?.explanation_de ?? "Warte auf die erste Entscheidung."}
          modus={hpModus}
          dauern={HP_DAUERN}
          dauerWort={(m) => (m === "on" ? "An für" : "Aus für")}
          disabled={readOnly}
          farbe="var(--heat-pump)"
          onClose={() => setOffen(null)}
          onSet={async (m, dauer) => {
            if (m === "auto") await api.setHeatPumpMode({ system_mode: "auto", duration_min: 120 });
            else await api.setHeatPumpMode({ system_mode: "manual", manual_state: m, duration_min: dauer });
          }}
        />
      ) : null}
      {offen === "alarm" && alarm ? (
        <AlarmBlatt alarm={alarm} disabled={readOnly} onClose={() => setOffen(null)} />
      ) : null}
      {offen === "stove" && stove ? (
        <Blatt
          titel="Pelletofen"
          status={ofenStatus}
          text={[stove.note_de, stove.plan_note_de].filter(Boolean).join(" ") || "Der Ofen bekommt genau einen Befehl, den er selbst kennt, und regelt danach allein weiter."}
          modus={stove.mode}
          dauern={OFEN_DAUERN}
          dauerWort={(m) => (m === "on" ? "Ofen an für" : "Ofen aus für")}
          disabled={readOnly || !stove.control_enabled}
          farbe="var(--stove)"
          onClose={() => setOffen(null)}
          onSet={async (m, dauer) => {
            await api.setStoveMode({ mode: m, duration_min: dauer || 180 });
          }}
        />
      ) : null}
    </div>
  );
}
