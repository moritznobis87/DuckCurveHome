"use client";

import { useMemo } from "react";
import type { EChartsCoreOption } from "echarts/core";
import { EChart } from "@/components/charts/EChart";
import { C, MONO } from "@/components/charts/palette";
import type { Nachbetrachtung } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { useIsMobile } from "@/lib/useIsMobile";
import { euro, staerke, zeilen, type Linie } from "./nachbetrachtung";
import { laeufe } from "./tagesuhr";

/**
 * Der Tagesvergleich: wann jede Linie Strom zog, und wo dabei das Geld auseinanderlief.
 *
 * Drei Teile auf einer Zeitachse. **Oben die Umstände:** der eingetretene Preis und der
 * Überschuss. **In der Mitte je Linie ein Streifen:** hell, wo sie Strom zieht, heller, je mehr.
 * Die Streifen stehen untereinander, damit der Blick senkrecht vergleichen kann - geplant war der
 * Mittag, gelaufen ist der Morgen, und das sieht man, bevor man eine Zahl liest. **Unten die
 * aufgelaufenen Kosten:** dieselben Linien als Kurven. Wo zwei Kurven sich trennen, ist die
 * Viertelstunde, in der es teuer wurde, und der Streifen darüber sagt, warum.
 *
 * **Jede Größe in ihrer eigenen Fläche.** Cent, Kilowatt und Euro in einem Gitter läsen sich als
 * Zusammenhang ihrer Kreuzungspunkte.
 *
 * **Die Farben** sind die der Kostentreppe: Fahrplan kühl, Wirklichkeit warm, der Vergleichslauf
 * hell. Gemessen am 10.11.2026 gegen die Kartenfläche #123544, alle Paare: schlechtestes Paar
 * ΔE 15,8 normal und 10,3 protan. Ein Grün für die perfekte Voraussicht fiel durch - gegen das
 * Orange der Wirklichkeit ΔE 0,8 bei Deuteranopie, also dieselbe Farbe. Deshalb drei Farben für
 * vier Linien: der erste Fahrplan gestrichelt, der letzte Stand durchgezogen, und jede Kurve hat
 * ihren Namen am Ende.
 */

/** Ränder: links die Namen der Streifen, rechts die Namen am Ende der Kurven. */
const RAND = { breit: { links: 136, rechts: 128 }, schmal: { links: 84, rechts: 12 } } as const;
const STREIFEN = 13;
const DECKUNG = [0.28, 0.5, 0.75, 1] as const;

export const KURZ: Record<string, string> = {
  erster: "erster Fahrplan",
  letzter: "letzter Stand",
  wirklich: "wirklich",
  perfekt: "perfekte Voraussicht",
};
/** Auf dem Telefon ist die Spalte der Namen schmaler; dort stehen sie kürzer. */
const KNAPP: Record<string, string> = { erster: "erster Plan", letzter: "letzter Stand", wirklich: "wirklich", perfekt: "perfekt" };

/** Farbe und Strichart einer Linie. Dieselbe Zuordnung wie in der Kostentreppe. */
export function strich(key: string): { color: string; type: "solid" | "dashed"; width: number } {
  if (key === "wirklich") return { color: C.heatPump, type: "solid", width: 2.5 };
  if (key === "letzter") return { color: C.mist, type: "solid", width: 2 };
  if (key === "erster") return { color: C.mist, type: "dashed", width: 1.6 };
  return { color: C.house, type: "solid", width: 1.6 };
}

function blass(hex: string, d: number): string {
  const n = Number.parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${d})`;
}

function de(x: number, n = 1): string {
  return x.toLocaleString("de-DE", { minimumFractionDigits: n, maximumFractionDigits: n });
}

type Flaeche = { key: string; titel: string; top: number; hoehe: number; linie?: Linie };

export function Tagesvergleich({ d }: { d: Nachbetrachtung }) {
  // Auf dem Telefon ist rechts kein Platz für die Namen an den Kurven: von 310 Punkten blieben
  // der Zeichnung 80. Dort trägt die Legende unter dem Bild, die ohnehin immer dasteht.
  const schmal = useIsMobile();
  const rand = schmal ? RAND.schmal : RAND.breit;
  const basis = useMemo(() => {
    const zeiten = (d.zeiten ?? []).map((z) => new Date(z).getTime());
    if (zeiten.length === 0) return null;
    const schritt = d.schritt_min * 60_000;
    const linien = zeilen(d);
    const hatSonne = (d.ueberschuss_kw ?? []).some((u) => (u ?? 0) > 0.05);
    const flaechen: Flaeche[] = [];
    let top = 26;
    flaechen.push({ key: "preis", titel: "Preis in ct/kWh", top, hoehe: 56 });
    top += 56 + 34;
    if (hatSonne) {
      flaechen.push({ key: "sonne", titel: "Überschuss in kW", top, hoehe: 40 });
      top += 40 + 34;
    }
    const streifenAb = top;
    for (const l of linien) {
      flaechen.push({ key: `s:${l.key}`, titel: (schmal ? KNAPP[l.key] : KURZ[l.key]) ?? l.name_de, top, hoehe: STREIFEN, linie: l });
      top += STREIFEN + 7;
    }
    top += 30;
    flaechen.push({ key: "kosten", titel: "aufgelaufene Kosten in €", top, hoehe: 170 });
    return { zeiten, schritt, linien, flaechen, streifenAb, hoehe: top + 170 + 34, von: new Date(d.von).getTime(), bis: new Date(d.bis).getTime() };
  }, [d, schmal]);

  const option = useMemo<EChartsCoreOption | null>(() => {
    if (!basis) return null;
    const { zeiten, schritt, flaechen, linien, von, bis } = basis;
    const index = (key: string) => flaechen.findIndex((f) => f.key === key);
    const paar = (werte: readonly (number | null | undefined)[]) => zeiten.map((z, i) => [z, werte[i] ?? null]);
    // Was nicht verglichen wird, liegt unter einem Schleier - in jeder Fläche derselbe.
    const aussen = laeufe(
      (d.verglichen ?? []).map((v) => !v),
      zeiten,
      schritt,
    )
      .filter((l) => l.wert)
      .map((l) => [{ xAxis: l.von }, { xAxis: l.bis }]);
    const schleier = (mitText: boolean) => ({
      silent: true,
      itemStyle: { color: "rgba(8,36,49,.62)" },
      label: mitText
        ? { show: true, position: "insideTopLeft" as const, color: C.text, fontFamily: MONO, fontSize: 10, formatter: "nicht verglichen" }
        : { show: false },
      data: aussen,
    });
    const xAchse = (gridIndex: number, zeigen: boolean) => ({
      type: "time" as const,
      gridIndex,
      min: von,
      max: bis,
      axisLine: { show: zeigen, lineStyle: { color: C.axis } },
      axisTick: { show: false },
      axisLabel: zeigen ? { color: C.text, fontFamily: MONO, fontSize: 10, hideOverlap: true, formatter: (v: number) => hhmm(new Date(v)) } : { show: false },
      splitLine: { show: false },
      axisPointer: { show: true },
    });
    const kurvenachse = (gridIndex: number, formatter?: string) => ({
      gridIndex,
      splitNumber: 2,
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, formatter },
      splitLine: { lineStyle: { color: C.gridline } },
    });
    const leiste = (gridIndex: number) => ({ gridIndex, min: 0, max: 1, show: false });

    const streifen = linien.flatMap((l) => {
      const k = index(`s:${l.key}`);
      const voll = d.wp_kw * (d.schritt_min / 60);
      const stufen = (l.wp_kwh_je ?? []).map((w) => staerke(w, voll));
      const gruppen = laeufe(stufen, zeiten, schritt);
      const flaeche = (stufe: number, color: string) => ({
        name: `${l.key}-${stufe}`,
        type: "line" as const,
        xAxisIndex: k,
        yAxisIndex: k,
        data: [],
        tooltip: { show: false },
        markArea: {
          silent: true,
          itemStyle: { color },
          data: gruppen.filter((g) => g.wert === stufe).map((g) => [{ xAxis: g.von }, { xAxis: g.bis }]),
        },
      });
      return [
        // Stufe null ist eine Aussage: die Linie sagt „aus". Sie bekommt einen schwachen Grund,
        // damit sie sich von „sagt nichts" unterscheidet, das leer bleibt.
        flaeche(0, "rgba(255,255,255,.07)"),
        ...DECKUNG.map((deckung, n) => flaeche(n + 1, blass(C.heatPump, deckung))),
        // Der Ofen als schmaler Rand unter dem Streifen, nur wo es einen gibt.
        ...(d.hat_ofen
          ? [
              {
                name: `${l.key}-ofen`,
                type: "line" as const,
                xAxisIndex: k,
                yAxisIndex: k,
                data: [],
                tooltip: { show: false },
                markArea: {
                  silent: true,
                  itemStyle: { color: C.stove },
                  data: laeufe(
                    (l.ofen_je ?? []).map((o) => (o == null ? null : o > 0.5)),
                    zeiten,
                    schritt,
                  )
                    .filter((g) => g.wert)
                    .map((g) => [
                      { xAxis: g.von, yAxis: 0 },
                      { xAxis: g.bis, yAxis: 0.28 },
                    ]),
                },
              },
            ]
          : []),
        { name: `${l.key}-schleier`, type: "line" as const, xAxisIndex: k, yAxisIndex: k, data: [], tooltip: { show: false }, markArea: schleier(false) },
      ];
    });

    const kosten = linien.map((l) => {
      const s = strich(l.key);
      return {
        name: KURZ[l.key] ?? l.name_de,
        type: "line" as const,
        showSymbol: false,
        connectNulls: false,
        xAxisIndex: index("kosten"),
        yAxisIndex: index("kosten"),
        data: paar(l.eur_kumuliert ?? []),
        itemStyle: { color: s.color },
        lineStyle: s,
        z: l.key === "wirklich" ? 5 : 3,
        // Der Name am Ende der Kurve: mit drei Farben für fünf Linien trägt die Farbe allein
        // nicht, und eine Legende müsste man erst den Kurven zuordnen.
        endLabel: { show: !schmal, formatter: "{a}", color: "rgba(255,255,255,.72)", fontSize: 11, distance: 6 },
        labelLayout: { moveOverlap: "shiftY" as const },
      };
    });

    return {
      animation: false,
      backgroundColor: "transparent",
      graphic: flaechen.map((f) => ({
        type: "text" as const,
        left: 0,
        top: f.linie ? f.top + 1 : f.top - 20,
        silent: true,
        style: { text: f.titel, fill: C.text, font: `10px ${MONO}` },
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
          const ms = Number((arr[0] as { axisValue?: unknown } | undefined)?.axisValue);
          if (!Number.isFinite(ms)) return "";
          // Die Viertelstunde, in der der Zeiger steht, nicht die nächstgelegene Marke.
          const i = Math.min(zeiten.length - 1, Math.max(0, Math.floor((ms - von) / schritt)));
          const marke = (key: string) => {
            const s = strich(key);
            return `<span style="display:inline-block;width:12px;height:0;border-top:2px ${s.type} ${s.color};margin:0 6px 3px 0"></span>`;
          };
          const preis = d.preis_ct?.[i];
          const sonne = d.ueberschuss_kw?.[i];
          const kopf = `${hhmm(new Date(zeiten[i]!))} bis ${hhmm(new Date(zeiten[i]! + schritt))}`;
          const out = [
            `<div style="margin-bottom:4px"><b>${kopf}</b></div>`,
            `<div style="opacity:.78">${preis == null ? "Preis unbekannt" : `${de(preis)} ct/kWh`}${sonne == null ? "" : ` · Überschuss ${de(sonne)} kW`}</div>`,
          ];
          if (!d.verglichen?.[i]) out.push(`<div style="opacity:.78">Diese Viertelstunde wird nicht verglichen.</div>`);
          out.push(`<table style="margin-top:6px;border-spacing:0 2px;font-variant-numeric:tabular-nums">`);
          for (const l of linien) {
            const kwh = l.wp_kwh_je?.[i];
            const eur = l.eur_je?.[i];
            const summe = l.eur_kumuliert?.[i];
            out.push(
              `<tr><td>${marke(l.key)}${KURZ[l.key] ?? l.name_de}</td>` +
                `<td style="text-align:right;padding-left:14px">${kwh == null ? "-" : `${de(kwh, 2)} kWh`}</td>` +
                `<td style="text-align:right;padding-left:14px">${euro(eur)}</td>` +
                `<td style="text-align:right;padding-left:14px;opacity:.7">bis hier ${euro(summe)}</td></tr>`,
            );
          }
          out.push(`</table>`);
          return out.join("");
        },
      },
      // `outerBoundsMode: "none"`: sonst rückt ECharts 6 ein Gitter ein, sobald eine Beschriftung
      // übersteht, und die Flächen stünden nicht mehr untereinander.
      grid: flaechen.map((f) => ({ left: rand.links, right: rand.rechts, top: f.top, height: f.hoehe, outerBoundsMode: "none" as const })),
      xAxis: flaechen.map((_, k) => xAchse(k, k === flaechen.length - 1)),
      yAxis: flaechen.map((f, k) => (f.linie ? leiste(k) : kurvenachse(k, f.key === "kosten" ? "{value} €" : undefined))),
      series: [
        {
          name: "Preis",
          type: "line" as const,
          step: "end" as const,
          showSymbol: false,
          connectNulls: false,
          data: paar(d.preis_ct ?? []),
          itemStyle: { color: C.price },
          lineStyle: { color: C.price, width: 1.6 },
          areaStyle: { color: C.price, opacity: 0.14 },
          markArea: schleier(true),
        },
        ...(index("sonne") >= 0
          ? [
              {
                name: "Überschuss",
                type: "line" as const,
                showSymbol: false,
                connectNulls: false,
                xAxisIndex: index("sonne"),
                yAxisIndex: index("sonne"),
                data: paar(d.ueberschuss_kw ?? []),
                itemStyle: { color: C.pv },
                lineStyle: { color: C.pv, width: 1.6 },
                areaStyle: { color: C.pv, opacity: 0.18 },
                markArea: schleier(false),
              },
            ]
          : []),
        ...streifen,
        ...kosten.map((k, n) => (n === 0 ? { ...k, markArea: schleier(false) } : k)),
      ],
    };
  }, [basis, d, schmal, rand]);

  if (!option || !basis) return null;
  return (
    <div style={{ height: basis.hoehe }}>
      <EChart option={option} />
    </div>
  );
}
