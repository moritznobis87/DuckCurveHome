"use client";

import { useState } from "react";
import type { Period } from "@/lib/api/models";
import { useIsMobile } from "@/lib/useIsMobile";
import { Card, CardHead } from "@/components/ui/Card";
import { ALL_PERIODS, isoToday } from "./useReport";

const STRIP_LABEL: Record<Period, string> = { day: "Heute", week: "Woche", month: "Monat", year: "Jahr" };

/** Spaltenkopf der Tagesspalte: „Heute" nur, wenn der Ankertag auch heute ist. */
function dayLabel(anchor: string | undefined, todayIso: string): string {
  if (!anchor || anchor === todayIso) return STRIP_LABEL.day;
  const d = new Date(`${anchor}T00:00:00`);
  return d.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" });
}

export type StripRow = { label: string; value: (p: Period) => string; tone?: "amber" | "ember" | "mist" };
const TONE: Record<NonNullable<StripRow["tone"]>, string> = { amber: "var(--amber)", ember: "var(--alert)", mist: "var(--mist)" };

/**
 * Kennzahlen als Tabelle: Zeilen = Größen, Spalten = Tag · Woche · Monat · Jahr **des Ankertags**.
 *
 * Die Spalten folgen der Navigation. Blättert man auf einen vergangenen Tag, zeigen sie dessen
 * Woche, Monat und Jahr - nicht mehr die laufenden. Der Kopf sagt, worauf sie sich beziehen, und die
 * Tagesspalte heißt nur dann „Heute", wenn sie es auch ist.
 *
 * **Am Handy eine Spalte.** Vier Zahlenspalten neben dem Namen der Zeile passen nicht auf 390
 * Punkte: die Namen wurden abgeschnitten, die Zahlen liefen ineinander. Dort steht deshalb ein
 * Umschalter über der Liste, und die Liste zeigt eine Spanne in lesbarer Größe.
 */
export function PeriodStrip({ title, rows, right, anchor }: { title: string; rows: StripRow[]; right?: string; anchor?: string }) {
  const todayIso = isoToday();
  const bis =
    right ??
    (!anchor || anchor === todayIso
      ? "jeweils bis jetzt"
      : `jeweils bis ${new Date(`${anchor}T00:00:00`).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "numeric" })}`);
  const handy = useIsMobile();
  const [spanne, setSpanne] = useState<Period>("day");
  const kopf = (p: Period) => (p === "day" ? dayLabel(anchor, todayIso) : STRIP_LABEL[p]);
  if (handy) {
    return (
      <Card style={{ gap: 12 }}>
        <CardHead title={title} right={bis} />
        <div className="spannen" role="tablist" aria-label="Spanne">
          {ALL_PERIODS.map((p) => (
            <button key={p} role="tab" aria-selected={p === spanne} className={`spanne${p === spanne ? " spanne-an" : ""}`} onClick={() => setSpanne(p)}>
              {kopf(p)}
            </button>
          ))}
        </div>
        <dl className="spannen-liste">
          {rows.map((r, i) => (
            <div key={r.label} className="spannen-zeile">
              <dt>{r.label}</dt>
              <dd className="mono" style={{ fontWeight: i === 0 ? 600 : 400, color: r.tone ? TONE[r.tone] : "var(--text-1)" }}>
                {r.value(spanne)}
              </dd>
            </div>
          ))}
        </dl>
      </Card>
    );
  }
  return (
    <Card style={{ padding: "14px 18px", gap: 10 }}>
      <CardHead title={title} right={bis} />
      <table className="w-full border-collapse text-[12px]" style={{ tableLayout: "fixed" }}>
        <thead>
          <tr className="kicker" style={{ fontSize: 10 }}>
            <th className="w-[34%] pb-1.5 text-left font-medium" />
            {ALL_PERIODS.map((p) => (
              <th key={p} className="pb-1.5 text-right font-medium">{kopf(p)}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={r.label} className="border-t border-line-1">
              {/* Am Handy bricht der Name um, statt abgeschnitten zu werden: sonst fehlt die Einheit. */}
              <td className="truncate py-2 pr-2 text-text-3 max-[720px]:whitespace-normal">{r.label}</td>
              {ALL_PERIODS.map((p) => (
                <td key={p} className="mono whitespace-nowrap py-2 pl-1 text-right" style={{ fontSize: 12, fontWeight: i === 0 ? 600 : 400, color: r.tone ? TONE[r.tone] : "var(--text-1)" }}>
                  {r.value(p)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  );
}
