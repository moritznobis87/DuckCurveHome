"use client";

import { usePathname } from "next/navigation";
import { Icon } from "@/components/ui/Icon";
import { isoToday } from "@/lib/day";
import { useLiveStore } from "@/lib/live/store";
import { useRole } from "@/lib/live/useRole";

/** Die Einstiegsleiste im Dashboard-Kopf: von hier aus ist jede Seite unmittelbar unter dem
 *  Dashboard mit einem Griff erreichbar.
 *
 *  Bewusst nur hier. In den Unterseiten stand sie kurzzeitig auch, wurde dort aber zur Dauerpräsenz
 *  ohne Nutzen: wer eine Detailseite offen hat, will Zeiträume vergleichen, nicht springen. Zurück
 *  führt links das „← Dashboard". Unterunterseiten (PV-Abrechnung, Rechnungsprüfung) bleiben
 *  ohnehin aus ihrer Elternseite erreichbar.
 *
 *  Die Einstellungen erscheinen nur bei Vollzugriff; Gästen einen Weg zu zeigen, der sie umleitet,
 *  wäre unhöflich. */
const ITEMS = [
  { href: "/", icon: "dashboard", label: "Dashboard" },
  { href: "/pv", icon: "sun", label: "Photovoltaik", dated: true },
  { href: "/haus", icon: "house", label: "Haus", dated: true },
  { href: "/batterie", icon: "battery", label: "Batterie", dated: true },
  { href: "/waerme", icon: "pump", label: "Wärme", dated: true },
  { href: "/wallbox", icon: "car", label: "Wallbox", dated: true },
  { href: "/prognose", icon: "chart", label: "Prognosegüte" },
  { href: "/jahr", icon: "calendar", label: "Jahreskarte" },
  { href: "/daten", icon: "table", label: "Daten prüfen", dated: true },
  { href: "/settings", icon: "gear", label: "Einstellungen", ownerOnly: true },
] as const;

export function NavButtons() {
  // usePathname statt window.location: letzteres wäre beim Server-Rendern undefiniert und
  // erzeugte beim Hydrieren eine Abweichung.
  const current = usePathname();
  const role = useRole();
  // Der im Dashboard gewählte Kalendertag reist mit: wer den 13. September ansieht und dann auf
  // „Photovoltaik" geht, will dort den 13. September sehen. Seiten ohne Zeitraum (Prognosegüte,
  // Jahreskarte, Einstellungen) bekommen den Anker nicht angehängt, er hätte dort keine Wirkung.
  const day = useLiveStore((s) => s.historyDay);
  const anchor = day && day !== isoToday() ? day : "";
  return (
    <div className="flex shrink-0 items-center gap-2">
      {ITEMS.filter((i) => i.href !== current && (!("ownerOnly" in i) || role === "owner")).map((i) => (
        <a
          key={i.href}
          href={anchor && "dated" in i ? `${i.href}?anchor=${anchor}` : i.href}
          aria-label={i.label}
          title={i.label}
          className="flex h-9 w-9 items-center justify-center rounded-[3px] border border-line-2"
        >
          <Icon name={i.icon} size={18} color="var(--text-3)" />
        </a>
      ))}
    </div>
  );
}
