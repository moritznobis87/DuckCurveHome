"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary, HeatReport } from "@/lib/api/models";
import { useLiveStore, rowToPoint, type HistoryPoint } from "@/lib/live/store";
import { startLiveClient } from "@/lib/live/sseClient";
import { startReloadPolicy } from "@/lib/live/reloadPolicy";
import { useRole } from "@/lib/live/useRole";
import { useIsMobile } from "@/lib/useIsMobile";
import { MitteilungsHinweis } from "./MitteilungsHinweis";
import { UpdateHinweis } from "@/components/update/UpdateHinweis";
import { useRuhe } from "@/lib/useRuhe";
import { celsius, hhmm, kw, longDate } from "@/lib/format";
import { isoDay } from "@/lib/day";
import { AreaIcons, Brand, Fussleiste, Kontoknopf, Systemknopf } from "@/components/layout/AreaNav";
import { abschnitte, ausblick } from "./ausblick";
import { bild as himmel, sonnenlauf } from "./ambiente";
import { sonnenanteil } from "./buehne";
import { Buehne } from "./Buehne";
import { wpWort } from "./fluss";
import { Ausblickkarte, Pufferkarte } from "./Karten";
import { WpMenue } from "./WpMenue";
import { DayCurve } from "./DayCurve";
import { Dock } from "./Dock";
import { Wache } from "./Wache";
import { Ambiente } from "./Ambiente";
import { grenzen, kennzahlen, preise, pvSumme, schatten, waermeSumme, type Tag } from "./tage";

/**
 * Jetzt: die Startseite der Wandanzeige.
 *
 * Sie beantwortet eine Frage: Was tut das Haus gerade, und warum. Ein Satz, das lebende Bild, die
 * Kurve des Tages, vier Zahlen und das Dock. Alles Analytische steht in den Bereichen; wer eine
 * Zahl verstehen will, tippt sie an.
 *
 * **Kurve und Zahlen kennen drei Tage, das Bild oben nur einen.** Gestern, heute, morgen schalten
 * gemeinsam um; der Energiefluss, die Leiste und das Dock bleiben beim Jetzt, denn ein Schalter,
 * der an einer Wand ein Geraet von gestern anboete, waere eine Falle. Nach zwei Minuten ohne
 * Beruehrung kehrt die Anzeige zu heute zurueck: Wer vorbeigeht, soll nicht das Gestern eines
 * anderen sehen.
 *
 * **Wenn niemand da ist, wird daraus ein Bild.** Nach fuenf Minuten ohne Beruehrung legt sich das
 * Ambiente darueber: Uhr, Satz, drei grosse Zahlen. Die Seite darunter bleibt am Leben und mit
 * ihr die Verbindung; eine Beruehrung holt die Bedienung zurueck. Auf dem Telefon nicht - das
 * schaltet sich von selbst ab.
 *
 * **Was hier nicht mehr ist.** Die Messuhren, die Begruendungs-Chips, die vier Zeitspuren und das
 * Blaettern durch Tage. Die Begruendung ist der Satz oben; die Zeitspuren sind drei Zeilen in der
 * Leiste; und vergangene Tage stehen unter Strom, mit allem Blaettern, das dort hingehoert.
 */
const TAG_MS = 5 * 60_000;
// Nach dieser Zeit ohne Beruehrung steht wieder heute da.
const HEIMKEHR_MS = 2 * 60_000;
// Und nach dieser Zeit wird aus der Bedienung ein Bild (siehe `Ambiente`). Laenger als die
// Heimkehr, damit das Ambiente immer den heutigen Tag zeigt und nicht das Gestern von jemandem.
const AMBIENTE_MS = 5 * 60_000;
// Eine stabile leere Reihe: als Literal im JSX waere sie jedes Mal neu und liesse die Zeichnung
// bei jedem Takt von vorn rechnen.
const KEINE_REIHE: HistoryPoint[] = [];

/** Die Tagesbilanz eines Kalendertags, aus derselben Stundenbilanz wie die Strom-Seite. */
function useTagesbilanz(day: string): EnergySummary | null {
  const [s, setS] = useState<EnergySummary | null>(null);
  useEffect(() => {
    if (!day) return;
    let alive = true;
    const lade = () => void api.energySummary("day", day).then((r) => { if (alive) setS(r); }).catch(() => undefined);
    lade();
    const t = setInterval(lade, TAG_MS);
    return () => { alive = false; clearInterval(t); };
  }, [day]);
  return s;
}

export function Home() {
  const role = useRole();
  const isMobile = useIsMobile();
  const state = useLiveStore((s) => s.state);
  const plan = useLiveStore((s) => s.plan);
  const history = useLiveStore((s) => s.history);
  const connection = useLiveStore((s) => s.connection);
  const lastFrameAt = useLiveStore((s) => s.lastFrameAt);
  const offset = useLiveStore((s) => s.serverOffsetMs);
  const setHistory = useLiveStore((s) => s.setHistory);
  const [nowMs, setNowMs] = useState<number | null>(null);
  const [tag, setTag] = useState<Tag>("heute");

  useEffect(() => {
    const stop = startLiveClient();
    const stopReload = startReloadPolicy(() => useLiveStore.getState().state?.system.version ?? null);
    const tick = () => setNowMs(Date.now() + useLiveStore.getState().serverOffsetMs);
    tick();
    const t = setInterval(tick, 1000);
    return () => { stop(); stopReload(); clearInterval(t); };
  }, []);

  // Mitternacht: die Kurve dem neuen Tag folgen lassen. Die alte Ansicht blieb auf gestern stehen,
  // und weil der Zustandsspeicher Live-Werte nur an den laufenden Tag anhaengt, hoerte die Kurve
  // dort schlicht auf.
  const heute = nowMs != null && lastFrameAt != null ? isoDay(nowMs) : "";
  const gesehen = useRef("");
  useEffect(() => {
    if (!heute || gesehen.current === heute) return;
    const vorher = gesehen.current;
    gesehen.current = heute;
    if (!vorher) return;
    // Aus dem Gestern von eben ist vorgestern geworden: Schalter zurueck, Reihe verwerfen.
    setTag("heute");
    gesternGeholt.current = "";
    setGesternReihe([]);
    void api.history("today").then((h) => setHistory(h.rows.map(rowToPoint), heute)).catch(() => undefined);
  }, [heute, setHistory]);

  const s = state?.snapshot;
  const degraded = connection !== "live";
  const now = nowMs ?? Date.now() + offset;
  // Die Kurve und die Tagesgrenzen brauchen die Sekunde nicht. Mit ihr rechnete die Zeichnung
  // jeden Takt neu; die Marke „jetzt" wandert ohnehin nur minutenweise.
  const minute = Math.floor(now / 60_000) * 60_000;
  // Tag oder Nacht und wann die Sonne wiederkommt: aus der Erwartung des Fahrplans. Nur die
  // Uhrzeit, ohne „morgen": ein Sonnenaufgang ist immer der nächste, und neben dem Mond ist
  // kein Platz für mehr.
  const blick = useMemo(() => ausblick(plan, minute), [plan, minute]);
  const sonneAb = blick.nacht && blick.sonneWechsel ? hhmm(new Date(blick.sonneWechsel)) : null;
  const preis = s?.electricity_price_ct_kwh.value ?? null;

  // ---------------------------------------------------------------- Gestern, heute, morgen
  const { start, end } = useMemo(() => grenzen(tag, minute), [tag, minute]);
  const isoGestern = useMemo(() => grenzen("gestern", minute).iso, [minute]);
  const bilanzHeute = useTagesbilanz(heute);
  // Leerer Tag heisst: nicht laden. Der zuletzt geholte Stand bleibt stehen, also kostet das
  // Hin- und Herschalten keine Anfrage.
  const bilanzGestern = useTagesbilanz(tag === "gestern" ? isoGestern : "");

  // Die Reihe von gestern wird immer geholt, nicht erst beim Umschalten: Sie liegt als
  // Schattenkurve hinter heute (siehe `schatten` in `tage.ts`). Eine Anfrage am Tag.
  const [gesternReihe, setGesternReihe] = useState<HistoryPoint[]>([]);
  const gesternGeholt = useRef("");
  useEffect(() => {
    if (!isoGestern || gesternGeholt.current === isoGestern) return;
    gesternGeholt.current = isoGestern;
    void api
      .history("yesterday")
      .then((h) => setGesternReihe(h.rows.map(rowToPoint)))
      .catch(() => { gesternGeholt.current = ""; });
  }, [isoGestern]);

  // Die Waermelastprognose reicht 48 Stunden und wird nur geholt, wenn jemand nach morgen fragt.
  const [waerme, setWaerme] = useState<HeatReport | null>(null);
  useEffect(() => {
    if (tag !== "morgen" || !heute) return;
    let alive = true;
    const lade = () => void api.energyHeat("day", heute).then((r) => { if (alive) setWaerme(r); }).catch(() => undefined);
    lade();
    const t = setInterval(lade, TAG_MS);
    return () => { alive = false; clearInterval(t); };
  }, [tag, heute]);

  // Das Ambiente erst, wenn ueberhaupt etwas da ist: Eine Wand, die nach fuenf Minuten gross
  // „Verbinde mit dem Haus" sagt, ist kein Bild, sondern ein Vorwurf.
  const { ruhe, wecken } = useRuhe(AMBIENTE_MS, !isMobile && state != null);

  const [getippt, setGetippt] = useState(0);
  useEffect(() => {
    if (tag === "heute") return;
    const t = setTimeout(() => setTag("heute"), HEIMKEHR_MS);
    return () => clearTimeout(t);
  }, [tag, getippt]);

  const morgen = useMemo(() => {
    const g = grenzen("morgen", minute);
    return {
      pvKwh: pvSumme(plan?.intervals, g.start, g.end),
      waerme: waermeSumme(waerme?.forecast, g.start, g.end),
      preise: preise(plan?.intervals, g.start, g.end),
    };
  }, [plan, waerme, minute]);

  const schattenKurve = useMemo(() => schatten(tag, minute, gesternReihe, history), [tag, minute, gesternReihe, history]);

  const zahlen = kennzahlen(tag, tag === "gestern" ? bilanzGestern : bilanzHeute, preis, morgen);
  const reihe = tag === "gestern" ? gesternReihe : tag === "morgen" ? KEINE_REIHE : history;
  const wache = state?.system.watch ?? [];
  const d = state?.decision;
  const satz = d?.explanation_de ?? (state ? "Das Haus ist da, die erste Entscheidung steht noch aus." : "Verbinde mit dem Haus …");
  // Die Zeile unter dem Satz, in Worten statt in Kennungen („Entscheidung 20:46 · auto · smart").
  // Erst, wer gerade entscheidet; dann, was als Nächstes kommt oder seit wann der Satz gilt.
  const modeWort = state?.operating_mode.override
    ? `von Hand bis ${hhmm(state.operating_mode.override.ends_at)}`
    : state?.operating_mode.system_mode === "off"
      ? "Automatik aus, Duck Curve schaut nur zu"
      : "Automatik";
  const naechsterLauf = abschnitte(blick.zellen, (z) => z.wp)[0];
  const laufStart = naechsterLauf && naechsterLauf[0] > 0 ? blick.zellen[naechsterLauf[0]]?.ts : undefined;
  const dazu =
    laufStart != null && !state?.heat_pump.running && !state?.operating_mode.override && state?.operating_mode.system_mode !== "off"
      ? `Der nächste Lauf ist für ${hhmm(new Date(laufStart))} geplant.`
      : d
        ? `Entschieden um ${hhmm(d.at)}.`
        : "";

  // Der Himmel der Bühne: Tag oder Nacht und wo die Sonne auf ihrem Bogen steht. Vor dem Aufgang
  // und nach dem Untergang sitzt sie am Ende des Bogens, ohne Fahrplan in seiner Mitte.
  const lauf = useMemo(() => sonnenlauf(plan, minute), [plan, minute]);
  const nacht = himmel(lauf, minute, s?.pv_power_kw.value) === "abend";
  const stand = sonnenanteil(lauf, minute) ?? (lauf ? (minute < lauf.von ? 0 : 1) : 0.5);
  const vonEben = degraded && lastFrameAt ? hhmm(new Date(lastFrameAt + offset)) : null;
  const [wpMenue, setWpMenue] = useState(false);
  const wpLaeuft = state?.heat_pump.running;

  return (
    <main className={`home start dashboard-bg ${isMobile ? "home-telefon" : ""}`}>
      <header className="home-kopf">
        <div className="flex items-center gap-5">
          <Brand />
          <AreaIcons />
          <span className="kopfknoepfe flex items-center gap-1">
            <Systemknopf />
            <Kontoknopf />
          </span>
        </div>
        <div className="home-uhr start-uhr" suppressHydrationWarning>
          <div className="start-daten">
            <span className="home-datum">{nowMs ? longDate(new Date(nowMs)) : ""}</span>
            <span className="start-zeile">
              <span className="flex items-center gap-2" title={state?.system.connection_label_de}>
                <span className={`home-punkt ${degraded ? "home-punkt-aus" : ""}`} aria-hidden />
                <span className="kicker home-status-wort" data-stoerung={degraded} style={{ fontSize: 11, color: degraded ? "var(--alert-text)" : "var(--text-3)" }}>{degraded ? (lastFrameAt ? `unterbrochen · ${hhmm(new Date(lastFrameAt + offset))}` : "verbinde") : state?.system.mode === "demo" ? `demo${state.system.sim_speed !== 1 ? ` ${state.system.sim_speed}×` : ""}` : "live"}</span>
              </span>
              <span className="mono home-aussen" title={state?.system.outdoor_source_de ? "Der Messwert aus dem Haus ist alt oder unglaubwürdig; gezeigt wird der Wert des Wetterdienstes." : undefined}>{celsius(state?.system.outdoor_shown_c ?? s?.outdoor_temp_c.value, 1)}<span className="home-aussen-wort">{state?.system.outdoor_source_de || "draußen"}</span></span>
            </span>
          </div>
          <span className="mono home-zeit">{nowMs ? hhmm(new Date(nowMs)) : ""}</span>
        </div>
      </header>

      <div className="start-satzzeile">
        <div className="start-satz">
          <p className="home-satz">{satz}</p>
          <div className="start-marken">
            <span className="start-marke">{modeWort}</span>
            {wpLaeuft ? <span className="start-marke" data-art="laeuft">Wärmepumpe läuft</span> : null}
            {dazu ? <span>{dazu}</span> : null}
          </div>
        </div>
        <div className="start-hinweise">
          <Wache befunde={wache} />
          {isMobile ? <MitteilungsHinweis /> : null}
          <UpdateHinweis />
        </div>
      </div>

      <div className="start-oben">
        <Buehne snapshot={s ?? null} nowMs={now} wpLaeuft={wpLaeuft} nacht={nacht} stand={stand} lauf={lauf} sonneAb={sonneAb} vonEben={vonEben} onPumpe={() => setWpMenue(true)} />
        <div className="start-rechts">
          <Pufferkarte state={state} nowMs={now} />
          <Ausblickkarte blick={blick} warnung={plan?.planner_warn_de} />
        </div>
      </div>

      <div className="start-unten">
        <section className="start-karte start-tag" aria-label="Der Tag">
          <DayCurve
            tag={tag}
            onTag={(t) => { setTag(t); setGetippt(Date.now()); }}
            history={reihe}
            plan={plan}
            heat={waerme}
            schatten={schattenKurve}
            nowMs={minute}
            start={start}
            end={end}
            zahlen={
              <div className="start-zahlen">
                {zahlen.map((k) => (
                  <span key={k.wort} className="start-zahl">
                    <span className="mono start-zahl-wert" data-gelb={k.gelb || undefined}>{k.wert}<small>{k.einheit}</small></span>
                    <span className="start-zahl-wort">{k.wort}</span>
                  </span>
                ))}
              </div>
            }
          />
        </section>
        <section className="start-karte start-schalter" aria-label="Schalter">
          <Dock state={state} readOnly={role !== "owner"} />
        </section>
      </div>

      <WpMenue offen={wpMenue} onZu={() => setWpMenue(false)} zeile={`${kw(s?.heat_pump_power_kw.value)} kW · ${wpWort(s?.heat_pump_power_kw.value ?? 0, wpLaeuft)}`} />
      <Fussleiste />

      {ruhe && tag === "heute" ? (
        <Ambiente state={state} plan={plan} zahlen={zahlen} morgenPvKwh={morgen.pvKwh} nowMs={minute} degraded={degraded} onWecken={wecken} />
      ) : null}
    </main>
  );
}
