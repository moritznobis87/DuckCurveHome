import type { NextConfig } from "next";

// Die API wird über die BFF-Route src/app/api/dch/[...path]/route.ts angesprochen (Laufzeit-Konfiguration
// per DCH_API_URL, SSE-Durchleitung). Rewrites wären zur Build-Zeit fixiert und damit für Docker ungeeignet.

const nextConfig: NextConfig = {
  output: "standalone",
  // Zur Build-Zeit eingebrannt; /api/build liefert dieselbe Kennung zur Laufzeit. Der Vergleich beider
  // sagt dem Dashboard, ob im Browser noch eine alte Fassung läuft.
  env: { NEXT_PUBLIC_BUILD_ID: process.env.RAILWAY_GIT_COMMIT_SHA ?? "dev" },
  reactStrictMode: true,
  poweredByHeader: false,
  // Die alten Adressen, eine je Geraet, fuehren auf die neuen Bereiche. Lesezeichen und der
  // Verlauf des Wand-iPads bleiben gueltig; die Abfrage (?period=&anchor=) reist mit.
  async redirects() {
    const alt: Array<[string, string]> = [
      ["/pv", "/strom/pv"],
      ["/pv/abrechnung", "/geld/pv-abrechnung"],
      ["/haus", "/strom"],
      ["/haus/rechnungen", "/geld/rechnungen"],
      ["/batterie", "/strom/speicher"],
      ["/wallbox", "/strom/wallbox"],
      ["/jahr", "/strom/jahr"],
      ["/waermebilanz", "/waerme/bilanz"],
      ["/raeume", "/waerme/raeume"],
      ["/prognose", "/system"],
      ["/daten", "/system/daten"],
      ["/settings", "/system/zugang"],
    ];
    return alt.map(([source, destination]) => ({ source, destination, permanent: true }));
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          // Kein Suchmaschineneintrag: die Seite zeigt den Zustand eines bewohnten Hauses.
          { key: "X-Robots-Tag", value: "noindex, nofollow, noarchive, nosnippet, noimageindex" },
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          { key: "Referrer-Policy", value: "same-origin" },
        ],
      },
    ];
  },
};

export default nextConfig;
