import Link from "next/link";
import { redirect } from "next/navigation";

import { ausweis, zustand } from "@/lib/zugang";

import { PasskeyAnmeldung, Wiederherstellung } from "./passkey";

export const dynamic = "force-dynamic";
export const metadata = { title: "Anmelden · Duck Curve Home" };

/**
 * Die Anmeldeseite.
 *
 * **Weitergeleitet wird nur eine angemeldete Person.** Ein gepaartes Gerät bleibt hier stehen und
 * bekommt die Anmeldung angeboten: sonst käme auf dem Wand-iPad oder einem Rechner, der einmal
 * den Pairing-Link gesehen hat, nie jemand als Person herein - die Seite leitete ihn immer weg
 * (gefunden in der Rauchprobe am 23.11.2026). Beides nebeneinander ist genau der Fall, den es
 * geben soll: das Gerät sieht zu, der Mensch stellt etwas und steht danach im Protokoll.
 *
 * Solange es **noch keine Person** gibt, sagt die Seite, wie der erste Hausherr hereinkommt:
 * über den Pairing-Link des Geräts, und von dort in die Verwaltung. Ein offener Weg „ersten
 * Hausherrn hier anlegen" gäbe es nicht - wer die Adresse zuerst findet, hätte das Haus
 * (docs/ZUGANG.md).
 */
export default async function Page() {
  const wer = await ausweis();
  if (wer?.art === "person") redirect("/");
  const stand = await zustand();
  return (
    <main className="dashboard-bg flex min-h-[100dvh] flex-col items-center justify-center p-8 text-text-1">
      <div className="flex w-full max-w-[420px] flex-col gap-6">
        <div>
          <div className="kicker">Duck Curve Home</div>
          <h1 className="m-0 mt-1 text-[26px] font-semibold tracking-[-.02em]">Anmelden</h1>
        </div>

        {stand.personen === 0 ? (
          <section className="flex flex-col gap-3 rounded-[3px] border border-line-1 bg-surface-2 p-4">
            <h2 className="m-0 text-[16px] font-semibold">Noch hat niemand einen Zugang</h2>
            <p className="m-0 text-[15px] leading-[1.6] text-text-2">
              Öffne einmal den Pairing-Link dieses Hauses
              (<code className="mono text-[13px]">/pair?token=…</code>) und lege unter
              <strong> System › Zugang und Sicherung</strong> die erste Person an. Den Link, der dabei entsteht,
              öffnest du auf dem Gerät, das künftig anmeldet.
            </p>
          </section>
        ) : (
          <>
            <PasskeyAnmeldung />
            <Wiederherstellung />
          </>
        )}

        {wer !== null ? (
          <p className="m-0 text-[13px] leading-[1.6] text-text-3">
            Dieses Gerät ist als <strong>{wer.name}</strong> gekoppelt und sieht das Haus schon.
            Eine Anmeldung als Person kommt dazu: dann steht im Protokoll, wer etwas verstellt hat,
            und nicht nur, an welchem Gerät. <Link href="/" className="text-amber">Ohne Anmeldung weiter</Link>
          </p>
        ) : null}

        <p className="m-0 text-[13px] leading-[1.6] text-text-3">
          Eine Wandanzeige meldet sich nicht an. Sie wird einmal gepaart und bleibt gepaart.
          {stand.rp_id ? (
            <>
              {" "}
              Passkeys dieses Hauses gehören zu <span className="mono">{stand.rp_id}</span>.
            </>
          ) : null}
        </p>
      </div>
    </main>
  );
}
