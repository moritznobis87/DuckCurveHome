"use client";

import { useState } from "react";
import { Software } from "@/components/update/Software";
import type { Ampel, ApiSelbst, Geraet as GeraetDaten, GeraetDienst, GeraetProtokoll, GeraetRechner } from "@/lib/api/models";
import { DIENSTNAMEN } from "./namen";
import { beschaeftigt, holeProtokoll, useGeraet, type Handgriff } from "./useGeraet";
import { Verlauf, bytesText } from "./Verlauf";

/**
 * Technik → Hausgerät: wie es dem Gerät und seinen Diensten geht, und die wenigen Handgriffe, die
 * es aus der Ferne braucht. Auf dem Gerät selbst gibt es für den Hausherrn keinen Zugang; diese
 * Seite ersetzt `dch status`, `dch logs` und `dch neustart`.
 *
 * Bewertet wird in der API (routers/geraet.py): Ampel und Satz kommen fertig, damit Browser und
 * iOS-App dasselbe sagen.
 */

export { DIENSTNAMEN } from "./namen";

const EINHEITEN: Record<string, string> = {
  "duckcurve.service": "Start beim Einschalten",
  "duckcurve-anfrage.path": "Anfragen aus der App",
  "duckcurve-zustand.timer": "Gesundheitsbericht (jede Minute)",
  "duckcurve-pruefen.timer": "Nach Updates sehen (alle 6 Stunden)",
  "duckcurve-sicherung.timer": "Nächtliche Sicherung",
  "duckcurve-kiosk.service": "Anzeige am Bildschirm",
};

const HANDGRIFFE: Record<string, string> = {
  neustart: "Neustart",
  sichern: "Sicherung",
  protokoll: "Protokoll",
  geraet_neustart: "Gerät neu starten",
  zustand: "Bericht erneuern",
};

function farbe(a: Ampel): string {
  return { gut: "var(--mist)", warn: "var(--amber-soft)", schlecht: "var(--alert)", aus: "var(--text-3)" }[a];
}

export function Punkt({ ampel, gross = false }: { ampel: Ampel; gross?: boolean }) {
  const s = gross ? 12 : 9;
  return (
    <span
      aria-label={{ gut: "in Ordnung", warn: "Hinweis", schlecht: "Störung", aus: "keine Angabe" }[ampel]}
      role="img"
      className="inline-block shrink-0 rounded-full"
      style={{ width: s, height: s, background: farbe(ampel), marginTop: gross ? 6 : 6 }}
    />
  );
}

export function dauer(sekunden: number): string {
  const s = Math.max(0, Math.round(sekunden));
  const t = Math.floor(s / 86_400);
  const h = Math.floor((s % 86_400) / 3_600);
  const m = Math.floor((s % 3_600) / 60);
  if (t > 0) return `${t} T ${h} h`;
  if (h > 0) return `${h} h ${m} min`;
  if (m > 0) return `${m} min`;
  return `${s} s`;
}

function seit(iso: string | null | undefined): string {
  if (!iso) return "–";
  const ms = new Date(iso).getTime();
  return Number.isNaN(ms) ? "–" : dauer((Date.now() - ms) / 1000);
}

function uhr(iso: string | null | undefined): string {
  if (!iso) return "–";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "–";
  const heute = d.toDateString() === new Date().toDateString();
  return heute
    ? d.toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" })
    : d.toLocaleString("de-DE", { dateStyle: "short", timeStyle: "short" });
}

function gb(bytes: number): string {
  return `${(bytes / 1e9).toLocaleString("de-DE", { maximumFractionDigits: bytes > 1e11 ? 0 : 1 })} GB`;
}

function groesse(bytes: number): string {
  if (bytes < 1e6) return `${Math.max(1, Math.round(bytes / 1e3))} kB`;
  return `${(bytes / 1e6).toLocaleString("de-DE", { maximumFractionDigits: 1 })} MB`;
}

function Karte({ children }: { children: React.ReactNode }) {
  return <div className="flex flex-col gap-2 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3">{children}</div>;
}

function Zeile({ ampel, titel, text, rechts }: { ampel?: Ampel; titel: string; text?: string; rechts?: React.ReactNode }) {
  return (
    <div className="flex items-start gap-3 text-[14px]">
      {ampel ? <Punkt ampel={ampel} /> : <span className="w-[9px] shrink-0" />}
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="text-text-1">{titel}</span>
        {text ? <span className="text-[13px] leading-[1.45] text-text-3">{text}</span> : null}
      </span>
      {rechts ? <span className="mono shrink-0 text-right text-[13px] text-text-2">{rechts}</span> : null}
    </div>
  );
}

/** Eine Rückfrage an Ort und Stelle; „Abbrechen“ ist vorausgewählt. */
function Rueckfrage({ frage, ja, onJa, onNein }: { frage: string; ja: string; onJa: () => void; onNein: () => void }) {
  return (
    <div className="flex flex-col gap-2 rounded-[3px] border border-amber px-3 py-2" role="alertdialog" aria-label={ja}>
      <span className="text-[14px] leading-[1.5] text-text-2">{frage}</span>
      <span className="flex gap-2">
        <button type="button" autoFocus className="rounded-[8px] border border-line-2 px-3 py-1.5 text-[14px]" onClick={onNein}>
          Abbrechen
        </button>
        <button type="button" className="rounded-[8px] bg-amber px-3 py-1.5 text-[14px] font-semibold text-deep" onClick={onJa}>
          {ja}
        </button>
      </span>
    </div>
  );
}

const KNOPF = "rounded-[8px] border border-line-2 px-3 py-1.5 text-[13px] text-text-1 disabled:opacity-40";

function DienstZeile({
  d,
  gesperrt,
  onNeustart,
  onProtokoll,
}: {
  d: GeraetDienst;
  gesperrt: boolean;
  onNeustart: () => void;
  onProtokoll: () => void;
}) {
  const [offen, setOffen] = useState(false);
  const [frage, setFrage] = useState(false);
  const laeuft = d.zustand === "running";
  return (
    <div className="flex flex-col gap-2 border-t border-line-1 py-3 first:border-t-0 first:pt-0 last:pb-0">
      <button type="button" className="flex items-start gap-3 text-left" onClick={() => setOffen((o) => !o)} aria-expanded={offen}>
        <Punkt ampel={d.ampel} />
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="text-[15px] text-text-1">
            {DIENSTNAMEN[d.name] ?? d.name} <span className="mono text-[12px] text-text-3">{d.name}</span>
          </span>
          <span className="text-[13px] leading-[1.45] text-text-3">{d.text_de}</span>
        </span>
        <span className="mono hidden shrink-0 flex-col items-end text-[12px] text-text-2 sm:flex">
          {laeuft ? <span>seit {seit(d.gestartet_am)}</span> : null}
          {d.cpu_prozent != null || d.speicher_mb != null ? (
            <span className="text-text-3">
              {d.cpu_prozent != null ? `${d.cpu_prozent.toLocaleString("de-DE", { maximumFractionDigits: 1 })} % CPU` : ""}
              {d.speicher_mb != null ? ` · ${Math.round(d.speicher_mb)} MB` : ""}
            </span>
          ) : null}
        </span>
      </button>
      {offen ? (
        <div className="ml-[21px] flex flex-col gap-2 text-[13px] text-text-2">
          <dl className="m-0 grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1">
            {laeuft ? (
              <>
                <dt className="text-text-3">Läuft seit</dt>
                <dd className="m-0">{seit(d.gestartet_am)}</dd>
              </>
            ) : null}
            <dt className="text-text-3">Fassung</dt>
            <dd className="mono m-0 break-all">{d.revision ?? d.image ?? "–"}</dd>
            {d.neustarts ? (
              <>
                <dt className="text-text-3">Von selbst neu gestartet</dt>
                <dd className="m-0">{d.neustarts}-mal</dd>
              </>
            ) : null}
            {d.pruefung ? (
              <>
                <dt className="text-text-3">Letzte Prüfung</dt>
                <dd className="mono m-0 whitespace-pre-wrap break-all text-[12px]">{d.pruefung}</dd>
              </>
            ) : null}
          </dl>
          {frage ? (
            <Rueckfrage
              frage={
                d.name === "postgres"
                  ? "Die Datenbank startet neu; API und Oberfläche verlieren kurz die Verbindung."
                  : d.name === "web"
                    ? "Die Oberfläche ist einige Sekunden nicht erreichbar; diese Seite lädt danach weiter."
                    : `${DIENSTNAMEN[d.name] ?? d.name} startet neu und ist einige Sekunden nicht erreichbar.`
              }
              ja="Neu starten"
              onNein={() => setFrage(false)}
              onJa={() => {
                setFrage(false);
                onNeustart();
              }}
            />
          ) : (
            <span className="flex flex-wrap gap-2">
              <button type="button" className={KNOPF} disabled={gesperrt} onClick={() => setFrage(true)}>
                Neu starten
              </button>
              <button type="button" className={KNOPF} disabled={gesperrt} onClick={onProtokoll}>
                Protokoll ansehen
              </button>
            </span>
          )}
        </div>
      ) : null}
    </div>
  );
}

function ApiKarte({ api }: { api: ApiSelbst }) {
  return (
    <Karte>
      <Zeile ampel={api.ampel} titel={api.text_de} />
      <Zeile
        ampel={api.datenbank_ok === false ? "schlecht" : api.datenbank_ok ? "gut" : "aus"}
        titel="Datenbank"
        text={api.datenbank_de}
      />
      {(api.quellen ?? []).map((q) => (
        <Zeile
          key={q.name}
          ampel={q.online ? "gut" : q.detail_de?.startsWith("nicht eingerichtet") ? "aus" : "warn"}
          titel={q.name}
          text={[q.detail_de, q.last_ok ? `zuletzt ${uhr(q.last_ok)}` : ""].filter(Boolean).join(" · ")}
        />
      ))}
      {(api.befunde ?? []).map((b) => (
        <Zeile key={b.name} ampel={b.severity === "alarm" ? "schlecht" : "warn"} titel={b.title_de} text={b.text_de} />
      ))}
      <Zeile
        titel="Alfred"
        ampel={api.alfred_eingerichtet ? "gut" : "aus"}
        text={api.alfred_eingerichtet ? "Sprachmodell eingerichtet." : "Kein Schlüssel für das Sprachmodell hinterlegt."}
      />
      <span className="mono text-[12px] text-text-3">
        Fassung {api.version} · {api.commit} · läuft seit {dauer(api.laufzeit_s)} · {Math.round(api.rss_mb)} MB · {api.sse_clients} offene
        Ansicht(en)
      </span>
    </Karte>
  );
}

function RechnerKarte({ r }: { r: GeraetRechner }) {
  const belegt = r.speicher_gesamt_mb - r.speicher_frei_mb;
  return (
    <Karte>
      <Zeile titel={r.modell ?? r.name} text={[r.system, r.kernel ? `Kernel ${r.kernel}` : null, r.docker ? `Docker ${r.docker}` : null].filter(Boolean).join(" · ")} />
      <Zeile titel="Läuft seit" rechts={dauer(r.laufzeit_s)} text={r.adresse ? `Adresse im Heimnetz: ${r.adresse}` : undefined} />
      <Zeile
        titel="Auslastung"
        text={`Mittlere Last über 1, 5 und 15 Minuten bei ${r.kerne} Kernen`}
        rechts={(r.last ?? []).map((l) => l.toLocaleString("de-DE", { maximumFractionDigits: 2 })).join(" · ")}
      />
      {r.temperatur_c != null ? (
        <Zeile
          ampel={r.temperatur_ampel}
          titel="Temperatur"
          text={r.temperatur_ampel === "gut" ? undefined : "Ab 80 °C drosselt sich der Rechner selbst."}
          rechts={`${r.temperatur_c.toLocaleString("de-DE", { maximumFractionDigits: 1 })} °C`}
        />
      ) : null}
      {r.drosselung != null ? (
        <Zeile
          ampel={r.drosselung_ampel}
          titel="Stromversorgung und Takt"
          text={r.drosselung_de?.length ? r.drosselung_de.join(" ") : "Keine Unterspannung, keine Drosselung seit dem Start."}
        />
      ) : null}
      {r.speicher_gesamt_mb ? (
        <Zeile
          ampel={r.speicher_ampel}
          titel="Arbeitsspeicher"
          rechts={`${(belegt / 1024).toLocaleString("de-DE", { maximumFractionDigits: 1 })} von ${(r.speicher_gesamt_mb / 1024).toLocaleString("de-DE", { maximumFractionDigits: 1 })} GB`}
        />
      ) : null}
      {(r.platten ?? []).map((p) => (
        <Zeile key={p.ort} ampel={p.ampel} titel={p.ort === "/" ? "SSD" : p.ort} rechts={`${gb(p.frei_bytes)} frei von ${gb(p.gesamt_bytes)}`} />
      ))}
      {r.cpu_prozent != null ? (
        <Zeile
          titel="CPU-Auslastung"
          text={r.takt_mhz ? `Takt gerade ${Math.round(r.takt_mhz)} MHz` : undefined}
          rechts={`${r.cpu_prozent.toLocaleString("de-DE", { maximumFractionDigits: 1 })} %`}
        />
      ) : null}
      {r.eingangsspannung_v != null ? (
        <Zeile
          ampel={r.spannung_ampel}
          titel="Eingangsspannung"
          text="Spannung am Netzteil- oder PoE-Eingang des Raspberry Pi"
          rechts={`${r.eingangsspannung_v.toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} V`}
        />
      ) : null}
      {r.swap_gesamt_mb ? (
        <Zeile titel="Auslagerung (Swap)" rechts={`${r.swap_gesamt_mb - (r.swap_frei_mb ?? 0)} von ${r.swap_gesamt_mb} MB`} />
      ) : null}
      {r.netz ? (
        <Zeile
          titel={`Netzwerk (${r.netz.schnittstelle})`}
          text="seit dem Start des Geräts"
          rechts={`↓ ${bytesText(r.netz.empfangen_bytes)} · ↑ ${bytesText(r.netz.gesendet_bytes)}`}
        />
      ) : null}
    </Karte>
  );
}

function SsdKarte({ s }: { s: NonNullable<GeraetRechner["ssd"]> }) {
  const stunden = s.betriebsstunden;
  return (
    <Karte>
      <Zeile ampel={s.ampel} titel={s.text_de} text={[s.modell, `/dev/${s.geraet}`].filter(Boolean).join(" · ")} />
      {s.abnutzung_prozent != null ? (
        <Zeile
          titel="Abnutzung"
          text={s.reserve_prozent != null ? `Reserve-Blöcke: ${s.reserve_prozent} %` : "verbrauchte Lebensdauer laut Hersteller"}
          rechts={`${s.abnutzung_prozent} %`}
        />
      ) : null}
      {s.temperatur_c != null ? <Zeile titel="Temperatur" rechts={`${s.temperatur_c} °C`} /> : null}
      {stunden != null ? (
        <Zeile titel="Betriebsstunden" rechts={`${stunden.toLocaleString("de-DE")} h (${(stunden / 8760).toLocaleString("de-DE", { maximumFractionDigits: 1 })} Jahre)`} />
      ) : null}
      {s.geschrieben_bytes != null ? (
        <Zeile titel="Geschrieben / gelesen" text="seit Herstellung" rechts={`${bytesText(s.geschrieben_bytes)} / ${bytesText(s.gelesen_bytes)}`} />
      ) : null}
      {s.fehler != null ? <Zeile ampel={s.fehler ? "warn" : "gut"} titel="Lesefehler" rechts={String(s.fehler)} /> : null}
      {s.unsichere_abschaltungen != null ? (
        <Zeile titel="Unsaubere Abschaltungen" text="Strom weg, ohne herunterzufahren" rechts={String(s.unsichere_abschaltungen)} />
      ) : null}
    </Karte>
  );
}

/** Wofür der Platz auf der SSD draufgeht, als ein Balken mit Abschnitten. */
export function platzAbschnitte(g: GeraetDaten): { name: string; bytes: number; farbe: string }[] | null {
  const p = g.rechner?.platten?.find((x) => x.ort === "/");
  if (!p) return null;
  const d = g.rechner?.docker_platz;
  const belegt = p.gesamt_bytes - p.frei_bytes;
  const programme = (d?.images_bytes ?? 0) + (d?.container_bytes ?? 0) + (d?.cache_bytes ?? 0);
  const daten = d?.volumes_bytes ?? 0;
  const sicherungen = g.sicherung?.gesamt_bytes ?? 0;
  const rest = Math.max(0, belegt - programme - daten - sicherungen);
  return [
    { name: "Programme (Docker-Images, Cache)", bytes: programme, farbe: "#2f89b5" },
    { name: "Daten (Datenbank und Volumes)", bytes: daten, farbe: "#f2a900" },
    { name: "Sicherungen", bytes: sicherungen, farbe: "#cfd8dc" },
    { name: "System und Sonstiges", bytes: rest, farbe: "rgba(255,255,255,.28)" },
    { name: "frei", bytes: p.frei_bytes, farbe: "transparent" },
  ];
}

function PlatzKarte({ g }: { g: GeraetDaten }) {
  const teile = platzAbschnitte(g);
  if (!teile) return null;
  const summe = teile.reduce((a, t) => a + t.bytes, 0) || 1;
  return (
    <Karte>
      <div className="flex h-[14px] w-full gap-[2px] overflow-hidden rounded-[4px] bg-surface-3" role="img" aria-label="Aufteilung der SSD">
        {teile
          .filter((t) => t.bytes > 0 && t.farbe !== "transparent")
          .map((t) => (
            <span key={t.name} style={{ width: `${(t.bytes / summe) * 100}%`, background: t.farbe, minWidth: 2 }} />
          ))}
      </div>
      <ul className="m-0 flex list-none flex-col gap-1 p-0 text-[13px]">
        {teile.map((t) => (
          <li key={t.name} className="flex items-center gap-2">
            <span
              className="inline-block h-[10px] w-[10px] shrink-0 rounded-[2px]"
              style={{ background: t.farbe, border: t.farbe === "transparent" ? "1px solid var(--line-2)" : undefined }}
            />
            <span className="flex-1 text-text-2">{t.name}</span>
            <span className="mono text-text-1">{bytesText(t.bytes)}</span>
            <span className="mono w-[44px] text-right text-text-3">{Math.round((t.bytes / summe) * 100)} %</span>
          </li>
        ))}
      </ul>
      {g.api.datenbank_bytes != null ? (
        <span className="text-[12px] text-text-3">Davon die Datenbank selbst: {bytesText(g.api.datenbank_bytes)}.</span>
      ) : null}
    </Karte>
  );
}

function ProtokollFenster({ titel, inhalt, onZu, onNeu }: { titel: string; inhalt: GeraetProtokoll | string | null; onZu: () => void; onNeu: () => void }) {
  return (
    <div className="flex flex-col gap-2 rounded-[3px] border border-line-2 bg-surface-1 p-3" role="region" aria-label={`Protokoll ${titel}`}>
      <span className="flex items-center justify-between gap-2">
        <span className="text-[15px] font-semibold">Protokoll: {titel}</span>
        <span className="flex gap-2">
          <button type="button" className={KNOPF} onClick={onNeu} disabled={inhalt === null}>
            Neu holen
          </button>
          <button type="button" className={KNOPF} onClick={onZu}>
            Schließen
          </button>
        </span>
      </span>
      {inhalt === null ? (
        <span className="text-[14px] text-text-3">Das Gerät holt die letzten 300 Zeilen …</span>
      ) : typeof inhalt === "string" ? (
        <span className="text-[14px] text-alert-text">{inhalt}</span>
      ) : (
        <>
          <span className="text-[12px] text-text-3">
            Geholt um {uhr(inhalt.erstellt_am)} · {inhalt.zeilen?.length ?? 0} Zeilen · Schlüssel und Passwörter sind durch *** ersetzt
          </span>
          <pre className="mono m-0 max-h-[420px] overflow-auto whitespace-pre-wrap break-all rounded-[3px] bg-deep p-3 text-[11.5px] leading-[1.5] text-text-2">
            {inhalt.zeilen?.length ? inhalt.zeilen.join("\n") : "(leer)"}
          </pre>
        </>
      )}
    </div>
  );
}

function aktionText(g: GeraetDaten): { text: string; ton: "laeuft" | "ok" | "fehler" } | null {
  const a = g.letzte_aktion;
  if (!a) return null;
  const was = `${HANDGRIFFE[a.aktion] ?? a.aktion}${a.dienst ? ` ${a.dienst === "alle" ? "aller Dienste" : (DIENSTNAMEN[a.dienst] ?? a.dienst)}` : ""}`;
  if (a.zustand === "laeuft") return { text: `${was} läuft …`, ton: "laeuft" };
  return {
    text: `${was}, ${uhr(a.beendet_am)}: ${a.meldung || (a.zustand === "ok" ? "erledigt." : "fehlgeschlagen.")}`,
    ton: a.zustand === "ok" ? "ok" : "fehler",
  };
}

export function Geraet() {
  const { geraet: g, unerreichbar, fehler, anfragen } = useGeraet();
  const [protokoll, setProtokoll] = useState<{ dienst: string; inhalt: GeraetProtokoll | string | null } | null>(null);
  const [frage, setFrage] = useState<"alle" | "geraet" | null>(null);

  if (g === null) {
    return <p className="m-0 text-[15px] text-text-3">{unerreichbar ? "Der Dienst antwortet gerade nicht …" : "Lade …"}</p>;
  }
  const gesperrt = beschaeftigt(g) || !g.unterstuetzt;
  const aktion = aktionText(g);

  const zeigeProtokoll = async (dienst: string) => {
    setProtokoll({ dienst, inhalt: null });
    const inhalt = await holeProtokoll(dienst, anfragen);
    setProtokoll((p) => (p?.dienst === dienst ? { dienst, inhalt } : p));
  };
  const handgriff = (a: Handgriff, dienst?: string) => void anfragen(a, dienst);

  return (
    <div className="flex max-w-[860px] flex-col gap-6">
      <div className="flex items-start gap-3 rounded-[3px] border border-line-2 px-4 py-3" aria-live="polite">
        <Punkt ampel={g.ampel} gross />
        <span className="flex flex-col gap-0.5">
          <span className="text-[16px] font-semibold">{g.ampel === "gut" ? "Alles in Ordnung." : g.text_de}</span>
          <span className="text-[13px] text-text-3">
            {unerreichbar
              ? "Gerade keine Verbindung. Vielleicht startet die API neu; die Seite versucht es weiter."
              : g.unterstuetzt
                ? `Bericht des Geräts von ${uhr(g.bericht_am)}${g.bericht_alt ? ". Er ist veraltet, weil der Zeitgeber auf dem Gerät nicht läuft" : ""}.`
                : "Diese Installation läuft nicht auf dem Hausgerät; hier steht nur, was die API über sich selbst weiß."}
          </span>
        </span>
      </div>

      {aktion || fehler ? (
        <p className={`m-0 text-[14px] ${fehler || aktion?.ton === "fehler" ? "text-alert-text" : "text-text-2"}`} aria-live="polite">
          {fehler ?? aktion?.text}
        </p>
      ) : null}

      {protokoll ? (
        <ProtokollFenster
          titel={DIENSTNAMEN[protokoll.dienst] ?? protokoll.dienst}
          inhalt={protokoll.inhalt}
          onZu={() => setProtokoll(null)}
          onNeu={() => void zeigeProtokoll(protokoll.dienst)}
        />
      ) : null}

      {g.unterstuetzt ? (
        <section className="flex flex-col gap-3">
          <h2 className="m-0 text-[18px] font-semibold">Dienste</h2>
          <Karte>
            {g.dienste?.length ? (
              g.dienste.map((d) => (
                <DienstZeile
                  key={d.name}
                  d={d}
                  gesperrt={gesperrt}
                  onNeustart={() => handgriff("neustart", d.name)}
                  onProtokoll={() => void zeigeProtokoll(d.name)}
                />
              ))
            ) : (
              <span className="text-[14px] text-text-3">Noch kein Bericht über die Dienste.</span>
            )}
          </Karte>
          <span className="text-[13px] text-text-3">Antippen zeigt Fassung, die letzte Prüfung und die Handgriffe.</span>
        </section>
      ) : null}

      <section className="flex flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Rechenkern</h2>
        <ApiKarte api={g.api} />
      </section>

      {g.rechner ? (
        <section className="flex flex-col gap-3">
          <h2 className="m-0 text-[18px] font-semibold">Gerät</h2>
          <RechnerKarte r={g.rechner} />
        </section>
      ) : null}

      {g.rechner?.ssd ? (
        <section className="flex flex-col gap-3">
          <h2 className="m-0 text-[18px] font-semibold">SSD-Gesundheit</h2>
          <SsdKarte s={g.rechner.ssd} />
        </section>
      ) : null}

      {g.rechner?.platten?.some((p) => p.ort === "/") ? (
        <section className="flex flex-col gap-3">
          <h2 className="m-0 text-[18px] font-semibold">Platz auf der SSD</h2>
          <PlatzKarte g={g} />
        </section>
      ) : null}

      {g.unterstuetzt ? <Verlauf /> : null}

      {g.sicherung ? (
        <section className="flex flex-col gap-3">
          <h2 className="m-0 text-[18px] font-semibold">Sicherung</h2>
          <Karte>
            <Zeile ampel={g.sicherung.ampel} titel={g.sicherung.text_de} />
            {g.sicherung.letzte ? (
              <Zeile
                titel="Letzte Sicherung"
                text={g.sicherung.letzte}
                rechts={`${uhr(g.sicherung.letzte_am)}${g.sicherung.letzte_bytes ? ` · ${groesse(g.sicherung.letzte_bytes)}` : ""}`}
              />
            ) : null}
            <Zeile titel="Kopie außer Haus" text={g.sicherung.ausser_haus ?? "keine (DCH_SICHERUNG_ZIEL in .env)"} />
            <span>
              <button type="button" className={KNOPF} disabled={gesperrt} onClick={() => handgriff("sichern")}>
                Jetzt sichern
              </button>
            </span>
          </Karte>
        </section>
      ) : null}

      {g.einheiten?.length ? (
        <section className="flex flex-col gap-3">
          <h2 className="m-0 text-[18px] font-semibold">Abläufe auf dem Gerät</h2>
          <Karte>
            {(g.einheiten ?? []).map((e) => (
              <Zeile
                key={e.name}
                ampel={e.ampel}
                titel={EINHEITEN[e.name] ?? e.beschreibung ?? e.name}
                text={`${e.text_de}${e.naechster_lauf ? ` Nächster Lauf ${uhr(e.naechster_lauf)}.` : ""}`}
              />
            ))}
          </Karte>
        </section>
      ) : null}

      <section id="software" className="flex flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Software</h2>
        <Software />
      </section>

      {g.unterstuetzt ? (
        <section className="flex flex-col gap-3">
          <h2 className="m-0 text-[18px] font-semibold">Neu starten</h2>
          {frage === "alle" ? (
            <Rueckfrage
              frage="Alle Dienste starten nacheinander neu. Duck Curve regelt etwa eine Minute nicht; die Anlage läuft in dieser Zeit wie ohne Duck Curve."
              ja="Alle neu starten"
              onNein={() => setFrage(null)}
              onJa={() => {
                setFrage(null);
                handgriff("neustart", "alle");
              }}
            />
          ) : frage === "geraet" ? (
            <Rueckfrage
              frage="Das ganze Gerät startet neu. Es ist ein bis zwei Minuten nicht erreichbar und kommt von selbst wieder. Nur nötig, wenn ein Neustart der Dienste nicht hilft."
              ja="Gerät neu starten"
              onNein={() => setFrage(null)}
              onJa={() => {
                setFrage(null);
                handgriff("geraet_neustart");
              }}
            />
          ) : (
            <span className="flex flex-wrap gap-2">
              <button type="button" className={KNOPF} disabled={gesperrt} onClick={() => setFrage("alle")}>
                Alle Dienste neu starten
              </button>
              <button type="button" className={KNOPF} disabled={gesperrt} onClick={() => setFrage("geraet")}>
                Gerät neu starten
              </button>
            </span>
          )}
        </section>
      ) : null}
    </div>
  );
}
