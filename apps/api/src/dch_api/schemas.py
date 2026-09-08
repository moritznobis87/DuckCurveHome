"""API-Schemas - dort, wo sie vom Domänenmodell abweichen (Transportform)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field

from dch_api.application.tibber_invoice import InvoiceFinding, MeasuredPeriod, TibberInvoice
from hems_core.accounting import EnergyTotals, HeatForecastPoint, PvTaxTotals
from hems_core.domain import (
    AutoProfile,
    BufferState,
    Decision,
    EnergySnapshot,
    HeatPumpState,
    OperatingMode,
    Quality,
    SystemMode,
)
from hems_core.forecasting import CorrectorState, ForecastScore
from hems_core.thermal import CyclingStats


class PriceWindowOut(BaseModel):
    start: datetime
    end: datetime
    kind: Literal["cheap", "expensive", "negative", "pv_surplus"]
    avg_ct_kwh: float | None = None
    label_de: str


class PlanIntervalOut(BaseModel):
    ts: datetime
    expected_pv_kw: float
    price_ct_kwh: float | None
    planned_hp_state: Literal["off", "release", "free", "avoid"]
    reason_code: str
    note_de: str | None = None


class PlanOut(BaseModel):
    created_at: datetime
    planner: str
    horizon_start: datetime
    horizon_end: datetime
    windows: list[PriceWindowOut]
    intervals: list[PlanIntervalOut]
    pv_forecast_today_kwh: float
    next_cheap_window: PriceWindowOut | None


class InvoiceReportOut(BaseModel):
    """Ergebnis einer Rechnungsprüfung: gelesene Rechnung, Befunde, Ampel und der Vergleichswert."""

    invoice: TibberInvoice
    findings: list[InvoiceFinding]
    verdict: str
    measured: MeasuredPeriod | None = None
    checked_at: datetime
    file_name: str | None = None
    already_known: bool = False


class InvoiceSummaryOut(BaseModel):
    """Eine Zeile im Rechnungsverlauf."""

    number: str
    period_label: str
    period_start: date
    period_end: date
    issued_on: date
    kwh: float
    measured_kwh: float | None = None
    measured_avg_ct_kwh: float | None = None  # aus unseren Tibber-Preisen und dem eigenen Bezug
    coverage: float | None = None
    total_net_eur: float
    total_gross_eur: float
    avg_ct_kwh_gross: float
    energy_net_eur: float
    fees_net_eur: float
    verdict: str
    problems: int
    checked_at: datetime


class SystemEventOut(BaseModel):
    at: datetime
    severity: str
    code: str
    message: str
    context: dict[str, object] = Field(default_factory=dict)


class BackfillResultOut(BaseModel):
    """Ergebnis eines manuell angestoßenen myenergi-Historienabrufs."""

    ok: bool
    readings: int = 0
    start: datetime | None = None
    end: datetime | None = None
    error_de: str | None = None
    price_note_de: str | None = (
        None  # Ergebnis des Tibber-Preisabgleichs für die nachgetragenen Minuten
    )


class SourceStatusOut(BaseModel):
    """Zustand einer Messquelle (Bridge, myenergi, …)."""

    name: str
    online: bool
    last_ok: datetime | None = None
    detail_de: str = ""


class SystemStatusOut(BaseModel):
    mode: str
    server_time: datetime
    sim_speed: float
    bridge_online: bool
    sse_clients: int
    version: str
    connection_label_de: str
    sources: list[SourceStatusOut] = Field(default_factory=list)


class StoveLiveOut(BaseModel):
    """Der Pelletofen im Augenblick: was er tut und ob DCH ihn schalten darf.

    Zwei Dinge sind hier bewusst getrennt. `running` ist eine **Beobachtung** aus dem Maestro-Modul;
    `mode` ist eine **Absicht** des Bedienenden. Beide können auseinanderlaufen: ein Ofen braucht
    Minuten zum Zünden und noch mehr zum Ausbrennen, und in dieser Zeit sagt die Oberfläche „an"
    (gewollt) und „läuft nicht" (gemessen) zugleich. Genau das soll sie auch.

    `control_enabled` ist die Freigabe aus der Konfiguration. Ist sie aus, zeigt die Leiste den Ofen
    weiterhin an, aber ohne Schaltflächen: eine Feuerstätte fernzustarten gehört nicht zu den
    Dingen, die standardmäßig eingeschaltet sind.
    """

    present: bool = False
    control_enabled: bool = False
    mode: Literal["auto", "on", "off"] = "auto"
    ends_at: datetime | None = None  # Ende eines manuellen Eingriffs
    running: bool | None = None
    power_level: float | None = None
    fume_temp_c: float | None = None
    boiler_temp_c: float | None = None
    observed_at: datetime | None = None
    quality: Quality = Quality.UNAVAILABLE
    # Der Fahrplan des Optimierers. `planned_on` ist das, was DCH im Modus `auto` von sich aus tut;
    # `None` heißt: es liegt kein Fahrplan vor, und dann schaltet DCH auch nichts.
    planned_on: bool | None = None
    plan_until: datetime | None = None
    plan_note_de: str = ""
    note_de: str = ""


class StoveModeIn(BaseModel):
    """`auto` heißt: DCH schaltet nicht und überlässt dem Ofen seine eigene Regelung."""

    mode: Literal["auto", "on", "off"]
    duration_min: int = Field(default=180, ge=15, le=24 * 60)


class LiveStateOut(BaseModel):
    snapshot: EnergySnapshot
    buffer: BufferState
    heat_pump: HeatPumpState
    decision: Decision | None
    operating_mode: OperatingMode
    stove: StoveLiveOut = StoveLiveOut()
    price_rank: float | None
    today_kwh: dict[str, float]
    system: SystemStatusOut


class HistoryOut(BaseModel):
    start: datetime
    end: datetime
    resolution_s: int = 60
    rows: list[dict[str, float | str | None]]


class ActuatorCommandIn(BaseModel):
    state: bool
    duration_min: int | None = Field(default=None, ge=1, le=24 * 60)


class ActuatorCommandOut(BaseModel):
    key: str
    requested: bool
    observed: bool | None
    ok: bool
    message_de: str


class HeatPumpModeIn(BaseModel):
    system_mode: SystemMode
    auto_profile: AutoProfile | None = None
    manual_state: Literal["on", "off"] | None = None
    duration_min: int = Field(default=120, ge=5, le=12 * 60)


class DemoControlIn(BaseModel):
    speed: float | None = Field(default=None, ge=0.0, le=3600.0)
    fault_key: str | None = None
    fault_quality: Literal["stale", "unavailable", "unknown"] | None = None
    fault_duration_s: int | None = Field(default=None, ge=1, le=86400)
    scenario: (
        Literal["reset", "sunny_surplus", "cold_evening", "buffer_full", "sensor_outage"] | None
    ) = None


class ErrorOut(BaseModel):
    error: dict[str, object]


# ----------------------------------------------------------------------------- Prognose-Auswertung


class ForecastPointOut(BaseModel):
    ts: datetime
    actual_kw: float | None
    day_ahead_kw: float | None  # Prognose, die um 06:00 für den Tag vorlag
    latest_kw: float | None  # jüngster Lauf, unkorrigiert
    corrected_kw: float | None  # jüngster Lauf mit den heutigen Korrekturfaktoren


class ForecastDayOut(BaseModel):
    day: date
    issued_at: datetime | None
    score: ForecastScore | None  # Day-ahead gegen Ist, bis jetzt
    points: list[ForecastPointOut]


class DailyScoreOut(BaseModel):
    day: date
    energy_forecast_kwh: float
    energy_actual_kwh: float
    energy_error_pct: float | None
    mae_kw: float
    bias_kw: float
    k_global_after: float
    issued_at: datetime | None = None


class HorizonScoreOut(BaseModel):
    key: str
    label_de: str
    score: ForecastScore


class SourceOut(BaseModel):
    name: str
    label_de: str
    weight: float
    mae_7d_kw: float | None
    active: bool


class ForecastEvaluationOut(BaseModel):
    generated_at: datetime
    stage_de: str
    sources: list[SourceOut]
    today: ForecastDayOut
    yesterday: ForecastDayOut
    daily: list[DailyScoreOut]
    horizons: list[HorizonScoreOut]
    corrector: CorrectorState
    correction_active: bool
    next_changes_de: list[str]
    runs_kept: int
    notes_de: list[str]


# ----------------------------------------------------------------------------- Energiebilanz

Period = Literal["day", "week", "month", "year"]


class EnergyTotalsOut(EnergyTotals):
    """Summen plus abgeleitete Kennzahlen als normale Felder (für JSON)."""

    autarky: float | None = None
    self_consumption_share: float | None = None
    avg_import_price_ct: float | None = None

    @classmethod
    def from_totals(cls, t: EnergyTotals) -> EnergyTotalsOut:
        return cls(
            **t.model_dump(),
            autarky=t.autarky,
            self_consumption_share=t.self_consumption_share,
            avg_import_price_ct=t.avg_import_price_ct,
        )


class EnergyBucketOut(BaseModel):
    start: datetime
    end: datetime
    label: str  # z. B. "14:00", "Mo 02.09.", "Sep"
    totals: EnergyTotalsOut


class EnergyMetaOut(BaseModel):
    battery_capacity_kwh: float
    feed_in_ct_kwh: float
    data_since: datetime | None
    coverage: float | None  # bewertete Minuten / Minuten des Zeitraums (bis jetzt)
    estimated_note_de: str


class EnergySummaryOut(BaseModel):
    period: Period
    anchor: date
    start: datetime
    end: datetime
    totals: EnergyTotalsOut
    buckets: list[EnergyBucketOut]
    meta: EnergyMetaOut


class PvTaxMetaOut(BaseModel):
    """Was die Zahlen der Abrechnung bedingt - gehört sichtbar zur Auswertung, nicht ins Kleingedruckte."""

    feed_in_ct_kwh: float  # Nettosatz laut Bescheid
    vat_rate: float
    small_business: bool
    prices_include_vat: bool
    data_since: datetime | None
    coverage: float | None  # bewertete Minuten / Minuten des Zeitraums
    battery_capacity_kwh: float
    method_de: str


class PvTaxBucketOut(BaseModel):
    start: datetime
    end: datetime
    label: str
    totals: PvTaxTotals


class PvTaxReportOut(BaseModel):
    """PV-Abrechnung eines Zeitraums: Einspeisung, Eigenverbrauch, Umsatzsteuer."""

    period: Period
    anchor: date
    start: datetime
    end: datetime
    totals: PvTaxTotals
    buckets: list[PvTaxBucketOut]
    meta: PvTaxMetaOut


YearMetric = Literal[
    "pv_kwh",
    "house_kwh",
    "import_kwh",
    "export_kwh",
    "grid_net_kwh",
    "heat_pump_kwh",
    "price_ct_kwh",
    "autarky",
]


class YearMapOut(BaseModel):
    """Ein Kalenderjahr als Tag × Stunde: 365 Spalten, 24 Zeilen, je Kennzahl eine Fläche.

    Die Stunde ist Ortszeit, nicht UTC - sonst wanderte die Sonne im Bild um eine Stunde, sobald die
    Zeitumstellung kommt. `null` heißt „keine Messdaten", nicht „null Kilowattstunden"; beides zu
    unterscheiden ist der halbe Nutzen der Darstellung.
    """

    year: int
    days: list[date]  # Spaltenachse, ein Eintrag je Kalendertag
    metrics: dict[str, list[list[float | None]]]  # Kennzahl → [Tag][Stunde 0-23]
    hours_with_data: int
    data_since: datetime | None


class PriceQualityOut(BaseModel):
    """Lief die Wärmepumpe zur richtigen Zeit? Ergebnis statt Regeltreue.

    Verglichen wird, was der Wärmepumpenstrom aus dem Netz gekostet hat, mit dem, was der Bezug des
    ganzen Hauses im selben Zeitraum im Mittel kostete. Liegt der erste darunter, hat die Steuerung
    gewirkt - unabhängig davon, ob sie jedes geplante Fenster genau getroffen hat.
    """

    hp_grid_price_ct: float | None = None  # Mittelpreis des WP-Netzbezugs
    house_grid_price_ct: float | None = None  # Mittelpreis des Hausbezugs
    advantage_ct: float | None = None  # Differenz; positiv = günstiger als der Durchschnitt
    cheap_share: float | None = None  # Anteil der WP-Energie in den günstigsten 25 % der Stunden
    pv_share: float | None = None  # Anteil der WP-Energie aus eigener PV
    hours_ranked: int = 0
    note_de: str = ""


class BufferBalanceOut(BaseModel):
    """Energiebilanz des Puffers am Ankertag, aus den vier Fühlern gerechnet.

    Die Änderung des Energieinhalts ist die Nettoleistung des Speichers. Wer sie verursacht hat, war
    bis zur Anbindung des Ofens eine Schlussfolgerung: steigt der Inhalt, während die Wärmepumpe
    steht, muss die Wärme von woanders kommen. Mit den Maestro-Daten ist es eine Feststellung, und
    `gain_unexplained_kwh` bleibt für das übrig, was wirklich niemand erklärt.
    """

    energy_start_kwh: float | None = None
    energy_end_kwh: float | None = None
    gain_kwh: float = 0.0  # Summe aller Zunahmen
    drop_kwh: float = 0.0  # Summe aller Abnahmen (Entnahme und Verluste)
    gain_with_hp_kwh: float = 0.0
    gain_without_hp_kwh: float = 0.0  # ohne laufende Wärmepumpe, gleich ob Ofen bekannt oder nicht
    gain_with_stove_kwh: float = 0.0  # gemessen: der Ofen lief
    gain_unexplained_kwh: float = 0.0  # weder Wärmepumpe noch Ofen: Rest, Messfehler, Schichtung
    stove_known: bool = False  # lagen für den Zeitraum überhaupt Ofendaten vor
    samples: int = 0
    note_de: str = ""


class StoveOut(BaseModel):
    """Der Pelletofen im Zeitraum. `available=False` heißt: keine Daten, nicht „lief nicht"."""

    available: bool = False
    running_minutes: int = 0
    burning_minutes: int = 0
    runs: int = 0
    longest_run_min: int | None = None
    auger_revolutions: float = 0.0  # Brennstoffeintrag, relativ; siehe fuel_note_de
    fume_temp_max_c: float | None = None
    spread_k: float | None = None
    pumping_minutes: int = 0
    dhw_minutes: int = 0
    minutes_by_level: dict[str, int] = {}
    operating_hours: float | None = None  # Zählerstand des Geräts, monoton
    ignitions: int | None = None
    note_de: str = ""
    fuel_note_de: str = ""


class HeatReportOut(BaseModel):
    summary: EnergySummaryOut
    thermal_kwh_est: float  # gelieferte Wärme aus Strom × COP (Schätzung)
    cop_est: float
    forecast: list[HeatForecastPoint]  # nächste 48 h
    forecast_electric_kwh_24h: float
    forecast_thermal_kwh_24h: float
    buffer_series: list[
        dict[str, float | str | None]
    ]  # Puffertemperaturen des Ankertags (Minutenmittel)
    heat_loss_kw_per_k: float
    cycling: CyclingStats
    price_quality: PriceQualityOut
    buffer_balance: BufferBalanceOut
    stove: StoveOut
    model_note_de: str


class EvSessionOut(BaseModel):
    start: datetime
    end: datetime
    kwh: float
    pv_share: float | None  # Anteil aus PV (direkt) am Ladevorgang
    grid_kwh: float
    cost_eur: float
    avg_kw: float


class EvReportOut(BaseModel):
    summary: EnergySummaryOut
    sessions: list[EvSessionOut]  # Ladevorgänge im Zeitraum (nur Tag/Woche)
