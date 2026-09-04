export function Dot({ tone, pulse = false }: { tone: "ok" | "warn" | "alert" | "muted"; pulse?: boolean }) {
  const color = { ok: "var(--amber)", warn: "var(--mist)", alert: "var(--alert)", muted: "var(--text-3)" }[tone];
  return <span aria-hidden className="inline-block h-2 w-2 rounded-full" style={{ background: color, animation: pulse ? "dch-pulse 2.4s ease-in-out infinite" : undefined }} />;
}
