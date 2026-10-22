"use client";

import { useEffect, useState } from "react";

/** Breite, ab der die Telefonansicht gilt; identisch mit der Media Query in globals.css. */
export const MOBILE_MAX_WIDTH = 720;
/**
 * Höhe, ab der ebenfalls die Telefonansicht gilt.
 *
 * Das Querformat eines Telefons ist breit genug für die Wandansicht und viel zu niedrig für sie:
 * rund 850 mal 390 Punkte. Die Startseite teilt `100dvh` in feste Zeilen; bei 390 Punkten bleibt
 * für den Energiefluss fast nichts, und seine absolut gesetzten Knoten legen sich über Text und
 * Kurve. Unterhalb dieser Höhe kommt deshalb die Liste statt der Zeichnung.
 */
export const MOBILE_MAX_HEIGHT = 560;

/** true auf Telefonen (schmaler oder niedriger Viewport). Bis zum ersten Client-Render false, damit Server und Client gleich rendern. */
export function useIsMobile(): boolean {
  const [mobile, setMobile] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia(`(max-width: ${MOBILE_MAX_WIDTH}px), (max-height: ${MOBILE_MAX_HEIGHT}px)`);
    const update = () => setMobile(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);
  return mobile;
}
