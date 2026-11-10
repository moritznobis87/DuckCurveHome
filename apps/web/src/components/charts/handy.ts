import type { EChartsCoreOption } from "echarts/core";

/**
 * Ein Diagramm für das Handy nachstellen, ohne dass jedes Diagramm davon wissen muss.
 *
 * Die Diagramme sind für den Rechner eingestellt: Achsenschrift 10 Punkt, fünf Achsenwerte,
 * Legenden, die umbrechen dürfen. Am Handy sind 10 Punkt zu klein, fünf Werte an einer 150
 * Punkte hohen Achse zu viele, und eine umbrechende Legende liegt auf dem Bild. Was sich für
 * alle gleich beantworten lässt, steht hier an einer Stelle:
 *
 * - Achsenschrift mindestens 11 Punkt, überlappende Beschriftungen entfallen;
 * - Wertachsen ohne festes Raster zeigen höchstens drei Schritte;
 * - Legenden blättern in einer Zeile, statt umzubrechen;
 * - der Hinweis am Finger bleibt im Bild.
 *
 * Was ein Diagramm ausdrücklich gesetzt hat (ein festes `interval`, ausgeblendete Achsen), bleibt.
 * Die Form der Option bleibt erhalten: ein einzelnes Objekt bleibt eines, eine Liste eine Liste.
 */
type Ding = Record<string, unknown>;

const SCHRIFT = 11;

function je(wert: unknown, f: (d: Ding) => Ding): unknown {
  if (Array.isArray(wert)) return wert.map((w) => (w && typeof w === "object" ? f(w as Ding) : w));
  if (wert && typeof wert === "object") return f(wert as Ding);
  return wert;
}

function achse(a: Ding, wertachse: boolean): Ding {
  const neu: Ding = { ...a };
  const schrift = (a.axisLabel ?? {}) as Ding;
  if (schrift.show !== false) {
    const groesse = typeof schrift.fontSize === "number" ? schrift.fontSize : SCHRIFT;
    neu.axisLabel = { ...schrift, fontSize: Math.max(SCHRIFT, groesse), hideOverlap: true };
  }
  if (a.nameTextStyle && typeof a.nameTextStyle === "object") neu.nameTextStyle = { ...(a.nameTextStyle as Ding), fontSize: SCHRIFT };
  if (wertachse && a.type === "value" && a.interval == null) {
    const schritte = typeof a.splitNumber === "number" ? a.splitNumber : 4;
    neu.splitNumber = Math.min(schritte, 3);
  }
  return neu;
}

export function fuerHandy(option: EChartsCoreOption): EChartsCoreOption {
  const o = option as Ding;
  const neu: Ding = { ...o };
  if (o.xAxis) neu.xAxis = je(o.xAxis, (a) => achse(a, false));
  if (o.yAxis) neu.yAxis = je(o.yAxis, (a) => achse(a, true));
  if (o.legend) {
    neu.legend = je(o.legend, (l) => ({
      pageIconColor: "rgba(255,255,255,.6)",
      pageIconInactiveColor: "rgba(255,255,255,.15)",
      pageIconSize: 11,
      ...l,
      type: "scroll",
      itemGap: 14,
      textStyle: { ...((l.textStyle ?? {}) as Ding), fontSize: 12 },
      pageTextStyle: { color: "rgba(255,255,255,.6)", fontSize: 11, ...((l.pageTextStyle ?? {}) as Ding) },
    }));
  }
  if (o.tooltip) neu.tooltip = je(o.tooltip, (t) => ({ ...t, confine: true }));
  return neu as EChartsCoreOption;
}
