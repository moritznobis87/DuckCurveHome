"use client";

import { useEffect, useState } from "react";
import { C } from "@/components/charts/palette";
import { Card, CardHead } from "@/components/ui/Card";
import { Methode } from "@/components/ui/Methode";
import { Stat } from "@/components/ui/Stat";
import { api } from "@/lib/api/client";
import type { Kontaktwirkung } from "@/lib/api/models";
import { Antwortfaecher, MIN_FUER_BAND } from "./Antwortfaecher";
import { Ereignisraster } from "./Ereignisraster";
import { prozentZahl, spanne } from "./wirkung";

/**
 * Die Seite „Wirkung": was der Freigabekontakt K1 auslöst.
 *
 * Schritt 3 des Zwillingsentwurfs. Der Planer schließt K1 in den günstigen Stunden und rechnet
 * damit, dass die Wärmepumpe dann läuft. Ob sie das tut, entscheidet ihre eigene Regelung - der
 * Kontakt ist eine Anforderung, keine Sperre. Diese Seite stellt beide Reihen zum ersten Mal
 * gegeneinander.
 *
 * **Von oben nach unten vom Urteil zum Einzelfall.** Zuerst der Satz und die beiden Quoten mit
 * ihren Bereichen, dann der Fächer mit der Mitte und der Streuung aller Antworten, zuletzt das
 * Raster mit jedem einzelnen Schließvorgang. Wer dem Satz nicht glaubt, kann bis zur Minute
 * hinunter nachsehen, worauf er steht.
 *
 * **Das Urteil fällt der Server.** Hier wird nichts verglichen und nichts gerundet, was eine
 * Aussage ändern könnte; die Oberfläche zeichnet.
 */

const TAGE = [7, 30, 90] as const;

const URTEIL: Record<string, string> = {
  offen: "noch offen",
  wirkt: "die Maschine folgt",
  kein_unterschied: "kein gesicherter Unterschied",
  seltener: "seltener als sonst",
};

/** Die Spur der Quoten: 0 bis 100 Prozent zwischen diesen beiden Stellen des Bildes. */
const X0 = 92;
const X1 = 332;

function x(anteil: number): number {
  return X0 + Math.min(1, Math.max(0, anteil)) * (X1 - X0);
}

/**
 * Eine Zeile des Quotenvergleichs: der Punkt ist die beobachtete Quote, der Balken ihr Bereich.
 *
 * Die Schrift steht in Textfarben; die Farbe gehört Punkt und Balken. Ohne Quote bleibt die Spur
 * leer, und daneben steht, warum.
 */
function Quote({ y, name, farbe, quote, lo, hi, leer }: { y: number; name: string; farbe: string; quote: number | null; lo: number | null; hi: number | null; leer: string }) {
  return (
    <g>
      <text x={0} y={y + 4} className="wk-q-name">
        {name}
      </text>
      <line x1={X0} x2={X1} y1={y} y2={y} stroke="rgba(255,255,255,.14)" strokeWidth={1} />
      {quote === null ? (
        <text x={X0 + 6} y={y - 8} className="wk-q-klein">
          {leer}
        </text>
      ) : (
        <>
          {lo !== null && hi !== null ? <rect x={x(lo)} y={y - 5} width={Math.max(x(hi) - x(lo), 2)} height={10} rx={5} fill={farbe} opacity={0.38} /> : null}
          {/* Der Ring in der Kartenfarbe hält den Punkt vom Balken ab. */}
          <circle cx={x(quote)} cy={y} r={6} fill={farbe} stroke="var(--surface-2)" strokeWidth={2} />
          <text x={X1 + 14} y={y + 1} className="wk-q-zahl">
            {prozentZahl(quote)} %
          </text>
          {lo !== null && hi !== null ? (
            <text x={X1 + 14} y={y + 15} className="wk-q-klein">
              {prozentZahl(lo)} bis {prozentZahl(hi)} %
            </text>
          ) : null}
        </>
      )}
    </g>
  );
}

function Quotenvergleich({ d }: { d: Kontaktwirkung }) {
  const v = d.vergleich;
  return (
    <figure className="wk-quoten">
      <svg viewBox="0 0 444 132" role="img" aria-label={`Anlauf binnen ${d.folge_min} Minuten: mit K1 ${prozentZahl(d.quote)} Prozent, ohne K1 ${prozentZahl(v.quote)} Prozent.`}>
        {[0, 0.5, 1].map((a) => (
          <g key={a}>
            <line x1={x(a)} x2={x(a)} y1={14} y2={104} stroke="rgba(255,255,255,.09)" strokeWidth={1} />
            <text x={x(a)} y={120} textAnchor="middle" className="wk-q-achse">
              {a * 100} %
            </text>
          </g>
        ))}
        <Quote y={38} name="mit K1" farbe={C.heatPump} quote={d.quote ?? null} lo={d.quote_lo ?? null} hi={d.quote_hi ?? null} leer="kein auswertbarer Schließvorgang" />
        <Quote y={82} name="ohne K1" farbe={C.mist} quote={v.quote ?? null} lo={v.quote_lo ?? null} hi={v.quote_hi ?? null} leer="kein Vergleich zur selben Tageszeit" />
      </svg>
      <figcaption>
        Anlauf binnen {d.folge_min} Minuten bei stehender Maschine. Punkt: beobachtete Quote. Balken: der Bereich, in dem die wahre Quote mit 95 Prozent
        Sicherheit liegt. Ein Urteil gibt es erst, wenn sich die Balken nicht überlappen.
      </figcaption>
    </figure>
  );
}

function minuten(x: number | null | undefined): string {
  return x === null || x === undefined ? "-" : x.toLocaleString("de-DE", { maximumFractionDigits: 0 });
}

export function Wirkung() {
  const [tage, setTage] = useState<number>(30);
  const [d, setD] = useState<Kontaktwirkung | null>(null);
  const [laden, setLaden] = useState(true);
  const [fehler, setFehler] = useState<string | null>(null);

  useEffect(() => {
    let lebt = true;
    setLaden(true);
    api
      .kontaktwirkung(tage)
      .then((antwort) => {
        if (!lebt) return;
        setD(antwort);
        setFehler(null);
      })
      .catch((e: unknown) => {
        if (!lebt) return;
        setD(null);
        setFehler(e instanceof Error ? e.message : "Die Auswertung ist gerade nicht zu erreichen.");
      })
      .finally(() => lebt && setLaden(false));
    return () => {
      lebt = false;
    };
  }, [tage]);

  const v = d?.vergleich;
  const nichtGefolgt = d ? d.n_auswertbar - d.gefolgt : 0;

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <CardHead title="Was löst K1 aus?" right={d?.von && d.bis ? <span className="mono text-[12px] text-text-3">{spanne(d.von, d.bis)}</span> : null} />
        <div className="mb-4 flex flex-wrap items-center gap-2">
          <span className="text-[12px] text-text-3">Zeitraum</span>
          {TAGE.map((t) => (
            <button key={t} type="button" className={`wg-wahl${tage === t ? " wg-wahl-an" : ""}`} onClick={() => setTage(t)} aria-pressed={tage === t}>
              {t} Tage
            </button>
          ))}
          {laden && d ? <span className="text-[12px] text-text-3">wird neu gerechnet</span> : null}
        </div>

        {fehler ? <p className="m-0 text-[13px] text-alert">{fehler}</p> : null}
        {laden && !d ? <p className="m-0 text-[13px] text-text-3">Die Schließvorgänge werden gesucht.</p> : null}

        {d ? (
          <div className="wk-kopf">
            <div>
              <p className="kicker m-0 mb-2">Urteil · {URTEIL[d.urteil] ?? d.urteil}</p>
              <p className="wk-urteil">{d.urteil_de}</p>
            </div>
            <Quotenvergleich d={d} />
          </div>
        ) : null}
      </Card>

      {d ? (
        <div className="kpi-handy grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
          <Stat
            label="Schließvorgänge"
            value={String(d.n)}
            hint={d.n === 0 ? "im Zeitraum keiner" : `${d.n_auswertbar} bei stehender Maschine, ${d.n_lief_schon} bei laufender`}
          />
          <Stat
            label="danach angelaufen"
            value={prozentZahl(d.quote)}
            unit={d.quote == null ? undefined : "%"}
            hint={d.n_auswertbar ? `${d.gefolgt} von ${d.n_auswertbar} binnen ${d.folge_min} Minuten, ${nichtGefolgt} nicht` : "kein auswertbarer Schließvorgang"}
          />
          <Stat
            label="ohne K1 angelaufen"
            value={prozentZahl(v?.quote)}
            unit={v?.quote == null ? undefined : "%"}
            hint={v?.quote == null ? "kein Vergleich zur selben Tageszeit" : `zur selben Tageszeit, aus ${v.n_gleiche_stunde} Vergleichsmomenten`}
          />
          <Stat
            label="Verzögerung"
            value={minuten(d.verzoegerung_median_min)}
            unit={d.verzoegerung_median_min == null ? undefined : "min"}
            hint="Median vom Schließen bis zum Anlauf"
          />
          <Stat
            label="Nachlauf"
            value={minuten(d.nachlauf_median_min)}
            unit={d.nachlauf_median_min == null ? undefined : "min"}
            hint={d.nachlauf_n ? `Median nach dem Öffnen, ${d.nachlauf_n === 1 ? "1 Fall" : `${d.nachlauf_n} Fälle`}` : "kein Öffnen bei laufender Maschine"}
          />
        </div>
      ) : null}

      {d && d.n_auswertbar > 0 ? (
        <Card>
          <CardHead title="Antwortfächer" right={`${d.n_auswertbar} Schließvorgänge bei stehender Maschine, am Nullpunkt übereinandergelegt`} />
          <Antwortfaecher daten={d} />
          <ul className="uhr-legende wk-legende">
            <li>
              <span className="uhr-marke wk-marke-linie" style={{ background: C.heatPump, opacity: 0.45 }} />
              jede einzelne Antwort
            </li>
            <li>
              <span className="uhr-marke wk-marke-linie" style={{ background: C.heatPump }} />
              Mittel der Leistung, unten: Anteil angelaufen
            </li>
            {d.n_auswertbar >= MIN_FUER_BAND ? (
              <li>
                <span className="uhr-marke" style={{ background: C.heatPump, opacity: 0.3 }} />
                mittlere Hälfte der Antworten
              </li>
            ) : (
              <li>das Band der mittleren Hälfte erscheint ab {MIN_FUER_BAND} Ereignissen</li>
            )}
            <li>
              <span className="uhr-marke wk-marke-gestrichelt" style={{ borderColor: C.mist }} />
              Anteil angelaufen ohne K1, zur selben Tageszeit
            </li>
          </ul>
        </Card>
      ) : null}

      {d && d.n > 0 ? (
        <Card>
          <CardHead title="Jeder Schließvorgang" right="sortiert nach Verzögerung · eine Zeile öffnet die Wiedergabe dieses Augenblicks" />
          <Ereignisraster daten={d} />
        </Card>
      ) : null}

      {/* Was für diesen Zeitraum gilt, bleibt offen stehen; zugeklappt wäre es verschwiegen. */}
      {d && (d.hinweise_de?.length ?? 0) > 0 ? (
        <Card>
          <CardHead title="Zu diesem Zeitraum" />
          <ul className="wk-hinweise">
            {(d.hinweise_de ?? []).map((h) => (
              <li key={h}>{h}</li>
            ))}
          </ul>
        </Card>
      ) : null}

      {d && (d.methode_de?.length ?? 0) > 0 ? (
        <Methode title="Was die Auswertung kann" kurz="ein Zusammenhang in der Zeit, keine Ursache · Vergleich zur selben Tageszeit">
          <ul>
            {(d.methode_de ?? []).map((m) => (
              <li key={m}>{m}</li>
            ))}
          </ul>
        </Methode>
      ) : null}
    </div>
  );
}
