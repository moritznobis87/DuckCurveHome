import { describe, expect, it } from "vitest";
import type { EChartsCoreOption } from "echarts/core";
import { fuerHandy } from "./handy";

type Ding = Record<string, unknown>;

describe("fuerHandy", () => {
  it("hebt die Achsenschrift auf mindestens 11 Punkt und lässt größere stehen", () => {
    const o = fuerHandy({
      xAxis: { type: "category", axisLabel: { fontSize: 10, color: "#fff" } },
      yAxis: [{ type: "value", axisLabel: { fontSize: 14 } }, { type: "value" }],
    } as EChartsCoreOption) as Ding;
    expect(((o.xAxis as Ding).axisLabel as Ding).fontSize).toBe(11);
    expect(((o.xAxis as Ding).axisLabel as Ding).color).toBe("#fff");
    const y = o.yAxis as Ding[];
    expect((y[0]!.axisLabel as Ding).fontSize).toBe(14);
    expect((y[1]!.axisLabel as Ding).fontSize).toBe(11);
  });

  it("zeigt an Wertachsen höchstens drei Schritte, außer das Raster ist fest gesetzt", () => {
    const o = fuerHandy({
      yAxis: [
        { type: "value", splitNumber: 5 },
        { type: "value", splitNumber: 2 },
        { type: "value", interval: 10, splitNumber: 8 },
        { type: "category" },
      ],
    } as EChartsCoreOption) as Ding;
    const y = o.yAxis as Ding[];
    expect(y[0]!.splitNumber).toBe(3);
    expect(y[1]!.splitNumber).toBe(2);
    expect(y[2]!.splitNumber).toBe(8);
    expect(y[3]!.splitNumber).toBeUndefined();
  });

  it("lässt eine ausgeblendete Achsenbeschriftung ausgeblendet", () => {
    const o = fuerHandy({ xAxis: [{ type: "time", axisLabel: { show: false } }] } as EChartsCoreOption) as Ding;
    expect((o.xAxis as Ding[])[0]!.axisLabel).toEqual({ show: false });
  });

  it("macht aus der Legende eine blätterbare Zeile und behält ihre Lage", () => {
    const o = fuerHandy({ legend: { bottom: 0, textStyle: { color: "#abc", fontSize: 10 } } } as EChartsCoreOption) as Ding;
    const l = o.legend as Ding;
    expect(l.type).toBe("scroll");
    expect(l.bottom).toBe(0);
    expect(l.textStyle).toEqual({ color: "#abc", fontSize: 12 });
  });

  it("hält den Hinweis im Bild und ändert die Vorlage nicht", () => {
    const vorlage = { tooltip: { trigger: "axis" }, yAxis: { type: "value", splitNumber: 5 } };
    const o = fuerHandy(vorlage as EChartsCoreOption) as Ding;
    expect((o.tooltip as Ding).confine).toBe(true);
    expect((o.tooltip as Ding).trigger).toBe("axis");
    expect(vorlage.yAxis.splitNumber).toBe(5);
    expect("confine" in vorlage.tooltip).toBe(false);
  });

  it("gibt eine Option ohne Achsen und Legende unverändert im Inhalt zurück", () => {
    const o = fuerHandy({ series: [{ type: "line" }] } as EChartsCoreOption) as Ding;
    expect(o).toEqual({ series: [{ type: "line" }] });
  });
});
