"use client";

import {
  browserSupportsWebAuthn,
  startRegistration,
  type PublicKeyCredentialCreationOptionsJSON,
} from "@simplewebauthn/browser";
import { useCallback, useEffect, useState } from "react";

import { abmelden } from "@/app/anmeldung/aktionen";
import { api, ApiError } from "@/lib/api/client";
import type { Ich } from "@/lib/api/models";
import { BestaetigKnopf } from "./BestaetigKnopf";
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
        noch ein eigenes Passwort. Wer einen eigenen Zugang möchte, lässt sich oben einladen.
      </p>
    );
  }

  // Die erzeugten Typen machen Listen mit Vorgabewert optional; hier sind sie immer da.
  const meine = ich.passkeys ?? [];
  const sitzungen = ich.sitzungen ?? [];
  const hatPasswort = ich.passwort ?? false;
  // Ohne Passwort bleibt der letzte Passkey, denn sonst gäbe es keinen Weg herein.
  const letzterBleibt = meine.length <= 1 && !hatPasswort;

  return (
    <div className="flex flex-col gap-3">
      <p className="m-0 text-[15px] leading-[1.6] text-text-2">
        Angemeldet als <strong>{ich.ausweis.name}</strong>
        {ich.ausweis.name !== ich.ausweis.email ? ` (${ich.ausweis.email})` : ""}, Rolle{" "}
        <span className="mono text-[13px]">{ich.ausweis.rolle}</span>. Noch{" "}
        {ich.codes_offen} Wiederherstellungscodes übrig.
      </p>
      {fehler ? <p className="m-0 text-[14px] text-amber">{fehler}</p> : null}

      <span className="kicker" style={{ fontSize: 11 }}>Meine Passkeys</span>
      <ul className="m-0 flex list-none flex-col gap-2 p-0">
        {meine.map((p) => (
          <li
            key={p.id}
            className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3"
          >
            <span className="flex items-baseline gap-3">
              <span className="text-[15px] text-text-1">{p.name}</span>
              {p.gesichert ? (
                <span className="mono text-[12px] text-text-3">in der Wolke gesichert</span>
              ) : (
                <span className="mono text-[12px] text-text-3">nur auf diesem Gerät</span>
              )}
            </span>
            <span className="flex items-baseline gap-3">
              <span className="mono text-[12px] text-text-3">zuletzt {datum(p.zuletzt_benutzt_am)}</span>
              <button
                type="button"
                disabled={laeuft}
                onClick={() => setUmbenennen({ id: p.id, name: p.name })}
                className="text-[13px] text-text-3 underline decoration-dotted"
              >
                umbenennen
              </button>
              <BestaetigKnopf
                frage="wirklich?"
                disabled={laeuft || letzterBleibt}
                onBestaetigt={() => void fuehre(() => api.passkeyLoeschen(p.id))}
                className="text-[13px] text-text-3 underline decoration-dotted disabled:opacity-40"
              >
                {letzterBleibt ? "der letzte bleibt" : "löschen"}
              </BestaetigKnopf>
            </span>
            {umbenennen?.id === p.id ? (
              <form
                className="flex w-full flex-wrap items-center gap-2"
                action={() => {
                  const name = umbenennen.name.trim();
                  setUmbenennen(undefined);
                  if (name) void fuehre(() => api.passkeyUmbenennen(p.id, name));
                }}
              >
                <input
                  type="text"
                  value={umbenennen.name}
                  autoFocus
                  maxLength={80}
                  onChange={(e) => setUmbenennen({ id: p.id, name: e.target.value })}
                  className="min-w-[160px] flex-1 rounded-[3px] border border-line-1 bg-surface-1 px-2 py-1 text-[14px] text-text-1"
                />
                <button type="submit" className="text-[13px] text-amber underline decoration-dotted">
                  übernehmen
                </button>
                <button
                  type="button"
                  onClick={() => setUmbenennen(undefined)}
                  className="text-[13px] text-text-3 underline decoration-dotted"
                >
                  abbrechen
                </button>
              </form>
            ) : null}
          </li>
        ))}
      </ul>
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="text"
          value={neuerName}
          onChange={(e) => setNeuerName(e.target.value)}
          placeholder="Name des neuen Geräts"
          maxLength={80}
          autoComplete="off"
          className="min-w-[200px] rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2 text-[14px] text-text-1"
        />
        <button
          type="button"
          disabled={laeuft}
          onClick={() => void passkeyAnlegen()}
          className="rounded-[3px] border border-line-1 px-4 py-2 text-[14px] text-text-1 disabled:opacity-50"
        >
          {meine.length === 0 ? "Passkey anlegen" : "Weiteren Passkey anlegen"}
        </button>
        <button
          type="button"
          disabled={laeuft}
          onClick={() => void fuehre(async () => setCodes((await api.codesNeu()).codes))}
          className="rounded-[3px] border border-line-1 px-4 py-2 text-[14px] text-text-2 disabled:opacity-50"
        >
          Neue Wiederherstellungscodes
        </button>
      </div>
      <p className="m-0 text-[13px] leading-[1.5] text-text-3">
        Zwei Passkeys auf zwei Geräten sind der beste Rückweg. Ein in der Wolke gesicherter Passkey
        (iCloud-Schlüsselbund, Google-Passwortmanager) liegt ohnehin auf mehreren.
      </p>

      <MeinPasswort
        email={ich.ausweis.email ?? ""}
        vorhanden={hatPasswort}
        passkeys={meine.length}
        mindestlaenge={mindestlaenge}
        laeuft={laeuft}
        fuehre={fuehre}
      />

      {codes ? (
        <div className="flex flex-col gap-2 rounded-[3px] border border-amber/40 bg-surface-2 p-4">
          <span className="kicker" style={{ fontSize: 11 }}>Zehn neue Codes ersetzen die alten</span>
          <ul className="m-0 grid list-none grid-cols-2 gap-2 p-0 sm:grid-cols-5">
            {codes.map((c) => (
              <li key={c} className="mono text-[14px] text-text-1">{c}</li>
            ))}
          </ul>
          <span className="text-[13px] text-text-3">Sie stehen nur jetzt hier.</span>
        </div>
      ) : null}

      <span className="kicker" style={{ fontSize: 11 }}>Meine Sitzungen</span>
      <ul className="m-0 flex list-none flex-col gap-2 p-0">
        {sitzungen.map((s) => (
          <li
            key={s.id}
            className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3"
          >
            <span className="flex items-baseline gap-3">
              <span className="text-[14px] text-text-2" title={s.herkunft}>{geraet(s.herkunft)}</span>
              {s.diese ? <span className="mono text-[12px] text-amber">dieses Gerät</span> : null}
            </span>
            <span className="flex items-baseline gap-3">
              <span className="mono text-[12px] text-text-3">
                seit {datum(s.erstellt_am)} · zuletzt {datum(s.zuletzt_benutzt_am)}
              </span>
              {!s.diese ? (
                <button
                  type="button"
                  disabled={laeuft}
                  onClick={() => void fuehre(() => api.sitzungBeenden(s.id))}
                  className="text-[13px] text-text-3 underline decoration-dotted"
                >
                  beenden
                </button>
              ) : null}
            </span>
          </li>
        ))}
      </ul>
      <div className="flex flex-wrap gap-4">
        <button
          type="button"
          disabled={laeuft}
          onClick={() =>
            void (async () => {
              await abmelden();
              window.location.href = "/anmeldung";
            })()
          }
          className="text-[13px] text-text-2 underline decoration-dotted"
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
        className="text-[13px] text-text-3 underline decoration-dotted"
      >
        Überall abmelden
      </BestaetigKnopf>
      </div>
    </div>
  );
}
