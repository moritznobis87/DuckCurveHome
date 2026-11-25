"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { HistoryRow } from "@/lib/api/models";
import { Systemkarte } from "@/components/ui/Systemkarte";
import { EChart } from "@/components/charts/EChart";
import { CoverageMap } from "./CoverageMap";
import { Sources } from "./Sources";
import { powerOverlay } from "./charts";
import { ErrorBanner, Note, ReportShell, usePeriod } from "./ReportShell";
import { PRUEFSAETZE } from "./pruefsaetze";

/**
 * Prüfansicht: die Messreihen eines Tages so, wie sie in der Datenbank stehen.
 *
 * **Wozu.** Jede andere Seite zeigt Ergebnisse - Summen, Anteile, Kosten. Wenn eines davon nicht
 * stimmen kann, half bisher nur Nachfragen. Hier liegen Erzeugung, Hausverbrauch, Netz und Speicher
 * auf einer Achse übereinander, darunter dieselben Zahlen je Stunde, und daneben der Weg zu den
 * Rohdaten. Wer „der Speicher hat aus dem Netz geladen, obwohl die Sonne schien" prüfen will,
 * braucht genau diese drei Dinge und nichts weiter.
 */
function dayBounds(anchor: string): [Date, Date] {
  const start = new Date(`${anchor}T00:00:00`);
  return [start, new Date(start.getTime() + 86400000)];
}

export function DataCheck() {
  const { period, anchor, setPeriod, move, today } = usePeriod("day");
  const [rows, setRows] = useState<HistoryRow[]>([]);
  const [text, setText] = useState<string>("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!anchor) return;
    setLoading(true);
    const [start, end] = dayBounds(anchor);
    const [h, d] = await Promise.allSettled([api.historyDay(start, end), api.diagnoseDay(anchor)]);
    setRows(h.status === "fulfilled" ? (h.value.rows as HistoryRow[]) : []);
    setText(d.status === "fulfilled" ? d.value : "");
    setError(h.status === "rejected" && d.status === "rejected" ? "Daten konnten nicht geladen werden." : null);
    setLoading(false);
  }, [anchor]);

  useEffect(() => {
    void load();
  }, [load]);

  const overlay = useMemo(() => powerOverlay(rows), [rows]);
  // Ohne Anker keine Adresse. Sie aus `new Date()` zu bilden, ergäbe beim Vorrendern auf dem Server
  // eine andere Zeichenkette als im Browser, und React beanstandet die Abweichung beim Hydrieren.
  const csv = useMemo(() => {
    if (!anchor) return null;
    const [start, end] = dayBounds(anchor);
    return `/api/dch/export/minutes?start=${encodeURIComponent(start.toISOString())}&end=${encodeURIComponent(end.toISOString())}`;
  }, [anchor]);

  return (
    <ReportShell
      title="Daten prüfen"
      kicker="Messreihen · Stundenbilanz · Rohdaten"
      period={period}
      anchor={anchor}
      onPeriod={setPeriod}
      onMove={move}
      onToday={today}
      showPeriods={false}
    >
      {error ? <ErrorBanner message={error} /> : null}

      <div className="konto">
        <Systemkarte zeichen="chart" titel="Leistungen über den Tag" satz={PRUEFSAETZE.leistungen}>
          {rows.length > 0 ? (
            <div style={{ height: 400 }}>
              <EChart option={overlay} />
            </div>
          ) : (
            <Note>{loading ? "lädt …" : "Für diesen Tag liegen keine Minutenwerte vor. Seine Stundenbilanzen stammen dann aus dem Historienimport."}</Note>
          )}
        </Systemkarte>

        {/* Die Verfügbarkeit steht vor der Bilanz: eine Auswertung zu lesen, deren Datengrundlage
            Löcher hat, ist die falsche Reihenfolge. Und vor der Karte steht der Augenblick: sie
            zählt Stunden und sieht einen Ausfall erst nach einer. */}
        <Systemkarte zeichen="bolt" titel="Quellen" satz={PRUEFSAETZE.quellen}>
          <Sources />
        </Systemkarte>

        <CoverageMap anchor={anchor} />

        <Systemkarte zeichen="table" titel="Stundenbilanz und auffällige Strecken">
          {csv ? (
            <a href={csv} className="zugang-knopf zugang-knopf-klein self-start" download>
              Minutenwerte dieses Tages als CSV ›
            </a>
          ) : null}
          {/* Bewusst als Text und nicht als gestaltete Tabelle: das ist dieselbe Ausgabe, die auch
              über die API kommt, Zeichen für Zeichen. */}
          <pre className="mono m-0 overflow-x-auto whitespace-pre text-[11px] leading-[1.5] text-text-2">
            {text || (loading ? "lädt …" : "Keine Diagnose verfügbar.")}
          </pre>
        </Systemkarte>
      </div>
    </ReportShell>
  );
}
