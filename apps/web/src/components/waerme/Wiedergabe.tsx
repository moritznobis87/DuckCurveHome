"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Schema } from "@/components/anlage/Schema";
import { Card, CardHead } from "@/components/ui/Card";
import { Methode, MethodeAbsatz } from "@/components/ui/Methode";
import { api } from "@/lib/api/client";
import type { AnlageReplay } from "@/lib/api/models";
import { isoToday, istTagIso, langerTag, tagPlus } from "@/lib/day";
import { hhmm } from "@/lib/format";
import { Tagesband } from "./Tagesband";
import { Tagesuhr } from "./Tagesuhr";

/**
 * Die Seite „Wiedergabe": ein vergangener Tag am Anlagenschema, zum Durchfahren.
 *
 * Schritt 10 des Zwillingsentwurfs. Gezeichnet wird **dasselbe** Schema wie auf der Seite
 * „Anlage" - dieselbe Komponente, dieselben Rohre, dasselbe wandernde Licht -, nur bekommt es
 * statt des Augenblicks ein Bild aus der Minutenreihe. Dass es dieselbe Komponente ist, ist die
 * ganze Idee: ein zweites, vereinfachtes Rückblickschema wäre in einer Woche ein anderes Haus.
 *
 * **Drei Ansichten desselben Zeitpunkts, eine Uhr.** Oben das Schema: was in diesem Augenblick
 * floss. Darunter links die Tagesuhr: wo im Tag dieser Augenblick liegt, als Ring zum Anfassen.
 * Rechts das Tagesband: derselbe Tag als Zeile, mit Achsen zum Ablesen. Alle drei hängen an einem
 * einzigen Index, und jede kann ihn verstellen.
 *
 * **Die Uhr der Wiedergabe ist nicht die Wanduhr.** `nowMs` bekommt die Zeit des Bildes, nicht
 * `Date.now()`. Sonst stünde am Schema „läuft seit 7 Stunden", weil es die Laufzeit gegen jetzt
 * rechnet, während das Bild von gestern Mittag ist.
 *
 * **Tag und Uhrzeit stehen in der Adresse** (`?day=2026-11-08&t=14`). So führt ein Klick in die
 * Jahreskarte genau hierher, und eine Stelle lässt sich weitergeben, statt beschrieben zu werden.
 */

/** Bilder je Sekunde. Bei 5-Minuten-Schritten ist 12 ein Tag in 24 Sekunden. */
const TEMPI = [2, 6, 12, 24] as const;
const SCHRITTE = [1, 5, 15] as const;

/** Deutsche Zahl. Lokal wie auf den Nachbarseiten; `lib/format` hat nur fertige Einheiten. */
function de(x: number, n = 1): string {
  return x.toLocaleString("de-DE", { minimumFractionDigits: n, maximumFractionDigits: n });
}

/**
 * Heute, und jede Uhrzeit dieser Seite, in der Zeit des Hauses und nicht des Geräts.
 *
 * Die erste Fassung formatierte mit der Zeitzone des Browsers. Auf einem Gerät in einer anderen
 * Zone zeigte die Mitte der Tagesuhr dann eine Stunde, die nicht zu ihrem eigenen Zifferblatt
 * passte: das Zifferblatt zählt vom Tagesbeginn des Hauses, die Schrift zählte vom Gerät aus.
 * `lib/format` und `lib/day` lösen das längst für die ganze App; hier wurden sie übergangen.
 */
const heute = isoToday;
const uhr = hhmm;

function ruhigGewuenscht(): boolean {
  return typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export function Wiedergabe() {
  const router = useRouter();
  const params = useSearchParams();
  const tagAusAdresse = params.get("day");
  const stundeAusAdresse = params.get("t");
  const tag = istTagIso(tagAusAdresse) && tagAusAdresse <= heute() ? tagAusAdresse : heute();

  const [stepMin, setStepMin] = useState<number>(5);
  const [daten, setDaten] = useState<AnlageReplay | null>(null);
  const [laden, setLaden] = useState(true);
  const [fehler, setFehler] = useState<string | null>(null);
  const [i, setI] = useState(0);
  const [spielt, setSpielt] = useState(false);
  const [tempo, setTempo] = useState<number>(12);
  const [ruhig, setRuhig] = useState(false);

  useEffect(() => setRuhig(ruhigGewuenscht()), []);

  /** Den Tag wechseln heißt die Adresse wechseln; die Uhrzeit aus einem Sprung gilt dann nicht mehr. */
  const zuTag = useCallback(
    (neu: string) => {
      router.replace(`/waerme/wiedergabe?day=${neu}`, { scroll: false });
    },
    [router],
  );

  // Die gewünschte Stunde nur einmal je Ladung anwenden. In einer Referenz, damit ein späteres
  // Neuzeichnen den Spielkopf nicht wieder auf die Stunde aus der Adresse zurückwirft.
  const zielStunde = useRef<number | null>(null);
  useEffect(() => {
    const h = stundeAusAdresse === null ? NaN : Number(stundeAusAdresse);
    zielStunde.current = Number.isFinite(h) && h >= 0 && h < 25 ? h : null;
  }, [stundeAusAdresse, tag]);

  useEffect(() => {
    let lebt = true;
    setLaden(true);
    setSpielt(false);
    api
      .anlageWiedergabe(tag, stepMin)
      .then((d) => {
        if (!lebt) return;
        setDaten(d);
        // Der Sprung aus der Adresse: das erste Bild an oder nach der gewünschten Stunde, gezählt
        // ab dem Tagesbeginn der Antwort und nicht ab der Mitternacht des Browsers.
        let start = 0;
        if (zielStunde.current !== null) {
          const ziel = new Date(d.von).getTime() + zielStunde.current * 3_600_000;
          const k = d.frames.findIndex((f) => new Date(f.at).getTime() >= ziel);
          start = k >= 0 ? k : Math.max(d.frames.length - 1, 0);
          zielStunde.current = null;
        }
        setI(start);
        setFehler(null);
      })
      .catch((e: unknown) => {
        if (!lebt) return;
        setDaten(null);
        setFehler(e instanceof Error ? e.message : "Die Wiedergabe ist gerade nicht zu erreichen.");
      })
      .finally(() => lebt && setLaden(false));
    return () => {
      lebt = false;
    };
  }, [tag, stepMin]);

  const anzahl = daten?.frames.length ?? 0;

  // Der Abspieler. Am Ende hält er an, statt von vorn zu beginnen: ein Tag, der unbemerkt in den
  // nächsten Durchlauf rutscht, lässt einen zweimal dasselbe für zwei Tage halten.
  useEffect(() => {
    if (!spielt || anzahl === 0) return;
    const t = setInterval(() => {
      setI((alt) => {
        if (alt + 1 >= anzahl) {
          setSpielt(false);
          return anzahl - 1;
        }
        return alt + 1;
      });
    }, 1000 / tempo);
    return () => clearInterval(t);
  }, [spielt, tempo, anzahl]);

  const springen = useCallback(
    (ziel: number) => {
      setI(Math.max(0, Math.min(anzahl - 1, ziel)));
    },
    [anzahl],
  );

  /** Ein Sprung von Hand hält die Wiedergabe an: wer hinfasst, will hinsehen. */
  const greifen = useCallback(
    (ziel: number) => {
      setSpielt(false);
      springen(ziel);
    },
    [springen],
  );

  // Tastatur: Leertaste spielt, Pfeile gehen Bild für Bild, Pos1 und Ende an die Ränder. Nicht auf
  // dem Fenster, sondern auf dem Abschnitt: sonst verschluckt die Seite die Leertaste auch dann,
  // wenn jemand in einem Eingabefeld steht.
  const buehne = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = buehne.current;
    if (!el) return;
    const aufTaste = (e: KeyboardEvent) => {
      if (e.key === " ") {
        e.preventDefault();
        setSpielt((s) => !s);
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        greifen(i + 1);
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        greifen(i - 1);
      } else if (e.key === "Home") {
        greifen(0);
      } else if (e.key === "End") {
        greifen(anzahl - 1);
      }
    };
    el.addEventListener("keydown", aufTaste);
    return () => el.removeEventListener("keydown", aufTaste);
  }, [i, anzahl, greifen]);

  const bild = daten?.frames[i] ?? null;
  const zeitMs = bild ? new Date(bild.at).getTime() : 0;
  const vollstaendig = daten ? daten.frames.length >= daten.erwartet : true;

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <CardHead
          title="Wiedergabe"
          right={
            daten ? (
              <span className="mono text-[12px] text-text-3">
                {daten.frames.length} von {daten.erwartet} Bildern · {daten.step_min}-Minuten-Schritt
              </span>
            ) : null
          }
        />

        <div className="mb-3 flex flex-wrap items-center gap-2">
          <button type="button" className="wg-knopf" onClick={() => zuTag(tagPlus(tag, -1))} aria-label="Tag zurück">
            ‹
          </button>
          <input type="date" className="wg-datum mono" value={tag} max={heute()} onChange={(e) => e.target.value && zuTag(e.target.value)} />
          <button type="button" className="wg-knopf" onClick={() => zuTag(tagPlus(tag, 1))} disabled={tag >= heute()} aria-label="Tag vor">
            ›
          </button>
          <span className="text-[13px] text-text-2">{langerTag(tag)}</span>
          <span className="ml-auto text-[12px] text-text-3">Schritt</span>
          {SCHRITTE.map((s) => (
            <button key={s} type="button" className={`wg-wahl${stepMin === s ? " wg-wahl-an" : ""}`} onClick={() => setStepMin(s)}>
              {s} min
            </button>
          ))}
        </div>

        {fehler ? <p className="m-0 text-[13px] text-alert">{fehler}</p> : null}
        {laden && !daten ? <p className="m-0 text-[13px] text-text-3">Der Tag wird geholt.</p> : null}
        {daten && anzahl === 0 && !laden ? <p className="m-0 text-[13px] text-text-3">{daten.hinweise_de?.[0]}</p> : null}

        {bild && daten ? (
          <div
            ref={buehne}
            tabIndex={0}
            className="wg-buehne"
            aria-label="Wiedergabe des Anlagenschemas. Leertaste spielt, Pfeiltasten gehen Bild für Bild."
          >
            <div className="anlage-buehne">
              <div className="anlage-innen">
                <div className="anlage-scroll">
                  {/* Die Uhr der Wiedergabe: die Zeit des Bildes, nicht die Wanduhr. */}
                  <Schema a={bild} nowMs={zeitMs} ruhig={ruhig} />
                </div>
              </div>
            </div>

            <div className="wg-leiste">
              <button type="button" className="wg-spiel" onClick={() => setSpielt((s) => !s)} aria-label={spielt ? "Pause" : "Abspielen"}>
                {spielt ? "❚❚" : "▶"}
              </button>
              <span className="mono wg-uhr">{uhr(bild.at)}</span>
              <input
                type="range"
                className="wg-schieber"
                min={0}
                max={Math.max(anzahl - 1, 0)}
                value={i}
                onChange={(e) => greifen(Number(e.target.value))}
                aria-label="Zeitpunkt"
                aria-valuetext={uhr(bild.at)}
              />
              <span className="mono wg-zaehler">
                {i + 1}/{anzahl}
              </span>
              {TEMPI.map((t) => (
                <button
                  key={t}
                  type="button"
                  className={`wg-wahl${tempo === t ? " wg-wahl-an" : ""}`}
                  onClick={() => setTempo(t)}
                  aria-label={`Tempo ${t} Bilder je Sekunde`}
                >
                  {t}×
                </button>
              ))}
            </div>

            {/* Uhr und Band nebeneinander: links zum Zurechtfinden, rechts zum Ablesen. Auf
                schmalen Schirmen stehen sie untereinander, die Uhr zuerst. */}
            <div className="wg-tag">
              <Tagesuhr daten={daten} index={i} onSprung={greifen} />
              <div className="wg-tag-band">
                <Tagesband daten={daten} zeitMs={zeitMs} onSprung={greifen} />
              </div>
            </div>
          </div>
        ) : null}
      </Card>

      {/* Was für diesen Tag gilt, bleibt offen stehen; zugeklappt wäre es verschwiegen. */}
      {bild && ((daten?.hinweise_de?.length ?? 0) > 0 || !vollstaendig) ? (
        <Card>
          <CardHead title="Zu diesem Tag" />
          <ul className="wk-hinweise">
            {(daten?.hinweise_de ?? []).map((h) => (
              <li key={h}>{h}</li>
            ))}
            {!vollstaendig ? (
              <li>
                Die fehlenden Bilder sind als Lücke zu sehen: der Ring bleibt dort offen, und im Band reißt die Linie ab. Überbrückt wird nichts, denn ein ruhiges Haus und ein blindes
                Messsystem sähen im Schema gleich aus.
              </li>
            ) : null}
          </ul>
        </Card>
      ) : null}

      {bild ? (
        <Methode title="Was dieses Bild ist" kurz="dasselbe Schema wie unter Anlage, aus der Minutenreihe nachgebaut · Leertaste spielt, Pfeile gehen Bild für Bild">
          <MethodeAbsatz>
            Dasselbe Schema wie in der Ansicht <span className="mono">Jetzt</span>, nur aus der Minutenreihe nachgebaut. Es gibt genau eine Zusammensetzung des Bildes; die Wiedergabe stellt
            ihr die Eingänge von {uhr(bild.at)} hin, der Augenblick die von jetzt. Deshalb kann hier nichts stehen, was dort nicht stünde, und nichts fehlen, was dort steht.
          </MethodeAbsatz>
          <MethodeAbsatz>
            Die Uhr zeigt den Tag als Ring: außen der Preis, dann die Sonne, dann was der Fahrplan für die Wärmepumpe vorsah, und innen, was sie tat. Wo der Umriss der Absicht steht und
            darunter nichts gefüllt ist, wollte der Fahrplan und die Maschine nicht. Das Band rechts zeigt dasselbe mit Achsen. Die Uhr lässt sich anfassen und drehen.
          </MethodeAbsatz>
          <MethodeAbsatz>
            Tastatur: Leertaste spielt und hält, Pfeile gehen Bild für Bild, Pos1 und Ende springen an die Ränder. Bei {de(daten?.step_min ?? 5, 0)} Minuten Schritt und {tempo}× läuft der Tag
            in {de(anzahl / tempo, 0)} Sekunden durch.
          </MethodeAbsatz>
        </Methode>
      ) : null}
    </div>
  );
}
