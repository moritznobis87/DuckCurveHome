import { Bereichsuebersicht } from "@/components/layout/Bereichsuebersicht";

export const dynamic = "force-dynamic";
export const metadata = { title: "Energie · Duck Curve Home" };

export default function Page() {
  return <Bereichsuebersicht bereich="energie" />;
}
