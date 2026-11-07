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
 * und Leistung auf zwei Achsen. Hier geht es um sechs Größen mit sechs Einheiten über zwei Tage,
 * und zwei davon sind keine Zahlen, sondern Zustände. Sechs Flächen übereinander mit einer
 * gemeinsamen Zeitachse sagen das, ohne eine Achse zu erfinden, die es nicht gibt.
 *
 * **Die Reihenfolge ist die Begründung.** Oben steht, was der Planer nicht ändern kann: Preis,
 * PV-Erwartung, Wärmebedarf. Darunter der Pufferinhalt, der aus seiner Entscheidung folgt. Unten
 * die Entscheidung selbst. Wer von oben nach unten liest, liest die Rechnung in der Richtung, in
 * der sie entstanden ist - und sieht, warum eine teure Stunde ohne Anforderung bleiben darf: der
 * Puffer reicht.
 *
 * **Was echt ist.** Alles aus `/plan`, je Viertelstunde. Der Wärmebedarf ist dabei kein Messwert,
 * sondern das Modell v1 des Hauses (Heizgradstunden gegen die Prognose plus Warmwasserprofil);
 * derselbe Bedarf, gegen den der Optimierer rechnet, nicht ein zweiter daneben. Wo der Planer
 * nichts sagt - außerhalb seines Horizonts, ohne Preise, bei blinden Puffersensoren -, bleibt die
 * Kurve eine Lücke und keine Linie auf dem Boden.
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

/**
 * Die sechs Flächen: Titel, Oberkante, Höhe.
 *
 * An einer Stelle und nicht an drei. Gitter, Achsen und Titel müssen zusammenpassen, und als die
 * Zahlen noch in drei Listen standen, war eine Fläche um 20 Pixel verschoben, ohne dass man sah,
 * welche der drei Listen recht hatte.
 */
const FLAECHEN = [
  { titel: "Strompreis · ct/kWh", top: 28, hoehe: 92 },
  { titel: "PV-Erwartung · kW", top: 162, hoehe: 80 },
  { titel: "Wärmebedarf · kW thermisch", top: 284, hoehe: 92 },
  { titel: "Pufferinhalt · kWh", top: 418, hoehe: 80 },
  { titel: "Wärmepumpe", top: 540, hoehe: 26 },
  { titel: "Pelletofen", top: 596, hoehe: 26 },
] as const;

/** Wie hoch der Kasten um die Zeichnung sein muss: letzte Fläche plus Platz für die Zeitachse. */
const HOEHE = Math.max(...FLAECHEN.map((f) => f.top + f.hoehe)) + 34;

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
    if (iv.length === 0 || !plan) return null;

    const t = (s: string) => new Date(s).getTime();
    const preis = iv.filter((i) => i.price_ct_kwh != null).map((i) => [t(i.ts), i.price_ct_kwh]);
    const pv = iv.map((i) => [t(i.ts), i.expected_pv_kw]);
    // `null` und nicht `0`: eine Viertelstunde ohne Fahrplan ist eine Lücke in der Fläche. Eine
    // Null wäre die Behauptung, das Haus brauche dort keine Wärme.
    const heizen = iv.map((i) => [t(i.ts), i.heat_demand_kw ?? null]);
    const warmwasser = iv.map((i) => [t(i.ts), i.dhw_demand_kw ?? null]);
    const puffer = iv.map((i) => [t(i.ts), i.buffer_kwh ?? null]);
    const hatWaerme = iv.some((i) => i.heat_demand_kw != null);
    const hatPuffer = iv.some((i) => i.buffer_kwh != null);
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
    const baender = (plan.windows ?? [])
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

    // Unterhalb dieser Linie darf der Puffer nicht landen; sie ist eine Bedingung des Modells und
    // keine Zierde. Ohne sie wäre die Kurve eine Zahlenreihe ohne Maßstab.
    const reserve =
      plan.buffer_min_kwh != null
        ? {
            silent: true,
            itemStyle: { color: "rgba(224,83,61,.10)" },
            label: { show: true, position: "insideBottomLeft" as const, formatter: "RESERVE", color: C.alert, fontFamily: MONO, fontSize: 10, letterSpacing: 1 },
            data: [[{ yAxis: 0 }, { yAxis: plan.buffer_min_kwh }]],
          }
        : undefined;

    // `gridIndex` ist hier nicht Zierde: ohne ihn hängt **jede** Achse an Gitter 0, und die
    // Flächen fallen übereinander. Gesehen am 07.11.2026, und von außen sah es aus wie eine
    // Zeichnung mit zwei Achsen - also genau das, was dieser Aufbau vermeiden soll.
    const achse = (gridIndex: number, labels: boolean) => ({
      type: "time" as const,
      gridIndex,
      min: t(plan.horizon_start),
      max: t(plan.horizon_end),
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: labels },
      axisLabel: labels ? { color: C.text, fontFamily: MONO, fontSize: 10 } : { show: false },
      splitLine: { show: true, lineStyle: { color: C.gridline } },
    });
    const wert = (gridIndex: number, max?: number) => ({
      type: "value" as const,
      gridIndex,
      min: 0,
      ...(max != null ? { max } : {}),
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

    const zeile = (name: string, wertText: string, farbe?: string) =>
      `<div>${name} <b style="font-family:${MONO}${farbe ? `;color:${farbe}` : ""}">${wertText}</b></div>`;

    return {
      animation: false,
      title: FLAECHEN.map((f) => ({
        text: f.titel,
        left: 56,
        top: f.top - 22,
        textStyle: { color: C.text, fontSize: 11, fontWeight: "normal" as const },
      })),
      grid: FLAECHEN.map((f) => ({ left: 56, right: 18, top: f.top, height: f.hoehe })),
      xAxis: FLAECHEN.map((_, k) => achse(k, k === FLAECHEN.length - 1)),
      yAxis: [
        wert(0),
        wert(1),
        wert(2),
        wert(3, plan.buffer_capacity_kwh ?? undefined),
        zustandsachse(4),
        zustandsachse(5),
      ],
      axisPointer: { link: [{ xAxisIndex: "all" }], label: { show: false }, lineStyle: { color: "rgba(255,255,255,.3)" } },
      tooltip: {
        trigger: "axis" as const,
        // Ohne das verlässt das Hinweisfenster am unteren Rand die Zeichnung und wird vom
        // Fensterrand abgeschnitten - auf dem iPad bei jedem Tippen in der unteren Hälfte.
        confine: true,
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
            zeile("Strompreis", i.price_ct_kwh == null ? "-" : `${de(i.price_ct_kwh, 1)} ct`),
            zeile("PV erwartet", `${de(i.expected_pv_kw, 1)} kW`),
          ];
          if (i.heat_demand_kw != null) {
            const summe = i.heat_demand_kw + (i.dhw_demand_kw ?? 0);
            zeilen.push(zeile("Wärmebedarf", `${de(summe, 1)} kW`));
            zeilen.push(
              `<div style="padding-left:12px;color:rgba(255,255,255,.65)">Heizen <b style="font-family:${MONO};color:${C.house}">${de(i.heat_demand_kw, 1)}</b> · Warmwasser <b style="font-family:${MONO};color:${C.dhw}">${de(i.dhw_demand_kw ?? 0, 1)}</b></div>`,
            );
          }
          if (i.buffer_kwh != null) zeilen.push(zeile("Puffer danach", `${de(i.buffer_kwh, 1)} kWh`, C.puffer));
          if (i.outdoor_temp_c != null) {
            const cop = i.cop == null ? "" : ` · COP ${de(i.cop, 2)}`;
            zeilen.push(zeile("Außen", `${de(i.outdoor_temp_c, 1)} °C${cop}`));
          }
          zeilen.push(`<div>Wärmepumpe <b style="color:${z.farbe}">${z.wort}</b></div>`);
          zeilen.push(
            `<div>Pelletofen <b style="color:${i.planned_stove_on ? C.stove : "inherit"}">${i.planned_stove_on == null ? "kein Fahrplan" : i.planned_stove_on ? "brennt" : "aus"}</b></div>`,
          );
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
        // Gestapelt, weil die Summe die Größe ist, gegen die geplant wird, und die beiden Teile
        // sich verschieden verhalten: das Heizen hängt an der Außentemperatur, das Warmwasser am
        // Tagesprofil. Nebeneinander wäre die Summe nicht ablesbar, einzeln nicht die Herkunft.
        {
          name: "Heizen",
          type: "line" as const,
          xAxisIndex: 2,
          yAxisIndex: 2,
          stack: "waerme",
          data: heizen,
          symbol: "none" as const,
          lineStyle: { color: C.house, width: 1.5 },
          areaStyle: { color: "rgba(207,216,220,.22)" },
          markLine: jetzt,
        },
        {
          name: "Warmwasser",
          type: "line" as const,
          xAxisIndex: 2,
          yAxisIndex: 2,
          stack: "waerme",
          data: warmwasser,
          symbol: "none" as const,
          lineStyle: { color: C.dhw, width: 1.5 },
          areaStyle: { color: "rgba(74,163,199,.34)" },
        },
        {
          name: "Pufferinhalt",
          type: "line" as const,
          xAxisIndex: 3,
          yAxisIndex: 3,
          data: puffer,
          symbol: "none" as const,
          lineStyle: { color: C.puffer, width: 2 },
          areaStyle: { color: "rgba(143,191,107,.14)" },
          markArea: reserve,
          markLine: jetzt,
        },
        { name: "Wärmepumpe", type: "bar" as const, xAxisIndex: 4, yAxisIndex: 4, data: wp, barWidth: "92%", markLine: jetzt },
        { name: "Pelletofen", type: "bar" as const, xAxisIndex: 5, yAxisIndex: 5, data: ofen, barWidth: "92%", markLine: jetzt },
      ],
      // Die beiden leeren Flächen bleiben stehen und bekommen ein Wort statt einer leeren Achse:
      // „nicht geplant" ist eine Aussage, eine leere Fläche wäre ein Rätsel.
      graphic: [
        ...(hatWaerme ? [] : [leererHinweis(FLAECHEN[2].top + FLAECHEN[2].hoehe / 2, "kein Wärmebedarf im Fahrplan")]),
        ...(hatPuffer ? [] : [leererHinweis(FLAECHEN[3].top + FLAECHEN[3].hoehe / 2, "kein Pufferverlauf im Fahrplan")]),
      ],
    };
  }, [plan]);

  const kennzahlen = useMemo(() => {
    const iv = plan?.intervals ?? [];
    const viertel = (n: number) => `${de(n / 4, 1)} h`;
    const preise = iv.map((i) => i.price_ct_kwh).filter((p): p is number => p != null);
    const waerme = iv
      .filter((i) => i.heat_demand_kw != null)
      .reduce((s, i) => s + (i.heat_demand_kw ?? 0) + (i.dhw_demand_kw ?? 0), 0);
    const cops = iv.map((i) => i.cop).filter((c): c is number => c != null);
    return {
      wp: viertel(iv.filter((i) => i.planned_hp_state === "release").length),
      gemieden: viertel(iv.filter((i) => i.planned_hp_state === "avoid").length),
      ofen: iv.some((i) => i.planned_stove_on != null) ? viertel(iv.filter((i) => i.planned_stove_on).length) : null,
      // Viertelstunden in Stunden: die Leistungen stehen je Viertelstunde, die Summe ist Arbeit.
      waerme: waerme > 0 ? de(waerme / 4, 0) : null,
      cop: cops.length ? `${de(Math.min(...cops), 1)} bis ${de(Math.max(...cops), 1)}` : null,
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
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        <Stat label="Wärmepumpe angefordert" value={kennzahlen.wp} tone="ember" hint="im ganzen Horizont" />
        <Stat label="bewusst gemieden" value={kennzahlen.gemieden} tone="muted" hint="teure Stunden ohne Anforderung" />
        <Stat label="Ofen geplant" value={kennzahlen.ofen ?? "-"} tone={kennzahlen.ofen ? "ember" : "muted"} hint={kennzahlen.ofen ? "Volllast, 15 kg je Füllung" : "kein Fahrplan für den Ofen"} />
        <Stat label="Wärmebedarf geplant" value={kennzahlen.waerme ?? "-"} unit="kWh" tone="mist" hint={kennzahlen.waerme ? "Modell v1, nicht gemessen" : "kein Fahrplan"} />
        <Stat label="COP im Horizont" value={kennzahlen.cop ?? "-"} tone="mist" hint="aus der Außentemperatur" />
        <Stat label="Preisspanne" value={kennzahlen.spanne} unit="ct" tone="amber" hint="im Horizont" />
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
          <div className="w-full" style={{ height: HOEHE }}>
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
          <span className="inline-flex items-center gap-1.5">
            <span style={{ display: "inline-block", width: 14, height: 10, borderRadius: 2, background: C.house }} />
            Heizen
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span style={{ display: "inline-block", width: 14, height: 10, borderRadius: 2, background: C.dhw }} />
            Warmwasser
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span style={{ display: "inline-block", width: 14, height: 3, borderRadius: 2, background: C.puffer }} />
            Pufferinhalt
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
        <CardHead title="Woher die Zahlen kommen" />
        <p className="text-[13px] leading-[1.6] text-text-3">
          Preis und PV-Erwartung sind Prognosen, der Wärmebedarf ist ein Modell: Heizgradstunden gegen die Wettervorhersage plus ein Warmwasserprofil über den Tag. Es ist derselbe Bedarf, gegen den der Optimierer rechnet, nicht ein zweiter daneben. Gemessen wird er noch nicht; das kommt mit dem Wärmemengenzähler über den eBUS-Anschluss. Der COP folgt aus der Außentemperatur, noch nicht aus der Vorlauftemperatur, denn die liefert bislang kein Fühler.
        </p>
        <p className="mt-3 text-[13px] leading-[1.6] text-text-3">
          Was hier noch fehlt: die Nachbetrachtung, die Plan und Wirklichkeit gegeneinanderhält, und der Lernschritt, der das Hüllenmodell aus den Prognosefehlern nachzieht. Der Entwurf dazu steht in <code className="mono text-[12px]">docs/design/digitaler-zwilling.md</code>.
        </p>
      </Card>
    </div>
  );
}

/** Ein Wort in der Mitte einer leeren Fläche. Besser als eine leere Achse ohne Erklärung. */
function leererHinweis(top: number, text: string) {
  return {
    type: "text" as const,
    left: "center" as const,
    top,
    silent: true,
    style: { text, fill: C.text, font: `11px ${MONO}` },
  };
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
    <div className="overflow-x-auto">
      <table className="w-full border-collapse text-[12px]">
        <thead>
          <tr className="text-left text-text-3">
            <th scope="col" className="border-b border-white/10 py-1.5 font-medium">Zeit</th>
            <th scope="col" className="border-b border-white/10 py-1.5 text-right font-medium">Preis</th>
            <th scope="col" className="border-b border-white/10 py-1.5 text-right font-medium">Bedarf</th>
            <th scope="col" className="border-b border-white/10 py-1.5 text-right font-medium">Puffer</th>
            <th scope="col" className="border-b border-white/10 py-1.5 text-right font-medium">Wärmepumpe</th>
            <th scope="col" className="border-b border-white/10 py-1.5 text-right font-medium">Ofen</th>
            <th scope="col" className="border-b border-white/10 py-1.5 pl-4 font-medium">Warum</th>
          </tr>
        </thead>
        <tbody>
          {zeilen.map((i) => {
            const z = zustandOf(i.planned_hp_state);
            const bedarf = i.heat_demand_kw == null ? null : i.heat_demand_kw + (i.dhw_demand_kw ?? 0);
            return (
              <tr key={i.ts}>
                <td className="mono border-b border-white/5 py-2">{tagUndUhr(i.ts)}</td>
                <td className="mono border-b border-white/5 py-2 text-right">{i.price_ct_kwh == null ? "-" : `${de(i.price_ct_kwh, 1)} ct`}</td>
                <td className="mono border-b border-white/5 py-2 text-right">{bedarf == null ? "-" : `${de(bedarf, 1)} kW`}</td>
                <td className="mono border-b border-white/5 py-2 text-right" style={{ color: i.buffer_kwh == null ? undefined : C.puffer }}>
                  {i.buffer_kwh == null ? "-" : `${de(i.buffer_kwh, 1)} kWh`}
                </td>
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
    </div>
  );
}
