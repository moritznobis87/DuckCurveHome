import type { Metadata, Viewport } from "next";
import "@/styles/globals.css";

export const metadata: Metadata = {
  title: "Duck Curve Home",
  description: "Home Energy Management – Energieflüsse, Pufferspeicher, Strompreis und Wärmepumpen-Plan auf einen Blick.",
  applicationName: "Duck Curve Home",
  appleWebApp: { capable: true, statusBarStyle: "black-translucent", title: "Duck Curve Home" },
  icons: { icon: "/brand/duck-curve-mark.svg" },
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
