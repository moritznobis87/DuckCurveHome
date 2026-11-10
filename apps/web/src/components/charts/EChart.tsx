"use client";

import { useEffect, useRef } from "react";
import * as echarts from "echarts/core";
import { BarChart, HeatmapChart, LineChart, ScatterChart } from "echarts/charts";
import { GridComponent, GraphicComponent, LegendComponent, MarkAreaComponent, MarkLineComponent, TitleComponent, TooltipComponent, AxisPointerComponent, VisualMapComponent, DataZoomComponent, ToolboxComponent } from "echarts/components";
import { LabelLayout } from "echarts/features";
import { CanvasRenderer } from "echarts/renderers";
import type { EChartsCoreOption } from "echarts/core";

// Nur registrierte Bausteine zeichnen. Fehlt einer, bleibt die Reihe stillschweigend weg - das Gerüst
// erscheint, die Daten nicht. HeatmapChart und VisualMapComponent tragen die Jahreskarte,
// DataZoomComponent und ToolboxComponent das Zeitfenster der Prüfansicht, TitleComponent die
// Beschriftung der einzelnen Flächen eines gestapelten Diagramms, LabelLayout die Namen am Ende
// der Kurven in der Nachbetrachtung: ohne es lägen zwei Namen übereinander, wo zwei Kurven
// auf demselben Betrag enden.
echarts.use([LineChart, BarChart, ScatterChart, HeatmapChart, GraphicComponent, LegendComponent, GridComponent, MarkAreaComponent, MarkLineComponent, TitleComponent, TooltipComponent, AxisPointerComponent, VisualMapComponent, DataZoomComponent, ToolboxComponent, LabelLayout, CanvasRenderer]);

/** Der eine Chart-Baustein: Thema an einer Stelle, setOption auf lebender Instanz (Live-Daten), Resize, Dispose.
 *
 *  `onKlick` bekommt die angeklickte Stelle, umgerechnet aus Bildschirmpunkten in die
 *  Datenkoordinaten des ersten Gitters: auf einer Zeitachse die Zeit, auf einer Kategorienachse
 *  die Nummer der Kategorie. Zwei Stellen brauchen das. Im Tagesband der Wiedergabe ist das Band
 *  selbst der Schieber, und ein Klick springt zu dieser Uhrzeit. In der Jahreskarte ist ein Feld
 *  ein Tag und eine Stunde, und ein Klick öffnet die Wiedergabe genau dort. Bewusst der Rohklick
 *  auf der Zeichenfläche und nicht `click` auf einer Reihe - getroffen werden soll die Stelle,
 *  nicht die Marke, und ein Feld ohne Wert hat gar keine Marke, die man treffen könnte.
 */
export function EChart({
  option,
  className,
  onKlick,
}: {
  option: EChartsCoreOption;
  className?: string;
  onKlick?: (x: number, y: number) => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const chart = useRef<echarts.ECharts | null>(null);
  // In einer Referenz und nicht im Effekt-Abhängigkeitsfeld: sonst würde der Chart bei jedem
  // Neuzeichnen der Elternkomponente verworfen und neu angelegt, und die Wiedergabe flackerte.
  const klick = useRef(onKlick);
  klick.current = onKlick;

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
      if (Array.isArray(p) && Number.isFinite(p[0])) klick.current(Number(p[0]), Number(p[1]));
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
