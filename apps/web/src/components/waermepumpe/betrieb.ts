import type { EChartsCoreOption } from "echarts/core";
import type { Betrieb, BetriebKlasse, BetriebStunde, BetriebTag } from "@/lib/api/models";
import { C, MONO } from "@/components/charts/palette";
import { dauer } from "./bilanz";

/**
 * Der Betrieb der Wärmepumpe über Tage als Bild: die Rechnungen hinter den vier Diagrammen.
 *
 * Vier Fragen, vier Diagramme, jedes mit einer Achse:
 *
 * 1. Wie lange lief sie, und womit? Gestapelte Balken je Tag: Heizen, Abtauen, Heizstab.
 * 2. Wie gut war sie? Die Arbeitszahl je Tag, einmal über alles (mit Anlauf, Abtauen und
 *    Heizstab) und einmal nur im eingeschwungenen Heizbetrieb. Der Abstand ist, was Takten und
 *    Abtauen kosten.
 * 3. Taktet sie? Die Lauflängen als Balken je Klasse. Viele Läufe unter zehn Minuten sind
 *    Läufe, die nie aus dem Anlauf herauskommen.
 * 4. Was verlangt der Regler? Der Vorlauf-Sollwert je Stunde über der Außentemperatur: die
 *    Heizkurve, wie sie am Gerät eingestellt ist, mit der Geraden durch die Punkte.
 */

const de = (n: number, stellen = 1): string => n.toFixed(stellen).replace(".", ",");
export const zahl = de;

const FLAECHE = "#123544";
const tooltip = {
  confine: true,
  backgroundColor: C.deep,
  borderColor: "rgba(255,255,255,.14)",
  borderRadius: 3,
  textStyle: { color: "rgba(255,255,255,.92)", fontFamily: MONO, fontSize: 12 },
};
const achse = {
  axisLine: { onZero: false, lineStyle: { color: C.axis } },
  axisTick: { show: false },
  axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10 },
  splitLine: { lineStyle: { color: C.gridline } },
  nameTextStyle: { color: C.text, fontFamily: MONO, fontSize: 10 },
};
const legende = { show: true, bottom: 0, left: 0, itemWidth: 16, itemHeight: 8, textStyle: { color: C.text, fontFamily: MONO, fontSize: 10 } };

/** Der Tag als „14.11.“. Das Datum kommt als Ortstag vom Dienst und wird nicht umgerechnet. */
export function tagName(tag: string): string {
  const [, monat, t] = tag.split("-");
  return `${Number(t)}.${Number(monat)}.`;
}

/** Die Stunden eines Tages nach dem, was die Maschine tat. Heizen ist der Lauf ohne Abtauen
 *  und ohne die Minuten mit Heizstab; zusammen ergeben die drei die Laufzeit. */
export function stundenTeile(t: BetriebTag): { heizen: number; abtauen: number; heizstab: number } {
  const heizen = Math.max(0, t.lauf_min - t.abtau_min - t.zusatz_min);
  return { heizen: heizen / 60, abtauen: t.abtau_min / 60, heizstab: t.zusatz_min / 60 };
}

/** Starts je Tag, über die Tage mit Betrieb. Ein Tag ohne Lauf drückt den Schnitt nicht. */
export function startsJeTag(d: Betrieb): number | null {
  const tage = d.tage.filter((t) => t.lauf_min > 0).length;
  return tage ? d.starts / tage : null;
}

/** Der Anteil des Abtauens an der Laufzeit, 0 bis 1. */
export function abtauAnteil(d: Betrieb): number | null {
  return d.lauf_min > 0 ? d.abtau_min / d.lauf_min : null;
}

/** Der Anteil der vollständigen Läufe, die kürzer als zehn Minuten waren. */
export function kurzAnteil(d: Betrieb): number | null {
  const alle = d.klassen.reduce((s, k) => s + k.laeufe, 0);
  const kurz = d.klassen.find((k) => k.von_min === 0)?.laeufe ?? 0;
  return alle ? kurz / alle : null;
}

export function klassenName(k: BetriebKlasse): string {
  if (k.von_min === 0) return `unter ${k.bis_min} min`;
  if (k.bis_min == null) return `ab ${k.von_min} min`;
  return `${k.von_min} bis ${k.bis_min}`;
}

const zeile = (k: string, v: string) => `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:rgba(255,255,255,.6)">${k}</span><span>${v}</span></div>`;
const kopf = (t: string) => `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${t}</div>`;

export function tagZeilen(t: BetriebTag): string {
  return [
    kopf(tagName(t.tag)),
    zeile("Lauf", dauer(t.lauf_min)),
    zeile("Starts", String(t.starts)),
    t.abtau_min ? zeile("Abtauen", `${dauer(t.abtau_min)} · ${t.abtauungen}-mal`) : "",
    t.zusatz_min ? zeile("Heizstab", dauer(t.zusatz_min)) : "",
    zeile("Strom", `${de(t.strom_kwh)} kWh`),
    t.aussen_c != null ? zeile("draußen", `${de(t.aussen_c)} °C`) : "",
  ].join("");
}

export function optionStunden(d: Betrieb): EChartsCoreOption {
  const teile = d.tage.map(stundenTeile);
  const reihe = (name: string, farbe: string, wert: (t: { heizen: number; abtauen: number; heizstab: number }) => number) => ({
    name,
    type: "bar",
    stack: "lauf",
    barMaxWidth: 26,
    // Ein Spalt in der Farbe der Fläche trennt die Teile eines Balkens.
    itemStyle: { color: farbe, borderColor: FLAECHE, borderWidth: 1, borderRadius: 2 },
    data: teile.map((t) => Number(wert(t).toFixed(2))),
  });
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "axis", axisPointer: { type: "shadow" }, formatter: (x: { dataIndex: number }[]) => { const t = d.tage[x[0]?.dataIndex ?? -1]; return t ? tagZeilen(t) : ""; } },
    legend: { ...legende, data: ["Heizen", "Abtauen", "Heizstab"] },
    grid: { left: 40, right: 14, top: 14, bottom: 48 },
    xAxis: { type: "category", data: d.tage.map((t) => tagName(t.tag)), ...achse },
    yAxis: { type: "value", name: "Stunden", ...achse },
    series: [reihe("Heizen", C.heatPump, (t) => t.heizen), reihe("Abtauen", C.battery, (t) => t.abtauen), reihe("Heizstab", C.grid, (t) => t.heizstab)],
  };
}

/** Die Grenzen der Achse der Arbeitszahl: ganze Zahlen um die Werte, mindestens von 2 bis 5. */
export function copAchse(d: Betrieb): [number, number] {
  const werte = d.tage.flatMap((t) => [t.cop_tag, t.cop_heizen]).filter((v): v is number => v != null);
  if (!werte.length) return [2, 5];
  return [Math.min(2, Math.floor(Math.min(...werte))), Math.max(5, Math.ceil(Math.max(...werte)))];
}

export function optionArbeitszahl(d: Betrieb): EChartsCoreOption {
  const [ymin, ymax] = copAchse(d);
  const reihe = (name: string, farbe: string, wert: (t: BetriebTag) => number | null | undefined) => ({
    name,
    type: "line",
    connectNulls: false,
    symbol: "circle",
    symbolSize: 8,
    lineStyle: { color: farbe, width: 2 },
    itemStyle: { color: farbe, borderColor: FLAECHE, borderWidth: 1.5 },
    data: d.tage.map((t) => wert(t) ?? null),
  });
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      ...tooltip,
      trigger: "axis",
      formatter: (x: { dataIndex: number }[]) => {
        const t = d.tage[x[0]?.dataIndex ?? -1];
        if (!t) return "";
        return [kopf(tagName(t.tag)), zeile("im Heizbetrieb", t.cop_heizen != null ? de(t.cop_heizen, 2) : "?"), zeile("über alles", t.cop_tag != null ? de(t.cop_tag, 2) : "?"), t.waerme_kwh != null ? zeile("Wärme", `${de(t.waerme_kwh)} kWh`) : ""].join("");
      },
    },
    legend: { ...legende, data: ["im Heizbetrieb", "über alles"] },
    grid: { left: 34, right: 14, top: 14, bottom: 48 },
    xAxis: { type: "category", data: d.tage.map((t) => tagName(t.tag)), ...achse },
    yAxis: { type: "value", min: ymin, max: ymax, name: "COP", ...achse },
    series: [reihe("im Heizbetrieb", C.heatPump, (t) => t.cop_heizen), reihe("über alles", C.house, (t) => t.cop_tag)],
  };
}

export function optionLauflaengen(d: Betrieb): EChartsCoreOption {
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "item", formatter: (x: { name: string; value: number }) => `${kopf(x.name)}${zeile("Läufe", String(x.value))}` },
    grid: { left: 34, right: 14, top: 22, bottom: 26 },
    xAxis: { type: "category", data: d.klassen.map(klassenName), ...achse },
    yAxis: { type: "value", name: "Läufe", minInterval: 1, ...achse },
    series: [
      {
        name: "Läufe",
        type: "bar",
        barMaxWidth: 46,
        itemStyle: { color: C.heatPump, borderRadius: [4, 4, 0, 0] },
        label: { show: true, position: "top", color: C.text, fontFamily: MONO, fontSize: 11 },
        data: d.klassen.map((k) => k.laeufe),
      },
    ],
  };
}

export function stundeZeilen(s: BetriebStunde): string {
  const wann = new Date(s.at).toLocaleString("de-DE", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", timeZone: "Europe/Berlin" });
  return [kopf(wann), zeile("draußen", `${de(s.aussen_c)} °C`), zeile("Sollwert", `${de(s.soll_c)} °C`), s.vorlauf_c != null ? zeile("erreicht", `${de(s.vorlauf_c)} °C`) : "", zeile("im Heizbetrieb", `${s.minuten} min`)].join("");
}

export function optionHeizkurve(d: Betrieb): EChartsCoreOption {
  const g = d.heizkurve;
  const erreicht = d.stunden.filter((s) => s.vorlauf_c != null);
  const namen = ["Sollwert", ...(erreicht.length ? ["erreicht"] : []), ...(g ? ["Gerade"] : [])];
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: { ...tooltip, trigger: "item" },
    legend: { ...legende, data: namen },
    grid: { left: 40, right: 18, top: 14, bottom: 62 },
    xAxis: { type: "value", scale: true, name: "Außentemperatur °C", nameLocation: "middle", nameGap: 26, ...achse },
    yAxis: { type: "value", scale: true, name: "Vorlauf °C", ...achse },
    series: [
      ...(g
        ? [
            {
              name: "Gerade",
              type: "line",
              showSymbol: false,
              data: [g.aussen_von_c, g.aussen_bis_c].map((ta) => [ta, g.a + g.b * ta]),
              lineStyle: { color: "rgba(255,255,255,.85)", width: 2 },
              itemStyle: { color: "rgba(255,255,255,.85)" },
              tooltip: { show: false },
              z: 3,
            },
          ]
        : []),
      ...(erreicht.length
        ? [
            {
              name: "erreicht",
              type: "scatter",
              data: erreicht.map((s) => ({ value: [s.aussen_c, s.vorlauf_c], s })),
              symbol: "diamond",
              symbolSize: 8,
              itemStyle: { color: C.battery, borderColor: FLAECHE, borderWidth: 1 },
              tooltip: { formatter: (x: { data: { s: BetriebStunde } }) => stundeZeilen(x.data.s) },
              z: 2,
            },
          ]
        : []),
      {
        name: "Sollwert",
        type: "scatter",
        data: d.stunden.map((s) => ({ value: [s.aussen_c, s.soll_c], s })),
        symbolSize: 9,
        itemStyle: { color: C.heatPump, borderColor: FLAECHE, borderWidth: 1.5 },
        tooltip: { formatter: (x: { data: { s: BetriebStunde } }) => stundeZeilen(x.data.s) },
        z: 4,
      },
    ],
  };
}
