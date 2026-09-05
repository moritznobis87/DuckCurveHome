import { Card } from "@/components/ui/Card";

/** Kennzahl-Kachel: Kicker, große Zahl, Einheit, optional eine Zeile Kontext. */
export function Stat({ label, value, unit, hint, tone }: { label: string; value: string; unit?: string; hint?: string; tone?: "amber" | "ember" | "mist" | "muted" }) {
  const color = tone === "amber" ? "var(--amber)" : tone === "ember" ? "var(--alert)" : tone === "mist" ? "var(--mist)" : tone === "muted" ? "var(--text-3)" : "var(--text-1)";
  return (
    <Card style={{ padding: "14px 18px", gap: 6 }}>
      <span className="kicker" style={{ fontSize: 11 }}>{label}</span>
      <span className="mono text-[26px] leading-none tracking-[-.02em]" style={{ color }}>
        {value}
        {unit ? <span className="ml-1.5 text-[13px] text-text-3" style={{ fontFamily: "var(--font-sans)" }}>{unit}</span> : null}
      </span>
      {hint ? <span className="truncate text-[12px] text-text-3">{hint}</span> : null}
    </Card>
  );
}
