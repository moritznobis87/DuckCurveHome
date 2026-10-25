"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary, HeatReport } from "@/lib/api/models";
import { useLiveStore, rowToPoint, type HistoryPoint } from "@/lib/live/store";
import { startLiveClient } from "@/lib/live/sseClient";
import { startReloadPolicy } from "@/lib/live/reloadPolicy";
import { useRole } from "@/lib/live/useRole";
import { useIsMobile } from "@/lib/useIsMobile";
import { celsius, hhmm, longDate } from "@/lib/format";
import { isoDay } from "@/lib/day";
import { AreaIcons, Brand } from "@/components/layout/AreaNav";
import { FlowHero, FlowList } from "./FlowHero";
import { Rail } from "./Rail";
import { DayCurve } from "./DayCurve";
import { Dock } from "./Dock";
import { grenzen, kennzahlen, preise, pvSumme, waermeSumme, type Tag } from "./tage";

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
 * **Was hier nicht mehr ist.** Die Messuhren, die Begruendungs-Chips, die vier Zeitspuren und das
 * Blaettern durch Tage. Die Begruendung ist der Satz oben; die Zeitspuren sind drei Zeilen in der
 * Leiste; und vergangene Tage stehen unter Strom, mit allem Blaettern, das dort hingehoert.
 */
const TAG_MS = 5 * 60_000;
// Nach dieser Zeit ohne Beruehrung steht wieder heute da.
const HEIMKEHR_MS = 2 * 60_000;
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
  const pvPeak = useMemo(() => Math.max(4, ...(plan?.intervals ?? []).map((i) => i.expected_pv_kw)), [plan]);
  const degraded = connection !== "live";
  const now = nowMs ?? Date.now() + offset;
  // Die Kurve und die Tagesgrenzen brauchen die Sekunde nicht. Mit ihr rechnete die Zeichnung
  // jeden Takt neu; die Marke „jetzt" wandert ohnehin nur minutenweise.
  const minute = Math.floor(now / 60_000) * 60_000;
  const preis = s?.electricity_price_ct_kwh.value ?? null;

  // ---------------------------------------------------------------- Gestern, heute, morgen
  const { start, end } = useMemo(() => grenzen(tag, minute), [tag, minute]);
  const isoGestern = useMemo(() => grenzen("gestern", minute).iso, [minute]);
  const bilanzHeute = useTagesbilanz(heute);
  // Leerer Tag heisst: nicht laden. Der zuletzt geholte Stand bleibt stehen, also kostet das
  // Hin- und Herschalten keine Anfrage.
  const bilanzGestern = useTagesbilanz(tag === "gestern" ? isoGestern : "");

  const [gesternReihe, setGesternReihe] = useState<HistoryPoint[]>([]);
  const gesternGeholt = useRef("");
  useEffect(() => {
    if (tag !== "gestern" || !isoGestern || gesternGeholt.current === isoGestern) return;
    gesternGeholt.current = isoGestern;
    void api
      .history("yesterday")
      .then((h) => setGesternReihe(h.rows.map(rowToPoint)))
      .catch(() => { gesternGeholt.current = ""; });
  }, [tag, isoGestern]);

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

  const zahlen = kennzahlen(tag, tag === "gestern" ? bilanzGestern : bilanzHeute, preis, morgen);
  const reihe = tag === "gestern" ? gesternReihe : tag === "morgen" ? KEINE_REIHE : history;
  const d = state?.decision;
  const satz = d?.explanation_de ?? (state ? "Das Haus ist da, die erste Entscheidung steht noch aus." : "Verbinde mit dem Haus …");
  const modeWort = state?.operating_mode.override ? `manuell bis ${hhmm(state.operating_mode.override.ends_at)}` : state?.operating_mode.system_mode === "off" ? "aus · beobachten" : `auto · ${state?.operating_mode.auto_profile ?? "smart"}`;

  return (
    <main className={`home dashboard-bg ${isMobile ? "home-telefon" : ""}`}>
      <header className="home-kopf">
        <div className="flex items-center gap-5">
          <Brand />
          <AreaIcons />
        </div>
        <div className="home-uhr" suppressHydrationWarning>
          <span className="home-datum">{nowMs ? longDate(new Date(nowMs)) : ""}</span>
          <span className="mono home-zeit">{nowMs ? hhmm(new Date(nowMs)) : ""}</span>
          <span className="mono home-aussen">{celsius(s?.outdoor_temp_c.value, 1)}<span className="home-aussen-wort">draußen</span></span>
          <span className="flex items-center gap-2" title={state?.system.connection_label_de}>
            <span className={`home-punkt ${degraded ? "home-punkt-aus" : ""}`} aria-hidden />
            <span className="kicker" style={{ fontSize: 11, color: degraded ? "var(--alert)" : "var(--text-3)" }}>{degraded ? (lastFrameAt ? `unterbrochen · ${hhmm(new Date(lastFrameAt + offset))}` : "verbinde") : state?.system.mode === "demo" ? `demo${state.system.sim_speed !== 1 ? ` ${state.system.sim_speed}×` : ""}` : "live"}</span>
          </span>
        </div>
      </header>

      <div className="home-satz-zeile">
        <p className="home-satz">{satz}</p>
        <span className="kicker home-satz-meta" style={{ fontSize: 11, color: "var(--text-3)" }}>{d ? `Entscheidung ${hhmm(d.at)} · ${modeWort}` : modeWort}</span>
      </div>

      <div className="home-hero" style={{ opacity: degraded ? 0.6 : 1, transition: "opacity .4s" }}>
        {isMobile ? <FlowList snapshot={s ?? null} /> : <FlowHero snapshot={s ?? null} nowMs={now} pvPeakKw={pvPeak} />}
        <Rail state={state} plan={plan} nowMs={now} kompakt={isMobile} />
      </div>

      <DayCurve tag={tag} onTag={(t) => { setTag(t); setGetippt(Date.now()); }} history={reihe} plan={plan} heat={waerme} nowMs={minute} start={start} end={end} />

      <div className="home-fuss">
        <div className="home-heute">
          {zahlen.map((k) => (
            <span key={k.wort} className="home-heute-wert">
              <span className="mono home-heute-zahl" style={k.gelb ? { color: "var(--pv)" } : undefined}>
                {k.wert} <span className="home-einheit">{k.einheit}</span>
              </span>
              <span className="home-heute-wort">{k.wort}</span>
            </span>
          ))}
        </div>
        <Dock state={state} readOnly={role !== "owner"} />
      </div>
    </main>
  );
}
