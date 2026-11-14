"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { ReglerKennzahlen } from "@/lib/api/models";

/**
 * Was die Wärmepumpe unter welcher Kennzahl ihres Reglers tat.
 *
 * Der Regler sendet eine Zahl, kein Wort. Die Wörter einer fremden Liste passten für diese
 * Anlage nicht: am 14.11.2026 stand hier „Puffer kühlen" an einer Maschine, die heizt. Diese
 * Tabelle sammelt stattdessen die Belege, aus denen sich die Bedeutung ablesen lässt: lief die
 * Maschine, mit welchem Vorlauf und Sollwert, wurde der Speicher oben oder weiter unten wärmer,
 * lief der Heizstab mit. Gedeutet wird hier nichts.
 */
const de = (n: number | null | undefined, stellen = 1): string => (n == null ? "?" : n.toFixed(stellen).replace(".", ","));
const mitVorzeichen = (n: number | null | undefined): string => (n == null ? "?" : `${n >= 0 ? "+" : "−"}${Math.abs(n).toFixed(1).replace(".", ",")}`);

export function Kennzahlen({ aktuell }: { aktuell: number | null | undefined }) {
  const [d, setD] = useState<ReglerKennzahlen | null>(null);

  useEffect(() => {
    let lebt = true;
    const laden = () =>
      api
        .reglerkennzahlen(7)
        .then((x) => {
          if (lebt) setD(x);
        })
        .catch(() => undefined);
    void laden();
    // Der Dienst hält die Auszählung fünf Minuten; öfter zu fragen bringt nichts.
    const takt = setInterval(laden, 5 * 60_000);
    return () => {
      lebt = false;
      clearInterval(takt);
    };
  }, []);

  const zeilen = d?.zeilen ?? [];
  if (!zeilen.length) return null;
  return (
    <div className="card kl-karte">
      <h2 className="kl-titel">Was der Regler meldet, letzte {d?.tage} Tage</h2>
      <p className="m-0 kl-klein">
        Der Regler sendet eine Kennzahl, kein Wort. Was sie bedeutet, ist für diese Anlage noch nicht entschlüsselt; hier steht, was die Maschine unter jeder Zahl getan hat.
      </p>
      <div className="kl-rollt">
        <table className="kl-tabelle">
          <thead>
            <tr>
              <th scope="col">Kennzahl</th>
              <th scope="col">Minuten</th>
              <th scope="col">davon Lauf</th>
              <th scope="col">Vorlauf</th>
              <th scope="col">Sollwert</th>
              <th scope="col">Speicher oben</th>
              <th scope="col">Speicher Mitte unten</th>
              <th scope="col">Zähler über Maschine</th>
              <th scope="col">angefordert</th>
            </tr>
          </thead>
          <tbody>
            {zeilen.map((z) => (
              <tr key={z.code} data-aktuell={z.code === aktuell}>
                <td className="mono">
                  {z.code}
                  {z.code === aktuell ? " · jetzt" : ""}
                </td>
                <td className="mono">{z.minuten}</td>
                <td className="mono">{z.lauf_min}</td>
                <td className="mono">{z.vorlauf_c == null ? "?" : `${de(z.vorlauf_c)} °C`}</td>
                <td className="mono">{z.vorlauf_soll_c == null ? "?" : `${de(z.vorlauf_soll_c)} °C`}</td>
                <td className="mono">{z.oben_k_h == null ? "?" : `${mitVorzeichen(z.oben_k_h)} K/h`}</td>
                <td className="mono">{z.unten_k_h == null ? "?" : `${mitVorzeichen(z.unten_k_h)} K/h`}</td>
                <td className="mono">{z.zusatz_kw == null ? "?" : `${mitVorzeichen(z.zusatz_kw)} kW`}</td>
                <td className="mono">{z.angefordert_anteil == null ? "?" : `${Math.round(z.angefordert_anteil * 100)} %`}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="m-0 kl-klein">
        „Speicher oben“ und „Mitte unten“: wie schnell der Fühler im Lauf wärmer wurde, ab zwanzig Minuten Lauf. „Zähler über Maschine“: was der Zähler im Lauf mehr aufnahm, als die Maschine für sich meldet; mehrere Kilowatt sprechen für den Heizstab. „Angefordert“: Anteil der Minuten, in denen Duck Curve Home die Maschine eingeschaltet hatte.
      </p>
    </div>
  );
}
