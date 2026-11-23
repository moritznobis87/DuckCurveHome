import { describe, expect, it } from "vitest";
import { AREAS, LEISTE, ansichtOf, areaOf, tabOf, tabsDerGruppe } from "./areas";

describe("Bereiche", () => {
  it("hat fuenf Bereiche in der Leiste und das System dahinter", () => {
    expect(LEISTE.map((a) => a.label)).toEqual(["Jetzt", "Haus", "Energie", "Geld", "Anlage"]);
    expect(AREAS.filter((a) => a.leiste === false).map((a) => a.label)).toEqual(["System"]);
  });

  it("ordnet einen Pfad seinem Bereich zu, die Startseite ist Jetzt", () => {
    expect(areaOf("/").key).toBe("jetzt");
    expect(areaOf("/strom/speicher?period=week").key).toBe("energie");
    expect(areaOf("/geld/rechnungen").key).toBe("geld");
    expect(areaOf("/irgendwas").key).toBe("jetzt");
  });

  it("richtet sich nach der laengsten Adresse, nicht nach dem ersten Stueck des Pfads", () => {
    // Die Waerme als Bericht gehoert zur Energie, ihre Anlage und ihr Fahrplan zur Anlage.
    expect(areaOf("/waerme").key).toBe("energie");
    expect(areaOf("/waerme?period=day&anchor=2026-11-10").key).toBe("energie");
    expect(areaOf("/anlage").key).toBe("anlage");
    expect(areaOf("/waerme/anlage").key).toBe("anlage");
    expect(areaOf("/waerme/wiedergabe").key).toBe("anlage");
    expect(areaOf("/waerme/nachbetrachtung").key).toBe("anlage");
    // Die Raeume ueber den Tag gehoeren zum Haus, die Prognose zur Energie, der Rest von
    // `/system` zur Verwaltung: drei Bereiche unter zwei alten Pfadanfaengen.
    expect(areaOf("/waerme/raeume").key).toBe("haus");
    expect(areaOf("/system").key).toBe("energie");
    expect(areaOf("/system/zugang").key).toBe("system");
    expect(areaOf("/system/daten").key).toBe("system");
  });

  it("findet den Reiter am laengsten passenden Pfad, nicht am ersten", () => {
    const energie = areaOf("/strom/pv");
    expect(tabOf(energie, "/strom/pv")?.label).toBe("Photovoltaik");
    expect(tabOf(energie, "/strom")?.label).toBe("Strom");
    expect(tabOf(energie, "/strom/")?.label).toBe("Strom");
    expect(tabOf(energie, "/waerme")?.label).toBe("Wärme");
  });

  it("kennt im Haus die Raeume und ihren Verlauf ueber den Tag", () => {
    expect(areaOf("/haus").key).toBe("haus");
    expect(areaOf("/haus").tabs.map((t) => t.label)).toEqual(["Räume", "Über den Tag"]);
  });

  it("zeigt einem Gast die Anlage ohne Regelkreis und Annahmen, und das System gar nicht", () => {
    expect(AREAS.filter((a) => a.ownerOnly).map((a) => a.key)).toEqual(["system"]);
    const anlage = AREAS.find((a) => a.key === "anlage")!;
    expect(anlage.tabs.filter((t) => !t.ownerOnly).map((t) => t.label)).toEqual(["Anlage", "Wärmepumpe", "Fahrplan", "Wirkung", "Regler"]);
    const system = AREAS.find((a) => a.key === "system")!;
    expect(system.tabs.every((t) => t.ownerOnly)).toBe(true);
    // Was unter `/system` liegt, sieht nur der Hausherr, gleich in welchem Bereich es steht.
    expect(AREAS.flatMap((a) => a.tabs).filter((t) => t.href.startsWith("/system")).every((t) => t.ownerOnly)).toBe(true);
  });

  it("ordnet jeden Reiter der Anlage genau einer ihrer Gruppen zu", () => {
    const anlage = AREAS.find((a) => a.key === "anlage")!;
    const namen = (anlage.gruppen ?? []).map((g) => g.name);
    expect(namen).toEqual(["Maschine", "Regelung", "Abstimmung"]);
    for (const t of anlage.tabs) expect(namen).toContain(t.gruppe);
    expect(tabsDerGruppe(anlage, "Maschine").map((t) => t.label)).toEqual(["Anlage", "Wärmepumpe"]);
    expect(tabsDerGruppe(anlage, "Regelung").map((t) => t.label)).toEqual(["Fahrplan", "Wirkung", "Regelkreis"]);
    expect(tabsDerGruppe(anlage, "Abstimmung").map((t) => t.label)).toEqual(["Annahmen", "Regler"]);
    // Die Karte auf der Uebersicht braucht je Seite einen Satz.
    for (const t of anlage.tabs) expect(t.beschreibung?.endsWith(".")).toBe(true);
    // Gruppen gibt es nur dort, wo sie etwas ordnen.
    for (const a of AREAS.filter((x) => x.key !== "anlage")) {
      expect(a.gruppen).toBeUndefined();
      for (const t of a.tabs) expect(t.gruppe).toBeUndefined();
    }
  });

  it("verweist nirgends auf eine alte Adresse und nennt keine Adresse zweimal", () => {
    const alt = ["/pv", "/batterie", "/wallbox", "/jahr", "/waermebilanz", "/raeume", "/prognose", "/daten", "/settings"];
    const alle = AREAS.flatMap((a) => a.tabs.map((t) => t.href));
    for (const href of alle) expect(alt).not.toContain(href);
    expect(new Set(alle).size).toBe(alle.length);
  });

  it("zaehlt die Ansichten eines Reiters zu ihm", () => {
    const anlage = areaOf("/waerme/anlage");
    // Die Wiedergabe ist die Anlage ueber einen Tag, die Nachbetrachtung der Fahrplan im Rueckblick.
    expect(tabOf(anlage, "/waerme/wiedergabe")?.label).toBe("Anlage");
    expect(tabOf(anlage, "/waerme/anlage")?.label).toBe("Anlage");
    expect(tabOf(anlage, "/waerme/nachbetrachtung")?.label).toBe("Fahrplan");
    expect(tabOf(areaOf("/waerme/raeume"), "/waerme/raeume")?.label).toBe("Über den Tag");
    expect(ansichtOf(tabOf(anlage, "/waerme/wiedergabe"), "/waerme/wiedergabe")?.label).toBe("Ein Tag");
    expect(ansichtOf(tabOf(anlage, "/waerme/fahrplan"), "/waerme/fahrplan")?.label).toBe("Voraus");
    expect(ansichtOf(tabOf(anlage, "/waerme/wirkung"), "/waerme/wirkung")).toBeUndefined();
    // Der Regler liegt unter dem Pfad der Waermepumpe und ist trotzdem ein eigener Reiter: es
    // gilt die laengste passende Adresse.
    expect(tabOf(anlage, "/waerme/waermepumpe/regler")?.label).toBe("Regler");
    expect(tabOf(anlage, "/waerme/waermepumpe/betrieb")?.label).toBe("Wärmepumpe");
    // Auf der Uebersicht ist kein Reiter aktiv.
    expect(tabOf(anlage, "/anlage")).toBeUndefined();
  });

  it("gibt jeder ersten Ansicht die Adresse ihres Reiters, und dem Bereich die seines ersten Reiters", () => {
    for (const a of AREAS) {
      // Ein Bereich mit Gruppen hat eine Uebersicht unter eigener Adresse.
      if (a.tabs[0] && !a.gruppen) expect(a.tabs[0].href).toBe(a.href);
      if (a.gruppen) expect(a.tabs.map((t) => t.href)).not.toContain(a.href);
      for (const t of a.tabs) if (t.unter) expect(t.unter[0]?.href).toBe(t.href);
    }
  });
});
