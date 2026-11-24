"use client";

import {
  browserSupportsWebAuthn,
  startAuthentication,
  startRegistration,
  type PublicKeyCredentialCreationOptionsJSON,
  type PublicKeyCredentialRequestOptionsJSON,
} from "@simplewebauthn/browser";
import { useRouter } from "next/navigation";
import { useActionState, useState } from "react";

import {
  einrichtenAnlegen,
  einrichtenOptionen,
  passkeyAnmelden,
  passkeyOptionen,
  wiederherstellen,
  type Ergebnis,
} from "./aktionen";

/**
 * Die Zeremonie im Browser. Challenge und Prüfung liegen beim Dienst (aktionen.ts).
 *
 * **Kein automatisches Angebot beim Öffnen der Seite** (Autofill): jede Challenge ist eine Zeile
 * beim Dienst, und eine Seite, die beim blossen Aufruf eine anlegt, ließe sich von jedem Bot
 * fluten. Der Passkey wird erst auf Klick angefragt.
 */

const NICHT_MOEGLICH =
  "Dieser Browser kann keine Passkeys. Mit dem Wiederherstellungscode kommst du trotzdem herein.";
const ABGEBROCHEN = "Abgebrochen oder kein passender Passkey auf diesem Gerät.";

export function PasskeyAnmeldung() {
  const router = useRouter();
  const [fehler, setFehler] = useState<string>();
  const [laeuft, setLaeuft] = useState(false);

  async function anmelden() {
    setFehler(undefined);
    if (!browserSupportsWebAuthn()) {
      setFehler(NICHT_MOEGLICH);
      return;
    }
    setLaeuft(true);
    try {
      const z = await passkeyOptionen();
      if (!z.schritt || !z.optionen) {
        setFehler(z.fehler ?? ABGEBROCHEN);
        return;
      }
      const antwort = await startAuthentication({
        optionsJSON: JSON.parse(z.optionen) as PublicKeyCredentialRequestOptionsJSON,
      });
      const ergebnis = await passkeyAnmelden(z.schritt, antwort);
      if (ergebnis.fehler) {
        setFehler(ergebnis.fehler);
        return;
      }
      router.replace("/");
    } catch {
      // Abgebrochen, kein passender Passkey, Zeitüberschreitung: der Browser nennt das alles
      // NotAllowedError und sagt mit Absicht nicht, welches davon.
      setFehler(ABGEBROCHEN);
    } finally {
      setLaeuft(false);
    }
  }

  return (
    <div className="flex flex-col gap-3">
      {fehler ? <p className="m-0 text-[14px] leading-[1.5] text-amber">{fehler}</p> : null}
      <button
        type="button"
        onClick={anmelden}
        disabled={laeuft}
        className="rounded-[3px] border border-line-1 bg-surface-2 px-5 py-3 text-[15px] text-text-1 disabled:opacity-50"
      >
        {laeuft ? "Warte auf das Gerät…" : "Mit Passkey anmelden"}
      </button>
    </div>
  );
}

export function Wiederherstellung() {
  const router = useRouter();
  const [offen, setOffen] = useState(false);
  const [ergebnis, absenden, laeuft] = useActionState<Ergebnis, FormData>(
    async (vorher, daten) => {
      const antwort = await wiederherstellen(vorher, daten);
      if (!antwort.fehler) router.replace("/");
      return antwort;
    },
    {},
  );

  if (!offen) {
    return (
      <button
        type="button"
        onClick={() => setOffen(true)}
        className="self-start text-[14px] text-text-3 underline decoration-dotted"
      >
        Alle Geräte verloren? Mit Wiederherstellungscode anmelden
      </button>
    );
  }
  return (
    <form action={absenden} className="flex flex-col gap-3">
      <p className="m-0 text-[14px] leading-[1.5] text-text-3">
        Einer der zehn Codes aus der Einrichtung. Jeder gilt einmal. Danach bitte gleich einen
        neuen Passkey anlegen.
      </p>
      {ergebnis.fehler ? <p className="m-0 text-[14px] text-amber">{ergebnis.fehler}</p> : null}
      <input
        type="email"
        name="email"
        required
        autoFocus
        autoComplete="email"
        placeholder="E-Mail-Adresse"
        className="rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2 text-[15px] text-text-1"
      />
      <input
        type="text"
        name="code"
        required
        autoComplete="one-time-code"
        maxLength={32}
        placeholder="Code, z. B. a3kf9-2mqxr"
        className="mono rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2 text-[15px] text-text-1"
      />
      <button
        type="submit"
        disabled={laeuft}
        className="rounded-[3px] border border-line-1 bg-surface-2 px-5 py-3 text-[15px] text-text-1 disabled:opacity-50"
      >
        Anmelden
      </button>
      <button
        type="button"
        onClick={() => setOffen(false)}
        className="self-start text-[14px] text-text-3 underline decoration-dotted"
      >
        Zurück
      </button>
    </form>
  );
}

export function Einrichten({
  token,
  email,
  hinweis,
  fehler: fehlerVonAussen,
}: {
  token: string;
  email: string;
  hinweis: string;
  /** Warum der Link nicht gilt - leer, wenn er gilt. */
  fehler: string;
}) {
  const router = useRouter();
  const [fehler, setFehler] = useState<string>();
  const [laeuft, setLaeuft] = useState(false);
  const [name, setName] = useState("");
  const [codes, setCodes] = useState<string[]>();

  async function anlegen() {
    setFehler(undefined);
    if (!browserSupportsWebAuthn()) {
      setFehler("Dieser Browser kann keine Passkeys. Bitte ein anderes Gerät nehmen.");
      return;
    }
    setLaeuft(true);
    try {
      const z = await einrichtenOptionen(token);
      if (!z.schritt || !z.optionen) {
        setFehler(z.fehler ?? "Dieser Link gilt nicht mehr.");
        return;
      }
      const antwort = await startRegistration({
        optionsJSON: JSON.parse(z.optionen) as PublicKeyCredentialCreationOptionsJSON,
      });
      const ergebnis = await einrichtenAnlegen(token, z.schritt, antwort, name.trim());
      if (ergebnis.fehler) {
        setFehler(ergebnis.fehler);
        return;
      }
      setCodes(ergebnis.codes ?? []);
    } catch {
      setFehler(ABGEBROCHEN);
    } finally {
      setLaeuft(false);
    }
  }

  // Zuerst: liegen Codes vor, gehen sie vor allem anderen. Nach dem Anlegen rendert Next diese
  // Seite neu, und dann gilt der Link nicht mehr - die Codes dürfen dabei nicht verschwinden,
  // denn sie gehen nur einmal hinaus.
  if (codes) {
    return (
      <section className="flex flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Deine zehn Wiederherstellungscodes</h2>
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Sie stehen <strong>nur jetzt</strong> hier. Jeder gilt einmal und bringt dich herein,
          wenn alle Geräte mit Passkey verloren sind. Aufschreiben oder in den Passwortmanager.
        </p>
        <ul className="m-0 grid list-none grid-cols-2 gap-2 p-0">
          {codes.map((c) => (
            <li key={c} className="mono rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2 text-[15px]">
              {c}
            </li>
          ))}
        </ul>
        <button
          type="button"
          onClick={() => router.replace("/")}
          className="self-start rounded-[3px] border border-line-1 bg-surface-2 px-5 py-3 text-[15px] text-text-1"
        >
          Notiert, weiter
        </button>
      </section>
    );
  }

  if (fehlerVonAussen) {
    return (
      <section className="flex flex-col gap-2 rounded-[3px] border border-line-1 bg-surface-2 p-4">
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">{fehlerVonAussen}</p>
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Ein Link gilt einmal und läuft ab. Bitte den Hausherrn um einen neuen.
        </p>
      </section>
    );
  }

  return (
    <section className="flex flex-col gap-3">
      {hinweis ? <p className="m-0 text-[14px] text-text-3">{hinweis}</p> : null}
      <p className="m-0 text-[15px] leading-[1.6] text-text-2">
        Für <span className="mono">{email}</span>. Ein Passkey bleibt auf diesem Gerät und wird mit
        Fingerabdruck, Gesicht oder Geräte-PIN freigegeben. Ein Passwort gibt es nicht.
      </p>
      {fehler ? <p className="m-0 text-[14px] text-amber">{fehler}</p> : null}
      <label className="flex flex-col gap-1.5 text-[14px] text-text-3">
        Name dieses Geräts (nur für deine Liste)
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="iPhone"
          maxLength={80}
          autoComplete="off"
          className="rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2 text-[15px] text-text-1"
        />
      </label>
      <button
        type="button"
        onClick={anlegen}
        disabled={laeuft}
        className="self-start rounded-[3px] border border-line-1 bg-surface-2 px-5 py-3 text-[15px] text-text-1 disabled:opacity-50"
      >
        {laeuft ? "Warte auf das Gerät…" : "Passkey anlegen"}
      </button>
    </section>
  );
}
