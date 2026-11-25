"use client";

import { useCallback, useEffect, useState } from "react";

import { api, ApiError } from "@/lib/api/client";
import type { Einladung, Person } from "@/lib/api/models";
import { CopyField } from "@/components/ui/CopyField";
import { BestaetigKnopf } from "./BestaetigKnopf";
import { ROLLE } from "./kontoworte";
import { Zugangskarte } from "./Zugangskarte";

/**
 * Wer Zugang zu diesem Haus hat - anlegen, einladen, umstellen, abschalten, löschen.
 *
 * Die Rechte stehen im Dienst (`dch_api/auth/rechte.py`); diese Seite zeigt sie nur und schickt
 * die Änderungen hin. Was hier nicht geht, geht auch über die Adresszeile nicht.
 *
 * **Ohne Erklärtext** (Wunsch des Hausherrn vom 25.11.2026: „der Text muss weg“). Jede Person ist
 * eine Zeile mit Anfangsbuchstaben, einer Zeile Zahlen und der Wahl ihrer Rolle; was eine Rolle darf,
 * steht als ein Satz unter der Wahl beim Anlegen (`ROLLE` in `kontoworte.ts`).
 */

const ROLLEN: Person["rolle"][] = ["hausherr", "bewohner", "gast", "service"];

function datum(wert: string | null | undefined): string {
  if (!wert) return "nie";
  return new Date(wert).toLocaleString("de-DE", { dateStyle: "short", timeStyle: "short" });
}

export function Personen({ versand }: { versand: { aktiv: boolean; fehlt: string[] } }) {
  const [personen, setPersonen] = useState<Person[]>();
  const [fehler, setFehler] = useState<string>();
  const [link, setLink] = useState<Einladung>();
  const [laeuft, setLaeuft] = useState(false);
  const [neueRolle, setNeueRolle] = useState<Person["rolle"]>("bewohner");

  const laden = useCallback(() => {
    void api
      .personen()
      .then(setPersonen)
      .catch((e: unknown) => setFehler(e instanceof ApiError ? e.message : "Laden fehlgeschlagen."));
  }, []);

  useEffect(laden, [laden]);

  async function fuehre(was: () => Promise<unknown>) {
    setFehler(undefined);
    setLaeuft(true);
    try {
      await was();
      laden();
    } catch (e) {
      setFehler(e instanceof ApiError ? e.message : "Das hat nicht geklappt.");
    } finally {
      setLaeuft(false);
    }
  }

  async function anlegen(daten: FormData) {
    await fuehre(async () => {
      const einladung = await api.personAnlegen({
        email: String(daten.get("email") ?? ""),
        anzeigename: String(daten.get("name") ?? ""),
        rolle: (daten.get("rolle") as Person["rolle"]) ?? "bewohner",
        einladen: daten.get("einladen") === "on",
      });
      setLink(einladung);
    });
  }

  return (
    <Zugangskarte art="personen">
      {fehler ? <p className="konto-fehler" role="alert">{fehler}</p> : null}

      {personen === undefined ? (
        <p className="konto-leise">Lade…</p>
      ) : (
        <ul className="konto-liste">
          {personen.map((p) => {
            const name = p.anzeigename || p.email;
            return (
              <li key={p.id} className="konto-zeile" data-aus={p.aktiv ? undefined : ""}>
                <span className="person-anfang" data-rolle={p.rolle} aria-hidden="true">
                  {name.trim().charAt(0).toLocaleUpperCase("de-DE") || "?"}
                </span>
                <div className="konto-zeile-text">
                  <span className="konto-zeile-name">
                    {name}
                    {!p.aktiv ? <span className="konto-marke konto-marke-aus">abgeschaltet</span> : null}
                  </span>
                  {p.anzeigename ? <span className="konto-zeile-dazu">{p.email}</span> : null}
                  <span className="konto-zeile-dazu">
                    {p.passkeys} Passkey{p.passkeys === 1 ? "" : "s"} · {p.passwort ? "mit Passwort" : "ohne Passwort"} · {p.codes_offen} Codes · zuletzt{" "}
                    {datum(p.zuletzt_angemeldet_am)}
                  </span>
                </div>
                <span className="konto-zeile-tun person-tun">
                  <select
                    value={p.rolle}
                    disabled={laeuft}
                    aria-label={`Rolle von ${name}`}
                    onChange={(e) => void fuehre(() => api.personAendern(p.id, { rolle: e.target.value as Person["rolle"] }))}
                    className="zugang-wahl zugang-knopf-klein"
                  >
                    {ROLLEN.map((r) => (
                      <option key={r} value={r}>
                        {ROLLE[r]?.name ?? r}
                      </option>
                    ))}
                  </select>
                  <button
                    type="button"
                    disabled={laeuft}
                    onClick={() => void fuehre(async () => setLink(await api.personEinladen(p.id, versand.aktiv)))}
                    className="zugang-knopf zugang-knopf-klein"
                  >
                    {p.passkeys > 0 || p.passwort ? "Neuer Link" : p.einladung_offen ? "Link erneuern" : "Einladen"}
                  </button>
                  <button
                    type="button"
                    disabled={laeuft}
                    onClick={() => void fuehre(() => api.personAendern(p.id, { aktiv: !p.aktiv }))}
                    className="zugang-knopf zugang-knopf-klein"
                  >
                    {p.aktiv ? "Abschalten" : "Einschalten"}
                  </button>
                  <BestaetigKnopf
                    frage={`„${name}“ löschen?`}
                    disabled={laeuft}
                    onBestaetigt={() => void fuehre(() => api.personLoeschen(p.id))}
                    className="zugang-knopf zugang-knopf-klein zugang-knopf-leise"
                  >
                    Löschen
                  </BestaetigKnopf>
                </span>
              </li>
            );
          })}
          {personen.length === 0 ? <li className="konto-leise">Noch niemand angelegt.</li> : null}
        </ul>
      )}

      {link ? (
        <div className="konto-codes">
          <span className="kicker" style={{ fontSize: 11 }}>
            Einladungslink für {link.person.email}
            {link.verschickt ? " · per E-Mail verschickt" : ""}
          </span>
          <CopyField value={link.link} label="Einladungslink" />
          <span className="konto-leise">Gilt einmal und bis {datum(link.laeuft_ab_am)}.</span>
        </div>
      ) : null}

      <form action={(daten) => void anlegen(daten)} className="person-anlegen">
        <span className="kicker" style={{ fontSize: 11 }}>Person anlegen</span>
        <div className="konto-reihe">
          <input type="email" name="email" required placeholder="E-Mail-Adresse" className="konto-feld" />
          <input type="text" name="name" placeholder="Name" maxLength={80} className="konto-feld" />
          <select
            name="rolle"
            value={neueRolle}
            onChange={(e) => setNeueRolle(e.target.value as Person["rolle"])}
            aria-label="Rolle"
            className="zugang-wahl"
          >
            {ROLLEN.map((r) => (
              <option key={r} value={r}>
                {ROLLE[r]?.name ?? r}
              </option>
            ))}
          </select>
        </div>
        <p className="konto-leise">{ROLLE[neueRolle]?.satz}</p>
        <div className="konto-reihe">
          <button type="submit" disabled={laeuft} className="zugang-knopf zugang-knopf-an">
            Anlegen und Link erzeugen
          </button>
          <label className="person-versand">
            <input type="checkbox" name="einladen" defaultChecked={versand.aktiv} disabled={!versand.aktiv} />
            per E-Mail verschicken
          </label>
        </div>
        {!versand.aktiv ? (
          <p className="konto-leise" title={versand.fehlt.join(", ")}>
            E-Mail-Versand ist nicht eingerichtet; der Link bleibt hier zum Kopieren.
          </p>
        ) : null}
      </form>
    </Zugangskarte>
  );
}
