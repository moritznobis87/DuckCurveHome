import { Systemkarte } from "@/components/ui/Systemkarte";
import { KARTEN } from "./kontoworte";

/** Eine Karte auf „Mein Zugang“ und „Zugang und Sicherung“, mit Zeichen und Satz aus `KARTEN`. */
export function Zugangskarte({ art, children }: { art: keyof typeof KARTEN; children: React.ReactNode }) {
  const k = KARTEN[art];
  return (
    <Systemkarte zeichen={k.zeichen} titel={k.titel} satz={k.satz}>
      {children}
    </Systemkarte>
  );
}
