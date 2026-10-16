import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";

// Das Diagramm selbst braucht eine Zeichenflaeche, die es in jsdom nicht gibt. Gefragt ist hier
// ohnehin der Kopf der Karte: Ueberschrift und hervorgehobener Tag.
vi.mock("./EChart", () => ({ EChart: () => null }));

import { DayChart } from "./DayChart";
import { istTagIso } from "@/lib/day";

// Mittag: so faellt der Kalendertag in jeder Zeitzone, in der ein Lauf stattfinden kann, gleich aus.
const JETZT = new Date("2026-10-17T12:00:00Z").getTime();

function kopf(dayIso: string) {
  render(<DayChart history={[]} plan={null} nowMs={JETZT} dayIso={dayIso} onDay={() => {}} />);
  const hervorgehoben = ["Gestern", "Heute", "Morgen"].filter((t) => screen.getByText(t).style.background === "var(--amber)");
  return { titel: screen.getByRole("heading", { level: 2 }).textContent ?? "", hervorgehoben };
}

describe("Kopf des Tagesdiagramms", () => {
  it("nennt den laufenden Tag „Heute“ und hebt ihn hervor", () => {
    const { titel, hervorgehoben } = kopf("2026-10-17");
    expect(titel).toContain("Heute");
    expect(hervorgehoben).toEqual(["Heute"]);
  });

  it("faellt auf den laufenden Tag zurueck, wenn der gesetzte keiner ist", () => {
    // So sah die Wandanzeige aus, als der Live-Client das Wort „today" als Tag ablegte:
    // „Invalid Date" in der Ueberschrift und keine hervorgehobene Schaltflaeche.
    const { titel, hervorgehoben } = kopf("today");
    expect(titel).not.toMatch(/Invalid/i);
    expect(titel).toContain("Heute");
    expect(hervorgehoben).toEqual(["Heute"]);
  });

  it("zeigt einen vergangenen Tag mit Datum", () => {
    const { titel, hervorgehoben } = kopf("2026-10-12");
    expect(titel).toContain("12.10.2026");
    expect(hervorgehoben).toEqual([]);
  });
});

describe("istTagIso", () => {
  it.each(["2026-10-17", "2024-02-29"])("nimmt %s an", (s) => expect(istTagIso(s)).toBe(true));
  it.each(["", "today", "2026-13-45", "2026-02-30", "2026-1-7", "Invalid Date", null, undefined])("weist %s zurueck", (s) =>
    expect(istTagIso(s)).toBe(false),
  );
});
