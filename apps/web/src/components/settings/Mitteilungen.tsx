"use client";

import { useCallback, useEffect, useState } from "react";
import { api } from "@/lib/api/client";

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
 */
type Lage = "prüfe" | "geht-nicht" | "aus" | "an" | "verboten";

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

/** Ein Wort, an dem man das Gerät in der Liste wiedererkennt. Mehr wird nicht gespeichert. */
function geraeteWort(): string {
  const ua = navigator.userAgent;
  if (/iPhone/.test(ua)) return "iPhone";
  if (/iPad/.test(ua)) return "iPad";
  if (/Android/.test(ua)) return "Android";
  if (/Macintosh/.test(ua)) return "Mac";
  if (/Windows/.test(ua)) return "Windows";
  return "Gerät";
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

const UNTERSTUETZT = (): boolean =>
  typeof window !== "undefined" &&
  "serviceWorker" in navigator &&
  "PushManager" in window &&
  "Notification" in window;

export function Mitteilungen() {
  const [lage, setLage] = useState<Lage>("prüfe");
  const [geraete, setGeraete] = useState<number | null>(null);
  const [meldung, setMeldung] = useState<string | null>(null);
  const [laeuft, setLaeuft] = useState(false);

  const zaehlen = useCallback(async () => {
    try {
      setGeraete((await api.pushKey()).devices);
    } catch {
      setGeraete(null);
    }
  }, []);

  useEffect(() => {
    if (!UNTERSTUETZT()) {
      setLage("geht-nicht");
      return;
    }
    if (Notification.permission === "denied") {
      setLage("verboten");
      void zaehlen();
      return;
    }
    void (async () => {
      const reg = await navigator.serviceWorker.getRegistration();
      const abo = reg ? await reg.pushManager.getSubscription() : null;
      setLage(abo ? "an" : "aus");
      await zaehlen();
    })();
  }, [zaehlen]);

  const einschalten = async () => {
    setLaeuft(true);
    setMeldung(null);
    try {
      // Die Erlaubnis muss aus einer Berührung kommen; deshalb steht sie hier und nicht im Effekt.
      const erlaubnis = await Notification.requestPermission();
      if (erlaubnis !== "granted") {
        setLage(erlaubnis === "denied" ? "verboten" : "aus");
        setMeldung("Ohne Erlaubnis des Browsers geht es nicht.");
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
      const daten = abo.toJSON();
      const antwort = await api.pushSubscribe({
        endpoint: abo.endpoint,
        p256dh: daten.keys?.p256dh ?? "",
        auth: daten.keys?.auth ?? "",
        label: geraeteWort(),
      });
      setLage("an");
      setGeraete(antwort.devices);
      setMeldung(antwort.message_de);
    } catch (e) {
      setMeldung(hinweis(e));
    } finally {
      setLaeuft(false);
    }
  };

  const ausschalten = async () => {
    setLaeuft(true);
    setMeldung(null);
    try {
      const reg = await navigator.serviceWorker.getRegistration();
      const abo = reg ? await reg.pushManager.getSubscription() : null;
      if (abo) {
        await api.pushUnsubscribe(abo.endpoint);
        await abo.unsubscribe();
      }
      setLage("aus");
      await zaehlen();
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
    try {
      const antwort = await api.pushTest();
      setGeraete(antwort.devices);
      setMeldung(antwort.message_de);
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
          Wenn eine Quelle schweigt, meldet sich Duck Curve Home auf den angemeldeten Geräten. Was
          gemeldet wird und ab wann, steht im Wächter; hier wird nur bestimmt, wer es erfährt.
        </span>
      </div>

      {lage === "geht-nicht" ? (
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Dieser Browser kann keine Mitteilungen empfangen. Auf dem iPhone und iPad geht es erst,
          wenn die Seite über Teilen → „Zum Home-Bildschirm" hinzugefügt und von dort geöffnet wird.
        </p>
      ) : null}

      {lage === "verboten" ? (
        <p className="m-0 text-[14px] leading-[1.6]" style={{ color: "var(--amber-soft)" }}>
          Der Browser hat Mitteilungen für diese Seite abgelehnt. Das lässt sich nur in seinen
          Einstellungen zurücknehmen, nicht von hier aus.
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
        {geraete !== null ? (
          <span className="mono text-[13px] text-text-3">
            {geraete === 1 ? "1 Gerät angemeldet" : `${geraete} Geräte angemeldet`}
          </span>
        ) : null}
      </div>

      {meldung ? <p className="m-0 text-[14px] leading-[1.6] text-text-2">{meldung}</p> : null}

      <p className="m-0 text-[13px] leading-[1.6] text-text-3">
        Eine Probe lohnt sich: Der Weg hat viele Glieder - Browser, Push-Dienst, Schlüssel,
        Service Worker -, und jedes kann still versagen. Ohne Probe merkt man das erst, wenn die
        erste echte Meldung ausbleibt, also genau dann, wenn sie gebraucht wird.
      </p>
    </div>
  );
}
