import { requireOwner } from "@/lib/guard";
import { anmeldungNoetig } from "@/lib/anmeldungAktiv";
import { active } from "@/lib/presence";
import { zustand } from "@/lib/zugang";
import { StorageReport } from "@/components/settings/StorageReport";
import { AreaShell } from "@/components/layout/AreaShell";
import { MeinZugang } from "@/components/zugang/MeinZugang";
import { Personen } from "@/components/zugang/Personen";

export const dynamic = "force-dynamic";
export const metadata = { title: "Zugang und Sicherung · Duck Curve Home" };

/** „vor 12 s“ statt einer Uhrzeit: hier zählt der Abstand zu jetzt, nicht der Zeitpunkt. */
function ago(ms: number): string {
  const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
  if (s < 60) return `vor ${s} s`;
  return `vor ${Math.round(s / 60)} min`;
}

export default async function Page() {
  await requireOwner(); // doppelt zum Layout: hier stehen die Zugänge zum Haus
  const stand = await zustand();
  const here = active();
  const year = new Date().getFullYear();
  return (
    <AreaShell kicker="wer Zugang hat · wer zusieht · Daten sichern">

      <Personen versand={{ aktiv: stand.versand.aktiv, fehlt: stand.versand.fehlt }} />

      <section className="flex max-w-[760px] flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Mein Zugang</h2>
        <MeinZugang />
      </section>

      <section className="flex max-w-[760px] flex-col gap-2">
        <h2 className="m-0 text-[18px] font-semibold">Wie man hereinkommt</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Nur als Person, nur mit Passkey. Es gibt <strong>keinen Link mehr, der Zugang vergibt</strong>:
          bis zum 23.11.2026 standen hier zwei Adressen mit einem stehenden Token darin, die jeder
          einlösen konnte, der sie je gesehen hatte, und die sich nur für alle zugleich widerrufen
          ließen. Was es stattdessen gibt, ist der Einladungslink oben. Er gilt einmal, ist befristet und gehört zu genau einer Person.
        </p>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Eine Person darf an beliebig vielen Geräten zugleich angemeldet sein: je Gerät ein
          Passkey und eine eigene Sitzung, einzeln zu beenden. Auch das Gerät an der Wand bekommt
          deshalb eine eigene Person. Gib ihr einen Namen, dem man ansieht, dass kein Mensch
          dahintersteht („Wandanzeige Flur"), und die Rolle, die sie wirklich braucht.
        </p>
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          {!anmeldungNoetig()
            ? "Achtung: Es wird derzeit keine Anmeldung verlangt, denn DCH_ANMELDUNG steht auf „aus\". "
            : ""}
          {!stand.anmeldung
            ? "Achtung: Der Dienst läuft ohne Datenbank (Demo-Modus); Personen lassen sich damit nicht anlegen."
            : ""}
        </p>
      </section>

      <section className="flex max-w-[760px] flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Gerade verbunden</h2>
        {here.length === 0 ? (
          <p className="m-0 text-[15px] text-text-3">Niemand in den letzten fünf Minuten.</p>
        ) : (
          <ul className="m-0 flex list-none flex-col gap-2 p-0">
            {here.map((p) => (
              <li key={`${p.rolle}:${p.name}:${p.agent}`} className="flex items-baseline justify-between gap-4 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3">
                <span className="flex items-baseline gap-3">
                  <span className="text-[15px] text-text-1">{p.name}</span>
                  <span className="mono text-[12px] uppercase tracking-[.1em]" style={{ color: p.rolle === "hausherr" ? "var(--amber)" : "var(--text-3)" }}>
                    {p.rolle}
                  </span>
                  <span className="text-[13px] text-text-3">{p.agent}</span>
                </span>
                <span className="mono text-[12px] text-text-3">{ago(p.lastSeen)}</span>
              </li>
            ))}
          </ul>
        )}
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Der Name stammt aus dem Zugang der Person. Die Liste liegt nur im Arbeitsspeicher: nach einem Neustart des
          Web-Dienstes ist sie leer. Sie zeigt, wer zusieht. Ein Zugriffsprotokoll ist sie nicht.
          Zum Aktualisieren die Seite neu laden.
        </p>
      </section>

      <section className="flex max-w-[760px] flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Platzbedarf</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Eine verwaltete Datenbank wird nach Arbeitsspeicher abgerechnet, und den belegt sie im
          Wesentlichen mit ihrer eigenen Größe. Welche Tabelle das ist, lässt sich nicht erraten:
          bei schmalen Zeilen sind die Indizes regelmäßig größer als die Daten.
        </p>
        <StorageReport />
      </section>

      <section className="flex max-w-[760px] flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Sicherung</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Die Datenbank ist die einzige Kopie. Ein verwaltetes Volume bei einem Anbieter ist kein
          Archiv: es überlebt keinen gelöschten Zugang und keinen Anbieterwechsel. Einmal im Jahr
          herunterladen und woanders ablegen. Die Dateien sind gzip-komprimiertes CSV und lassen
          sich ohne dieses Programm lesen.
        </p>
        <div className="flex flex-col gap-2">
          {[year, year - 1].map((y) => (
            <div key={y} className="flex flex-wrap items-baseline gap-x-4 gap-y-1 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3">
              <span className="mono text-[14px] text-text-1">{y}</span>
              <a className="text-[14px] text-amber" href={`/api/dch/export/minutes?year=${y}`}>
                Minutenwerte ↓
              </a>
              <a className="text-[14px] text-amber" href={`/api/dch/export/hours?year=${y}`}>
                Stundenbilanz ↓
              </a>
              <span className="text-[13px] text-text-3">
                Minutenwerte eines vollen Jahres: rund 20 MB gepackt
              </span>
            </div>
          ))}
        </div>
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Die Stundenbilanz enthält auch die Grundlagen der PV-Abrechnung, also Eigenverbrauch,
          Wiederbeschaffungswert und Umsatzsteuer. Sie gehört zu den Unterlagen, die aufzubewahren
          sind. Ein laufendes Jahr ist naturgemäß unvollständig; für den Abschluss im Januar erneut
          holen.
        </p>
      </section>

      <section className="flex max-w-[760px] flex-col gap-2">
        <h2 className="m-0 text-[18px] font-semibold">Sichtbarkeit</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Die Seite ist für Suchmaschinen gesperrt, und zwar über <code className="mono text-[13px]">robots.txt</code>, den
          <code className="mono mx-1 text-[13px]">noindex</code>-Meta-Tag und den Header
          <code className="mono mx-1 text-[13px]">X-Robots-Tag</code>. Ein Schutz vor unbefugtem Zugriff ist das
          nicht; dafür sorgt die Anmeldung.
        </p>
      </section>

      <section className="flex max-w-[760px] flex-col gap-2">
        <h2 className="m-0 text-[18px] font-semibold">Konfiguration</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Regelparameter, Aktoren und Grenzwerte stehen in <code className="mono text-[13px]">CONFIGURATION.md</code> und
          im Entity-Mapping, das die Bridge beim Start aus dem Repository lädt. Die Annahmen der
          Wärmerechnung stehen unter <a href="/waerme/annahmen" className="text-amber">Wärme › Annahmen</a>.
        </p>
      </section>
    </AreaShell>
  );
}
