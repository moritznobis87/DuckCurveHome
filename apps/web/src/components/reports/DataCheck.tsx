"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { HistoryRow } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { EChart } from "@/components/charts/EChart";
import { powerOverlay } from "./charts";
import { ErrorBanner, Note, ReportShell, usePeriod } from "./ReportShell";

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

      <Card style={{ padding: 16, height: 480 }}>
        <CardHead
          title="Leistungen über den Tag"
          // Die Bedienhinweise stehen im Fließtext unter der Auswertung und nicht hier: auf einem
          // Telefon ist diese Zeile schon mit der Vorzeichenregel voll und wird abgeschnitten.
          right="Netz + Bezug, − Einspeisung · Speicher + Entladen, − Laden"
        />
        {rows.length > 0 ? (
          <div className="min-h-0 flex-1"><EChart option={overlay} /></div>
        ) : (
          <div className="flex flex-1 items-center justify-center">
            <Note>{loading ? "lädt …" : "Für diesen Tag liegen keine Minutenwerte vor. Seine Stundenbilanzen stammen dann aus dem Historienimport."}</Note>
          </div>
        )}
      </Card>

      <Card style={{ padding: 16 }}>
        <CardHead
          title="Stundenbilanz und auffällige Strecken"
          right={
            csv ? (
              <a href={csv} className="text-amber" download>
                Minutenwerte dieses Tages als CSV ›
              </a>
            ) : undefined
          }
        />
        {/* Bewusst als Text und nicht als gestaltete Tabelle: das ist dieselbe Ausgabe, die auch
            über die API kommt, Zeichen für Zeichen. Wer sie hier liest und dort abruft, vergleicht
            dasselbe - und kann sie unverändert weitergeben, wenn etwas zu klären ist. */}
        <pre className="mono m-0 mt-2 overflow-x-auto whitespace-pre text-[11px] leading-[1.5] text-text-2">
          {text || (loading ? "lädt …" : "Keine Diagnose verfügbar.")}
        </pre>
      </Card>

      <Note>
        Die obere Fläche zeigt die Messreihen, wie sie gespeichert sind, auf einer gemeinsamen
        kW-Achse mit hervorgehobener Nulllinie. Die Strecke, um die es geht, ist oft nur eine
        Viertelstunde lang; über den ganzen Tag gezeichnet sind das wenige Bildpunkte. Deshalb lässt
        sich ein Zeitfenster wählen: mit dem linken Werkzeug oben rechts ein Fenster aufziehen, mit
        dem Regler unter dem Diagramm eines über den Tag schieben, oder mit dem Mausrad und zwei
        Fingern dort zoomen, wo der Zeiger steht. Der Kreis daneben zeigt wieder den ganzen Tag. Die
        kW-Achse geht dabei mit, damit auch kleine Leistungen im Ausschnitt lesbar bleiben. Der Hausverbrauch ist dabei keine eigene Messung,
        sondern folgt aus der Bilanz Haus = PV + Netz + Speicher. Läuft die PV und zeigt das Netz
        trotzdem Bezug, sieht man hier unmittelbar, ob der Hausverbrauch über der Erzeugung lag oder
        ob die Erzeugungsreihe selbst eine Lücke hat. Der Text darunter nimmt diese zweite Frage noch
        einmal auf: zwischen der ersten und der letzten Minute mit Erzeugung zählt er die Minuten auf
        genau 0,00 kW und meldet es, wenn sich der Netzwert in derselben Strecke weiterbewegt. Dann
        liefert der Zähler, die Erzeugungsmessung aber nicht - und die ausgewiesene Netzladung ist
        eine Folge der Lücke, kein Verhalten des Speichers.
      </Note>
    </ReportShell>
  );
}
