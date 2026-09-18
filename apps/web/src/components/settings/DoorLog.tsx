"use client";

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
    <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1 border-b border-line-1 py-2 last:border-b-0">
      <span className="mono w-[44px] shrink-0 text-[13px] text-text-3">{time(e.at)}</span>
      <span className="text-[14px] text-text-1">{e.actor || "unbekannt"}</span>
      <span className="text-[13px] text-text-3">per {methodLabel(e.method)}</span>
      <span className="ml-auto flex items-center gap-2">
        {/* Ein Fehlschlag ist etwas anderes als eine Ablehnung: dort hat das Haus nein gesagt,
            hier hat das Schloss nicht reagiert. Nur das zweite ist ein Defekt. */}
        <Pill tone={failed ? "alert" : opened ? "amber" : "neutral"}>{e.outcome}</Pill>
      </span>
      {!opened && e.reason ? (
        <span className="w-full pl-[56px] text-[13px] leading-[1.5] text-text-3">{e.reason}</span>
      ) : null}
    </div>
  );
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
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        {SPANS.map((d) => (
          <button
            key={d}
            type="button"
            onClick={() => setDays(d)}
            aria-pressed={days === d}
            className={`mono rounded-[2px] border px-3 py-1 text-[12px] ${
              days === d
                ? "border-amber text-amber"
                : "border-line-1 text-text-3 hover:text-text-2"
            }`}
          >
            {d} Tage
          </button>
        ))}
      </div>

      {error ? <p className="m-0 text-[14px] text-text-3">{error}</p> : null}
      {!error && !data ? <p className="m-0 text-[14px] text-text-3">lädt …</p> : null}

      {data && groups.length > 0 ? (
        <div className="flex flex-col gap-4">
          {groups.map(([key, rows]) => (
            <div key={key} className="rounded-[3px] border border-line-1 bg-surface-2 px-4 py-3">
              <div className="kicker mb-1" style={{ fontSize: 11 }}>
                {dayLabel(rows[0]!.at)}
              </div>
              {rows.map((e, i) => (
                <Entry key={`${e.at}-${i}`} e={e} />
              ))}
            </div>
          ))}
        </div>
      ) : null}

      {data ? <p className="m-0 text-[14px] leading-[1.6] text-text-3">{data.note_de}</p> : null}
    </div>
  );
}
