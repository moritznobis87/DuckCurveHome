"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AreaShell } from "@/components/layout/AreaShell";
import { Card, CardHead } from "@/components/ui/Card";
import { Stellen } from "@/components/rooms/Stellen";
import { api, ApiError } from "@/lib/api/client";
import type { House, HouseContactPlan, RoomsLive } from "@/lib/api/models";
import { celsius } from "@/lib/format";
import { startLiveClient } from "@/lib/live/sseClient";
import { useLiveStore } from "@/lib/live/store";
import { useRole } from "@/lib/live/useRole";
import type { FokusInfo, HausSzene } from "./HouseScene";
import { hausLive, type HausLive } from "./live";
import type { Ort } from "./insights";
import { Konsole, type Klappe } from "./Konsole";

/**
 * Das Haus als Modell: beide Geschosse als Glas, die Raeume in ihrer Temperatur, Tueren und
 * Fenster mit Kontakt, die Alarmanlage als Schild um die Aussenhaut, Puffer, Waermepumpe und
 * Wallbox an ihrem Platz.
 *
 * **Woher das Bild kommt.** Die Geometrie ist eine Datei neben der Entity-Zuordnung auf dem
 * Home-Assistant-Rechner; die Bruecke liest sie und meldet sie als Ereignis, der Dienst liefert
 * sie unter `/haus`. Hier wird sie nur gezeichnet. Die Werte dazu kommen aus drei Quellen, die es
 * schon gibt: die Raeume (`/rooms`, alle 30 Sekunden, haeufiger fragt Controme nicht), der
 * Hausplan mit seinen Kontakten (`/haus`, alle 10 Sekunden) und der Live-Strom fuer Alarm,
 * Puffer, Waermepumpe und Wallbox.
 *
 * **Tippen auf einen Raum** oeffnet ihn: gross die Temperatur, das Ziel, der Heizkreis, seine
 * Kontakte. Der Sollwert wird im selben Fenster gestellt wie auf der Raumseite, mit der
 * geschaetzten Wirkung daneben; eine zweite Stellmechanik waere eine zweite Wahrheit.
 *
 * **Die Bloecke links klappen auf** und beantworten die Anschlussfrage zu ihrer Zahl (siehe
 * `Konsole`); aus einer Zeile dort springt das Modell in den Raum, der gemeint ist.
 *
 * three.js wird erst im Browser geladen: Die Szene braucht WebGL und das Dokument, und das
 * halbe Megabyte soll nicht in jeder anderen Seite mitreisen.
 */
const HAUS_MS = 10_000;
const RAEUME_MS = 30_000;

export function HouseReport() {
  const role = useRole();
  const state = useLiveStore((s) => s.state);
  const [house, setHouse] = useState<House | null>(null);
  const [rooms, setRooms] = useState<RoomsLive | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [fokus, setFokus] = useState<FokusInfo | null>(null);
  const [stellt, setStellt] = useState<number | null>(null);
  const [sichtbar, setSichtbar] = useState<string>("alle");
  const [klappe, setKlappe] = useState<Klappe | null>(null);
  const [alarmMeldung, setAlarmMeldung] = useState<string | null>(null);
  const [alarmBusy, setAlarmBusy] = useState(false);
  // Die Uhr des Servers: im Demo-Betrieb laeuft sie im Zeitraffer, und „seit 12 min" soll sich auf
  // sie beziehen und nicht auf die des Geraets.
  const [nowMs, setNowMs] = useState(() => Date.now());
  const buehne = useRef<HTMLDivElement>(null);
  const szene = useRef<HausSzene | null>(null);
  const history = useLiveStore((s) => s.history);

  useEffect(() => startLiveClient(), []);
  useEffect(() => {
    const tick = () => setNowMs(Date.now() + useLiveStore.getState().serverOffsetMs);
    tick();
    const t = setInterval(tick, 10_000);
    return () => clearInterval(t);
  }, []);

  const ladeHaus = useCallback(async () => {
    try {
      setHouse(await api.house());
      setFehler(null);
    } catch (e) {
      setFehler(e instanceof ApiError ? e.message : "Der Hausplan konnte nicht geladen werden.");
    }
  }, []);
  const ladeRaeume = useCallback(async () => {
    try {
      setRooms(await api.rooms());
    } catch {
      /* die Raeume fehlen dann, das Modell steht trotzdem */
    }
  }, []);
  useEffect(() => {
    void ladeHaus();
    void ladeRaeume();
    const a = setInterval(() => void ladeHaus(), HAUS_MS);
    const b = setInterval(() => void ladeRaeume(), RAEUME_MS);
    return () => {
      clearInterval(a);
      clearInterval(b);
    };
  }, [ladeHaus, ladeRaeume]);

  const live: HausLive = useMemo(() => hausLive(rooms?.rooms ?? null, house, state), [rooms, house, state]);
  const plan = house?.present ? house.plan : null;
  // Ein neuer Plan ist eine neue Szene. Der Stand kommt mit dem Ereignis; die Vorfuehrung hat
  // immer denselben.
  const planKennung = plan ? `${house?.received_at ?? ""}:${plan.decks.map((d) => d.key + d.rooms.length + (d.items?.length ?? 0)).join("/")}` : "";

  useEffect(() => {
    const wurzel = buehne.current;
    if (!wurzel || !plan) return;
    let verworfen = false;
    const params = new URLSearchParams(window.location.search);
    void import("./HouseScene").then(({ HausSzene }) => {
      if (verworfen || !buehne.current) return;
      const s = new HausSzene({
        root: wurzel,
        plan,
        onFokus: setFokus,
        start: { sichtbar: params.get("deck") ?? undefined, drehung: Number(params.get("dreh") ?? 0) || undefined, fokus: params.get("fokus") ?? undefined },
      });
      szene.current = s;
      setSichtbar(s.sichtbaresDeck);
      if (params.get("fokus")) {
        const deck = plan.decks.find((d) => d.rooms.some((r) => r.name === params.get("fokus") && !r.part_of));
        const raum = deck?.rooms.find((r) => r.name === params.get("fokus") && !r.part_of);
        if (deck && raum) setFokus({ deck: deck.key, raum });
      }
    });
    return () => {
      verworfen = true;
      szene.current?.dispose();
      szene.current = null;
    };
    // Die Szene haengt am Stand des Plans, nicht am Objekt: `planKennung` wechselt genau dann.
  }, [planKennung]);

  useEffect(() => {
    szene.current?.setLive(live);
  }, [live, planKennung]);

  const waehleDeck = (key: string) => {
    setSichtbar(key);
    szene.current?.setSichtbar(key);
  };
  const schliesseFokus = () => {
    setFokus(null);
    szene.current?.setFokus(null, null);
  };

  /** Aus einer Zeile der Konsole in den Raum: notfalls das Geschoss wechseln, dann scharf stellen. */
  const springe = (ort: Ort) => {
    const deck = plan?.decks.find((d) => d.key === ort.deck);
    const raum = deck?.rooms.find((r) => r.name === ort.raum && !r.part_of);
    if (!deck || !raum) return;
    if (sichtbar !== "alle" && sichtbar !== deck.key) waehleDeck(deck.key);
    szene.current?.setFokus(deck.key, raum.name);
    setFokus({ deck: deck.key, raum });
    setKlappe(null);
  };

  const scharf = async (mode: "home" | "away") => {
    setAlarmBusy(true);
    setAlarmMeldung(null);
    try {
      const r = await api.armAlarm(mode);
      setAlarmMeldung(r.message_de);
    } catch (e) {
      setAlarmMeldung(e instanceof ApiError ? e.message : "Die Anlage hat nicht bestätigt.");
    } finally {
      setAlarmBusy(false);
    }
  };

  const decks = plan?.decks ?? [];
  const fokusRaum = fokus?.raum ?? null;
  const fokusWerte = fokusRaum?.room_id != null ? live.raeume.get(fokusRaum.room_id) ?? null : null;
  const fokusKontakte: HouseContactPlan[] = useMemo(() => {
    if (!fokus || !plan) return [];
    const deck = plan.decks.find((d) => d.key === fokus.deck);
    return (deck?.contacts ?? []).filter((k) => k.room === fokus.raum.name);
  }, [fokus, plan]);
  const alarm = state?.alarm ?? null;
  const kannScharf = !!alarm?.can_arm && role === "owner";

  return (
    <AreaShell
      kicker={plan ? `${plan.name || "Hausplan"} · ${house?.source_de ?? ""}` : "Hausplan"}
      right={
        plan ? (
          <div className="haus-werkzeuge">
            <div className="haus-gruppe" role="tablist" aria-label="Geschoss">
              <button role="tab" aria-selected={sichtbar === "alle"} className={sichtbar === "alle" ? "an" : ""} onClick={() => waehleDeck("alle")}>
                {decks.length > 1 ? "Alle" : "Haus"}
              </button>
              {decks.length > 1
                ? decks.map((d) => (
                    <button key={d.key} role="tab" aria-selected={sichtbar === d.key} className={sichtbar === d.key ? "an" : ""} onClick={() => waehleDeck(d.key)}>
                      {d.name}
                    </button>
                  ))
                : null}
            </div>
            <div className="haus-gruppe">
              <button className="rund" aria-label="Nach links drehen" onClick={() => szene.current?.drehen(-1)}>↺</button>
              <button className="rund" aria-label="Nach rechts drehen" onClick={() => szene.current?.drehen(1)}>↻</button>
            </div>
          </div>
        ) : undefined
      }
    >
      {fehler ? <p className="m-0 rounded-[4px] border border-line-2 px-3 py-2 text-[13px] text-text-2">{fehler}</p> : null}

      {house && !plan ? (
        <Card style={{ padding: 20 }}>
          <CardHead title="Kein Hausplan" />
          <p className="m-0 max-w-[72ch] text-[13px] leading-[1.5] text-text-2">{house.error_de}</p>
          <p className="m-0 mt-2 max-w-[72ch] text-[12px] leading-[1.5] text-text-3">
            Die Vorlage liegt im Repository unter <code>config/haus.example.yaml</code>; sie beschreibt jede Art von Eintrag.
            Die Bruecke liest die Datei alle 30 Sekunden neu, ein Neustart ist nicht noetig.
          </p>
        </Card>
      ) : null}

      {plan ? (
        <div className="haus-seite">
          <Konsole
            live={live}
            state={state}
            rooms={rooms?.rooms ?? null}
            plan={plan}
            history={history}
            nowMs={nowMs}
            offen={klappe}
            onKlappe={setKlappe}
            onSpringe={springe}
            alarm={{ kannScharf, busy: alarmBusy, meldung: alarmMeldung, nurAnsicht: role !== "owner", onScharf: (m) => void scharf(m) }}
          />

          <div className="haus-buehne-huelle">
            <div ref={buehne} className="haus-buehne" aria-label="Hausmodell" />
            <div className="haus-legende">
              <span className="kicker" style={{ fontSize: 10 }}>kalt</span>
              <span className="haus-balken" />
              <span className="kicker" style={{ fontSize: 10 }}>warm</span>
              <span className="kicker" style={{ fontSize: 10, marginLeft: 8 }}>gelb: unter Ziel · tippen: Raum</span>
            </div>
            {fokusRaum ? (
              <section className="haus-panel" aria-label={`${fokusRaum.name}`}>
                <div className="flex items-baseline justify-between gap-3">
                  <div>
                    <div className="kicker" style={{ fontSize: 10 }}>{decks.find((d) => d.key === fokus?.deck)?.name ?? ""}</div>
                    <div className="text-[18px] font-semibold">{fokusRaum.name}</div>
                  </div>
                  <button className="haus-zu" onClick={schliesseFokus}>Schließen</button>
                </div>
                {fokusRaum.room_id != null ? (
                  <>
                    <div className="flex items-baseline gap-2">
                      <span className="mono text-[44px] font-medium leading-none tracking-[-.03em]">{fokusWerte?.temp_c == null ? "-" : fokusWerte.temp_c.toLocaleString("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}</span>
                      <span className="mono text-[14px] text-text-3">°C gemessen</span>
                    </div>
                    <div className="haus-zeile">
                      <span className="k">Ziel</span>
                      <span className="v">{celsius(fokusWerte?.target_c ?? fokusWerte?.setpoint_c, 1)}</span>
                    </div>
                    <div className="haus-zeile">
                      <span className="k">Heizkreis</span>
                      <span className="v">{fokusWerte?.valve == null ? "-" : `${Math.round(fokusWerte.valve * 100)} %`}</span>
                    </div>
                  </>
                ) : (
                  <p className="m-0 text-[13px] text-text-3">Kein Thermostat in diesem Raum.</p>
                )}
                <div className="haus-zeile" style={{ flexDirection: "column", alignItems: "stretch", gap: 6 }}>
                  <span className="k">Fenster und Türen</span>
                  <ul>
                    {fokusKontakte.length === 0 ? <li className="leer">keine Kontakte in diesem Raum</li> : null}
                    {fokusKontakte.map((k) => {
                      const z = live.kontakte.get(k.key);
                      const wort = z?.open === true ? "offen" : z?.open === false ? "zu" : "keine Meldung";
                      return (
                        <li key={k.key} className={z?.open ? "offen" : ""}>
                          {k.name}
                          <span>{wort}</span>
                        </li>
                      );
                    })}
                  </ul>
                </div>
                {fokusRaum.room_id != null && fokusWerte ? (
                  <button className="haus-stellen" onClick={() => setStellt(fokusRaum.room_id ?? null)}>
                    Sollwert stellen
                  </button>
                ) : null}
              </section>
            ) : null}
          </div>
        </div>
      ) : null}

      {plan?.note_de ? <p className="m-0 max-w-[90ch] text-[11px] leading-[1.5] text-text-3">{plan.note_de}</p> : null}

      {stellt != null && rooms ? (
        (() => {
          const raum = rooms.rooms.find((r) => r.id === stellt);
          if (!raum) return null;
          return <Stellen raum={raum} readOnly={role !== "owner"} onClose={() => setStellt(null)} onDone={() => void ladeRaeume()} />;
        })()
      ) : null}
    </AreaShell>
  );
}

