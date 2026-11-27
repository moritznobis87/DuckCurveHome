import { api } from "@/lib/api/client";
import type { Decision, LiveState, Plan } from "@/lib/api/models";
import { isoDay, istTagIso } from "@/lib/day";
import { rowToPoint, useLiveStore } from "./store";

const STREAM_URL = "/api/dch/live/stream";
const STALE_AFTER_MS = 15_000;

/**
 * Ob ein Fehler heißt, dass die Anmeldung nicht mehr gilt. Dann hilft kein Neuverbinden.
 *
 * Die Middleware prüft nur, *ob* ein Anmelde-Cookie da ist, nicht ob die Sitzung dahinter noch
 * gilt. Ist sie abgelaufen, widerrufen oder nach einer Übernahme der Datenbank verschwunden, lädt
 * die Seite trotzdem, der Strom antwortet 401, und EventSource sieht davon nur einen Fehler. Die
 * Startseite stand dann für immer bei „Verbinde mit dem Haus …“ (gemeldet am 26.11.2026).
 */
function abgemeldet(e: unknown): boolean {
  return typeof e === "object" && e !== null && (e as { status?: unknown }).status === 401;
}

function zurAnmeldung(): void {
  window.location.assign("/anmeldung");
}

/**
 * Hält die SSE-Verbindung zum Backend: Reconnect mit Backoff, Erstladung von Zustand und Historie
 * nach jeder (Wieder-)Verbindung, Erkennung ausbleibender Frames. Kein Polling.
 */
export function startLiveClient(): () => void {
  const store = useLiveStore.getState;
  let source: EventSource | null = null;
  let backoff = 1000;
  let closed = false;
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  const loadInitial = async (): Promise<void> => {
    try {
      const [state, history, plan] = await Promise.all([api.liveState(), api.history("today"), api.plan()]);
      // Der Zustand zuerst: er setzt den Zeitversatz zum Server, und ohne den ist „heute" geraten.
      store().setState(state);
      store().setPlan(plan);
      if (state.decision) store().pushDecision(state.decision);
      /**
       * Die Historie kommt als `range=today`, abgelegt wird sie unter dem **Datum** dieses Tages.
       *
       * Hier stand das Wort „today". Das war richtig, solange der Tagesschalter drei feste Stufen
       * hatte; seit daraus ein Kalender wurde, ist `historyDay` ein ISO-Datum. Das Wort überlebte
       * den Umbau und hat die Startseite zerlegt: die Überschrift las „Invalid Date", beide
       * Diagramme blieben leer, weil der Zeitraum des Tages zu NaN wurde und kein Messwert mehr
       * hineinfiel, keine der Schaltflächen Gestern/Heute/Morgen war hervorgehoben, und der
       * Zustandsspeicher hängte auch keine Live-Werte mehr an, weil der laufende Tag nicht mehr
       * „today" heißt. Dass es trotzdem meist ging, lag an einem Zufall: die Adresse trug früher
       * immer ein `?tag=`, und das lud den richtigen Tag gleich wieder nach. Seit der laufende Tag
       * nicht mehr in der Adresse steht, fehlte diese Reparatur.
       *
       * **Nur, wenn die Ansicht auf dem laufenden Tag steht.** Diese Funktion läuft nach *jeder*
       * Wiederverbindung, und die Aufsicht erzwingt eine, sobald 15 s lang kein Rahmen kam. Wer
       * gerade den 12. Oktober liest, soll davon nichts merken.
       */
      const heute = isoDay(store().nowMs());
      const gezeigt = store().historyDay;
      if (!istTagIso(gezeigt) || gezeigt === heute) store().setHistory(history.rows.map(rowToPoint), heute);
    } catch (e) {
      // Sonst liefert der Strom den Zustand ohnehin, und die Historie kommt beim nächsten Verbinden.
      if (abgemeldet(e)) zurAnmeldung();
    }
  };

  const connect = (): void => {
    if (closed) return;
    source?.close();
    source = new EventSource(STREAM_URL);
    source.onopen = () => {
      backoff = 1000;
      void loadInitial();
    };
    source.addEventListener("snapshot", (e) => {
      const data = JSON.parse((e as MessageEvent<string>).data) as LiveState;
      store().setState(data);
      if (data.decision) store().pushDecision(data.decision);
    });
    source.addEventListener("decision", (e) => {
      store().pushDecision(JSON.parse((e as MessageEvent<string>).data) as Decision);
    });
    source.addEventListener("plan", (e) => {
      store().setPlan(JSON.parse((e as MessageEvent<string>).data) as Plan);
    });
    source.onerror = () => {
      source?.close();
      source = null;
      store().setConnection("reconnecting");
      // EventSource verrät den Grund nicht. Eine gewöhnliche Anfrage zeigt, ob es die Anmeldung ist.
      api.liveState().catch((e: unknown) => {
        if (abgemeldet(e)) zurAnmeldung();
      });
      reconnectTimer = setTimeout(connect, backoff + Math.random() * 500);
      backoff = Math.min(backoff * 2, 30_000);
    };
  };

  const watchdog = setInterval(() => {
    const { lastFrameAt, connection } = store();
    if (lastFrameAt && Date.now() - lastFrameAt > STALE_AFTER_MS && connection === "live") {
      store().setConnection("reconnecting");
      source?.close();
      source = null;
      connect();
    }
  }, 5000);

  void loadInitial();
  connect();
  return () => {
    closed = true;
    clearInterval(watchdog);
    if (reconnectTimer) clearTimeout(reconnectTimer);
    source?.close();
  };
}
