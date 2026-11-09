"use client";

import { useEffect, useRef } from "react";
import * as echarts from "echarts/core";
import { BarChart, HeatmapChart, LineChart, PieChart, ScatterChart } from "echarts/charts";
import { GridComponent, GraphicComponent, LegendComponent, MarkAreaComponent, MarkLineComponent, TitleComponent, TooltipComponent, AxisPointerComponent, VisualMapComponent, DataZoomComponent, ToolboxComponent } from "echarts/components";
import { CanvasRenderer } from "echarts/renderers";
import type { EChartsCoreOption } from "echarts/core";

// Nur registrierte Bausteine zeichnen. Fehlt einer, bleibt die Reihe stillschweigend weg - das Gerüst
// erscheint, die Daten nicht. HeatmapChart und VisualMapComponent tragen die Jahreskarte,
// DataZoomComponent und ToolboxComponent das Zeitfenster der Prüfansicht, TitleComponent die
// Beschriftung der einzelnen Flächen eines gestapelten Diagramms.
echarts.use([LineChart, BarChart, ScatterChart, PieChart, HeatmapChart, GraphicComponent, LegendComponent, GridComponent, MarkAreaComponent, MarkLineComponent, TitleComponent, TooltipComponent, AxisPointerComponent, VisualMapComponent, DataZoomComponent, ToolboxComponent, CanvasRenderer]);

/** Der eine Chart-Baustein: Thema an einer Stelle, setOption auf lebender Instanz (Live-Daten), Resize, Dispose.
 *
 *  `onZeitKlick` bekommt den x-Wert der angeklickten Stelle, umgerechnet aus Bildschirmpunkten in
 *  Datenkoordinaten des ersten Gitters. Gebraucht für den Spielkopf der Wiedergabe: dort ist das
 *  Tagesband selbst der Schieber, und ein Klick springt zu dieser Uhrzeit. Bewusst der Rohklick auf
 *  der Zeichenfläche und nicht `click` auf einer Reihe - getroffen werden soll der Zeitpunkt, nicht
 *  der Balken, und zwischen zwei Balken liegt bei 288 Bildern mehr Luft als Fläche.
 */
export function EChart({
  option,
  className,
  onZeitKlick,
}: {
  option: EChartsCoreOption;
  className?: string;
  onZeitKlick?: (x: number) => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const chart = useRef<echarts.ECharts | null>(null);
  // In einer Referenz und nicht im Effekt-Abhängigkeitsfeld: sonst würde der Chart bei jedem
  // Neuzeichnen der Elternkomponente verworfen und neu angelegt, und die Wiedergabe flackerte.
  const klick = useRef(onZeitKlick);
  klick.current = onZeitKlick;

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    // useDirtyRect zeichnet nur veränderte Rechtecke neu. Das spart Rechenzeit, hinterlässt aber
    // beim Überfahren leere Flächen, sobald sich Tooltip, Achsenzeiger und Hervorhebung
    // überlagern - die Optimierung schätzt die betroffene Fläche dann zu klein. Vollbild neu
    // zeichnen ist bei unseren Diagrammgrößen ohnehin nicht spürbar.
    const c = echarts.init(el, undefined, { renderer: "canvas" });
    chart.current = c;
    const ro = new ResizeObserver(() => c.resize());
    ro.observe(el);
    const aufKlick = (e: { offsetX: number; offsetY: number }) => {
      if (!klick.current) return;
      const p = c.convertFromPixel({ gridIndex: 0 }, [e.offsetX, e.offsetY]);
      // Außerhalb des Gitters gibt ECharts NaN zurück; ein Klick auf den Rand ist kein Sprung.
      if (Array.isArray(p) && Number.isFinite(p[0])) klick.current(Number(p[0]));
    };
    c.getZr().on("click", aufKlick);
    return () => {
      ro.disconnect();
      c.getZr().off("click", aufKlick);
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
