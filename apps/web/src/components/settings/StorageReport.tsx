"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import type { StorageReport as Report } from "@/lib/api/models";

/**
 * Womit die Datenbank ihren Platz füllt.
 *
 * **Warum das hier steht.** Eine verwaltete Datenbank wird nach Arbeitsspeicher abgerechnet, und
 * den belegt sie im Wesentlichen mit dem, was sie an Seiten im Cache hält - also mit ihrer Größe.
 * Welche Tabelle das ist, lässt sich nicht erraten. Bei schmalen Zeilen sind die Indizes
 * regelmäßig größer als die Daten, und der größte Posten ist meistens der, den man für einen
 * Zwischenspeicher hielt.
 *
 * `measurements_raw` ist genau so ein Zwischenspeicher: Rohwerte werden alle fünf Minuten zu
 * Minutenzeilen verdichtet, danach braucht sie niemand mehr. Wie lange sie trotzdem liegen
 * bleiben, steht in `DCH_RAW_RETENTION_DAYS` und ist der einzige Regler, der von außen zu stellen
 * ist.
 */
function mb(bytes: number): string {
  if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toLocaleString("de-DE", { maximumFractionDigits: 2 })} GB`;
  return `${(bytes / 1024 ** 2).toLocaleString("de-DE", { maximumFractionDigits: 1 })} MB`;
}

function rows(n: number): string {
  return n >= 1000 ? `${Math.round(n / 1000).toLocaleString("de-DE")} Tsd.` : String(Math.round(n));
}

export function StorageReport() {
  const [data, setData] = useState<Report | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .storage()
      .then(setData)
      .catch(() => setError("Die Größen konnten nicht abgefragt werden."));
  }, []);

  if (error) return <p className="m-0 text-[14px] text-text-3">{error}</p>;
  if (!data) return <p className="m-0 text-[14px] text-text-3">lädt …</p>;
  if (data.tables.length === 0) return <p className="m-0 text-[14px] text-text-3">{data.note_de}</p>;

  const big = data.tables.filter((t) => t.total_bytes > 0).slice(0, 8);
  return (
    <div className="flex flex-col gap-3">
      <div className="overflow-x-auto">
        <table className="mono w-full border-collapse text-[13px]">
          <thead>
            <tr className="text-text-3">
              <th className="border-b border-line-1 py-2 pr-4 text-left font-normal">Tabelle</th>
              <th className="border-b border-line-1 py-2 pr-4 text-right font-normal">Zeilen</th>
              <th className="border-b border-line-1 py-2 pr-4 text-right font-normal">Daten</th>
              <th className="border-b border-line-1 py-2 pr-4 text-right font-normal">Indizes</th>
              <th className="border-b border-line-1 py-2 text-right font-normal">gesamt</th>
            </tr>
          </thead>
          <tbody>
            {big.map((t) => (
              <tr key={t.name}>
                <td className="border-b border-line-1 py-1.5 pr-4 text-text-1">{t.name}</td>
                <td className="border-b border-line-1 py-1.5 pr-4 text-right text-text-2">{rows(t.rows_estimate)}</td>
                <td className="border-b border-line-1 py-1.5 pr-4 text-right text-text-2">{mb(t.table_bytes)}</td>
                {/* Indizes eigens: bei schmalen Zeilen sind sie oft der größere Posten, und das
                    sieht man nur, wenn es getrennt dasteht. */}
                <td className="border-b border-line-1 py-1.5 pr-4 text-right text-text-2">{mb(t.index_bytes)}</td>
                <td className="border-b border-line-1 py-1.5 text-right text-amber">{mb(t.total_bytes)}</td>
              </tr>
            ))}
            <tr>
              <td className="py-2 pr-4 text-text-2">alle Tabellen</td>
              <td className="py-2 pr-4" />
              <td className="py-2 pr-4" />
              <td className="py-2 pr-4" />
              <td className="py-2 text-right text-text-1">{mb(data.total_bytes)}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p className="m-0 text-[14px] leading-[1.6] text-text-3">{data.note_de}</p>
    </div>
  );
}
