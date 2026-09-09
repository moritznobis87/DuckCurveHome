import type { ActuatorCommandOut, BatteryLive, BatteryModeIn, EnergySummary, InvoiceReport, InvoiceSummary, EvReport, ForecastEvaluation, HeatPumpModeIn, HeatReport, History, LiveState, OperatingMode, Period, Plan, PvTaxReport, StoveLive, StoveModeIn, YearMap } from "./models";

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
  // Minutenwerte eines beliebigen Tages. Ohne das ist der Verlauf nur für heute und gestern zu
  // sehen, und genau der beantwortet die Frage „was ist an diesem Tag wirklich passiert?".
  historyDay: (start: Date, end: Date) =>
    request<History>(`/history?range=custom&start=${encodeURIComponent(start.toISOString())}&end=${encodeURIComponent(end.toISOString())}`),
  batteryState: () => request<BatteryLive>("/control/battery"),
  setBatteryMode: (body: BatteryModeIn) =>
    request<BatteryLive>("/control/battery/mode", { method: "POST", body: JSON.stringify(body) }),
  plan: () => request<Plan>("/plan"),
  forecastEvaluation: () => request<ForecastEvaluation>("/forecast/evaluation"),
  energySummary: (period: Period, anchor: string) => request<EnergySummary>(`/energy/summary?period=${period}&anchor=${anchor}`),
  energyHeat: (period: Period, anchor: string) => request<HeatReport>(`/energy/heat?period=${period}&anchor=${anchor}`),
  energyEv: (period: Period, anchor: string) => request<EvReport>(`/energy/ev?period=${period}&anchor=${anchor}`),
  energyPv: (period: Period, anchor: string) => request<PvTaxReport>(`/energy/pv?period=${period}&anchor=${anchor}`),
  energyYearMap: (year: number) => request<YearMap>(`/energy/year-map?year=${year}`),
  switchActuator: (key: string, state: boolean, durationMin?: number) =>
    request<ActuatorCommandOut>(`/control/actuators/${key}`, {
      method: "POST",
      body: JSON.stringify({ state, duration_min: durationMin ?? null }),
    }),
  setHeatPumpMode: (cmd: HeatPumpModeIn) =>
    request<OperatingMode>("/control/heat-pump/mode", { method: "POST", body: JSON.stringify(cmd) }),
  setStoveMode: (cmd: StoveModeIn) =>
    request<StoveLive>("/control/stove/mode", { method: "POST", body: JSON.stringify(cmd) }),
  tibberInvoices: () => request<InvoiceSummary[]>("/import/tibber-invoices"),
  tibberInvoice: (number: string) => request<InvoiceReport>(`/import/tibber-invoices/${encodeURIComponent(number)}`),
  checkTibberInvoice: (file: File) =>
    request<InvoiceReport>(`/import/tibber-invoice?file_name=${encodeURIComponent(file.name)}`, {
      method: "POST",
      body: file,
      headers: { "content-type": "application/pdf" },
    }),
  demo: (body: Record<string, unknown>) => request<Record<string, unknown>>("/demo", { method: "POST", body: JSON.stringify(body) }),
};
