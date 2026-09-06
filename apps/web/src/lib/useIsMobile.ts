"use client";

import { useEffect, useState } from "react";

/** Breite, ab der die Hochformat-Ansicht für Telefone gilt; identisch mit der Media Query in globals.css. */
export const MOBILE_MAX_WIDTH = 720;

/** true auf Telefonen (schmaler Viewport). Bis zum ersten Client-Render false, damit Server und Client gleich rendern. */
export function useIsMobile(): boolean {
  const [mobile, setMobile] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia(`(max-width: ${MOBILE_MAX_WIDTH}px)`);
    const update = () => setMobile(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);
  return mobile;
}
