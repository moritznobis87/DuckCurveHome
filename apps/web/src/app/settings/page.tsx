import Link from "next/link";
import { headers } from "next/headers";
import { requireOwner } from "@/lib/guard";
import { authRequired } from "@/lib/session";
import { active } from "@/lib/presence";

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

/** „vor 12 s“ statt einer Uhrzeit: hier zählt der Abstand zu jetzt, nicht der Zeitpunkt. */
function ago(ms: number): string {
  const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
  if (s < 60) return `vor ${s} s`;
  return `vor ${Math.round(s / 60)} min`;
}

/** Der Pairing-Link soll die Adresse tragen, unter der das Haus die Seite kennt – nicht die, über die
 *  dieser Aufruf zufällig hereinkam. Railway antwortet weiterhin unter *.up.railway.app; ein von dort
 *  kopierter Link führte Gäste an der eigenen Domain vorbei. Vorrang hat darum DCH_PUBLIC_HOST, dann
 *  ein echter Host aus der Anfrage (localhost bleibt für die Entwicklung erhalten), zuletzt die Domain. */
async function publicHost(): Promise<string> {
  const configured = process.env.DCH_PUBLIC_HOST?.trim();
  if (configured) return configured.replace(/^https?:\/\//, "").replace(/\/+$/, "");
  const host = (await headers()).get("host");
  if (host && !host.endsWith(".railway.app")) return host;
  return "home.duckcurve.de";
}

export default async function SettingsPage() {
  await requireOwner();
  const here = active();
  const base = `https://${await publicHost()}`;
  return (
    <main className="dashboard-bg flex min-h-[100dvh] flex-col gap-6 p-8 text-text-1">
      <Link href="/" className="kicker">← Zurück zum Dashboard</Link>
      <h1 className="m-0 text-[28px] font-semibold tracking-[-.02em]">Einstellungen</h1>

      <section className="flex max-w-[760px] flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Zugang einrichten</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Ein Gerät wird einmal über einen Link gepaart und behält danach seine Sitzung. Setze
          <code className="mono mx-1 text-[13px]">…</code> durch den jeweiligen Token aus den
          Umgebungsvariablen des Web-Dienstes. Die Adresse kommt aus
          <code className="mono mx-1 text-[13px]">DCH_PUBLIC_HOST</code> — so steht hier die eigene Domain,
          auch wenn du gerade über die Railway-Adresse hereingekommen bist.
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

      <section className="flex max-w-[760px] flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Gerade verbunden</h2>
        {here.length === 0 ? (
          <p className="m-0 text-[15px] text-text-3">Niemand in den letzten fünf Minuten.</p>
        ) : (
          <ul className="m-0 flex list-none flex-col gap-2 p-0">
            {here.map((p) => (
              <li key={`${p.role}:${p.name}:${p.agent}`} className="flex items-baseline justify-between gap-4 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3">
                <span className="flex items-baseline gap-3">
                  <span className="text-[15px] text-text-1">{p.name}</span>
                  <span className="mono text-[12px] uppercase tracking-[.1em]" style={{ color: p.role === "owner" ? "var(--amber)" : "var(--text-3)" }}>
                    {p.role === "owner" ? "Vollzugriff" : "Gast"}
                  </span>
                  <span className="text-[13px] text-text-3">{p.agent}</span>
                </span>
                <span className="mono text-[12px] text-text-3">{ago(p.lastSeen)}</span>
              </li>
            ))}
          </ul>
        )}
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Der Name stammt aus dem Pairing-Link (<code className="mono text-[13px]">&amp;name=…</code>); ohne Angabe
          heißt ein Gast schlicht „gast". Die Liste liegt nur im Arbeitsspeicher: nach einem Neustart des
          Web-Dienstes ist sie leer. Sie zeigt, wer zusieht — ein Zugriffsprotokoll ist sie nicht.
          Zum Aktualisieren die Seite neu laden.
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
