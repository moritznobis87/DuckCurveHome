export default function LockedPage() {
  return (
    <main className="dashboard-bg flex min-h-[100dvh] flex-col items-center justify-center gap-4 p-8 text-center text-text-1">
      <div className="kicker">Duck Curve Home</div>
      <h1 className="m-0 text-[28px] font-semibold tracking-[-.02em]">Dieses Gerät ist nicht gekoppelt.</h1>
      <p className="max-w-[520px] text-[15px] leading-[1.6] text-text-2">
        Öffne auf diesem Gerät den Pairing-Link aus den Einstellungen von Duck Curve Home
        (<code className="mono">/pair?token=…&amp;name=iPad</code>). Danach bleibt das Gerät 180 Tage angemeldet.
      </p>
    </main>
  );
}
