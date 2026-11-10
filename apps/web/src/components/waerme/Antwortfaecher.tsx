"use client";

import { useMemo } from "react";
import type { EChartsCoreOption } from "echarts/core";
import { EChart } from "@/components/charts/EChart";
import { C, MONO } from "@/components/charts/palette";
import type { Kontaktwirkung } from "@/lib/api/models";
import { achsenText, deckung, prozentZahl } from "./wirkung";

/**
 * Der Antwortfächer: alle Schließvorgänge am Nullpunkt übereinandergelegt.
 *
 * Zwei Flächen auf einer Zeitachse, die nicht die Uhrzeit zeigt, sondern die Minuten vor und nach
 * dem Schließen. **Oben die Leistung:** jede einzelne Antwort als dünne Kurve, darüber das Mittel
 * und das Band zwischen dem unteren und oberen Viertel. Links der Null steht, was die Maschine
 * ohnehin tat, rechts, was auf den Kontakt folgte. **Unten der Anlauf:** welcher Anteil der
 * Ereignisse bis zu dieser Minute angelaufen war, und gestrichelt dieselbe Kurve für Momente ohne
 * Schließvorgang zur selben Tageszeit. Der Abstand der beiden Kurven ist die Wirkung.
 *
 * **Das Mittel, nicht der Median.** Die Maschine läuft oder steht. Bei drei laufenden und drei
 * stehenden läge der Median auf halber Höhe, wo keine einzige Kurve je lag; das Mittel liegt auch
 * dort, aber es bedeutet etwas: Anteil mal Leistung, also womit nach dem Schließen zu rechnen ist.
 *
 * **Zwei Flächen statt zweier Achsen.** Kilowatt und Prozent in einem Gitter läsen sich als
 * Zusammenhang ihrer Kreuzungspunkte, und die sind Zufall der Skalierung.
 *
 * Das Band der Viertel erscheint erst ab acht Ereignissen, derselben Zahl, ab der es ein Urteil
 * gibt. Bei vieren ist ein Viertel der Wert eines einzelnen Ereignisses: mit drei stehenden und
 * einer laufenden Maschine reichte das Band von null bis zu einem Viertel der Leistung dieser
 * einen, eine Höhe, auf der keine einzige Kurve je lag (gesehen am 09.11.2026 in der Vorführung).
 * Die einzelnen Kurven zeigen dann selbst, was da ist.
 */

const LINKS = 46;
const RECHTS = 34;
const OBEN = { top: 30, hoehe: 210 };
const UNTEN = { top: OBEN.top + OBEN.hoehe + 58, hoehe: 110 };
const HOEHE = UNTEN.top + UNTEN.hoehe + 34;
/** Mehr einzelne Kurven zeichnet der Fächer nicht; darüber wird die Wolke nicht dichter, nur langsamer. */
const MAX_KURVEN = 80;
export const MIN_FUER_BAND = 8;

function blass(hex: string, d: number): string {
  const n = Number.parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${d})`;
}

function de(x: number, n = 1): string {
  return x.toLocaleString("de-DE", { minimumFractionDigits: n, maximumFractionDigits: n });
}

export function Antwortfaecher({ daten }: { daten: Kontaktwirkung }) {
  const option = useMemo<EChartsCoreOption>(() => {
    const f = daten.faecher;
    const minuten = f.minuten;
    const paar = (werte: readonly (number | null | undefined)[]) => minuten.map((m, i) => [m, werte[i] ?? null]);
    const auswertbar = (daten.ereignisse ?? []).filter((e) => e.auswertbar).slice(-MAX_KURVEN);
    const d = deckung(auswertbar.length);
    const mitBand = minuten.map((_, i) => (f.n[i] ?? 0) >= MIN_FUER_BAND);
    const q25 = minuten.map((m, i) => [m, mitBand[i] ? (f.q25_kw[i] ?? null) : null]);
    const spanne = minuten.map((m, i) => {
      const a = f.q25_kw[i];
      const b = f.q75_kw[i];
      return [m, mitBand[i] && a != null && b != null ? b - a : null];
    });
    const angelaufen = minuten.map((m, i) => {
      const w = f.anteil_angelaufen?.[i];
      return [m, w == null ? null : w * 100];
    });
    const ohne = (daten.vergleich.angelaufen_bis ?? []).map((w, m) => [m, w * 100]);
    const xAchse = (gridIndex: number, zeigen: boolean) => ({
      type: "value" as const,
      gridIndex,
      min: -daten.vor_min,
      max: daten.nach_min,
      interval: 30,
      axisLine: { show: zeigen, lineStyle: { color: C.axis } },
      axisTick: { show: false },
      axisLabel: zeigen
        ? {
            color: C.text,
            fontFamily: MONO,
            fontSize: 10,
            hideOverlap: true,
            // Die Einheit nur am Ende: sechsmal „min" nebeneinander stößt auf schmalen Schirmen
            // zusammen, und einmal genügt.
            formatter: (v: number) => (v === 0 || v === daten.nach_min ? achsenText(v) : `${v > 0 ? "+" : "−"}${Math.abs(v)}`),
          }
        : { show: false },
      splitLine: { show: false },
      axisPointer: { show: true },
    });
    const nullLinie = {
      silent: true,
      symbol: ["none", "none"] as [string, string],
      lineStyle: { color: "rgba(255,255,255,.75)", width: 1.5, type: "solid" as const },
      label: { show: false },
      data: [{ xAxis: 0 }],
    };
    return {
      animation: false,
      backgroundColor: "transparent",
      // Jede Fläche hat ihren Titel über sich, in Textfarbe. Neben der Achse stieße er mit deren
      // Zahlen zusammen, und die Einheit allein sagte nicht, wovon die Fläche handelt.
      graphic: [
        { type: "text" as const, left: 0, top: OBEN.top - 22, silent: true, style: { text: "Leistung der Wärmepumpe in kW", fill: C.text, font: `10px ${MONO}` } },
        {
          type: "text" as const,
          left: 0,
          top: UNTEN.top - 22,
          silent: true,
          style: { text: "Anteil, der bis hier angelaufen ist", fill: C.text, font: `10px ${MONO}` },
        },
      ],
      axisPointer: { link: [{ xAxisIndex: "all" }], label: { show: false }, lineStyle: { color: "rgba(255,255,255,.3)" } },
      tooltip: {
        trigger: "axis" as const,
        confine: true,
        backgroundColor: C.deep,
        borderColor: "rgba(242,169,0,.4)",
        textStyle: { color: "#f1f5f5", fontSize: 12 },
        formatter: (params: unknown) => {
          const arr = Array.isArray(params) ? params : [params];
          const m = Math.round(Number((arr[0] as { axisValue?: unknown } | undefined)?.axisValue));
          const i = minuten.indexOf(m);
          if (i < 0) return "";
          const marke = (farbe: string, gestrichelt = false) =>
            `<span style="display:inline-block;width:10px;height:0;border-top:2px ${gestrichelt ? "dashed" : "solid"} ${farbe};margin:0 6px 3px 0"></span>`;
          const med = f.mittel_kw?.[i];
          const a = f.q25_kw[i];
          const b = f.q75_kw[i];
          const kopf = m === 0 ? "Anforderung beginnt" : m > 0 ? `${m} min nach Beginn der Anforderung` : `${-m} min vor der Anforderung`;
          const zeilen = [`<div style="margin-bottom:4px"><b>${kopf}</b></div>`];
          if (med == null) {
            zeilen.push(`<div style="opacity:.78">keine Messung</div>`);
          } else {
            zeilen.push(`<div>${marke(C.heatPump)}im Mittel ${de(med)} kW</div>`);
            if (mitBand[i] && a != null && b != null) zeilen.push(`<div style="opacity:.78;padding-left:16px">mittlere Hälfte ${de(a)} bis ${de(b)} kW</div>`);
            zeilen.push(`<div style="opacity:.78;padding-left:16px">läuft in ${prozentZahl(f.anteil_laeuft[i])} % der ${f.n[i]} Ereignisse</div>`);
          }
          const an = f.anteil_angelaufen?.[i];
          if (an != null) zeilen.push(`<div style="margin-top:4px">${marke(C.heatPump)}angelaufen ${prozentZahl(an)} %</div>`);
          const o = daten.vergleich.angelaufen_bis?.[m];
          if (m >= 0 && o != null) zeilen.push(`<div>${marke(C.mist, true)}ohne Anforderung ${prozentZahl(o)} %</div>`);
          return zeilen.join("");
        },
      },
      grid: [
        // `outerBoundsMode: "none"`: ECharts 6 rückt ein Gitter sonst ein, sobald eine
        // Achsenbeschriftung übersteht. Das untere wäre dann schmaler als das obere, und der
        // Nullpunkt stünde in beiden an verschiedener Stelle.
        { left: LINKS, right: RECHTS, top: OBEN.top, height: OBEN.hoehe, outerBoundsMode: "none" as const },
        { left: LINKS, right: RECHTS, top: UNTEN.top, height: UNTEN.hoehe, outerBoundsMode: "none" as const },
      ],
      xAxis: [xAchse(0, false), xAchse(1, true)],
      yAxis: [
        {
          gridIndex: 0,
          min: 0,
          splitNumber: 3,
          axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10 },
          splitLine: { lineStyle: { color: C.gridline } },
        },
        {
          gridIndex: 1,
          min: 0,
          max: 100,
          interval: 50,
          axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, formatter: "{value} %" },
          splitLine: { lineStyle: { color: C.gridline } },
        },
      ],
      series: [
        // Die einzelnen Antworten. Still und ohne Tooltip: gelesen wird die Wolke, das einzelne
        // Ereignis steht im Raster darunter.
        ...auswertbar.map((e, k) => ({
          name: `e${k}`,
          type: "line" as const,
          silent: true,
          showSymbol: false,
          connectNulls: false,
          tooltip: { show: false },
          data: paar(e.kw),
          lineStyle: { color: blass(C.heatPump, d), width: 1 },
          z: 1,
        })),
        // Das Band zwischen den Vierteln: eine unsichtbare Untergrenze, darauf gestapelt die Spanne.
        { name: "q25", type: "line" as const, stack: "band", silent: true, showSymbol: false, data: q25, lineStyle: { opacity: 0 }, z: 2 },
        {
          name: "Spanne",
          type: "line" as const,
          stack: "band",
          silent: true,
          showSymbol: false,
          data: spanne,
          lineStyle: { opacity: 0 },
          areaStyle: { color: C.heatPump, opacity: 0.22 },
          z: 2,
        },
        {
          name: "Mittel",
          type: "line" as const,
          showSymbol: false,
          connectNulls: false,
          data: paar(f.mittel_kw ?? []),
          // Die Farbe auch am Punkt unter dem Zeiger; sonst nähme er eine aus der Vorgabe.
          itemStyle: { color: C.heatPump },
          lineStyle: { color: C.heatPump, width: 2 },
          z: 3,
          markLine: {
            ...nullLinie,
            // Die Schwelle steht mit im Bild: an ihr hängt, was hier „läuft" heißt.
            data: [
              { xAxis: 0 },
              {
                yAxis: daten.schwelle_kw,
                lineStyle: { color: C.axis, width: 1, type: "dashed" as const },
                label: {
                  show: true,
                  // Links, vor dem Schließen: dort stehen die Maschinen nach Voraussetzung, die
                  // Fläche ist also frei. Rechts läge die Schrift auf der Kurve des Mittels.
                  position: "insideStartTop" as const,
                  formatter: `läuft ab ${de(daten.schwelle_kw)} kW`,
                  color: C.text,
                  fontFamily: MONO,
                  fontSize: 10,
                },
              },
            ],
          },
        },
        {
          name: "angelaufen",
          type: "line" as const,
          step: "end" as const,
          showSymbol: false,
          xAxisIndex: 1,
          yAxisIndex: 1,
          data: angelaufen,
          itemStyle: { color: C.heatPump },
          lineStyle: { color: C.heatPump, width: 2 },
          areaStyle: { color: C.heatPump, opacity: 0.12 },
          markLine: nullLinie,
          // Das Folgefenster: nur ein Anlauf in diesem Streifen zählt in die Quote.
          markArea: {
            silent: true,
            itemStyle: { color: "rgba(255,255,255,.05)" },
            label: { show: true, position: "insideTopLeft" as const, color: C.text, fontFamily: MONO, fontSize: 10, formatter: `zählt als Folge: ${daten.folge_min} min` },
            data: [[{ xAxis: 0 }, { xAxis: daten.folge_min }]],
          },
        },
        {
          name: "ohne Anforderung",
          type: "line" as const,
          step: "end" as const,
          showSymbol: false,
          xAxisIndex: 1,
          yAxisIndex: 1,
          data: ohne,
          itemStyle: { color: C.mist },
          lineStyle: { color: C.mist, width: 2, type: "dashed" as const },
        },
      ],
    };
  }, [daten]);

  return (
    <div style={{ height: HOEHE }}>
      <EChart option={option} />
    </div>
  );
}
