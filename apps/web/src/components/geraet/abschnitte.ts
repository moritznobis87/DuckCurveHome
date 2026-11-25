import type { IconName } from "@/components/ui/Icon";

/**
 * Das Zeichen jeder Karte auf „Hausgerät“. Dieselben stehen in der App
 * (`Hausgeraet.abschnittszeichen`); je ein Test hält beide auf derselben Liste.
 */
export const ABSCHNITTSZEICHEN = {
  Dienste: "dashboard",
  Rechenkern: "bolt",
  Gerät: "house",
  "SSD-Gesundheit": "shield",
  "Platz auf der SSD": "battery",
  Verlauf: "chart",
  Sicherung: "calendar",
  "Abläufe auf dem Gerät": "clock",
  Software: "loop",
  "Neu starten": "alert",
} as const satisfies Record<string, IconName>;
