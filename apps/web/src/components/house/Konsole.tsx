"use client";

import Link from "next/link";
import { useEffect, useRef, type ReactNode } from "react";
import type { HousePlan, LiveState, RoomLive } from "@/lib/api/models";
import type { HistoryPoint } from "@/lib/live/store";
import { heatColor } from "@/components/home/puffer";
import { ventilText } from "@/components/rooms/palette";
import { celsius, kwh as kwhText, kwWithUnit } from "@/lib/format";
import { ALARM_WORT, offenSatz, type HausLive } from "./live";
import { anDerGrenze, dauerText, kontaktZeilen, kreisZeilen, methodeText, schichtZeilen, seitText, sparkPfade, statusWort, tagesLauf, verdichte, type Ort } from "./insights";

/**
 * Die Konsole links am Modell: fuenf Bloecke, vier davon zum Aufklappen.
 *
 * **Warum ein Fenster und keine zweite Seite.** Ein Block nennt eine Zahl, und jede dieser Zahlen
 * hat genau eine Anschlussfrage: Welche Tuer steht offen? Welcher Fuehler zieht den Ladestand
 * herunter? Wie lange lief die Waermepumpe heute? Welcher Raum haelt seine Kreise offen? Die
 * Antwort gehoert neben die Zahl, nicht hinter einen Seitenwechsel - und von dort aus geht es
 * weiter: ein Tippen auf eine Zeile holt den Raum ins Modell, der Fuss fuehrt auf die Seite, die
 * den Verlauf hat.
 */
export type Klappe = "kontakte" | "puffer" | "waermepumpe" | "kreise";

export interface KonsoleProps {
  live: HausLive;
  state: LiveState | null;
  rooms: RoomLive[] | null;
  plan: HousePlan | null;
  history: HistoryPoint[];
  nowMs: number;
  offen: Klappe | null;
  onKlappe: (k: Klappe | null) => void;
  onSpringe: (ort: Ort) => void;
  alarm: { kannScharf: boolean; busy: boolean; meldung: string | null; nurAnsicht: boolean; onScharf: (mode: "home" | "away") => void };
}

function Zeile({ links, rechts, unten, onClick, stark = false }: { links: ReactNode; rechts: ReactNode; unten?: ReactNode; onClick?: () => void; stark?: boolean }) {
  const inhalt = (
    <>
      <span className="haus-pop-links">
        <span className={stark ? "haus-pop-name stark" : "haus-pop-name"}>{links}</span>
        {unten ? <span className="haus-pop-unten">{unten}</span> : null}
      </span>
      <span className="haus-pop-rechts">{rechts}</span>
    </>
  );
  if (!onClick) return <li className="haus-pop-zeile">{inhalt}</li>;
  return (
    <li>
      <button type="button" className="haus-pop-zeile haus-pop-tippbar" onClick={onClick}>
        {inhalt}
      </button>
    </li>
  );
}

function Block({
  klappe,
  kicker,
  wert,
  satz,
  farbe,
  zustand,
  offen,
  onKlappe,
  kinder,
  children,
}: {
  klappe?: Klappe;
  kicker: string;
  wert: ReactNode;
  satz: ReactNode;
  farbe?: string;
  zustand?: string;
  offen?: boolean;
  onKlappe?: (k: Klappe | null) => void;
  /** Der Inhalt des Fensters. */
  kinder?: ReactNode;
  /** Inhalt im Block selbst, etwa die Alarmknoepfe. */
  children?: ReactNode;
}) {
  const id = klappe ? `haus-pop-${klappe}` : undefined;
  const kopf = (
    <>
      <span className="k">{kicker}</span>
      <span className="w">{wert}</span>
      <span className="s">{satz}</span>
    </>
  );
  return (
    <div className="haus-block" data-zustand={zustand} style={farbe ? ({ "--farbe": farbe } as React.CSSProperties) : undefined}>
      {klappe && onKlappe ? (
        <button type="button" className="haus-block-kopf" aria-expanded={!!offen} aria-controls={id} onClick={() => onKlappe(offen ? null : klappe)}>
          {kopf}
          <span className="haus-block-pfeil" aria-hidden>{offen ? "‹" : "›"}</span>
        </button>
      ) : (
        <div className="haus-block-kopf">{kopf}</div>
      )}
      {children}
      {klappe && offen ? (
        <div className="haus-pop" id={id} role="group" aria-label={kicker}>
          {kinder}
        </div>
      ) : null}
    </div>
  );
}

/** Die Tageskurve der Waermepumpe: eine Linie, zwei Zahlen an der Achse, mehr braucht es hier nicht. */
function Tageskurve({ werte, max }: { werte: (number | null)[]; max: number }) {
  const B = 280;
  const H = 46;
  const pfade = sparkPfade(werte, B, H, max);
  return (
    <div className="haus-spark">
      <svg viewBox={`0 0 ${B} ${H}`} preserveAspectRatio="none" role="img" aria-label="Leistung der Wärmepumpe über den Tag">
        <line x1="0" y1={H - 0.5} x2={B} y2={H - 0.5} stroke="var(--line-1)" strokeWidth="1" />
        {pfade.map((d) => (
          <path key={d.slice(0, 24)} d={d} fill="none" stroke="var(--heat-pump)" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" />
        ))}
      </svg>
      <div className="haus-spark-achse mono">
        <span>00</span>
        <span>{max > 0 ? `${max.toLocaleString("de-DE", { maximumFractionDigits: 1 })} kW` : ""}</span>
        <span>24</span>
      </div>
    </div>
  );
}

export function Konsole({ live, state, rooms, plan, history, nowMs, offen, onKlappe, onSpringe, alarm }: KonsoleProps) {
  const wurzel = useRef<HTMLDivElement>(null);

  // Das Fenster schliesst, wo man es erwartet: Escape, und ein Zeiger ausserhalb der Konsole.
  useEffect(() => {
    if (!offen) return;
    const taste = (e: KeyboardEvent) => {
      if (e.key === "Escape") onKlappe(null);
    };
    const zeiger = (e: PointerEvent) => {
      if (wurzel.current && e.target instanceof Node && !wurzel.current.contains(e.target)) onKlappe(null);
    };
    window.addEventListener("keydown", taste);
    window.addEventListener("pointerdown", zeiger);
    return () => {
      window.removeEventListener("keydown", taste);
      window.removeEventListener("pointerdown", zeiger);
    };
  }, [offen, onKlappe]);

  const kontakte = kontaktZeilen(plan, live);
  const offeneKontakte = kontakte.filter((k) => k.offen === true);
  const kreise = kreisZeilen(rooms, plan);
  const grenze = anDerGrenze(kreise);
  const temps = state?.snapshot ? [state.snapshot.buffer_temps_c.top, state.snapshot.buffer_temps_c.mid_top, state.snapshot.buffer_temps_c.mid_bottom, state.snapshot.buffer_temps_c.bottom] : [];
  const schichten = schichtZeilen(temps);
  const lauf = tagesLauf(history);
  const hp = state?.heat_pump;
  const alarmZustand = live.alarm;

  return (
    <aside ref={wurzel} className="haus-konsole" aria-label="Zustand">
      <Block
        kicker="Alarm"
        wert={ALARM_WORT[alarmZustand]}
        satz={live.alarmSatz}
        zustand={alarmZustand}
        farbe="var(--amber)"
      >
        {state?.alarm.present && alarmZustand !== "ausgeloest" ? (
          <div className="haus-block-knoepfe">
            <button type="button" disabled={!alarm.kannScharf || alarm.busy || alarmZustand === "zuhause"} onClick={() => alarm.onScharf("home")}>
              zu Hause
            </button>
            <button type="button" disabled={!alarm.kannScharf || alarm.busy || alarmZustand === "unterwegs"} onClick={() => alarm.onScharf("away")}>
              unterwegs
            </button>
          </div>
        ) : null}
        {alarm.meldung ? <span className="s">{alarm.meldung}</span> : null}
        {state?.alarm.present && alarm.nurAnsicht ? <span className="s">Gastzugang: nur Ansicht.</span> : null}
      </Block>

      <Block
        klappe="kontakte"
        kicker="Fenster und Türen"
        wert={
          <>
            {offeneKontakte.length}
            <small>offen</small>
          </>
        }
        satz={offenSatz(offeneKontakte, kontakte.length)}
        farbe="var(--mist)"
        offen={offen === "kontakte"}
        onKlappe={onKlappe}
        kinder={
          <>
            <ul className="haus-pop-liste">
              {kontakte.map((k) => (
                <Zeile
                  key={k.key}
                  links={k.name}
                  unten={k.raum ?? (k.tuer ? "Tür" : "Fenster")}
                  stark={k.offen === true}
                  onClick={k.ort ? () => onSpringe(k.ort!) : undefined}
                  rechts={
                    <span className={k.offen === true ? "haus-wort offen" : k.offen === false ? "haus-wort" : "haus-wort stumm"}>
                      {k.offen === true ? "offen" : k.offen === false ? "zu" : "keine Meldung"}
                      {k.offen === true && seitText(k.observed_at, nowMs) ? <small> seit {seitText(k.observed_at, nowMs)}</small> : null}
                    </span>
                  }
                />
              ))}
              {kontakte.length === 0 ? <li className="haus-pop-leer">Der Hausplan nennt keine Kontakte.</li> : null}
            </ul>
            <p className="haus-pop-fuss">
              Die Kontakte kommen aus der Alarmanlage. Ein Tippen auf eine Zeile holt den Raum ins Modell.
            </p>
          </>
        }
      />

      <Block
        klappe="puffer"
        kicker="Puffer"
        wert={
          <>
            {live.pufferSoc == null ? "-" : Math.round(live.pufferSoc * 100)}
            <small>%</small>
          </>
        }
        satz={schichten.filter((s) => s.temp_c != null).map((s) => Math.round(s.temp_c!)).join(" · ") || "keine Werte"}
        farbe="var(--heat-pump)"
        offen={offen === "puffer"}
        onKlappe={onKlappe}
        kinder={
          <>
            <div className="haus-pop-gross">
              <span className="z">{state?.buffer.usable_energy_kwh == null ? "-" : kwhText(state.buffer.usable_energy_kwh)}</span>
              <span className="e">nutzbar von {state?.buffer.capacity_kwh == null ? "-" : kwhText(state.buffer.capacity_kwh)}</span>
            </div>
            <ul className="haus-pop-liste">
              {schichten.map((s) => (
                <Zeile
                  key={s.name}
                  links={
                    <>
                      <span className="haus-punkt" style={{ background: s.temp_c == null ? "var(--surface-3)" : heatColor(s.temp_c) }} />
                      {s.name}
                    </>
                  }
                  rechts={
                    <span className={s.frisch ? "haus-wort" : "haus-wort stumm"}>
                      {s.temp_c == null ? "kein Messwert" : celsius(s.temp_c, 1)}
                      {!s.frisch && s.temp_c != null && seitText(s.observed_at, nowMs) ? <small> vor {seitText(s.observed_at, nowMs)}</small> : null}
                    </span>
                  }
                />
              ))}
            </ul>
            <div className="haus-pop-zeile">
              <span className="haus-pop-name">Zustand</span>
              <span className="haus-pop-rechts haus-wort">
                {statusWort(state?.buffer.status)}
                {state?.buffer.headroom_soc != null ? <small> noch {Math.round(state.buffer.headroom_soc * 100)} % Platz</small> : null}
              </span>
            </div>
            <p className="haus-pop-fuss">
              {methodeText(state?.buffer.method)}
              {state?.buffer.volume_liters ? ` · ${Math.round(state.buffer.volume_liters)} Liter.` : "."} <Link href="/waerme">Wärme und Verlauf</Link>
            </p>
          </>
        }
      />

      <Block
        klappe="waermepumpe"
        kicker="Wärmepumpe"
        wert={kwWithUnit(live.waermepumpeKw)}
        satz={hp?.running ? `läuft${seitText(hp.running_since, nowMs) ? ` seit ${seitText(hp.running_since, nowMs)}` : ""}` : `steht${seitText(hp?.stopped_since, nowMs) ? ` seit ${seitText(hp!.stopped_since, nowMs)}` : ""}`}
        farbe="var(--heat-pump)"
        offen={offen === "waermepumpe"}
        onKlappe={onKlappe}
        kinder={
          <>
            <Tageskurve werte={verdichte(history.map((p) => p.hp), 96)} max={Math.max(1, Math.ceil(lauf.max))} />
            <ul className="haus-pop-liste">
              <Zeile links="heute" rechts={<span className="haus-wort">{kwhText(lauf.kwh)} Strom</span>} />
              <Zeile links="Laufzeit" rechts={<span className="haus-wort">{dauerText(lauf.minuten)}</span>} />
              <Zeile links="Starts" rechts={<span className="haus-wort">{hp?.starts_today ?? "-"}</span>} />
              <Zeile
                links="PV-Freigabe"
                unten="Kontakt K1 am Regler"
                rechts={<span className={hp?.release_contact_on ? "haus-wort offen" : "haus-wort"}>{hp?.release_contact_on ? "an" : "aus"}</span>}
              />
            </ul>
            {state?.decision?.explanation_de ? <p className="haus-pop-grund">{state.decision.explanation_de}</p> : null}
            <p className="haus-pop-fuss">
              Betrieb: {state?.operating_mode.system_mode === "auto" ? "Automatik" : "von Hand"}. <Link href="/waerme">Erzeuger und Verlauf</Link>
            </p>
          </>
        }
      />

      <Block
        klappe="kreise"
        kicker="Heizkreise"
        wert={
          <>
            {live.kreiseOffen}
            <small>offen</small>
          </>
        }
        satz={rooms ? `${rooms.length} Räume` : "keine Raumwerte"}
        farbe="var(--ev)"
        offen={offen === "kreise"}
        onKlappe={onKlappe}
        kinder={
          <>
            <ul className="haus-pop-liste">
              {kreise.map((k) => (
                <Zeile
                  key={k.id}
                  links={k.name}
                  unten={k.floor}
                  stark
                  onClick={k.ort ? () => onSpringe(k.ort!) : undefined}
                  rechts={
                    <span className="haus-wort offen">
                      {ventilText(k.valve, k.circuits)}
                      <small> {k.temp_c == null ? "" : celsius(k.temp_c, 1)}</small>
                    </span>
                  }
                />
              ))}
              {kreise.length === 0 ? <li className="haus-pop-leer">Kein Heizkreis steht offen.</li> : null}
            </ul>
            {grenze ? (
              <p className="haus-pop-grund">
                {grenze.name} hat alle Kreise offen und liegt trotzdem unter dem Ziel. Dieser Raum bestimmt die nötige Vorlauftemperatur für alle anderen mit.
              </p>
            ) : null}
            <p className="haus-pop-fuss">
              Die Antriebe sind auf oder zu, nichts dazwischen. <Link href="/waerme/raeume">Räume im Tagesverlauf</Link>
            </p>
          </>
        }
      />
    </aside>
  );
}
