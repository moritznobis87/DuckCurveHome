import { Icon, type IconName } from "@/components/ui/Icon";

/**
 * Eine Karte der Systemseiten und von „Mein Zugang“: Zeichen in einer getönten Fläche, Titel und
 * ein kurzer Satz, darunter der Inhalt. Dieselbe Bildsprache wie die Kacheln der Übersichten.
 *
 * Der Hausherr hat am 25.11.2026 entschieden, dass die Systemseiten so aussehen und keine langen
 * Erklärtexte mehr tragen. In der App ist es `Kontokarte`.
 */
export function Systemkarte({
  zeichen,
  titel,
  satz,
  id,
  children,
}: {
  zeichen: IconName;
  titel: string;
  satz?: React.ReactNode;
  /** Ein Sprungziel, etwa `software` für den Hinweis auf ein Update. */
  id?: string;
  children?: React.ReactNode;
}) {
  return (
    <section id={id} className="konto-karte" aria-label={titel}>
      <header className="konto-karte-kopf">
        <span className="konto-zeichen" aria-hidden="true">
          <Icon name={zeichen} size={20} />
        </span>
        <div className="min-w-0">
          <h2 className="konto-karte-titel">{titel}</h2>
          {satz ? <p className="konto-karte-satz">{satz}</p> : null}
        </div>
      </header>
      {children}
    </section>
  );
}
