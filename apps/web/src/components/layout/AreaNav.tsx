"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { AREAS, areaOf, tabOf } from "@/lib/areas";
import { Icon } from "@/components/ui/Icon";
import { useRole } from "@/lib/live/useRole";

/**
 * Die Bereichsleiste: fuenf Zeichen, kein Text.
 *
 * Entenkurve, Blitz, Flamme, Euro, Zahnrad. Der Name steht im `title` und fuer die Vorlesehilfe
 * im `aria-label`; auf dem Bildschirm genuegt das Zeichen, weil es nur vier sind und sie sich
 * nicht aehneln. Das Zahnrad sehen nur Hausherren: Gaesten einen Weg zu zeigen, der sie
 * umleitet, waere unhoeflich.
 */
export function AreaIcons({ size = 20 }: { size?: number }) {
  const pathname = usePathname();
  const role = useRole();
  const active = areaOf(pathname ?? "/");
  return (
    <nav className="flex items-center gap-1" aria-label="Bereiche">
      {AREAS.filter((a) => !a.ownerOnly || role === "owner").map((a) => {
        const on = a.key === active.key;
        return (
          <Link
            key={a.key}
            href={a.href}
            aria-label={a.label}
            aria-current={on ? "page" : undefined}
            title={a.label}
            className="area-icon flex h-10 w-10 items-center justify-center rounded-[6px] transition-colors"
            style={{ background: on ? "var(--amber)" : "transparent", color: on ? "var(--petrol)" : "var(--text-2)" }}
          >
            <Icon name={a.icon} size={size} />
          </Link>
        );
      })}
    </nav>
  );
}

/** Marke links: Kurve und Name. Fuehrt immer nach Jetzt. */
export function Brand() {
  return (
    <Link href="/" className="flex items-center gap-2.5" aria-label="Duck Curve Home, zur Startseite">
      <Icon name="duck" size={30} color="var(--amber)" strokeWidth={2.4} />
      <span className="whitespace-nowrap text-[16px] font-semibold tracking-[-.02em] text-text-1">Duck Curve</span>
    </Link>
  );
}

/**
 * Die Reiter eines Bereichs, mit dem Zeitraum in der Adresse.
 *
 * Der Zeitraum gehoert zum Bereich, nicht zur Seite: wer in Strom die Woche ansieht und von der
 * Photovoltaik zum Speicher wechselt, sieht dort dieselbe Woche. Reiter ohne Zeitraum (Jahreskarte,
 * Annahmen) bekommen ihn nicht angehaengt, er haette dort keine Wirkung.
 */
export function AreaTabs({ period, anchor, right }: { period?: string; anchor?: string; right?: React.ReactNode }) {
  const pathname = usePathname() ?? "/";
  const role = useRole();
  const area = areaOf(pathname);
  const current = tabOf(area, pathname);
  const tabs = area.tabs.filter((t) => !t.ownerOnly || role === "owner");
  if (tabs.length === 0) return null;
  const query = period && anchor ? `?period=${period}&anchor=${anchor}` : "";
  return (
    <div className="area-tabs flex items-baseline justify-between gap-6 border-b border-line-1">
      <div className="area-tabs-row flex gap-6">
        {tabs.map((t) => {
          const on = current?.href === t.href;
          return (
            <Link
              key={t.href}
              href={t.dated ? `${t.href}${query}` : t.href}
              aria-current={on ? "page" : undefined}
              className="whitespace-nowrap pb-2.5 pt-2 text-[13px]"
              style={{ color: on ? "var(--text-1)" : "var(--text-2)", borderBottom: `2px solid ${on ? "var(--amber)" : "transparent"}`, marginBottom: -1 }}
            >
              {t.label}
            </Link>
          );
        })}
      </div>
      {right ? <div className="kicker hidden truncate pb-2.5 md:block" style={{ fontSize: 11 }}>{right}</div> : null}
    </div>
  );
}
