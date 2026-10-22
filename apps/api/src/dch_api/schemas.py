"""API-Schemas - dort, wo sie vom Domänenmodell abweichen (Transportform)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

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
from hems_core.thermal import CyclingStats, HeatTotals


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
    # Soll der Ofen in diesem Viertelstundenschritt brennen? `None` heißt: kein Fahrplan - weil es
    # keinen Ofen gibt, die Fühler fehlen oder der Optimierer nicht gerechnet hat. Das ist etwas
    # anderes als `False`, und die Oberfläche muss es unterscheiden können.
    planned_stove_on: bool | None = None
    reason_code: str
    note_de: str | None = None


class PlanOut(BaseModel):
    created_at: datetime
    planner: str
    # Wie der Fahrplan zustande kam, nicht nur von wem.
    #
    # Der Optimierer darf abbrechen, wenn seine Zeit um ist, und gibt dann das Beste zurück, was er
    # bis dahin gefunden hat. Das sah von außen aus wie ein fertiger Lauf: dieselbe Datenstruktur,
    # dieselben Zahlen, nur eben ein anderer Fahrplan. Seit er die Wärmepumpe führt, steht hinter
    # diesem Unterschied echte Laufzeit am Relais, also steht er jetzt im Plan.
    planner_status: str = "unavailable"
    planner_note_de: str = ""
    # Leer, solange nichts zu sagen ist. Die Beurteilung steht im Dienst und nicht in der
    # Oberfläche: ob ein Abstand von 5 % erwähnenswert ist, ist eine fachliche Frage.
    planner_warn_de: str = ""
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


class BatteryLiveOut(BaseModel):
    """Der Speicher im Augenblick: sein Ladestand und was DCH mit ihm vorhat.

    `mode` ist die Absicht, `command` der zuletzt an den Libbi gesendete Befehl. Die myenergi-Cloud
    bestätigt nichts; ob das Gerät folgt, sagt erst die nächste Messung. Deshalb stehen beide da.

    `command` kann None sein, und das ist nicht dasselbe wie „normal": es heißt, dass DCH gar nichts
    gesendet hat und der Speicher in seiner eigenen Betriebsart läuft.
    """

    control_enabled: bool = False
    mode: Literal["auto", "normal", "hold", "off"] = "off"
    ends_at: datetime | None = None
    reserve_soc: float = 0.0  # Untergrenze als Anteil; 0 heisst abgeschaltet
    soc: float | None = None
    command: Literal["normal", "stopped"] | None = None
    sent_at: datetime | None = None
    last_error: str | None = None
    note_de: str = ""


class BatteryModeIn(BaseModel):
    """`off` heißt: DCH sendet nichts und lässt dem Speicher seine eigene Regelung."""

    mode: Literal["auto", "normal", "hold", "off"]
    duration_min: int = Field(default=120, ge=15, le=24 * 60)
    # Die Untergrenze lässt sich zusammen mit dem Modus setzen, damit sie nicht in einer YAML-Datei
    # auf dem Server festliegt. None lässt sie, wie sie ist.
    reserve_soc: float | None = Field(default=None, ge=0.0, le=0.5)


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
    # Verbrauch und Kosten: geschätzt aus den Minuten je Leistungsstufe und dem Durchsatz je Stufe.
    # Der Ofen meldet keine Kilogramm, und der Faktor zwischen Schneckendrehzahl und Gewicht ist
    # ungemessen; bis jemand den Sack wiegt, ist das eine belastbare Schätzung und keine Messung.
    pellet_kg: float = 0.0
    pellet_eur: float = 0.0
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


class StorageTableOut(BaseModel):
    """Platzbedarf einer Tabelle: Daten, Indizes, geschätzte Zeilen."""

    name: str
    total_bytes: int
    table_bytes: int
    index_bytes: int
    rows_estimate: int


class StorageReportOut(BaseModel):
    """Womit die Datenbank ihren Platz füllt, und wie lange Rohwerte aufgehoben werden.

    Die Aufbewahrung gehört dazu, weil sie der einzige Regler ist, der von außen gestellt werden
    kann: `measurements_raw` ist ein Durchlauferhitzer für die Verdichtung zu Minutenwerten, alles
    darüber hinaus ist Vorrat für einen Fall, der selten eintritt.
    """

    tables: list[StorageTableOut]
    total_bytes: int
    raw_retention_days: int
    note_de: str


class CoverageSeriesOut(BaseModel):
    """Verfügbarkeit einer Messreihe: je Stunde die Zahl der angekommenen Minuten, plus Kennzahlen.

    `longest_outage_h` zählt nur **vollständig** leere Stunden. Das ist bewusst eine Untergrenze:
    aus Stundenzahlen lässt sich nicht ablesen, ob die fehlenden Minuten einer halb gefüllten Stunde
    zusammenhängen. Eine Zahl, die etwas behauptet, was die Daten nicht hergeben, wäre hier schlimmer
    als eine, die zu klein ist - und die Karte zeigt die Teilstunden ohnehin.
    """

    key: str
    label_de: str
    hours: list[tuple[str, int]]
    coverage: float
    minutes_seen: int
    minutes_expected: int
    incomplete_hours: int
    longest_outage_h: int
    last_at: datetime | None


class CoverageOut(BaseModel):
    start: datetime
    end: datetime
    series: list[CoverageSeriesOut]
    note_de: str


class DoorEntryOut(BaseModel):
    """Ein Zutritt an der Haustür, so wie er im Ereignisprotokoll steht.

    Aufbereitet und nicht roh: die Oberfläche soll eine Zeile zeigen können, ohne selbst zu wissen,
    wie die Zutrittskonsole ihre Felder nennt. Die Übersetzung von „ACCESS" zu „geöffnet" ist an
    der Tür passiert, hier steht das Ergebnis.
    """

    at: datetime
    actor: str
    door: str
    method: str
    outcome: str
    granted: bool
    reason: str


class DoorLogOut(BaseModel):
    entries: list[DoorEntryOut]
    days: int
    note_de: str


class HeatBalancePointOut(BaseModel):
    """Ein Punkt der Wärmebilanz im Zeitverlauf, alle Leistungen thermisch in kW."""

    ts: datetime
    heat_pump_kw: float = 0.0
    stove_water_kw: float = 0.0
    stove_room_kw: float = 0.0
    # `None` heißt: für diese Minute lässt sich über die Entnahme nichts sagen. Eine Lücke in der
    # Kurve ist dafür die richtige Darstellung; eine Null wäre eine Behauptung.
    draw_kw: float | None = None
    loss_kw: float = 0.0
    loss_useful_kw: float = 0.0  # davon dem Aufstellraum zugute
    buffer_change_kw: float = 0.0
    buffer_kwh: float | None = None
    cop: float | None = None


class HeatBucketOut(BaseModel):
    """Ein Balken der Statistik: Stunde, Tag oder Monat, je nach Zeitraum."""

    start: datetime
    label_de: str
    heat_pump_kwh: float = 0.0
    stove_water_kwh: float = 0.0
    stove_room_kwh: float = 0.0
    draw_kwh: float = 0.0
    loss_kwh: float = 0.0
    loss_useful_kwh: float = 0.0
    residual_kwh: float = 0.0
    electric_kwh: float = 0.0
    cop_mean: float | None = None


class HeatParamsOut(BaseModel):
    """Die Annahmen, mit denen gerechnet wurde.

    Sie stehen im Bericht, weil eine gerechnete Wärmemenge ohne ihre Annahmen keine Zahl ist,
    sondern eine Behauptung. Wer sie ändert, ändert jede Zahl auf dieser Seite, auch die von letztem
    Jahr - gespeichert werden Eingänge, nicht Ergebnisse.
    """

    cop_curve: list[tuple[float, float]] = []
    cop_reference_c: float = 0.0  # Senkentemperatur, bei der die Kennlinie gilt
    stove_nominal_heat_kw: float = 0.0
    stove_water_heat_kw: float = 0.0
    stove_min_heat_kw: float = 0.0
    stove_min_water_heat_kw: float = 0.0
    stove_combustion_efficiency: float = 0.0
    pellet_kwh_per_kg: float = 0.0
    pellet_price_eur_per_t: float = 0.0
    buffer_volume_liters: float = 0.0
    buffer_loss_kw_per_k: float = 0.0
    buffer_ambient_c: float = 0.0
    buffer_loss_useful_fraction: float = 0.0
    room_source_de: str = ""


class HeatCostOut(BaseModel):
    """Was die Wärme des Zeitraums gekostet hat, je Erzeuger und je Kilowattstunde.

    **Zwei verschiedene Arten von Kosten**, und sie stehen deshalb getrennt. Der Strom der
    Wärmepumpe ist bezahlt worden, als er floss; zu ihm gehört die entgangene Einspeisevergütung für
    PV-Strom, der stattdessen ins Haus ging. Die Pellets sind bezahlt worden, als sie geliefert
    wurden - hier steht, was die in diesem Zeitraum **verbrannte** Menge zum hinterlegten Preis
    wert war. Das ist kein Kontoauszug, sondern der Vergleichsmaßstab zwischen zwei Erzeugern.
    """

    heat_pump_paid_eur: float = 0.0  # Netzstrom der Wärmepumpe
    heat_pump_opportunity_eur: float = 0.0  # nicht eingespeister PV-Strom
    heat_pump_ct_per_kwh: float | None = None  # je Kilowattstunde Wärme
    stove_kg: float = 0.0  # geschätzt aus den Minuten je Leistungsstufe
    stove_eur: float = 0.0
    stove_ct_per_kwh: float | None = None
    cheaper_de: str = ""


class HeatBalanceOut(BaseModel):
    """Die Wärmeseite eines Zeitraums: wer geliefert hat, was entnommen wurde, was verloren ging."""

    period: Period
    start: datetime
    end: datetime
    resolution_de: str  # woraus gerechnet wurde: Minuten oder Stunden
    totals: HeatTotals
    previous: HeatTotals | None = None
    series: list[HeatBalancePointOut] = []
    buckets: list[HeatBucketOut] = []
    cost: HeatCostOut = HeatCostOut()
    forecast_heat_kwh: float | None = None  # erwarteter Wärmebedarf des Folgetags
    forecast_note_de: str = ""
    params: HeatParamsOut
    note_de: str = ""


class HeatConfigIn(BaseModel):
    """Die Annahmen der Wärmerechnung, soweit sie von Hand zu stellen sind.

    **Teilmenge, kein Abbild der Konfiguration.** Hier stehen nur Werte, die ein Mensch an seiner
    Anlage kennt oder ablesen kann: was auf dem Lieferschein der Pellets steht, was im Datenblatt des
    Ofens steht, wie warm der Puffer gefahren wird. Regelparameter bleiben draußen; sie gehören in
    die Konfigurationsdatei, wo eine falsche Zahl beim Start auffällt und nicht nachts um drei.

    Jedes Feld ist freiwillig: geschickt wird, was geändert wurde, alles andere bleibt stehen.
    """

    cop_curve: list[tuple[float, float]] | None = Field(
        default=None,
        description="Stützpunkte (Außentemperatur °C, COP) der Kennlinie, aufsteigend nach Temperatur",
    )
    buffer_target_temperature_c: float | None = Field(default=None, gt=20.0, lt=95.0)
    buffer_volume_liters: float | None = Field(default=None, gt=50.0, lt=20000.0)
    buffer_loss_kw_per_k: float | None = Field(default=None, ge=0.0, le=1.0)
    buffer_ambient_c: float | None = Field(default=None, gt=-20.0, lt=40.0)
    buffer_loss_useful_fraction: float | None = Field(default=None, ge=0.0, le=1.0)
    indoor_target_c: float | None = Field(default=None, gt=5.0, lt=30.0)
    stove_nominal_heat_kw: float | None = Field(default=None, gt=0.0, lt=100.0)
    stove_water_heat_kw: float | None = Field(default=None, ge=0.0, lt=100.0)
    stove_min_heat_kw: float | None = Field(default=None, gt=0.0, lt=100.0)
    stove_min_water_heat_kw: float | None = Field(default=None, ge=0.0, lt=100.0)
    stove_combustion_efficiency: float | None = Field(default=None, gt=0.3, le=1.0)
    pellet_kwh_per_kg: float | None = Field(default=None, gt=1.0, lt=10.0)
    pellet_price_eur_per_t: float | None = Field(default=None, ge=0.0, lt=5000.0)

    @field_validator("cop_curve")
    @classmethod
    def _kennlinie(cls, v: list[tuple[float, float]] | None) -> list[tuple[float, float]] | None:
        """Eine Kennlinie mit einem Punkt ist eine Konstante, eine mit Sprüngen eine Falle."""
        if v is None:
            return v
        if not 2 <= len(v) <= 10:
            raise ValueError("Die Kennlinie braucht zwischen zwei und zehn Stützpunkten.")
        temps = [t for t, _ in v]
        if temps != sorted(temps) or len(set(temps)) != len(temps):
            raise ValueError("Die Außentemperaturen müssen aufsteigend und verschieden sein.")
        if any(c <= 0.5 or c > 10.0 for _, c in v):
            raise ValueError("Eine Arbeitszahl liegt zwischen 0,5 und 10.")
        return v


# ------------------------------------------------------------------ Einzelraumregelung


class RoomLiveOut(BaseModel):
    """Ein Raum im Augenblick.

    `deviation_k` wird hier gerechnet und nicht in der Anzeige, weil zur Abweichung die Frage
    gehört, auf welchen Wert sie sich bezieht - und die ist entschieden: auf `target_c`, den
    Sollwert **plus** Offset. Contromes Oberfläche rechnet es selbst vor (`21,00 - 0,32` über
    `20,68`). `setpoint_c` und `offset_k` stehen weiter einzeln daneben, damit die Rechnung
    nachvollziehbar bleibt und ein falsches Vorzeichen auffällt.

    **Jedes Feld ist angegeben, keines hat eine Voreinstellung.** Das ist keine Pedanterie: Aus den
    Voreinstellungen wird in der erzeugten Schnittstellenbeschreibung „darf fehlen", und in der App
    heißt das für jede Zahl eine zweite Möglichkeit neben `null` - undefiniert -, die dasselbe
    bedeutet und trotzdem überall mitgeprüft werden müsste.
    """

    id: int
    name: str
    floor: str
    circuits: int
    temp_c: float | None
    setpoint_c: float | None
    offset_k: float | None
    # Worauf geregelt wird: `setpoint_c` + `offset_k`. Eigenes Feld, damit die Anzeige nicht
    # rechnet - und damit sichtbar bleibt, aus welchen zwei Zahlen es entstanden ist.
    target_c: float | None
    humidity_pct: float | None
    # Anteil der offenen Heizkreise, 0 bis 1. Die Antriebe kennen keine Zwischenstellung, der
    # Anteil entsteht aus der Zahl der Kreise: 0,25 heißt „einer von vier".
    valve: float | None
    deviation_k: float | None
    observed_at: datetime | None
    quality: Quality


class RoomsLiveOut(BaseModel):
    at: datetime
    # Falsch, solange die Brücke noch kein `rooms.list` geschickt hat: dann stehen hier Messwerte
    # unter Ersatznamen („Raum 5"), und die Anzeige soll sagen können, warum.
    named: bool
    rooms: list[RoomLiveOut]


class RoomSeriesOut(BaseModel):
    """Eine Raumzeitreihe spaltenweise: alle Listen so lang wie `ts` der Hülle."""

    id: int
    name: str
    floor: str
    circuits: int
    temp_c: list[float | None]
    setpoint_c: list[float | None]
    offset_k: list[float | None]
    valve: list[float | None]


class RoomHistoryOut(BaseModel):
    start: datetime
    end: datetime
    step_min: int
    ts: list[datetime]
    rooms: list[RoomSeriesOut]
