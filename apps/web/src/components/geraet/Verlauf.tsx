"use client";

import { Systemkarte } from "@/components/ui/Systemkarte";
import { ABSCHNITTSZEICHEN } from "./abschnitte";
import { useEffect, useState } from "react";
import type { EChartsCoreOption } from "echarts/core";
import { EChart } from "@/components/charts/EChart";
import { C, MONO } from "@/components/charts/palette";
import type { components } from "@/lib/api/types";
import { DIENSTNAMEN } from "./namen";

/**
 * Der Verlauf des Hausgeräts (routers/geraet.py → /system/geraet/verlauf): ein kleines Diagramm je
 * Größe, nicht ein großes mit allem.
 *
 * **Eine Größe je Diagramm.** Temperatur, Prozent, Gigabyte und Kilobyte pro Sekunde auf einer
 * Fläche hieße mehrere y-Achsen, und auf zwei Achsen liest man Zusammenhänge, die es nicht gibt.
 * Zwei Reihen teilen sich ein Diagramm nur, wenn sie dieselbe Einheit haben (CPU- und
 * SSD-Temperatur, empfangen und gesendet); sie haben dann eine Legende und ein Namensschild am
 * Ende der Linie.
 *
 * **Farben.** Bernstein und Blau aus der Palette der App, mit dem Palettenprüfer gegen die
 * Kartenfläche geprüft (ΔE 32,5 normal, 25,5 bei Farbschwäche). Die Dienste stehen je in einem
 * eigenen kleinen Diagramm: Fünf unterscheidbare Farben gibt die Palette nicht her, zwei der
 * warmen Töne lagen bei ΔE 6.
 */

type Verlauf = components["schemas"]["GeraetVerlaufOut"];
type Punkt = components["schemas"]["GeraetVerlaufPunktOut"];
export type Spanne = "tag" | "woche" | "monat" | "jahr";

const SPANNEN: { wert: Spanne; wort: string }[] = [
  { wert: "tag", wort: "Tag" },
  { wert: "woche", wort: "Woche" },
  { wert: "monat", wort: "Monat" },
  { wert: "jahr", wort: "Jahr" },
];

const ZAHL = (v: number, stellen = 1) => v.toLocaleString("de-DE", { maximumFractionDigits: stellen });

export function bytesText(b: number | null | undefined): string {
  if (b == null) return "–";
  const a = Math.abs(b);
  if (a >= 1e12) return `${ZAHL(b / 1e12, 2)} TB`;
  if (a >= 1e9) return `${ZAHL(b / 1e9, 1)} GB`;
  if (a >= 1e6) return `${ZAHL(b / 1e6, 1)} MB`;
  return `${ZAHL(b / 1e3, 0)} kB`;
}

/** „in etwa 380 Tagen“, „in etwa 3 Jahren“ - eine Schätzung, kein Termin. */
export function dauerText(tage: number): string {
  if (tage >= 730) return `in etwa ${Math.round(tage / 365)} Jahren`;
  if (tage >= 60) return `in etwa ${Math.round(tage / 30)} Monaten`;
  return `in etwa ${tage} Tagen`;
}

type Reihe = { name: string; farbe: string; werte: (number | null)[] };

/** Fehlt ein Abschnitt (Gerät aus), soll die Linie dort reißen statt die Lücke zu überbrücken. */
export function mitLuecken(t: string[], schrittMin: number, reihen: Reihe[]): { t: string[]; reihen: Reihe[] } {
  const zeiten: string[] = [];
  const neu = reihen.map((r) => ({ ...r, werte: [] as (number | null)[] }));
  t.forEach((iso, i) => {
    if (i > 0) {
      const abstand = (new Date(iso).getTime() - new Date(t[i - 1]!).getTime()) / 60_000;
      if (abstand > schrittMin * 1.5) {
        zeiten.push(new Date(new Date(t[i - 1]!).getTime() + schrittMin * 60_000).toISOString());
        neu.forEach((r) => r.werte.push(null));
      }
    }
    zeiten.push(iso);
    neu.forEach((r, j) => r.werte.push(reihen[j]!.werte[i] ?? null));
  });
  return { t: zeiten, reihen: neu };
}

function zeitachse(spanne: Spanne): (wert: number) => string {
  return (wert: number) => {
    const d = new Date(wert);
    if (spanne === "tag") return d.toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });
    if (spanne === "woche") return d.toLocaleDateString("de-DE", { weekday: "short" });
    return d.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" });
  };
}

function option(
  spanne: Spanne,
  schrittMin: number,
  zeiten: string[],
  roh: Reihe[],
  einheit: string,
  stellen: number,
  {
    min,
    max,
    grenze,
    balken,
    intervall,
  }: { min?: number; max?: number; grenze?: { wert: number; wort: string }; balken?: boolean; intervall?: number } = {},
): EChartsCoreOption {
  const { t, reihen } = mitLuecken(zeiten, schrittMin, roh);
  const mehrere = reihen.length > 1;
  return {
    animation: false,
    backgroundColor: "transparent",
    textStyle: { fontFamily: MONO },
    grid: { left: 40, right: mehrere ? 80 : 12, top: 10, bottom: 22 },
    tooltip: {
      trigger: "axis",
      confine: true,
      backgroundColor: C.deep,
      borderColor: "rgba(255,255,255,.14)",
      borderRadius: 3,
      textStyle: { color: "rgba(255,255,255,.92)", fontFamily: MONO, fontSize: 12 },
      axisPointer: { type: "line", lineStyle: { color: "rgba(255,255,255,.3)" } },
      formatter: (params: unknown) => {
        const ps = params as Array<{ axisValue: number; seriesName: string; value: [string, number | null]; color: string }>;
        if (!ps.length) return "";
        const kopf = new Date(ps[0]!.axisValue).toLocaleString("de-DE", {
          weekday: spanne === "tag" ? undefined : "short",
          day: "2-digit",
          month: "2-digit",
          hour: spanne === "jahr" ? undefined : "2-digit",
          minute: spanne === "jahr" ? undefined : "2-digit",
        });
        const zeilen = ps
          .filter((p) => p.value[1] != null)
          .map(
            (p) =>
              `<div style="display:flex;justify-content:space-between;gap:16px"><span><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${p.color};margin-right:6px"></span>${p.seriesName}</span><span>${ZAHL(p.value[1]!, stellen)} ${einheit}</span></div>`,
          )
          .join("");
        return `<div style="color:rgba(255,255,255,.6);margin-bottom:4px">${kopf}</div>${zeilen || "keine Werte"}`;
      },
    },
    xAxis: {
      type: "time",
      min: t[0],
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, hideOverlap: true, formatter: zeitachse(spanne) },
    },
    yAxis: {
      type: "value",
      min,
      max,
      interval: intervall,
      splitNumber: 3,
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10, formatter: (v: number) => ZAHL(v, stellen) },
      splitLine: { lineStyle: { color: C.gridline } },
    },
    series: reihen.map((r, i) => ({
      name: r.name,
      type: balken ? "bar" : "line",
      data: t.map((x, j) => [x, r.werte[j]]),
      showSymbol: false,
      connectNulls: false,
      barMaxWidth: 8,
      lineStyle: { color: r.farbe, width: 2 },
      itemStyle: { color: r.farbe, borderRadius: balken ? [2, 2, 0, 0] : undefined },
      endLabel: mehrere
        ? { show: true, formatter: r.name, color: C.text, fontFamily: MONO, fontSize: 10, offset: [4, 0] }
        : undefined,
      // Enden zwei Linien auf demselben Wert, rücken die Namen auseinander statt übereinander.
      labelLayout: mehrere ? { moveOverlap: "shiftY" } : undefined,
      markLine:
        grenze && i === 0
          ? {
              symbol: "none",
              silent: true,
              lineStyle: { color: C.alert, type: "dashed", width: 1 },
              label: { formatter: grenze.wort, color: C.text, fontFamily: MONO, fontSize: 10, position: "insideEndTop" },
              data: [{ yAxis: grenze.wert }],
            }
          : undefined,
    })),
  };
}

/** Der feste Rahmen um ein Diagramm. `EChart` setzt sich selbst `height: 100%`; ohne einen Rahmen
 *  mit fester Höhe wächst die Zeichenfläche mit ihrem Behälter und der Behälter mit ihr, endlos. */
function Flaeche({ className, option: o }: { className: string; option: EChartsCoreOption }) {
  return (
    <div className={className}>
      <EChart option={o} />
    </div>
  );
}

function Diagramm({ titel, untertitel, legende, children }: { titel: string; untertitel?: string; legende?: Reihe[]; children: React.ReactNode }) {
  return (
    <figure className="m-0 flex min-w-0 flex-col gap-1 rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2">
      <figcaption className="flex flex-wrap items-baseline justify-between gap-x-3">
        <span className="text-[14px] text-text-1">{titel}</span>
        {legende && legende.length > 1 ? (
          <span className="flex gap-3 text-[12px] text-text-3">
            {legende.map((r) => (
              <span key={r.name} className="inline-flex items-center gap-1.5">
                <span className="inline-block h-[3px] w-[12px] rounded-full" style={{ background: r.farbe }} />
                {r.name}
              </span>
            ))}
          </span>
        ) : untertitel ? (
          <span className="text-[12px] text-text-3">{untertitel}</span>
        ) : null}
      </figcaption>
      {children}
    </figure>
  );
}

const hat = (werte: (number | null)[]) => werte.some((v) => v != null);

export function VerlaufAnsicht({ v, spanne }: { v: Verlauf; spanne: Spanne }) {
  const p = v.punkte ?? [];
  const t = p.map((x) => x.t);
  const s = v.schritt_min ?? 5;
  const reihe = (f: (x: Punkt) => number | null | undefined) => p.map((x) => f(x) ?? null);

  const belegt = reihe((x) => (x.platte_belegt_bytes != null && x.platte_gesamt_bytes ? (x.platte_belegt_bytes / x.platte_gesamt_bytes) * 100 : null));
  const temperatur: Reihe[] = [
    { name: "Rechner", farbe: C.pv, werte: reihe((x) => x.temperatur_c) },
    { name: "SSD", farbe: C.ev, werte: reihe((x) => x.ssd_temperatur_c) },
  ].filter((r) => hat(r.werte));
  const cpu = reihe((x) => x.cpu_prozent);
  const ram = reihe((x) => (x.speicher_belegt_mb != null ? x.speicher_belegt_mb / 1024 : null));
  const ramGesamt = p.map((x) => x.speicher_gesamt_mb).find((x) => x != null);
  const netz: Reihe[] = [
    { name: "empfangen", farbe: C.ev, werte: reihe((x) => (x.netz_empfangen_bytes_s ?? 0) / 1000) },
    { name: "gesendet", farbe: C.pv, werte: reihe((x) => (x.netz_gesendet_bytes_s ?? 0) / 1000) },
  ];
  const daten: Reihe[] = [
    { name: "Datenbank", farbe: C.pv, werte: reihe((x) => (x.datenbank_bytes != null ? x.datenbank_bytes / 1e6 : null)) },
    { name: "Sicherungen", farbe: C.ev, werte: reihe((x) => (x.sicherung_bytes != null ? x.sicherung_bytes / 1e6 : null)) },
  ].filter((r) => hat(r.werte));
  const spannung = reihe((x) => x.eingangsspannung_v_min);
  const geschrieben = reihe((x) => (x.ssd_geschrieben_bytes ? x.ssd_geschrieben_bytes / 1e9 : null));
  const dienste = Array.from(new Set(p.flatMap((x) => Object.keys(x.dienste ?? {})))).sort();

  const CHART = "h-[150px] w-full";
  return (
    <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
      {hat(belegt) ? (
        <Diagramm titel="SSD belegt" untertitel="Prozent der Platte">
          <Flaeche className={CHART} option={option(spanne, s, t, [{ name: "belegt", farbe: C.pv, werte: belegt }], "%", 1, { min: 0, max: 100, intervall: 25, grenze: { wert: 85, wort: "85 %" } })} />
        </Diagramm>
      ) : null}
      {temperatur.length ? (
        <Diagramm titel="Temperatur" legende={temperatur}>
          <Flaeche className={CHART} option={option(spanne, s, t, temperatur, "°C", 1, { grenze: { wert: 80, wort: "80 °C" } })} />
        </Diagramm>
      ) : null}
      {hat(cpu) ? (
        <Diagramm titel="CPU-Auslastung" untertitel="Mittel aller Kerne, %">
          <Flaeche className={CHART} option={option(spanne, s, t, [{ name: "Auslastung", farbe: C.pv, werte: cpu }], "%", 1, { min: 0 })} />
        </Diagramm>
      ) : null}
      {hat(ram) ? (
        <Diagramm titel="Arbeitsspeicher belegt" untertitel="GB">
          <EChart
            className={CHART}
            option={option(spanne, s, t, [{ name: "belegt", farbe: C.ev, werte: ram }], "GB", 2, {
              min: 0,
              grenze: ramGesamt ? { wert: ramGesamt / 1024, wort: "gesamt" } : undefined,
            })}
          />
        </Diagramm>
      ) : null}
      {netz.some((r) => r.werte.some((w) => w)) ? (
        <Diagramm titel="Netzwerk" legende={netz}>
          <Flaeche className={CHART} option={option(spanne, s, t, netz, "kB/s", 1, { min: 0 })} />
        </Diagramm>
      ) : null}
      {daten.length ? (
        <Diagramm titel="Datenbank und Sicherungen" legende={daten.length > 1 ? daten : undefined} untertitel="MB">
          <Flaeche className={CHART} option={option(spanne, s, t, daten, "MB", 1, { min: 0 })} />
        </Diagramm>
      ) : null}
      {hat(spannung) ? (
        <Diagramm titel="Eingangsspannung" untertitel="tiefster Wert je Abschnitt, V">
          <Flaeche className={CHART} option={option(spanne, s, t, [{ name: "Spannung", farbe: C.pv, werte: spannung }], "V", 2, { min: 4.5, max: 5.3, grenze: { wert: 4.85, wort: "4,85 V" } })} />
        </Diagramm>
      ) : null}
      {hat(geschrieben) ? (
        <Diagramm titel="Auf die SSD geschrieben" untertitel="GB je Abschnitt">
          <Flaeche className={CHART} option={option(spanne, s, t, [{ name: "geschrieben", farbe: C.ev, werte: geschrieben }], "GB", 2, { min: 0, balken: true })} />
        </Diagramm>
      ) : null}
      {dienste.map((d) => (
        <Diagramm key={d} titel={`${DIENSTNAMEN[d] ?? d}: Speicher`} untertitel="MB">
          <EChart
            className="h-[110px] w-full"
            option={option(spanne, s, t, [{ name: "Speicher", farbe: C.mist, werte: reihe((x) => x.dienste?.[d]?.speicher_mb) }], "MB", 0, { min: 0 })}
          />
        </Diagramm>
      ))}
    </div>
  );
}

export function prognoseSaetze(v: Verlauf): string[] {
  const p = v.prognose;
  if (!p || (p.tage_verlauf ?? 0) < 7) {
    return [`Für eine Prognose braucht es sieben Tage Verlauf; bisher sind es ${ZAHL(p?.tage_verlauf ?? 0, 1)}.`];
  }
  const saetze: string[] = [];
  if (p.platte_bytes_pro_tag != null) {
    if (p.platte_bytes_pro_tag <= 0) saetze.push("Die SSD füllt sich derzeit nicht.");
    else
      saetze.push(
        `Die SSD füllt sich um ${bytesText(p.platte_bytes_pro_tag)} pro Tag${p.platte_voll_in_tagen != null ? `; bei diesem Tempo ist sie ${dauerText(p.platte_voll_in_tagen)} voll` : ""}.`,
      );
  }
  if (p.datenbank_bytes_pro_tag != null) saetze.push(`Die Datenbank wächst um ${bytesText(p.datenbank_bytes_pro_tag)} pro Tag.`);
  if (p.ssd_geschrieben_bytes_pro_tag != null) saetze.push(`Auf die SSD werden ${bytesText(p.ssd_geschrieben_bytes_pro_tag)} pro Tag geschrieben.`);
  return saetze;
}

export function Verlauf() {
  const [spanne, setSpanne] = useState<Spanne>("tag");
  const [v, setV] = useState<Verlauf | null>(null);
  const [fehler, setFehler] = useState(false);

  useEffect(() => {
    let aus = false;
    const laden = async () => {
      try {
        const antwort = await fetch(`/api/dch/system/geraet/verlauf?spanne=${spanne}`, { cache: "no-store" });
        if (!antwort.ok) throw new Error(String(antwort.status));
        const daten = (await antwort.json()) as Verlauf;
        if (!aus) {
          setV(daten);
          setFehler(false);
        }
      } catch {
        if (!aus) setFehler(true);
      }
    };
    void laden();
    // Neue Punkte kommen alle fünf Minuten.
    const timer = setInterval(() => void laden(), 5 * 60_000);
    return () => {
      aus = true;
      clearInterval(timer);
    };
  }, [spanne]);

  if (v && !v.unterstuetzt) return null;
  return (
    <Systemkarte zeichen={ABSCHNITTSZEICHEN.Verlauf} titel="Verlauf">
      <div className="konto-reihe">
        <div className="konto-reihe" role="group" aria-label="Spanne">
          {SPANNEN.map((x) => (
            <button
              key={x.wert}
              type="button"
              aria-pressed={spanne === x.wert}
              onClick={() => setSpanne(x.wert)}
              className="zugang-knopf zugang-knopf-klein wahl-knopf"
            >
              {x.wort}
            </button>
          ))}
        </div>
      </div>
      {fehler && !v ? <p className="m-0 text-[14px] text-text-3">Der Verlauf ist gerade nicht zu holen.</p> : null}
      {v ? (
        <>
          <ul className="m-0 flex list-none flex-col gap-1 p-0 text-[14px] text-text-2">
            {prognoseSaetze(v).map((satz) => (
              <li key={satz}>{satz}</li>
            ))}
          </ul>
          {v.punkte?.length ? (
            <VerlaufAnsicht v={v} spanne={spanne} />
          ) : (
            <p className="m-0 text-[14px] text-text-3">Noch keine Messpunkte in dieser Spanne. Das Gerät legt alle fünf Minuten einen an.</p>
          )}
        </>
      ) : !fehler ? (
        <p className="m-0 text-[14px] text-text-3">Lade …</p>
      ) : null}
    </Systemkarte>
  );
}
