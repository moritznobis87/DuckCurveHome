"use client";

import { AreaAnsichten, AreaIcons, AreaTabs, Bereichstitel, Brand, Fussleiste, Kontoknopf, Systemknopf } from "./AreaNav";
import { UpdateHinweis } from "@/components/update/UpdateHinweis";

/**
 * Die Huelle jeder Unterseite: Marke, Bereichsleiste, das Zahnrad zum System und die Person zum
 * eigenen Zugang, rechts die
 * Werkzeuge der Seite (meist die Zeitraumwahl), darunter die Reiter des Bereichs.
 *
 * Eine Huelle fuer alle, damit die Seiten sich nicht in Kleinigkeiten unterscheiden: vorher hatten
 * Jahreskarte, Prognose und Einstellungen je einen eigenen Kopf mit „← Dashboard", und jeder war
 * ein bisschen anders.
 */
export function AreaShell({ right, kicker, period, anchor, children }: { right?: React.ReactNode; kicker?: React.ReactNode; period?: string; anchor?: string; children: React.ReactNode }) {
  return (
    <main className="dashboard-bg report-main flex min-h-[100dvh] flex-col gap-4 p-5 text-text-1">
      <header className="report-header flex min-h-14 shrink-0 items-center justify-between gap-4 rounded-[6px] border border-line-2 px-4" style={{ background: "var(--surface-glass)", backdropFilter: "blur(18px)" }}>
        <div className="flex min-w-0 items-center gap-5">
          <Brand />
          <Bereichstitel />
          <AreaIcons />
          <span className="kopfknoepfe flex items-center gap-1">
            <Systemknopf />
            <Kontoknopf />
          </span>
        </div>
        {right ? <div className="report-header-right flex shrink-0 items-center gap-3">{right}</div> : null}
      </header>
      <UpdateHinweis />
      <AreaTabs period={period} anchor={anchor} right={kicker} />
      <AreaAnsichten />
      {children}
      <Fussleiste />
    </main>
  );
}
