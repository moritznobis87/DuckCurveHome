"use client";

import { useEffect, useState } from "react";
import type { EChartsCoreOption } from "echarts/core";
import { api, ApiError } from "@/lib/api/client";
import type { ForecastHistory, ForecastHistoryReihe } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { EChart } from "@/components/charts/EChart";
import { C, MONO } from "@/components/charts/palette";

/**
 * Was die abgelegten Prognosen wert waren, nach Abstand zur Lieferung.
 *
 * Bis hierher war `forecast_runs` eine Tabelle, in die geschrieben und aus der nie gelesen wurde.
 * Diese Ansicht beantwortet die eine Frage, für die alle Läufe dreißig Tage bleiben: **wird die
 * Prognose besser, je näher die Lieferung kommt?** Jeder Lauf wird einzeln gegen die Messung
 * gehalten, und das Ergebnis steht nach Vorlaufklassen sortiert da.
 *
 * Zwei Zahlen je Klasse, und beide sind nötig. Der mittlere Fehler sagt, wie es im Schnitt lief;
 * der Rand sagt, womit der Fahrplan im schlechtesten Fall rechnen muss. Für eine harte
 * Komfortgrenze zählt der Rand, nicht die Mitte.
 */

const REFRESH_MS = 10 * 60_000;

const de = (n: number | null | undefined, digits = 2): string =>
  n == null ? "-" : n.toFixed(digits).replace(".", ",");

/**
 * Mittlerer Fehler als Balken, der Rand als Punkt darüber.
 *
 * Farben geprüft mit dem Palettenprüfer der dataviz-Anleitung gegen die Kartenfläche #123544,
 * Modus dunkel: ΔE 23,4 normal und 15,1 deutan zwischen den beiden. Sie stehen im selben Gitter,
 * also ist dieser Abstand der maßgebliche. Die Form trennt sie zusätzlich - Fläche gegen Punkt.
 */
function option(reihe: ForecastHistoryReihe): EChartsCoreOption {
  const labels = reihe.je_vorlauf.map((v) => v.key);
  const mae = reihe.je_vorlauf.map((v) => (v.wertung.n > 0 ? v.wertung.mae : null));
  const p95 = reihe.je_vorlauf.map((v) => (v.wertung.n > 0 ? v.wertung.p95 : null));
  const n = reihe.je_vorlauf.map((v) => v.wertung.n);
  const leer = reihe.je_vorlauf.every((v) => v.wertung.n === 0);
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    tooltip: {
      trigger: "axis",
      confine: true,
      backgroundColor: C.deep,
      borderColor: "rgba(255,255,255,.14)",
      borderRadius: 3,
      textStyle: { color: "rgba(255,255,255,.92)", fontFamily: MONO, fontSize: 12 },
      formatter: (params: unknown) => {
        const ps = params as Array<{ dataIndex: number; seriesName: string; value: number | null; color: string }>;
        if (!ps.length) return "";
        const i = ps[0]!.dataIndex;
        const rows = ps
          .filter((p) => p.value != null)
          .map(
            (p) =>
              `<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:${p.color}">${p.seriesName}</span><span>${de(p.value)} ${reihe.einheit}</span></div>`,
          )
          .join("");
        // Die Zahl der Paare gehört dazu: eine Sprosse aus drei Proben ist keine Aussage.
        return `<div style="letter-spacing:.06em;color:rgba(255,255,255,.6);margin-bottom:4px">${reihe.je_vorlauf[i]?.label_de ?? ""} · ${n[i]} Paare</div>${rows}`;
      },
    },
    grid: { left: 44, right: 14, top: 18, bottom: 28 },
    xAxis: {
      type: "category",
      data: labels,
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10 },
    },
    yAxis: {
      type: "value",
      min: 0,
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10 },
      splitLine: { lineStyle: { color: C.gridline } },
    },
    series: [
      {
        name: "mittlerer Fehler",
        type: "bar",
        data: mae,
        barWidth: "52%",
        itemStyle: { color: C.price, borderRadius: [2, 2, 0, 0] },
      },
      {
        name: "Rand (95 %)",
        type: "line",
        data: p95,
        symbol: "circle",
        symbolSize: 7,
        lineStyle: { color: C.alert, width: 1, type: "dashed" },
        itemStyle: { color: C.alert },
      },
    ],
    ...(leer
      ? {
          graphic: {
            type: "text",
            left: "center",
            top: "middle",
            style: {
              text: "keine Paare im Zeitraum",
              fill: C.text,
              fontFamily: MONO,
              fontSize: 11,
            },
          },
        }
      : {}),
  };
}

function Legend({ color, label, punkt = false }: { color: string; label: string; punkt?: boolean }) {
  return (
    <span className="flex items-center gap-2 text-[12px] text-text-2">
      <span
        className={`inline-block ${punkt ? "h-2 w-2 rounded-full" : "h-3 w-3 rounded-[2px]"}`}
        style={{ background: color }}
      />
      {label}
    </span>
  );
}

export function Rueckblick() {
  const [data, setData] = useState<ForecastHistory | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [tage, setTage] = useState(7);

  useEffect(() => {
    let lebt = true;
    const laden = async () => {
      try {
        const out = await api.forecastHistory(tage);
        if (lebt) {
          setData(out);
          setFehler(null);
        }
      } catch (e) {
        if (lebt) setFehler(e instanceof ApiError ? e.message : "Rückblick nicht verfügbar.");
      }
    };
    void laden();
    const t = setInterval(laden, REFRESH_MS);
    return () => {
      lebt = false;
      clearInterval(t);
    };
  }, [tage]);

  const reihen = data?.reihen ?? [];

  return (
    <>
      <div className="flex items-baseline justify-between gap-4">
        <h2 className="kicker m-0">Rückblick · abgelegte Läufe gegen das Ist</h2>
        <div className="flex items-center gap-3">
          <div className="flex gap-4">
            <Legend color={C.price} label="mittlerer Fehler" />
            <Legend color={C.alert} label="Rand (95 %)" punkt />
          </div>
          <div className="flex gap-1">
            {[3, 7, 14, 30].map((d) => (
              <button
                key={d}
                type="button"
                onClick={() => setTage(d)}
                className={`mono rounded-[3px] border px-2 py-[3px] text-[11px] ${d === tage ? "border-line-1 text-text-1" : "border-line-2 text-text-3"}`}
              >
                {d} d
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="grid gap-4" style={{ gridTemplateColumns: `repeat(${Math.max(1, reihen.length)}, 1fr)` }}>
        {reihen.map((r) => (
          <Card key={r.key} style={{ padding: 16, height: 250 }}>
            <CardHead
              title={`${r.label_de} · ${r.einheit}`}
              right={
                r.gesamt.n > 0
                  ? `${r.gesamt.n} Paare · Bias ${r.gesamt.bias > 0 ? "+" : ""}${de(r.gesamt.bias)} ${r.einheit}`
                  : `${r.laeufe} Läufe, keine Paare`
              }
            />
            <div className="mt-1 min-h-0 flex-1">
              <EChart key={`${r.key}-${tage}`} option={option(r)} />
            </div>
          </Card>
        ))}
      </div>

      <Card accent style={{ padding: 18 }}>
        <CardHead
          title="Wie der Rückblick zu lesen ist"
          right={data ? `${tage} Tage · ${reihen[0]?.laeufe ?? 0} Läufe im Bestand` : undefined}
        />
        {fehler ? <p className="mt-3 text-[13px] text-text-2">{fehler}</p> : null}
        <div className="mt-3 flex flex-col gap-1">
          {(data?.hinweise_de ?? []).map((h, i) => (
            <span key={i} className="text-[12px] leading-[1.55] text-text-3">
              {h}
            </span>
          ))}
        </div>
      </Card>
    </>
  );
}
