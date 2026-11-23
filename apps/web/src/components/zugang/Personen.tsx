"use client";

import { useCallback, useEffect, useState } from "react";

import { api, ApiError } from "@/lib/api/client";
import type { Einladung, Person } from "@/lib/api/models";
import { CopyField } from "@/components/ui/CopyField";
import { BestaetigKnopf } from "./BestaetigKnopf";

/**
 * Wer Zugang zu diesem Haus hat - anlegen, einladen, umstellen, abschalten, löschen.
 *
 * Die Rechte stehen im Dienst (`dch_api/auth/rechte.py`); diese Seite zeigt sie nur und schickt
 * die Änderungen hin. Was hier nicht geht, geht auch über die Adresszeile nicht.
 */

const ROLLEN: { wert: Person["rolle"]; name: string; was: string }[] = [
  { wert: "hausherr", name: "Hausherr", was: "alles - auch Rechnungen, Verwaltung und Export" },
  { wert: "bewohner", name: "Bewohner", was: "sehen und im Haus stellen; keine Akten" },
  { wert: "gast", name: "Gast", was: "nur zusehen; keine Akten" },
  { wert: "service", name: "Beratung", was: "zusehen und am Gerät arbeiten; nie die Akten" },
];

function datum(wert: string | null | undefined): string {
  if (!wert) return "nie";
  return new Date(wert).toLocaleString("de-DE", { dateStyle: "short", timeStyle: "short" });
}

export function Personen({ versand }: { versand: { aktiv: boolean; fehlt: string[] } }) {
  const [personen, setPersonen] = useState<Person[]>();
  const [fehler, setFehler] = useState<string>();
  const [link, setLink] = useState<Einladung>();
  const [laeuft, setLaeuft] = useState(false);

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
    <section className="flex max-w-[760px] flex-col gap-3">
      <h2 className="m-0 text-[18px] font-semibold">Personen</h2>
      <p className="m-0 text-[15px] leading-[1.6] text-text-2">
        Eine Person meldet sich mit einem Passkey an - kein Passwort, nichts zum Abtippen. Über den
        Einladungslink legt sie ihn selbst an und ist damit angemeldet.
        {versand.aktiv
          ? " Die Einladung geht auf Wunsch gleich per E-Mail hinaus."
          : ` E-Mail-Versand ist nicht eingerichtet (${versand.fehlt.join(", ") || "keine Angaben"}) - der Link bleibt hier zum Kopieren.`}
      </p>

      {fehler ? <p className="m-0 text-[14px] text-amber">{fehler}</p> : null}

      {personen === undefined ? (
        <p className="m-0 text-[15px] text-text-3">Lade…</p>
      ) : (
        <ul className="m-0 flex list-none flex-col gap-2 p-0">
          {personen.map((p) => (
            <li
              key={p.id}
              className="flex flex-col gap-2 rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3"
            >
              <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
                <span className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                  <span className="text-[15px] text-text-1">{p.anzeigename || p.email}</span>
                  {p.anzeigename ? (
                    <span className="mono text-[12px] text-text-3">{p.email}</span>
                  ) : null}
                  {!p.aktiv ? (
                    <span className="mono text-[12px] uppercase tracking-[.1em] text-amber">abgeschaltet</span>
                  ) : null}
                </span>
                <span className="mono text-[12px] text-text-3">
                  {p.passkeys} Passkey{p.passkeys === 1 ? "" : "s"} · {p.codes_offen} Codes · zuletzt{" "}
                  {datum(p.zuletzt_angemeldet_am)}
                </span>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <select
                  value={p.rolle}
                  disabled={laeuft}
                  onChange={(e) =>
                    void fuehre(() =>
                      api.personAendern(p.id, { rolle: e.target.value as Person["rolle"] }),
                    )
                  }
                  className="rounded-[3px] border border-line-1 bg-surface-1 px-2 py-1 text-[13px] text-text-1"
                >
                  {ROLLEN.map((r) => (
                    <option key={r.wert} value={r.wert}>
                      {r.name}
                    </option>
                  ))}
                </select>
                <button
                  type="button"
                  disabled={laeuft}
                  onClick={() =>
                    void fuehre(async () => setLink(await api.personEinladen(p.id, versand.aktiv)))
                  }
                  className="rounded-[3px] border border-line-1 px-2 py-1 text-[13px] text-text-2"
                >
                  {p.passkeys > 0 ? "Neuer Link" : p.einladung_offen ? "Link erneuern" : "Einladen"}
                </button>
                <button
                  type="button"
                  disabled={laeuft}
                  onClick={() => void fuehre(() => api.personAendern(p.id, { aktiv: !p.aktiv }))}
                  className="rounded-[3px] border border-line-1 px-2 py-1 text-[13px] text-text-2"
                >
                  {p.aktiv ? "Abschalten" : "Einschalten"}
                </button>
                <BestaetigKnopf
                  frage="Wirklich löschen? Passkeys und Sitzungen gehen mit"
                  disabled={laeuft}
                  onBestaetigt={() => void fuehre(() => api.personLoeschen(p.id))}
                  className="rounded-[3px] border border-line-1 px-2 py-1 text-[13px] text-text-3"
                >
                  Löschen
                </BestaetigKnopf>
              </div>
            </li>
          ))}
          {personen.length === 0 ? (
            <li className="text-[15px] text-text-3">Noch niemand. Unten die erste Person anlegen.</li>
          ) : null}
        </ul>
      )}

      {link ? (
        <div className="flex flex-col gap-2 rounded-[3px] border border-amber/40 bg-surface-2 p-4">
          <span className="kicker" style={{ fontSize: 11 }}>
            Einladungslink für {link.person.email}
            {link.verschickt ? " · per E-Mail verschickt" : ""}
          </span>
          <CopyField value={link.link} label="Einladungslink" />
          <span className="text-[13px] leading-[1.5] text-text-3">
            Gilt bis {datum(link.laeuft_ab_am)} und nur einmal. Er steht nur jetzt hier - wer ihn
            verliert, bekommt einen neuen.
          </span>
        </div>
      ) : null}

      <form action={(daten) => void anlegen(daten)} className="flex flex-col gap-2 rounded-[3px] border border-line-1 bg-surface-2 p-4">
        <span className="kicker" style={{ fontSize: 11 }}>Person anlegen</span>
        <div className="flex flex-wrap gap-2">
          <input
            type="email"
            name="email"
            required
            placeholder="E-Mail-Adresse"
            className="min-w-[220px] flex-1 rounded-[3px] border border-line-1 bg-surface-1 px-3 py-2 text-[14px] text-text-1"
          />
          <input
            type="text"
            name="name"
            placeholder="Name"
            maxLength={80}
            className="min-w-[140px] rounded-[3px] border border-line-1 bg-surface-1 px-3 py-2 text-[14px] text-text-1"
          />
          <select
            name="rolle"
            defaultValue="bewohner"
            className="rounded-[3px] border border-line-1 bg-surface-1 px-2 py-2 text-[14px] text-text-1"
          >
            {ROLLEN.map((r) => (
              <option key={r.wert} value={r.wert}>
                {r.name}
              </option>
            ))}
          </select>
        </div>
        <label className="flex items-center gap-2 text-[14px] text-text-3">
          <input type="checkbox" name="einladen" defaultChecked={versand.aktiv} disabled={!versand.aktiv} />
          Einladung per E-Mail verschicken
        </label>
        <button
          type="submit"
          disabled={laeuft}
          className="self-start rounded-[3px] border border-line-1 px-4 py-2 text-[14px] text-text-1 disabled:opacity-50"
        >
          Anlegen und Link erzeugen
        </button>
        <ul className="m-0 flex list-none flex-col gap-0.5 p-0 text-[13px] leading-[1.5] text-text-3">
          {ROLLEN.map((r) => (
            <li key={r.wert}>
              <strong className="text-text-2">{r.name}:</strong> {r.was}
            </li>
          ))}
        </ul>
      </form>
    </section>
  );
}
