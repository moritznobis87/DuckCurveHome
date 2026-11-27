"use client";

import { useMemo, type ReactNode } from "react";
import type { EChartsCoreOption } from "echarts/core";
import type { HeatReport, Plan } from "@/lib/api/models";
import type { HistoryPoint } from "@/lib/live/store";
import { hhmm } from "@/lib/format";
import { EChart } from "@/components/charts/EChart";
import { useIsMobile } from "@/lib/useIsMobile";
import { C, MONO } from "@/components/charts/palette";
import { priceBounds } from "@/components/charts/dayBounds";
import { TAGE, TAG_WORT, type Schatten, type Tag } from "./tage";
import { tageslegende, type Kurveninhalt, type Legendenreihe } from "./tageslegende";

/**
 * Die Kurve des Tages: die Marke selbst.
 *
 * Sonne als Flaeche (gemessen voll, Prognose blass und gestrichelt), das Haus als weisse Linie,
 * der Strompreis als Linie auf eigener Achse, das Preistief als Band. Ein Blick zeigt, warum es
 * dieses Haus gibt: mittags ist Strom billig, weil die Sonne scheint.
 *
 * **Drei Tage, eine Zeichnung.** Gestern ist nur Messung, morgen nur Erwartung, heute beides mit
 * der Marke „jetzt" dazwischen. Dieselben Achsen, dieselben Farben: Was gestrichelt ist, ist
 * nicht gemessen. Fuer morgen kommt eine Linie dazu, die es sonst nicht gaebe - der Strom, den
 * die Waermepumpe nach der Wetterprognose brauchen wird.
 *
 * **Dahinter liegt der Tag davor.** Blass, ohne Flaeche, hinter allem: gestern hinter heute,
 * heute hinter morgen. Eine Kurve allein sagt nicht, ob der Tag gut war; erst der Vortag macht
 * aus 13,4 kWh eine Auskunft. Die Schattenlinie ist nicht gestrichelt, denn gestern ist gemessen -
 * gestrichelt bleibt in dieser Zeichnung, was noch keiner gemessen hat. Die Legende nennt dazu
 * die Kilowattstunden bis zur gleichen Uhrzeit, damit der Vergleich eine Zahl hat.
 *
 * Weiter zurueck als gestern geht es hier nicht. Vergangene Tage stehen unter Strom, mit Blaettern
 * und allem; die Wandanzeige soll nicht an einem Tag von vorgestern haengen bleiben, wie es der
 * alten passiert ist.
 */
export function DayCurve({ tag, onTag, history, plan, heat, schatten, nowMs, start, end, zahlen }: { zahlen?: ReactNode; tag: Tag; onTag: (t: Tag) => void; history: HistoryPoint[]; plan: Plan | null; heat: HeatReport | null; schatten: Schatten | null; nowMs: number; start: number; end: number }) {
  // **Am Handy zwei Flächen.** Auf 390 Punkten lagen Leistung und Preis an zwei Achsen
  // übereinander, die Preisstufen kreuzten Sonne und Haus, und über allem standen vier Mal
  // „PREISTIEF" ineinander (gesehen am 10.11.2026). Dort steht die Leistung jetzt oben, der Preis
  // als eigene niedrige Fläche darunter, an derselben Zeitachse; die Bänder laufen durch beide,
  // ihr Name steht in der Legende.
  const handy = useIsMobile();
  const { option, inhalt } = useMemo<{ option: EChartsCoreOption; inhalt: Kurveninhalt }>(() => {
    const hx = (ts: number) => (ts - start) / 3600000;
    const inDay = history.filter((p) => p.ts >= start && p.ts < end);
    const pv = inDay.map((p) => [hx(p.ts), p.pv]);
    const haus = inDay.map((p) => [hx(p.ts), p.house]);
    const preisHist = inDay.map((p) => [hx(p.ts), p.price]);
    // Gestern wird nichts vorhergesagt, heute erst ab jetzt: eine Prognose ueber eine Messung zu
    // legen, die es schon gibt, waere doppelt gezeichnet und sagte nichts.
    const abMs = tag === "heute" ? Math.max(start, nowMs - 15 * 60000) : start;
    const future =
      tag === "gestern"
        ? []
        : (plan?.intervals ?? []).filter((i) => {
            const t = new Date(i.ts).getTime();
            return t >= abMs && t >= start && t <= end;
          });
    const pvPrognose = future.map((i) => [hx(new Date(i.ts).getTime()), i.expected_pv_kw]);
    const preisVoraus = future.map((i) => [hx(new Date(i.ts).getTime()), i.price_ct_kwh]);
    const waerme =
      tag === "morgen"
        ? (heat?.forecast ?? [])
            .map((p) => ({ t: new Date(p.ts).getTime(), kw: p.electric_kw }))
            .filter((p) => p.t >= start && p.t < end)
            .map((p) => [hx(p.t), p.kw])
        : [];
    // **Der Schatten wird nach der Uhr abgebildet, nicht nach den Millisekunden.** Am Tag der
    // Zeitumstellung hat der Vortag 23 oder 25 Stunden; „um 12 Uhr" liegt dann nicht dort, wo
    // 12 mal 3600 Sekunden seit Mitternacht liegen. Verglichen werden soll die Uhrzeit.
    const uhrX = (ts: number) => {
      const d = new Date(ts);
      return d.getHours() + d.getMinutes() / 60;
    };
    const schattenPv = (schatten?.punkte ?? [])
      .filter((p) => p.ts >= (schatten?.start ?? 0) && p.ts < (schatten?.end ?? 0))
      .map((p) => [uhrX(p.ts), p.pv]);
    const baender = (plan?.windows ?? [])
      .filter((w) => (w.kind === "cheap" || w.kind === "negative") && new Date(w.start).getTime() < end && new Date(w.end).getTime() > start)
      .map((w) => [
        { xAxis: Math.max(0, hx(new Date(w.start).getTime())), itemStyle: { color: w.kind === "negative" ? "rgba(224,83,61,.14)" : "rgba(127,163,179,.14)" }, label: { show: !handy, position: "insideTopLeft", formatter: w.kind === "negative" ? "NEGATIV" : "PREISTIEF", color: w.kind === "negative" ? C.alert : C.price, fontFamily: MONO, fontSize: 10, letterSpacing: 1 } },
        { xAxis: Math.min(24, hx(new Date(w.end).getTime())) },
      ]);
    const maxOf = (rows: Array<Array<number | null>>) => rows.reduce((m, p) => (typeof p[1] === "number" && Number.isFinite(p[1]) ? Math.max(m, p[1]) : m), 0);
    const powerMax = Math.max(3, Math.ceil((maxOf([...pv, ...haus, ...pvPrognose, ...waerme, ...schattenPv]) * 1.1) / 2) * 2);
    const { min: pMin, max: pMax, step: pStep } = priceBounds([...preisHist, ...preisVoraus]);
    const preisAchse = handy ? 1 : 0;
    const jetzt = tag === "heute" ? { symbol: "none", silent: true, lineStyle: { color: "var(--amber-soft)", type: "dashed", width: 1.2 }, label: { show: false }, data: [{ xAxis: hx(nowMs) }] } : undefined;
    // Was davon im Bild steht: danach richtet sich die Legende (`tageslegende.ts`).
    const inhalt: Kurveninhalt = {
      schattenwort: schatten ? schattenWort(schatten) : null,
      waermepumpeGemessen: false,
      waermepumpeErwartet: waerme.length > 0,
      preisGemessen: preisHist.some((p) => p[1] != null),
      preisErwartet: preisVoraus.some((p) => p[1] != null),
      baender: baender.length > 0,
    };
    const option: EChartsCoreOption = {
      animation: false,
      backgroundColor: "transparent",
      textStyle: { fontFamily: MONO },
      tooltip: {
        trigger: "axis",
        backgroundColor: C.deep,
        borderColor: "rgba(255,255,255,.14)",
        borderRadius: 3,
        textStyle: { color: "rgba(255,255,255,.92)", fontFamily: MONO, fontSize: 12 },
        formatter: (params: unknown) => {
          const ps = params as Array<{ seriesName: string; value: [number, number | null]; color: string }>;
          if (!ps.length) return "";
          const t = hhmm(new Date(start + ps[0]!.value[0] * 3600000));
          const rows = ps
            .filter((p) => p.value[1] != null)
            .map((p) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${p.value[1]!.toFixed(1).replace(".", ",")} ${p.seriesName.startsWith("Preis") || p.seriesName === "Strompreis" ? "ct" : "kW"}</span></div>`)
            .join("");
          return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>${rows}`;
        },
      },
      grid: handy
        ? [
            { left: 44, right: 10, top: 10, bottom: PREIS_HOEHE + 22 + 22, outerBoundsMode: "none" },
            { left: 44, right: 10, height: PREIS_HOEHE, bottom: 22, outerBoundsMode: "none" },
          ]
        : { left: 40, right: 44, top: 10, bottom: 24 },
      xAxis: [0, 1].slice(0, handy ? 2 : 1).map((gridIndex) => ({ type: "value" as const, gridIndex, min: 0, max: 24, interval: 6, axisLine: { lineStyle: { color: C.axis } }, axisTick: { show: false }, splitLine: { show: false }, axisLabel: { show: !handy || gridIndex === 1, color: C.text, fontFamily: MONO, fontSize: handy ? 11 : 10, ...(handy ? { alignMaxLabel: "right" as const } : {}), formatter: (v: number) => `${String(v % 24).padStart(2, "0")}:00` } })),
      yAxis: [
        { type: "value", gridIndex: 0, min: 0, max: powerMax, interval: powerMax / 2, splitLine: { lineStyle: { color: C.gridline } }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: handy ? 11 : 10, formatter: (v: number) => `${v} kW` } },
        handy
          ? { type: "value", gridIndex: 1, min: pMin, max: pMax, interval: Math.max(pStep, (pMax - pMin) / 2), splitLine: { lineStyle: { color: C.gridline } }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: 11, formatter: ganzeCent } }
          : { type: "value", position: "right", min: pMin, max: pMax, interval: pStep, splitLine: { show: false }, axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, formatter: (v: number) => `${v} ct` } },
      ],
      series: [
        { name: `Sonne ${schatten?.wort ?? ""}`.trim(), type: "line", yAxisIndex: 0, data: schattenPv, showSymbol: false, lineStyle: { color: C.pvSchatten, width: 1.6, opacity: 0.75 }, z: 1 },
        { name: "Sonne", type: "line", yAxisIndex: 0, data: pv, showSymbol: false, lineStyle: { color: C.pv, width: 2 }, areaStyle: { color: { type: "linear", x: 0, y: 0, x2: 0, y2: 1, colorStops: [{ offset: 0, color: "rgba(242,169,0,.45)" }, { offset: 1, color: "rgba(242,169,0,.04)" }] } }, markArea: { silent: true, data: baender }, ...(jetzt ? { markLine: jetzt } : {}), z: 3 },
        { name: "Sonne, Prognose", type: "line", yAxisIndex: 0, data: pvPrognose, showSymbol: false, lineStyle: { color: C.pv, width: 1.5, type: [5, 5], opacity: 0.7 }, areaStyle: { color: "rgba(242,169,0,.08)" }, z: 2 },
        { name: "Haus", type: "line", yAxisIndex: 0, data: haus, showSymbol: false, lineStyle: { color: "rgba(255,255,255,.88)", width: 1.8 }, z: 4 },
        { name: "Wärmepumpe, erwartet", type: "line", step: "end", yAxisIndex: 0, data: waerme, showSymbol: false, lineStyle: { color: C.heatPump, width: 1.5, type: [5, 5], opacity: 0.9 }, z: 3 },
        { name: "Strompreis", type: "line", step: "end", xAxisIndex: preisAchse, yAxisIndex: 1, data: preisHist, showSymbol: false, lineStyle: { color: C.price, width: 1.6 }, ...(handy ? { areaStyle: { color: "rgba(127,163,179,.10)" }, markArea: { silent: true, data: baender }, ...(jetzt ? { markLine: jetzt } : {}) } : {}), z: 3 },
        { name: "Preis voraus", type: "line", step: "end", xAxisIndex: preisAchse, yAxisIndex: 1, data: preisVoraus, showSymbol: false, lineStyle: { color: C.price, width: 1.6, type: [5, 5], opacity: 0.8 }, z: 2 },
      ],
    };
    return { option, inhalt };
  }, [tag, history, plan, heat, schatten, nowMs, start, end, handy]);

  // Die Legende nennt, was im Bild steht, und jede Marke sieht aus wie ihre Linie (`tageslegende.ts`).
  const legende = (
    <>
      {tageslegende(tag, inhalt).map((e) => (
        <span key={e.reihe} className="flex items-center gap-1.5 text-[12px] text-text-2">
          <span
            className="inline-block"
            style={e.form === "flaeche" ? { width: 14, height: 8, background: LEGENDENFARBE[e.reihe], borderRadius: 2, opacity: 0.6 } : { width: 18, borderTop: `2px ${e.form === "gestrichelt" ? "dashed" : "solid"} ${LEGENDENFARBE[e.reihe]}` }}
          />
          {e.wort}
        </span>
      ))}
    </>
  );
  return (
    <div className="home-kurve">
      <div className="home-kurve-kopf">
        <div className="home-tage" role="tablist" aria-label="Tag">
          {TAGE.map((t) => (
            <button key={t} role="tab" aria-selected={t === tag} onClick={() => onTag(t)} className="home-tag" style={{ background: t === tag ? "var(--amber)" : "transparent", color: t === tag ? "var(--petrol)" : "var(--text-2)" }}>
              {TAG_WORT[t]}
            </button>
          ))}
        </div>
        {/* Die vier Zahlen des Tages stehen im Kopf der Karte und wechseln mit dem Tag. */}
        {zahlen}
      </div>
      <div className="home-kurve-bild min-h-0 flex-1">
        <EChart option={option} />
      </div>
      <div className="home-kurve-legende-unten">{legende}</div>
    </div>
  );
}

/** Höhe der Preisfläche am Handy, in Punkten. */
const PREIS_HOEHE = 58;

/**
 * Die Beschriftung der Preisachse am Telefon: nur ganze Cent. Die mittlere Marke liegt dort auf
 * der Hälfte zwischen den Enden; bei 0 bis 45 ct stand „22.5 ct“ da, mit Punkt und links
 * abgeschnitten (gesehen am 27.11.2026). Die Linie der Marke bleibt, nur ihr Wort entfällt.
 */
const ganzeCent = (v: number) => (Number.isInteger(v) ? `${v} ct` : "");

/** Die Farbe der Marke je Reihe: dieselbe wie die der Linie im Bild. */
const LEGENDENFARBE: Record<Legendenreihe, string> = {
  sonne: C.pv,
  sonneErwartet: C.pv,
  schatten: C.pvSchatten,
  haus: "rgba(255,255,255,.88)",
  waermepumpe: C.heatPump,
  waermepumpeErwartet: C.heatPump,
  strompreis: C.price,
  preistief: C.price,
};

/** „gestern 8,1 kWh": der Tag im Hintergrund und seine Sonne bis zur gleichen Uhrzeit. */
function schattenWort(s: Schatten): string {
  if (s.kwh == null) return s.wort;
  return `${s.wort} ${s.kwh.toFixed(1).replace(".", ",")} kWh`;
}
