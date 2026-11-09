import { Suspense } from "react";
import { Nachbetrachtung } from "@/components/waerme/Nachbetrachtung";
import { AreaShell } from "@/components/layout/AreaShell";

export const dynamic = "force-dynamic";
export const metadata = { title: "Nachbetrachtung · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Versprochen, gehalten, wirklich · ein Tag in Euro">
      {/* Die Seite liest den Tag aus der Adresse; das verlangt eine Suspense-Grenze. */}
      <Suspense fallback={null}>
        <Nachbetrachtung />
      </Suspense>
    </AreaShell>
  );
}
