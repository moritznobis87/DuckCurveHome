import { AreaShell } from "@/components/layout/AreaShell";
import { Betrieb } from "@/components/waermepumpe/Betrieb";

export const dynamic = "force-dynamic";
export const metadata = { title: "Betrieb der Wärmepumpe · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Läufe · Abtauen · Heizkurve">
      <Betrieb />
    </AreaShell>
  );
}
