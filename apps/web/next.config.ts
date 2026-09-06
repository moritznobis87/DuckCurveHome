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
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          { key: "Referrer-Policy", value: "same-origin" },
        ],
      },
    ];
  },
};

export default nextConfig;
