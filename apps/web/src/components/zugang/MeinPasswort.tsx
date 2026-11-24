"use client";

import { useState } from "react";

import { api } from "@/lib/api/client";
import { BestaetigKnopf } from "./BestaetigKnopf";

/**
 * Das eigene Passwort: vergeben, wechseln, entfernen.
 *
 * Der Hausherr hat am 24.11.2026 entschieden, dass es neben dem Passkey ein Passwort gibt. Wer
 * mit Passkey angemeldet ist, kann hier eines dazu vergeben; wer schon eines hat, wechselt es mit
 * dem bisherigen. **Einer der beiden Wege muss bleiben:** Das Passwort lässt sich nur entfernen,
 * solange ein Passkey da ist. Der Dienst lehnt es sonst ab, und diese Seite sagt es vorher.
 */

const FELD = "min-w-[220px] rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2 text-[14px] text-text-1";

export function MeinPasswort({
  email,
  vorhanden,
  passkeys,
  mindestlaenge,
  laeuft,
  fuehre,
}: {
  email: string;
  /** Ob die Person schon ein Passwort hat. */
  vorhanden: boolean;
  passkeys: number;
  /** Wie lang ein Passwort mindestens sein muss; die Regel kommt vom Dienst. */
  mindestlaenge: number;
  laeuft: boolean;
  /** Führt eine Änderung aus, zeigt ihren Fehler und lädt die Seite neu (`MeinZugang`). */
  fuehre: (was: () => Promise<unknown>) => Promise<boolean>;
}) {
  const [offen, setOffen] = useState(false);
  const [bisher, setBisher] = useState("");
  const [neu, setNeu] = useState("");
  const [wiederholung, setWiederholung] = useState("");
  const [hinweis, setHinweis] = useState<string>();

  function leeren() {
    setBisher("");
    setNeu("");
    setWiederholung("");
  }

  async function speichern() {
    setHinweis(undefined);
    if (neu !== wiederholung) {
      setHinweis("Die beiden Eingaben sind verschieden.");
      return;
    }
    const gelungen = await fuehre(() => api.passwortSetzen(neu, bisher));
    if (!gelungen) return;
    leeren();
    setOffen(false);
    setHinweis(
      vorhanden
        ? "Das Passwort ist gewechselt. Deine anderen Geräte sind abgemeldet."
        : "Das Passwort ist vergeben. Du kannst dich jetzt auch mit E-Mail-Adresse und Passwort anmelden.",
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <span className="kicker" style={{ fontSize: 11 }}>Mein Passwort</span>
      <p className="m-0 text-[14px] leading-[1.6] text-text-2">
        {vorhanden
          ? "Du hast ein Passwort und kannst dich damit an jedem Gerät anmelden."
          : "Du hast kein Passwort. Mit einem Passwort kommst du auch an Geräten herein, die keinen Passkey können."}
      </p>
      {hinweis ? <p className="m-0 text-[14px] text-text-2">{hinweis}</p> : null}
      {offen ? (
        <form
          className="flex flex-col gap-2"
          action={() => {
            void speichern();
          }}
        >
          {/* Für den Passwortmanager: zu welchem Konto das neue Passwort gehört. */}
          <input type="hidden" name="username" autoComplete="username" value={email} readOnly />
          {vorhanden ? (
            <label className="flex flex-col gap-1 text-[13px] text-text-3">
              Bisheriges Passwort
              <input
                type="password"
                value={bisher}
                onChange={(e) => setBisher(e.target.value)}
                required
                autoComplete="current-password"
                className={FELD}
              />
            </label>
          ) : null}
          <label className="flex flex-col gap-1 text-[13px] text-text-3">
            Neues Passwort, mindestens {mindestlaenge} Zeichen
            <input
              type="password"
              value={neu}
              onChange={(e) => setNeu(e.target.value)}
              required
              minLength={mindestlaenge}
              autoComplete="new-password"
              className={FELD}
            />
          </label>
          <label className="flex flex-col gap-1 text-[13px] text-text-3">
            Neues Passwort wiederholen
            <input
              type="password"
              value={wiederholung}
              onChange={(e) => setWiederholung(e.target.value)}
              required
              autoComplete="new-password"
              className={FELD}
            />
          </label>
          <div className="flex flex-wrap items-center gap-3">
            <button
              type="submit"
              disabled={laeuft}
              className="rounded-[3px] border border-line-1 px-4 py-2 text-[14px] text-text-1 disabled:opacity-50"
            >
              {vorhanden ? "Passwort wechseln" : "Passwort vergeben"}
            </button>
            <button
              type="button"
              onClick={() => {
                leeren();
                setOffen(false);
              }}
              className="text-[13px] text-text-3 underline decoration-dotted"
            >
              abbrechen
            </button>
          </div>
        </form>
      ) : (
        <div className="flex flex-wrap items-center gap-4">
          <button
            type="button"
            disabled={laeuft}
            onClick={() => {
              setHinweis(undefined);
              setOffen(true);
            }}
            className="rounded-[3px] border border-line-1 px-4 py-2 text-[14px] text-text-1 disabled:opacity-50"
          >
            {vorhanden ? "Passwort wechseln" : "Passwort vergeben"}
          </button>
          {vorhanden ? (
            <BestaetigKnopf
              frage="Passwort wirklich entfernen?"
              disabled={laeuft || passkeys === 0}
              onBestaetigt={() =>
                void (async () => {
                  setHinweis(undefined);
                  if (await fuehre(() => api.passwortEntfernen())) setHinweis("Das Passwort ist entfernt.");
                })()
              }
              className="text-[13px] text-text-3 underline decoration-dotted disabled:opacity-40"
            >
              {passkeys === 0 ? "Entfernen geht erst mit einem Passkey" : "Passwort entfernen"}
            </BestaetigKnopf>
          ) : null}
        </div>
      )}
    </div>
  );
}
