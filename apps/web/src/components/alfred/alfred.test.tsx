import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { AREAS } from "@/lib/areas";
import { Alfred, rechnungZusammenfassung } from "./Alfred";
import { SEITEN, TEXTE, ortBestimmen, wegweiser, wissen } from "./hilfetexte";
import { schrittText, stromLesen, verlaufFuerServer, vorschlagAufruf, vorschlagText } from "./strom";

let pfad = "/strom";
let rolle: "owner" | "guest" = "owner";
vi.mock("next/navigation", () => ({ usePathname: () => pfad }));
vi.mock("@/lib/live/useRole", () => ({ useRole: () => rolle }));

function strom(text: string): Response {
  const bytes = new TextEncoder().encode(text);
  return new Response(
    new ReadableStream({
      start(c) {
        // In zwei Stücken, mitten in einer Zeile getrennt: der Puffer muss das zusammensetzen.
        c.enqueue(bytes.slice(0, 17));
        c.enqueue(bytes.slice(17));
        c.close();
      },
    }),
    { status: 200, headers: { "content-type": "text/event-stream" } },
  );
}

describe("Hilfetexte", () => {
  it("jeder Reiter und jeder Bereich hat einen Seitentext", () => {
    for (const a of AREAS) {
      expect(SEITEN[a.href], a.href).toBeTruthy();
      for (const t of a.tabs) {
        expect(SEITEN[t.href], t.href).toBeTruthy();
        for (const u of t.unter ?? []) expect(SEITEN[u.href], u.href).toBeTruthy();
      }
    }
  });

  it("es gibt keinen Seitentext für eine Adresse, die es nicht gibt", () => {
    const adressen = new Set(AREAS.flatMap((a) => [a.href, ...a.tabs.flatMap((t) => [t.href, ...(t.unter ?? []).map((u) => u.href)])]));
    for (const href of Object.keys(SEITEN)) expect(adressen.has(href), href).toBe(true);
  });

  it("der Wegweiser entsteht aus der Leiste und nennt nur, was dort steht", () => {
    const text = wegweiser();
    for (const a of AREAS) for (const t of a.tabs) expect(text).toContain(t.label);
    expect(text).toContain("Rechnungen [nur Vollzugriff]");
    expect(text).toContain("Fahrplan (Ansichten: Voraus, Rückblick)");
  });

  it("der Ort folgt Bereich und Reiter", () => {
    expect(ortBestimmen("/waerme/nachbetrachtung")).toMatchObject({ bereich: "Technik", reiter: "Fahrplan" });
    expect(ortBestimmen("/").bereich).toBe("Jetzt");
    expect(wissen("/geld/rechnungen")).toContain("Bereich Geld, Reiter Rechnungen");
  });
});

describe("Strom", () => {
  it("liest Schritte und Antwort, auch mit \\r\\n und geteilten Paketen", async () => {
    const schritte: string[] = [];
    let antwort = "";
    await stromLesen(
      strom('event: schritt\r\ndata: {"werkzeug": "jetzt"}\r\n\r\nevent: antwort\r\ndata: {"bereit": true, "antwort": "42", "vorschlaege": []}\r\n\r\n'),
      { schritt: (s) => schritte.push(s.werkzeug), antwort: (d) => (antwort = d.antwort), fehler: () => undefined },
    );
    expect(schritte).toEqual(["jetzt"]);
    expect(antwort).toBe("42");
  });

  it("unbekannte Werkzeuge bekommen den allgemeinen Satz", () => {
    expect(schrittText({ werkzeug: "jetzt" }, TEXTE)).toBe(TEXTE.schritte.jetzt);
    expect(schrittText({ werkzeug: "neu_im_dienst" }, TEXTE)).toBe(TEXTE.schrittAllgemein);
  });

  it("der Verlauf ist gekürzt und trägt nur Rolle und Inhalt", () => {
    const viele = Array.from({ length: 15 }, (_, i) => ({ wer: "nutzer", inhalt: String(i), kennung: `k${i}` }));
    const v = verlaufFuerServer(viele);
    expect(v).toHaveLength(10);
    expect(v[0]).toEqual({ wer: "nutzer", inhalt: "5" });
  });

  it("Vorschläge gehen an die Endpunkte der Schalter", () => {
    expect(vorschlagAufruf({ art: "schalten", ziel: "terrace_light", name: "Licht Terrasse", an: true })).toEqual({
      pfad: "/api/dch/control/actuators/terrace_light",
      rumpf: { state: true },
    });
    expect(vorschlagAufruf({ art: "sollwert", ziel: 3, name: "Bad", alt: 21, neu: 22.5 })).toEqual({
      pfad: "/api/dch/rooms/3/setpoint",
      rumpf: { setpoint_c: 22.5 },
    });
    expect(vorschlagText({ art: "sollwert", ziel: 3, name: "Bad", alt: 21, neu: 22.5 })).toBe("Bad: Soll 21 → 22,5 °C");
  });
});

describe("Panel", () => {
  const fetchMock = vi.fn();
  beforeEach(() => {
    pfad = "/strom";
    rolle = "owner";
    fetchMock.mockReset();
    vi.stubGlobal("fetch", fetchMock);
  });
  afterEach(() => vi.unstubAllGlobals());

  it("ohne Modell: Begrüßung, Seitentext, kein Eingabefeld", async () => {
    fetchMock.mockResolvedValue(Response.json({ bereit: false }));
    render(<Alfred />);
    fireEvent.click(screen.getByRole("button", { name: TEXTE.ansprechen }));
    expect(screen.getByText(TEXTE.begruessung)).toBeInTheDocument();
    await screen.findByText(TEXTE.hinweisOhneModell);
    expect(screen.queryByLabelText(TEXTE.frageFeld)).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: TEXTE.seiteErklaeren }));
    expect(screen.getByText(SEITEN["/strom"]!)).toBeInTheDocument();
  });

  it("Gäste fragen nicht, auch wenn ein Modell da ist", async () => {
    rolle = "guest";
    fetchMock.mockResolvedValue(Response.json({ bereit: true, anbieter: "Mistral" }));
    render(<Alfred />);
    fireEvent.click(screen.getByRole("button", { name: TEXTE.ansprechen }));
    await screen.findByText(/KI-Assistent \(Mistral\)/);
    expect(screen.queryByLabelText(TEXTE.frageFeld)).not.toBeInTheDocument();
  });

  it("mit Modell: Frage, Schritt, KI-Antwort und ein Vorschlag, der erst auf Knopfdruck schaltet", async () => {
    fetchMock.mockImplementation((url: string, init?: RequestInit) => {
      if (url.endsWith("/alfred/status")) return Promise.resolve(Response.json({ bereit: true, anbieter: "Mistral" }));
      if (url.endsWith("/alfred/ask/stream")) {
        const rumpf = JSON.parse(String(init?.body)) as { frage: string; wissen: string; verlauf: unknown[] };
        expect(rumpf.frage).toBe("Licht an");
        expect(rumpf.wissen).toContain("Bereich Energie, Reiter Strom");
        return Promise.resolve(
          strom(
            'event: schritt\ndata: {"werkzeug": "schalten_vorschlagen"}\n\nevent: antwort\ndata: {"bereit": true, "antwort": "Ich habe es **vorgeschlagen**.", "vorschlaege": [{"art": "schalten", "ziel": "terrace_light", "name": "Licht Terrasse", "an": true}]}\n\n',
          ),
        );
      }
      if (url.endsWith("/control/actuators/terrace_light")) {
        expect(JSON.parse(String(init?.body))).toEqual({ state: true });
        return Promise.resolve(Response.json({ ok: true, message_de: "Licht Terrasse eingeschaltet." }));
      }
      return Promise.reject(new Error(url));
    });
    render(<Alfred />);
    fireEvent.click(screen.getByRole("button", { name: TEXTE.ansprechen }));
    const feld = await screen.findByLabelText(TEXTE.frageFeld);
    fireEvent.change(feld, { target: { value: "Licht an" } });
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: TEXTE.frageSenden }));
    });
    await screen.findByText("vorgeschlagen");
    expect(screen.getByText(TEXTE.kiMarke)).toBeInTheDocument();
    // Noch nichts geschaltet: nur Status und Frage gingen hinaus.
    expect(fetchMock.mock.calls.map((c) => String(c[0]))).toEqual(["/api/dch/alfred/status", "/api/dch/alfred/ask/stream"]);
    fireEvent.click(screen.getByRole("button", { name: TEXTE.vorschlagAusfuehren }));
    await screen.findByText("Licht Terrasse eingeschaltet.");
    await waitFor(() => expect(screen.queryByText(TEXTE.vorschlagTitel)).not.toBeInTheDocument());
  });

  it("die Tagesgrenze hat einen eigenen Satz", async () => {
    fetchMock.mockImplementation((url: string) =>
      Promise.resolve(
        url.endsWith("/status")
          ? Response.json({ bereit: true, anbieter: "Mistral" })
          : Response.json({ error: { code: "zu_viele_fragen", message: "", details: null } }, { status: 429 }),
      ),
    );
    render(<Alfred />);
    fireEvent.click(screen.getByRole("button", { name: TEXTE.ansprechen }));
    fireEvent.change(await screen.findByLabelText(TEXTE.frageFeld), { target: { value: "Und?" } });
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: TEXTE.frageSenden }));
    });
    await screen.findByText(TEXTE.frageTagesgrenze);
  });

  it("auf /locked gibt es Alfred nicht", () => {
    pfad = "/locked";
    const { container } = render(<Alfred />);
    expect(container).toBeEmptyDOMElement();
  });
});

describe("Rechnung", () => {
  it("fasst gelesene Werte und Befunde zusammen", () => {
    const text = rechnungZusammenfassung({
      gelesen: { anbieter: "Stadtwerke", von: "2026-08-01", bis: "2026-08-31", kwh: 312, brutto_eur: 109.84, arbeitspreis_ct_kwh: 31.2 },
      mittlerer_preis_ct_kwh: 35.21,
      gemessen_kwh: 300,
      abdeckung: 0.98,
      befunde: [{ stufe: "ok", titel: "Verbrauch gegen eigene Messung", text: "Rechnung 312 kWh, gemessen 300 kWh (+4,0 %)." }],
    });
    expect(text).toContain("**Stadtwerke**, 1.8.2026 bis 31.8.2026: 312 kWh, 109,84 € brutto, im Mittel 35,21 ct/kWh.");
    expect(text).toContain("Eigene Messung: 300 kWh (Abdeckung 98 %).");
  });
});
