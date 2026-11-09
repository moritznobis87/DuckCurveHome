"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { EChartsCoreOption } from "echarts/core";
import { EChart } from "@/components/charts/EChart";
import { C, MONO } from "@/components/charts/palette";
import { Schema } from "@/components/anlage/Schema";
import { Card, CardHead } from "@/components/ui/Card";
import { api } from "@/lib/api/client";
import type { AnlageReplay } from "@/lib/api/models";

/**
 * Die Seite „Wiedergabe": ein vergangener Tag am Anlagenschema, zum Durchfahren.
 *
 * Schritt 10 des Zwillingsentwurfs. Gezeichnet wird **dasselbe** Schema wie auf der Seite
 * „Anlage" - dieselbe Komponente, dieselben Rohre, dasselbe wandernde Licht -, nur bekommt es
 * statt des Augenblicks ein Bild aus der Minutenreihe. Dass es dieselbe Komponente ist, ist die
 * ganze Idee: ein zweites, vereinfachtes Rückblickschema wäre in einer Woche ein anderes Haus.
 *
 * **Die Uhr der Wiedergabe ist nicht die Wanduhr.** `nowMs` bekommt die Zeit des Bildes, nicht
 * `Date.now()`. Sonst stünde am Schema „läuft seit 7 Stunden", weil es die Laufzeit gegen jetzt
 * rechnet, während das Bild von gestern Mittag ist.
 *
 * **Das Tagesband ist der Schieber.** Oben Preis und Sonne als Flächen, darunter zwei Zeitleisten
 * für Wärmepumpe und Ofen. Ein Klick springt zu dieser Uhrzeit; der Spielkopf ist die senkrechte
 * Linie. Dazu bleibt ein echter Schieber für Tastatur und Finger - ein Diagramm ist kein
 * Bedienelement, und wer mit der Tastatur arbeitet, soll nicht zielen müssen.
 */

/** Bilder je Sekunde. Bei 5-Minuten-Schritten ist 12 ein Tag in 24 Sekunden. */
const TEMPI = [2, 6, 12, 24] as const;
const SCHRITTE = [1, 5, 15] as const;

/** Deutsche Zahl. Lokal wie auf den Nachbarseiten; `lib/format` hat nur fertige Einheiten. */
function de(x: number, n = 1): string {
  return x.toLocaleString("de-DE", { minimumFractionDigits: n, maximumFractionDigits: n });
}

function heute(): string {
  return new Date().toLocaleDateString("sv-SE");
}

function tagPlus(tag: string, tage: number): string {
  const d = new Date(`${tag}T12:00:00`);
  d.setDate(d.getDate() + tage);
  return d.toLocaleDateString("sv-SE");
}

function uhr(iso: string): string {
  return new Date(iso).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });
}

function ruhigGewuenscht(): boolean {
  return typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export function Wiedergabe() {
  const [tag, setTag] = useState(heute);
  const [stepMin, setStepMin] = useState<number>(5);
  const [daten, setDaten] = useState<AnlageReplay | null>(null);
  const [laden, setLaden] = useState(true);
  const [fehler, setFehler] = useState<string | null>(null);
  const [i, setI] = useState(0);
  const [spielt, setSpielt] = useState(false);
  const [tempo, setTempo] = useState<number>(12);
  const [ruhig, setRuhig] = useState(false);

  useEffect(() => setRuhig(ruhigGewuenscht()), []);

  useEffect(() => {
    let lebt = true;
    setLaden(true);
    setSpielt(false);
    api
      .anlageWiedergabe(tag, stepMin)
      .then((d) => {
        if (!lebt) return;
        setDaten(d);
        setI(0);
        setFehler(null);
      })
      .catch((e: unknown) => {
        if (!lebt) return;
        setDaten(null);
        setFehler(e instanceof Error ? e.message : "Die Wiedergabe ist gerade nicht zu erreichen.");
      })
      .finally(() => lebt && setLaden(false));
    return () => {
      lebt = false;
    };
  }, [tag, stepMin]);

  const anzahl = daten?.frames.length ?? 0;

  // Der Abspieler. Am Ende hält er an, statt von vorn zu beginnen: ein Tag, der unbemerkt in den
  // nächsten Durchlauf rutscht, lässt einen zweimal dasselbe für zwei Tage halten.
  useEffect(() => {
    if (!spielt || anzahl === 0) return;
    const t = setInterval(() => {
      setI((alt) => {
        if (alt + 1 >= anzahl) {
          setSpielt(false);
          return anzahl - 1;
        }
        return alt + 1;
      });
    }, 1000 / tempo);
    return () => clearInterval(t);
  }, [spielt, tempo, anzahl]);

  const springen = useCallback(
    (ziel: number) => {
      setI(Math.max(0, Math.min(anzahl - 1, ziel)));
    },
    [anzahl],
  );

  // Tastatur: Leertaste spielt, Pfeile gehen Bild für Bild, Pos1 und Ende an die Ränder. Nicht auf
  // dem Fenster, sondern auf dem Abschnitt: sonst verschluckt die Seite die Leertaste auch dann,
  // wenn jemand in einem Eingabefeld steht.
  const buehne = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = buehne.current;
    if (!el) return;
    const aufTaste = (e: KeyboardEvent) => {
      if (e.key === " ") {
        e.preventDefault();
        setSpielt((s) => !s);
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        setSpielt(false);
        springen(i + 1);
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        setSpielt(false);
        springen(i - 1);
      } else if (e.key === "Home") {
        springen(0);
      } else if (e.key === "End") {
        springen(anzahl - 1);
      }
    };
    el.addEventListener("keydown", aufTaste);
    return () => el.removeEventListener("keydown", aufTaste);
  }, [i, anzahl, springen]);

  const bild = daten?.frames[i] ?? null;
  const zeitMs = bild ? new Date(bild.at).getTime() : 0;

  /** Das Tagesband ohne Spielkopf. Teuer zu bauen, deshalb nur bei neuen Daten. */
  const bandBasis = useMemo(() => {
    const f = daten?.frames ?? [];
    if (f.length === 0) return null;
    const t = (s: string) => new Date(s).getTime();
    // Das Band zeigt, was auch das Schema zeigt: Sonne, Netz, Wärmepumpe, Ofen. Den Strompreis
    // trägt das Anlagenbild nicht, und ihn hier aus einer zweiten Abfrage zu holen hieße, zwei
    // Zeitachsen in Deckung halten zu müssen - dafür gibt es die Seite „Fahrplan".
    const sonne = f.map((x) => [t(x.at), x.strom.pv_kw ?? 0]);
    const netz = f.map((x) => [t(x.at), x.strom.grid_kw ?? 0]);
    const wp = f
      .filter((x) => x.waermepumpe.running)
      .map((x) => ({ value: [t(x.at), 1] as [number, number] }));
    const ofen = f
      .filter((x) => x.ofen.running)
      .map((x) => ({ value: [t(x.at), 1] as [number, number] }));
    const von = t(f[0]!.at);
    const bis = t(f[f.length - 1]!.at);
    // "100%" und keine gerechnete Breite: auf einer Zeitachse leitet ECharts das Band aus dem
    // kleinsten Abstand zweier Punkte ab, also aus der Schrittweite. Mit einer Prozentzahl aus
    // der Bildzahl wurden daraus Haarstriche, und ein durchgehender Lauf sah aus wie ein Kamm.
    const breite = "100%";
    return { sonne, netz, wp, ofen, von, bis, breite, hatOfen: ofen.length > 0 };
  }, [daten]);

  const band = useMemo<EChartsCoreOption | null>(() => {
    if (!bandBasis) return null;
    const { sonne, netz, wp, ofen, von, bis, breite } = bandBasis;
    const spielkopf = {
      silent: true,
      symbol: ["none", "none"] as [string, string],
      lineStyle: { color: "#fff", width: 1.5, type: "solid" as const },
      label: { show: false },
      data: [{ xAxis: zeitMs }],
    };
    const achse = (gridIndex: number, zeigen: boolean) => ({
      type: "time" as const,
      gridIndex,
      min: von,
      max: bis,
      axisLine: { lineStyle: { color: C.axis } },
      axisTick: { show: false },
      axisLabel: zeigen
        ? {
            color: C.text,
            fontFamily: MONO,
            fontSize: 10,
            hideOverlap: true,
            // Immer die Uhrzeit. ECharts setzt an den Tagesgrenzen sonst die Tageszahl, und
            // zwischen "9" und "04:00" liest niemand eine Zeitachse.
            formatter: "{HH}:{mm}",
          }
        : { show: false },
      splitLine: { show: false },
    });
    return {
      animation: false,
      backgroundColor: "transparent",
      grid: [
        { left: 44, right: 12, top: 8, height: 64 },
        { left: 44, right: 12, top: 80, height: 14 },
        { left: 44, right: 12, top: 100, height: 14 },
      ],
      xAxis: [achse(0, false), achse(1, false), achse(2, true)],
      yAxis: [
        {
          gridIndex: 0,
          // Ohne Achsennamen: in 64 Punkten Hoehe draengt er sich an den Rand und wurde dort zu
          // einem einzelnen Buchstaben. Die Einheit steht in der Zeile unter dem Band.
          splitNumber: 2,
          axisLabel: { color: C.text, fontFamily: MONO, fontSize: 10 },
          splitLine: { lineStyle: { color: C.gridline } },
        },
        { gridIndex: 1, max: 1, min: 0, show: false },
        { gridIndex: 2, max: 1, min: 0, show: false },
      ],
      series: [
        {
          name: "PV",
          type: "line",
          smooth: true,
          showSymbol: false,
          data: sonne,
          lineStyle: { color: C.pv, width: 1.6 },
          areaStyle: { color: C.pv, opacity: 0.18 },
          markLine: spielkopf,
        },
        {
          name: "Netz",
          type: "line",
          showSymbol: false,
          data: netz,
          lineStyle: { color: C.price, width: 1.1 },
        },
        // Zwei Zeitleisten statt zweier Linien in einem Gitter. Wärmepumpe und Ofen liegen
        // farblich nah (ΔE 15,3 normal / 15,1 deutan, gemessen 09.11.2026), und der Ofen hält
        // gegen die Kartenfläche nur 2,99:1. Eigene Zeile mit eigener Beschriftung ist genau die
        // Entlastung, die beides zulässig macht.
        {
          name: "Wärmepumpe",
          type: "bar",
          xAxisIndex: 1,
          yAxisIndex: 1,
          data: wp,
          barWidth: breite,
          itemStyle: { color: C.heatPump },
        },
        {
          name: "Pelletofen",
          type: "bar",
          xAxisIndex: 2,
          yAxisIndex: 2,
          data: ofen,
          barWidth: breite,
          itemStyle: { color: C.stove },
        },
      ],
    };
  }, [bandBasis, zeitMs]);

  const aufBandKlick = useCallback(
    (x: number) => {
      const f = daten?.frames ?? [];
      if (f.length === 0) return;
      let beste = 0;
      let abstand = Infinity;
      f.forEach((frame, index) => {
        const d = Math.abs(new Date(frame.at).getTime() - x);
        if (d < abstand) {
          abstand = d;
          beste = index;
        }
      });
      setSpielt(false);
      springen(beste);
    },
    [daten, springen],
  );

  const vollstaendig = daten ? daten.frames.length >= daten.erwartet : true;

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <CardHead
          title="Wiedergabe"
          right={
            daten ? (
              <span className="mono text-[12px] text-text-3">
                {daten.frames.length} von {daten.erwartet} Bildern · {daten.step_min}-Minuten-Schritt
              </span>
            ) : null
          }
        />

        <div className="mb-3 flex flex-wrap items-center gap-2">
          <button type="button" className="wg-knopf" onClick={() => setTag(tagPlus(tag, -1))} aria-label="Tag zurück">
            ‹
          </button>
          <input
            type="date"
            className="wg-datum mono"
            value={tag}
            max={heute()}
            onChange={(e) => e.target.value && setTag(e.target.value)}
          />
          <button
            type="button"
            className="wg-knopf"
            onClick={() => setTag(tagPlus(tag, 1))}
            disabled={tag >= heute()}
            aria-label="Tag vor"
          >
            ›
          </button>
          <span className="ml-2 text-[12px] text-text-3">Schritt</span>
          {SCHRITTE.map((s) => (
            <button
              key={s}
              type="button"
              className={`wg-wahl${stepMin === s ? " wg-wahl-an" : ""}`}
              onClick={() => setStepMin(s)}
            >
              {s} min
            </button>
          ))}
        </div>

        {fehler ? <p className="m-0 text-[13px] text-alert">{fehler}</p> : null}
        {laden ? <p className="m-0 text-[13px] text-text-3">Der Tag wird geholt.</p> : null}

        {daten && anzahl === 0 && !laden ? (
          <p className="m-0 text-[13px] text-text-3">{daten.hinweise_de?.[0]}</p>
        ) : null}

        {bild ? (
          <div
            ref={buehne}
            tabIndex={0}
            className="wg-buehne"
            aria-label="Wiedergabe des Anlagenschemas. Leertaste spielt, Pfeiltasten gehen Bild für Bild."
          >
            <div className="anlage-buehne">
              <div className="anlage-innen">
                <div className="anlage-scroll">
                  {/* Die Uhr der Wiedergabe: die Zeit des Bildes, nicht die Wanduhr. */}
                  <Schema a={bild} nowMs={zeitMs} ruhig={ruhig} />
                </div>
              </div>
            </div>

            <div className="wg-leiste">
              <button
                type="button"
                className="wg-spiel"
                onClick={() => setSpielt((s) => !s)}
                aria-label={spielt ? "Pause" : "Abspielen"}
              >
                {spielt ? "❚❚" : "▶"}
              </button>
              <span className="mono wg-uhr">{uhr(bild.at)}</span>
              <input
                type="range"
                className="wg-schieber"
                min={0}
                max={Math.max(anzahl - 1, 0)}
                value={i}
                onChange={(e) => {
                  setSpielt(false);
                  springen(Number(e.target.value));
                }}
                aria-label="Zeitpunkt"
              />
              <span className="mono wg-zaehler">
                {i + 1}/{anzahl}
              </span>
              {TEMPI.map((t) => (
                <button
                  key={t}
                  type="button"
                  className={`wg-wahl${tempo === t ? " wg-wahl-an" : ""}`}
                  onClick={() => setTempo(t)}
                  aria-label={`Tempo ${t} Bilder je Sekunde`}
                >
                  {t}×
                </button>
              ))}
            </div>

            {band ? (
              <div className="wg-band">
                <EChart option={band} onZeitKlick={aufBandKlick} />
                <div className="wg-bandbeschriftung mono">
                  <span className="text-text-3">kW</span>
                  <span style={{ color: C.pv }}>PV</span>
                  <span style={{ color: C.price }}>Netz</span>
                  <span style={{ color: C.heatPump }}>Wärmepumpe</span>
                  {bandBasis?.hatOfen ? <span style={{ color: C.stove }}>Pelletofen</span> : null}
                </div>
              </div>
            ) : null}
          </div>
        ) : null}
      </Card>

      {bild ? (
        <Card>
          <CardHead title="Was dieses Bild ist" />
          <p className="m-0 text-[13px] leading-[1.6] text-text-2">
            Dasselbe Schema wie unter <span className="mono">Wärme → Anlage</span>, nur aus der
            Minutenreihe nachgebaut. Es gibt genau eine Zusammensetzung des Bildes; die Wiedergabe
            stellt ihr die Eingänge von {uhr(bild.at)} hin, der Augenblick die von jetzt. Deshalb
            kann hier nichts stehen, was dort nicht stünde - und nichts fehlen, was dort steht.
          </p>
          <ul className="mt-2 mb-0 flex list-none flex-col gap-1.5 p-0 text-[13px] leading-[1.6] text-text-3">
            {(daten?.hinweise_de ?? []).map((h) => (
              <li key={h}>· {h}</li>
            ))}
          </ul>
          {!vollstaendig ? (
            <p className="mt-2 mb-0 text-[12px] leading-[1.5] text-text-3">
              Die fehlenden Bilder sind im Band als Lücke zu sehen: dort springt die Linie, statt
              durchzulaufen. Überbrückt wird nichts, denn ein ruhiges Haus und ein blindes
              Messsystem sähen im Schema gleich aus.
            </p>
          ) : null}
          <p className="mt-2 mb-0 text-[12px] leading-[1.5] text-text-3">
            Tastatur: Leertaste spielt und hält, Pfeile gehen Bild für Bild, Pos1 und Ende springen
            an die Ränder. Ein Klick ins Band springt zu dieser Uhrzeit. Bei{" "}
            {de(daten?.step_min ?? 5, 0)} Minuten Schritt und {tempo}× läuft der Tag in{" "}
            {de(anzahl / tempo, 0)} Sekunden durch.
          </p>
        </Card>
      ) : null}
    </div>
  );
}
