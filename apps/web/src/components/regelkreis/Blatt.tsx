"use client";

import { useState } from "react";
import { Card, CardHead } from "@/components/ui/Card";
import type { Regelkreis, RegelkreisHerkunft, RegelkreisKreis, RegelkreisParameter } from "@/lib/api/models";

/**
 * Das Detailblatt eines Blocks: was er tut, woran er lernt, und was man ihm vorschreiben kann.
 *
 * **Die Reihenfolge ist Absicht.** Zuerst die Wirkung im Kreis in Worten, dann das Modell als
 * Gleichung, dann die Parameter mit ihrer Herkunft, dann - bei einem Regler - der Entwurf und
 * seine Reserven. Wer nur wissen will, was das Kästchen tut, liest den ersten Absatz. Wer eine
 * Zahl anzweifelt, kommt bis zum Übernahmeprotokoll.
 *
 * **Die abgelehnte Prüfung ist die interessantere Hälfte.** Neben jedem geschätzten Parameter
 * steht nicht nur, was gilt, sondern warum noch der alte Wert gilt: zu wenig Daten, innerhalb
 * der Unsicherheit, zu früh, außerhalb der Grenzen, kein Gütegewinn. Ohne diesen Satz sieht eine
 * Lernebene, die nichts tut, aus wie eine, die nicht funktioniert.
 */

const HERKUNFT: Record<RegelkreisHerkunft, { text: string; farbe: string }> = {
  gemessen: { text: "gemessen", farbe: "var(--amber)" },
  geschaetzt: { text: "geschätzt", farbe: "var(--amber-soft)" },
  annahme: { text: "Annahme", farbe: "var(--text-3)" },
  fest: { text: "fest", farbe: "var(--text-3)" },
  entwurf: { text: "Entwurf", farbe: "var(--mist)" },
  uebersteuert: { text: "übersteuert", farbe: "var(--alert)" },
};

const de = (v: number, stellen = 2) => v.toLocaleString("de-DE", { minimumFractionDigits: stellen, maximumFractionDigits: stellen });
const datum = (iso: string) => new Date(iso).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "numeric" });

/** Die Frequenzkennlinie des offenen Kreises: Betrag in dB, Phase in Grad, mit Durchtritt. */
function Kennlinie({ k }: { k: RegelkreisKreis }) {
  const punkte = k.kennlinie;
  if (!punkte.length) return null;
  const B = { l: 46, t: 14, r: 46, b: 30, w: 580, hM: 118, lu: 16, hP: 92 };
  const w0 = punkte[0]!.w;
  const w1 = punkte[punkte.length - 1]!.w;
  const x = (w: number) => B.l + (B.w - B.l - B.r) * (Math.log10(w / w0) / Math.log10(w1 / w0));
  const dbLo = -40;
  const dbHi = 40;
  const phLo = -270;
  const phHi = -45;
  const yM = (db: number) => B.t + B.hM * (1 - (Math.max(dbLo, Math.min(dbHi, db)) - dbLo) / (dbHi - dbLo));
  const yP = (ph: number) => B.t + B.hM + B.lu + B.hP * (1 - (Math.max(phLo, Math.min(phHi, ph)) - phLo) / (phHi - phLo));
  const hoehe = B.t + B.hM + B.lu + B.hP + B.b;
  const linie = (f: (p: { w: number; db: number; grad: number }) => number) => punkte.map((p, i) => `${i ? "L" : "M"}${x(p.w).toFixed(1)} ${f(p).toFixed(1)}`).join(" ");
  const dekaden: number[] = [];
  for (let e = Math.ceil(Math.log10(w0)); e <= Math.floor(Math.log10(w1)); e++) dekaden.push(10 ** e);
  const periode = (w: number) => {
    const t = (2 * Math.PI) / w;
    return t >= 1440 ? `${de(t / 1440, 0)} d` : t >= 60 ? `${de(t / 60, 0)} h` : `${de(t, 0)} min`;
  };
  const wc = k.reserven?.durchtritt ?? null;
  const pm = k.reserven?.phasenreserve_grad ?? null;
  return (
    <figure className="rk-chart">
      <svg viewBox={`0 0 ${B.w} ${hoehe}`} role="img" aria-label={`Frequenzkennlinie des Kreises ${k.id}: Durchtritt bei ${wc ? de(wc, 4) : "—"} Radiant je Minute, Phasenreserve ${pm ? de(pm, 0) : "—"} Grad.`}>
        {[-40, -20, 0, 20, 40].map((db) => (
          <g key={db}>
            <line className={db === 0 ? "rk-achse" : "rk-raster"} x1={B.l} x2={B.w - B.r} y1={yM(db)} y2={yM(db)} />
            <text className="rk-achse-text" x={B.l - 6} y={yM(db) + 3} textAnchor="end">
              {db}
            </text>
          </g>
        ))}
        {[-90, -180, -270].map((ph) => (
          <g key={ph}>
            <line className={ph === -180 ? "rk-grenze" : "rk-raster"} x1={B.l} x2={B.w - B.r} y1={yP(ph)} y2={yP(ph)} />
            <text className="rk-achse-text" x={B.l - 6} y={yP(ph) + 3} textAnchor="end">
              {ph}°
            </text>
          </g>
        ))}
        {dekaden.map((w) => (
          <g key={w}>
            <line className="rk-raster" x1={x(w)} x2={x(w)} y1={B.t} y2={B.t + B.hM} />
            <line className="rk-raster" x1={x(w)} x2={x(w)} y1={B.t + B.hM + B.lu} y2={B.t + B.hM + B.lu + B.hP} />
            <text className="rk-achse-text" x={x(w)} y={hoehe - 6} textAnchor="middle">
              {periode(w)}
            </text>
          </g>
        ))}
        {wc ? (
          <>
            <line className="rk-durchtritt" x1={x(wc)} x2={x(wc)} y1={B.t} y2={B.t + B.hM + B.lu + B.hP} />
            {pm !== null ? (
              <>
                <line x1={x(wc)} x2={x(wc)} y1={yP(-180)} y2={yP(-180 + pm)} stroke="var(--alert)" strokeWidth={2.4} />
                <text className="rk-achse-text" x={x(wc) + 6} y={yP(-180 + pm / 2)} style={{ fill: "var(--alert)" }}>
                  φR = {de(pm, 0)}°
                </text>
              </>
            ) : null}
          </>
        ) : null}
        <path className="rk-betrag" d={linie((p) => yM(p.db))} />
        <path className="rk-phase" d={linie((p) => yP(p.grad))} />
        <text className="rk-achse-text" x={B.l} y={B.t + 9}>
          |L| in dB
        </text>
        <text className="rk-achse-text" x={B.l} y={B.t + B.hM + B.lu + 10}>
          arg L
        </text>
        <text className="rk-achse-text" x={B.w - B.r} y={B.t + B.hM + B.lu + 10} textAnchor="end">
          Periode
        </text>
      </svg>
      <figcaption className="rk-bild-text">
        Offener Kreis L(jω) = Regler · Strecke, aus den heute geltenden Parametern gerechnet. Der senkrechte Strich ist der Durchtritt, der rote Balken die Phasenreserve. Jede Übersteuerung oben verschiebt beide.
      </figcaption>
    </figure>
  );
}

function Entwurf({ k }: { k: RegelkreisKreis }) {
  if (!k.regler || !k.strecke) {
    return (
      <p className="rk-text">
        Für diesen Kreis gibt es keine Frequenzkennlinie: {k.art === "planung" ? "er rechnet über einen gleitenden Horizont und wird in Euro beurteilt, nicht an einer Reserve." : "seine Stellgröße ist eine Entscheidung zwischen zwei Maschinen mit Mindestzeiten. Beurteilt wird er am Umschaltpunkt und an der Totzone."}
      </p>
    );
  }
  const s = k.strecke;
  const r = k.reserven;
  return (
    <>
      {k.hinweis ? <p className="rk-warnung">{k.hinweis}</p> : null}
      <div className="rk-kacheln">
        <div>
          <span>Strecke</span>
          <b>{s.art === "iptd" ? "Integrierer" : "1. Ordnung"}</b>
          <small>
            {s.art === "iptd" ? `k′ = ${de(s.k, 3)} K/min` : `K = ${de(s.k, 3)}`} · Tt = {de(s.totzeit, 1)} min
            {s.t1 ? ` · T1 = ${de(s.t1, 0)} min` : ""}
            {s.halbregel ? ` · T2 = ${de(s.t2, 0)} min` : ""}
          </small>
        </div>
        <div>
          <span>Regler</span>
          <b>KR = {de(k.regler.kp, 2)}</b>
          <small>
            Tn = {de(k.regler.tn, 0)} min · λ = {de(k.regler.lam, 1)} min · {k.regler.regel}
          </small>
        </div>
        <div>
          <span>Phasenreserve</span>
          <b style={{ color: r?.gut ? "var(--mist)" : "var(--alert)" }}>{r?.phasenreserve_grad !== null && r?.phasenreserve_grad !== undefined ? `${de(r.phasenreserve_grad, 0)}°` : "—"}</b>
          <small>Amplitudenreserve {r?.amplitudenreserve ? de(r.amplitudenreserve, 2) : "∞"}</small>
        </div>
        <div>
          <span>Durchtritt</span>
          <b>{r?.periode_min ? (r.periode_min >= 60 ? `${de(r.periode_min / 60, 1)} h` : `${de(r.periode_min, 0)} min`) : "—"}</b>
          <small>Periode bei ωc</small>
        </div>
        {k.hysterese_k !== null && k.hysterese_k !== undefined ? (
          <div>
            <span>Hysterese</span>
            <b>{de(k.hysterese_k, 1)} K</b>
            <small>aus der Taktzahlgrenze</small>
          </div>
        ) : null}
      </div>
      {s.halbregel ? (
        <p className="rk-text">
          Zwei Zeitkonstanten, deshalb die Halbregel von Skogestad: die kleinere geht zur Hälfte in die große ({de(s.t1_entwurf, 0)} min) und zur Hälfte in die Totzeit ({de(s.totzeit_entwurf, 1)} min). Entworfen wird mit diesen beiden Zahlen.
        </p>
      ) : null}
      <Kennlinie k={k} />
    </>
  );
}

function Parameterzeile({ p, offen, onOeffne, onStellen, onFreigeben, busy }: { p: RegelkreisParameter; offen: boolean; onOeffne: () => void; onStellen: (wert: number) => void; onFreigeben: () => void; busy: boolean }) {
  const [feld, setFeld] = useState(String(p.wert));
  const h = HERKUNFT[p.herkunft];
  return (
    <>
      <tr className="rk-zeile" onClick={onOeffne}>
        <td className="mono">
          <span className="rk-punkt" style={{ background: h.farbe }} />
          {p.symbol}
        </td>
        <td>{p.name}</td>
        <td className="rk-num mono">
          {de(p.wert, p.stellen)}
          {p.einheit === "—" ? "" : ` ${p.einheit}`}
        </td>
        <td className="rk-num mono">{p.sigma !== null && p.sigma !== undefined ? `±${de(2 * p.sigma, p.stellen)}` : "—"}</td>
        <td className="rk-num mono">{p.n ? p.n.toLocaleString("de-DE") : "—"}</td>
        <td className="rk-klein" style={{ color: h.farbe }}>
          {h.text}
        </td>
      </tr>
      {offen ? (
        <tr>
          <td colSpan={6} className="rk-ausklapp">
            <p className="rk-text">{p.warum}</p>
            <p className="rk-klein">
              {p.schaetzart_text}
              {p.quelle ? ` Quelle: ${p.quelle}.` : ""}
            </p>
            <p className="rk-klein">
              Startwert {de(p.startwert, p.stellen)}
              {p.einheit === "—" ? "" : ` ${p.einheit}`} · Grenzen {de(p.unten, p.stellen)} bis {de(p.oben, p.stellen)}
              {p.schaetzung !== null && p.schaetzung !== undefined ? ` · laufende Schätzung ${de(p.schaetzung, p.stellen)}` : ""}
              {p.rmse !== null && p.rmse !== undefined ? ` · Restfehler ${de(p.rmse, 3)}` : ""}
            </p>
            {p.wirkt_auf.length ? <p className="rk-klein">Wirkt auf: {p.wirkt_auf.join(" · ")}</p> : null}
            {p.pruefung && !p.pruefung.uebernehmen ? (
              <p className="rk-pruefung">
                <b>Noch nicht übernommen.</b> {p.pruefung.grund}
              </p>
            ) : null}
            <div className="rk-stellen">
              <input
                type="number"
                step="any"
                value={feld}
                onChange={(e) => setFeld(e.target.value)}
                aria-label={`Eigener Wert für ${p.name}`}
                className="rk-feld mono"
              />
              <button className="rk-knopf" disabled={busy} onClick={() => onStellen(Number(feld.replace(",", ".")))}>
                Übersteuern
              </button>
              {p.herkunft === "uebersteuert" ? (
                <button className="rk-knopf" disabled={busy} onClick={onFreigeben}>
                  Dem Lernen überlassen
                </button>
              ) : null}
            </div>
            {p.protokoll.length ? (
              <table className="rk-protokoll">
                <thead>
                  <tr>
                    <th>Datum</th>
                    <th>alt → neu</th>
                    <th className="rk-num">σ</th>
                    <th className="rk-num">n</th>
                    <th>Grund der Übernahme</th>
                  </tr>
                </thead>
                <tbody>
                  {[...p.protokoll].reverse().map((u, i) => (
                    <tr key={i}>
                      <td className="mono rk-nowrap">{datum(u.at)}</td>
                      <td className="mono">
                        <s>{de(u.alt, p.stellen)}</s> → <b>{de(u.neu, p.stellen)}</b>
                      </td>
                      <td className="rk-num mono">±{de(u.sigma, p.stellen)}</td>
                      <td className="rk-num mono">{u.n.toLocaleString("de-DE")}</td>
                      <td className="rk-klein">{u.grund}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="rk-klein">Noch keine Übernahme: es gilt der Startwert.</p>
            )}
          </td>
        </tr>
      ) : null}
    </>
  );
}

export function Blatt({ d, blockId, onWaehle, onStellen, onFreigeben, busy }: { d: Regelkreis; blockId: string; onWaehle: (id: string) => void; onStellen: (pid: string, wert: number) => void; onFreigeben: (pid: string) => void; busy: boolean }) {
  const [offen, setOffen] = useState<string | null>(null);
  const block = d.bloecke.find((b) => b.id === blockId);
  if (!block) return null;
  const params = d.parameter.filter((p) => p.block === block.id);
  const kreis = block.kreis ? d.kreise.find((k) => k.id === block.kreis) : undefined;
  const hinein = d.kanten.filter((k) => k.nach === block.id);
  const hinaus = d.kanten.filter((k) => k.von === block.id);
  const name = (id: string) => d.bloecke.find((b) => b.id === id)?.name ?? id;
  return (
    <Card>
      <CardHead
        title={`Ebene ${block.ebene} · ${block.rolle_text}${block.kreis ? ` · Kreis ${block.kreis}` : ""}`}
        right={block.behandlung_text ?? undefined}
      />
      <h3 className="rk-titel">{block.name}</h3>
      {block.erklaerung.map((t, i) => (
        <p key={i} className="rk-text">
          {t}
        </p>
      ))}
      {block.gleichungen.length ? (
        <div className="rk-gleichungen">
          {block.gleichungen.map((g, i) => (
            <code key={i}>{g}</code>
          ))}
        </div>
      ) : null}
      {params.length ? (
        <>
          <p className="kicker rk-abschnitt">Parameter — Zeile anklicken für Verlauf und Übersteuerung</p>
          <table className="rk-tabelle">
            <thead>
              <tr>
                <th>Größe</th>
                <th>Bedeutung</th>
                <th className="rk-num">Wert</th>
                <th className="rk-num">Unsicherheit</th>
                <th className="rk-num">n</th>
                <th>Herkunft</th>
              </tr>
            </thead>
            <tbody>
              {params.map((p) => (
                <Parameterzeile
                  key={p.id}
                  p={p}
                  offen={offen === p.id}
                  onOeffne={() => setOffen(offen === p.id ? null : p.id)}
                  onStellen={(wert) => onStellen(p.id, wert)}
                  onFreigeben={() => onFreigeben(p.id)}
                  busy={busy}
                />
              ))}
            </tbody>
          </table>
        </>
      ) : null}
      {kreis ? (
        <>
          <p className="kicker rk-abschnitt">Entwurf und Reserven · {kreis.name}</p>
          {kreis.erklaerung.map((t, i) => (
            <p key={i} className="rk-text">
              {t}
            </p>
          ))}
          <Entwurf k={kreis} />
        </>
      ) : null}
      <p className="kicker rk-abschnitt">Signale</p>
      <div className="rk-signale">
        {hinein.map((k) => (
          <div key={`in-${k.von}-${k.signal}`}>
            <b>← {k.signal}</b>
            <button onClick={() => onWaehle(k.von)}>{name(k.von)}</button>
          </div>
        ))}
        {hinaus.map((k) => (
          <div key={`out-${k.nach}-${k.signal}`}>
            <b>→ {k.signal}</b>
            <button onClick={() => onWaehle(k.nach)}>{name(k.nach)}</button>
          </div>
        ))}
        {block.marke ? (
          <div>
            <b>◂ {block.marke}</b>
            <span className="rk-klein">über Signalmarke, nicht gezeichnet</span>
          </div>
        ) : null}
      </div>
    </Card>
  );
}
