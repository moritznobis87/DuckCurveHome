import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { Software, ergebnisText } from "./Software";
import { UpdateHinweis } from "./UpdateHinweis";
import { gruppentitel, nachVersion, type UpdateStatus } from "./useUpdate";

let rolle: "owner" | "guest" = "owner";
vi.mock("@/lib/live/useRole", () => ({
  useRole: () => rolle,
  useSitzung: () => ({ role: rolle, hausherr: rolle === "owner", person: true }),
}));

function stand(felder: Partial<UpdateStatus> = {}): UpdateStatus {
  return {
    unterstuetzt: true,
    kanal: "main",
    aktuell: "2026.11.1",
    verfuegbar: null,
    update_verfuegbar: false,
    neuerungen: [],
    geprueft_am: "2026-11-20T07:00:00Z",
    zustand: "bereit",
    schritt: null,
    meldung: null,
    zuletzt: null,
    anfrage_offen: false,
    ...felder,
  };
}

const bereit = stand({
  update_verfuegbar: true,
  verfuegbar: "2026.11.2",
  neuerungen: [
    { version: "2026.11.2", bereich: "Alfred", text: "Rechnungen lassen sich auf Alfred ziehen." },
    { version: "2026.11.2", bereich: "Updates", text: "Updates lassen sich aus der App installieren." },
  ],
});

describe("Update", () => {
  const fetchMock = vi.fn();
  beforeEach(() => {
    rolle = "owner";
    fetchMock.mockReset();
    vi.stubGlobal("fetch", fetchMock);
    window.localStorage.clear();
  });
  afterEach(() => vi.unstubAllGlobals());

  it("ohne Hausgerät bietet die Seite nichts an", async () => {
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(stand({ unterstuetzt: false }))));
    render(<Software />);
    await screen.findByText(/Updates aus der App gibt es auf dem Hausgerät/);
    expect(screen.queryByRole("button", { name: "Update installieren" })).not.toBeInTheDocument();
  });

  it("auf dem neuesten Stand", async () => {
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(stand())));
    render(<Software />);
    await screen.findByText("Duck Curve ist auf dem neuesten Stand.");
    expect(screen.getByText("2026.11.1")).toBeInTheDocument();
  });

  it("installiert erst nach Bestätigung und schickt nur die Anfrage", async () => {
    // Wie die echte API: Nach der Anfrage meldet auch GET sie als offen.
    let angefragt = false;
    fetchMock.mockImplementation((_url: string, init?: RequestInit) => {
      if (init?.method === "POST") angefragt = true;
      return Promise.resolve(
        Response.json(angefragt ? { ...bereit, anfrage_offen: true, anfrage: "installieren" } : bereit, { status: init?.method === "POST" ? 202 : 200 }),
      );
    });
    render(<Software />);
    await screen.findByText("Rechnungen lassen sich auf Alfred ziehen.");
    fireEvent.click(screen.getByRole("button", { name: "Update installieren" }));
    // Erst die Bestätigung, mit „Abbrechen“ vorausgewählt; noch kein POST.
    expect(screen.getByRole("button", { name: "Abbrechen" })).toHaveFocus();
    expect(fetchMock.mock.calls.some((c) => (c[1] as RequestInit | undefined)?.method === "POST")).toBe(false);
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: "Jetzt installieren" }));
    });
    const post = fetchMock.mock.calls.find((c) => (c[1] as RequestInit | undefined)?.method === "POST");
    expect(post?.[0]).toBe("/api/dch/system/update");
    expect(JSON.parse(String((post?.[1] as RequestInit).body))).toEqual({ aktion: "installieren" });
    await screen.findByText("Update läuft");
  });

  it("zeigt den Fortschritt", async () => {
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(stand({ ...bereit, zustand: "laeuft", schritt: "Laden" }))));
    render(<Software />);
    await screen.findByText("Update läuft");
    expect(screen.getByText("✓ Datenbank sichern")).toBeInTheDocument();
    expect(screen.getByText("… Neue Fassung laden")).toBeInTheDocument();
    expect(screen.getByText("· Prüfen, ob alles läuft")).toBeInTheDocument();
  });

  it("nennt eine Rückkehr zur alten Fassung", () => {
    expect(ergebnisText(stand({ zustand: "zurueckgerollt", meldung: "Die vorherige läuft wieder." }))).toBe("Die vorherige läuft wieder.");
    expect(ergebnisText(stand({ zustand: "fertig", zuletzt: { am: "2026-11-20T07:05:00Z", ergebnis: "ok", von: "a", nach: "b" } }))).toMatch(/^Zuletzt aktualisiert am /);
  });

  it("der Hinweis erscheint beim Hausherrn und lässt sich für diese Fassung wegklicken", async () => {
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(bereit)));
    const { unmount } = render(<UpdateHinweis />);
    await screen.findByText(/steht ein Update bereit mit 2 Neuerungen/);
    expect(screen.getByRole("link", { name: "Ansehen und installieren" })).toHaveAttribute("href", "/system/geraet#software");
    fireEvent.click(screen.getByRole("button", { name: "Nicht jetzt" }));
    await waitFor(() => expect(screen.queryByRole("note")).not.toBeInTheDocument());
    expect(window.localStorage.getItem("dch-update-weg")).toBe("2026.11.2");
    unmount();
    // Eine neuere Fassung bringt ihn zurück.
    fetchMock.mockImplementation(() => Promise.resolve(Response.json({ ...bereit, verfuegbar: "dddddddddddd" })));
    render(<UpdateHinweis />);
    await screen.findByRole("note");
  });

  it("eine Fassung, die schon einmal nicht hochkam, drängt nicht mehr", async () => {
    const gescheitert = {
      ...bereit,
      zustand: "zurueckgerollt",
      meldung: "Die neue Fassung kam nicht gesund hoch. Die vorherige läuft wieder.",
      zuletzt: { am: "2026-11-20T07:05:00Z", ergebnis: "zurueckgerollt", von: "2026.11.1", nach: "2026.11.2" },
    };
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(gescheitert)));
    const { container, unmount } = render(<UpdateHinweis />);
    await act(async () => {});
    expect(container).toBeEmptyDOMElement();
    unmount();
    render(<Software />);
    await screen.findByText(/kam beim letzten Versuch nicht gesund hoch/);
    expect(screen.getByRole("button", { name: "Erneut versuchen" })).toBeInTheDocument();
    expect(screen.getByText(/Die vorherige läuft wieder/)).toBeInTheDocument();
  });

  it("Gäste sehen keinen Hinweis und fragen gar nicht erst", async () => {
    rolle = "guest";
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(bereit)));
    const { container } = render(<UpdateHinweis />);
    await act(async () => {});
    expect(container).toBeEmptyDOMElement();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("zeigt die Neuerungen mit Bereich, und Überschriften erst ab zwei Versionen", async () => {
    const zwei = stand({
      update_verfuegbar: true,
      verfuegbar: "Entwicklungsstand nach 2026.11.2",
      neuerungen: [
        { version: null, bereich: "Energie", text: "Die Tagesbilanz zeigt die Einspeisung getrennt." },
        { version: "2026.11.2", bereich: "Alfred", text: "Rechnungen lassen sich auf Alfred ziehen." },
      ],
    });
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(zwei)));
    render(<Software />);
    await screen.findByText("Die Tagesbilanz zeigt die Einspeisung getrennt.");
    expect(screen.getByText("Seit der letzten Version")).toBeInTheDocument();
    expect(screen.getByText("Version 2026.11.2")).toBeInTheDocument();
    expect(screen.getByText("Energie:")).toBeInTheDocument();
    expect(screen.getByText(/Update bereit: Entwicklungsstand nach 2026\.11\.2/)).toBeInTheDocument();
  });

  it("nach Updates sehen ist kein laufendes Update", async () => {
    // Vorher zeigte jede offene Anfrage „Update läuft“, auch diese.
    let angefragt = false;
    fetchMock.mockImplementation((_url: string, init?: RequestInit) => {
      if (init?.method === "POST") angefragt = true;
      const s = angefragt ? stand({ anfrage_offen: true, anfrage: "pruefen" }) : stand();
      return Promise.resolve(Response.json(s, { status: init?.method === "POST" ? 202 : 200 }));
    });
    render(<Software />);
    fireEvent.click(await screen.findByRole("button", { name: "Jetzt nach Updates sehen" }));
    await screen.findByText("Das Gerät sieht gerade nach Updates. Das dauert einige Sekunden.");
    expect(screen.queryByText("Update läuft")).not.toBeInTheDocument();
    expect(screen.getByText("Duck Curve ist auf dem neuesten Stand.")).toBeInTheDocument();
  });

  it("eine Aktion der Seite Hausgerät ist kein laufendes Update", async () => {
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(stand({ anfrage_offen: true, anfrage: "neustart" }))));
    render(<Software />);
    await screen.findByText("Duck Curve ist auf dem neuesten Stand.");
    expect(screen.queryByText("Update läuft")).not.toBeInTheDocument();
  });

  it("eine einzelne Version braucht keine Überschrift", async () => {
    fetchMock.mockImplementation(() => Promise.resolve(Response.json(bereit)));
    render(<Software />);
    await screen.findByText("Rechnungen lassen sich auf Alfred ziehen.");
    expect(screen.queryByText("Version 2026.11.2")).not.toBeInTheDocument();
  });
});

describe("nachVersion", () => {
  it("fasst aufeinanderfolgende Neuerungen derselben Version zusammen", () => {
    const gruppen = nachVersion([
      { version: null, bereich: "Energie", text: "a" },
      { version: "2026.12.1", bereich: "Haus", text: "b" },
      { version: "2026.12.1", bereich: "Geld", text: "c" },
      { version: "2026.11.2", bereich: "Haus", text: "d" },
    ]);
    expect(gruppen.map((g) => [g.version, g.eintraege.length])).toEqual([
      [null, 1],
      ["2026.12.1", 2],
      ["2026.11.2", 1],
    ]);
    expect(gruppentitel(null)).toBe("Seit der letzten Version");
    expect(gruppentitel("2026.12.1")).toBe("Version 2026.12.1");
  });
});
