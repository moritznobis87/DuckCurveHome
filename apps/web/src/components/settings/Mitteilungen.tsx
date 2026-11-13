"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { PushGeraet } from "@/lib/api/models";
import { hhmm } from "@/lib/format";
import { kurzDatum } from "@/components/waerme/wirkung";
import { abonnement, anmeldung, pushLage, type PushLage } from "@/lib/push/lage";

/**
 * Mitteilungen auf dieses Gerät.
 *
 * **Wozu.** Der Wächter sieht, wenn eine Quelle schweigt. Das nützt nur jemandem, der gerade auf
 * die Wandanzeige sieht - und genau das tat im Oktober 2026 zwei Tage lang niemand. Hier wird der
 * Weg umgedreht: Die Meldung sucht sich den Menschen.
 *
 * **Jedes Gerät einzeln.** Ein Abonnement gehört zu einem Browser auf einem Gerät, nicht zu einem
 * Konto. Das iPad in der Küche soll auch nicht klingeln - es steht ja da und zeigt es an.
 *
 * **Auf dem iPhone erst nach dem Hinzufügen zum Home-Bildschirm.** Safari erlaubt Mitteilungen
 * nur einer installierten Web-App. Steht die Seite nur im Browser, fehlt die Schaltfläche nicht,
 * sondern sie sagt, was zu tun ist: Teilen, „Zum Home-Bildschirm", von dort öffnen.
 *
 * **Der Grund steht da.** Bis zum 12.11.2026 hieß eine gescheiterte Probe „an 0 von 1 Geräten
 * zugestellt", und warum, stand im Protokoll des Dienstes. An dem Tag kam im Haus keine einzige
 * Mitteilung an, und die Seite konnte nicht sagen, woran es lag. Jetzt zeigt sie je Gerät, wann
 * zuletzt eine Mitteilung angenommen wurde und was der Push-Dienst zur letzten gesagt hat.
 */
type Lage = "prüfe" | PushLage;

/** Der öffentliche Schlüssel kommt base64url; die Browser-API will rohe Bytes. */
function schluesselBytes(b64: string): Uint8Array<ArrayBuffer> {
  const fest = (b64 + "=".repeat((4 - (b64.length % 4)) % 4)).replace(/-/g, "+").replace(/_/g, "/");
  const roh = atob(fest);
  // Ueber die Laenge angelegt, nicht ueber `from`: Nur so ist der Puffer ein ArrayBuffer und
  // nicht ein ArrayBufferLike, und nur das nimmt `pushManager.subscribe` an.
  const bytes = new Uint8Array(roh.length);
  for (let i = 0; i < roh.length; i++) bytes[i] = roh.charCodeAt(i);
  return bytes;
}

/**
 * Was schiefgehen kann, in Worten statt als Fehlermeldung.
 *
 * „Registration failed - permission denied" kommt nicht von der Erlaubnis des Nutzers, sondern
 * vom Push-Dienst des Browsers: Er war nicht erreichbar. Das steht so in keiner Meldung, und wer
 * es nicht weiß, sucht an der falschen Stelle (gesehen am 26.10.2026 im Prüfbrowser ohne Zugang
 * zu Googles Push-Dienst).
 */
function hinweis(e: unknown): string {
  const text = e instanceof Error ? e.message : String(e);
  if (/Registration failed/i.test(text)) {
    return `Der Browser konnte kein Abonnement anlegen (${text}). Auf dem iPhone und iPad geht das nur in der zum Home-Bildschirm hinzugefügten App. Sonst war der Push-Dienst des Browsers nicht erreichbar - das sperren manche Netze.`;
  }
  return `Das hat nicht geklappt: ${text}`;
}

function wann(iso: string | null | undefined): string {
  return iso ? `${kurzDatum(iso)}, ${hhmm(iso)}` : "";
}

/** Eine Zeile je Gerät: was es ist, seit wann, und wie es um die Zustellung steht. */
function Geraet({ g }: { g: PushGeraet }) {
  const stand = g.letzter_fehler_de
    ? g.letzter_fehler_de.replace(`${g.label}: `, "")
    : g.zuletzt_ok
      ? `Zuletzt angenommen am ${wann(g.zuletzt_ok)}.`
      : (g.fehlversuche ?? 0) > 0
        ? `Noch keine Mitteilung angenommen, ${g.fehlversuche} ${g.fehlversuche === 1 ? "Versuch" : "Versuche"} gescheitert. Eine Probe zeigt den Grund.`
        : "Noch keine Mitteilung verschickt.";
  const schlecht = Boolean(g.letzter_fehler_de) || (!g.zuletzt_ok && (g.fehlversuche ?? 0) > 0);
  return (
    <li className="geraet">
      <span className="geraet-name">{g.label}</span>
      <span className="geraet-seit">{g.seit ? `angemeldet seit ${kurzDatum(g.seit)}` : ""}</span>
      <span className="geraet-stand" data-schlecht={schlecht}>{stand}</span>
    </li>
  );
}

export function Mitteilungen() {
  const [lage, setLage] = useState<Lage>("prüfe");
  const [geraete, setGeraete] = useState<PushGeraet[] | null>(null);
  const [meldung, setMeldung] = useState<string | null>(null);
  const [details, setDetails] = useState<string[]>([]);
  const [laeuft, setLaeuft] = useState(false);

  const ladeGeraete = useCallback(async () => {
    try {
      setGeraete((await api.pushGeraete()).devices ?? []);
    } catch {
      setGeraete(null);
    }
  }, []);

  useEffect(() => {
    void (async () => {
      const jetzt = await pushLage();
      setLage(jetzt);
      if (jetzt === "an") {
        // Der Browser hat ein Abonnement. Ob der Dienst es noch kennt, weiß er nicht: nach einer
        // neu aufgesetzten Datenbank stünde hier „angemeldet", und es käme nie etwas an. Deshalb
        // meldet sich das Gerät bei jedem Öffnen der Seite still noch einmal; dasselbe Gerät
        // bleibt dabei ein Gerät.
        try {
          const abo = await abonnement();
          if (abo) await api.pushSubscribe(anmeldung(abo));
        } catch {
          // Die Liste darunter zeigt, was der Dienst weiß.
        }
      }
      await ladeGeraete();
    })();
  }, [ladeGeraete]);

  const einschalten = async () => {
    setLaeuft(true);
    setMeldung(null);
    setDetails([]);
    try {
      // Die Erlaubnis muss aus einer Berührung kommen; deshalb steht sie hier und nicht im Effekt.
      const erlaubnis = await Notification.requestPermission();
      if (erlaubnis !== "granted") {
        setLage(erlaubnis === "denied" ? "verboten" : "aus");
        setMeldung("Ohne Erlaubnis des Geräts geht es nicht.");
        return;
      }
      const reg = await navigator.serviceWorker.register("/sw.js");
      await navigator.serviceWorker.ready;
      const { public_key } = await api.pushKey();
      const abo =
        (await reg.pushManager.getSubscription()) ??
        (await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: schluesselBytes(public_key),
        }));
      const antwort = await api.pushSubscribe(anmeldung(abo));
      setLage("an");
      setMeldung(`${antwort.message_de} Am besten gleich eine Probe senden.`);
      await ladeGeraete();
    } catch (e) {
      setMeldung(hinweis(e));
    } finally {
      setLaeuft(false);
    }
  };

  const ausschalten = async () => {
    setLaeuft(true);
    setMeldung(null);
    setDetails([]);
    try {
      const abo = await abonnement();
      if (abo) {
        await api.pushUnsubscribe(abo.endpoint);
        await abo.unsubscribe();
      }
      setLage("aus");
      await ladeGeraete();
      setMeldung("Dieses Gerät bekommt keine Mitteilungen mehr.");
    } catch (e) {
      setMeldung(hinweis(e));
    } finally {
      setLaeuft(false);
    }
  };

  const probe = async () => {
    setLaeuft(true);
    setMeldung(null);
    setDetails([]);
    try {
      const antwort = await api.pushTest();
      setMeldung(antwort.message_de);
      setDetails(antwort.details_de ?? []);
      await ladeGeraete();
    } catch (e) {
      setMeldung(hinweis(e));
    } finally {
      setLaeuft(false);
    }
  };

  const knopf = "rounded-[3px] border border-line-2 px-4 py-2 text-[14px] transition-colors hover:border-amber disabled:opacity-50";

  return (
    <div className="flex max-w-[760px] flex-col gap-4 rounded-[3px] border border-line-1 bg-surface-2 p-5">
      <div className="flex flex-col gap-1">
        <span className="kicker" style={{ fontSize: 11 }}>Mitteilungen</span>
        <span className="text-[15px] leading-[1.6] text-text-2">
          Wenn eine Quelle schweigt, meldet sich Duck Curve Home auf den angemeldeten Geräten, und
          morgens kommt das Morning Briefing. Jedes Gerät meldet sich einzeln an, hier auf dieser Seite.
        </span>
      </div>

      {lage === "ios-browser" ? (
        <div className="flex flex-col gap-2 text-[14px] leading-[1.6] text-text-2">
          <span>Auf dem iPhone und iPad gehen Mitteilungen nur in der App vom Home-Bildschirm, nicht im Browser:</span>
          <ol className="m-0 flex flex-col gap-1 pl-5">
            <li>Unten auf Teilen tippen, dann „Zum Home-Bildschirm".</li>
            <li>Duck Curve Home vom Home-Bildschirm öffnen.</li>
            <li>Dort wieder hierher: Technik, Mitteilungen, „Auf diesem Gerät einschalten".</li>
          </ol>
        </div>
      ) : null}

      {lage === "geht-nicht" ? (
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Dieser Browser kann keine Mitteilungen empfangen.
        </p>
      ) : null}

      {lage === "verboten" ? (
        <p className="m-0 text-[14px] leading-[1.6]" style={{ color: "var(--amber-soft)" }}>
          Mitteilungen sind für Duck Curve Home auf diesem Gerät abgelehnt. Das lässt sich nur in
          den Einstellungen des Geräts zurücknehmen (auf dem iPhone: Einstellungen, Mitteilungen,
          Duck Curve), nicht von hier aus.
        </p>
      ) : null}

      <div className="flex flex-wrap items-center gap-3">
        {lage === "aus" || lage === "prüfe" ? (
          <button type="button" className={knopf} onClick={einschalten} disabled={laeuft || lage === "prüfe"}>
            Auf diesem Gerät einschalten
          </button>
        ) : null}
        {lage === "an" ? (
          <>
            <span className="text-[14px]" style={{ color: "var(--pv)" }}>Dieses Gerät ist angemeldet.</span>
            <button type="button" className={knopf} onClick={probe} disabled={laeuft}>
              Probe senden
            </button>
            <button type="button" className={knopf} onClick={ausschalten} disabled={laeuft}>
              Ausschalten
            </button>
          </>
        ) : null}
        {lage !== "an" && geraete && geraete.length > 0 ? (
          <button type="button" className={knopf} onClick={probe} disabled={laeuft}>
            Probe an die angemeldeten Geräte
          </button>
        ) : null}
      </div>

      {meldung ? <p className="m-0 text-[14px] leading-[1.6] text-text-2">{meldung}</p> : null}
      {details.length > 0 ? (
        <ul className="m-0 flex list-none flex-col gap-1 p-0 text-[14px] leading-[1.6] text-text-2">
          {details.map((d) => <li key={d}>{d}</li>)}
        </ul>
      ) : null}

      {geraete !== null ? (
        <div className="flex flex-col gap-2">
          <span className="kicker" style={{ fontSize: 11 }}>
            {geraete.length === 0 ? "Kein Gerät angemeldet" : geraete.length === 1 ? "1 Gerät angemeldet" : `${geraete.length} Geräte angemeldet`}
          </span>
          {geraete.length === 0 ? (
            <span className="text-[14px] leading-[1.6]" style={{ color: "var(--amber-soft)" }}>
              Solange kein Gerät angemeldet ist, gehen weder Störungen noch das Morning Briefing an jemanden.
            </span>
          ) : (
            <ul className="geraete">
              {geraete.map((g, i) => <Geraet key={`${g.label}-${g.seit ?? i}`} g={g} />)}
            </ul>
          )}
        </div>
      ) : null}

      <p className="m-0 text-[13px] leading-[1.6] text-text-3">
        Eine Probe lohnt sich nach jedem Einschalten. Sie schickt das aktuelle Morning Briefing, so
        wie es unten steht. „Angenommen" heißt: Der Push-Dienst von
        Apple oder Google hat die Mitteilung entgegengenommen. Kommt trotzdem nichts, liegt es am
        Gerät selbst: Fokus oder „Nicht stören", oder die Mitteilungen der App sind in den
        Einstellungen abgeschaltet.
      </p>
    </div>
  );
}
