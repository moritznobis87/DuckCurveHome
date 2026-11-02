"use client";

import { useState } from "react";
import { api } from "@/lib/api/client";
import type { Period } from "@/lib/api/models";
import { Card, CardHead } from "@/components/ui/Card";

/**
 * Der Prüfbericht des Speichers, auf Abruf.
 *
 * **Warum er hier steht und nicht als Kachel.** Die Kacheln dieser Seite rechnen alle aus einer
 * einzigen Messreihe; wenn eine von ihnen unglaubwürdig aussieht, hilft keine weitere Kachel aus
 * derselben Quelle. Der Bericht holt zwei unabhängige Zeugen dazu, den Ladestand des Geräts und
 * den Hausverbrauch der Hub-Wandler, und stellt sie nebeneinander.
 *
 * **Warum auf Abruf.** Er liest die Minutenreihen des Zeitraums, bei einem Jahr über eine halbe
 * Million Zeilen. Das ist nichts, was bei jedem Seitenaufruf nebenbei laufen soll.
 */
export function SpeicherCheck({ period, anchor }: { period: Period; anchor: string }) {
  const [text, setText] = useState<string | null>(null);
  const [laeuft, setLaeuft] = useState(false);
  const [fehler, setFehler] = useState<string | null>(null);

  const pruefen = async () => {
    setLaeuft(true);
    setFehler(null);
    try {
      setText(await api.speicherCheck(period, anchor));
    } catch (e) {
      setFehler(e instanceof Error ? e.message : "Die Prüfung ist nicht durchgelaufen.");
      setText(null);
    } finally {
      setLaeuft(false);
    }
  };

  return (
    <Card style={{ padding: "14px 18px", gap: 10 }}>
      <CardHead
        title="Stimmt das?"
        right={<button type="button" className="pruef-knopf" onClick={() => void pruefen()} disabled={laeuft || !anchor}>{laeuft ? "liest Minuten ..." : "Speicher prüfen"}</button>}
      />
      <p className="m-0 text-[13px] leading-[1.6] text-text-2">
        Alle Zahlen dieser Seite kommen aus einer einzigen Messreihe, der Leistung des Speichers.
        Stimmt sie nicht, stimmt keine davon, und zwar alle im selben Sinn. Die Prüfung hält sie
        gegen zwei Messungen, die nichts mit ihr zu tun haben: den Ladestand aus dem Gerät und den
        Hausverbrauch von den Wandlern des Hubs. Damit lässt sich trennen, ob der Strom im Speicher
        angekommen ist, ob er nur im Gerät geblieben ist oder ob er gar nicht geflossen ist.
      </p>
      {fehler ? <p className="m-0 text-[13px] text-alert">{fehler}</p> : null}
      {text ? <pre className="pruefbericht">{text}</pre> : null}
    </Card>
  );
}
