"use client";

import { usePathname } from "next/navigation";
import { Icon } from "@/components/ui/Icon";
import { useRole } from "@/lib/live/useRole";

/** Die immer gleichen kleinen Knöpfe oben rechts. Eine Stelle, damit die Unterseiten nicht
 *  auseinanderlaufen — bisher hatte jede ihre eigene, teils gar keine.
 *  Die eigene Seite lässt ihren Knopf weg: ein Verweis auf sich selbst ist keine Navigation. */
const ITEMS = [
  { href: "/", icon: "home", label: "Dashboard" },
  { href: "/jahr", icon: "calendar", label: "Jahreskarte" },
  { href: "/prognose", icon: "chart", label: "Prognose-Auswertung" },
  { href: "/settings", icon: "gear", label: "Einstellungen", ownerOnly: true },
] as const;

export function NavButtons() {
  // usePathname statt window.location: letzteres wäre beim Server-Rendern undefiniert und
  // erzeugte beim Hydrieren eine Abweichung.
  const current = usePathname();
  const role = useRole();
  return (
    <div className="flex shrink-0 items-center gap-2">
      {ITEMS.filter((i) => i.href !== current && (!("ownerOnly" in i) || role === "owner")).map((i) => (
        <a
          key={i.href}
          href={i.href}
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
