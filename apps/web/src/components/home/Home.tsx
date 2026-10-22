"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { api } from "@/lib/api/client";
import type { EnergySummary } from "@/lib/api/models";
import { useLiveStore, rowToPoint } from "@/lib/live/store";
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

/**
 * Jetzt: die Startseite der Wandanzeige.
 *
 * Sie beantwortet eine Frage: Was tut das Haus gerade, und warum. Ein Satz, das lebende Bild, die
 * Kurve des Tages, drei Zahlen und das Dock. Alles Analytische steht in den Bereichen; wer eine
 * Zahl verstehen will, tippt sie an.
 *
 * **Was hier nicht mehr ist.** Die Messuhren, die Begruendungs-Chips, die vier Zeitspuren und das
 * Blaettern durch Tage. Die Begruendung ist der Satz oben; die Zeitspuren sind drei Zeilen in der
 * Leiste; und vergangene Tage stehen unter Strom, mit allem Blaettern, das dort hingehoert.
 */
const TAG_MS = 5 * 60_000;

/** Der Tag in drei Zahlen, aus derselben Stundenbilanz wie die Strom-Seite. */
function useHeute(day: string): EnergySummary | null {
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
    void api.history("today").then((h) => setHistory(h.rows.map(rowToPoint), heute)).catch(() => undefined);
  }, [heute, setHistory]);

  const tag = useHeute(heute);
  const s = state?.snapshot;
  const pvPeak = useMemo(() => Math.max(4, ...(plan?.intervals ?? []).map((i) => i.expected_pv_kw)), [plan]);
  const degraded = connection !== "live";
  const now = nowMs ?? Date.now() + offset;
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
        {isMobile ? <FlowList snapshot={s ?? null} pvPeakKw={pvPeak} /> : <FlowHero snapshot={s ?? null} nowMs={now} pvPeakKw={pvPeak} />}
        <Rail state={state} plan={plan} nowMs={now} />
      </div>

      <DayCurve history={history} plan={plan} nowMs={now} />

      <div className="home-fuss">
        <div className="home-heute">
          <span className="home-heute-wert">
            <span className="mono home-heute-zahl" style={{ color: "var(--pv)" }}>{tag ? tag.totals.pv_kwh.toFixed(1).replace(".", ",") : "-"} <span className="home-einheit">kWh</span></span>
            <span className="home-heute-wort">Sonne geerntet</span>
          </span>
          <span className="home-heute-wert">
            <span className="mono home-heute-zahl">{tag?.totals.autarky != null ? Math.round(tag.totals.autarky * 100) : "-"} <span className="home-einheit">%</span></span>
            <span className="home-heute-wort">ohne Netz</span>
          </span>
          <span className="home-heute-wert">
            <span className="mono home-heute-zahl">{tag ? tag.totals.import_cost_eur.toFixed(2).replace(".", ",") : "-"} <span className="home-einheit">€</span></span>
            <span className="home-heute-wort">bezahlt bis jetzt</span>
          </span>
        </div>
        <Dock state={state} readOnly={role !== "owner"} />
      </div>
    </main>
  );
}
