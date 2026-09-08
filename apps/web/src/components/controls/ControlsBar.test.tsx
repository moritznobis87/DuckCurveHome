import { act, fireEvent, render, screen, within } from "@testing-library/react";
import type * as ApiClient from "@/lib/api/client";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { ControlsBar } from "./ControlsBar";
import type { LiveState } from "@/lib/api/models";

vi.mock("@/lib/api/client", async () => {
  const actual = await vi.importActual<typeof ApiClient>("@/lib/api/client");
  return {
    ...actual,
    api: {
      setStoveMode: vi.fn(async () => ({})),
      setHeatPumpMode: vi.fn(async () => ({})),
      switchActuator: vi.fn(async () => ({ ok: true })),
    },
  };
});

type Stove = NonNullable<LiveState["stove"]>;

function state(stove?: Partial<Stove>): LiveState {
  return {
    snapshot: { actuators: {} },
    heat_pump: { running: false },
    operating_mode: { system_mode: "auto", auto_profile: "smart", override: null },
    decision: null,
    stove: stove
      ? { present: true, control_enabled: true, mode: "auto", quality: "ok", note_de: "", ...stove }
      : { present: false, control_enabled: false, mode: "auto", quality: "unavailable", note_de: "" },
  } as unknown as LiveState;
}

/** Das Ofensegment, gefunden über die Vorlesehilfe: der Name steht nicht mehr sichtbar da. */
function stoveSegment(): HTMLElement {
  const icon = screen.getByLabelText("Pelletofen");
  const box = icon.closest(".controls-device");
  if (!box) throw new Error("Ofensegment nicht gefunden");
  return box as HTMLElement;
}

describe("untere Leiste", () => {
  beforeEach(() => vi.clearAllMocks());

  it("zeigt ohne Ofen nur die Wärmepumpe", () => {
    const { container } = render(<ControlsBar state={state()} />);
    expect(screen.getByLabelText("Wärmepumpe")).toBeInTheDocument();
    expect(screen.queryByLabelText("Pelletofen")).toBeNull();
    expect(container.querySelector(".controls-grid.has-stove")).toBeNull();
  });

  it("gibt Wärmepumpe und Ofen dieselben drei Schaltflächen", () => {
    render(<ControlsBar state={state({ running: false })} />);
    for (const gerät of ["Wärmepumpe", "Pelletofen"]) {
      const box = screen.getByLabelText(gerät).closest(".controls-device") as HTMLElement;
      expect(within(box).getByRole("button", { name: "Auto" })).toBeInTheDocument();
      expect(within(box).getByRole("button", { name: "An" })).toBeInTheDocument();
      expect(within(box).getByRole("button", { name: "Aus" })).toBeInTheDocument();
    }
  });

  it("stellt Wunsch und Wirklichkeit nebeneinander", () => {
    // Zwischen Befehl und Feuer liegen Minuten. Beides zugleich zu zeigen ist der Zweck der Zeile.
    render(<ControlsBar state={state({ running: false, mode: "on", ends_at: "2026-01-15T21:00:00Z" })} />);
    expect(stoveSegment().textContent).toContain("aus");
    expect(stoveSegment().textContent).toContain("manuell an");
  });

  it("nennt die brennende Stufe", () => {
    render(<ControlsBar state={state({ running: true, power_level: 5 })} />);
    expect(stoveSegment().textContent).toContain("brennt · Stufe 5");
  });

  it("unterscheidet „aus“ von „keine Verbindung“", () => {
    render(<ControlsBar state={state({ running: null, quality: "unavailable" })} />);
    expect(stoveSegment().textContent).toContain("keine Verbindung");
  });

  it("sperrt die Schaltflächen ohne Freigabe und sagt warum", () => {
    render(<ControlsBar state={state({ running: true, control_enabled: false })} />);
    const box = stoveSegment();
    expect(box.textContent).toContain("nicht freigegeben");
    expect(within(box).getByRole("button", { name: "An" })).toBeDisabled();
  });

  it("fragt beim Einschalten erst nach der Dauer", async () => {
    const { api } = await import("@/lib/api/client");
    render(<ControlsBar state={state({ running: false })} />);
    const box = stoveSegment();
    fireEvent.click(within(box).getByRole("button", { name: "An" }));
    expect(api.setStoveMode).not.toHaveBeenCalled();
    expect(within(box).getByText("Ofen an für")).toBeInTheDocument();
    await act(async () => {
      fireEvent.click(within(box).getByRole("button", { name: "2 h" }));
    });
    expect(api.setStoveMode).toHaveBeenCalledWith({ mode: "on", duration_min: 120 });
  });

  it("schaltet mit Auto nichts, sondern gibt nur frei", async () => {
    const { api } = await import("@/lib/api/client");
    render(<ControlsBar state={state({ running: true, mode: "on" })} />);
    await act(async () => {
      fireEvent.click(within(stoveSegment()).getByRole("button", { name: "Auto" }));
    });
    expect(api.setStoveMode).toHaveBeenCalledWith({ mode: "auto", duration_min: 180 });
  });

  it("lässt Gäste sehen, aber nicht schalten", () => {
    render(<ControlsBar state={state({ running: true })} readOnly />);
    const box = stoveSegment();
    expect(box.textContent).toContain("nur Ansicht");
    expect(within(box).getByRole("button", { name: "Aus" })).toBeDisabled();
  });
});
