export function Pill({ children, tone = "neutral" }: { children: React.ReactNode; tone?: "neutral" | "amber" | "alert" }) {
  const styles = {
    neutral: { color: "var(--text-2)", background: "rgba(255,255,255,.06)", border: "1px solid var(--line-2)" },
    amber: { color: "var(--amber)", background: "rgba(242,169,0,.14)", border: "1px solid rgba(242,169,0,.35)" },
    alert: { color: "var(--alert)", background: "rgba(224,83,61,.14)", border: "1px solid rgba(224,83,61,.4)" },
  }[tone];
  return (
    <span className="mono inline-block rounded-[2px] px-[10px] py-[4px] text-[12px] uppercase tracking-[.08em] whitespace-nowrap" style={styles}>
      {children}
    </span>
  );
}
