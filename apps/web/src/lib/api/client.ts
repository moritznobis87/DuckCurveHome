import type { ActuatorCommandOut, BatteryLive, BatteryModeIn, Coverage, DoorLog, EnergySummary, HeatBalance, HeatConfigIn, HemsConfig, InvoiceReport, InvoiceSummary, EvReport, ForecastEvaluation, HeatPumpModeIn, HeatReport, History, LiveState, OperatingMode, Period, Plan, PvTaxReport, StoveLive, StorageReport, StoveModeIn, YearMap } from "./models";

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
  // Reiner Text, kein JSON-Umschlag: die Diagnose ist eine Tabelle zum Lesen, keine Datenstruktur.
  diagnoseDay: async (day: string): Promise<string> => {
    const res = await fetch(`/api/dch/energy/diagnose?day=${day}`, { cache: "no-store" });
    if (!res.ok) throw new ApiError("http_error", `Fehler ${res.status}`, res.status);
    return res.text();
  },
  batteryState: () => request<BatteryLive>("/control/battery"),
  setBatteryMode: (body: BatteryModeIn) =>
    request<BatteryLive>("/control/battery/mode", { method: "POST", body: JSON.stringify(body) }),
  plan: () => request<Plan>("/plan"),
  forecastEvaluation: () => request<ForecastEvaluation>("/forecast/evaluation"),
  energySummary: (period: Period, anchor: string) => request<EnergySummary>(`/energy/summary?period=${period}&anchor=${anchor}`),
  energyHeat: (period: Period, anchor: string) => request<HeatReport>(`/energy/heat?period=${period}&anchor=${anchor}`),
  heatBalance: (period: Period, anchor: string) => request<HeatBalance>(`/energy/waermebilanz?period=${period}&anchor=${anchor}`),
  heatConfig: () => request<HemsConfig>("/config"),
  setHeatConfig: (patch: HeatConfigIn) =>
    request<HemsConfig>("/config/heat", { method: "POST", body: JSON.stringify(patch) }),
  energyEv: (period: Period, anchor: string) => request<EvReport>(`/energy/ev?period=${period}&anchor=${anchor}`),
  energyPv: (period: Period, anchor: string) => request<PvTaxReport>(`/energy/pv?period=${period}&anchor=${anchor}`),
  energyYearMap: (year: number) => request<YearMap>(`/energy/year-map?year=${year}`),
  storage: () => request<StorageReport>("/system/storage"),
  coverage: (anchor: string, days: number) => request<Coverage>(`/system/coverage?anchor=${anchor}&days=${days}`),
  doorLog: (days: number) => request<DoorLog>(`/system/door?days=${days}`),
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
