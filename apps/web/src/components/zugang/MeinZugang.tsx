"use client";

import {
  browserSupportsWebAuthn,
  startRegistration,
  type PublicKeyCredentialCreationOptionsJSON,
} from "@simplewebauthn/browser";
import { useCallback, useEffect, useState } from "react";

import { abmelden } from "@/app/anmeldung/aktionen";
import { Icon } from "@/components/ui/Icon";
import { api, ApiError } from "@/lib/api/client";
import type { Ich } from "@/lib/api/models";
import { BestaetigKnopf } from "./BestaetigKnopf";
import { ROLLE, loeschfrage } from "./kontoworte";
import { Zugangskarte } from "./Zugangskarte";
import { MeinPasswort } from "./MeinPasswort";

/**
 * Der eigene Zugang: Passkeys anlegen, umbenennen und löschen, das Passwort vergeben oder
 * wechseln, Sitzungen beenden, neue Codes holen.
 *
 * **Ein Weg herein muss bleiben.** Der letzte Passkey lässt sich nur löschen, wenn die Person ein
 * Passwort hat, und das Passwort nur entfernen, solange ein Passkey da ist. Sonst käme sie nur
 * noch über einen Wiederherstellungscode oder einen Link des Hausherrn herein - der Dienst lehnt
 * das ab, und diese Seite sagt es vorher.
 *
 * Für einen Dienst mit dem API-Token erscheint der Abschnitt gar nicht: er ist keine Person und
 * hat weder Passkeys noch ein Passwort.
 *
 * **Das Bild** (seit dem 24.11.2026, auf Wunsch des Hausherrn): oben eine Kopfkarte mit dem
 * Anfangsbuchstaben, der Rolle als Marke und drei Zahlen; darunter je eine Karte für Passkeys,
 * Passwort und Sitzungen, jede mit ihrem Zeichen wie die Kacheln der Übersichten. Dieselben Worte
 * stehen in der App (`Kontoworte.swift`).
 */

function datum(wert: string | null | undefined): string {
  if (!wert) return "nie";
  return new Date(wert).toLocaleString("de-DE", { dateStyle: "short", timeStyle: "short" });
}

/**
 * Aus dem User-Agent ein Wort machen, an dem man das Gerät wiedererkennt.
 *
 * Der rohe Wert ist eine Zeile wie „Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 …" und
 * sagt in einer Liste nichts; abgelegt wird er trotzdem ganz, damit man im Zweifel nachsehen
 * kann. Dieselbe Verkürzung wie in `lib/presence.ts`.
 */
function geraet(ua: string): string {
  if (!ua) return "unbekanntes Gerät";
  if (/iPad/i.test(ua)) return "iPad";
  if (/iPhone/i.test(ua)) return "iPhone";
  if (/Android/i.test(ua)) return "Android";
  if (/Macintosh/i.test(ua)) return "Mac";
  if (/Windows/i.test(ua)) return "Windows";
  if (/Linux/i.test(ua)) return "Linux";
  return "unbekanntes Gerät";
}

export function MeinZugang({ mindestlaenge }: { mindestlaenge: number }) {
  const [ich, setIch] = useState<Ich | null>();
  const [fehler, setFehler] = useState<string>();
  const [codes, setCodes] = useState<string[]>();
  const [laeuft, setLaeuft] = useState(false);
  const [neuerName, setNeuerName] = useState("");
  /** Welcher Passkey gerade umbenannt wird, und auf was. */
  const [umbenennen, setUmbenennen] = useState<{ id: string; name: string }>();

  const laden = useCallback(() => {
    void api
      .ich()
      .then(setIch)
      .catch(() => setIch(null)); // keine Person angemeldet: keine eigene Seite
  }, []);

  useEffect(laden, [laden]);

  /** Führt eine Änderung aus und lädt neu. Sagt zurück, ob sie gelungen ist. */
  async function fuehre(was: () => Promise<unknown>): Promise<boolean> {
    setFehler(undefined);
    setLaeuft(true);
    try {
      await was();
      laden();
      return true;
    } catch (e) {
      setFehler(e instanceof ApiError ? e.message : "Das hat nicht geklappt.");
      return false;
    } finally {
      setLaeuft(false);
    }
  }

  async function passkeyAnlegen() {
    setFehler(undefined);
    if (!browserSupportsWebAuthn()) {
      setFehler("Dieser Browser kann keine Passkeys.");
      return;
    }
    await fuehre(async () => {
      const z = await api.passkeyBeginnen();
      const antwort = await startRegistration({
        optionsJSON: JSON.parse(z.optionen) as PublicKeyCredentialCreationOptionsJSON,
      });
      await api.passkeyAbschliessen(z.schritt, antwort, neuerName.trim());
      setNeuerName("");
    });
  }

  if (ich === undefined) return <p className="m-0 text-[15px] text-text-3">Lade…</p>;
  if (ich === null) {
    return (
      <p className="m-0 text-[15px] leading-[1.6] text-text-3">
        Hier ist keine Person angemeldet. Darum gibt es an dieser Stelle weder eigene Passkeys
        noch ein eigenes Passwort. Wer einen eigenen Zugang möchte, lässt sich vom Hausherrn einladen.
      </p>
    );
  }

  // Die erzeugten Typen machen Listen mit Vorgabewert optional; hier sind sie immer da.
  const meine = ich.passkeys ?? [];
  const sitzungen = ich.sitzungen ?? [];
  const hatPasswort = ich.passwort ?? false;
  // Ohne Passwort bleibt der letzte Passkey, denn sonst gäbe es keinen Weg herein.
  const letzterBleibt = meine.length <= 1 && !hatPasswort;

  const rolle = ROLLE[ich.ausweis.rolle] ?? { name: ich.ausweis.rolle, satz: "" };
  const name = ich.ausweis.name || ich.ausweis.email || "";

  return (
    <div className="konto">
      <section className="konto-kopf" aria-label="Angemeldet">
        <div className="konto-person">
          <span className="konto-anfang" aria-hidden="true">{name.trim().charAt(0).toLocaleUpperCase("de-DE") || "?"}</span>
          <div className="min-w-0">
            <p className="konto-name">{name}</p>
            {ich.ausweis.email && ich.ausweis.email !== name ? <p className="konto-adresse">{ich.ausweis.email}</p> : null}
            <p className="konto-rolle">
              <span className="konto-marke">{rolle.name}</span>
              <span>{rolle.satz}</span>
            </p>
          </div>
        </div>
        <dl className="konto-zahlen">
          <div><dt>Passkeys</dt><dd>{meine.length}</dd></div>
          <div><dt>Sitzungen</dt><dd>{sitzungen.length}</dd></div>
          <div><dt>Codes übrig</dt><dd>{ich.codes_offen}</dd></div>
        </dl>
      </section>
      {fehler ? <p className="konto-fehler" role="alert">{fehler}</p> : null}

      <Zugangskarte art="passkeys">
        {meine.length > 0 ? (
          <ul className="konto-liste">
            {meine.map((p) => (
              <li key={p.id} className="konto-zeile">
                <span className="konto-zeile-zeichen" aria-hidden="true">
                  <Icon name="key" size={17} />
                </span>
                <div className="konto-zeile-text">
                  <span className="konto-zeile-name">{p.name}</span>
                  <span className="konto-zeile-dazu">
                    {p.gesichert ? "in der Wolke gesichert" : "nur auf diesem Gerät"} · zuletzt {datum(p.zuletzt_benutzt_am)}
                  </span>
                </div>
                <span className="konto-zeile-tun">
                  <button type="button" disabled={laeuft} onClick={() => setUmbenennen({ id: p.id, name: p.name })} className="zugang-knopf zugang-knopf-klein">
                    umbenennen
                  </button>
                  <BestaetigKnopf
                    frage={loeschfrage(p.name)}
                    disabled={laeuft || letzterBleibt}
                    onBestaetigt={() => void fuehre(() => api.passkeyLoeschen(p.id))}
                    className="zugang-knopf zugang-knopf-klein"
                  >
                    {letzterBleibt ? "der letzte bleibt" : "löschen"}
                  </BestaetigKnopf>
                </span>
                {umbenennen?.id === p.id ? (
                  <form
                    className="konto-umbenennen"
                    action={() => {
                      const neu = umbenennen.name.trim();
                      setUmbenennen(undefined);
                      if (neu) void fuehre(() => api.passkeyUmbenennen(p.id, neu));
                    }}
                  >
                    <input
                      type="text"
                      value={umbenennen.name}
                      autoFocus
                      maxLength={80}
                      onChange={(e) => setUmbenennen({ id: p.id, name: e.target.value })}
                      className="konto-feld"
                    />
                    <button type="submit" className="zugang-knopf zugang-knopf-an zugang-knopf-klein">
                      übernehmen
                    </button>
                    <button type="button" onClick={() => setUmbenennen(undefined)} className="zugang-knopf zugang-knopf-klein">
                      abbrechen
                    </button>
                  </form>
                ) : null}
              </li>
            ))}
          </ul>
        ) : null}
        <div className="konto-reihe">
          <input
            type="text"
            value={neuerName}
            onChange={(e) => setNeuerName(e.target.value)}
            placeholder="Name des neuen Geräts"
            maxLength={80}
            autoComplete="off"
            className="konto-feld"
          />
          <button type="button" disabled={laeuft} onClick={() => void passkeyAnlegen()} className="zugang-knopf zugang-knopf-an">
            {meine.length === 0 ? "Passkey anlegen" : "Weiteren Passkey anlegen"}
          </button>
        </div>
        <p className="konto-leise">
          Zwei Passkeys auf zwei Geräten sind der beste Rückweg. Ein in der Wolke gesicherter Passkey
          (iCloud-Schlüsselbund, Google-Passwortmanager) liegt ohnehin auf mehreren.
        </p>
        <div className="konto-reihe">
          <button
            type="button"
            disabled={laeuft}
            onClick={() => void fuehre(async () => setCodes((await api.codesNeu()).codes))}
            className="zugang-knopf"
          >
            Neue Wiederherstellungscodes
          </button>
        </div>
        {codes ? (
          <div className="konto-codes">
            <span className="kicker" style={{ fontSize: 11 }}>Zehn neue Codes ersetzen die alten</span>
            <ul className="m-0 grid list-none grid-cols-2 gap-2 p-0 sm:grid-cols-5">
              {codes.map((c) => (
                <li key={c} className="mono text-[14px] text-text-1">{c}</li>
              ))}
            </ul>
            <span className="text-[13px] text-text-3">Sie stehen nur jetzt hier.</span>
          </div>
        ) : null}
      </Zugangskarte>

      <Zugangskarte art="passwort">
        <MeinPasswort
          email={ich.ausweis.email ?? ""}
          vorhanden={hatPasswort}
          passkeys={meine.length}
          mindestlaenge={mindestlaenge}
          laeuft={laeuft}
          fuehre={fuehre}
        />
      </Zugangskarte>

      <Zugangskarte art="sitzungen">
        <ul className="konto-liste">
          {sitzungen.map((s) => (
            <li key={s.id} className="konto-zeile" data-diese={s.diese ? "" : undefined}>
              <span className="konto-zeile-zeichen" aria-hidden="true">
                <Icon name="device" size={17} />
              </span>
              <div className="konto-zeile-text">
                <span className="konto-zeile-name" title={s.herkunft}>
                  {geraet(s.herkunft)}
                  {s.diese ? <span className="konto-marke konto-marke-hier">dieses Gerät</span> : null}
                </span>
                <span className="konto-zeile-dazu">
                  seit {datum(s.erstellt_am)} · zuletzt {datum(s.zuletzt_benutzt_am)}
                </span>
              </div>
              {!s.diese ? (
                <span className="konto-zeile-tun">
                  <button type="button" disabled={laeuft} onClick={() => void fuehre(() => api.sitzungBeenden(s.id))} className="zugang-knopf zugang-knopf-klein">
                    beenden
                  </button>
                </span>
              ) : null}
            </li>
          ))}
        </ul>
      </Zugangskarte>

      <div className="konto-reihe">
        <button
          type="button"
          disabled={laeuft}
          onClick={() =>
            void (async () => {
              await abmelden();
              window.location.href = "/anmeldung";
            })()
          }
          className="zugang-knopf"
        >
          Abmelden
        </button>
        <BestaetigKnopf
          frage="Überall abmelden, auch hier?"
          disabled={laeuft}
          onBestaetigt={() =>
            void fuehre(async () => {
              await api.alleSitzungenBeenden();
              window.location.href = "/anmeldung";
            })
          }
          className="zugang-knopf zugang-knopf-leise"
        >
          Überall abmelden
        </BestaetigKnopf>
      </div>
    </div>
  );
}
