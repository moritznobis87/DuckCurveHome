import { describe, expect, it } from "vitest";
import { AREAS, areaOf, tabOf } from "./areas";

describe("Bereiche", () => {
  it("ordnet einen Pfad seinem Bereich zu, die Startseite ist Jetzt", () => {
    expect(areaOf("/").key).toBe("jetzt");
    expect(areaOf("/strom/speicher?period=week").key).toBe("strom");
    expect(areaOf("/waerme").key).toBe("waerme");
    expect(areaOf("/irgendwas").key).toBe("jetzt");
  });

  it("findet den Reiter am laengsten passenden Pfad, nicht am ersten", () => {
    const strom = areaOf("/strom/pv");
    expect(tabOf(strom, "/strom/pv")?.label).toBe("Photovoltaik");
    expect(tabOf(strom, "/strom")?.label).toBe("Bilanz");
    expect(tabOf(strom, "/strom/")?.label).toBe("Bilanz");
  });

  it("kennt das Haus als eigenen Bereich ohne Reiter", () => {
    expect(areaOf("/haus").key).toBe("haus");
    expect(areaOf("/haus").tabs).toEqual([]);
  });

  it("hat genau einen Bereich nur fuer den Hausherrn, und der ist System", () => {
    expect(AREAS.filter((a) => a.ownerOnly).map((a) => a.key)).toEqual(["system"]);
  });

  it("verweist nirgends auf eine alte Adresse", () => {
    const alt = ["/pv", "/batterie", "/wallbox", "/jahr", "/waermebilanz", "/raeume", "/prognose", "/daten", "/settings"];
    for (const a of AREAS) for (const t of a.tabs) expect(alt).not.toContain(t.href);
  });
});
