import { AreaShell } from "@/components/layout/AreaShell";
import { DoorLog } from "@/components/settings/DoorLog";

export const dynamic = "force-dynamic";
export const metadata = { title: "Haustür · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Wer sich am Reader erkennen ließ, und was geschah">
      <section className="flex max-w-[860px] flex-col gap-3">
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Von hier führt kein Weg zur Tür: die Entscheidung fällt im Haus, an einer Erlaubnisliste in
          der Bridge, und diese Seite liest nur mit. Abgelehnte Versuche stehen mit dabei; sie sind
          die eigentliche Auskunft, wenn man wissen will, ob jemand vor der Tür stand, den das Haus
          nicht kannte.
        </p>
        <DoorLog />
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Die Namen kommen aus UniFi Access und stehen in der Datenbank im Klartext. Deshalb steht
          diese Liste unter System und nicht auf der Startseite: ein Gast sieht sie nicht, und auf
          der Küchenanzeige hat sie nichts verloren.
        </p>
      </section>
    </AreaShell>
  );
}
