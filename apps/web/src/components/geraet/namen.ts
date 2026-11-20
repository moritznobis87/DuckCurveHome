/** Was die Dienste des Hausgeräts für jemanden sind, der nicht weiß, was ein Container ist.
 *  Dieselben Wörter stehen in der iOS-App (`Hausgeraet.dienstnamen`). */
export const DIENSTNAMEN: Record<string, string> = {
  api: "Rechenkern (API)",
  web: "Oberfläche",
  postgres: "Datenbank",
  caddy: "Webserver (HTTPS)",
  cloudflared: "Fernzugang",
};
