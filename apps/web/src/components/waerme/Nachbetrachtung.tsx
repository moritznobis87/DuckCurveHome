"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { C } from "@/components/charts/palette";
import { Card, CardHead } from "@/components/ui/Card";
import { api } from "@/lib/api/client";
import type { Nachbetrachtung as Daten } from "@/lib/api/models";
import { isoToday, istTagIso, langerTag, tagPlus } from "@/lib/day";
import { hhmm } from "@/lib/format";
import { Kostentreppe } from "./Kostentreppe";
import { euro, zeilen } from "./nachbetrachtung";
import { KURZ, strich, Tagesvergleich } from "./Tagesvergleich";
import { kurzDatum } from "./wirkung";

/**
 * Die Seite „Nachbetrachtung": ein Tag in Euro.
 *
 * Schritt 9 des Zwillingsentwurfs. Der Fahrplan sagt, was vorgesehen ist; die Wiedergabe zeigt,
 * was geschah. Hier steht, was der Unterschied gekostet hat, und woran er lag: an der Prognose,
 * am Nachführen des Fahrplans über den Tag, oder an der Maschine, die den Kontakt nur als
 * Anforderung nimmt.
 *
 * **Von oben nach unten vom Satz zur Viertelstunde.** Zuerst der Satz über den Tag und die
 * Kostentreppe, die ihn zerlegt. Dann der Tagesvergleich: wann jede Linie Strom zog und wo das
 * Geld auseinanderlief. Zuletzt die Zahlen als Tabelle, für den, der nachrechnen will.
 *
 * **Gerechnet und beurteilt wird im Dienst.** Hier wird nichts bewertet; jede Zahl und jeder Satz
 * kommt fertig an. Der Tag steht in der Adresse, damit sich eine Stelle weitergeben lässt.
 */

function de(x: number | null | undefined, n = 1): string {
  return x === null || x === undefined ? "-" : x.toLocaleString("de-DE", { minimumFractionDigits: n, maximumFractionDigits: n });
}

function Marke({ linie }: { linie: string }) {
  const s = strich(linie);
  return <span className="nb-marke" style={{ borderTop: `${Math.max(2, Math.round(s.width))}px ${s.type} ${s.color}` }} />;
}

export function Nachbetrachtung() {
  const router = useRouter();
  const params = useSearchParams();
  const ausAdresse = params.get("day");
  const heute = isoToday();
  // Ohne Angabe gestern: der heutige Tag ist nie zu Ende, und die Frage „was hat es gekostet"
  // meint meist einen abgeschlossenen.
  const tag = istTagIso(ausAdresse) && ausAdresse <= heute ? ausAdresse : tagPlus(heute, -1);

  const [d, setD] = useState<Daten | null>(null);
  const [laden, setLaden] = useState(true);
  const [fehler, setFehler] = useState<string | null>(null);

  const zuTag = useCallback((neu: string) => router.replace(`/waerme/nachbetrachtung?day=${neu}`, { scroll: false }), [router]);

  useEffect(() => {
    let lebt = true;
    setLaden(true);
    api
      .nachbetrachtung(tag)
      .then((antwort) => {
        if (!lebt) return;
        setD(antwort);
        setFehler(null);
      })
      .catch((e: unknown) => {
        if (!lebt) return;
        setD(null);
        setFehler(e instanceof Error ? e.message : "Die Nachbetrachtung ist gerade nicht zu erreichen.");
      })
      .finally(() => lebt && setLaden(false));
    return () => {
      lebt = false;
    };
  }, [tag]);

  // Solange ein anderer Tag geladen wird, steht der alte nicht mehr da: seine Zahlen unter dem
  // neuen Datum wären falsch, auch für zwei Sekunden.
  const daten = d && d.day === tag ? d : null;
  const linien = daten ? zeilen(daten) : [];
  const fehlend = (daten?.linien ?? []).filter((l) => !l.verfuegbar);
  const saetze = (daten?.abstaende ?? []).filter((a) => a.eur != null && a.satz_de);
  const gesamt = daten?.zeiten?.length ?? 0;

  return (
    <div className="flex flex-col gap-4">
      <Card>
        <CardHead
          title="Was hat der Tag gekostet?"
          right={
            daten ? (
              <span className="mono text-[12px] text-text-3">
                {daten.n_verglichen} von {gesamt} Viertelstunden verglichen
                {daten.erster_plan_erstellt ? ` · erster Fahrplan vom ${kurzDatum(daten.erster_plan_erstellt)} ${hhmm(daten.erster_plan_erstellt)}` : ""}
              </span>
            ) : null
          }
        />
        <div className="mb-4 flex flex-wrap items-center gap-2">
          <button type="button" className="wg-knopf" onClick={() => zuTag(tagPlus(tag, -1))} aria-label="Tag zurück">
            ‹
          </button>
          <input type="date" className="wg-datum mono" value={tag} max={heute} onChange={(e) => e.target.value && zuTag(e.target.value)} aria-label="Tag" />
          <button type="button" className="wg-knopf" onClick={() => zuTag(tagPlus(tag, 1))} disabled={tag >= heute} aria-label="Tag vor">
            ›
          </button>
          <span className="text-[13px] text-text-2">{langerTag(tag)}</span>
          <Link href={`/waerme/wiedergabe?day=${tag}`} className="ml-auto text-[12px] text-text-3 underline decoration-dotted underline-offset-4">
            diesen Tag in der Wiedergabe ansehen
          </Link>
        </div>

        {fehler ? <p className="m-0 text-[13px] text-alert">{fehler}</p> : null}
        {laden && !daten ? <p className="m-0 text-[13px] text-text-3">Der Tag wird bewertet. Der Vergleichslauf mit perfekter Voraussicht braucht einige Sekunden.</p> : null}

        {daten ? (
          <div className="nb-kopf">
            <div>
              <p className="wk-urteil">{daten.satz_de}</p>
              {saetze.length > 0 ? (
                <ul className="nb-saetze">
                  {saetze.map((a) => (
                    <li key={a.key}>
                      <span className="kicker">{a.name_de}</span>
                      {a.satz_de}
                    </li>
                  ))}
                </ul>
              ) : null}
              {/* Der Vergleich ohne Preisblick: gerechnet auf der Kostenseite, hier nur genannt. */}
              {daten.verschieben_de ? (
                <p className="nb-verweis">
                  <span className="kicker">Ohne Preisblick</span>
                  {daten.verschieben_de}{" "}
                  <Link href={`/geld?period=day&anchor=${tag}`} className="text-amber">
                    Zur Rechnung ›
                  </Link>
                </p>
              ) : null}
            </div>
            <Kostentreppe d={daten} />
          </div>
        ) : null}
      </Card>

      {daten && daten.n_verglichen > 0 ? (
        <Card>
          <CardHead title="Der Tag, Linie für Linie" right="oben die Umstände, in der Mitte wann jede Linie Strom zieht, unten was dabei auflief" />
          <Tagesvergleich d={daten} />
          <ul className="uhr-legende wk-legende">
            {linien.map((l) => (
              <li key={l.key}>
                <Marke linie={l.key} />
                {KURZ[l.key] ?? l.name_de}
              </li>
            ))}
            <li>
              <span className="nb-stufen" aria-hidden="true">
                {[0.28, 0.5, 0.75, 1].map((o) => (
                  <span key={o} style={{ background: C.heatPump, opacity: o }} />
                ))}
              </span>
              Strom der Wärmepumpe je Viertelstunde, bis {de(daten.wp_kw / 4, 2)} kWh
            </li>
            {daten.hat_ofen ? (
              <li>
                <span className="uhr-marke wk-marke-strich" style={{ background: C.stove }} />
                Ofen brennt
              </li>
            ) : null}
          </ul>
        </Card>
      ) : null}

      {daten && daten.n_verglichen > 0 ? (
        <Card>
          <CardHead title="Die Linien in Zahlen" right={`über die ${daten.n_verglichen} verglichenen Viertelstunden`} />
          <div className="nb-tabelle-rahmen">
            <table className="nb-tabelle">
              <thead>
                <tr>
                  <th scope="col">Linie</th>
                  <th scope="col">Kosten</th>
                  {daten.hat_ofen ? <th scope="col">davon Ofen</th> : null}
                  <th scope="col">Strom</th>
                  <th scope="col" title="Was die Kilowattstunde Strom dieser Linie im Mittel gekostet hat. Hängt nicht an der Menge.">
                    im Mittel
                  </th>
                  <th scope="col">Wärmepumpe</th>
                  {daten.hat_ofen ? <th scope="col">Ofen</th> : null}
                </tr>
              </thead>
              <tbody>
                {(daten.linien ?? [])
                  .filter((l) => l.verfuegbar)
                  .map((l) => (
                    <tr key={l.key}>
                      <th scope="row">
                        {l.name_de}
                        {l.geschaetzt ? <span className="nb-klein"> · geschätzt</span> : null}
                      </th>
                      <td>{euro(l.eur)}</td>
                      {daten.hat_ofen ? <td>{euro(l.ofen_eur)}</td> : null}
                      <td>{l.wp_kwh == null ? "-" : `${de(l.wp_kwh)} kWh`}</td>
                      <td>{l.ct_je_kwh == null ? "-" : `${de(l.ct_je_kwh)} ct/kWh`}</td>
                      <td>{l.wp_h == null ? "-" : `${de(l.wp_h)} h`}</td>
                      {daten.hat_ofen ? <td>{l.ofen_h == null ? "-" : `${de(l.ofen_h)} h`}</td> : null}
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
          {daten.standby_eur != null && daten.standby_kwh != null && daten.standby_kwh >= 0.05 ? (
            <p className="nb-fuss">
              Daneben, in keiner Linie: die Grundlast der Anlage im Stillstand, {de(daten.standby_kwh)} kWh für {euro(daten.standby_eur)}.
            </p>
          ) : null}
          {fehlend.length > 0 ? (
            <ul className="nb-fehlend">
              {fehlend.map((l) => (
                <li key={l.key}>
                  <span className="kicker">{l.name_de} fehlt</span>
                  {l.grund_de}
                </li>
              ))}
            </ul>
          ) : null}
        </Card>
      ) : null}

      {daten && (daten.hinweise_de?.length ?? 0) > 0 ? (
        <Card>
          <CardHead title="Wie gerechnet wird, und was die Zahlen nicht sagen" />
          <ul className="wk-hinweise">
            {/* Die Gründe fehlender Linien stehen schon in der Tabelle; hier nicht noch einmal. */}
            {(daten.hinweise_de ?? [])
              .filter((h) => !h.startsWith("Die Linie „"))
              .map((h) => (
                <li key={h}>{h}</li>
              ))}
          </ul>
        </Card>
      ) : null}
    </div>
  );
}
