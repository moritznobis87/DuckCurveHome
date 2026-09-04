import Link from "next/link";

export default function SettingsPage() {
  return (
    <main className="dashboard-bg flex min-h-[100dvh] flex-col gap-6 p-8 text-text-1">
      <Link href="/" className="kicker">← Zurück zum Dashboard</Link>
      <h1 className="m-0 text-[28px] font-semibold tracking-[-.02em]">Einstellungen</h1>
      <p className="max-w-[640px] text-[15px] leading-[1.6] text-text-2">
        Konfiguration, Overrides und Diagnose folgen in Phase 2/3. Im Demo-Modus lassen sich Zeitraffer und Störungen über
        die API steuern (<code className="mono">POST /api/v1/demo</code>), siehe CONFIGURATION.md.
      </p>
    </main>
  );
}
