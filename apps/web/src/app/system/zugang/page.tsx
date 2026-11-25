import { requireOwner } from "@/lib/guard";
import { anmeldungNoetig } from "@/lib/anmeldungAktiv";
import { active } from "@/lib/presence";
import { zustand } from "@/lib/zugang";
import { StorageReport } from "@/components/settings/StorageReport";
import { AreaShell } from "@/components/layout/AreaShell";
import { Icon } from "@/components/ui/Icon";
import { Personen } from "@/components/zugang/Personen";
import { ROLLE } from "@/components/zugang/kontoworte";
import { Zugangskarte } from "@/components/zugang/Zugangskarte";

export const dynamic = "force-dynamic";
export const metadata = { title: "Zugang und Sicherung · Duck Curve Home" };

/** „vor 12 s“ statt einer Uhrzeit: hier zählt der Abstand zu jetzt, nicht der Zeitpunkt. */
function ago(ms: number): string {
  const s = Math.max(0, Math.round((Date.now() - ms) / 1000));
  if (s < 60) return `vor ${s} s`;
  return `vor ${Math.round(s / 60)} min`;
}

/**
 * Zugang und Sicherung: wer hereindarf, wer gerade zusieht, wie groß die Datenbank ist und wie man
 * sie sichert. Vier Karten wie auf „Mein Zugang“.
 *
 * **Ohne Erklärtexte.** Der Hausherr hat am 25.11.2026 entschieden: „der Text muss weg“. Bis dahin
 * standen hier sieben Abschnitte mit langen Absätzen, darunter die Geschichte der alten
 * Kopplungslinks, Sichtbarkeit für Suchmaschinen und wo die Konfiguration liegt. Geblieben ist je
 * Karte ein Satz und, wenn nötig, eine Warnung zum Zustand des Dienstes. Dieselben Karten zeigt
 * die App (`ZugangSeite.swift`).
 */
export default async function Page() {
  await requireOwner(); // doppelt zum Layout: hier stehen die Zugänge zum Haus
  const stand = await zustand();
  const here = active();
  const year = new Date().getFullYear();
  const warnungen = [
    !anmeldungNoetig() ? "Es wird derzeit keine Anmeldung verlangt, denn DCH_ANMELDUNG steht auf „aus“." : "",
    !stand.anmeldung ? "Der Dienst läuft ohne Datenbank; Personen lassen sich damit nicht anlegen." : "",
  ].filter(Boolean);
  return (
    <AreaShell kicker="wer Zugang hat · wer zusieht · Daten sichern">
      <div className="konto max-w-[820px]">
        {warnungen.map((w) => (
          <p key={w} className="zugang-warnung" role="status">
            <Icon name="alert" size={18} />
            <span>{w}</span>
          </p>
        ))}

        <Personen versand={{ aktiv: stand.versand.aktiv, fehlt: stand.versand.fehlt }} />

        <Zugangskarte art="verbunden">
          {here.length === 0 ? (
            <p className="konto-leise">Niemand in den letzten fünf Minuten.</p>
          ) : (
            <ul className="konto-liste">
              {here.map((p) => (
                <li key={`${p.rolle}:${p.name}:${p.agent}`} className="konto-zeile">
                  <span className="konto-zeile-zeichen" aria-hidden="true">
                    <Icon name="device" size={17} />
                  </span>
                  <div className="konto-zeile-text">
                    <span className="konto-zeile-name">
                      {p.name}
                      <span className="konto-marke konto-marke-hier">{ROLLE[p.rolle]?.name ?? p.rolle}</span>
                    </span>
                    <span className="konto-zeile-dazu">
                      {p.agent} · {ago(p.lastSeen)}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Zugangskarte>

        <Zugangskarte art="platz">
          <StorageReport />
        </Zugangskarte>

        <Zugangskarte art="sicherung">
          <ul className="konto-liste">
            {[year, year - 1].map((y) => (
              <li key={y} className="konto-zeile">
                <span className="konto-zeile-zeichen" aria-hidden="true">
                  <Icon name="calendar" size={17} />
                </span>
                <div className="konto-zeile-text">
                  <span className="konto-zeile-name mono">{y}</span>
                  <span className="konto-zeile-dazu">gzip-komprimiertes CSV, Minutenwerte rund 20 MB im Jahr</span>
                </div>
                <span className="konto-zeile-tun">
                  <a className="zugang-knopf zugang-knopf-klein" href={`/api/dch/export/minutes?year=${y}`}>
                    Minutenwerte ↓
                  </a>
                  <a className="zugang-knopf zugang-knopf-klein" href={`/api/dch/export/hours?year=${y}`}>
                    Stundenbilanz ↓
                  </a>
                </span>
              </li>
            ))}
          </ul>
        </Zugangskarte>
      </div>
    </AreaShell>
  );
}
