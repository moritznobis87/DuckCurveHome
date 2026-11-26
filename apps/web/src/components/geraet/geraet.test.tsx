import { act, fireEvent, render, screen, within } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { Geraet as GeraetDaten } from "@/lib/api/models";
import { Geraet, dauer, platzAbschnitte, rechenkernZeile } from "./Geraet";
import { dauerText, mitLuecken, prognoseSaetze } from "./Verlauf";
import { holeProtokoll } from "./useGeraet";

vi.mock("@/lib/live/useRole", () => ({ useRole: () => "owner" }));

const jetzt = new Date().toISOString();

function stand(felder: Partial<GeraetDaten> = {}): GeraetDaten {
  return {
    unterstuetzt: true,
    bericht_am: jetzt,
    bericht_alt: false,
    kanal: "main",
    fernzugang: false,
    rechner: {
      name: "duckcurve",
      modell: "Raspberry Pi Compute Module 5 Rev 1.0",
      system: "Debian GNU/Linux 12 (bookworm)",
      kernel: "6.6.51",
      adresse: "192.168.1.20",
      laufzeit_s: 90_000,
      kerne: 4,
      last: [0.21, 0.3, 0.28],
      temperatur_c: 51.2,
      temperatur_ampel: "gut",
      drosselung: "0x50000",
      drosselung_de: ["Seit dem Start war die Spannung mindestens einmal zu niedrig."],
      drosselung_ampel: "warn",
      // Die Uhr des Geraets: Pflichtfelder, weil sie im Schema einen Vorgabewert tragen
      // (openapi-typescript macht Eigenschaften mit `default` nicht optional). Hier die
      // unauffaellige Lage - Uhr gestellt, also kein Satz und Ampel aus dem Bericht.
      zeit_de: "",
      zeit_ampel: "gut",
      zeitzone: "Europe/Berlin",
      zeit_synchron: true,
      zeitdienst_an: true,
      speicher_gesamt_mb: 4096,
      speicher_frei_mb: 2900,
      speicher_ampel: "gut",
      platten: [{ ort: "/", gesamt_bytes: 500e9, frei_bytes: 420e9, ampel: "gut" }],
      docker: "28.0.1",
      spannung_ampel: "gut",
      eingangsspannung_v: 5.08,
      swap_gesamt_mb: 0,
      swap_frei_mb: 0,
      cpu_prozent: 6.2,
      ssd: {
        geraet: "nvme0n1",
        modell: "Intenso M.2 SSD",
        gesund: true,
        temperatur_c: 41,
        betriebsstunden: 1234,
        abnutzung_prozent: 1,
        geschrieben_bytes: 2_500_000_000_000,
        gelesen_bytes: 900_000_000_000,
        fehler: 0,
        unsichere_abschaltungen: 3,
        ampel: "gut",
        text_de: "Gesund: 1 % abgenutzt, 1234 Betriebsstunden.",
      },
      docker_platz: { images_bytes: 30e9, container_bytes: 1e6, volumes_bytes: 10e9, cache_bytes: 9e9 },
    },
    dienste: [
      { name: "api", zustand: "running", gesundheit: "healthy", gestartet_am: jetzt, neustarts: 0, ampel: "gut", text_de: "Läuft, Prüfung bestanden.", cpu_prozent: 2.5, speicher_mb: 180 },
      {
        name: "web",
        zustand: "running",
        gesundheit: "unhealthy",
        pruefung: "wget: server returned error: HTTP/1.1 503",
        pruefung_fehlschlaege: 3,
        gestartet_am: jetzt,
        neustarts: 0,
        ampel: "schlecht",
        text_de: "Läuft, aber die Prüfung schlägt fehl, 3-mal in Folge.",
      },
    ],
    einheiten: [{ name: "duckcurve-sicherung.timer", beschreibung: "", aktiv: "active", unterzustand: "waiting", eingeschaltet: true, naechster_lauf: jetzt, ampel: "gut", text_de: "Wartet auf den nächsten Lauf." }],
    sicherung: { letzte: "dch-20261120-031500.dump", letzte_am: jetzt, letzte_bytes: 4_200_000, anzahl: 14, gesamt_bytes: 1e9, ausser_haus: null, ampel: "gut", text_de: "14 Sicherung(en) auf dem Gerät. Keine Kopie außer Haus eingerichtet." },
    letzte_aktion: null,
    beschaeftigt: null,
    api: {
      version: "2026.11.1",
      commit: "abc1234",
      modus: "live",
      laufzeit_s: 3_600,
      rss_mb: 210,
      datenbank_ok: true,
      datenbank_ms: 2.1,
      datenbank_de: "Antwortet in 2 ms.",
      bridge_online: true,
      verbindung_de: "live",
      quellen: [],
      befunde: [],
      sse_clients: 2,
      alfred_eingerichtet: true,
      energy_rebuild: "fertig",
      ampel: "gut",
      text_de: "Die API läuft, Datenbank und Bridge antworten.",
    },
    ampel: "schlecht",
    text_de: "web: Läuft, aber die Prüfung schlägt fehl, 3-mal in Folge.",
    ...felder,
  };
}

const update = { unterstuetzt: true, kanal: "stable", aktuell: "2026.11.1", verfuegbar: null, update_verfuegbar: false, neuerungen: [], geprueft_am: jetzt, zustand: "bereit", schritt: null, meldung: null, zuletzt: null, anfrage_offen: false };

const verlauf = {
  unterstuetzt: true,
  spanne: "tag",
  schritt_min: 5,
  punkte: [],
  prognose: { tage_verlauf: 20, platte_bytes_pro_tag: 1.2e9, platte_voll_in_tagen: 380, datenbank_bytes_pro_tag: 2e6, ssd_geschrieben_bytes_pro_tag: 8e9 },
};

describe("Hausgerät", () => {
  const fetchMock = vi.fn();
  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal("fetch", fetchMock);
  });
  afterEach(() => vi.unstubAllGlobals());

  function antworte(geraet: GeraetDaten) {
    fetchMock.mockImplementation((url: string, init?: RequestInit) => {
      if (url.startsWith("/api/dch/system/update")) return Promise.resolve(Response.json(update));
      if (url.startsWith("/api/dch/system/geraet/verlauf")) return Promise.resolve(Response.json(verlauf));
      if (init?.method === "POST") return Promise.resolve(Response.json({ aktion: "neustart", zustand: "angefragt" }, { status: 202 }));
      return Promise.resolve(Response.json(geraet));
    });
  }

  it("zeigt Urteil, Dienste, Rechenkern und Gerät", async () => {
    antworte(stand());
    render(<Geraet />);
    await screen.findByText("web: Läuft, aber die Prüfung schlägt fehl, 3-mal in Folge.");
    expect(screen.getByText("Oberfläche")).toBeInTheDocument();
    expect(screen.getByText("Rechenkern (API)")).toBeInTheDocument();
    expect(screen.getByText("Antwortet in 2 ms.")).toBeInTheDocument();
    expect(screen.getByText(/Spannung mindestens einmal zu niedrig/)).toBeInTheDocument();
    expect(screen.getByText("420 GB frei von 500 GB")).toBeInTheDocument();
    expect(screen.getByText("Nächtliche Sicherung")).toBeInTheDocument();
  });

  it("startet einen Dienst erst nach Rückfrage neu", async () => {
    antworte(stand());
    render(<Geraet />);
    fireEvent.click(await screen.findByText("Oberfläche"));
    expect(screen.getByText("wget: server returned error: HTTP/1.1 503")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Neu starten" }));
    const frage = screen.getByRole("alertdialog");
    expect(within(frage).getByRole("button", { name: "Abbrechen" })).toHaveFocus();
    expect(fetchMock.mock.calls.some((c) => (c[1] as RequestInit | undefined)?.method === "POST")).toBe(false);
    await act(async () => {
      fireEvent.click(within(frage).getByRole("button", { name: "Neu starten" }));
    });
    const post = fetchMock.mock.calls.find((c) => (c[1] as RequestInit | undefined)?.method === "POST");
    expect(post?.[0]).toBe("/api/dch/system/geraet/aktion");
    expect(JSON.parse(String((post?.[1] as RequestInit).body))).toEqual({ aktion: "neustart", dienst: "web" });
  });

  it("sperrt die Handgriffe, solange das Gerät beschäftigt ist", async () => {
    antworte(stand({ letzte_aktion: { aktion: "sichern", zustand: "laeuft", meldung: "" }, beschaeftigt: "Das Gerät ist noch mit der letzten Aktion beschäftigt." }));
    render(<Geraet />);
    await screen.findByText("Sicherung läuft …");
    expect(screen.getByRole("button", { name: "Jetzt sichern" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Gerät neu starten" })).toBeDisabled();
  });

  it("ohne Hausgerät nur die Selbstauskunft der API", async () => {
    antworte(stand({ unterstuetzt: false, rechner: null, dienste: [], einheiten: [], sicherung: null, ampel: "gut", text_de: "" }));
    render(<Geraet />);
    await screen.findByText(/läuft nicht auf dem Hausgerät/);
    expect(screen.queryByText("Dienste")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Gerät neu starten" })).not.toBeInTheDocument();
    expect(screen.getByText("Antwortet in 2 ms.")).toBeInTheDocument();
  });

  it("holt ein Protokoll erst, wenn das Gerät es frisch geschrieben hat", async () => {
    const alt = new Date(Date.now() - 600_000).toISOString();
    let abrufe = 0;
    fetchMock.mockImplementation(() => {
      abrufe += 1;
      const erstellt = abrufe < 2 ? alt : new Date().toISOString();
      return Promise.resolve(Response.json({ dienst: "api", vorhanden: true, erstellt_am: erstellt, zeilen: ["start", "bereit"] }));
    });
    const anfragen = vi.fn().mockResolvedValue(true);
    const p = await holeProtokoll("api", anfragen, () => Promise.resolve());
    expect(anfragen).toHaveBeenCalledWith("protokoll", "api");
    expect(typeof p === "string" ? p : p.zeilen).toEqual(["start", "bereit"]);
    expect(abrufe).toBe(2);
  });

  it("zeigt SSD-Gesundheit, Platz und Prognose", async () => {
    antworte(stand());
    render(<Geraet />);
    await screen.findByText("SSD-Gesundheit");
    expect(screen.getByText("Gesund: 1 % abgenutzt, 1234 Betriebsstunden.")).toBeInTheDocument();
    expect(screen.getByText("2,5 TB / 900 GB")).toBeInTheDocument();
    expect(screen.getByText("Programme (Docker-Images, Cache)")).toBeInTheDocument();
    expect(await screen.findByText(/füllt sich um 1,2 GB pro Tag; bei diesem Tempo ist sie in etwa 13 Monaten voll/)).toBeInTheDocument();
    expect(screen.getByText("5,08 V")).toBeInTheDocument();
  });

  it("teilt den Platz auf", () => {
    const teile = platzAbschnitte(stand())!;
    // 80 GB belegt: 39 GB Programme, 10 GB Daten, 1 GB Sicherungen, der Rest ist System.
    expect(teile.map((t) => Math.round(t.bytes / 1e9))).toEqual([39, 10, 1, 30, 420]);
  });

  it("Prognose erst ab sieben Tagen, Lücken reißen die Linie", () => {
    expect(prognoseSaetze({ unterstuetzt: true, prognose: { tage_verlauf: 2 } } as never)[0]).toMatch(/sieben Tage/);
    expect(dauerText(40)).toBe("in etwa 40 Tagen");
    expect(dauerText(1100)).toBe("in etwa 3 Jahren");
    const { t, reihen } = mitLuecken(
      ["2026-11-20T10:00:00Z", "2026-11-20T10:05:00Z", "2026-11-20T10:30:00Z"],
      5,
      [{ name: "x", farbe: "#000", werte: [1, 2, 3] }],
    );
    expect(t).toHaveLength(4);
    expect(reihen[0]!.werte).toEqual([1, 2, null, 3]);
  });

  it("jedes Diagramm im Verlauf steht in einem Rahmen mit fester Höhe", () => {
    // EChart setzt sich selbst height: 100%. Ohne festen Rahmen wächst die Zeichenfläche mit ihrem
    // Behälter und der Behälter mit ihr. Zweimal ist ein Diagramm dem Rahmen entgangen, weil sein
    // Aufruf über mehrere Zeilen ging (Arbeitsspeicher und Dienste, gefunden am 26.11.2026).
    const quelle = readFileSync(join(__dirname, "Verlauf.tsx"), "utf8");
    const aufrufe = quelle.match(/<EChart\b/g) ?? [];
    expect(aufrufe).toHaveLength(1); // nur der eine in Flaeche
    expect(quelle).toMatch(/function Flaeche[\s\S]*?<div className=\{className\}>\s*<EChart option=\{o\} \/>/);
  });

  it("schreibt Dauern lesbar", () => {
    expect(dauer(42)).toBe("42 s");
    expect(dauer(3_720)).toBe("1 h 2 min");
    expect(dauer(90_000)).toBe("1 T 1 h");
  });
});

describe("rechenkernZeile", () => {
  it("nennt die Version und keinen Hash, mit richtigem Plural", () => {
    const api = { version: "2026.11.1", laufzeit_s: 3_720, rss_mb: 311.6, sse_clients: 2 };
    expect(rechenkernZeile(api)).toBe("Fassung 2026.11.1 · läuft seit 1 h 2 min · 312 MB · 2 offene Ansichten");
    expect(rechenkernZeile({ ...api, sse_clients: 1 })).toBe("Fassung 2026.11.1 · läuft seit 1 h 2 min · 312 MB · 1 offene Ansicht");
  });
});
