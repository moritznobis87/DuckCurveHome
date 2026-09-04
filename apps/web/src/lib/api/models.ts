import type { components } from "./types";

type S = components["schemas"];

export type LiveState = S["LiveStateOut"];
export type EnergySnapshot = S["EnergySnapshot"];
export type Measurement = S["Measurement"];
export type BufferState = S["BufferState"];
export type HeatPumpState = S["HeatPumpState"];
export type Decision = S["Decision"];
export type OperatingMode = S["OperatingMode"];
export type Plan = S["PlanOut"];
export type PlanInterval = S["PlanIntervalOut"];
export type PriceWindow = S["PriceWindowOut"];
export type History = S["HistoryOut"];
export type HistoryRow = Record<string, number | string | null>;
export type ActuatorCommandOut = S["ActuatorCommandOut"];
export type HeatPumpModeIn = S["HeatPumpModeIn"];
export type SystemMode = S["SystemMode"];
export type AutoProfile = S["AutoProfile"];
export type Quality = S["Quality"];
