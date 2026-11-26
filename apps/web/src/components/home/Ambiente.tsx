"use client";

import type { LiveState, Plan } from "@/lib/api/models";
import { celsius, hhmm, longDate } from "@/lib/format";
import { aussicht, type Sonnenlauf } from "./ambiente";
import type { Ausblick } from "./ausblick";
import { Buehne } from "./Buehne";
import { Ausblickkarte, Pufferkarte, Stromkarte } from "./Karten";
import type { Startbild } from "./startbild";
import { de, type Kennzahl } from "./tage";
import { Uhr } from "./Uhr";
import { schwerster } from "./Wache";

/**
 * Das Ambiente: dasselbe Haus, aus drei Metern gelesen.
 *
 * Kein Schalter, kein Reiter, kein Dock. Oben die Uhr, darunter das Bild der Startseite mit
 * seinen zwei Karten, am Fuß die Zahlen des Tages und der einzige Hinweis, den es braucht: dass
 * eine Berührung die Bedienung zurückholt.
 *
 * **Dasselbe Bild wie die Startseite** (Hausherr am 25.11.2026: „es läuft noch der
 * Bildschirmschoner auf dem alten Stand“). Bühne oder Uhr, wie das Gerät es gewählt hat; die
 * Zeichnung ist dieselbe Komponente, hier nur ohne Bedienung. Vorher standen hier ein eigenes
 * Flussbild aus drei Kreisen und am Abend eigene Zeilen zum Fahrplan.
 *
 * **Kein Satz mehr.** Der Hausherr hat den Begründungssatz der Regelung gestrichen: „Wenn dann
 * nur ein ‚Wärmepumpe läuft‘.“ Das steht als Marke unter dem Datum. Was bleibt, ist der Befund
 * der Wache, wenn eine Quelle schweigt: wer im Vorbeigehen auf die Wand sieht, soll den Ausfall
 * sehen. Im Normalfall steht dort nichts.
 *
 * **Die Seite darunter bleibt am Leben.** Das Ambiente liegt als Schicht darüber, es ersetzt
 * `Home` nicht. Sonst riss bei jedem Wechsel die Verbindung ab, und nach dem Antippen stand die
 * Wand erst einmal auf „verbinde …“.
 */
export function Ambiente({ state, plan, zahlen, morgenPvKwh, nowMs, degraded, startbild, blick, lauf, nacht, stand, sonneAb, vonEben, onWecken }: {
  state: LiveState | null;
  plan: Plan | null;
  zahlen: Kennzahl[];
  morgenPvKwh: number | null;
  nowMs: number;
  degraded: boolean;
  /** Das Bild, das dieses Gerät für die Startseite gewählt hat. */
  startbild: Startbild;
  blick: Ausblick;
  lauf: Sonnenlauf | null;
  nacht: boolean;
  stand: number;
  sonneAb: string | null;
  vonEben: string | null;
  onWecken: () => void;
}) {
  const s = state?.snapshot;
  const befund = schwerster(state?.system.watch);
  const wpLaeuft = state?.heat_pump.running;
  // Die fünfte Zahl am Fuß: am Tag, was die Sonne heute bringen soll, nachts, was sie morgen bringt.
  const erwartet = nacht ? morgenPvKwh : aussicht(plan, nowMs).erwartetKwh;
  const fuss: Kennzahl[] = erwartet == null ? zahlen : [...zahlen, { wert: de(erwartet, 1), einheit: "kWh", wort: nacht ? "Sonne morgen" : "Sonne heute erwartet" }];
  const nichts = () => undefined;

  return (
    <div
      className="ambiente"
      role="button"
      tabIndex={0}
      onClick={onWecken}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") onWecken(); }}
      aria-label="Bedienung zurückholen"
    >
      <div className="ambiente-schein" aria-hidden data-bild={nacht ? "abend" : "tag"} />

      <div className="ambiente-kopf">
        <span className="ambiente-kopf-links">
          <span className="mono ambiente-zeit" suppressHydrationWarning>{hhmm(new Date(nowMs))}</span>
          <span className="ambiente-datum" suppressHydrationWarning>{longDate(new Date(nowMs))}</span>
          {wpLaeuft ? <span className="start-marke ambiente-marke" data-art="laeuft">Wärmepumpe läuft</span> : null}
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

      {befund ? <p className="ambiente-befund" data-schwere={befund.severity}>{befund.text_de}</p> : null}

      {/* Das Bild ist hier nur zum Ansehen: nichts darin nimmt eine Berührung an, sie weckt die Seite. */}
      <div className="ambiente-bild start-oben" inert aria-hidden>
        {startbild === "uhr" ? (
          <Uhr snapshot={s ?? null} nowMs={nowMs} wpLaeuft={wpLaeuft} nacht={nacht} blick={blick} sonneAb={sonneAb} vonEben={vonEben} onPumpe={nichts} />
        ) : (
          <Buehne snapshot={s ?? null} nowMs={nowMs} wpLaeuft={wpLaeuft} nacht={nacht} stand={stand} lauf={lauf} sonneAb={sonneAb} vonEben={vonEben} onPumpe={nichts} />
        )}
        <div className="start-rechts">
          <Pufferkarte state={state} nowMs={nowMs} />
          {startbild === "uhr" ? <Stromkarte blick={blick} warnung={plan?.planner_warn_de} /> : <Ausblickkarte blick={blick} warnung={plan?.planner_warn_de} />}
        </div>
      </div>

      <div className="ambiente-fuss">
        <span className="ambiente-zahlen">
          {fuss.map((k) => (
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
    </div>
  );
}
