/**
 * Kann dieses Gerät Mitteilungen bekommen, und bekommt es welche?
 *
 * Die Antwort hängt an vier Dingen, die der Browser einzeln verrät: ob er Web Push überhaupt
 * kann, ob die Seite als App vom Home-Bildschirm läuft (auf iPhone und iPad die Bedingung), ob
 * der Mensch es erlaubt hat und ob ein Abonnement besteht. Hier steht die Entscheidung als reine
 * Funktion, damit die Seite „Mitteilungen" und der Hinweis auf der Startseite dasselbe sagen.
 *
 * Anlass: Am 12.11.2026 kam im Haus keine Mitteilung an, auch kein Morgenbrief. Die Einstellung
 * lag unter Technik, und nichts auf der Startseite sagte, dass dieses Telefon gar nicht
 * angemeldet war.
 */
export type PushLage =
  /** Der Browser kann es nicht, und es liegt nicht am Home-Bildschirm. */
  | "geht-nicht"
  /** iPhone oder iPad, Seite im Browser geöffnet: erst zum Home-Bildschirm hinzufügen. */
  | "ios-browser"
  /** Der Mensch hat abgelehnt; zurücknehmen geht nur in den Einstellungen des Geräts. */
  | "verboten"
  | "aus"
  | "an";

export type Umstaende = {
  unterstuetzt: boolean;
  ios: boolean;
  installiert: boolean;
  erlaubnis: "default" | "denied" | "granted";
  abo: boolean;
};

export function lageAus(u: Umstaende): PushLage {
  if (!u.unterstuetzt) return u.ios && !u.installiert ? "ios-browser" : "geht-nicht";
  if (u.erlaubnis === "denied") return "verboten";
  return u.abo ? "an" : "aus";
}

/** iPhone, iPad, iPod. Ein iPad gibt sich seit iPadOS 13 als Mac aus; verraten tut es der Finger. */
export function istIos(): boolean {
  if (typeof navigator === "undefined") return false;
  return /iPhone|iPad|iPod/.test(navigator.userAgent) || (/Macintosh/.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
}

/** Läuft die Seite als App vom Home-Bildschirm? */
export function istInstalliert(): boolean {
  if (typeof window === "undefined") return false;
  const apple = (navigator as Navigator & { standalone?: boolean }).standalone === true;
  return apple || window.matchMedia("(display-mode: standalone)").matches;
}

export function unterstuetzt(): boolean {
  return typeof window !== "undefined" && "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
}

/** Das Abonnement dieses Browsers, wenn es eines gibt. */
export async function abonnement(): Promise<PushSubscription | null> {
  if (!unterstuetzt()) return null;
  const reg = await navigator.serviceWorker.getRegistration();
  return reg ? await reg.pushManager.getSubscription() : null;
}

export async function pushLage(): Promise<PushLage> {
  const kann = unterstuetzt();
  return lageAus({
    unterstuetzt: kann,
    ios: istIos(),
    installiert: istInstalliert(),
    erlaubnis: kann ? Notification.permission : "default",
    abo: kann && Notification.permission !== "denied" ? (await abonnement()) !== null : false,
  });
}

/** Ein Wort, an dem man das Gerät in der Liste wiedererkennt. Mehr wird nicht gespeichert. */
export function geraeteWort(): string {
  const ua = navigator.userAgent;
  if (/iPhone/.test(ua)) return "iPhone";
  if (/iPad/.test(ua)) return "iPad";
  if (/Android/.test(ua)) return "Android";
  if (/Macintosh/.test(ua)) return istIos() ? "iPad" : "Mac";
  if (/Windows/.test(ua)) return "Windows";
  return "Gerät";
}

/** Was der Dienst von einem Abonnement wissen muss. `origin` wird der Absender der Mitteilungen. */
export function anmeldung(abo: PushSubscription): { endpoint: string; p256dh: string; auth: string; label: string; origin: string } {
  const daten = abo.toJSON();
  return {
    endpoint: abo.endpoint,
    p256dh: daten.keys?.p256dh ?? "",
    auth: daten.keys?.auth ?? "",
    label: geraeteWort(),
    origin: window.location.origin,
  };
}
