import { redirect } from "next/navigation";

/**
 * Die Bilanz ist in der Wärmeübersicht aufgegangen (10.11.2026). Die Adresse bleibt als
 * Weiterleitung, damit ein Lesezeichen und ein Verweis von außen nicht ins Leere führen; der
 * Zeitraum in der Adresse reist mit.
 */
export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(await searchParams)) {
    if (typeof v === "string") q.set(k, v);
  }
  const s = q.toString();
  redirect(s ? `/waerme?${s}` : "/waerme");
}
