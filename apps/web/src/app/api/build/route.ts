export const dynamic = "force-dynamic";

/** Kennung des laufenden Web-Builds. Das Dashboard vergleicht sie mit der Kennung, die in seinem
 *  eigenen Bündel steckt: weichen sie ab, läuft im Browser eine alte Fassung und er lädt neu.
 *  Ohne das bliebe auf einem Tablet, das seit Stunden offen ist, für immer der alte Stand stehen. */
export function GET(): Response {
  const id = process.env.RAILWAY_GIT_COMMIT_SHA ?? process.env.NEXT_PUBLIC_BUILD_ID ?? "dev";
  return Response.json({ id }, { headers: { "cache-control": "no-store" } });
}
