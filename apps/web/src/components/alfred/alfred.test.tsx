import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { AREAS } from "@/lib/areas";
import { Alfred, HALTEN_MS, NACHLAUF_MS, WACHE_MS, rechnungZusammenfassung, technikZeile, tibberZusammenfassung } from "./Alfred";
import { SEITEN, TEXTE, ortBestimmen, wegweiser, wissen } from "./hilfetexte";
import { schrittText, stromLesen, verlaufFuerServer, vorschlagAenderung, vorschlagAufruf, vorschlagText } from "./strom";

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
    expect(vorschlagAenderung({ art: "sollwert", ziel: 3, name: "Bad", alt: 21, neu: 22.5 })).toBe("Bad: Solltemperatur 21 °C → 22,5 °C");
    // Ein unbekannter Ausgangszustand wird nicht erraten.
    expect(vorschlagAenderung({ art: "schalten", ziel: "x", name: "Licht", an: false, war_an: null })).toBe("Licht: ? → aus");
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

  /** Ein Modell, das "Licht an" mit einem Vorschlag beantwortet - und im Text etwas anderes
   *  behauptet als im Vorschlag steht. Die Bestätigung muss den Vorschlag zeigen, nicht den Text. */
  function lichtModell(geschaltet: RequestInit[]): void {
    fetchMock.mockImplementation((url: string, init?: RequestInit) => {
      if (url.endsWith("/alfred/status")) return Promise.resolve(Response.json({ bereit: true, anbieter: "Mistral" }));
      if (url.endsWith("/alfred/ask/stream")) {
        const rumpf = JSON.parse(String(init?.body)) as { frage: string; wissen: string; verlauf: unknown[] };
        expect(rumpf.frage).toBe("Licht an");
        expect(rumpf.wissen).toContain("Bereich Energie, Reiter Strom");
        return Promise.resolve(
          strom(
            'event: schritt\ndata: {"werkzeug": "schalten_vorschlagen"}\n\nevent: antwort\ndata: {"bereit": true, "antwort": "Ich habe den Innenhof **vorgeschlagen**.", "vorschlaege": [{"art": "schalten", "ziel": "terrace_light", "name": "Licht Terrasse", "an": true, "war_an": false}]}\n\n',
          ),
        );
      }
      if (url.endsWith("/control/actuators/terrace_light")) {
        geschaltet.push(init ?? {});
        return Promise.resolve(Response.json({ ok: true, message_de: "Licht Terrasse eingeschaltet." }));
      }
      return Promise.reject(new Error(url));
    });
  }

  async function lichtFragen(): Promise<void> {
    render(<Alfred />);
    fireEvent.click(screen.getByRole("button", { name: TEXTE.ansprechen }));
    fireEvent.change(await screen.findByLabelText(TEXTE.frageFeld), { target: { value: "Licht an" } });
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: TEXTE.frageSenden }));
    });
    await screen.findByText("vorgeschlagen");
  }

  it("ein Vorschlag schaltet nicht von selbst, und Abbrechen schaltet nie", async () => {
    const geschaltet: RequestInit[] = [];
    lichtModell(geschaltet);
    await lichtFragen();
    expect(screen.getByText(TEXTE.kiMarke)).toBeInTheDocument();
    // Noch nichts geschaltet: nur Status und Frage gingen hinaus.
    expect(fetchMock.mock.calls.map((c) => String(c[0]))).toEqual(["/api/dch/alfred/status", "/api/dch/alfred/ask/stream"]);

    fireEvent.click(screen.getByRole("button", { name: TEXTE.vorschlagPruefen }));
    const dialog = screen.getByRole("alertdialog");
    // Gezeigt wird der Vorschlag aus dem Dienst, mit vorher und nachher - nicht der Antworttext.
    expect(dialog).toHaveTextContent("Licht Terrasse: aus → ein");
    expect(screen.getByRole("button", { name: TEXTE.bestaetigungAbbrechen })).toHaveFocus();

    fireEvent.click(screen.getByRole("button", { name: TEXTE.bestaetigungAbbrechen }));
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    // Escape bricht eine offene Bestätigung ab, ohne das Panel zu schließen.
    fireEvent.click(screen.getByRole("button", { name: TEXTE.vorschlagPruefen }));
    fireEvent.keyDown(document, { key: "Escape" });
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(screen.getByRole("dialog", { name: TEXTE.name })).toBeInTheDocument();
    expect(geschaltet).toHaveLength(0);
  });

  it("erst OK schaltet, und zwar mit dem Vermerk „über Alfred“", async () => {
    const geschaltet: RequestInit[] = [];
    lichtModell(geschaltet);
    await lichtFragen();
    fireEvent.click(screen.getByRole("button", { name: TEXTE.vorschlagPruefen }));
    fireEvent.click(screen.getByRole("button", { name: TEXTE.bestaetigungOk }));
    await screen.findByText("Licht Terrasse eingeschaltet.");
    expect(geschaltet).toHaveLength(1);
    expect(JSON.parse(String(geschaltet[0]!.body))).toEqual({ state: true });
    expect((geschaltet[0]!.headers as Record<string, string>)["x-dch-ueber"]).toBe("alfred");
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

  it("eine Tibber-Rechnung per Drag-and-drop: auch ohne Modell, mit Zusammenfassung und Link", async () => {
    const gesendet: { url: string; init?: RequestInit }[] = [];
    fetchMock.mockImplementation((url: string, init?: RequestInit) => {
      if (url.endsWith("/alfred/status")) return Promise.resolve(Response.json({ bereit: false }));
      gesendet.push({ url, init });
      return Promise.resolve(
        Response.json({
          art: "tibber",
          link: "/geld/rechnungen?nr=5085697",
          andere: null,
          tibber: {
            zeitraum: "Oktober 2026",
            kwh: 412,
            brutto_eur: 120.5,
            ct_kwh_brutto: 29.25,
            gemessen_kwh: 410,
            abdeckung: 0.99,
            urteil: "ok",
            befunde: [],
            schon_bekannt: false,
          },
        }),
      );
    });
    render(<Alfred />);
    const pdf = new File(["%PDF"], "Rechnung Oktober.pdf", { type: "application/pdf" });
    const ziel = screen.getByRole("button", { name: TEXTE.ansprechen }).parentElement!;
    fireEvent.dragOver(ziel, { dataTransfer: { types: ["Files"], files: [pdf], dropEffect: "none" } });
    expect(ziel).toHaveClass("zieht");
    await act(async () => {
      fireEvent.drop(ziel, { dataTransfer: { types: ["Files"], files: [pdf] } });
    });
    await screen.findByText(/Tibber-Rechnung Oktober 2026/);
    // Fest geprüft, ohne Modell: keine KI-Marke, aber ein Link zur vollen Auswertung.
    expect(screen.queryByText(TEXTE.kiMarke)).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: TEXTE.rechnungZurAuswertung })).toHaveAttribute("href", "/geld/rechnungen?nr=5085697");
    expect(gesendet).toHaveLength(1);
    expect(gesendet[0]!.url).toBe("/api/dch/alfred/rechnung?file_name=Rechnung%20Oktober.pdf");
    expect(gesendet[0]!.init?.body).toBe(pdf);
  });

  it("Gäste können nichts ablegen", () => {
    rolle = "guest";
    render(<Alfred />);
    const ziel = screen.getByRole("button", { name: TEXTE.ansprechen }).parentElement!;
    fireEvent.drop(ziel, { dataTransfer: { types: ["Files"], files: [new File(["%PDF"], "r.pdf", { type: "application/pdf" })] } });
    expect(fetchMock).not.toHaveBeenCalledWith(expect.stringContaining("/alfred/rechnung"), expect.anything());
  });

  it("auf /locked gibt es Alfred nicht", () => {
    pfad = "/locked";
    const { container } = render(<Alfred />);
    expect(container).toBeEmptyDOMElement();
  });
});

/** Eine Spracherkennung zum Fernsteuern: Der Test löst ihre Ereignisse selbst aus. */
class FalscheErkennung {
  static alle: FalscheErkennung[] = [];
  lang = "";
  interimResults = true;
  maxAlternatives = 0;
  onstart: (() => void) | null = null;
  onaudiostart: (() => void) | null = null;
  onspeechstart: (() => void) | null = null;
  onresult: ((e: { results: ({ transcript: string }[] & { isFinal?: boolean })[] }) => void) | null = null;
  onend: (() => void) | null = null;
  onerror: ((e: { error?: string }) => void) | null = null;
  start = vi.fn();
  stop = vi.fn();
  abort = vi.fn();
  constructor() {
    FalscheErkennung.alle.push(this);
  }
}
const letzte = () => FalscheErkennung.alle.at(-1)!;
/** Ein Ergebnis der Erkennung; ohne `final` ein Zwischenstand. */
const ergebnis = (transcript: string, final = false) => ({ results: [Object.assign([{ transcript }], { isFinal: final })] });

describe("Halten zum Sprechen", () => {
  const fetchMock = vi.fn();
  const gefragt: string[] = [];
  const ente = () => screen.getByRole("button", { name: TEXTE.ansprechen });
  /** Ente drücken und halten. Die Antwort auf die Statusfrage kommt, während sie noch gedrückt ist. */
  const halten = async () => {
    fireEvent.pointerDown(ente(), { pointerId: 1, pointerType: "touch" });
    await act(() => vi.advanceTimersByTimeAsync(HALTEN_MS / 2));
    await act(() => vi.advanceTimersByTimeAsync(HALTEN_MS / 2));
  };
  /** Loslassen, und der Klick, den der Browser danach schickt. */
  const loslassen = () => {
    fireEvent.pointerUp(ente(), { pointerId: 1, pointerType: "touch" });
    fireEvent.click(ente());
  };

  beforeEach(() => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    pfad = "/strom";
    rolle = "owner";
    gefragt.length = 0;
    FalscheErkennung.alle = [];
    fetchMock.mockReset();
    fetchMock.mockImplementation((url: string, init?: RequestInit) => {
      if (url.endsWith("/alfred/status")) return Promise.resolve(Response.json({ bereit: true, anbieter: "Mistral" }));
      if (url.endsWith("/alfred/ask/stream")) {
        gefragt.push((JSON.parse(String(init?.body)) as { frage: string }).frage);
        return Promise.resolve(
          strom(
            'event: antwort\ndata: {"bereit": true, "antwort": "Das Terrassenlicht ist **vorgeschlagen**.", "vorschlaege": [{"art": "schalten", "ziel": "terrace_light", "name": "Licht Terrasse", "an": true, "war_an": false}]}\n\n',
          ),
        );
      }
      return Promise.reject(new Error(url));
    });
    vi.stubGlobal("fetch", fetchMock);
    vi.stubGlobal("webkitSpeechRecognition", FalscheErkennung);
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it("Ente halten hört zu, Loslassen schickt den erkannten Text als Frage, geschaltet wird nichts", async () => {
    render(<Alfred />);
    expect(ente()).toHaveAttribute("title", TEXTE.ansprechenHalten);
    await halten();
    // Schon beim Drücken gefragt: Ist ein Modell da? Und das Panel steht offen und sagt, was passiert.
    expect(fetchMock).toHaveBeenCalledWith("/api/dch/alfred/status", expect.anything());
    expect(screen.getByRole("dialog", { name: TEXTE.name })).toBeInTheDocument();
    expect(screen.getByText(TEXTE.haltenLaeuft)).toBeInTheDocument();
    expect(ente().parentElement).toHaveClass("hoert");
    const e = letzte();
    expect(e.start).toHaveBeenCalledOnce();
    expect(e.lang).toBe("de-DE");

    act(() => e.onstart?.());
    loslassen();
    expect(e.stop).toHaveBeenCalledOnce();
    expect(screen.getByText(TEXTE.sprachWartet)).toBeInTheDocument();
    // Der Klick nach dem Halten schließt das eben geöffnete Panel nicht.
    expect(screen.getByRole("dialog", { name: TEXTE.name })).toBeInTheDocument();

    await act(async () => {
      e.onresult?.({ results: [[{ transcript: " Mach das Terrassenlicht an " }]] });
      e.onend?.();
    });
    await screen.findByText("vorgeschlagen");
    expect(gefragt).toEqual(["Mach das Terrassenlicht an"]);
    expect(screen.getByText("Mach das Terrassenlicht an")).toBeInTheDocument();
    // Ein Sprachbefehl wird ein Vorschlag wie jede Frage: Nur Status und Frage gingen hinaus.
    expect(screen.getByRole("button", { name: TEXTE.vorschlagPruefen })).toBeInTheDocument();
    expect(fetchMock.mock.calls.map((c) => String(c[0]))).toEqual(["/api/dch/alfred/status", "/api/dch/alfred/ask/stream"]);
    expect(ente().parentElement).not.toHaveClass("hoert");
  });

  it("kurz tippen öffnet nur das Panel und hört nicht zu", async () => {
    render(<Alfred />);
    fireEvent.pointerDown(ente(), { pointerId: 1, pointerType: "touch" });
    loslassen();
    await act(() => vi.advanceTimersByTimeAsync(HALTEN_MS * 3));
    expect(screen.getByRole("dialog", { name: TEXTE.name })).toBeInTheDocument();
    expect(FalscheErkennung.alle).toHaveLength(0);
    // Ein zweites Tippen schließt wieder: Vom Halten bleibt nichts hängen.
    fireEvent.pointerDown(ente(), { pointerId: 1, pointerType: "touch" });
    loslassen();
    expect(screen.queryByRole("dialog", { name: TEXTE.name })).not.toBeInTheDocument();
  });

  it("läuft die Erkennung nie an, endet das Zuhören beim Loslassen mit einem Hinweis", async () => {
    // So verhält sich Safari, wenn die Erkennung angeboten wird, aber nicht antwortet (Web-App vom
    // Home-Bildschirm), und auch, solange die Frage nach dem Mikrofon offen steht.
    render(<Alfred />);
    await halten();
    loslassen();
    expect(letzte().abort).toHaveBeenCalledOnce();
    expect(screen.getByText(TEXTE.sprachNichtAngelaufen)).toBeInTheDocument();
    expect(ente().parentElement).not.toHaveClass("hoert");
    expect(gefragt).toEqual([]);
  });

  it("kommt nach dem Loslassen kein Text, beendet die Wache das Zuhören, und ein später Text fragt nichts", async () => {
    render(<Alfred />);
    await halten();
    const e = letzte();
    act(() => e.onstart?.());
    loslassen();
    await act(() => vi.advanceTimersByTimeAsync(WACHE_MS));
    expect(e.abort).toHaveBeenCalledOnce();
    expect(screen.getByText(TEXTE.sprachKeineAntwort)).toBeInTheDocument();
    expect(ente().parentElement).not.toHaveClass("hoert");
    await act(async () => {
      e.onresult?.({ results: [[{ transcript: "zu spät" }]] });
      e.onend?.();
    });
    expect(gefragt).toEqual([]);
  });

  it("ein verweigertes Mikrofon und Stille haben je einen eigenen Satz", async () => {
    render(<Alfred />);
    await halten();
    act(() => {
      letzte().onerror?.({ error: "not-allowed" });
      letzte().onend?.();
    });
    expect(screen.getByText(TEXTE.sprachNichtErlaubt)).toBeInTheDocument();
    loslassen();

    await halten();
    act(() => {
      letzte().onstart?.();
      letzte().onerror?.({ error: "no-speech" });
      letzte().onend?.();
    });
    expect(screen.getByText(TEXTE.sprachNichtsGehoert)).toBeInTheDocument();
    expect(gefragt).toEqual([]);
  });

  it("der Mikrofonknopf im Panel nimmt denselben Weg", async () => {
    render(<Alfred />);
    fireEvent.click(ente());
    const mikro = await screen.findByRole("button", { name: TEXTE.mikrofon });
    fireEvent.click(mikro);
    const e = letzte();
    expect(e.start).toHaveBeenCalledOnce();
    expect(screen.getByText(TEXTE.mikrofonLaeuft, { selector: ".alfred-schritt" })).toBeInTheDocument();
    await act(async () => {
      e.onstart?.();
      e.onresult?.({ results: [[{ transcript: "Licht an" }]] });
      e.onend?.();
    });
    await screen.findByText("vorgeschlagen");
    expect(gefragt).toEqual(["Licht an"]);
  });

  it("ohne Modell sagt Alfred das, statt zuzuhören", async () => {
    fetchMock.mockImplementation(() => Promise.resolve(Response.json({ bereit: false })));
    render(<Alfred />);
    await halten();
    expect(screen.getByText(TEXTE.frageOhneModell)).toBeInTheDocument();
    expect(FalscheErkennung.alle).toHaveLength(0);
  });

  it("ohne Spracherkennung im Browser gibt es einen Hinweis statt Stille", async () => {
    vi.stubGlobal("webkitSpeechRecognition", undefined);
    render(<Alfred />);
    expect(ente()).toHaveAttribute("title", TEXTE.ansprechen);
    await halten();
    expect(screen.getByText(TEXTE.sprachOhneBrowser)).toBeInTheDocument();
  });

  it("Safari unter iOS: Ein Zwischentext erscheint live und gilt kurz nach dem Loslassen, auch ohne Ende", async () => {
    render(<Alfred />);
    await halten();
    const e = letzte();
    expect(e.interimResults).toBe(true);
    act(() => {
      e.onstart?.();
      e.onresult?.(ergebnis("Mach das"));
    });
    expect(screen.getByText("Ich höre: „Mach das“")).toBeInTheDocument();
    act(() => e.onresult?.(ergebnis("Mach das Terrassenlicht an")));
    loslassen();
    expect(gefragt).toEqual([]);
    // Kein endgültiges Ergebnis, kein Ende: Nach dem Nachlauf gilt der letzte Zwischentext.
    await act(() => vi.advanceTimersByTimeAsync(NACHLAUF_MS));
    await screen.findByText("vorgeschlagen");
    expect(gefragt).toEqual(["Mach das Terrassenlicht an"]);
    expect(e.abort).toHaveBeenCalled();
  });

  it("ein endgültiges Ergebnis fragt sofort, ohne auf das Loslassen zu warten", async () => {
    render(<Alfred />);
    await halten();
    await act(async () => {
      letzte().onstart?.();
      letzte().onresult?.(ergebnis("Wie war die Woche?", true));
    });
    await screen.findByText("vorgeschlagen");
    expect(gefragt).toEqual(["Wie war die Woche?"]);
    // Das Loslassen danach fragt nicht noch einmal.
    loslassen();
    expect(gefragt).toHaveLength(1);
  });

  it("übernimmt das System die Berührung, hört Alfred weiter zu, bis der Finger sich hebt", async () => {
    render(<Alfred />);
    await halten();
    const e = letzte();
    act(() => e.onstart?.());
    fireEvent.pointerCancel(ente(), { pointerId: 1, pointerType: "touch" });
    expect(e.stop).not.toHaveBeenCalled();
    expect(screen.getByText(TEXTE.haltenLaeuft)).toBeInTheDocument();
    fireEvent.touchEnd(window);
    expect(e.stop).toHaveBeenCalledOnce();
    // Kam nichts an, steht in der Technikzeile, dass das System die Berührung übernommen hatte.
    act(() => e.onend?.());
    expect(screen.getByText(TEXTE.sprachNichtsGehoert)).toBeInTheDocument();
    expect(screen.getByText(/Berührung vom System übernommen/)).toBeInTheDocument();
  });

  it("derselbe Fehler stapelt sich nicht: einmal deutlicher, dann nur die Technikzeile neu", async () => {
    render(<Alfred />);
    for (let i = 0; i < 3; i++) {
      await halten();
      act(() => {
        letzte().onstart?.();
        letzte().onaudiostart?.();
      });
      loslassen();
      act(() => letzte().onend?.());
    }
    expect(screen.getAllByText(TEXTE.sprachNichtsGehoert)).toHaveLength(1);
    expect(screen.getAllByText(TEXTE.sprachWiederholt)).toHaveLength(1);
    expect(screen.getAllByText(/Start ✓ · Ton ✓ · Sprache – · Text –/)).toHaveLength(2);
  });

  it("Gäste halten nicht: Die Ente öffnet nur das Panel", async () => {
    rolle = "guest";
    render(<Alfred />);
    await halten();
    expect(screen.queryByRole("dialog", { name: TEXTE.name })).not.toBeInTheDocument();
    expect(FalscheErkennung.alle).toHaveLength(0);
    loslassen();
    expect(screen.getByRole("dialog", { name: TEXTE.name })).toBeInTheDocument();
  });
});

describe("Technikzeile", () => {
  it("sagt, wie weit die Erkennung kam", () => {
    const z = { art: "halten" as const, gestartet: true, ton: true, sprache: false, text: "", fehler: "no-speech", losgelassen: true, abgebrochen: false, beginn: 1000 };
    expect(technikZeile(z, 2800, true)).toBe("Start ✓ · Ton ✓ · Sprache – · Text – · Fehler no-speech · 1,8\u00a0s · nach dem Loslassen · Web-App");
    expect(technikZeile({ ...z, art: "knopf", fehler: null, abgebrochen: true }, 1500, false)).toBe(
      "Start ✓ · Ton ✓ · Sprache – · Text – · 0,5\u00a0s · Berührung vom System übernommen · Browser",
    );
  });
});

describe("Rechnung", () => {
  it("fasst eine Tibber-Prüfung zusammen und nennt nur die Befunde, auf die es ankommt", () => {
    const text = tibberZusammenfassung({
      zeitraum: "Oktober 2026",
      kwh: 412,
      brutto_eur: 120.5,
      ct_kwh_brutto: 29.25,
      gemessen_kwh: 380,
      abdeckung: 0.97,
      urteil: "warning",
      befunde: [{ stufe: "warning", titel: "Menge", text: "Rechnung 412 kWh, gemessen 380 kWh." }],
      schon_bekannt: true,
    });
    expect(text).toContain("**Tibber-Rechnung Oktober 2026**: 412 kWh, 120,5 € brutto, im Mittel 29,25 ct/kWh. Ergebnis: auffällig.");
    expect(text).toContain("⚠ Menge: Rechnung 412 kWh, gemessen 380 kWh.");
    expect(text).toContain("lag schon vor");
    const ohneMessung = tibberZusammenfassung({
      zeitraum: "Juni 2026", kwh: 251, brutto_eur: 97.54, ct_kwh_brutto: 34.24, gemessen_kwh: 0, abdeckung: 0,
      urteil: "info", befunde: [], schon_bekannt: false,
    });
    expect(ohneMessung).not.toContain("Eigene Messung");
  });

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
