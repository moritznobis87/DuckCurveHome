"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { RoomLive, RoomShift } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { Note } from "@/components/reports/ReportShell";
import { hhmm } from "@/lib/format";

/**
 * Die Automatik: vor dem Preishoch ein halbes Grad mehr, danach wieder dein Wert.
 *
 * **Dies ist die einzige Stelle, an der Duck Curve Home von sich aus in die Wohnung greift.**
 * Alles andere zeigt an oder tut, was jemand drückt. Deshalb steht hier nicht nur ein Schalter,
 * sondern auch, was die Automatik darf, was sie gerade vorhat und was sie zuletzt getan hat - und
 * deshalb ist sie aus, bis jemand sie einschaltet.
 *
 * **Sie hebt an, sie senkt nicht.** Während des Preishochs steht der Sollwert wieder auf deinem
 * Wert; der Raum ist dann von selbst darüber und fordert nichts an, bis er sich abgekühlt hat.
 * Das ist der ganze Trick, und er braucht kein Absenken.
 *
 * **Wer von Hand stellt, hat recht.** Weicht der Sollwert von dem ab, den die Automatik
 * geschrieben hat, zieht sie sich für diesen Raum zurück - zwölf Stunden lang. Gegen einen
 * Menschen zu regeln ist das Schlimmste, was sie tun könnte.
 */
const AKTUALISIEREN_MS = 60_000;

function de(x: number, stellen = 1): string {
  return x.toFixed(stellen).replace(".", ",");
}

function Knopf({ an, kind, onClick, disabled }: { an: boolean; kind: string; onClick: () => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-pressed={an}
      className="rounded-[3px] border px-3 py-1.5 text-[13px] transition-colors disabled:opacity-50"
      style={{
        borderColor: an ? "var(--amber)" : "var(--line-2)",
        color: an ? "var(--petrol)" : "var(--text-2)",
        background: an ? "var(--amber)" : "transparent",
      }}
    >
      {kind}
    </button>
  );
}

export function Automatik({ rooms, readOnly }: { rooms: RoomLive[]; readOnly: boolean }) {
  const [stand, setStand] = useState<RoomShift | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, setLaeuft] = useState(false);

  const holen = useCallback(async () => {
    try {
      setStand(await api.roomsAutomatik());
      setFehler(null);
    } catch {
      setFehler("Die Automatik konnte nicht gelesen werden.");
    }
  }, []);

  useEffect(() => {
    void holen();
    const t = setInterval(() => void holen(), AKTUALISIEREN_MS);
    return () => clearInterval(t);
  }, [holen]);

  const stellen = async (patch: Parameters<typeof api.setRoomsAutomatik>[0]) => {
    setLaeuft(true);
    try {
      setStand(await api.setRoomsAutomatik(patch));
      setFehler(null);
    } catch (e) {
      setFehler(e instanceof Error ? e.message : "Das hat nicht geklappt.");
    } finally {
      setLaeuft(false);
    }
  };

  if (!stand) return null;
  const an = stand.enabled;
  const dabei = new Set(stand.rooms ?? []);
  const angehoben = (stand.active ?? []).filter((r) => r.offset_k !== 0);
  const ruhend = (stand.active ?? []).filter((r) => r.paused_until);

  return (
    <Card style={{ padding: 16, gap: 12 }}>
      <CardHead
        title="Automatik: vor dem Preishoch vorladen"
        right={
          <span className="mono text-[11px]" style={{ color: an ? "var(--amber)" : "var(--text-3)" }}>
            {an ? `an · höchstens ${de(stand.delta_k)} K` : "aus"}
          </span>
        }
      />

      <div className="flex flex-wrap items-center gap-3">
        <Knopf an={an} kind={an ? "Ausschalten" : "Einschalten"} onClick={() => void stellen({ enabled: !an })} disabled={readOnly || laeuft} />
        <span className="text-[13px] leading-[1.5] text-text-2">{stand.reason_de}</span>
      </div>

      {an ? (
        <div className="flex flex-col gap-2">
          <span className="kicker" style={{ fontSize: 11 }}>Diese Räume machen mit</span>
          <div className="flex flex-wrap gap-2">
            {rooms.map((r) => {
              const drin = dabei.has(r.id);
              return (
                <Knopf
                  key={r.id}
                  an={drin}
                  kind={r.name}
                  disabled={readOnly || laeuft}
                  onClick={() =>
                    void stellen({
                      rooms: drin ? [...dabei].filter((x) => x !== r.id) : [...dabei, r.id],
                    })
                  }
                />
              );
            })}
          </div>
        </div>
      ) : null}

      {angehoben.length ? (
        <div className="flex flex-col gap-1 text-[13px]">
          <span className="kicker" style={{ fontSize: 11 }}>Gerade angehoben</span>
          {angehoben.map((r) => (
            <span key={r.room_id} className="flex justify-between gap-3">
              <span className="text-text-2">{r.name}</span>
              <span className="mono text-text-1">
                {de(r.base_setpoint_c)} auf {de(r.written_setpoint_c)} °C
              </span>
            </span>
          ))}
        </div>
      ) : null}

      {ruhend.length ? (
        <div className="flex flex-col gap-1 text-[13px]">
          {ruhend.map((r) => (
            <span key={r.room_id} style={{ color: "var(--amber-soft)" }}>
              {r.name}: von Hand gestellt, die Automatik lässt den Raum bis {hhmm(r.paused_until)} in Ruhe.
            </span>
          ))}
        </div>
      ) : null}

      {stand.note_de ? <Note>{stand.note_de}</Note> : null}
      {fehler ? <Note>{fehler}</Note> : null}

      {(stand.log ?? []).length ? (
        <details className="text-[12px] leading-[1.5] text-text-3">
          <summary className="cursor-pointer text-text-2">Was die Automatik getan hat</summary>
          <ul className="mt-1.5 flex list-none flex-col gap-1 pl-0">
            {(stand.log ?? []).map((e) => (
              <li key={`${e.at}-${e.text_de}`} className="flex gap-3">
                <span className="mono shrink-0">{hhmm(e.at)}</span>
                <span>{e.text_de}</span>
              </li>
            ))}
          </ul>
        </details>
      ) : null}

      <Note>
        Angehoben wird höchstens um {de(stand.delta_k)} K und nur, wenn das Preishoch mindestens{" "}
        {de(stand.min_spread_ct, 0)} ct über den Stunden davor liegt. Unter deinen Wert geht die
        Automatik nie. Steht ein Fenster offen, lädt sie nicht vor. Wer von Hand stellt, hat recht:
        Dann zieht sie sich für diesen Raum zwölf Stunden zurück.
      </Note>
    </Card>
  );
}
