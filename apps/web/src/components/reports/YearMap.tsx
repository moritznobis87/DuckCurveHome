"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { api, ApiError } from "@/lib/api/client";
import type { YearMap as YearMapData } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { EChart } from "@/components/charts/EChart";
import { RAMP_GRID, RAMP_HEAT, RAMP_NET, RAMP_OWN, yearMap } from "./charts";
import { de1, ErrorBanner, Note } from "./ReportShell";

/** Die Kennzahlen der Karte. Farbzuordnung wie im Energiefluss: Bernstein für eigene Energie,
 *  Mist für das Netz, Terrakotta für die Wärmepumpe. Wer den Energiefluss gelesen hat, liest die
 *  Karte ohne Umlernen. */
const METRICS = [
  { key: "grid_net_kwh", label: "Netz", unit: "kWh", ramp: RAMP_NET, diverging: true, hint: "Bezug (hell blau) gegen Einspeisung (bernstein) - die Entenkurve über ein ganzes Jahr" },
  { key: "pv_kwh", label: "Erzeugung", unit: "kWh", ramp: RAMP_OWN, hint: "Wann die Anlage lieferte: Tageslänge und Wetter, Tag für Tag" },
  { key: "house_kwh", label: "Verbrauch", unit: "kWh", ramp: RAMP_GRID, hint: "Der Rhythmus des Hauses - Wochentage, Urlaube, Gewohnheiten" },
  { key: "heat_pump_kwh", label: "Wärmepumpe", unit: "kWh", ramp: RAMP_HEAT, hint: "Heizperiode, Warmwasserspitzen und die Taktung der Regelung" },
  { key: "import_kwh", label: "Netzbezug", unit: "kWh", ramp: RAMP_GRID, hint: "Nur der Bezug, ohne Verrechnung mit der Einspeisung" },
  { key: "export_kwh", label: "Einspeisung", unit: "kWh", ramp: RAMP_OWN, hint: "Überschuss, der ins Netz ging" },
  { key: "price_ct_kwh", label: "Strompreis", unit: "ct/kWh", ramp: RAMP_GRID, digits: 1, hint: "Der bezugsgewichtete Preis je Stunde - die Struktur, gegen die geplant wird" },
  { key: "autarky", label: "Autarkie", unit: "", ramp: RAMP_OWN, digits: 2, hint: "Anteil des Verbrauchs, der nicht aus dem Netz kam (0-1)" },
] as const;

type MetricKey = (typeof METRICS)[number]["key"];

function describe(e: unknown): string {
  if (e instanceof ApiError) return e.status === 401 || e.status === 403 ? "Nicht angemeldet - bitte Gerät koppeln." : e.message;
  return "Daten konnten nicht geladen werden.";
}

export function YearMapReport() {
  const thisYear = new Date().getFullYear();
  const [year, setYear] = useState(thisYear);
  const [metric, setMetric] = useState<MetricKey>("grid_net_kwh");
  const [data, setData] = useState<YearMapData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    api
      .energyYearMap(year)
      .then((d) => {
        if (!alive) return;
        setData(d);
        setError(null);
      })
      .catch((e) => alive && setError(describe(e)))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [year]);

  const active = METRICS.find((m) => m.key === metric) ?? METRICS[0];
  const grid = useMemo(() => (data?.metrics as Record<string, Array<Array<number | null>>> | undefined)?.[metric] ?? [], [data, metric]);
  const option = useMemo(
    () => yearMap(data?.days ?? [], grid, { unit: active.unit, ramp: [...active.ramp], diverging: "diverging" in active ? active.diverging : false, digits: "digits" in active ? active.digits : 2 }),
    [data, grid, active],
  );
  const extremes = useMemo(() => {
    const flat = grid.flat().filter((v): v is number => typeof v === "number");
    if (!flat.length) return null;
    return { min: Math.min(...flat), max: Math.max(...flat) };
  }, [grid]);

  const years = Array.from({ length: 4 }, (_, i) => thisYear - i);

  return (
    <main className="dashboard-bg report-main flex min-h-[100dvh] flex-col gap-4 p-5 text-text-1">
      <header className="report-header flex h-14 shrink-0 items-center justify-between rounded-[3px] border border-line-2 px-5" style={{ background: "var(--surface-glass)", backdropFilter: "blur(18px)" }}>
        <div className="flex min-w-0 items-center gap-5">
          <Link href="/" className="kicker whitespace-nowrap" style={{ fontSize: 12 }}>← Dashboard</Link>
          <div className="flex min-w-0 items-baseline gap-2.5">
            <span className="whitespace-nowrap text-[17px] font-semibold tracking-[-.02em]">Jahreskarte</span>
            <span className="kicker truncate" style={{ fontSize: 12 }}>365 Tage × 24 Stunden</span>
          </div>
        </div>
        <div className="flex shrink-0 items-center gap-1 rounded-[3px] border border-line-2 p-1" role="tablist" aria-label="Jahr">
          {years.map((y) => (
            <button key={y} onClick={() => setYear(y)} className="mono px-3 py-1.5 text-[12px]" style={{ background: year === y ? "var(--amber)" : "transparent", color: year === y ? "var(--petrol)" : "var(--text-2)", borderRadius: 2 }}>
              {y}
            </button>
          ))}
        </div>
      </header>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="flex flex-wrap gap-1.5" role="tablist" aria-label="Kennzahl">
        {METRICS.map((m) => (
          <button
            key={m.key}
            onClick={() => setMetric(m.key)}
            aria-pressed={metric === m.key}
            className="rounded-[3px] border px-3 py-1.5 text-[13px]"
            style={{
              borderColor: metric === m.key ? "var(--amber)" : "var(--line-2)",
              color: metric === m.key ? "var(--amber)" : "var(--text-2)",
              background: metric === m.key ? "rgba(242,169,0,.10)" : "transparent",
            }}
          >
            {m.label}
          </button>
        ))}
      </div>

      {/* Feste Höhe, keine Flex-Höhe: `height: 100%` im Chart löst sich sonst gegen eine unbestimmte
          Elternhöhe auf und die Karte fällt auf eine Linie zusammen. */}
      <Card style={{ padding: 16, height: "clamp(360px, calc(100dvh - 250px), 780px)" }}>
        <CardHead title={active.label} right={active.unit || undefined} />
        <div className="min-h-0 flex-1">
          {loading && !data ? <Note>Jahr wird geladen …</Note> : data && data.hours_with_data === 0 ? <Note>Für {year} liegen keine Stundenwerte vor.</Note> : <EChart option={option} />}
        </div>
      </Card>

      <Note>
        {active.hint}
        {". "}
        Jede Zelle ist eine Stunde in Ortszeit; leere Zellen sind Lücken in der Aufzeichnung, keine
        Nullwerte.
        {data ? ` ${de1(data.hours_with_data, 0)} von ${de1(data.days.length * 24, 0)} Stunden erfasst.` : ""}
        {extremes ? ` Werteumfang ${de1(extremes.min, 2)} bis ${de1(extremes.max, 2)} ${active.unit}; die Farbskala endet beim 98. Perzentil, damit einzelne Ausreißer nicht das ganze Jahr einfärben.` : ""}
      </Note>
    </main>
  );
}
