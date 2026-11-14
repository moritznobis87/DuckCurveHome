import { describe, expect, it } from "vitest";
import { AREAS } from "@/lib/areas";
import { ZIELE } from "./WpMenue";

describe("die Auswahl an der Wärmepumpe", () => {
  it("führt nur auf Seiten, die es in der Navigation gibt", () => {
    const bekannt = new Set(AREAS.flatMap((a) => [a.href, ...a.tabs.flatMap((t) => [t.href, ...(t.unter ?? []).map((u) => u.href)])]));
    for (const z of ZIELE) expect(bekannt.has(z.href), z.href).toBe(true);
  });

  it("nennt Technik und Kosten zuerst, je mit eigenem Zeichen", () => {
    expect(ZIELE.slice(0, 2).map((z) => [z.titel, z.zeichen])).toEqual([["Technik", "gear"], ["Kosten", "euro"]]);
    expect(new Set(ZIELE.map((z) => z.href)).size).toBe(ZIELE.length);
    // Keines der Ziele ist nur für den Hausherrn: die Auswahl sieht für jeden gleich aus.
    const nurHausherr = new Set(AREAS.flatMap((a) => a.tabs.filter((t) => t.ownerOnly).map((t) => t.href)));
    for (const z of ZIELE) expect(nurHausherr.has(z.href)).toBe(false);
  });
});
