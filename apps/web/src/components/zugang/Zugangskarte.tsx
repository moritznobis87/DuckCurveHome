import { Icon } from "@/components/ui/Icon";
import { KARTEN } from "./kontoworte";

/**
 * Eine Karte auf „Mein Zugang“ und „Zugang und Sicherung“: Zeichen in einer getönten Fläche,
 * Titel und ein kurzer Satz, darunter der Inhalt. Dieselbe Bildsprache wie die Kacheln der
 * Übersichten; in der App ist es `Kontokarte`.
 */
export function Zugangskarte({ art, children }: { art: keyof typeof KARTEN; children: React.ReactNode }) {
  const k = KARTEN[art];
  return (
    <section className="konto-karte" aria-label={k.titel}>
      <header className="konto-karte-kopf">
        <span className="konto-zeichen" aria-hidden="true">
          <Icon name={k.zeichen} size={20} />
        </span>
        <div className="min-w-0">
          <h2 className="konto-karte-titel">{k.titel}</h2>
          <p className="konto-karte-satz">{k.satz}</p>
        </div>
      </header>
      {children}
    </section>
  );
}
