import { describe, expect, it } from "vitest";
import { AREAS, ansichtOf, areaOf, tabOf } from "./areas";

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

  it("zaehlt die Ansichten eines Reiters zu ihm", () => {
    const waerme = areaOf("/waerme");
    // Die Wiedergabe ist die Anlage ueber einen Tag, die Nachbetrachtung der Fahrplan im Rueckblick.
    expect(tabOf(waerme, "/waerme/wiedergabe")?.label).toBe("Anlage");
    expect(tabOf(waerme, "/waerme/anlage")?.label).toBe("Anlage");
    expect(tabOf(waerme, "/waerme/nachbetrachtung")?.label).toBe("Fahrplan");
    expect(tabOf(waerme, "/waerme")?.label).toBe("Übersicht");
    expect(ansichtOf(tabOf(waerme, "/waerme/wiedergabe"), "/waerme/wiedergabe")?.label).toBe("Ein Tag");
    expect(ansichtOf(tabOf(waerme, "/waerme/fahrplan"), "/waerme/fahrplan")?.label).toBe("Voraus");
    expect(ansichtOf(tabOf(waerme, "/waerme"), "/waerme")).toBeUndefined();
  });

  it("hat in der Waerme sechs Reiter, und die erste Ansicht hat die Adresse ihres Reiters", () => {
    const waerme = areaOf("/waerme");
    expect(waerme.tabs.map((t) => t.label)).toEqual(["Übersicht", "Räume", "Anlage", "Fahrplan", "Wirkung", "Annahmen"]);
    for (const t of waerme.tabs) if (t.unter) expect(t.unter[0]?.href).toBe(t.href);
  });
});
