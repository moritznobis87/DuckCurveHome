"use client";

import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { Coverage, CoverageSeries } from "@/lib/api/models";
import { C } from "@/components/charts/palette";
import { Card, CardHead } from "@/components/ui/Card";
import { EChart } from "@/components/charts/EChart";
import { yearMap } from "./charts";
import { Note } from "./ReportShell";

/**
 * Verfügbarkeit der beiden Netzmessungen als Karte aus Tagen und Stunden.
 *
 * **Warum eine Karte und keine Kurve.** Die Frage ist nicht „wie hoch war die Leistung", sondern
 * „kam überhaupt etwas an". In einer Leistungskurve ist das kaum zu sehen: eine Lücke sieht aus wie
 * eine Null, und eine Null sieht aus wie eine Nacht ohne Verbrauch. Als Fläche aus Tagen und
 * Stunden wird ein Muster daraus. Eine Verbindung, die jede Nacht abreißt, ist ein waagerechter
 * Streifen; eine, die alle paar Tage für zwei Stunden wegbleibt, ein Fleck.
 *
 * **Die Farbe ist absichtlich herum.** Vollständig ist ruhig, fehlend ist rot. Eine Karte ohne
 * Lücken soll langweilig aussehen, damit die eine Lücke, die es gibt, ins Auge springt.
 *
 * **Leer ist nicht null.** Eine Zelle ohne Farbe heißt, dass für diese Stunde überhaupt keine
 * Minutenzeile existiert - dann stand der Dienst still, und das ist unser Ausfall, nicht der des
 * Geräts. Eine rote Zelle heißt, dass Minutenzeilen da sind und diese eine Reihe darin fehlt. Der
 * Unterschied entscheidet, wen man anschaut.
 */
const HOURS = 24;
// Von rot über sandfarben zu ruhigem Blaugrau. Die Zwischenstufe muss es geben: eine Stunde mit 55
// von 60 Minuten ist etwas anderes als eine mit 5.
const RAMP = [C.alert, "#c2a86b", C.battery];

function grid(series: CoverageSeries, days: string[]): Array<Array<number | null>> {
  const byHour = new Map(series.hours.map(([iso, n]) => [iso.slice(0, 13), n]));
  return days.map((day) =>
    Array.from({ length: HOURS }, (_, h) => {
      const key = `${day}T${String(h).padStart(2, "0")}`;
      const v = byHour.get(key);
      return v === undefined ? null : v;
    }),
  );
}

function daysBetween(startIso: string, endIso: string): string[] {
  const out: string[] = [];
  const d = new Date(startIso);
  const end = new Date(endIso);
  while (d < end) {
    out.push(d.toISOString().slice(0, 10));
    d.setUTCDate(d.getUTCDate() + 1);
  }
  return out;
}

function ageOf(iso: string | null | undefined): string {
  if (!iso) return "noch kein Wert";
  const s = Math.max(0, Math.round((Date.now() - new Date(iso).getTime()) / 1000));
  if (s < 5) return "letzter Wert gerade eben";
  if (s < 120) return `letzter Wert vor ${s} s`;
  if (s < 7200) return `letzter Wert vor ${Math.round(s / 60)} min`;
  return `letzter Wert vor ${Math.round(s / 3600)} h`;
}

function Headline({ s }: { s: CoverageSeries }) {
  const pct = (s.coverage * 100).toFixed(s.coverage > 0.999 ? 2 : 1);
  const bad = s.coverage < 0.99;
  return (
    <div className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
      <span className="text-[14px] text-text-1">{s.label_de}</span>
      <span className="mono text-[13px]" style={{ color: bad ? "var(--alert)" : "var(--amber)" }}>
        {pct} % Abdeckung
      </span>
      <span className="text-[13px] text-text-3">
        {s.incomplete_hours} unvollständige Stunden
        {s.longest_outage_h > 0 ? ` · längster Ausfall ${s.longest_outage_h} h` : ""}
        {` · ${ageOf(s.last_at)}`}
      </span>
    </div>
  );
}

export function CoverageMap({ anchor, days = 28 }: { anchor: string; days?: number }) {
  const [data, setData] = useState<Coverage | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!anchor) return;
    let alive = true;
    api
      .coverage(anchor, days)
      .then((d) => alive && setData(d))
      .catch(() => alive && setError("Die Verfügbarkeit konnte nicht abgefragt werden."));
    return () => {
      alive = false;
    };
  }, [anchor, days]);

  const dayList = useMemo(() => (data ? daysBetween(data.start, data.end) : []), [data]);

  if (error) return <Note>{error}</Note>;
  if (!data) return <Note>lädt …</Note>;

  return (
    <Card style={{ padding: 16 }}>
      <CardHead title={`Kommen die Daten an? ${days} Tage`} right="Farbe = Minuten je Stunde, 0 bis 60" />
      <div className="mt-2 flex flex-col gap-4">
        {data.series.map((s) => (
          <div key={s.key} className="flex flex-col gap-1">
            <Headline s={s} />
            <div style={{ height: 240 }}>
              <EChart
                option={yearMap(dayList, grid(s, dayList), {
                  unit: "min",
                  ramp: RAMP,
                  digits: 0,
                  max: 60,
                  xLabel: "day",
                })}
              />
            </div>
          </div>
        ))}
      </div>
      <Note>
        {data.note_de} Eine Zelle ohne Farbe heißt, dass für diese Stunde gar keine Minutenzeile
        existiert - dann stand der Dienst still, und der Ausfall ist unserer. Eine rote Zelle heißt,
        dass Minutenzeilen da sind und diese eine Reihe darin fehlt: dann hat das Gerät nichts
        geliefert.
      </Note>
    </Card>
  );
}
