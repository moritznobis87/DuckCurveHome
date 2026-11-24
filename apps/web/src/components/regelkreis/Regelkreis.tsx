"use client";

import { useCallback, useEffect, useState } from "react";
import { Card, CardHead } from "@/components/ui/Card";
import { Methode } from "@/components/ui/Methode";
import { ApiError, api } from "@/lib/api/client";
import type { Regelkreis as Daten, RegelkreisUebernahme } from "@/lib/api/models";
import { Leuchte, Pegel, Ring, Rundinstrument, SprungantwortBild } from "./Anzeigen";
import { Blatt } from "./Blatt";
import { Karte } from "./Karte";
import { SICHT } from "./layout";

/**
 * Die Seite „Regelkreis": die ganze Regelung des Hauses als Blockschaltbild, mit dem Lernstand.
 *
 * **Warum diese Seite nötig ist.** Die Anlage regelt auf fünf Ebenen mit Zeitkonstanten von
 * Sekunden bis Stunden, und ihre dreißig Parameter sind zu verschiedenen Teilen gemessen,
 * geschätzt und geraten. Verstreut über Einstellungsseiten sieht das alles gleich aus. Hier steht
 * es zusammen - und zwar so, dass sichtbar ist, welche Zahl eine Messung ist und welche eine
 * Annahme.
 *
 * **Was sie nicht ist.** Keine Einstellungsseite. Übersteuern kann man hier, aber der Normalfall
 * ist, dass die Lernebene die Parameter führt und der Entwurf die Regler daraus rechnet. Eine
 * Übersteuerung hält genau das an und steht deshalb in Warnfarbe.
 *
 * **Der Arbeitspunkt oben ist die Pointe.** Die Verstärkung der Wärmepumpe ändert sich zwischen
 * einem milden und einem kalten Tag um den Faktor zwei; die Regler darunter werden deshalb für
 * den Augenblick gerechnet. Wer die Seite an zwei verschiedenen Tagen aufruft, sieht zwei
 * verschiedene Regler - das ist Verstärkungsplanung, und sie ist hier zu sehen.
 */

const de = (v: number, stellen = 2) => v.toLocaleString("de-DE", { minimumFractionDigits: stellen, maximumFractionDigits: stellen });

/** So viele Stützstellen verlangt die Übernahmeprüfung, bevor sie überhaupt hinsieht. */
const NOETIGE_STUETZSTELLEN = 30;

/** Die Ordnung des Katalogs: erst, was regelt, dann was gestellt wird, dann der Rest. */
const KATEGORIEN: [string, string][] = [
  ["regler", "Regelglieder"],
  ["strecke", "Streckenglieder"],
  ["nichtlinear", "Nichtlineare Glieder"],
  ["beobachter", "Beobachter"],
  ["planung", "Planung"],
  ["messglied", "Messglieder"],
];

/** In welchen Blöcken ein Glied vorkommt - der Katalog soll nicht abstrakt bleiben. */
function woGenutzt(d: Daten, gid: string): string {
  const namen = d.bloecke.filter((b) => b.glied === gid || b.glied_entwurf === gid).map((b) => b.name);
  return namen.length ? `im Haus: ${namen.join(" · ")}` : "";
}

/** Alle Übernahmen über alle Parameter, jüngste zuerst. */
function protokoll(d: Daten): { pid: string; name: string; symbol: string; einheit: string; stellen: number; block: string; u: RegelkreisUebernahme }[] {
  const aus = d.parameter.flatMap((p) => p.protokoll.map((u) => ({ pid: p.id, name: p.name, symbol: p.symbol, einheit: p.einheit, stellen: p.stellen, block: p.block, u })));
  return aus.sort((a, b) => b.u.at.localeCompare(a.u.at));
}

export function Regelkreis() {
  const [d, setD] = useState<Daten | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [sicht, setSicht] = useState("alles");
  const [gewaehlt, setGewaehlt] = useState<string>("puffer_regler");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let lebt = true;
    api
      .regelkreis()
      .then((x) => lebt && setD(x))
      .catch((e) => lebt && setFehler(e instanceof ApiError ? e.message : "Die Karte ist nicht zu laden."));
    return () => {
      lebt = false;
    };
  }, []);

  const stellen = useCallback(async (pid: string, wert: number) => {
    if (!Number.isFinite(wert)) return;
    setBusy(true);
    setFehler(null);
    try {
      setD(await api.regelkreisStellen(pid, wert));
    } catch (e) {
      setFehler(e instanceof ApiError ? e.message : "Der Wert ließ sich nicht setzen.");
    } finally {
      setBusy(false);
    }
  }, []);

  const freigeben = useCallback(async (pid: string) => {
    setBusy(true);
    setFehler(null);
    try {
      setD(await api.regelkreisFreigeben(pid));
    } catch (e) {
      setFehler(e instanceof ApiError ? e.message : "Die Übersteuerung ließ sich nicht aufheben.");
    } finally {
      setBusy(false);
    }
  }, []);

  if (fehler && !d) return <Card>{fehler}</Card>;
  if (!d) return <Card>Karte wird geladen …</Card>;

  const springeZuGlied = (gid: string) => {
    const b = d.bloecke.find((x) => x.glied === gid || x.glied_entwurf === gid);
    if (b) setGewaehlt(b.id);
  };
  const log = protokoll(d);
  const ap = d.arbeitspunkt;
  const k = d.kosten;
  const billiger = k.waermepumpe_ct_kwh <= k.ofen_ct_kwh;
  // Wie viele der lernbaren Parameter stehen schon auf einer Messung statt auf einer Annahme.
  const lernbar = d.parameter.filter((p) => p.schaetzart !== "keiner").length;
  const belegt = d.parameter.filter((p) => p.herkunft === "gemessen" || p.herkunft === "geschaetzt").length;
  const kreiseGut = d.kreise.every((kr) => !kr.reserven || kr.reserven.gut);

  return (
    <div className="flex flex-col gap-4">
      <section className="rk-konsole" aria-label="Arbeitspunkt und Lernstand">
        <div className="rk-konsole-feld">
          <Rundinstrument
            wert={k.cop}
            von={1}
            bis={6}
            stellen={2}
            titel="Arbeitszahl im Punkt"
            felder={[
              { bis: 2.2, farbe: "var(--alert)" },
              { bis: 3.2, farbe: "var(--amber)" },
              { bis: 6, farbe: "var(--mist)" },
            ]}
          />
          <p className="rk-klein rk-konsole-text">
            bei {de(ap.aussen_c, 1)} °C außen und {de(ap.vorlauf_c, 0)} °C Vorlauf
            <br />
            {ap.aussen_gemessen ? "Außentemperatur gemessen" : "Auslegungspunkt"}
            {ap.vorlauf_gemessen ? ", Vorlauf gemessen" : ", Vorlauf aus der Kennlinie"}
          </p>
        </div>

        <div className="rk-konsole-feld rk-konsole-pegel">
          <Pegel wert={k.waermepumpe_ct_kwh} max={30} schwelle={k.ofen_ct_kwh} titel="Wärmepumpe" zahl={de(k.waermepumpe_ct_kwh, 1)} farbe="var(--heat-pump)" />
          <Pegel wert={k.ofen_ct_kwh} max={30} titel="Ofen" zahl={de(k.ofen_ct_kwh, 1)} farbe="var(--stove)" />
          <div className="rk-konsole-text">
            <span className="kicker">Grenzkosten Wärme</span>
            <b className="mono" style={{ color: billiger ? "var(--heat-pump)" : "var(--stove)" }}>
              {billiger ? "Wärmepumpe" : "Pelletofen"}
            </b>
            <span className="rk-klein">
              ct je kWh Wärme bei {de(ap.strompreis_eur_kwh * 100, 1)} ct/kWh Strom. Die Linie am linken Pegel ist der Ofen.
            </span>
          </div>
        </div>

        <div className="rk-konsole-feld">
          <span className="kicker">Umschaltpunkt</span>
          <b className="mono rk-konsole-zahl">{k.umschalt_aussen_c !== null ? `${de(k.umschalt_aussen_c, 1)} °C` : "—"}</b>
          <span className="rk-klein">
            {k.umschalt_aussen_c !== null ? "darunter ist der Ofen die billigere Kilowattstunde" : "außerhalb des sinnvollen Bereichs"}
            <br />
            nötige Arbeitszahl {de(k.cop_umschalt, 2)}
          </span>
        </div>

        <div className="rk-konsole-feld">
          <Ring anteil={lernbar ? belegt / lernbar : 0} mitte={`${belegt}/${lernbar}`} titel="aus Messung" />
          <div className="rk-konsole-text">
            <span className="kicker">Lernstand</span>
            <b className="mono rk-konsole-zahl">{d.tage != null ? de(d.tage, 0) : "0"}<i> Betriebstage</i></b>
            <span className="rk-klein">
              {d.uebernahmen} Übernahme{d.uebernahmen === 1 ? "" : "n"}
            </span>
            <div className="rk-leuchten">
              <Leuchte an={ap.aussen_gemessen} titel="Arbeitspunkt gemessen" />
              <Leuchte an={d.uebersteuert.length > 0} farbe="var(--alert)" titel={`${d.uebersteuert.length} übersteuert`} />
              {/* Diese Leuchte brennt immer; ihre Farbe ist die Meldung. Eine Warnleuchte, die bei
                  einer Warnung ausgeht, ist die Umkehrung ihres Zwecks. */}
              <Leuchte an farbe={kreiseGut ? "var(--ok)" : "var(--alert)"} titel={kreiseGut ? "Reserven in Ordnung" : "Reserve zu klein"} />
            </div>
          </div>
        </div>
      </section>

      {fehler ? <Card>{fehler}</Card> : null}

      <Card>
        <CardHead
          title="Die Kaskade"
          right={
            <div className="rk-sicht">
              {Object.entries(SICHT).map(([key, s]) => (
                <button key={key} className={`rk-knopf${sicht === key ? " rk-an" : ""}`} onClick={() => setSicht(key)}>
                  {s.label}
                </button>
              ))}
            </div>
          }
        />
        <Karte d={d} sicht={sicht} gewaehlt={gewaehlt} onWaehle={setGewaehlt} />
        <div className="rk-legende">
          <span><i className="rk-l-signal" />Signal</span>
          <span><i className="rk-l-fuehrung" />Führungsgröße</span>
          <span><i className="rk-l-rueck" />Rückführung</span>
          <span><i className="rk-l-stoer" />Störgröße</span>
          <span><i className="rk-l-param" />Parameterwirkung</span>
          <span><i className="rk-l-punkt" style={{ background: "var(--amber)" }} />gemessen</span>
          <span><i className="rk-l-punkt" style={{ background: "var(--amber-soft)" }} />geschätzt</span>
          <span><i className="rk-l-punkt" style={{ background: "var(--text-3)" }} />Annahme oder fest</span>
          <span><i className="rk-l-punkt" style={{ background: "var(--mist)" }} />Entwurf</span>
          <span><i className="rk-l-punkt" style={{ background: "var(--alert)" }} />übersteuert</span>
          <span><i className="rk-l-bild" />Kennbild: Sprungantwort des Glieds</span>
        </div>
      </Card>

      <Blatt d={d} blockId={gewaehlt} onWaehle={setGewaehlt} onStellen={stellen} onFreigeben={freigeben} busy={busy} />

      <div className="rk-panels">
        <Card>
          <CardHead title="Lernprotokoll" right="jüngste zuerst" />
          {log.length ? (
            <ul className="rk-log">
              {log.slice(0, 12).map((e, i) => (
                <li key={i} onClick={() => setGewaehlt(e.block)}>
                  <span className="rk-klein">{new Date(e.u.at).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "numeric" })}</span>
                  <span className="rk-log-was">{e.name}</span>
                  <span className="mono rk-log-delta">
                    {e.symbol}: <s>{de(e.u.alt, e.stellen)}</s> → <b>{de(e.u.neu, e.stellen)}</b>
                    {e.einheit === "—" ? "" : ` ${e.einheit}`} · n = {e.u.n.toLocaleString("de-DE")}
                  </span>
                  <span className="rk-klein">{e.u.grund}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="rk-text">
              Noch keine Übernahme. Übernommen wird erst, was mehr als die eigene Unsicherheit abweicht, auf genug Stützstellen steht und den Restfehler über vierzehn Tage senkt. Bis dahin gelten die Startwerte, und jeder Parameter sagt an seiner Zeile, woran es liegt.
            </p>
          )}
        </Card>

        <Card>
          <CardHead title="Modellgüte" right="Restfehler gegen die Messung" />
          <table className="rk-tabelle">
            <thead>
              <tr>
                <th>Modell</th>
                <th className="rk-num">Restfehler</th>
                <th className="rk-zelle-mitte">Datenlage</th>
              </tr>
            </thead>
            <tbody>
              {d.guete.map((g) => (
                <tr key={g.modell} className="rk-zeile" onClick={() => setGewaehlt(g.block)}>
                  <td>
                    {g.modell}
                    <br />
                    <span className="rk-klein">{g.quelle}</span>
                  </td>
                  <td className="rk-num mono">{g.rmse !== null ? `${de(g.rmse, 3)}${g.einheit === "—" ? "" : ` ${g.einheit}`}` : "—"}</td>
                  <td className="rk-zelle-mitte">
                    <Ring
                      anteil={Math.min(1, g.n / NOETIGE_STUETZSTELLEN)}
                      mitte={g.n ? (g.n > 999 ? `${Math.round(g.n / 1000)}k` : String(g.n)) : "0"}
                      groesse={38}
                      farbe={g.n >= NOETIGE_STUETZSTELLEN ? "var(--amber)" : "var(--mist)"}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>

        <Card>
          <CardHead title="Kennwerte der Kreise" right="nach SIMC entworfen" />
          <table className="rk-tabelle rk-ktab">
            <thead>
              <tr>
                <th>Kreis</th>
                <th className="rk-zelle-mitte">Phasenreserve</th>
              </tr>
            </thead>
            <tbody>
              {d.kreise.map((kr) => (
                <tr key={kr.id} className="rk-zeile" onClick={() => setGewaehlt(kr.regler_block)}>
                  <td>
                    <b className="rk-kreis-name">
                      {kr.id} {kr.name}
                    </b>
                    <span className="rk-klein">
                      {kr.regelgroesse} über {kr.stellgroesse}
                    </span>
                    {kr.reserven ? (
                      <span className="rk-klein mono">
                        Periode bei ωc {kr.reserven.periode_min ? (kr.reserven.periode_min >= 60 ? `${de(kr.reserven.periode_min / 60, 1)} h` : `${de(kr.reserven.periode_min, 0)} min`) : "—"}
                        {" · "}
                        Amplitudenreserve {kr.reserven.amplitudenreserve !== null ? de(kr.reserven.amplitudenreserve, 2) : "∞"}
                      </span>
                    ) : (
                      <span className="rk-klein">
                        {kr.art === "planung" ? "gleitender Horizont, in Euro beurteilt" : "hybrid und ganzzahlig, ohne Frequenzkennlinie"}
                      </span>
                    )}
                  </td>
                  <td className="rk-zelle-mitte">
                    {kr.reserven ? (
                      <Rundinstrument
                        wert={kr.reserven.phasenreserve_grad}
                        von={0}
                        bis={90}
                        stellen={0}
                        einheit="°"
                        titel={`Phasenreserve ${kr.id}`}
                        groesse={62}
                        felder={[
                          { bis: 45, farbe: "var(--alert)" },
                          { bis: 60, farbe: "var(--amber)" },
                          { bis: 90, farbe: "var(--mist)" },
                        ]}
                      />
                    ) : (
                      <span className="rk-klein">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      </div>

      <Card>
        <CardHead title="Die Glieder dieser Strecke" right="Kennbild, Kurzzeichen, Übertragungsfunktion" />
        <p className="rk-text">
          Jedes Kästchen der Karte trägt sein Kennbild: die Antwort auf einen Sprung am Eingang,
          bei statischen Gliedern stattdessen die Kennlinie. Wer die Form kennt, erkennt das Glied,
          ohne die Formel zu lesen, und wer die Formel liest, prüft die Form.
        </p>
        <div className="rk-katalog">
          {KATEGORIEN.map(([key, titel]) => {
            const glieder = d.glieder.filter((g) => g.kategorie === key);
            if (!glieder.length) return null;
            return (
              <div key={key} className="rk-katalog-gruppe">
                <span className="kicker">{titel}</span>
                {glieder.map((g) => (
                  <div key={g.id} className="rk-katalog-eintrag" onClick={() => springeZuGlied(g.id)} role="button" tabIndex={0} onKeyDown={(e) => { if (e.key === "Enter") springeZuGlied(g.id); }}>
                    <SprungantwortBild g={g} breite={80} hoehe={48} />
                    <div>
                      <b className="mono">{g.kurz}</b>
                      <span>{g.name}</span>
                      <code>{g.g_s}</code>
                      <span className="rk-klein">{g.erkennen}</span>
                      <span className="rk-klein rk-katalog-wo">{woGenutzt(d, g.id)}</span>
                    </div>
                  </div>
                ))}
              </div>
            );
          })}
        </div>
      </Card>

      <Methode kurz="Struktur, Entwurf nach SIMC, und wann eine Schätzung den geltenden Wert ersetzt">
        <p>
          <b>Die Struktur ist eine Aussage über das Haus</b> und steht im Kern, nicht in der Zeichnung: welcher Kreis welchem unterlagert ist, wo eine Störgröße angreift und ob sie aufgeschaltet oder nur ausgeregelt wird. Die Anzeige legt die Kästchen hin.
        </p>
        <p>
          <b>Der Regler wird gerechnet, nicht eingestellt.</b> Aus den Streckenparametern folgt er nach der Regel von Skogestad (SIMC), mit der Ersatzzeitkonstante λ als einziger freier Zahl. Bei zwei Zeitkonstanten greift die Halbregel: die halbe kleinere geht in die große, die andere Hälfte in die Totzeit. Ändert die Lernebene einen Streckenparameter, ändert sich der Regler mit. Das ist ein indirekter selbsteinstellender Regler.
        </p>
        <p>
          <b>Übernommen wird nur, was fünf Hürden überspringt:</b> genug Stützstellen, innerhalb der Plausibilitätsgrenzen, größer als die eigene Unsicherheit, vierzehn Tage seit der letzten Übernahme, und ein kleinerer Restfehler im Vergleich. Damit kann das Modell nie schlechter werden als sein Startwert. Jede Ablehnung steht als Satz an ihrem Parameter.
        </p>
        <p>
          <b>Woher die Zahlen kommen.</b> Die COP-Ebene aus der gemessenen Kennlinie (Ausgleich über Zehn-Minuten-Fenster im eingeschwungenen Heizbetrieb), Totzeit und Anlaufzeit der Wärmepumpe aus der Ereignisstudie über die Anforderungen an sie. Alles andere steht noch auf Startwerten aus Konfiguration und Datenblatt und ist als Annahme gekennzeichnet. Die Reihen dafür liegen vor, die Schätzer sind noch nicht angeschlossen.
        </p>
        <p>
          <b>Was die Reserven sagen.</b> Die Phasenreserve ist der Abstand zur Dauerschwingung: unter 45° reagiert der Kreis auf eine Änderung der Strecke, etwa einen kälteren Tag oder einen anderen Volumenstrom, mit Überschwingen. Für die Erzeugerwahl und den Fahrplan gibt es keine solche Zahl, weil ihre Stellgrößen ganzzahlig sind; sie werden am Umschaltpunkt und in Euro beurteilt.
        </p>
      </Methode>
    </div>
  );
}
