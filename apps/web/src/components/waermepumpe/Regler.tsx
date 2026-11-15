"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { ApiError, api } from "@/lib/api/client";
import type { ReglerEinstellung, ReglerEinstellungen } from "@/lib/api/models";
import { Fader } from "./Fader";
import { Heizkurve, type Stunde } from "./Heizkurve";
import { type Entwurf, aenderungen, gelesen, sichtbar, sperre, standText, wertText, zahlText } from "./regler";

/**
 * Der Regler der Wärmepumpe zum Einstellen (15.11.2026, Wunsch des Hausherrn: eine eigene Seite,
 * auf der sich die Einstellungen des Geräts grafisch verstellen lassen, die Heizkurve als Kurve
 * zum Anfassen und die Zahlen wie an einem Mischpult).
 *
 * Oben die Heizkurve mit ihren Griffen, darunter das Pult: ein Kanalzug je Zahl, Schalter für
 * alles, was nur Stufen kennt. Was jemand bewegt, ist zunächst ein Entwurf. Erst „Übernehmen“
 * schickt die Änderungen ab, nach einer Übersicht, was sich von welchem auf welchen Wert ändert.
 *
 * Drei Dinge hält die Seite streng auseinander: was am Regler steht (gelesen), was jemand
 * einstellen will (Entwurf), und was abgeschickt, aber vom Regler noch nicht zurückgemeldet ist
 * (gesendet). Als gestellt gilt nur, was der Regler selbst meldet.
 */
export function Regler() {
  const [daten, setDaten] = useState<ReglerEinstellungen | null>(null);
  const [stunden, setStunden] = useState<Stunde[]>([]);
  const [fehler, setFehler] = useState<string | null>(null);
  const [entwurf, setEntwurf] = useState<Entwurf>({});
  const [uebersicht, setUebersicht] = useState(false);
  const [laeuft, setLaeuft] = useState(false);
  const [meldungen, setMeldungen] = useState<{ ok: boolean; text: string }[]>([]);

  const laden = useCallback(async () => {
    try {
      setDaten(await api.reglerEinstellungen());
      setFehler(null);
    } catch {
      setFehler("Die Einstellungen sind gerade nicht zu erreichen.");
    }
  }, []);

  const wartet = daten?.werte.some((w) => w.gesendet) ?? false;
  useEffect(() => {
    void laden();
    // Solange ein gesendeter Wert auf seine Rückmeldung wartet, öfter nachsehen.
    const takt = setInterval(() => void laden(), wartet ? 5_000 : 60_000);
    return () => clearInterval(takt);
  }, [laden, wartet]);

  useEffect(() => {
    // Die gemessenen Stunden sind Beiwerk: fehlen sie, steht die Kurve ohne Punkte da.
    api
      .betrieb(14)
      .then((b) => setStunden(b.stunden.map((s) => ({ aussen_c: s.aussen_c, soll_c: s.soll_c }))))
      .catch(() => setStunden([]));
  }, []);

  const offen = useMemo(() => (daten ? aenderungen(daten.werte, entwurf) : []), [daten, entwurf]);

  if (!daten) {
    return <p className="m-0 text-[15px] text-text-3">{fehler ?? "Die Einstellungen werden gelesen …"}</p>;
  }
  const moeglich = daten.stellen_moeglich;
  const setze = (key: string, wert: number) => setEntwurf((e) => ({ ...e, [key]: wert }));
  const stellbar = daten.werte.filter((w) => w.stellbar);
  const verglichen = stellbar.filter((w) => w.bestaetigt).length;
  const nach = (gruppe: string, art: ReglerEinstellung["art"][]) => stellbar.filter((w) => w.gruppe_de === gruppe && art.includes(w.art));
  const zuege = ["Heizkurve", "Raum", "Warmwasser"].map((g) => ({ name: g, werte: nach(g, ["zahl"]) })).filter((g) => g.werte.length);
  const schalter = stellbar.filter((w) => w.art !== "zahl");
  const nurLesen = daten.werte.filter((w) => !w.stellbar);

  const vergleichen = async (w: ReglerEinstellung, bestaetigt: boolean) => {
    try {
      const aus = await api.reglerBestaetigen(w.schluessel, bestaetigt);
      setDaten(aus.einstellungen);
      if (!bestaetigt) setEntwurf(({ [w.schluessel]: _, ...rest }) => rest);
    } catch (e) {
      setMeldungen([{ ok: false, text: e instanceof ApiError ? e.message : "Der Vermerk ließ sich nicht speichern." }]);
    }
  };

  const uebernehmen = async () => {
    setLaeuft(true);
    const aus: { ok: boolean; text: string }[] = [];
    let stand = daten;
    // Nacheinander, nicht zugleich: jede Einstellung ist ein eigener Befehl auf dem Bus.
    for (const a of offen) {
      try {
        const r = await api.reglerStellen(a.w.schluessel, a.neu);
        aus.push({ ok: r.ok, text: r.message_de });
        stand = r.einstellungen;
      } catch (e) {
        aus.push({ ok: false, text: e instanceof ApiError ? e.message : `${a.w.name_de}: nicht gesendet.` });
      }
    }
    setDaten(stand);
    setEntwurf({});
    setMeldungen(aus);
    setUebersicht(false);
    setLaeuft(false);
  };

  const fuss = (w: ReglerEinstellung) => {
    const grund = sperre(w, moeglich);
    if (w.gesendet) return <span className="rg-wartet">gesendet {zahlText(w, w.gesendet.wert)}, wartet auf den Regler</span>;
    if (grund === "nicht verglichen") {
      return (
        <button type="button" className="rg-vergleich" onClick={() => void vergleichen(w, true)}>
          Am Gerät steht {wertText(w)}
        </button>
      );
    }
    if (grund) return <span className="rg-grund">{grund}</span>;
    return <span className="rg-grund">gelesen {standText(w)}</span>;
  };

  return (
    <section className="wp-seite rg-seite">
      <div className="wp-kopf">
        <p className="wp-satz">{daten.satz_de}</p>
        <span className="wp-stand">
          {verglichen} von {stellbar.length} stellbaren Einstellungen mit dem Bediengerät verglichen{fehler ? ` · ${fehler}` : ""}
        </span>
      </div>

      {!moeglich && daten.hindernis_de ? (
        <p className="wp-stumm" role="status">
          <strong>Stellen ist gerade nicht möglich.</strong> {daten.hindernis_de} Lesen geht weiter.
        </p>
      ) : null}
      {verglichen < stellbar.length ? (
        <p className="rg-anleitung">
          Bevor sich eine Einstellung bewegen lässt, einmal am Bediengerät nachsehen: Steht dort dieselbe Zahl wie hier, den Knopf „Am Gerät steht …“ unter dem Regler drücken. Steht dort etwas anderes, ist die Kennung für diese Anlage falsch gelesen; dann bitte nicht drücken.
        </p>
      ) : null}

      {meldungen.length ? (
        <div className="rg-meldungen" role="status">
          {meldungen.map((m, i) => (
            <p key={i} className="m-0" data-ok={m.ok}>
              {m.ok ? "✓" : "✗"} {m.text}
            </p>
          ))}
          <button type="button" className="rg-leise" onClick={() => setMeldungen([])}>Ausblenden</button>
        </div>
      ) : null}

      <div className="card kl-karte">
        <h2 className="kl-titel">Heizkurve</h2>
        <Heizkurve werte={daten.werte} entwurf={entwurf} setze={setze} stellenMoeglich={moeglich} stunden={stunden} />
        <p className="m-0 kl-klein">Die Kurve ist eine Näherung: Vorlauf = Raum + Steilheit × (Raum − außen) + Verschiebung, begrenzt auf den kleinsten und größten Vorlauf. Sie zeigt, wohin sich die Kurve mit einer Änderung bewegt; was der Regler daraus wirklich macht, zeigen danach die Punkte.</p>
      </div>

      <div className="card kl-karte rg-pult">
        <h2 className="kl-titel">Pult</h2>
        <div className="rg-zuege">
          {zuege.map((g) => (
            <div key={g.name} className="rg-zuggruppe" role="group" aria-label={g.name}>
              <span className="rg-gruppenname">{g.name}</span>
              <div className="rg-zugreihe">
                {g.werte.map((w) => (
                  <Fader key={w.schluessel} w={w} wert={sichtbar(w, entwurf)} sperre={sperre(w, moeglich)} onChange={(v) => setze(w.schluessel, v)} fuss={fuss(w)} />
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {schalter.length ? (
        <div className="card kl-karte">
          <h2 className="kl-titel">Schalter</h2>
          <div className="rg-schalterfeld">
            {schalter.map((w) => {
              const wert = sichtbar(w, entwurf);
              const frei = sperre(w, moeglich) === null;
              const ist = gelesen(w) ? w.wert.value : null;
              return (
                <div key={w.schluessel} className="rg-schalter" data-frei={frei} data-geaendert={wert != null && ist != null && wert !== ist}>
                  <span className="rg-schaltername">
                    {w.gruppe_de}: {w.name_de}
                    {w.muster ? <em> · Stellbefehl nach Muster gebildet</em> : null}
                  </span>
                  <div className="rg-stufen" role="radiogroup" aria-label={`${w.gruppe_de}: ${w.name_de}`}>
                    {Object.entries(w.wahl ?? {}).map(([zahl, wort]) => (
                      <button key={zahl} type="button" role="radio" aria-checked={wert === Number(zahl)} disabled={!frei} data-ist={ist === Number(zahl)} onClick={() => setze(w.schluessel, Number(zahl))}>
                        <span className="mono">{zahl}</span> {wort}
                      </button>
                    ))}
                  </div>
                  {w.hinweis_de ? <span className="rg-schalterhinweis">{w.hinweis_de}</span> : null}
                  <span className="rg-kanal-fuss">{fuss(w)}</span>
                </div>
              );
            })}
          </div>
          <p className="m-0 kl-klein">Die Wörter an den Stufen sind die Lesart der Busbeschreibung; der Regler kennt nur die Zahl davor. Die Stufe mit dem Strich darunter ist die, die am Regler steht.</p>
        </div>
      ) : null}

      {nurLesen.length ? (
        <details className="kl-liste">
          <summary>Nur zum Lesen ({nurLesen.length})</summary>
          <table className="kl-tabelle rg-tabelle">
            <thead>
              <tr>
                <th scope="col">Einstellung</th>
                <th scope="col">Wert</th>
                <th scope="col">gelesen</th>
                <th scope="col">Kennung</th>
              </tr>
            </thead>
            <tbody>
              {nurLesen.map((w) => (
                <tr key={w.schluessel} data-gemessen={gelesen(w)}>
                  <td>
                    {w.gruppe_de}: {w.name_de}
                    {w.lesart_de ? <span className="rg-lesart">laut Busbeschreibung: {w.lesart_de}</span> : null}
                  </td>
                  <td className="mono rg-wert">{wertText(w)}</td>
                  <td className="mono">{standText(w)}</td>
                  <td className="mono">{w.kennung}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      ) : null}

      {daten.protokoll.length ? (
        <details className="kl-liste" open>
          <summary>Was zuletzt gestellt wurde ({daten.protokoll.length})</summary>
          <table className="kl-tabelle">
            <thead>
              <tr>
                <th scope="col">Zeit</th>
                <th scope="col">Einstellung</th>
                <th scope="col">von</th>
                <th scope="col">auf</th>
                <th scope="col">wer</th>
              </tr>
            </thead>
            <tbody>
              {daten.protokoll.map((p) => (
                <tr key={`${p.at}-${p.schluessel}`}>
                  <td className="mono">{new Date(p.at).toLocaleString("de-DE", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", timeZone: "Europe/Berlin" })}</td>
                  <td>{p.name_de}</td>
                  <td className="mono">{p.von_de}</td>
                  <td className="mono">{p.auf_de}</td>
                  <td>{p.urheber_de ?? ""}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      ) : null}

      {stellbar.some((w) => w.bestaetigt) ? (
        <details className="kl-liste">
          <summary>Vermerke zurücknehmen</summary>
          <div className="rg-vermerke">
            {stellbar
              .filter((w) => w.bestaetigt)
              .map((w) => (
                <button key={w.schluessel} type="button" className="rg-leise" onClick={() => void vergleichen(w, false)}>
                  {w.gruppe_de}: {w.name_de} ist doch nicht verglichen
                </button>
              ))}
          </div>
        </details>
      ) : null}

      <div className="wp-fuss">
        {daten.hinweise_de.map((h) => (
          <p key={h} className="m-0">
            {h}
          </p>
        ))}
        <p className="m-0 wp-links">
          <Link href="/waerme/waermepumpe/betrieb">Die Heizkurve, wie sie gefahren wird ›</Link>
          <Link href="/waerme/waermepumpe">Die Wärmepumpe jetzt ›</Link>
        </p>
      </div>

      {offen.length ? (
        <div className="rg-leiste" role="region" aria-label="Änderungen übernehmen">
          {uebersicht ? (
            <div className="rg-uebersicht">
              <strong>Diese Änderungen gehen an den Regler der Wärmepumpe und bleiben dort stehen:</strong>
              <ul>
                {offen.map((a) => (
                  <li key={a.w.schluessel}>
                    {a.w.gruppe_de}: {a.w.name_de} <span className="mono">{zahlText(a.w, a.alt)} → {zahlText(a.w, a.neu)}</span>
                  </li>
                ))}
              </ul>
            </div>
          ) : (
            <span className="rg-zahl">
              {offen.length === 1 ? "1 Änderung" : `${offen.length} Änderungen`} im Entwurf
            </span>
          )}
          <div className="rg-leistenknoepfe">
            <button type="button" className="rg-leise" disabled={laeuft} onClick={() => (uebersicht ? setUebersicht(false) : setEntwurf({}))}>
              {uebersicht ? "Zurück" : "Verwerfen"}
            </button>
            <button type="button" className="rg-haupt" disabled={laeuft} onClick={() => (uebersicht ? void uebernehmen() : setUebersicht(true))}>
              {laeuft ? "Wird gesendet …" : uebersicht ? "Jetzt stellen" : "Übernehmen …"}
            </button>
          </div>
        </div>
      ) : null}
    </section>
  );
}
