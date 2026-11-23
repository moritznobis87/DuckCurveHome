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
    const vorher = process.env.DCH_SESSION_SECRET;
    beforeEach(() => { process.env.DCH_SESSION_SECRET = "x".repeat(32); });
    afterEach(() => { process.env.DCH_SESSION_SECRET = vorher; });

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

    it("das Geraetecookie allein genuegt weiterhin", () => {
      const req = new NextRequest("https://home.example/");
      req.cookies.set("dch_session", "egal");
      expect(middleware(req).headers.get("location")).toBeNull();
    });

    it("das Personencookie allein genuegt", () => {
      const req = new NextRequest("https://home.example/");
      req.cookies.set("dch_person", "egal");
      expect(middleware(req).headers.get("location")).toBeNull();
    });
  });
});
