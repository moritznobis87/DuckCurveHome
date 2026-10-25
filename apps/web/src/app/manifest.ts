import type { MetadataRoute } from "next";

/** Web-App-Manifest: Vom Home-Bildschirm des iPads startet das Dashboard damit als eigene App im
 *  Vollbild, mit Namen und Farben der Marke. Kein festes Format: Wandanzeige im Querformat, Telefone
 *  unter 720 px im Hochformat. Die Middleware lässt die Datei ohne Cookie durch, weil Browser das
 *  Manifest ohne Anmeldedaten abrufen. */
export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/",
    name: "Duck Curve Home",
    short_name: "Duck Curve",
    description: "Energieflüsse, Pufferspeicher, Strompreis und Wärmepumpen-Plan auf einen Blick.",
    lang: "de",
    start_url: "/",
    scope: "/",
    display: "standalone",
    orientation: "any",
    background_color: "#082431",
    theme_color: "#082431",
    icons: [
      { src: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" },
      { src: "/favicon.svg", sizes: "any", type: "image/svg+xml" },
    ],
  };
}
