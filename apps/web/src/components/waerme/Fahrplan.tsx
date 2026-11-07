"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { EChartsCoreOption } from "echarts/core";
import { api } from "@/lib/api/client";
import type { Plan } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Stat } from "@/components/ui/Stat";
import { EChart } from "@/components/charts/EChart";
import { C, MONO } from "@/components/charts/palette";

/**
 * Die Seite „Fahrplan": der Horizont als Zeitreihen, nicht als Summe.
 *
 * **Warum nicht in die Tageskurve.** Die Kurve auf der Startseite zeigt einen Tag und legt Preis
 * und Leistung auf zwei Achsen. Hier geht es um vier Größen mit vier Einheiten über 36 Stunden,
 * und zwei davon sind keine Zahlen, sondern Zustände. Vier Flächen übereinander mit einer
 * gemeinsamen Zeitachse sagen das, ohne eine Achse zu erfinden, die es nicht gibt.
 *
 * **Was echt ist.** Alles. Preis und PV-Erwartung je Viertelstunde kommen aus `/plan`, ebenso der
 * geplante Zustand der Wärmepumpe, der geplante Ofen und die Begründung je Schritt. Was dort nicht
 * steht, steht hier auch nicht: **der Wärmebedarf und der Pufferverlauf fehlen**, weil der Planer
 * sie nicht je Schritt ausgibt. Sie gehören zum Zwilling und kommen mit ihm.
 *
 * **Der Zustand trägt drei Kennzeichen, nicht eines.** Farbe, Balkenhöhe und das Wort im
 * Hinweisfenster. „Angefordert" und „gemieden" liegen farblich bei ΔE 14 und damit knapp unter
 * dem, was zwei Flächen in einer Zeile sicher unterscheidbar macht; die Höhe und das Wort schließen
 * die Lücke.
 */
const LIVE_MS = 60_000;

/** Die vier Zustände, die `planned_hp_state` kennt, mit Farbe, Höhe und Wort. */
const WP_ZUSTAND = {
  release: { wort: "angefordert", farbe: C.heatPump, hoehe: 1 },
  avoid: { wort: "gemieden", farbe: C.alert, hoehe: 0.55 },
  free: { wort: "frei", farbe: "rgba(255,255,255,.3)", hoehe: 0.3 },
  off: { wort: "aus", farbe: "rgba(255,255,255,.14)", hoehe: 0.12 },
} as const;

type WpZustand = keyof typeof WP_ZUSTAND;

function zustandOf(s: string): (typeof WP_ZUSTAND)[WpZustand] {
  return WP_ZUSTAND[(s as WpZustand) in WP_ZUSTAND ? (s as WpZustand) : "off"];
}

function de(x: number, n = 1): string {
  return x.toFixed(n).replace(".", ",");
}

function uhr(ts: string): string {
  const d = new Date(ts);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

function tagUndUhr(ts: string): string {
  const d = new Date(ts);
  const heute = new Date();
  const tage = Math.round((new Date(d).setHours(0, 0, 0, 0) - new Date(heute).setHours(0, 0, 0, 0)) / 86400000);
  const wort = tage === 0 ? "heute" : tage === 1 ? "morgen" : tage === 2 ? "übermorgen" : d.toLocaleDateString("de-DE", { weekday: "short" });
  return `${wort} ${uhr(ts)}`;
}

export function Fahrplan() {
  const [plan, setPlan] = useState<Plan | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);

  const laden = useCallback(async () => {
    try {
      setPlan(await api.plan());
      setFehler(null);
    } catch (e) {
      setFehler(e instanceof Error ? e.message : "Der Fahrplan ist gerade nicht zu erreichen.");
    }
  }, []);

  useEffect(() => {
    void laden();
    const t = setInterval(() => {
      if (document.visibilityState === "visible") void laden();
    }, LIVE_MS);
    return () => clearInterval(t);
  }, [laden]);

  const option = useMemo<EChartsCoreOption | null>(() => {
    const iv = plan?.intervals ?? [];
    if (iv.length === 0) return null;

    const t = (s: string) => new Date(s).getTime();
    const preis = iv.filter((i) => i.price_ct_kwh != null).map((i) => [t(i.ts), i.price_ct_kwh]);
    const pv = iv.map((i) => [t(i.ts), i.expected_pv_kw]);
    const wp = iv.map((i) => {
      const z = zustandOf(i.planned_hp_state);
      return { value: [t(i.ts), z.hoehe], itemStyle: { color: z.farbe } };
    });
    const ofen = iv
      .filter((i) => i.planned_stove_on != null)
      .map((i) => ({
        value: [t(i.ts), i.planned_stove_on ? 1 : 0.12],
        itemStyle: { color: i.planned_stove_on ? C.stove : "rgba(255,255,255,.14)" },
      }));

    // Preisfenster als Band hinter dem Preis. Dieselbe Lesart wie auf der Startseite: billig und
    // negativ werden hervorgehoben, teuer bleibt der Normalfall und braucht keine Farbe.
    const baender = (plan?.windows ?? [])
      .filter((w) => w.kind === "cheap" || w.kind === "negative")
      .map((w) => [
        {
          xAxis: t(w.start),
          itemStyle: { color: w.kind === "negative" ? "rgba(224,83,61,.14)" : "rgba(127,163,179,.14)" },
          // Ein negatives Fenster liegt in aller Regel **innerhalb** eines Preistiefs. Beide oben
          // links beschriftet, und sie drucken sich gegenseitig zu; das war auf dem ersten
          // Bildschirmfoto zu sehen. Also eine Beschriftung oben, die andere unten.
          label: { show: true, position: w.kind === "negative" ? ("insideBottomLeft" as const) : ("insideTopLeft" as const), formatter: w.kind === "negative" ? "NEGATIV" : "PREISTIEF", color: w.kind === "negative" ? C.alert : C.price, fontFamily: MONO, fontSize: 10, letterSpacing: 1 },
        },
        { xAxis: t(w.end) },
      ]);

    // `gridIndex` ist hier nicht Zierde: ohne ihn hängt **jede** Achse an Gitter 0, und die vier
    // Flächen fallen übereinander. Gesehen am 07.11.2026, und von außen sah es aus wie eine
    // Zeichnung mit zwei Achsen - also genau das, was dieser Aufbau vermeiden soll.
    const achse = (gridIndex: number, labels: boolean) => ({
      type: "time" as const,
      gridIndex,
      min: t(plan!.horizon_start),
      max: t(plan!.horizon_end),
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: labels },
      axisLabel: labels ? { color: C.text, fontFamily: MONO, fontSize: 10 } : { show: false },
      splitLine: { show: true, lineStyle: { color: C.gridline } },
    });
    const wert = (gridIndex: number) => ({
      type: "value" as const,
      gridIndex,
      min: 0,
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10 },
      splitLine: { lineStyle: { color: C.gridline } },
    });
    const zustandsachse = (gridIndex: number) => ({ type: "value" as const, gridIndex, min: 0, max: 1, show: false });

    const jetzt = {
      symbol: "none" as const,
      silent: true,
      lineStyle: { color: "var(--amber-soft)", type: "dashed" as const, width: 1.2 },
      label: { show: false },
      data: [{ xAxis: Date.now() }],
    };

    return {
      animation: false,
      title: [
        { text: "Strompreis · ct/kWh", left: 56, top: 6 },
        { text: "PV-Erwartung · kW", left: 56, top: 154 },
        { text: "Wärmepumpe", left: 56, top: 282 },
        { text: "Pelletofen", left: 56, top: 330 },
      ].map((x) => ({ ...x, textStyle: { color: C.text, fontSize: 11, fontWeight: "normal" as const } })),
      grid: [
        { left: 56, right: 18, top: 28, height: 108 },
        { left: 56, right: 18, top: 176, height: 96 },
        { left: 56, right: 18, top: 300, height: 28 },
        { left: 56, right: 18, top: 348, height: 28 },
      ],
      xAxis: [achse(0, false), achse(1, false), achse(2, false), achse(3, true)],
      yAxis: [wert(0), wert(1), zustandsachse(2), zustandsachse(3)],
      axisPointer: { link: [{ xAxisIndex: "all" }], label: { show: false }, lineStyle: { color: "rgba(255,255,255,.3)" } },
      tooltip: {
        trigger: "axis" as const,
        backgroundColor: C.deep,
        borderColor: "rgba(242,169,0,.4)",
        textStyle: { color: "#f1f5f5", fontSize: 12 },
        formatter: (params: unknown) => {
          const arr = Array.isArray(params) ? params : [params];
          const erste = arr[0] as { value?: unknown[] } | undefined;
          const ms = Array.isArray(erste?.value) ? Number(erste.value[0]) : NaN;
          if (!Number.isFinite(ms)) return "";
          const i = iv.find((x) => t(x.ts) === ms);
          if (!i) return "";
          const z = zustandOf(i.planned_hp_state);
          const zeilen = [
            `<div style="font-family:${MONO};color:var(--amber-soft);margin-bottom:6px">${tagUndUhr(i.ts)}</div>`,
            `<div>Strompreis <b style="font-family:${MONO}">${i.price_ct_kwh == null ? "-" : `${de(i.price_ct_kwh, 1)} ct`}</b></div>`,
            `<div>PV erwartet <b style="font-family:${MONO}">${de(i.expected_pv_kw, 1)} kW</b></div>`,
            `<div>Wärmepumpe <b style="color:${z.farbe}">${z.wort}</b></div>`,
            `<div>Pelletofen <b style="color:${i.planned_stove_on ? C.stove : "inherit"}">${i.planned_stove_on == null ? "kein Fahrplan" : i.planned_stove_on ? "brennt" : "aus"}</b></div>`,
          ];
          if (i.note_de) zeilen.push(`<div style="margin-top:6px;max-width:260px;white-space:normal;color:rgba(255,255,255,.7)">${i.note_de}</div>`);
          return zeilen.join("");
        },
      },
      series: [
        {
          name: "Strompreis",
          type: "line" as const,
          xAxisIndex: 0,
          yAxisIndex: 0,
          data: preis,
          step: "end" as const,
          symbol: "none" as const,
          lineStyle: { color: C.price, width: 2 },
          areaStyle: { color: "rgba(127,163,179,.16)" },
          markArea: baender.length ? { silent: true, data: baender } : undefined,
          markLine: jetzt,
        },
        {
          name: "PV erwartet",
          type: "line" as const,
          xAxisIndex: 1,
          yAxisIndex: 1,
          data: pv,
          smooth: true,
          symbol: "none" as const,
          lineStyle: { color: C.pv, width: 2 },
          areaStyle: { color: "rgba(242,169,0,.18)" },
          markLine: jetzt,
        },
        { name: "Wärmepumpe", type: "bar" as const, xAxisIndex: 2, yAxisIndex: 2, data: wp, barWidth: "92%", markLine: jetzt },
        { name: "Pelletofen", type: "bar" as const, xAxisIndex: 3, yAxisIndex: 3, data: ofen, barWidth: "92%", markLine: jetzt },
      ],
    };
  }, [plan]);

  const kennzahlen = useMemo(() => {
    const iv = plan?.intervals ?? [];
    const viertel = (n: number) => `${de(n / 4, 1)} h`;
    const preise = iv.map((i) => i.price_ct_kwh).filter((p): p is number => p != null);
    return {
      wp: viertel(iv.filter((i) => i.planned_hp_state === "release").length),
      gemieden: viertel(iv.filter((i) => i.planned_hp_state === "avoid").length),
      ofen: iv.some((i) => i.planned_stove_on != null) ? viertel(iv.filter((i) => i.planned_stove_on).length) : null,
      spanne: preise.length ? `${de(Math.min(...preise), 0)} bis ${de(Math.max(...preise), 0)}` : "-",
      pv: plan ? de(plan.pv_forecast_today_kwh, 1) : "-",
    };
  }, [plan]);

  if (fehler) {
    return (
      <Card>
        <CardHead title="Fahrplan" />
        <p className="text-[13px] text-text-3">{fehler}</p>
      </Card>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
        <Stat label="Wärmepumpe angefordert" value={kennzahlen.wp} tone="ember" hint="im ganzen Horizont" />
        <Stat label="bewusst gemieden" value={kennzahlen.gemieden} tone="muted" hint="teure Stunden ohne Anforderung" />
        <Stat label="Ofen geplant" value={kennzahlen.ofen ?? "-"} tone={kennzahlen.ofen ? "ember" : "muted"} hint={kennzahlen.ofen ? "Volllast, 15 kg je Füllung" : "kein Fahrplan für den Ofen"} />
        <Stat label="Preisspanne" value={kennzahlen.spanne} unit="ct" tone="mist" hint="im Horizont" />
        <Stat label="PV heute erwartet" value={kennzahlen.pv} unit="kWh" tone="amber" />
      </div>

      <Card>
        <CardHead
          title="Horizont"
          right={
            plan ? (
              <span className="mono">
                {tagUndUhr(plan.horizon_start)} bis {tagUndUhr(plan.horizon_end)} · {plan.planner}
              </span>
            ) : null
          }
        />
        {/* Der Kasten trägt die Höhe, nicht das Diagramm: `EChart` setzt `height: 100%` inline, und
            das schlägt jede Klasse. Ohne umschließende Höhe fällt die Zeichnung zusammen, und zwar
            von oben nach unten - sichtbar bleibt die erste Fläche, der Rest wird abgeschnitten. */}
        {option ? (
          <div className="h-[440px] w-full">
            <EChart option={option} />
          </div>
        ) : (
          <p className="text-[13px] text-text-3">Noch kein Fahrplan gerechnet.</p>
        )}

        <div className="mt-2 flex flex-wrap gap-x-5 gap-y-2 text-[11px] text-text-3">
          {(Object.keys(WP_ZUSTAND) as WpZustand[]).map((k) => (
            <span key={k} className="inline-flex items-center gap-1.5">
              <span style={{ display: "inline-block", width: 14, height: Math.max(3, Math.round(WP_ZUSTAND[k].hoehe * 10)), borderRadius: 2, background: WP_ZUSTAND[k].farbe }} />
              Wärmepumpe {WP_ZUSTAND[k].wort}
            </span>
          ))}
          <span className="inline-flex items-center gap-1.5">
            <span style={{ display: "inline-block", width: 14, height: 10, borderRadius: 2, background: C.stove }} />
            Ofen brennt
          </span>
        </div>

        {plan?.planner_note_de ? <p className="mt-3 text-[12px] leading-[1.5] text-text-3">{plan.planner_note_de}</p> : null}
        {plan?.planner_warn_de ? <p className="mt-2 text-[12px] leading-[1.5] text-alert">{plan.planner_warn_de}</p> : null}
      </Card>

      <Card>
        <CardHead title="Die Entscheidungen" right="die teuersten und die billigsten Viertelstunden, mit Begründung" />
        <Tabelle plan={plan} />
      </Card>

      <Card>
        <CardHead title="Was hier noch fehlt" />
        <p className="text-[13px] leading-[1.6] text-text-3">
          Wärmebedarf und Pufferverlauf stehen nicht in dieser Zeichnung, weil der Planer sie nicht je Viertelstunde ausgibt. Sie gehören zum digitalen Zwilling und kommen mit ihm, zusammen mit dem COP über der Vorlauftemperatur und der Nachbetrachtung, die Plan und Wirklichkeit gegeneinanderhält. Der Entwurf dazu steht in{" "}
          <code className="mono text-[12px]">docs/design/digitaler-zwilling.md</code>.
        </p>
      </Card>
    </div>
  );
}

/** Die Entscheidungen in Worten. Sechs Zeilen, nicht hundertvierzig: die Ränder tragen die Aussage. */
function Tabelle({ plan }: { plan: Plan | null }) {
  const zeilen = useMemo(() => {
    const iv = (plan?.intervals ?? []).filter((i) => i.price_ct_kwh != null);
    if (iv.length === 0) return [];
    const nachPreis = [...iv].sort((a, b) => (b.price_ct_kwh ?? 0) - (a.price_ct_kwh ?? 0));
    const auswahl = [...nachPreis.slice(0, 3), ...nachPreis.slice(-3)];
    const gesehen = new Set<string>();
    return auswahl
      .filter((i) => (gesehen.has(i.ts) ? false : (gesehen.add(i.ts), true)))
      .sort((a, b) => new Date(a.ts).getTime() - new Date(b.ts).getTime());
  }, [plan]);

  if (zeilen.length === 0) return <p className="text-[13px] text-text-3">Noch keine Preise im Horizont.</p>;

  return (
    <table className="w-full border-collapse text-[12px]">
      <thead>
        <tr className="text-left text-text-3">
          <th scope="col" className="border-b border-white/10 py-1.5 font-medium">Zeit</th>
          <th scope="col" className="border-b border-white/10 py-1.5 text-right font-medium">Preis</th>
          <th scope="col" className="border-b border-white/10 py-1.5 text-right font-medium">Wärmepumpe</th>
          <th scope="col" className="border-b border-white/10 py-1.5 text-right font-medium">Ofen</th>
          <th scope="col" className="border-b border-white/10 py-1.5 pl-4 font-medium">Warum</th>
        </tr>
      </thead>
      <tbody>
        {zeilen.map((i) => {
          const z = zustandOf(i.planned_hp_state);
          return (
            <tr key={i.ts}>
              <td className="mono border-b border-white/5 py-2">{tagUndUhr(i.ts)}</td>
              <td className="mono border-b border-white/5 py-2 text-right">{i.price_ct_kwh == null ? "-" : `${de(i.price_ct_kwh, 1)} ct`}</td>
              <td className="border-b border-white/5 py-2 text-right" style={{ color: z.farbe }}>{z.wort}</td>
              <td className="border-b border-white/5 py-2 text-right" style={{ color: i.planned_stove_on ? C.stove : undefined }}>
                {i.planned_stove_on == null ? "-" : i.planned_stove_on ? "brennt" : "aus"}
              </td>
              <td className="border-b border-white/5 py-2 pl-4 text-text-3">{i.note_de ?? i.reason_code}</td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
