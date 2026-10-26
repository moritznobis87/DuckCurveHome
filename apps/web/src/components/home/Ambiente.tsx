"use client";

import { useMemo } from "react";
import type { LiveState, Plan } from "@/lib/api/models";
import { celsius, hhmm, kw, longDate } from "@/lib/format";
import { Icon } from "@/components/ui/Icon";
import { aussicht, bild, bogen, sonnenlauf } from "./ambiente";
import { planZeilen } from "./fahrplan";
import { FUEHLER_POS, heatColor, pufferZustand, SCHICHT_GRENZEN } from "./puffer";
import type { Kennzahl } from "./tage";

/**
 * Das Ambiente: dasselbe Haus, aus drei Metern gelesen.
 *
 * Kein Schalter, kein Reiter, kein Dock. Die Uhr, der Satz, drei grosse Zahlen und die vier
 * Tageszahlen am Fuss - und unten rechts der einzige Hinweis, den es braucht: dass eine
 * Beruehrung die Bedienung zurueckholt. Welches der beiden Bilder gilt, entscheidet der
 * Sonnenlauf; die Regel steht in `ambiente.ts`.
 *
 * **Die Seite darunter bleibt am Leben.** Das Ambiente liegt als Schicht darueber, es ersetzt
 * `Home` nicht. Sonst riss bei jedem Wechsel die Verbindung ab, und nach dem Antippen stand die
 * Wand erst einmal auf „verbinde …".
 */
const SCHWELLE_KW = 0.05;

export function Ambiente({ state, plan, zahlen, morgenPvKwh, nowMs, degraded, onWecken }: { state: LiveState | null; plan: Plan | null; zahlen: Kennzahl[]; morgenPvKwh: number | null; nowMs: number; degraded: boolean; onWecken: () => void }) {
  const s = state?.snapshot;
  const lauf = useMemo(() => sonnenlauf(plan, nowMs), [plan, nowMs]);
  const welches = bild(lauf, nowMs, s?.pv_power_kw.value);

  return (
    <button type="button" className="ambiente" onClick={onWecken} aria-label="Bedienung zurückholen">
      <div className="ambiente-schein" aria-hidden data-bild={welches} />

      <div className="ambiente-kopf">
        <span className="ambiente-kopf-links">
          <span className="mono ambiente-zeit" suppressHydrationWarning>{hhmm(new Date(nowMs))}</span>
          <span className="ambiente-datum" suppressHydrationWarning>{longDate(new Date(nowMs))}</span>
        </span>
        <span className="ambiente-kopf-rechts">
          <span className="mono ambiente-aussen">
            {celsius(s?.outdoor_temp_c.value, 1)} <span className="ambiente-aussen-wort">draußen</span>
          </span>
          <span className="ambiente-live kicker">
            <span className={`home-punkt ${degraded ? "home-punkt-aus" : ""}`} aria-hidden />
            {degraded ? "unterbrochen" : "live"}
          </span>
        </span>
      </div>

      <div className="ambiente-satz-zeile">
        <p className="ambiente-satz">{state?.decision?.explanation_de ?? "Verbinde mit dem Haus …"}</p>
        {welches === "tag" ? <Vorschau plan={plan} lauf={lauf} nowMs={nowMs} /> : null}
      </div>

      {welches === "tag" ? <Fluss state={state} /> : <Abend state={state} plan={plan} morgenPvKwh={morgenPvKwh} nowMs={nowMs} />}

      <div className="ambiente-fuss">
        <span className="ambiente-zahlen">
          {/* Am Abend steht der Strompreis gross daneben; ein zweites Mal klein am Fuss waere
              dieselbe Zahl zweimal auf einem Bild. */}
          {(welches === "abend" ? zahlen.slice(0, 3) : zahlen).map((k) => (
            <span key={k.wort} className="ambiente-zahl">
              <span className="mono ambiente-zahl-wert" style={k.gelb ? { color: "var(--pv)" } : undefined}>
                {k.wert} <span className="home-einheit">{k.einheit}</span>
              </span>
              <span className="ambiente-zahl-wort">{k.wort}</span>
            </span>
          ))}
        </span>
        <span className="mono ambiente-hinweis">BERÜHREN FÜR DIE BEDIENUNG</span>
      </div>
    </button>
  );
}

/**
 * Die Aussicht: was der Tag noch bringt.
 *
 * Die Frage am Mittag ist nicht, wie viel die Anlage gerade liefert - das steht gross darunter -,
 * sondern ob noch etwas kommt. Der Bogen zeigt, wo im Tag man steht, gefuellt ist das, was hinter
 * einem liegt.
 */
function Vorschau({ plan, lauf, nowMs }: { plan: Plan | null; lauf: ReturnType<typeof sonnenlauf>; nowMs: number }) {
  const a = aussicht(plan, nowMs, lauf);
  const b = bogen(lauf, nowMs, 340, 62);
  if (a.erwartetKwh == null && !b) return null;
  const eins = (n: number | null) => (n == null ? "-" : n.toFixed(1).replace(".", ","));
  return (
    <span className="ambiente-vorschau">
      <span className="ambiente-vorschau-kopf">
        <span className="kicker ambiente-vorschau-wort">HEUTE ERWARTET</span>
        <span className="mono ambiente-vorschau-zahl">
          {eins(a.erwartetKwh)} <span className="home-einheit">kWh</span>
        </span>
      </span>
      {b ? (
        <svg className="ambiente-bogen" viewBox={`0 0 ${b.breite} ${b.hoehe + 2}`} role="img" aria-label="Erwarteter Sonnenverlauf des Tages, der bisherige Teil gefüllt">
          {b.flaeche ? <path d={b.flaeche} fill="rgba(242,169,0,.26)" /> : null}
          <path d={b.linie} fill="none" stroke="var(--pv)" strokeWidth={2} strokeLinecap="round" strokeDasharray="6 6" strokeOpacity={0.55} />
          {b.bisJetzt ? <path d={b.bisJetzt} fill="none" stroke="var(--pv)" strokeWidth={2.2} strokeLinecap="round" /> : null}
          {b.jetztX != null ? <line x1={b.jetztX} y1={0} x2={b.jetztX} y2={b.hoehe} stroke="var(--amber-soft)" strokeWidth={1.2} strokeDasharray="4 4" /> : null}
          <line x1={0} y1={b.hoehe} x2={b.breite} y2={b.hoehe} stroke="rgba(255,255,255,.2)" strokeWidth={1} />
        </svg>
      ) : null}
      {/* Was geerntet ist, steht unten als Tageszahl. Hier steht nur, was noch kommt - sonst
          stuende dieselbe Kilowattstunde zweimal auf einem Bild. */}
      <span className="ambiente-vorschau-fuss">
        {a.restKwh != null && a.bis != null ? `noch ${eins(a.restKwh)} kWh bis ${hhmm(new Date(a.bis))}` : ""}
      </span>
    </span>
  );
}

/** Sonne, Haus, Speicher: drei Knoten, zwei Leitungen, nichts dazwischen. */
function Fluss({ state }: { state: LiveState | null }) {
  const s = state?.snapshot;
  const bat = s?.battery_power_kw.value ?? 0;
  const laedt = bat < -SCHWELLE_KW;
  const gibt = bat > SCHWELLE_KW;
  const soc = s?.battery_soc.value ?? null;
  const pv = s?.pv_power_kw.value ?? null;
  return (
    <div className="ambiente-fluss">
      <Knoten icon="sun" farbe="var(--pv)" wert={kw(pv)} einheit="kW" wort="Sonne" />
      <span className="ambiente-leitung" aria-hidden style={{ ["--f" as string]: "rgba(242,169,0,.9)", opacity: (pv ?? 0) > SCHWELLE_KW ? 1 : 0.25 }} />
      <Knoten icon="home" farbe="rgba(255,255,255,.92)" wert={kw(s?.house_power_kw.value)} einheit="kW" wort="Haus" gross />
      <span className="ambiente-leitung" aria-hidden data-rueck={gibt ? "ja" : "nein"} style={{ ["--f" as string]: "rgba(127,183,200,.9)", opacity: laedt || gibt ? 1 : 0.25 }} />
      <Knoten
        icon="battery"
        farbe="var(--battery)"
        wert={soc != null ? String(Math.round(soc * 100)) : "-"}
        einheit="%"
        wort={laedt ? "Speicher lädt" : gibt ? "Speicher gibt ab" : "Speicher hält"}
        fuell={soc}
      />
    </div>
  );
}

function Knoten({ icon, farbe, wert, einheit, wort, gross = false, fuell }: { icon: "sun" | "home" | "battery"; farbe: string; wert: string; einheit: string; wort: string; gross?: boolean; fuell?: number | null }) {
  return (
    <span className={`ambiente-knoten ${gross ? "ambiente-knoten-gross" : ""}`}>
      <span className="ambiente-ring" style={{ borderColor: farbe, background: `linear-gradient(color-mix(in srgb, ${farbe} 12%, transparent), color-mix(in srgb, ${farbe} 12%, transparent)), var(--petrol)` }} aria-hidden>
        {typeof fuell === "number" ? <span className="ambiente-fuell" style={{ height: `${Math.round(fuell * 100)}%` }} /> : null}
        <Icon name={icon} size={gross ? 64 : 48} color={farbe} />
      </span>
      <span className="mono ambiente-knoten-zahl" style={icon === "sun" ? { color: "var(--pv)" } : undefined}>
        {wert} <span className="home-einheit">{einheit}</span>
      </span>
      <span className="ambiente-knoten-wort">{wort}</span>
    </span>
  );
}

/**
 * Am Abend: der Puffer und der Preis.
 *
 * Die Sonne ist gelaufen, also ist sie keine Nachricht mehr. Jetzt zaehlt, was im Speicher steht,
 * was die Kilowattstunde kostet und was das Haus in der Nacht vorhat.
 */
function Abend({ state, plan, morgenPvKwh, nowMs }: { state: LiveState | null; plan: Plan | null; morgenPvKwh: number | null; nowMs: number }) {
  const s = state?.snapshot;
  const temps = s ? [s.buffer_temps_c.top, s.buffer_temps_c.mid_top, s.buffer_temps_c.mid_bottom, s.buffer_temps_c.bottom] : [];
  const { vollstaendig, veraltet, wort } = pufferZustand(temps, nowMs, !!state?.heat_pump.running, state?.buffer.status);
  const stufen = temps.map((m, i) => `${heatColor(m.value ?? 20)} ${FUEHLER_POS[i]}%`).join(", ");
  const soc = state?.buffer.soc ?? null;
  const zeilen = planZeilen(plan, nowMs);
  const preis = s?.electricity_price_ct_kwh.value ?? null;
  return (
    <div className="ambiente-abend">
      <div className="ambiente-puffer">
        <span className="ambiente-tank" aria-hidden style={{ background: vollstaendig ? `linear-gradient(180deg, ${stufen})` : "var(--surface-3)", opacity: vollstaendig && !veraltet ? 1 : 0.45 }}>
          {SCHICHT_GRENZEN.map((y) => <span key={y} className="home-tank-marke" style={{ top: `${y}%` }} />)}
        </span>
        <span className="ambiente-tank-werte" aria-hidden>
          {temps.map((m, i) => (
            <span key={i} className="mono ambiente-tank-wert" style={{ top: `${FUEHLER_POS[i]}%` }}>
              {m.value == null ? "-" : `${Math.round(m.value)} °C`}
            </span>
          ))}
        </span>
        <span className="ambiente-puffer-text">
          <span className="kicker ambiente-vorschau-wort">PUFFER</span>
          <span className="mono ambiente-knoten-zahl">
            {soc != null ? String(Math.round(soc * 100)) : "-"} <span className="home-einheit">%</span>
          </span>
          <span className="ambiente-knoten-wort">{wort}</span>
        </span>
      </div>
      <div className="ambiente-abend-rechts">
        <span className="ambiente-preis">
          <span className="kicker ambiente-vorschau-wort">STROM GERADE</span>
          <span className="mono ambiente-preis-zahl" style={preis != null && preis < 0 ? { color: "var(--pv)" } : undefined}>
            {preis == null ? "-" : preis.toFixed(1).replace(".", ",")} <span className="home-einheit">ct</span>
          </span>
        </span>
        <span className="ambiente-plan">
          {zeilen.map(([k, v]) => (
            <span key={k} className="ambiente-plan-zeile">
              <span className="ambiente-plan-wort">{k}</span>
              <span className="mono">{v}</span>
            </span>
          ))}
          {morgenPvKwh != null ? (
            <span className="ambiente-plan-zeile">
              <span className="ambiente-plan-wort">Morgen Sonne</span>
              <span className="mono">{morgenPvKwh.toFixed(1).replace(".", ",")} kWh</span>
            </span>
          ) : null}
        </span>
      </div>
    </div>
  );
}
