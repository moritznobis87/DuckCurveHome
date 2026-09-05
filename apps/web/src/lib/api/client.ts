import type { ActuatorCommandOut, ForecastEvaluation, HeatPumpModeIn, History, LiveState, OperatingMode, Plan } from "./models";

export class ApiError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status: number,
    public readonly details?: unknown,
  ) {
    super(message);
  }
}

const BASE = "/api/dch";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${BASE}${path}`, {
      ...init,
      headers: { "content-type": "application/json", ...(init?.headers ?? {}) },
      cache: "no-store",
    });
  } catch (e) {
    throw new ApiError("network", "Keine Verbindung zum Backend.", 0, e);
  }
  if (!res.ok) {
    let code = "http_error";
    let message = `Fehler ${res.status}`;
    let details: unknown;
    try {
      const body = (await res.json()) as { error?: { code?: string; message?: string; details?: unknown } };
      code = body.error?.code ?? code;
      message = body.error?.message ?? message;
      details = body.error?.details;
    } catch {
      /* kein JSON-Envelope */
    }
    throw new ApiError(code, message, res.status, details);
  }
  return (await res.json()) as T;
}

export const api = {
  liveState: () => request<LiveState>("/live/state"),
  history: (range: "today" | "yesterday" | "24h") => request<History>(`/history?range=${range}`),
  plan: () => request<Plan>("/plan"),
  forecastEvaluation: () => request<ForecastEvaluation>("/forecast/evaluation"),
  switchActuator: (key: string, state: boolean, durationMin?: number) =>
    request<ActuatorCommandOut>(`/control/actuators/${key}`, {
      method: "POST",
      body: JSON.stringify({ state, duration_min: durationMin ?? null }),
    }),
  setHeatPumpMode: (cmd: HeatPumpModeIn) =>
    request<OperatingMode>("/control/heat-pump/mode", { method: "POST", body: JSON.stringify(cmd) }),
  demo: (body: Record<string, unknown>) => request<Record<string, unknown>>("/demo", { method: "POST", body: JSON.stringify(body) }),
};
