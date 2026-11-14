import type { EChartsCoreOption } from "echarts/core";
import type { Kennlinie, KennlinienFit, KennlinienPunkt } from "@/lib/api/models";
import { farbe } from "@/components/anlage/schema";
import { C, MONO } from "@/components/charts/palette";

/**
 * Die gemessene Kennlinie der Wärmepumpe als Bild: die Rechnungen hinter den drei Diagrammen.
 *
 * **Warum drei.** Die Arbeitszahl hängt an zwei Temperaturen, und ein Diagramm hat zwei Achsen.
 * Eine dreidimensionale Fläche sieht nach viel aus und lässt sich nicht ablesen: welcher Punkt
 * vorn liegt und welcher hinten, entscheidet der Blickwinkel. Stattdessen:
 *
 * 1. Arbeitszahl über der Außentemperatur, die Punkte in der Farbe ihres Vorlaufs, die
 *    Ausgleichsgeraden für zwei oder drei Vorläufe. Das ist die Kennlinie, wie sie im Datenblatt
 *    steht, und daneben die, mit der der Fahrplan bisher rechnet.
 * 2. Arbeitszahl über der Vorlauftemperatur. Solange das Wetter sich nicht ändert, ist das die
 *    Ansicht, in der überhaupt etwas zu sehen ist: eine Pufferladung durchläuft zwanzig Grad
 *    Vorlauf an einem Vormittag.
 * 3. Das Kennfeld: beide Temperaturen als Achsen, die Arbeitszahl als Farbe. Die Fläche von
 *    oben gesehen, mit einem Punkt, wo gemessen wurde.
 *
 * Die Farbe des Vorlaufs ist die des Wassers aus dem Anlagenschema: ein Punkt bei 35 Grad hat
 * die Farbe von 35 Grad warmem Wasser im Speicher.
 */

const de = (n: number, stellen = 1): string => n.toFixed(stellen).replace(".", ",");
export const zahl = de;

/** Die Arbeitszahl nach der Ausgleichsfläche. */
export const copNach = (f: KennlinienFit, aussen: number, vorlauf: number): number => f.a + f.b_aussen * aussen + f.c_vorlauf * vorlauf;

/** Die Arbeitszahl aller Punkte zusammen: Summe der Wärme durch Summe des Stroms, nicht das
 *  Mittel der einzelnen Arbeitszahlen. Ein Fenster mit 4 kW zählt mehr als eines mit 1 kW. */
export function gesamt(punkte: KennlinienPunkt[]): number | null {
  const strom = punkte.reduce((s, p) => s + p.strom_kw * p.minuten, 0);
  if (strom <= 0) return null;
  return punkte.reduce((s, p) => s + p.waerme_kw * p.minuten, 0) / strom;
}

export function mitte(werte: number[]): number | null {
  if (!werte.length) return null;
  const s = [...werte].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m]! : (s[m - 1]! + s[m]!) / 2;
}

/** Die Vorläufe, für die eine Gerade gezeichnet wird: runde Fünfer innerhalb der Messung,
 *  höchstens drei. Hat der Ausgleich keinen Term für den Vorlauf, gibt es nur eine Gerade. */
export function vorlaufStufen(f: KennlinienFit): number[] {
  if (f.art !== "ebene") return [];
  const stufen: number[] = [];
  for (let t = Math.ceil(f.vorlauf_von_c / 5) * 5; t <= f.vorlauf_bis_c; t += 5) stufen.push(t);
  if (stufen.length <= 3) return stufen;
  return [stufen[0]!, stufen[Math.floor((stufen.length - 1) / 2)]!, stufen[stufen.length - 1]!];
}

/** Was die Messung gegen die Annahme des Fahrplans sagt, je Stützstelle seiner Kennlinie. */
export interface Vergleich {
  aussen_c: number;
  annahme: number;
  messung: number;
  /** Liegt die Stelle dort, wo gemessen wurde? Sonst ist die Zahl eine Verlängerung. */
  gemessen: boolean;
}

/** Bei welchem Vorlauf der Vergleich gilt: bei dem der Annahme, wenn der Ausgleich den Vorlauf
 *  kennt, sonst beim mittleren Vorlauf der Messung, denn nur dort sagt er etwas. */
export function vergleichsVorlauf(d: Kennlinie): number | null {
  const f = d.fit;
  if (!f) return null;
  if ((f.art === "ebene" || f.art === "vorlauf") && d.annahme_vorlauf_c != null) return d.annahme_vorlauf_c;
  return mitte(d.punkte.map((p) => p.vorlauf_c));
}

export function vergleich(d: Kennlinie): Vergleich[] {
  const f = d.fit;
  const tv = vergleichsVorlauf(d);
  if (!f || tv == null) return [];
  const vorlaufGemessen = tv >= f.vorlauf_von_c && tv <= f.vorlauf_bis_c;
  return d.annahme.map((a) => ({
    aussen_c: a.aussen_c,
    annahme: a.cop,
    messung: copNach(f, a.aussen_c, tv),
    gemessen: vorlaufGemessen && a.aussen_c >= f.aussen_von_c && a.aussen_c <= f.aussen_bis_c,
  }));
}

// ----------------------------------------------------------------- Diagramme

const tooltip = {
  confine: true,
  backgroundColor: C.deep,
  borderColor: "rgba(255,255,255,.14)",
  borderRadius: 3,
  textStyle: { color: "rgba(255,255,255,.92)", fontFamily: MONO, fontSize: 12 },
};
const achse = {
  // Die Achsen bleiben am Rand: mit der Vorgabe wandert die senkrechte Achse auf null Grad und
  // steht mitten zwischen den Punkten.
  axisLine: { onZero: false, lineStyle: { color: C.axis } },
  axisTick: { show: false },
  axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10 },
  splitLine: { lineStyle: { color: C.gridline } },
  nameTextStyle: { color: C.text, fontFamily: MONO, fontSize: 10 },
};
const FLAECHE = "#123544";

function punktZeile(p: KennlinienPunkt): string {
  const wann = new Date(p.at).toLocaleString("de-DE", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", timeZone: "Europe/Berlin" });
  const zeile = (k: string, v: string) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:rgba(255,255,255,.6)">${k}</span><span>${v}</span></div>`;
  return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${wann}</div>${zeile("Arbeitszahl", de(p.cop, 2))}${zeile("draußen", `${de(p.aussen_c)} °C`)}${zeile("Vorlauf", `${de(p.vorlauf_c)} °C`)}${zeile("Wärme", `${de(p.waerme_kw)} kW`)}${zeile("Strom", `${de(p.strom_kw, 2)} kW`)}`;
}

/** Der Bereich der Arbeitszahl-Achse: was die Punkte und die Annahme brauchen, auf ganze gerundet. */
export function copAchse(d: Kennlinie): [number, number] {
  const werte = [...d.punkte.map((p) => p.cop), ...d.annahme.map((a) => a.cop)];
  if (!werte.length) return [1, 6];
  return [Math.max(0, Math.floor(Math.min(...werte) - 0.25)), Math.ceil(Math.max(...werte) + 0.25)];
}

/** Arbeitszahl über der Außentemperatur. */
export function optionAussen(d: Kennlinie): EChartsCoreOption {
  const f = d.fit;
  const [ymin, ymax] = copAchse(d);
  const linien: unknown[] = [];
  if (f) {
    const stufen = vorlaufStufen(f);
    const enden: Array<[number, string, string]> = stufen.length
      ? stufen.map((tv) => [tv, `${tv} °C Vorlauf`, farbe(tv)] as [number, string, string])
      : [[mitte(d.punkte.map((p) => p.vorlauf_c)) ?? 40, "Ausgleich", "rgba(255,255,255,.85)"]];
    for (const [tv, name, col] of enden) {
      linien.push({
        name,
        type: "line",
        showSymbol: false,
        data: [f.aussen_von_c, f.aussen_bis_c].map((ta) => [ta, copNach(f, ta, tv)]),
        lineStyle: { color: col, width: 2 },
        itemStyle: { color: col },
        endLabel: { show: true, formatter: name, color: col, fontFamily: MONO, fontSize: 10, distance: 6 },
        tooltip: { show: false },
        z: 3,
      });
    }
  }
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "item" },
    legend: { show: true, bottom: 0, left: 0, itemWidth: 16, itemHeight: 8, textStyle: { color: C.text, fontFamily: MONO, fontSize: 10 }, data: ["Messpunkt", "Annahme des Fahrplans"] },
    grid: { left: 40, right: 104, top: 14, bottom: 58 },
    xAxis: { type: "value", scale: true, name: "Außentemperatur °C", nameLocation: "middle", nameGap: 26, ...achse },
    yAxis: { type: "value", min: ymin, max: ymax, name: "COP", ...achse },
    series: [
      {
        name: "Annahme des Fahrplans",
        type: "line",
        data: d.annahme.map((a) => [a.aussen_c, a.cop]),
        showSymbol: true,
        symbol: "emptyCircle",
        symbolSize: 5,
        lineStyle: { color: "rgba(255,255,255,.5)", width: 1.5, type: "dashed" },
        itemStyle: { color: "rgba(255,255,255,.5)" },
        tooltip: { formatter: (p: { value: [number, number] }) => `Annahme des Fahrplans${d.annahme_vorlauf_c != null ? `, bei ${de(d.annahme_vorlauf_c, 0)} °C Vorlauf` : ""}<br/>${de(p.value[0], 0)} °C draußen: ${de(p.value[1])}` },
        z: 2,
      },
      ...linien,
      {
        name: "Messpunkt",
        type: "scatter",
        data: d.punkte.map((p) => ({ value: [p.aussen_c, p.cop], itemStyle: { color: farbe(p.vorlauf_c) }, p })),
        symbolSize: 9,
        itemStyle: { color: farbe(40), borderColor: FLAECHE, borderWidth: 1.5 },
        tooltip: { formatter: (x: { data: { p: KennlinienPunkt } }) => punktZeile(x.data.p) },
        z: 4,
      },
    ],
  };
}

/** Arbeitszahl über der Vorlauftemperatur, mit der Ausgleichsgeraden bei mittlerer Außentemperatur. */
export function optionVorlauf(d: Kennlinie): EChartsCoreOption {
  const f = d.fit;
  const [ymin, ymax] = copAchse({ ...d, annahme: [] });
  const ta = mitte(d.punkte.map((p) => p.aussen_c));
  const name = ta != null ? `Ausgleich bei ${de(ta, 0)} °C draußen` : "Ausgleich";
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "item" },
    legend: { show: true, bottom: 0, left: 0, itemWidth: 16, itemHeight: 8, textStyle: { color: C.text, fontFamily: MONO, fontSize: 10 }, data: ["Messpunkt", ...(f && ta != null ? [name] : [])] },
    grid: { left: 40, right: 18, top: 14, bottom: 58 },
    xAxis: { type: "value", scale: true, name: "Vorlauftemperatur °C", nameLocation: "middle", nameGap: 26, ...achse },
    yAxis: { type: "value", min: ymin, max: ymax, name: "COP", ...achse },
    series: [
      ...(f && ta != null
        ? [
            {
              name,
              type: "line",
              showSymbol: false,
              data: [f.vorlauf_von_c, f.vorlauf_bis_c].map((tv) => [tv, copNach(f, ta, tv)]),
              lineStyle: { color: "rgba(255,255,255,.85)", width: 2 },
              itemStyle: { color: "rgba(255,255,255,.85)" },
              tooltip: { show: false },
              z: 3,
            },
          ]
        : []),
      {
        name: "Messpunkt",
        type: "scatter",
        data: d.punkte.map((p) => ({ value: [p.vorlauf_c, p.cop], p })),
        symbolSize: 9,
        itemStyle: { color: C.heatPump, borderColor: FLAECHE, borderWidth: 1.5 },
        tooltip: { formatter: (x: { data: { p: KennlinienPunkt } }) => punktZeile(x.data.p) },
        z: 4,
      },
    ],
  };
}

/** Das Raster des Kennfelds: ganze Grad draußen, Vorlauf in Schritten von zwei Grad. */
export function raster(f: KennlinienFit): { aussen: number[]; vorlauf: number[] } {
  const aussen: number[] = [];
  for (let t = Math.floor(f.aussen_von_c); t <= Math.ceil(f.aussen_bis_c); t += 1) aussen.push(t);
  const vorlauf: number[] = [];
  for (let t = Math.floor(f.vorlauf_von_c / 2) * 2; t <= Math.ceil(f.vorlauf_bis_c / 2) * 2; t += 2) vorlauf.push(t);
  return { aussen, vorlauf };
}

/** Wie viele Messpunkte in jedem Feld des Rasters liegen. */
export function belegung(punkte: KennlinienPunkt[], r: { aussen: number[]; vorlauf: number[] }): Array<[number, number, number]> {
  const n = new Map<string, number>();
  for (const p of punkte) {
    const i = r.aussen.indexOf(Math.round(p.aussen_c));
    const j = r.vorlauf.indexOf(Math.round(p.vorlauf_c / 2) * 2);
    if (i < 0 || j < 0) continue;
    n.set(`${i},${j}`, (n.get(`${i},${j}`) ?? 0) + 1);
  }
  return [...n].map(([k, v]) => [Number(k.split(",")[0]), Number(k.split(",")[1]), v]);
}

/** Eine Farbe, hell für viel: die Arbeitszahl im Kennfeld. */
const COP_FARBEN = ["#173847", "#2f5560", "#667a5c", "#b3993f", "#f2a900", "#ffd778"];

/** Das Kennfeld: die Ausgleichsfläche von oben, mit einem Punkt, wo gemessen wurde. */
export function optionFeld(d: Kennlinie): EChartsCoreOption | null {
  const f = d.fit;
  if (!f || f.art !== "ebene") return null;
  const r = raster(f);
  const zellen: Array<[number, number, number]> = [];
  r.aussen.forEach((ta, i) => r.vorlauf.forEach((tv, j) => zellen.push([i, j, Math.round(copNach(f, ta, tv) * 100) / 100])));
  const werte = zellen.map((z) => z[2]);
  const belegt = belegung(d.punkte, r);
  const meiste = Math.max(1, ...belegt.map((b) => b[2]));
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "item",
      formatter: (x: { seriesType: string; value: [number, number, number] }) => {
        const [i, j, v] = x.value;
        const ort = `${r.aussen[i]} °C draußen, ${r.vorlauf[j]} °C Vorlauf`;
        return x.seriesType === "scatter" ? `${ort}<br/>${v} ${v === 1 ? "Messpunkt" : "Messpunkte"}` : `${ort}<br/>Arbeitszahl nach Ausgleich: ${de(v, 2)}`;
      },
    },
    grid: { left: 44, right: 76, top: 14, bottom: 44 },
    xAxis: { type: "category", data: r.aussen.map(String), name: "Außentemperatur °C", nameLocation: "middle", nameGap: 26, ...achse, splitLine: { show: false } },
    yAxis: { type: "category", data: r.vorlauf.map(String), name: "Vorlauf °C", ...achse, splitLine: { show: false } },
    visualMap: {
      type: "continuous",
      seriesIndex: 0,
      min: Math.floor(Math.min(...werte) * 2) / 2,
      max: Math.ceil(Math.max(...werte) * 2) / 2,
      calculable: false,
      orient: "vertical",
      right: 0,
      top: "middle",
      itemHeight: 140,
      itemWidth: 10,
      text: [`COP ${de(Math.ceil(Math.max(...werte) * 2) / 2)}`, de(Math.floor(Math.min(...werte) * 2) / 2)],
      textStyle: { color: C.text, fontFamily: MONO, fontSize: 10 },
      inRange: { color: COP_FARBEN },
    },
    series: [
      { name: "Arbeitszahl nach Ausgleich", type: "heatmap", data: zellen, itemStyle: { borderColor: FLAECHE, borderWidth: 1 }, emphasis: { itemStyle: { borderColor: "#fff" } } },
      {
        name: "Messpunkte",
        type: "scatter",
        data: belegt,
        symbol: "circle",
        symbolSize: (v: [number, number, number]) => 5 + 7 * Math.sqrt(v[2] / meiste),
        itemStyle: { color: "rgba(8,36,49,.85)", borderColor: "#fff", borderWidth: 1.2 },
        z: 3,
      },
    ],
  };
}
