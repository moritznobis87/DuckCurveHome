"use client";

import Link from "next/link";
import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { AREAS, ansichtOf, areaOf, tabOf } from "@/lib/areas";
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
            className={`area-icon flex h-10 w-10 items-center justify-center rounded-[6px] transition-colors${on ? " area-icon-an" : ""}`}
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
      {/* Auf sehr schmalen Geraeten bleibt die Kurve und der Name geht: fuenf Bereichszeichen
          daneben sind wichtiger als ein Wort, das ohnehin ueberall steht. */}
      <span className="brand-name whitespace-nowrap text-[16px] font-semibold tracking-[-.02em] text-text-1">Duck Curve</span>
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
  // Am Handy ist die Reiterzeile eine rollbare Reihe. Der aktive Reiter soll darin zu sehen sein,
  // auch wenn er der fünfte ist: sonst steht man auf „Annahmen" und sieht „Übersicht".
  const reihe = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = reihe.current;
    const an = el?.querySelector<HTMLElement>('[aria-current="page"]');
    if (!el || !an || el.scrollWidth <= el.clientWidth) return;
    el.scrollLeft = Math.max(0, an.offsetLeft - (el.clientWidth - an.offsetWidth) / 2);
  }, [current?.href]);
  return (
    <div className="area-tabs flex items-baseline justify-between gap-6 border-b border-line-1">
      <div ref={reihe} className="area-tabs-row flex gap-6">
        {tabs.map((t) => {
          const on = current?.href === t.href;
          return (
            <Link
              key={t.href}
              href={t.dated ? `${t.href}${query}` : t.href}
              aria-current={on ? "page" : undefined}
              className={`area-tab whitespace-nowrap pb-2.5 pt-2 text-[13px]${on ? " area-tab-an" : ""}`}
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

/**
 * Der Umschalter zwischen den Ansichten eines Reiters: „Jetzt | Ein Tag", „Voraus | Rückblick".
 *
 * Verweise und kein Zustand: jede Ansicht hat ihre eigene Adresse, damit ein Sprung von außen -
 * aus der Jahreskarte in die Wiedergabe, aus der Übersicht in den Rückblick - genau dort landet.
 * Ohne Ansichten zeichnet er nichts.
 */
export function AreaAnsichten() {
  const pathname = usePathname() ?? "/";
  const tab = tabOf(areaOf(pathname), pathname);
  const aktiv = ansichtOf(tab, pathname);
  if (!tab?.unter || tab.unter.length < 2) return null;
  return (
    <nav className="ansichten" aria-label={`Ansichten von ${tab.label}`}>
      {tab.unter.map((u) => {
        const an = aktiv?.href === u.href;
        return (
          <Link key={u.href} href={u.href} aria-current={an ? "page" : undefined} className={`ansicht${an ? " ansicht-an" : ""}`}>
            {u.label}
          </Link>
        );
      })}
    </nav>
  );
}

/**
 * Die Bereichsleiste des Handys: unten, wo der Daumen ist, mit Zeichen und Namen.
 *
 * Bis zum 10.11.2026 standen die Bereiche am Handy als sechs Zeichen ohne Namen in einem Kasten
 * am oberen Rand, darunter Zeitwahl und Reiter: drei Zeilen Bedienung, bevor die erste Zahl kam,
 * und alle außerhalb der Reichweite einer Hand. Unten kostet die Leiste eine Zeile, die immer da
 * ist, und der Kopf der Seite wird frei für das, was die Seite sagt.
 *
 * Über 720 Punkten Breite ist sie ausgeblendet; dort bleibt die Leiste im Kopf.
 */
export function Fussleiste() {
  const pathname = usePathname();
  const role = useRole();
  const active = areaOf(pathname ?? "/");
  return (
    <nav className="fussleiste" aria-label="Bereiche">
      {AREAS.filter((a) => !a.ownerOnly || role === "owner").map((a) => {
        const on = a.key === active.key;
        return (
          <Link key={a.key} href={a.href} aria-current={on ? "page" : undefined} className={`fussleiste-punkt${on ? " fussleiste-an" : ""}`}>
            <span className="fussleiste-zeichen">
              <Icon name={a.icon} size={22} strokeWidth={on ? 2.1 : 1.75} />
            </span>
            <span className="fussleiste-wort">{a.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}

/** Der Name des Bereichs als Überschrift der Seite. Nur am Handy sichtbar; am Rechner sagt es die Leiste. */
export function Bereichstitel() {
  const pathname = usePathname();
  const area = areaOf(pathname ?? "/");
  return <span className="bereichstitel">{area.label}</span>;
}
