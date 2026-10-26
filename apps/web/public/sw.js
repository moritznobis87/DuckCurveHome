/*
 * Duck Curve Home: der Service Worker, und zwar nur für Mitteilungen.
 *
 * **Was er absichtlich nicht tut: Seiten zwischenspeichern.** Ein zwischengespeichertes
 * Dashboard zeigt Zahlen von vorhin und sieht dabei aus wie jetzt - genau der Fehler, gegen den
 * der Wächter gebaut wurde. Hier steht deshalb kein `fetch`-Ereignis. Ohne eines geht jede
 * Anfrage am Service Worker vorbei ins Netz, so wie ohne ihn.
 *
 * **Warum es ihn trotzdem braucht.** Eine Push-Mitteilung erreicht kein Fenster, sondern den
 * Browser; nur ein Service Worker kann sie entgegennehmen. Auf dem iPhone geht das erst, wenn die
 * Seite zum Home-Bildschirm hinzugefügt und von dort geöffnet wurde.
 */

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

self.addEventListener("push", (event) => {
  let daten = {};
  try {
    daten = event.data ? event.data.json() : {};
  } catch {
    daten = { title: "Duck Curve Home", body: event.data ? event.data.text() : "" };
  }
  const titel = daten.title || "Duck Curve Home";
  event.waitUntil(
    self.registration.showNotification(titel, {
      body: daten.body || "",
      // Dieselbe Sache ersetzt sich selbst: Ein Ausfall, der seit zwei Tagen läuft, soll nicht
      // zwei Tage lang Mitteilungen stapeln.
      tag: daten.tag || "dch",
      renotify: false,
      icon: "/apple-touch-icon.png",
      badge: "/apple-touch-icon.png",
      data: { url: daten.url || "/" },
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const ziel = (event.notification.data && event.notification.data.url) || "/";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((fenster) => {
      // Ein offenes Fenster wird nach vorn geholt, statt ein zweites zu öffnen.
      for (const f of fenster) {
        if ("focus" in f) {
          f.navigate(ziel).catch(() => undefined);
          return f.focus();
        }
      }
      return self.clients.openWindow(ziel);
    }),
  );
});
