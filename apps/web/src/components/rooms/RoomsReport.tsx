"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api/client";
import type { RoomHistory, RoomLive, RoomSeries, RoomsLive } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";
import { ErrorBanner, Note, ReportShell, usePeriod } from "@/components/reports/ReportShell";
import { celsius, hhmm } from "@/lib/format";
import { isoToday } from "@/lib/day";
import { abweichungText, anteilText, BAND_K, farbe, fensterText, kelvin, KEIN_WERT, NOCH_NICHT, STUFEN, ventilText, zahl1 } from "./palette";
import { abweichungen, etagenText, gruppiere, mittel, offenSeitMin, ziel } from "./logic";
import { Stellen } from "./Stellen";
import { useRole } from "@/lib/live/useRole";

/**
 * Die Räume des Hauses: wie warm sie sind, wohin sie sollen, und wie weit die Heizkreise offen
 * standen.
 *
 * **Wozu diese Seite da ist.** Die Wärmeseiten zeigen, wie viel Wärme erzeugt wurde und was sie
 * gekostet hat. Wohin sie gegangen ist, war bisher eine einzige Zahl, die als Rest einer
 * Umkehrrechnung herausfiel. Hier steht sie je Raum - und mit den Ventilstellungen daneben die
 * Frage, die über die nötige Vorlauftemperatur entscheidet: Welcher Raum kommt zuerst nicht mehr
 * mit? Ein Raum, dessen Kreise den ganzen Tag offen sind und der trotzdem unter dem Sollwert
 * bleibt, bestimmt die Vorlauftemperatur für alle anderen mit.
 *
 * **Geregelt wird in Controme, gestellt auch von hier.** Die Ventile bleiben Sache des Reglers:
 * Der Fußboden hat Zeitkonstanten um 13 Stunden, der Raum um 25; auf dieser Skala gewinnt niemand
 * durch feinere Taktung. Der Sollwert dagegen ist der Griff, den auch ein Mensch benutzt - ein
 * Tippen auf eine Kachel öffnet ihn, mit der geschätzten Wirkung daneben. Gestellt wird dauerhaft,
 * ohne Frist, und nur für heute: Wer einen vergangenen Tag liest, soll nicht in die Gegenwart
 * greifen, ohne es zu merken.
 */

/** Wie oft die Istwerte neu geholt werden. Controme fragt seine Fühler alle zwei Minuten ab, und
 *  die Fühler selbst melden alle drei bis fünf - häufiger zu fragen erzeugt nur Last. */
const LIVE_MS = 30_000;
/** Fensterbreite der Tageszeitreihe: 96 Viertelstunden. */
const STEP_MIN = 15;

// ------------------------------------------------------------------ Bausteine

function Legende() {
  return (
    <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
      <div className="flex items-center gap-2.5">
        <span className="kicker" style={{ fontSize: 11 }}>Abweichung</span>
        <div className="flex items-center gap-[2px]">
          {STUFEN.map((s) => (
            <div key={s.marke} className="flex flex-col items-center gap-1">
              <span style={{ display: "inline-block", width: 30, height: 10, borderRadius: 2, background: s.farbe }} />
              <span className="mono text-[10px] text-text-3">{s.marke}</span>
            </div>
          ))}
        </div>
      </div>
      <div className="flex items-center gap-4 border-l border-line-1 pl-5">
        <span className="flex items-center gap-2">
          <span style={{ display: "inline-block", width: 18, height: 8, borderRadius: 2, background: "var(--valve-open)" }} />
          <span className="mono text-[11px] text-text-2">Ventil offen</span>
        </span>
        <span className="flex items-center gap-2">
          <span style={{ display: "inline-block", width: 18, height: 8, borderRadius: 2, background: KEIN_WERT, border: "1px solid var(--line-1)" }} />
          <span className="mono text-[11px] text-text-2">kein Messwert</span>
        </span>
      </div>
    </div>
  );
}

/** Der Streifen der Ventilstellungen unter einer Kachel, ein Feld je Zeitfenster.
 *
 *  **Auf oder zu, nichts dazwischen** - die verbauten Antriebe kennen keine Zwischenstellung. Ein
 *  Zwischenwert im Streifen heißt deshalb nicht „halb offen", sondern „ein Teil der Kreise offen"
 *  oder „einen Teil des Fensters offen". Die Deckkraft zeigt diesen Anteil, die Farbe ist dieselbe. */
function VentilStreifen({ serie, ts, proStunde, bisMs }: { serie: (number | null)[]; ts: string[]; proStunde: number; bisMs: number }) {
  // Auf Stunden verdichtet. In der Kachel sind 96 Viertelstunden rund drei Bildpunkte breit, und
  // das ergab einen gesprenkelten Streifen, in dem nichts mehr zu erkennen war - 24 Felder zu
  // zwölf Punkten sagen dasselbe und sind zu lesen.
  const stunden = Array.from({ length: Math.ceil(serie.length / proStunde) }, (_, h) => {
    const teil = serie.slice(h * proStunde, (h + 1) * proStunde).filter((v): v is number => v != null);
    const zeit = ts[h * proStunde];
    return {
      wert: teil.length ? teil.reduce((a, b) => a + b, 0) / teil.length : null,
      zeit,
      kuenftig: zeit != null && new Date(zeit).getTime() > bisMs,
    };
  });
  return (
    <div className="flex h-[7px] gap-px" role="img" aria-label="Ventilstellungen über den Tag">
      {stunden.map((s, h) => (
        <span
          key={s.zeit ?? h}
          title={`${hhmm(s.zeit)} · ${s.kuenftig ? "noch nicht" : anteilText(s.wert)}`}
          style={{
            flex: "1 1 0",
            borderRadius: 1,
            background: s.kuenftig
              ? NOCH_NICHT
              : s.wert == null
                ? KEIN_WERT
                : s.wert > 0
                  ? "var(--valve-open)"
                  : "rgba(255,255,255,.07)",
            opacity: s.wert == null || s.wert === 0 ? 1 : 0.35 + 0.65 * s.wert,
          }}
        />
      ))}
    </div>
  );
}

/**
 * Der Temperaturverlauf einer Kachel.
 *
 * **Gleiche Grad je Bildpunkt in allen Kacheln.** Jede Kurve auf ihre eigene Spanne zu dehnen hätte
 * aus 0,2 K Rauschen im einen Raum dasselbe Bild gemacht wie aus 2 K Unterdeckung im anderen. Die
 * Spanne ist deshalb fest, ±2 K um den Sollwert, und wächst nur, wenn ein Raum darüber hinausgeht -
 * dann steht sie an der Achse. Die gestrichelte Linie ist der Sollwert und liegt immer in der Mitte.
 */
function Verlauf({ serie, ts, proStunde, linie, bisMs }: { serie: RoomSeries; ts: string[]; proStunde: number; linie: string; bisMs: number }) {
  const abw = abweichungen(serie);
  const groesste = Math.max(2, ...abw.filter((v): v is number => v != null).map((v) => Math.ceil(Math.abs(v))));
  const H = 44;
  const y = (d: number) => H / 2 - (d / groesste) * (H / 2 - 3);
  // Abschnitte zwischen Lücken getrennt zeichnen. Eine durchgezogene Linie über eine Lücke wäre
  // eine Behauptung über Minuten, in denen nichts gemessen wurde.
  const stuecke: string[] = [];
  let lauf: string[] = [];
  abw.forEach((d, i) => {
    if (d == null) {
      if (lauf.length > 1) stuecke.push(lauf.join(" "));
      lauf = [];
      return;
    }
    const x = abw.length > 1 ? (i / (abw.length - 1)) * 320 : 0;
    lauf.push(`${lauf.length === 0 ? "M" : "L"} ${x.toFixed(1)} ${y(d).toFixed(1)}`);
  });
  if (lauf.length > 1) stuecke.push(lauf.join(" "));
  // Dieselbe Farbe wie das Abzeichen daneben. Vorher kam sie aus dem letzten Punkt der Reihe, und
  // das ist an einem vergangenen Tag der Wert um Mitternacht - eine Kurve in Bernstein neben einem
  // Abzeichen mit „auf Soll" ist ein Widerspruch, den niemand auflösen kann.

  return (
    <div className="flex flex-col gap-[3px]">
      <svg viewBox={`0 0 320 ${H}`} preserveAspectRatio="none" style={{ width: "100%", height: H, display: "block" }} role="img" aria-label="Abweichung vom Zielwert über den Tag">
        <line x1="0" y1={H / 2} x2="320" y2={H / 2} stroke="var(--line-2)" strokeWidth="1" strokeDasharray="3 3" />
        {stuecke.map((d) => (
          <path key={d.slice(0, 24)} d={d} fill="none" stroke={linie} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
        ))}
      </svg>
      <VentilStreifen serie={serie.valve} ts={ts} proStunde={proStunde} bisMs={bisMs} />
      <div className="mono relative flex justify-between text-[9px] text-text-3">
        <span>00</span>
        <span>12</span>
        <span>24</span>
        {/* Nur wenn die Spanne von den üblichen ±2 K abweicht. Sonst stünde an jeder der neun
            Kacheln dieselbe Zahl und sagte nichts. */}
        {groesste > 2 ? <span className="absolute -top-[13px] right-0 text-text-3">±{groesste} K</span> : null}
      </div>
    </div>
  );
}

/** Ein Raum als Kachel. Tippbar, wenn der laufende Tag angezeigt wird. */
function RaumKachel({ raum, serie, ts, proStunde, bisMs, stepMin, onStellen }: { raum: RoomLive; serie: RoomSeries | undefined; ts: string[]; proStunde: number; bisMs: number; stepMin: number; onStellen?: () => void }) {
  const d = raum.deviation_k;
  const stumm = raum.temp_c == null;
  const hatOffset = raum.offset_k != null && Math.abs(raum.offset_k) >= 0.05;
  const aufSoll = d != null && Math.abs(d) <= BAND_K;
  const tagesventil = serie ? mittel(serie.valve) : null;
  // Wie lange schon gelüftet wird. Der Index des letzten gemessenen Fensters kommt aus der
  // Zeitachse, nicht aus der Länge: am laufenden Tag steht hinter der Gegenwart noch nichts.
  const letzter = ts.reduce((acc, t, i) => (new Date(t).getTime() <= bisMs ? i : acc), -1);
  const offenSeit = serie && letzter >= 0 ? offenSeitMin(serie.window, stepMin, letzter) : null;
  const fenster = fensterText(raum.window, offenSeit);
  // **An der Grenze**: die Kreise standen fast den ganzen Tag offen, und der Raum ist trotzdem zu
  // kalt. Dann ist nicht die Einzelraumregelung am Zug, sondern die Vorlauftemperatur - dieser Raum
  // bestimmt sie für alle anderen mit.
  // **Ein offenes Fenster nimmt die Anklage zurück.** Ohne die Kontakte sah ein gelüfteter Raum
  // genauso aus wie einer, für den die Vorlauftemperatur nicht reicht - und die Seite schob es auf
  // die Heizkurve. Steht das Fenster offen, ist die Erklärung bekannt und harmlos.
  const anDerGrenze = tagesventil != null && tagesventil >= 0.85 && d != null && d < -BAND_K && !fenster;

  const Huelle = onStellen ? "button" : "div";
  return (
    <Huelle
      className={`card flex flex-col gap-3 text-left ${onStellen ? "raum-kachel-tippbar" : ""}`}
      style={{ padding: "16px 18px 14px" }}
      onClick={onStellen}
      {...(onStellen ? { "aria-label": `${raum.name}: Sollwert stellen` } : {})}
    >
      <div className="flex items-baseline justify-between gap-2.5">
        <span className="text-[15px] font-medium text-text-1">{raum.name}</span>
        {fenster ? (
          <span className="mono shrink-0 rounded-[2px] border px-[5px] py-px text-[10px] uppercase tracking-[.08em]" style={{ borderColor: "var(--mist)", color: "var(--mist)" }} title="Ein Fensterkontakt dieses Raums meldet offen. Solange das so ist, sagt eine Unterschreitung nichts über die Heizkurve.">
            {fenster}
          </span>
        ) : anDerGrenze ? (
          // Farblos und mit Zeichen. Ein bernsteinfarbenes Abzeichen stünde in der Farbe, die auf
          // dieser Seite „zu warm" heißt, und sagte damit das Gegenteil.
          <span className="mono shrink-0 rounded-[2px] border border-line-2 px-[5px] py-px text-[10px] uppercase tracking-[.08em] text-text-2" title="Die Heizkreise standen fast den ganzen Tag offen und der Raum ist trotzdem unter dem Zielwert. Dieser Raum bestimmt die nötige Vorlauftemperatur mit.">
            ! an der Grenze
          </span>
        ) : null}
      </div>

      <div className="flex items-end justify-between gap-3">
        {stumm ? (
          <span className="mono text-[20px] leading-none text-text-3">kein Messwert</span>
        ) : (
          <div className="flex items-baseline gap-[3px]">
            <span className="mono text-[34px] font-medium leading-none tracking-[-.02em]">{raum.temp_c == null ? "-" : zahl1(raum.temp_c)}</span>
            <span className="mono text-[14px] text-text-3">°C</span>
          </div>
        )}
        <div className="flex flex-col items-end gap-1">
          {/* **Ziel, nicht Soll.** Geregelt wird auf Sollwert plus Offset - Controme rechnet es
              in seiner eigenen Oberfläche vor. Die beiden Zahlen stehen darunter, solange der
              Offset nicht null ist: dann ist die Rechnung nachvollziehbar, und ein vertauschtes
              Vorzeichen fiele beim Vergleich mit Controme sofort auf. */}
          <span
            className="mono text-[11px] text-text-3"
            title={hatOffset ? `Sollwert ${celsius(raum.setpoint_c, 1)}, Offset ${kelvin(raum.offset_k ?? 0)}` : undefined}
          >
            Ziel {celsius(raum.target_c ?? raum.setpoint_c, 1)}
          </span>
          {hatOffset ? (
            <span className="mono text-[10px] text-text-3 opacity-70">
              {celsius(raum.setpoint_c, 1)} {kelvin(raum.offset_k ?? 0)}
            </span>
          ) : null}
          <span
            className="mono text-[11px] font-medium"
            style={{
              padding: "2px 7px",
              borderRadius: 2,
              background: stumm ? "transparent" : farbe(d ?? 0),
              border: stumm ? "1px solid var(--line-2)" : "none",
              color: stumm ? "var(--text-3)" : aufSoll ? "var(--text-2)" : "var(--deep)",
            }}
          >
            {abweichungText(d)}
          </span>
        </div>
      </div>

      {serie ? <Verlauf serie={serie} ts={ts} proStunde={proStunde} linie={stumm ? "var(--text-3)" : farbe(d ?? 0)} bisMs={bisMs} /> : <div className="h-[60px]" />}

      <div className="mono flex justify-between border-t border-line-1 pt-2 text-[11px] text-text-3">
        <span title="Jetzt">Ventil {ventilText(raum.valve, raum.circuits)}</span>
        <span>{raum.humidity_pct != null ? `${Math.round(raum.humidity_pct)} % rF` : ""}</span>
      </div>
    </Huelle>
  );
}

// ------------------------------------------------------------------ Seite

export function RoomsReport() {
  const { period, anchor, setPeriod, move, today } = usePeriod("day");
  const [live, setLive] = useState<RoomsLive | null>(null);
  // Welcher Raum gerade gestellt wird. Nur die Kennung, nicht der Raum selbst: der Wert kommt aus
  // der laufenden Liste, damit das Fenster beim naechsten Takt nicht auf einem alten Stand steht.
  const [stellt, setStellt] = useState<number | null>(null);
  const role = useRole();
  const [tag, setTag] = useState<RoomHistory | null>(null);
  const [error, setError] = useState<string | null>(null);

  const istHeute = !anchor || anchor === isoToday();

  const ladeLive = useCallback(async () => {
    try {
      setLive(await api.rooms());
      setError(null);
    } catch {
      setError("Die Raumwerte konnten nicht geladen werden.");
    }
  }, []);

  useEffect(() => {
    void ladeLive();
    // Nur für den laufenden Tag weiter nachladen. Wer einen vergangenen Tag liest, braucht keine
    // Istwerte, die sich unter der Hand ändern.
    if (!istHeute) return;
    const t = setInterval(() => void ladeLive(), LIVE_MS);
    return () => clearInterval(t);
  }, [ladeLive, istHeute]);

  useEffect(() => {
    if (!anchor) return;
    let abgebrochen = false;
    void (async () => {
      try {
        const d = await api.roomsDay(anchor, STEP_MIN);
        if (!abgebrochen) setTag(d);
      } catch {
        if (!abgebrochen) setTag(null);
      }
    })();
    return () => {
      abgebrochen = true;
    };
  }, [anchor]);

  const serien = useMemo(() => new Map((tag?.rooms ?? []).map((r) => [r.id, r])), [tag]);
  const ts = useMemo(() => tag?.ts ?? [], [tag]);
  // Wie viele Fenster auf eine Stunde gehen. Kommt aus der Antwort, nicht aus STEP_MIN: wenn die
  // Schnittstelle eines Tages eine andere Breite liefert, soll der Streifen trotzdem Stunden zeigen.
  const proStunde = Math.max(1, Math.round(60 / (tag?.step_min ?? STEP_MIN)));
  // **Bis wohin der Tag gemessen ist.** Die Uhr des Servers, nicht die des Browsers: im
  // Demo-Modus läuft sie im Zeitraffer, und ein Browser-Datum zöge dort eine Grenze, die mit den
  // Daten nichts zu tun hat. Ein vergangener Tag ist ganz vorbei.
  const bisMs = useMemo(() => {
    if (!istHeute) return Number.POSITIVE_INFINITY;
    return live ? new Date(live.at).getTime() : Date.now();
  }, [istHeute, live]);
  const kuenftig = useCallback(
    (i: number) => {
      const z = ts[i];
      return z != null && new Date(z).getTime() > bisMs;
    },
    [ts, bisMs],
  );
  // Am vergangenen Tag gibt es keine Istwerte. Dann kommen die Kacheln aus der Zeitreihe, mit dem
  // letzten gemessenen Wert des Tages - sonst wäre die halbe Seite leer.
  const raeume: RoomLive[] = useMemo(() => {
    if (istHeute) return live?.rooms ?? [];
    return (tag?.rooms ?? []).map((s) => {
      const i = s.temp_c.reduce<number>((best, v, k) => (v != null ? k : best), -1);
      const t = (i >= 0 ? s.temp_c[i] : null) ?? null;
      const soll = (i >= 0 ? s.setpoint_c[i] : null) ?? null;
      const off = (i >= 0 ? s.offset_k[i] : null) ?? null;
      const z = i >= 0 ? ziel(s, i) : null;
      return {
        id: s.id,
        name: s.name,
        floor: s.floor,
        circuits: s.circuits,
        temp_c: t,
        setpoint_c: soll,
        offset_k: off,
        target_c: z,
        humidity_pct: null,
        valve: (i >= 0 ? s.valve[i] : null) ?? null,
        window: (i >= 0 ? s.window[i] : null) ?? null,
        deviation_k: t != null && z != null ? t - z : null,
        observed_at: (i >= 0 ? ts[i] : null) ?? null,
        quality: "unavailable",
      } satisfies RoomLive;
    });
  }, [istHeute, live, tag, ts]);

  const gruppen = useMemo(() => gruppiere(raeume), [raeume]);
  const matrix = useMemo(
    () =>
      (tag?.rooms ?? []).map((s) => {
        const abw = abweichungen(s);
        return { id: s.id, name: s.name, abw, schnitt: mittel(abw) };
      }),
    [tag],
  );

  return (
    <ReportShell title="Räume" kicker="Einzelraumregelung · Ist und Soll · Heizkreisverteiler" period={period} anchor={anchor} onPeriod={setPeriod} onMove={move} onToday={today} showPeriods={false}>
      {error ? <ErrorBanner message={error} /> : null}

      {/* Die Legende stand zuerst im Seitenkopf und drängte den Untertitel ins Abschneiden. Sie
          gehört ohnehin über die Kacheln: dort wird sie gebraucht. */}
      {raeume.length > 0 ? <Legende /> : null}

      {live && !live.named && raeume.length > 0 ? (
        <Note>
          Die Räume heißen hier nach ihrer Kennung in der Heizungsregelung. Die Namensliste kommt als
          eigene Meldung der Brücke und steht nach ihrem nächsten Start zur Verfügung.
        </Note>
      ) : null}

      {raeume.length === 0 ? (
        <Card style={{ padding: 20 }}>
          <CardHead title="Keine Räume" />
          <p className="m-0 max-w-[70ch] text-[13px] text-text-2">
            Es liegen keine Werte der Einzelraumregelung vor. Die Brücke liest sie, sobald in ihrer
            Konfiguration die Adresse des Controme-Servers eingetragen ist.
          </p>
        </Card>
      ) : null}

      {gruppen.map((g) => (
        <div key={g.floor} className="flex flex-col gap-3">
          <div className="flex items-baseline gap-3">
            <span className="kicker">{g.floor}</span>
            <span className="mono text-[11px] text-text-3">{etagenText(g.rooms)}</span>
          </div>
          <div className="rooms-grid">
            {g.rooms.map((r) => (
              <RaumKachel
                key={r.id}
                raum={r}
                serie={serien.get(r.id)}
                ts={ts}
                proStunde={proStunde}
                bisMs={bisMs}
                stepMin={tag?.step_min ?? STEP_MIN}
                onStellen={istHeute ? () => setStellt(r.id) : undefined}
              />
            ))}
          </div>
        </div>
      ))}

      {matrix.length > 0 ? (
        <Card style={{ padding: "18px 20px 16px" }}>
          <CardHead
            title="Abweichung im Tagesverlauf"
            right="Je Raum und Viertelstunde die Abweichung vom Zielwert. Der Raum, der zuerst abfällt, bestimmt die nötige Vorlauftemperatur für alle."
          />
          <div className="rooms-matrix mt-3 flex flex-col gap-[3px]">
            {matrix.map((z) => (
              <div key={z.id} className="flex items-center gap-2.5">
                <span className="rooms-matrix-label shrink-0 truncate text-right text-[12px] text-text-2">{z.name}</span>
                <div className="rooms-matrix-cells flex flex-1">
                  {z.abw.map((d, i) => (
                    <span
                      key={ts[i] ?? i}
                      title={`${z.name} · ${hhmm(ts[i])} · ${kuenftig(i) ? "noch nicht" : d == null ? "kein Messwert" : kelvin(d)}`}
                      style={{ flex: "1 1 0", height: 20, borderRadius: 2, background: kuenftig(i) ? NOCH_NICHT : d == null ? KEIN_WERT : farbe(d) }}
                    />
                  ))}
                </div>
                <span className="mono w-[62px] shrink-0 text-right text-[11px] text-text-3">{z.schnitt == null ? "-" : kelvin(z.schnitt)}</span>
              </div>
            ))}
            <div className="flex items-center gap-2.5 pt-0.5">
              <span className="rooms-matrix-label shrink-0" />
              <div className="mono flex flex-1 justify-between text-[10px] text-text-3">
                <span>00:00</span>
                <span>06:00</span>
                <span>12:00</span>
                <span>18:00</span>
                <span>24:00</span>
              </div>
              <span className="mono w-[62px] shrink-0 text-right text-[10px] text-text-3">Mittel</span>
            </div>
          </div>
        </Card>
      ) : null}

      {raeume.length > 0 ? (
        <Card style={{ padding: "18px 20px 16px" }}>
          <CardHead title="Dieselben Werte als Tabelle" />
          <div className="rooms-table mt-3"><table className="w-full border-collapse text-[13px]">
            <thead>
              <tr className="text-left text-text-3">
                <th className="border-b border-line-1 px-2 py-1.5 font-medium">Raum</th>
                <th className="border-b border-line-1 px-2 py-1.5 font-medium">Etage</th>
                <th className="border-b border-line-1 px-2 py-1.5 text-right font-medium">Ist</th>
                <th className="border-b border-line-1 px-2 py-1.5 text-right font-medium">Ziel</th>
                <th className="border-b border-line-1 px-2 py-1.5 text-right font-medium">Abweichung</th>
                <th className="border-b border-line-1 px-2 py-1.5 text-right font-medium">Ventil am Tag</th>
                <th className="border-b border-line-1 px-2 py-1.5 text-right font-medium">Kreise</th>
              </tr>
            </thead>
            <tbody>
              {raeume.map((r) => {
                const s = serien.get(r.id);
                const tagesventil = s ? mittel(s.valve) : null;
                return (
                  <tr key={r.id}>
                    <td className="border-b border-line-1 px-2 py-1.5">{r.name}</td>
                    <td className="border-b border-line-1 px-2 py-1.5 text-text-3">{r.floor || "-"}</td>
                    <td className="mono border-b border-line-1 px-2 py-1.5 text-right">{r.temp_c == null ? "-" : celsius(r.temp_c, 1)}</td>
                    <td className="mono border-b border-line-1 px-2 py-1.5 text-right text-text-2" title={`Sollwert ${celsius(r.setpoint_c, 1)}, Offset ${kelvin(r.offset_k ?? 0)}`}>{celsius(r.target_c ?? r.setpoint_c, 1)}</td>
                    <td className="mono border-b border-line-1 px-2 py-1.5 text-right">{r.deviation_k == null ? "-" : kelvin(r.deviation_k)}</td>
                    <td className="mono border-b border-line-1 px-2 py-1.5 text-right">{anteilText(tagesventil)}</td>
                    <td className="mono border-b border-line-1 px-2 py-1.5 text-right text-text-3">{r.circuits || "-"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table></div>
        </Card>
      ) : null}

      <Note>
        Geregelt wird auf <strong>Sollwert plus Offset</strong> - Controme rechnet das in seiner
        eigenen Oberfläche vor und zeigt das Ergebnis als Zieltemperatur. Der Offset ist dabei die
        Summe mehrerer benannter Anpassungen, nicht nur der Witterung; die beiden Zahlen stehen
        deshalb einzeln unter dem Zielwert. Die Antriebe am Verteiler sind auf oder zu - ein
        Zwischenwert im Streifen heißt „ein Teil der Kreise" oder „einen Teil des Fensters", nicht
        „halb offen". Ein Tippen auf eine Kachel stellt den Sollwert dieses Raums, dauerhaft und
        in halben Grad; die Ventile bleiben Sache des Reglers.
      </Note>

      {stellt != null && live ? (
        (() => {
          const raum = live.rooms.find((r) => r.id === stellt);
          if (!raum) return null;
          return (
            <Stellen
              raum={raum}
              readOnly={role !== "owner"}
              onClose={() => setStellt(null)}
              onDone={() => void ladeLive()}
            />
          );
        })()
      ) : null}
    </ReportShell>
  );
}
