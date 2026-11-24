import { redirect } from "next/navigation";

import { ausweis, zustand } from "@/lib/zugang";

import { PasskeyAnmeldung, PasswortAnmeldung, Wiederherstellung } from "./passkey";

export const dynamic = "force-dynamic";
export const metadata = { title: "Anmelden · Duck Curve Home" };

/**
 * Die Anmeldeseite: zwei Wege herein, der Passkey und das Passwort.
 *
 * Der Hausherr hat am 24.11.2026 entschieden, dass es neben dem Passkey ein Passwort gibt, für
 * Leute, die keinen Passkey verwenden möchten. Der Passkey steht oben, weil er der empfohlene
 * Weg ist; das Passwort steht gleichwertig darunter und nicht hinter einem Verweis.
 *
 * **Weitergeleitet wird nur eine angemeldete Person.** Was sonst hereinkommt (ein Dienst mit dem
 * API-Token) bleibt hier stehen und bekommt die Anmeldung angeboten.
 *
 * Solange es **noch keine Person** gibt, sagt die Seite, wie der erste Hausherr hereinkommt:
 * über `DCH_ERSTE_PERSON` in der Umgebung des Dienstes. Einen offenen Weg „ersten Hausherrn
 * hier anlegen" gibt es mit Absicht nicht - wer die Adresse zuerst fände, hätte das Haus
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
              Die erste Person legt an, wer den Dienst betreibt: Auf dem Dienst wird
              <code className="mono text-[13px]"> DCH_ERSTE_PERSON</code> auf eine E-Mail-Adresse
              gesetzt und der Dienst neu gestartet. Der Einladungslink steht danach einmal in
              seinem Protokoll. Diesen Link öffnest du auf dem Gerät, das künftig anmeldet.
            </p>
          </section>
        ) : (
          <>
            <PasskeyAnmeldung />
            <div className="flex items-center gap-3 text-[13px] text-text-3" role="separator">
              <span className="h-px flex-1 bg-line-1" />
              oder mit Passwort
              <span className="h-px flex-1 bg-line-1" />
            </div>
            <PasswortAnmeldung />
            <Wiederherstellung />
          </>
        )}

        {stand.rp_id ? (
          <p className="m-0 text-[13px] leading-[1.6] text-text-3">
            Passkeys dieses Hauses gehören zu <span className="mono">{stand.rp_id}</span>. Auch
            eine Wandanzeige meldet sich an; sie bekommt dafür eine eigene Person.
          </p>
        ) : null}
      </div>
    </main>
  );
}
