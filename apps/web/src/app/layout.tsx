import type { Metadata, Viewport } from "next";
import "@/styles/globals.css";

export const metadata: Metadata = {
  title: "Duck Curve Home",
  description: "Home Energy Management – Energieflüsse, Pufferspeicher, Strompreis und Wärmepumpen-Plan auf einen Blick.",
  applicationName: "Duck Curve Home",
  appleWebApp: { capable: true, statusBarStyle: "black-translucent", title: "Duck Curve Home" },
  // Dieselben Markenicons wie duckcurve.de: ein Tab, ein Vogel.
  icons: {
    icon: [
      { url: "/favicon.ico" },
      { url: "/favicon.svg", type: "image/svg+xml" },
    ],
    shortcut: "/favicon.ico",
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
  },
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#082431",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de">
      <body>{children}</body>
    </html>
  );
}
