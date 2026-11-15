"use client";

import { useRef, useState } from "react";
import type { ReglerEinstellung } from "@/lib/api/models";
import { anteil, gelesen, raster, wertBei, zahlText } from "./regler";

/**
 * Ein Kanalzug wie am Mischpult: oben die Anzeige, darunter die Bahn mit dem Schieber, unten
 * der Name.
 *
 * Der Schieber zeigt den Entwurf; ein schmaler Strich an der Bahn zeigt, was am Regler steht.
 * Bewegt wird er durch Ziehen, mit den Pfeiltasten oder mit den beiden Knöpfen darunter, die
 * genau einen Schritt gehen (am Handy trifft man so den Wert, den man meint). Ein Zug, dessen
 * Einstellung sich nicht stellen lässt, ist blass; warum, steht darunter.
 */
export function Fader({ w, wert, sperre, onChange, fuss }: { w: ReglerEinstellung; wert: number | null; sperre: string | null; onChange: (wert: number) => void; fuss?: React.ReactNode }) {
  const bahn = useRef<HTMLDivElement>(null);
  const [zieht, setZieht] = useState(false);
  // Wo der Finger aufgesetzt hat. Mit dem Finger gilt ein Zug erst nach ein paar Bildpunkten
  // nach oben oder unten: wer das Pult zur Seite schiebt und dabei auf einer Bahn landet, soll
  // damit keinen Wert verstellen.
  const start = useRef<{ y: number; maus: boolean; los: boolean } | null>(null);
  const frei = sperre === null && wert != null;
  const ist = gelesen(w) ? (w.wert.value ?? null) : null;
  const geaendert = wert != null && ist != null && Math.abs(wert - ist) > 1e-6;
  const hoehe = wert != null ? anteil(w, wert) * 100 : 0;

  const vomZeiger = (clientY: number) => {
    const r = bahn.current?.getBoundingClientRect();
    if (!r) return;
    onChange(wertBei(w, 1 - (clientY - r.top) / r.height));
  };
  const schritt = (richtung: number) => {
    if (frei && wert != null) onChange(raster(w, wert + richtung * (w.schritt ?? 1)));
  };

  return (
    <div className="rg-kanal" data-frei={frei} data-geaendert={geaendert}>
      <div className="rg-anzeige mono" aria-hidden="true">{wert != null ? zahlText(w, wert) : "?"}</div>
      <div
        ref={bahn}
        className="rg-bahn"
        role="slider"
        tabIndex={frei ? 0 : -1}
        aria-label={`${w.gruppe_de}: ${w.name_de}`}
        aria-valuemin={w.von ?? undefined}
        aria-valuemax={w.bis ?? undefined}
        aria-valuenow={wert ?? undefined}
        aria-valuetext={wert != null ? zahlText(w, wert) : "nicht gelesen"}
        aria-disabled={!frei}
        aria-orientation="vertical"
        data-zieht={zieht}
        onPointerDown={(ev) => {
          if (!frei) return;
          ev.currentTarget.setPointerCapture(ev.pointerId);
          const maus = ev.pointerType === "mouse";
          start.current = { y: ev.clientY, maus, los: maus };
          setZieht(true);
          if (maus) vomZeiger(ev.clientY);
        }}
        onPointerMove={(ev) => {
          const s = start.current;
          if (!zieht || !s) return;
          if (!s.los && Math.abs(ev.clientY - s.y) < 6) return;
          s.los = true;
          vomZeiger(ev.clientY);
        }}
        onPointerUp={() => setZieht(false)}
        onPointerCancel={() => setZieht(false)}
        onKeyDown={(ev) => {
          const hoch = ev.key === "ArrowUp" || ev.key === "ArrowRight";
          const runter = ev.key === "ArrowDown" || ev.key === "ArrowLeft";
          if (!hoch && !runter) return;
          ev.preventDefault();
          schritt(hoch ? 1 : -1);
        }}
      >
        <div className="rg-skala" aria-hidden="true">
          {[0, 0.25, 0.5, 0.75, 1].map((a) => (
            <span key={a} style={{ bottom: `${a * 100}%` }} />
          ))}
        </div>
        <div className="rg-rille" aria-hidden="true">
          <div className="rg-fuellung" style={{ height: `${hoehe}%` }} />
        </div>
        {ist != null ? <div className="rg-ist" style={{ bottom: `${anteil(w, ist) * 100}%` }} aria-hidden="true" /> : null}
        {wert != null ? <div className="rg-knopf" style={{ bottom: `${hoehe}%` }} aria-hidden="true" /> : null}
      </div>
      <div className="rg-tasten">
        <button type="button" onClick={() => schritt(-1)} disabled={!frei} aria-label={`${w.name_de} einen Schritt kleiner`}>−</button>
        <button type="button" onClick={() => schritt(1)} disabled={!frei} aria-label={`${w.name_de} einen Schritt größer`}>+</button>
      </div>
      <div className="rg-name">{w.name_de}</div>
      <div className="rg-kanal-fuss">{fuss}</div>
    </div>
  );
}
