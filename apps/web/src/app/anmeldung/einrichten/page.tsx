import { dienstAnfrage } from "@/lib/dienst";
import { zustand } from "@/lib/zugang";

import { Einrichten } from "../passkey";

export const dynamic = "force-dynamic";
export const metadata = { title: "Zugang einrichten · Duck Curve Home" };

interface EinladungAntwort {
  email: string;
  anzeigename: string;
  rolle: string;
  passkeys: number;
  passwort?: boolean;
}

const ROLLEN: Record<string, string> = {
  hausherr: "Vollzugriff",
  bewohner: "Bewohner",
  gast: "Gast, nur Ansicht",
  service: "Beratungszugang",
};

/**
 * Der Weg hinter dem Einladungslink: einen Passkey anlegen oder ein Passwort vergeben und damit
 * angemeldet sein.
 *
 * Der Link wird hier nur **geprüft**, nicht eingelöst - das tut erst der fertige Passkey oder
 * das vergebene Passwort. Wer
 * die Seite öffnet und abbricht, hat seinen Link also noch.
 *
 * **Warum diese Seite immer dieselbe Komponente rendert.** Die Server Action, die den Passkey
 * anlegt, setzt ein Cookie - und daraufhin rendert Next die Serverkomponente neu. Dann ist der
 * Link eingelöst, diese Prüfung schlägt fehl, und wenn die Seite dabei den Zweig wechselte,
 * nähme React der Komponente ihren Zustand: **die zehn Wiederherstellungscodes wären weg, bevor
 * sie jemand lesen konnte.** Sie gehen nur einmal hinaus. Also bleibt der Zweig stehen, und
 * `Einrichten` entscheidet selbst, was es zeigt (gefunden in der Rauchprobe am 23.11.2026).
 */
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ token?: string }>;
}) {
  const { token = "" } = await searchParams;
  let einladung: EinladungAntwort | null = null;
  let fehler = "";
  try {
    einladung = await dienstAnfrage<EinladungAntwort>(
      `/auth/einladung?token=${encodeURIComponent(token)}`,
    );
  } catch (e) {
    fehler = e instanceof Error ? e.message : "Dieser Link gilt nicht.";
  }
  const stand = await zustand();
  const hinweis = einladung
    ? `${ROLLEN[einladung.rolle] ?? einladung.rolle}${
        einladung.passkeys > 0
          ? ` · ${einladung.passkeys} Passkey${einladung.passkeys === 1 ? "" : "s"} vorhanden`
          : ""
      }${einladung.passwort ? " · Passwort vorhanden" : ""}`
    : "";
  return (
    <main className="dashboard-bg flex min-h-[100dvh] flex-col items-center justify-center p-8 text-text-1">
      <div className="flex w-full max-w-[460px] flex-col gap-6">
        <div>
          <div className="kicker">Duck Curve Home</div>
          <h1 className="m-0 mt-1 text-[26px] font-semibold tracking-[-.02em]">Zugang einrichten</h1>
        </div>
        <Einrichten
          token={token}
          email={einladung?.email ?? ""}
          hinweis={hinweis}
          mindestlaenge={stand.passwort_mindestlaenge}
          fehler={fehler}
        />
      </div>
    </main>
  );
}
