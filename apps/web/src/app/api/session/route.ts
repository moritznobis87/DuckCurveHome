import type { NextRequest } from "next/server";

import { touch } from "@/lib/presence";
import { ausweis } from "@/lib/zugang";

export const dynamic = "force-dynamic";

/**
 * Wer gerade angemeldet ist. Die Oberfläche blendet danach aus, was die Rolle ohnehin nicht darf -
 * verboten wird es am Dienst (`dch_api/auth/rechte.py`), hier geht es nur darum, keine toten
 * Knöpfe zu zeigen.
 *
 * `role` bleibt als altes Feld bestehen (`owner`/`guest`) und heißt: darf im Haus stellen. Ein
 * Bewohner darf das, ein Gast und ein Beratungszugang nicht. Die genaue Rolle steht in `rolle`.
 *
 * Nebenbei hält der regelmäßige Aufruf die Anwesenheitsliste aktuell.
 */
export async function GET(req: NextRequest): Promise<Response> {
  const wer = await ausweis();
  touch(
    wer ? { name: wer.name, rolle: wer.rolle, person: wer.art === "person" } : null,
    req.headers.get("user-agent"),
  );
  const darfStellen = wer !== null && (wer.rolle === "hausherr" || wer.rolle === "bewohner");
  return Response.json(
    {
      role: darfStellen ? "owner" : "guest",
      rolle: wer?.rolle ?? "gast",
      art: wer?.art ?? null,
      name: wer?.name ?? null,
      email: wer?.email ?? null,
    },
    { headers: { "cache-control": "no-store" } },
  );
}
