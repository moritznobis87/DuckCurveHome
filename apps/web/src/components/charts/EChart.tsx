"use client";

import { useEffect, useRef } from "react";
import * as echarts from "echarts/core";
import { BarChart, HeatmapChart, LineChart, PieChart, ScatterChart } from "echarts/charts";
import { GridComponent, GraphicComponent, LegendComponent, MarkAreaComponent, MarkLineComponent, TooltipComponent, AxisPointerComponent, VisualMapComponent } from "echarts/components";
import { CanvasRenderer } from "echarts/renderers";
import type { EChartsCoreOption } from "echarts/core";

// Nur registrierte Bausteine zeichnen. Fehlt einer, bleibt die Reihe stillschweigend weg — das Gerüst
// erscheint, die Daten nicht. HeatmapChart und VisualMapComponent tragen die Jahreskarte.
echarts.use([LineChart, BarChart, ScatterChart, PieChart, HeatmapChart, GraphicComponent, LegendComponent, GridComponent, MarkAreaComponent, MarkLineComponent, TooltipComponent, AxisPointerComponent, VisualMapComponent, CanvasRenderer]);

/** Der eine Chart-Baustein: Thema an einer Stelle, setOption auf lebender Instanz (Live-Daten), Resize, Dispose. */
export function EChart({ option, className }: { option: EChartsCoreOption; className?: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const chart = useRef<echarts.ECharts | null>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const c = echarts.init(el, undefined, { renderer: "canvas", useDirtyRect: true });
    chart.current = c;
    const ro = new ResizeObserver(() => c.resize());
    ro.observe(el);
    return () => {
      ro.disconnect();
      c.dispose();
      chart.current = null;
    };
  }, []);

  useEffect(() => {
    // visualMap muss ersetzt statt gemischt werden: beim Wechsel von einer divergierenden auf eine
    // sequenzielle Kennzahl bliebe sonst die Beschriftung der alten Pole stehen.
    chart.current?.setOption(option, { replaceMerge: ["series", "grid", "xAxis", "yAxis", "visualMap"], lazyUpdate: true });
  }, [option]);

  return <div ref={ref} className={className} style={{ width: "100%", height: "100%" }} />;
}
