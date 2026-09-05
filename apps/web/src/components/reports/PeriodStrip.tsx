import type { Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { ALL_PERIODS } from "./useReport";

const STRIP_LABEL: Record<Period, string> = { day: "Heute", week: "Woche", month: "Monat", year: "Jahr" };

export type StripRow = { label: string; value: (p: Period) => string; tone?: "amber" | "ember" | "mist" };
const TONE: Record<NonNullable<StripRow["tone"]>, string> = { amber: "var(--amber)", ember: "var(--alert)", mist: "var(--mist)" };

/** Kennzahlen als Tabelle: Zeilen = Größen, Spalten = heute · Woche · Monat · Jahr (immer bis jetzt). */
export function PeriodStrip({ title, rows, right }: { title: string; rows: StripRow[]; right?: string }) {
  return (
    <Card style={{ padding: "14px 18px", gap: 10 }}>
      <CardHead title={title} right={right ?? "jeweils bis jetzt"} />
      <table className="w-full border-collapse text-[12px]" style={{ tableLayout: "fixed" }}>
        <thead>
          <tr className="kicker" style={{ fontSize: 10 }}>
            <th className="w-[34%] pb-1.5 text-left font-medium" />
            {ALL_PERIODS.map((p) => (
              <th key={p} className="pb-1.5 text-right font-medium">{STRIP_LABEL[p]}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={r.label} className="border-t border-line-1">
              <td className="truncate py-2 pr-2 text-text-3">{r.label}</td>
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
