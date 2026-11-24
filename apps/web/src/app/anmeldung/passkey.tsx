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
  einrichtenPasswort,
  passkeyAnmelden,
  passkeyOptionen,
  passwortAnmelden,
  wiederherstellen,
  type Ergebnis,
} from "./aktionen";

/**
 * Die beiden Wege herein im Browser: der Passkey und, seit dem 24.11.2026, das Passwort.
 * Challenge und Prüfung liegen beim Dienst (aktionen.ts).
 *
 * **Kein automatisches Angebot beim Öffnen der Seite** (Autofill): jede Challenge ist eine Zeile
 * beim Dienst, und eine Seite, die beim blossen Aufruf eine anlegt, ließe sich von jedem Bot
 * fluten. Der Passkey wird erst auf Klick angefragt.
 */

const NICHT_MOEGLICH =
  "Dieser Browser kann keine Passkeys. Mit dem Passwort oder einem Wiederherstellungscode kommst du trotzdem herein.";
const FELD = "rounded-[3px] border border-line-1 bg-surface-2 px-3 py-2 text-[15px] text-text-1";
const KNOPF =
  "rounded-[3px] border border-line-1 bg-surface-2 px-5 py-3 text-[15px] text-text-1 disabled:opacity-50";
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

/** Anmeldung mit E-Mail-Adresse und Passwort, für Leute, die keinen Passkey verwenden. */
export function PasswortAnmeldung() {
  const router = useRouter();
  // Die Adresse ist ein gehaltener Wert: React leert nach einer Formularaktion alle freien
  // Felder, und wer sich beim Passwort vertippt hat, soll die Adresse nicht neu schreiben.
  const [email, setEmail] = useState("");
  const [ergebnis, absenden, laeuft] = useActionState<Ergebnis, FormData>(
    async (vorher, daten) => {
      const antwort = await passwortAnmelden(vorher, daten);
      if (!antwort.fehler) router.replace("/");
      return antwort;
    },
    {},
  );
  return (
    <form action={absenden} className="flex flex-col gap-3">
      {ergebnis.fehler ? <p className="m-0 text-[14px] leading-[1.5] text-amber">{ergebnis.fehler}</p> : null}
      <label className="flex flex-col gap-1.5 text-[14px] text-text-3">
        E-Mail-Adresse
        <input
          type="email"
          name="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="username"
          className={FELD}
        />
      </label>
      <label className="flex flex-col gap-1.5 text-[14px] text-text-3">
        Passwort
        <input type="password" name="passwort" required autoComplete="current-password" className={FELD} />
      </label>
      <button type="submit" disabled={laeuft} className={KNOPF}>
        {laeuft ? "Prüfe…" : "Mit Passwort anmelden"}
      </button>
    </form>
  );
}

export function Wiederherstellung() {
  const router = useRouter();
  const [offen, setOffen] = useState(false);
  // Gehalten wie in `PasswortAnmeldung`: ein falscher Code soll die Adresse nicht mitnehmen.
  const [email, setEmail] = useState("");
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
        Passkey verloren oder Passwort vergessen? Mit Wiederherstellungscode anmelden
      </button>
    );
  }
  return (
    <form action={absenden} className="flex flex-col gap-3">
      <p className="m-0 text-[14px] leading-[1.5] text-text-3">
        Einer der zehn Codes aus der Einrichtung. Jeder gilt einmal. Danach bitte gleich einen
        neuen Passkey anlegen. Wer sein Passwort vergessen hat, bittet den Hausherrn um einen
        neuen Link.
      </p>
      {ergebnis.fehler ? <p className="m-0 text-[14px] text-amber">{ergebnis.fehler}</p> : null}
      <input
        type="email"
        name="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
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
  mindestlaenge,
  fehler: fehlerVonAussen,
}: {
  token: string;
  email: string;
  hinweis: string;
  /** Wie lang ein Passwort mindestens sein muss; die Regel kommt vom Dienst. */
  mindestlaenge: number;
  /** Warum der Link nicht gilt - leer, wenn er gilt. */
  fehler: string;
}) {
  const router = useRouter();
  const [fehler, setFehler] = useState<string>();
  const [laeuft, setLaeuft] = useState(false);
  const [name, setName] = useState("");
  const [codes, setCodes] = useState<string[]>();
  /** Welchen der beiden Wege die Person einrichtet. Der Passkey ist der empfohlene. */
  const [weg, setWeg] = useState<"passkey" | "passwort">("passkey");
  const [passwort, setPasswort] = useState("");
  const [wiederholung, setWiederholung] = useState("");

  async function vergeben() {
    setFehler(undefined);
    if (passwort !== wiederholung) {
      setFehler("Die beiden Eingaben sind verschieden.");
      return;
    }
    setLaeuft(true);
    try {
      const ergebnis = await einrichtenPasswort(token, passwort);
      if (ergebnis.fehler) {
        setFehler(ergebnis.fehler);
        return;
      }
      setCodes(ergebnis.codes ?? []);
    } finally {
      setLaeuft(false);
    }
  }

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
          wenn der Passkey verloren oder das Passwort vergessen ist. Aufschreiben oder in den
          Passwortmanager.
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
        Für <span className="mono">{email}</span>. Du meldest dich künftig mit einem Passkey an
        oder mit E-Mail-Adresse und Passwort. Den anderen Weg kannst du später ergänzen.
      </p>
      <div className="flex gap-2" role="tablist" aria-label="Weg der Anmeldung">
        {(["passkey", "passwort"] as const).map((w) => (
          <button
            key={w}
            type="button"
            role="tab"
            aria-selected={weg === w}
            onClick={() => {
              setWeg(w);
              setFehler(undefined);
            }}
            className={`rounded-[3px] border px-4 py-2 text-[14px] ${
              weg === w ? "border-amber text-text-1" : "border-line-1 text-text-3"
            }`}
          >
            {w === "passkey" ? "Passkey (empfohlen)" : "Passwort"}
          </button>
        ))}
      </div>
      {fehler ? <p className="m-0 text-[14px] text-amber">{fehler}</p> : null}
      {weg === "passkey" ? (
        <>
          <p className="m-0 text-[14px] leading-[1.6] text-text-3">
            Ein Passkey bleibt auf diesem Gerät und wird mit Fingerabdruck, Gesicht oder
            Geräte-PIN freigegeben. Es gibt nichts abzutippen und nichts zu vergessen.
          </p>
          <label className="flex flex-col gap-1.5 text-[14px] text-text-3">
            Name dieses Geräts (nur für deine Liste)
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="iPhone"
              maxLength={80}
              autoComplete="off"
              className={FELD}
            />
          </label>
          <button type="button" onClick={anlegen} disabled={laeuft} className={`self-start ${KNOPF}`}>
            {laeuft ? "Warte auf das Gerät…" : "Passkey anlegen"}
          </button>
        </>
      ) : (
        <form
          className="flex flex-col gap-3"
          action={() => {
            void vergeben();
          }}
        >
          <p className="m-0 text-[14px] leading-[1.6] text-text-3">
            Das Passwort braucht mindestens {mindestlaenge} Zeichen. Ein ganzer Satz ist besser
            als ein kurzes Wort mit Sonderzeichen.
          </p>
          {/* Die Adresse steht als verstecktes Feld da, damit der Passwortmanager das neue
              Passwort zum richtigen Konto ablegt. */}
          <input type="hidden" name="username" autoComplete="username" value={email} readOnly />
          <label className="flex flex-col gap-1.5 text-[14px] text-text-3">
            Passwort
            <input
              type="password"
              value={passwort}
              onChange={(e) => setPasswort(e.target.value)}
              required
              minLength={mindestlaenge}
              autoComplete="new-password"
              className={FELD}
            />
          </label>
          <label className="flex flex-col gap-1.5 text-[14px] text-text-3">
            Passwort wiederholen
            <input
              type="password"
              value={wiederholung}
              onChange={(e) => setWiederholung(e.target.value)}
              required
              autoComplete="new-password"
              className={FELD}
            />
          </label>
          <button type="submit" disabled={laeuft} className={`self-start ${KNOPF}`}>
            {laeuft ? "Prüfe…" : "Passwort vergeben"}
          </button>
        </form>
      )}
    </section>
  );
}
