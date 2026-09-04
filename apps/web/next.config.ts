import type { NextConfig } from "next";

// Die API wird über die BFF-Route src/app/api/dch/[...path]/route.ts angesprochen (Laufzeit-Konfiguration
// per DCH_API_URL, SSE-Durchleitung). Rewrites wären zur Build-Zeit fixiert und damit für Docker ungeeignet.

const nextConfig: NextConfig = {
  output: "standalone",
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
