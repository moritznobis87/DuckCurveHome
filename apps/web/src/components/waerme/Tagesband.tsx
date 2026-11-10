"use client";

import { useCallback, useMemo } from "react";
import type { EChartsCoreOption } from "echarts/core";
import { EChart } from "@/components/charts/EChart";
import { C, MONO } from "@/components/charts/palette";
import type { AnlageReplay } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { laeufe } from "./tagesuhr";

/**
 * Das Tagesband der Wiedergabe: der Tag als Zeile, zum Ablesen.
 *
 * Fünf Flächen untereinander auf einer Zeitachse, jede mit ihrer eigenen Größe und Einheit: Sonne
 * und Netz in Kilowatt, der Preis in Cent, dann drei Zeitleisten - was der Fahrplan für die
 * Wärmepumpe vorsah, was sie tat, und der Ofen. **Kein gemeinsames Gitter für verschiedene
 * Einheiten:** Kilowatt und Cent auf zwei Achsen desselben Bildes läsen sich als Zusammenhang
 * ihrer Kreuzungspunkte, und die sind Zufall der Skalierung.
 *
 * **Absicht und Ausführung stehen als Nachbarn**, dieselbe Farbe, die Absicht blass und flacher.
 * Dasselbe Ding in einem anderen Stand. Wo die blasse Zeile einen Balken hat und die kräftige
 * darunter keinen, wollte der Fahrplan und die Maschine nicht - das ist die Frage, was der
 * Freigabekontakt wirklich auslöst, als Bild.
 *
 * Die Tagesuhr daneben zeigt denselben Tag als Ring. Sie ist zum Zurechtfinden, dieses Band zum
 * Ablesen: hier stehen die Zahlen, und der Zeiger über dem Band nennt sie.
 */

const LINKS = 66;
const RECHTS = 12;

function uhrzeit(ms: number): string {
  return hhmm(new Date(ms));
}

/** Eine Farbe `#rrggbb` mit Deckung, als `rgba(...)`. */
function blass(hex: string, deckung: number): string {
  const n = Number.parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${deckung})`;
}

function de(x: number, n = 1): string {
  return x.toLocaleString("de-DE", { minimumFractionDigits: n, maximumFractionDigits: n });
}

export function Tagesband({ daten, zeitMs, onSprung }: { daten: AnlageReplay; zeitMs: number; onSprung: (i: number) => void }) {
  /** Alles außer dem Spielkopf. Teuer zu bauen, deshalb nur bei neuen Daten. */
  const basis = useMemo(() => {
    const f = daten.frames;
    if (f.length === 0) return null;
    const zeiten = f.map((x) => new Date(x.at).getTime());
    const paar = (werte: (number | null | undefined)[]) => werte.map((w, i) => [zeiten[i], w ?? null]);
    // Zusammenhängende Läufe, nicht ein Balken je Bild. Je Bild gezeichnet zeigte ein Block von
    // zwei Stunden vierundzwanzig feine Nähte, und ein Umriss um die Absicht wäre ein Gitter
    // geworden. Dieselbe Zusammenfassung wie in der Tagesuhr, also auch dieselben Lücken.
    const schritt = daten.step_min * 60_000;
    const balken = (an: (boolean | null | undefined)[]) =>
      laeufe(an, zeiten, schritt)
        .filter((l) => l.wert)
        .map((l) => [{ xAxis: l.von }, { xAxis: l.bis }]);
    const geplant = daten.geplant_wp ?? [];
    const hatOfen = f.some((x) => x.ofen.present);
    const hatAbsicht = geplant.some((g) => g != null);
    const hatPreis = (daten.preis_ct_kwh ?? []).some((p) => p != null);
    // Die Flächen von oben nach unten. Die Höhen sind fest: drei dünne Zeitleisten brauchen keine
    // Luft, die beiden Kurven schon.
    const flaechen = [
      { key: "kw", titel: "Sonne · Netz", top: 20, hoehe: 58 },
      { key: "preis", titel: "Preis", top: 100, hoehe: 30 },
      { key: "geplant", titel: "geplant", top: 146, hoehe: 8 },
      { key: "gelaufen", titel: "gelaufen", top: 159, hoehe: 13 },
      ...(hatOfen ? [{ key: "ofen", titel: "Ofen", top: 178, hoehe: 13 }] : []),
    ];
    const letzte = flaechen[flaechen.length - 1]!;
    return {
      zeiten,
      flaechen,
      hoehe: letzte.top + letzte.hoehe + 26,
      von: zeiten[0]!,
      bis: zeiten[zeiten.length - 1]!,
      sonne: paar(f.map((x) => x.strom.pv_kw)),
      netz: paar(f.map((x) => x.strom.grid_kw)),
      preis: paar(daten.preis_ct_kwh ?? []),
      geplant: balken(geplant),
      gelaufen: balken(f.map((x) => x.waermepumpe.running)),
      ofen: balken(f.map((x) => x.ofen.running)),
      hatOfen,
      hatAbsicht,
      hatPreis,
    };
  }, [daten]);

  const option = useMemo<EChartsCoreOption | null>(() => {
    if (!basis) return null;
    const { flaechen, von, bis } = basis;
    const index = (key: string) => flaechen.findIndex((x) => x.key === key);
    const achse = (gridIndex: number, zeigen: boolean) => ({
      type: "time" as const,
      gridIndex,
      min: von,
      max: bis,
      axisLine: { show: zeigen, lineStyle: { color: C.axis } },
      axisTick: { show: false },
      axisLabel: zeigen
        ? {
            color: C.text,
            fontFamily: MONO,
            fontSize: 10,
            hideOverlap: true,
            // Immer die Uhrzeit, und in der Zeit des Hauses. ECharts setzt an den Tagesgrenzen
            // sonst die Tageszahl, und zwischen "9" und "04:00" liest niemand eine Zeitachse; mit
            // seiner eigenen Formatierung stünde hier außerdem die Zeit des Geräts.
            formatter: (v: number) => uhrzeit(v),
          }
        : { show: false },
      splitLine: { show: false },
      axisPointer: { show: true },
    });
    const kurvenachse = (gridIndex: number) => ({
      gridIndex,
      splitNumber: 2,
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10 },
      splitLine: { lineStyle: { color: C.gridline } },
    });
    const leiste = (gridIndex: number) => ({ gridIndex, min: 0, max: 1, show: false });
    const spielkopf = {
      silent: true,
      symbol: ["none", "none"] as [string, string],
      lineStyle: { color: "#fff", width: 1.5, type: "solid" as const },
      label: { show: false },
      data: [{ xAxis: zeitMs }],
    };
    // Eine Zeitleiste ist eine leere Reihe mit Flächenmarken: je Lauf ein Rechteck über die ganze
    // Höhe der Zeile. `umriss` zeichnet die Absicht wie in der Tagesuhr - blass gefüllt, mit
    // Rand -, gefüllt heißt geschehen.
    const zeile = (key: string, name: string, data: unknown[], color: string, umriss = false) => ({
      name,
      type: "line" as const,
      xAxisIndex: index(key),
      yAxisIndex: index(key),
      data: [],
      markArea: {
        silent: true,
        // Der Umriss bekommt seine Blässe über die Füllfarbe, nicht über die Deckkraft der ganzen
        // Marke: sonst verblasste der Rand mit, und er ist das, was die Absicht kenntlich macht.
        itemStyle: umriss ? { color: blass(color, 0.2), borderColor: color, borderWidth: 1 } : { color },
        data,
      },
      // Der Spielkopf läuft durch jede Fläche, sonst endete er über den Zeitleisten.
      markLine: spielkopf,
    });
    return {
      animation: false,
      backgroundColor: "transparent",
      // Jede Fläche trägt ihren Namen links neben sich, in Textfarbe. Die Farbe gehört den
      // Marken; farbige Schrift wäre Kennung ohne Lesbarkeit.
      graphic: flaechen.map((x) => ({
        type: "text" as const,
        left: 0,
        top: x.top + Math.max(0, x.hoehe / 2 - 6),
        silent: true,
        style: {
          text:
            x.key === "kw" ? "kW" : x.key === "preis" ? "ct/kWh" : x.key === "geplant" && !basis.hatAbsicht ? "geplant ?" : x.titel,
          fill: C.text,
          font: `10px ${MONO}`,
        },
      })),
      axisPointer: { link: [{ xAxisIndex: "all" }], label: { show: false }, lineStyle: { color: "rgba(255,255,255,.3)" } },
      tooltip: {
        trigger: "axis" as const,
        confine: true,
        backgroundColor: C.deep,
        borderColor: "rgba(242,169,0,.4)",
        textStyle: { color: "#f1f5f5", fontSize: 12 },
        formatter: (params: unknown) => {
          const arr = Array.isArray(params) ? params : [params];
          const erste = arr[0] as { axisValue?: unknown } | undefined;
          const ms = Number(erste?.axisValue);
          if (!Number.isFinite(ms)) return "";
          // Das nächste Bild, nicht ein interpolierter Wert: zwischen zwei Bildern liegt nichts,
          // was gemessen wäre.
          let k = 0;
          let abstand = Infinity;
          basis.zeiten.forEach((z, i) => {
            const d = Math.abs(z - ms);
            if (d < abstand) {
              abstand = d;
              k = i;
            }
          });
          const b = daten.frames[k];
          if (!b) return "";
          const preis = daten.preis_ct_kwh?.[k];
          const absicht = daten.geplant_wp?.[k];
          const marke = (farbe: string) =>
            `<span style="display:inline-block;width:8px;height:8px;border-radius:2px;background:${farbe};margin-right:6px"></span>`;
          const zeilen = [
            `<div style="margin-bottom:4px"><b>${uhrzeit(basis.zeiten[k]!)}</b></div>`,
            `<div>${marke(C.pv)}Sonne ${b.strom.pv_kw == null ? "?" : `${de(b.strom.pv_kw)} kW`}</div>`,
            `<div>${marke(C.price)}Netz ${b.strom.grid_kw == null ? "?" : `${de(b.strom.grid_kw)} kW`}${preis == null ? "" : ` · ${de(preis, 1)} ct/kWh`}</div>`,
            `<div>${marke(C.heatPump)}Wärmepumpe ${b.waermepumpe.running ? `läuft${b.waermepumpe.power_kw == null ? "" : `, ${de(b.waermepumpe.power_kw)} kW`}` : "steht"}</div>`,
            `<div style="opacity:.78;padding-left:14px">${absicht == null ? "kein aufbewahrter Fahrplan" : absicht ? "der Fahrplan wollte anfordern" : "der Fahrplan wollte nicht anfordern"}</div>`,
          ];
          if (b.ofen.present) zeilen.push(`<div>${marke(C.stove)}Ofen ${b.ofen.running == null ? "?" : b.ofen.running ? "brennt" : "aus"}</div>`);
          return zeilen.join("");
        },
      },
      grid: flaechen.map((x) => ({ left: LINKS, right: RECHTS, top: x.top, height: x.hoehe })),
      xAxis: flaechen.map((_, k) => achse(k, k === flaechen.length - 1)),
      yAxis: flaechen.map((x, k) => (x.key === "kw" || x.key === "preis" ? kurvenachse(k) : leiste(k))),
      series: [
        {
          name: "Sonne",
          type: "line",
          smooth: true,
          showSymbol: false,
          connectNulls: false,
          data: basis.sonne,
          lineStyle: { color: C.pv, width: 2 },
          areaStyle: { color: C.pv, opacity: 0.16 },
          markLine: spielkopf,
        },
        {
          name: "Netz",
          type: "line",
          showSymbol: false,
          connectNulls: false,
          data: basis.netz,
          lineStyle: { color: C.price, width: 1.4 },
        },
        {
          name: "Preis",
          type: "line",
          step: "end" as const,
          showSymbol: false,
          connectNulls: false,
          xAxisIndex: index("preis"),
          yAxisIndex: index("preis"),
          data: basis.preis,
          lineStyle: { color: C.price, width: 1.4 },
          areaStyle: { color: C.price, opacity: 0.14 },
          markLine: spielkopf,
        },
        // Die Absicht blass, die Ausführung kräftig: dieselbe Farbe, zwei Stände. Wärmepumpe und
        // Ofen liegen farblich nah (ΔE 15,3 normal / 15,1 deutan, gemessen 09.11.2026), und der
        // Ofen hält gegen die Kartenfläche nur 2,99:1. Jede Zeitleiste hat deshalb ihre eigene
        // Zeile und ihren eigenen Namen - das ist die Entlastung, die beides zulässig macht.
        zeile("geplant", "geplant", basis.geplant, C.heatPump, true),
        zeile("gelaufen", "gelaufen", basis.gelaufen, C.heatPump),
        ...(basis.hatOfen ? [zeile("ofen", "Ofen", basis.ofen, C.stove)] : []),
      ],
    };
  }, [basis, daten, zeitMs]);

  const aufKlick = useCallback(
    (x: number) => {
      if (!basis) return;
      let beste = 0;
      let abstand = Infinity;
      basis.zeiten.forEach((z, i) => {
        const d = Math.abs(z - x);
        if (d < abstand) {
          abstand = d;
          beste = i;
        }
      });
      onSprung(beste);
    },
    [basis, onSprung],
  );

  if (!option || !basis) return null;
  return (
    <div className="wg-band" style={{ height: basis.hoehe }}>
      <EChart option={option} onKlick={aufKlick} />
    </div>
  );
}
