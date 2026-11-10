import { describe, expect, it } from "vitest";
import { AREAS, ansichtOf, areaOf, tabOf } from "./areas";

describe("Bereiche", () => {
  it("hat vier Bereiche fuer den Alltag und einen fuer die Technik", () => {
    expect(AREAS.map((a) => a.label)).toEqual(["Jetzt", "Haus", "Energie", "Geld", "Technik"]);
  });

  it("ordnet einen Pfad seinem Bereich zu, die Startseite ist Jetzt", () => {
    expect(areaOf("/").key).toBe("jetzt");
    expect(areaOf("/strom/speicher?period=week").key).toBe("energie");
    expect(areaOf("/geld/rechnungen").key).toBe("geld");
    expect(areaOf("/irgendwas").key).toBe("jetzt");
  });

  it("richtet sich nach der laengsten Adresse, nicht nach dem ersten Stueck des Pfads", () => {
    // Die Waerme als Bericht gehoert zur Energie, ihre Anlage und ihr Fahrplan zur Technik.
    expect(areaOf("/waerme").key).toBe("energie");
    expect(areaOf("/waerme?period=day&anchor=2026-11-10").key).toBe("energie");
    expect(areaOf("/waerme/anlage").key).toBe("technik");
    expect(areaOf("/waerme/wiedergabe").key).toBe("technik");
    expect(areaOf("/waerme/nachbetrachtung").key).toBe("technik");
    expect(areaOf("/waerme/raeume").key).toBe("technik");
    expect(areaOf("/system").key).toBe("technik");
    expect(areaOf("/system/zugang").key).toBe("technik");
  });

  it("findet den Reiter am laengsten passenden Pfad, nicht am ersten", () => {
    const energie = areaOf("/strom/pv");
    expect(tabOf(energie, "/strom/pv")?.label).toBe("Photovoltaik");
    expect(tabOf(energie, "/strom")?.label).toBe("Strom");
    expect(tabOf(energie, "/strom/")?.label).toBe("Strom");
    expect(tabOf(energie, "/waerme")?.label).toBe("Wärme");
  });

  it("kennt das Haus als eigenen Bereich ohne Reiter: Liste und Modell sind ein Schalter in der Seite", () => {
    expect(areaOf("/haus").key).toBe("haus");
    expect(areaOf("/haus").tabs).toEqual([]);
  });

  it("hat keinen Bereich nur fuer den Hausherrn, aber Reiter", () => {
    expect(AREAS.filter((a) => a.ownerOnly)).toEqual([]);
    const technik = AREAS.find((a) => a.key === "technik")!;
    expect(technik.tabs.filter((t) => !t.ownerOnly).map((t) => t.label)).toEqual(["Anlage", "Fahrplan", "Wirkung", "Heizkreise"]);
    expect(technik.tabs.filter((t) => t.href.startsWith("/system")).every((t) => t.ownerOnly)).toBe(true);
  });

  it("verweist nirgends auf eine alte Adresse und nennt keine Adresse zweimal", () => {
    const alt = ["/pv", "/batterie", "/wallbox", "/jahr", "/waermebilanz", "/raeume", "/prognose", "/daten", "/settings"];
    const alle = AREAS.flatMap((a) => a.tabs.map((t) => t.href));
    for (const href of alle) expect(alt).not.toContain(href);
    expect(new Set(alle).size).toBe(alle.length);
  });

  it("zaehlt die Ansichten eines Reiters zu ihm", () => {
    const technik = areaOf("/waerme/anlage");
    // Die Wiedergabe ist die Anlage ueber einen Tag, die Nachbetrachtung der Fahrplan im Rueckblick.
    expect(tabOf(technik, "/waerme/wiedergabe")?.label).toBe("Anlage");
    expect(tabOf(technik, "/waerme/anlage")?.label).toBe("Anlage");
    expect(tabOf(technik, "/waerme/nachbetrachtung")?.label).toBe("Fahrplan");
    expect(tabOf(technik, "/waerme/raeume")?.label).toBe("Heizkreise");
    expect(ansichtOf(tabOf(technik, "/waerme/wiedergabe"), "/waerme/wiedergabe")?.label).toBe("Ein Tag");
    expect(ansichtOf(tabOf(technik, "/waerme/fahrplan"), "/waerme/fahrplan")?.label).toBe("Voraus");
    expect(ansichtOf(tabOf(technik, "/waerme/wirkung"), "/waerme/wirkung")).toBeUndefined();
  });

  it("gibt jeder ersten Ansicht die Adresse ihres Reiters, und dem Bereich die seines ersten Reiters", () => {
    for (const a of AREAS) {
      if (a.tabs[0]) expect(a.tabs[0].href).toBe(a.href);
      for (const t of a.tabs) if (t.unter) expect(t.unter[0]?.href).toBe(t.href);
    }
  });
});
