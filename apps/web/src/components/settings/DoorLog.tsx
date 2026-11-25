"use client";

import { Systemkarte } from "@/components/ui/Systemkarte";
import { useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import { Pill } from "@/components/ui/Pill";
import type { DoorEntry, DoorLog as Log } from "@/lib/api/models";

/**
 * Wer sich wann an der Haustür erkannt hat.
 *
 * **Nur lesen.** Von hier führt kein Weg zur Tür, und das ist keine Sparsamkeit, sondern der
 * Entwurf: die Entscheidung fällt im Haus, an einer Erlaubnisliste in der Bridge, und die Cloud
 * erfährt davon erst hinterher. Eine Schaltfläche „öffnen" an dieser Stelle wäre eine Haustür am
 * Internet.
 *
 * **Auch die abgelehnten Versuche.** Ein Protokoll, das nur die geglückten Öffnungen zeigt,
 * beantwortet die Frage nicht, wegen der man abends hineinsieht.
 *
 * **Nach Tagen gruppiert**, weil man so hineinsieht: nicht „der 412. Eintrag", sondern „gestern
 * Abend". Innerhalb eines Tages steht der jüngste Eintrag oben.
 */
const SPANS = [7, 14, 30] as const;

function dayLabel(iso: string): string {
  const d = new Date(iso);
  const today = new Date();
  const same = (a: Date, b: Date) => a.toDateString() === b.toDateString();
  const yesterday = new Date(today.getTime() - 86_400_000);
  if (same(d, today)) return "Heute";
  if (same(d, yesterday)) return "Gestern";
  return d.toLocaleDateString("de-DE", { weekday: "long", day: "2-digit", month: "long" });
}

function time(iso: string): string {
  return new Date(iso).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });
}

/** „FACE" ist der Wert der Konsole. Auf einer Seite, die man liest, steht „Gesicht". */
function methodLabel(method: string): string {
  const m = method.trim().toUpperCase();
  if (m === "FACE") return "Gesicht";
  if (m === "NFC") return "Karte";
  if (m === "PIN") return "Code";
  if (m === "MOBILE_TAP" || m === "BT") return "Telefon";
  return method.trim() || "unbekannt";
}

function groupByDay(entries: DoorEntry[]): [string, DoorEntry[]][] {
  const out: [string, DoorEntry[]][] = [];
  for (const e of entries) {
    const key = new Date(e.at).toDateString();
    const last = out[out.length - 1];
    if (last && last[0] === key) last[1].push(e);
    else out.push([key, [e]]);
  }
  return out;
}

function Entry({ e }: { e: DoorEntry }) {
  const opened = e.outcome === "geöffnet";
  const failed = e.outcome === "fehlgeschlagen";
  return (
    <li className="konto-zeile">
      <span className="tuer-zeit mono">{time(e.at)}</span>
      <div className="konto-zeile-text">
        <span className="konto-zeile-name">{e.actor || "unbekannt"}</span>
        <span className="konto-zeile-dazu">per {methodLabel(e.method)}</span>
        {!opened && e.reason ? <span className="konto-zeile-dazu">{e.reason}</span> : null}
      </div>
      {/* Ein Fehlschlag ist etwas anderes als eine Ablehnung: dort hat das Haus nein gesagt,
          hier hat das Schloss nicht reagiert. Nur das zweite ist ein Defekt. */}
      <Pill tone={failed ? "alert" : opened ? "amber" : "neutral"}>{e.outcome}</Pill>
    </li>
  );
}

/** Der Satz unter dem Titel der Karte; derselbe in der App (`Tuerprotokoll.kartensatz`). */
export const TUERSATZ = "Zutritte und abgewiesene Versuche am Reader.";

/** Die drei Zahlen über der Liste, wie in der App (`Tuerprotokoll.kacheln`). */
export function zaehlung(entries: DoorEntry[]): { wort: string; wert: number; ton: "" | "achtung" | "alarm" }[] {
  const n = (o: string) => entries.filter((e) => e.outcome === o).length;
  const abgelehnt = n("abgelehnt");
  const fehlgeschlagen = n("fehlgeschlagen");
  return [
    { wort: "Öffnungen", wert: n("geöffnet"), ton: "" },
    { wort: "abgewiesen", wert: abgelehnt, ton: abgelehnt > 0 ? "achtung" : "" },
    { wort: "fehlgeschlagen", wert: fehlgeschlagen, ton: fehlgeschlagen > 0 ? "alarm" : "" },
  ];
}

export function DoorLog() {
  const [days, setDays] = useState<number>(14);
  const [data, setData] = useState<Log | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    setData(null);
    setError(null);
    api
      .doorLog(days)
      .then((d) => alive && setData(d))
      .catch(() => alive && setError("Das Türprotokoll konnte nicht geladen werden."));
    return () => {
      alive = false;
    };
  }, [days]);

  const groups = data ? groupByDay(data.entries) : [];
  return (
    <Systemkarte zeichen="door" titel="Haustür" satz={TUERSATZ}>
      <div className="konto-reihe" role="group" aria-label="Zeitraum">
        {SPANS.map((d) => (
          <button key={d} type="button" onClick={() => setDays(d)} aria-pressed={days === d} className="zugang-knopf zugang-knopf-klein wahl-knopf">
            {d} Tage
          </button>
        ))}
      </div>

      {error ? <p className="konto-leise">{error}</p> : null}
      {!error && !data ? <p className="konto-leise">lädt …</p> : null}

      {data ? (
        <dl className="konto-zahlen">
          {zaehlung(data.entries).map((z) => (
            <div key={z.wort} data-ton={z.ton || undefined}>
              <dt>{z.wort}</dt>
              <dd>{z.wert}</dd>
            </div>
          ))}
        </dl>
      ) : null}

      {data && groups.length > 0
        ? groups.map(([key, rows]) => (
            <div key={key} className="flex flex-col gap-2">
              <span className="kicker" style={{ fontSize: 11 }}>
                {dayLabel(rows[0]!.at)}
              </span>
              <ul className="konto-liste">
                {rows.map((e, i) => (
                  <Entry key={`${e.at}-${i}`} e={e} />
                ))}
              </ul>
            </div>
          ))
        : null}

      {data ? <p className="konto-leise">{data.note_de}</p> : null}
    </Systemkarte>
  );
}
