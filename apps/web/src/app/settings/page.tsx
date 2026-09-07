import Link from "next/link";
import { headers } from "next/headers";
import { requireOwner } from "@/lib/guard";
import { authRequired } from "@/lib/session";

export const dynamic = "force-dynamic";
export const metadata = { title: "Einstellungen · Duck Curve Home" };

function Row({ label, url, note }: { label: string; url: string; note: string }) {
  return (
    <div className="flex flex-col gap-1.5 rounded-[3px] border border-line-1 bg-surface-2 p-4">
      <span className="kicker" style={{ fontSize: 11 }}>{label}</span>
      <code className="mono break-all text-[14px] text-text-1">{url}</code>
      <span className="text-[13px] leading-[1.5] text-text-3">{note}</span>
    </div>
  );
}

export default async function SettingsPage() {
  await requireOwner();
  const host = (await headers()).get("host") ?? "home.duckcurve.de";
  const base = `https://${host}`;
  return (
    <main className="dashboard-bg flex min-h-[100dvh] flex-col gap-6 p-8 text-text-1">
      <Link href="/" className="kicker">← Zurück zum Dashboard</Link>
      <h1 className="m-0 text-[28px] font-semibold tracking-[-.02em]">Einstellungen</h1>

      <section className="flex max-w-[760px] flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Zugang einrichten</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Ein Gerät wird einmal über einen Link gepaart und behält danach seine Sitzung. Setze
          <code className="mono mx-1 text-[13px]">…</code> durch den jeweiligen Token aus den
          Umgebungsvariablen des Web-Dienstes.
        </p>
        <Row
          label="Vollzugriff (Hausherr, Wandanzeige)"
          url={`${base}/pair?token=<DCH_KIOSK_TOKEN>&name=iPad-Flur`}
          note="Darf schalten, sieht Kosten und Rechnungen. Die Sitzung hält ein halbes Jahr; `name` erscheint nur im Protokoll."
        />
        <Row
          label="Gast (nur ansehen)"
          url={`${base}/pair?token=<DCH_GUEST_TOKEN>&hours=8`}
          note="Sieht alles inklusive Kosten, die Schaltkacheln bleiben sichtbar, bewirken aber nichts. Tibber-Rechnungen sind gesperrt. Ohne `hours` gilt DCH_GUEST_HOURS (Vorgabe 24), höchstens 720."
        />
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Der Ablauf begrenzt die <em>Sitzung</em>, nicht den Link: Wer ihn aufhebt, kann sich erneut paaren.
          Um das zu unterbinden, <code className="mono text-[13px]">DCH_GUEST_TOKEN</code> ändern — bestehende
          Gast-Sitzungen laufen dann regulär ab, neue entstehen nicht mehr.
          {!authRequired() ? " Achtung: DCH_SESSION_SECRET ist nicht gesetzt, die Anmeldung ist derzeit deaktiviert." : ""}
        </p>
      </section>

      <section className="flex max-w-[760px] flex-col gap-2">
        <h2 className="m-0 text-[18px] font-semibold">Sichtbarkeit</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Die Seite ist für Suchmaschinen gesperrt — über <code className="mono text-[13px]">robots.txt</code>, den
          <code className="mono mx-1 text-[13px]">noindex</code>-Meta-Tag und den Header
          <code className="mono mx-1 text-[13px]">X-Robots-Tag</code>. Ein Schutz vor unbefugtem Zugriff ist das
          nicht; dafür sorgt die Anmeldung.
        </p>
      </section>

      <section className="flex max-w-[760px] flex-col gap-2">
        <h2 className="m-0 text-[18px] font-semibold">Konfiguration</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Regelparameter, Aktoren und Grenzwerte stehen in <code className="mono text-[13px]">CONFIGURATION.md</code> und
          im Entity-Mapping, das die Bridge beim Start aus dem Repository lädt.
        </p>
      </section>
    </main>
  );
}
