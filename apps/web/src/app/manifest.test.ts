// @vitest-environment node
import { NextRequest } from "next/server";
import { middleware } from "@/middleware";
import manifest from "./manifest";

describe("Web-App-Manifest", () => {
  it("startet als eigenständige App im Vollbild", () => {
    const m = manifest();
    expect(m.display).toBe("standalone");
    expect(m.start_url).toBe("/");
    expect(m.icons?.length).toBeGreaterThan(0);
  });

  describe("Zugangsschutz", () => {
    const vorher = process.env.DCH_ANMELDUNG;
    beforeEach(() => { delete process.env.DCH_ANMELDUNG; });  // Vorgabe ist „an"
    afterEach(() => { if (vorher === undefined) delete process.env.DCH_ANMELDUNG; else process.env.DCH_ANMELDUNG = vorher; });

    const ohneCookie = (pfad: string) => middleware(new NextRequest(`https://home.example${pfad}`));

    it.each(["/manifest.webmanifest", ...manifest().icons!.map((i) => i.src)])("%s ist ohne Cookie erreichbar", (pfad) => {
      expect(ohneCookie(pfad).headers.get("location")).toBeNull();
    });

    it("das Dashboard fuehrt ohne Cookie zur Anmeldung", () => {
      expect(ohneCookie("/").headers.get("location")).toContain("/anmeldung");
    });

    // Ohne das waere die Anmeldung eine Schleife: die Seite, die anmeldet, leitete auf sich selbst.
    it.each(["/anmeldung", "/anmeldung/einrichten"])("%s ist ohne Cookie erreichbar", (pfad) => {
      expect(ohneCookie(pfad).headers.get("location")).toBeNull();
    });

    it("mit Personencookie geht es durch", () => {
      const req = new NextRequest("https://home.example/");
      req.cookies.set("dch_person", "egal");
      expect(middleware(req).headers.get("location")).toBeNull();
    });

    // Das Geraetecookie gibt es seit dem 23.11.2026 nicht mehr - mit ihm ist der stehende
    // URL-Token verschwunden, der Vollzugriff vergab. Ein alter Keks oeffnet nichts mehr.
    it("das alte Geraetecookie oeffnet nichts mehr", () => {
      const req = new NextRequest("https://home.example/");
      req.cookies.set("dch_session", "ein alter Keks");
      expect(middleware(req).headers.get("location")).toContain("/anmeldung");
    });

    // Die Vorgabe ist „an": eine Instanz, die die Variable vergisst, soll zu sein, nicht offen.
    it("ohne jede Variable wird eine Anmeldung verlangt", () => {
      expect(ohneCookie("/").headers.get("location")).toContain("/anmeldung");
    });

    it("DCH_ANMELDUNG=aus laesst alles durch (Demo)", () => {
      process.env.DCH_ANMELDUNG = "aus";
      expect(ohneCookie("/").headers.get("location")).toBeNull();
    });
  });
});
