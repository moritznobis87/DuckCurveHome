"""API-Schemas - dort, wo sie vom Domänenmodell abweichen (Transportform)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator

from dch_api.application import rooms as rooms_logic
from dch_api.application.tibber_invoice import InvoiceFinding, MeasuredPeriod, TibberInvoice
from hems_core.accounting import EnergyTotals, HeatForecastPoint, PvTaxTotals
from hems_core.accounting.nachbetrachtung import Nachbetrachtung
from hems_core.domain import (
    AutoProfile,
    BufferState,
    Decision,
    EnergySnapshot,
    HeatPumpState,
    Measurement,
    OperatingMode,
    Quality,
    SystemMode,
)
from hems_core.forecasting import CorrectorState, ForecastScore
from hems_core.forecasting.rueckblick import ReiheOut
from hems_core.house import HousePlan
from hems_core.regelkreis.karte import Regelkreiskarte
from hems_core.thermal import CyclingStats, HeatTotals
from hems_core.thermal.kontaktwirkung import Kontaktwirkung


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
    # Die Modelleingänge dieses Schritts. `None` heißt: es wurde nicht geplant - kein Solver, keine
    # Preise, blinde Puffersensoren oder außerhalb des Planungshorizonts. Das ist etwas anderes als
    # eine Null, und die Oberfläche muss es unterscheiden können: eine Lücke in der Kurve ist
    # ehrlicher als eine Linie auf dem Boden.
    #
    # Getrennt nach Heizen und Warmwasser, weil die beiden sich verschieden verhalten: das Heizen
    # hängt an der Außentemperatur, das Warmwasser am Tagesprofil. Gestapelt ergeben sie den
    # Wärmebedarf, gegen den der Fahrplan rechnet.
    heat_demand_kw: float | None = None
    dhw_demand_kw: float | None = None
    # Der geplante nutzbare Pufferinhalt am **Ende** des Schritts, aus derselben Bilanz wie der
    # Fahrplan selbst. Er ist das Bindeglied: er erklärt, warum eine teure Stunde ohne Anforderung
    # bleiben darf und eine billige angefordert wird.
    buffer_kwh: float | None = None
    outdoor_temp_c: float | None = None
    # Die Arbeitszahl, mit der der Optimierer in diesem Schritt gerechnet hat. Sie folgt aus der
    # Außentemperatur und ist der zweite Grund, warum die Morgenstunden teuer sind: hoher Preis
    # **und** schlechter COP.
    cop: float | None = None
    # Was der Optimierer fuer diesen Schritt an Kosten gezaehlt hat: Strom der Waermepumpe und
    # Ofen, ohne Strafterme. `None`, wo er nicht gerechnet hat. Das Versprechen des Fahrplans;
    # es wird mit ihm aufbewahrt, und die Nachbetrachtung haelt den eingetretenen Tag dagegen.
    planned_cost_eur: float | None = None
    # Dieselbe Viertelstunde nach dem, wofuer das Geld ausgegeben wird: der Strom der
    # Waermepumpe und die Pellets, die der Ofen verbrennt, zum eingetragenen Pelletpreis. Die
    # Summe ist nicht `planned_cost_eur`: dort zaehlt der Ofen mit Eigenstrom und abzueglich der
    # angerechneten Raumwaerme. Fuer das Morning Briefing.
    planned_hp_cost_eur: float | None = None
    planned_pellet_cost_eur: float | None = None
    # ---------------------------------------------------------------- Was wirklich geschah
    #
    # Der Fahrplan beginnt an der Ortsmitternacht und reicht zwei Tage. Mittags liegt also die
    # Hälfte der Zeichnung in der **Vergangenheit**, und dort stand bis zum 08.11.2026 trotzdem
    # nur die Absicht: die PV-Erwartung und der Zustand, den die Regel für diese Stunde ausgibt,
    # wenn man sie heute noch einmal fragt. Was die Anlage in dieser Viertelstunde wirklich
    # erzeugte und zog, war auf der Seite nirgends zu sehen.
    #
    # `None` heißt hier wie überall in diesem Modell: **keine Messung**. Entweder liegt die
    # Viertelstunde in der Zukunft, oder sie ist noch nicht zu Ende, oder der Fühler schwieg. Eine
    # Null wäre die Behauptung, die Anlage habe gestanden.
    actual_pv_kw: float | None = None
    actual_hp_kw: float | None = None
    # War der Freigabekontakt K1 in dieser Viertelstunde überwiegend geschlossen?
    #
    # Das ist nicht dasselbe wie `actual_hp_kw > 0`, und der Unterschied ist der Kern der ganzen
    # Wärmeseite: K1 ist eine **Anforderung** und keine Sperre. Die Maschine entscheidet nach
    # ihrer eigenen Kennlinie, ob sie folgt. Beide Reihen nebeneinander zeigen zum ersten Mal, was
    # eine Anforderung auslöst - die Frage, die der Projektplan seit September offen führt.
    actual_hp_release: bool | None = None
    # Minuten dieser Viertelstunde, in denen der Verdichter lief, gezaehlt je Minute gegen
    # `heat_pump.running_threshold_kw`. Nicht dasselbe wie `actual_hp_kw > 0`: die Anlage zieht
    # auch im Stillstand Strom (Umwaelzpumpe, Elektronik), und ein Viertelstundenmittel von 1 kW
    # kann fuenf Minuten Lauf bei 3 kW sein. Die Kachel "gelaufen" summiert diese Minuten.
    actual_hp_run_min: float | None = None


class SunDayOut(BaseModel):
    """Sonnenaufgang und Sonnenuntergang eines Tages am Standort des Hauses."""

    day: date
    sunrise: datetime
    sunset: datetime


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
    # Erreicht `planned_hp_state == "release"` wirklich einen Kontakt, oder ist es eine Anforderung
    # an niemanden?
    #
    # **Dieselbe Zahl steht auch in `SystemStatusOut.hp_actuation`, und das ist Absicht.** Dort ist
    # sie der Zustand der Anlage, hier die Einschränkung einer Behauptung: die Seite „Fahrplan"
    # sagt „Wärmepumpe angefordert 9,8 h", und ohne dieses Feld sähe eine Anforderung an niemanden
    # genauso aus wie eine, die ankommt. Sie hier nachzuschlagen kostet eine zweite Abfrage je
    # Minute für ein Wahrheitswort; die Verdopplung ist der kleinere Preis.
    hp_actuation: bool = False
    horizon_start: datetime
    horizon_end: datetime
    windows: list[PriceWindowOut]
    intervals: list[PlanIntervalOut]
    pv_forecast_today_kwh: float
    next_cheap_window: PriceWindowOut | None
    # Die Ränder des Puffers, damit `buffer_kwh` einen Maßstab hat. `None`, solange nicht geplant
    # wurde; die Kapazität hängt am Zustand des Behälters, nicht an der Einstellung.
    buffer_capacity_kwh: float | None = None
    buffer_min_kwh: float | None = None
    # Aufgang und Untergang der Sonne für die beiden Tage des Horizonts, gerechnet aus Datum und
    # Standort (`hems_core.forecasting.sonne`).
    #
    # **Nicht dasselbe wie die erste und letzte Viertelstunde mit `expected_pv_kw`.** Die
    # Oberfläche las den Sonnenlauf bis zum 26.11.2026 dort ab und zeichnete die Sonne um 09:17
    # an den Horizont, obwohl sie seit 08:09 am Himmel stand: die Erzeugung beginnt später, als
    # die Sonne aufgeht, und endet früher. Leer, solange der Dienst den Standort nicht kennt.
    sun: list[SunDayOut] = Field(default_factory=list)


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


class WatchFindingOut(BaseModel):
    """Ein Befund des Wächters: Dieses Signal schweigt, seit wann, und was deshalb fehlt.

    Die Regeln stehen in `hems_core.watch`; hier ist nur die Form für die Oberfläche. Der Text ist
    ein ganzer Satz, weil er auch als Mitteilung auf einem Telefon landet, wo niemand aus
    `name` und `silent_min` etwas zusammensetzen kann.
    """

    name: str
    title_de: str
    severity: Literal["warn", "alarm"]
    since: datetime | None = None
    silent_min: float
    text_de: str


class SystemStatusOut(BaseModel):
    mode: str
    server_time: datetime
    sim_speed: float
    bridge_online: bool
    sse_clients: int
    version: str
    connection_label_de: str
    sources: list[SourceStatusOut] = Field(default_factory=list)
    #: Was gerade schweigt. Leer ist der Normalfall und bedeutet: Alles meldet sich.
    watch: list[WatchFindingOut] = Field(default_factory=list)
    #: Die Außentemperatur, die die Oberfläche zeigen soll, nach der Gegenprobe gegen den
    #: Wetterdienst (`hems_core.watch.aussen`). `outdoor_source_de` ist leer, wenn das der
    #: Messwert ist, und nennt sonst die Quelle, die an seine Stelle tritt. `None`: keine Prüfung
    #: (Vorführung); dann gilt der Messwert aus dem Snapshot.
    outdoor_shown_c: float | None = None
    outdoor_source_de: str = ""
    #: Stellt DCH den Wärmepumpen-Kontakt K1 selbst, oder liest es ihn nur mit?
    #
    #: **Warum das nach außen gehört.** Der Zustand stand bis zum 09.11.2026 in keinem Schema und
    #: in keiner Antwort, nur in einer Logzeile beim Start. Die Oberfläche sagte „Wärmepumpe
    #: angefordert 9,8 h", ob der Kontakt gestellt wurde oder nicht - eine Anforderung an niemanden
    #: sieht genauso aus wie eine, die ankommt. Wer den Schalter umlegt, bekam keine Bestätigung;
    #: wer ihn vergisst, keinen Hinweis.
    #:
    #: `False` heißt Schattenbetrieb: der Regler entscheidet, die Entscheidung wird abgelegt und
    #: angezeigt, der Kontakt bleibt unberührt und die Wärmepumpe läuft in ihrer eigenen Regelung.
    hp_actuation: bool = False
    #: Derselbe Zustand als Satz, damit die Oberfläche ihn nicht selbst formulieren muss.
    hp_actuation_de: str = "wird nur beobachtet"


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


class AlarmOut(BaseModel):
    """Die Alarmanlage, so weit sie dieses Werkzeug angeht.

    **Scharf ja, unscharf nein.** Die Anzeige hängt in der Küche, Gäste gehen daran vorbei, und
    ihr Zugang ist ein Sitzungskeks auf einem Gerät - schwächer als ein Code am Bedienteil.
    Deshalb kennt diese Schnittstelle nur das Schärfen. Wer entschärfen will, tut es dort, wo es
    hingehört, und `can_arm` sagt, ob überhaupt geschaltet werden darf.
    """

    present: bool
    # 0 unscharf, 1 zu Hause scharf, 2 unterwegs scharf, 3 schaltet gerade, 4 ausgelöst.
    state: float | None
    state_de: str
    can_arm: bool
    observed_at: datetime | None


class LiveStateOut(BaseModel):
    snapshot: EnergySnapshot
    buffer: BufferState
    heat_pump: HeatPumpState
    decision: Decision | None
    operating_mode: OperatingMode
    stove: StoveLiveOut = StoveLiveOut()
    price_rank: float | None
    today_kwh: dict[str, float]
    alarm: AlarmOut = AlarmOut(
        present=False, state=None, state_de="nicht eingerichtet", can_arm=False, observed_at=None
    )
    system: SystemStatusOut


class HouseContactOut(BaseModel):
    """Ein Kontakt des Hausplans im Augenblick. `open` ist `None`, wenn nichts Frisches vorliegt:
    nicht zugeordnet, noch nie gemeldet oder seit einer halben Stunde still."""

    key: str
    name: str
    room: str | None
    door: bool
    open: bool | None
    observed_at: datetime | None
    quality: Quality


class HouseOut(BaseModel):
    """Der Hausplan fuer die Modellansicht, samt dem Zustand seiner Kontakte.

    `present` ist falsch, solange keine Bruecke einen Plan gemeldet hat oder der letzte gemeldete
    nicht lesbar war; dann steht der Grund in `error_de`. Der Plan selbst ist Geometrie, keine
    Messung: Raeume verweisen ueber `room_id` auf die Einzelraumregelung, Kontakte ueber `key`
    auf die Entity-Zuordnung. Was zu welchem Raum gehoert, entscheidet die Datei des Hauses.
    """

    at: datetime
    present: bool
    plan: HousePlan | None
    source_de: str
    received_at: datetime | None
    error_de: str
    contacts: list[HouseContactOut]


class HistoryOut(BaseModel):
    start: datetime
    end: datetime
    resolution_s: int = 60
    rows: list[dict[str, float | str | None]]


class AlarmArmIn(BaseModel):
    mode: Literal["home", "away"]


class AlarmArmOut(BaseModel):
    ok: bool
    alarm: AlarmOut
    message_de: str


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


class ForecastHistoryOut(BaseModel):
    """Der Rückblick aus dem dauerhaften Archiv: Fehler je Reihe und je Vorlaufzeit.

    Etwas anderes als `ForecastEvaluationOut`: dort steht, was der Bewerter im Arbeitsspeicher hält
    (PV, gestern und heute), hier, was in `forecast_runs` liegt - mehrere Tage, und auch die
    Außentemperatur, an der im Modell v1 der ganze Wärmebedarf hängt.
    """

    generated_at: datetime
    von: datetime
    bis: datetime
    tage: int
    reihen: list[ReiheOut]
    hinweise_de: list[str]


# ----------------------------------------------------------------------------- Energiebilanz

Period = Literal["day", "week", "month", "year"]


class BerichtMitStand(BaseModel):
    """Eine Auswertung, die mitteilt, wann sie gerechnet wurde.

    **Weil sie nicht mehr in jedem Fall jetzt gerechnet wird.** Die Auswertungen der Zeiträume
    liegen seit dem 22.11.2026 in einem Zwischenspeicher
    (`dch_api.application.berichtsspeicher`): ein abgeschlossener Zeitraum bleibt dauerhaft
    liegen, der laufende eine Minute. Eine Zahl aus dem Speicher, die aussieht wie eine von
    jetzt, ist eine stille Lüge - auf einer Wandanzeige, die wochenlang läuft, besonders. Hier
    steht also nicht die Uhrzeit der Anfrage, sondern die der **Rechnung**, und bei einem
    Treffer ist das ein Zeitpunkt in der Vergangenheit.

    **Der Name ist nicht neu erfunden.** Die Vorlage kennt dieses Feld schon und nennt es
    `generated_at`; angezeigt wird es dort als „Stand 14:35“
    (`apps/web/src/components/forecast/ForecastPage.tsx` über `ForecastEvaluationOut`). Ein
    zweiter Name für dieselbe Sache wäre eine Fehlerquelle ohne Gegenwert.
    """

    #: Wann diese Antwort gerechnet wurde - nicht, wann sie abgeholt wurde.
    generated_at: datetime


class EnergyTotalsOut(EnergyTotals):
    """Summen plus abgeleitete Kennzahlen als normale Felder (für JSON)."""

    autarky: float | None = None
    self_consumption_share: float | None = None
    avg_import_price_ct: float | None = None
    #: Nutzen des Speichers nach Abzug dessen, was das Fuellen gekostet hat. Die Anzeige rechnet
    #: ihn nicht selbst: Eine Differenz zweier Betraege in der Oberflaeche waere eine zweite
    #: Definition neben der hier, und zwei Definitionen gehen irgendwann auseinander.
    battery_net_eur: float = 0.0

    @classmethod
    def from_totals(cls, t: EnergyTotals) -> EnergyTotalsOut:
        return cls(
            **t.model_dump(),
            autarky=t.autarky,
            self_consumption_share=t.self_consumption_share,
            avg_import_price_ct=t.avg_import_price_ct,
            battery_net_eur=t.battery_net_eur,
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


class EnergySummaryOut(BerichtMitStand):
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


class PvTaxReportOut(BerichtMitStand):
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


class HeatReportOut(BerichtMitStand):
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


class EvReportOut(BerichtMitStand):
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


class MemoryTypeOut(BaseModel):
    """Eine Objektgruppe im Python-Haufen: Typ, Anzahl, flache Größe."""

    name: str
    count: int
    mb: float


class MemoryReportOut(BaseModel):
    """Woraus der Arbeitsspeicher dieses Vorgangs besteht.

    Der Dienst wird nach Arbeitsspeicher abgerechnet, und die Plattform nennt nur eine Summe je
    Dienst. `rss_mb` ist diese Summe für die API, `types` beantwortet die Anschlussfrage: Liegt
    irgendwo eine Million Zeilen herum, die dort nicht hingehört?

    Die Differenz zwischen `rss_mb` und `tracked_mb` ist gross und in Ordnung: Interpreter,
    Bibliotheken und der Speicher von C-Erweiterungen zählen nicht zum verwalteten Haufen.
    """

    rss_mb: float | None
    peak_mb: float | None
    objects: int
    tracked_mb: float
    types: list[MemoryTypeOut]
    pool_de: str
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


class HeatBalanceOut(BerichtMitStand):
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
    #: Was bei offenem Fenster in die Räume ging. None, wenn der Zeitraum zu lang für Minutenwerte
    #: ist oder keine Fensterkontakte gemeldet haben.
    ventilation: VentilationOut | None = None
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
    # 1, solange ein Fenster dieses Raums offen steht; `None`, wenn es keinen Kontakt gibt. Aus der
    # Alarmanlage, nicht aus Controme.
    window: float | None
    deviation_k: float | None
    observed_at: datetime | None
    quality: Quality


class RoomsLiveOut(BaseModel):
    at: datetime
    # Falsch, solange die Brücke noch kein `rooms.list` geschickt hat: dann stehen hier Messwerte
    # unter Ersatznamen („Raum 5"), und die Anzeige soll sagen können, warum.
    named: bool
    rooms: list[RoomLiveOut]


class RoomSetpointIn(BaseModel):
    """Ein von Hand gestellter Sollwert, dauerhaft.

    Ohne Frist und ohne Rücknahme: Wer in Controme am Sollwert dreht, meint es so, bis er es
    anders meint. Ein Wert auf Zeit wäre eine zweite Wahrheit neben der, die der Regler kennt.
    """

    setpoint_c: float = Field(ge=rooms_logic.SOLL_MIN, le=rooms_logic.SOLL_MAX)


class RoomSetpointOut(BaseModel):
    ok: bool
    room: RoomLiveOut
    # Was gestellt wurde, nachdem gerundet wurde - nicht, was gewünscht war.
    setpoint_c: float
    message_de: str


class RoomEffectOut(BaseModel):
    """Was eine Sollwertänderung in diesem Raum bedeutet - geschätzt, mit Herkunft im Satz.

    Die Zahlen sind klein und ihre Grundlage ist eine Annahme; beides muss die Anzeige sagen. Der
    Zweck ist nicht die zweite Nachkommastelle, sondern die Größenordnung: ob ein halbes Grad
    Cent oder Euro kostet, und ob Vorladen vor dem Preishoch überhaupt lohnt.
    """

    room_id: int
    name: str
    delta_k: float
    share: float
    daily_kwh_th: float
    daily_kwh_el: float
    daily_eur: float
    store_kwh_th: float
    store_kwh_el: float
    shift_saving_eur: float | None
    half_life_h: float
    cop: float
    # Woraus gerechnet wurde, damit die Zahlen nachzuvollziehen sind.
    outdoor_c: float
    #: War `outdoor_c` eine Messung - oder die Rücklage, weil keine vorlag?
    #:
    #: Die Außentemperatur bestimmt über die Arbeitszahl jede Stromzahl dieser Antwort: zwischen
    #: 7 °C (Arbeitszahl 3,5) und -7 °C (2,4) liegt Faktor 1,46. Bis zum 23.11.2026 stand hier
    #: stumm die Rücklage von 7,0 °C, sobald die Aufnahme keine Außentemperatur hatte, und
    #: `outdoor_c` sah aus wie eine Messung. `note_de` sagt es jetzt auch im Satz.
    aussen_gemessen: bool
    price_ct_kwh: float | None
    cheap_ct_kwh: float | None
    expensive_ct_kwh: float | None
    note_de: str


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
    window: list[float | None]


class RoomHistoryOut(BaseModel):
    start: datetime
    end: datetime
    step_min: int
    ts: list[datetime]
    rooms: list[RoomSeriesOut]


class RoomLogEntryOut(BaseModel):
    """Eine Zeile der Zeitleiste: wann sich der Sollwert geändert hat und wer es war.

    `quelle` ist `app` (hier gestellt), `automatik` oder `extern`. **`extern` heißt nicht
    „der Nutzer"**, sondern nur: nicht über dieses Werkzeug. Dahinter stecken die Controme-App,
    das Bedienteil an der Wand oder Contromes eigenes Heizprogramm, und diese drei lassen sich
    von hier aus nicht unterscheiden.

    `art` ist `sollwert` (gemessene Änderung), `befehl` (geschickt, aber nie gemeldet),
    `ruhe` (die Automatik zieht sich zurück) oder `einstellung` (die Automatik wurde geschaltet).
    """

    at: datetime
    quelle: Literal["app", "automatik", "extern"]
    art: Literal["sollwert", "befehl", "ruhe", "einstellung"]
    #: `from` ist in Python ein Schlüsselwort, daher die Endung. Die Einheit ist Grad Celsius.
    from_c: float | None = None
    to_c: float | None = None
    text: str
    #: Wer es war, als fertige Zeile: „iPad Flur", mit Benutzersystem „Moritz, am iPad Flur".
    #: Leer heißt **unbekannt**, nicht „niemand": bei Änderungen von außen weiß es dieser Dienst
    #: nicht, und Zeilen aus der Zeit vor dieser Aufzeichnung tragen es nicht nach.
    urheber: str = ""


class RoomLogOut(BaseModel):
    """Das Protokoll eines Raums: Zeitreihe und Zeitleiste über denselben Zeitraum."""

    room: RoomSeriesOut
    start: datetime
    end: datetime
    step_min: int
    ts: list[datetime]
    #: Sollwert plus Offset - die Temperatur, auf die tatsächlich geregelt wurde.
    target_c: list[float | None]
    entries: list[RoomLogEntryOut]


class PushKeyOut(BaseModel):
    """Der öffentliche Schlüssel des Dienstes und die Zahl der angemeldeten Geräte.

    Der Browser braucht den Schlüssel, um ein Abonnement anzulegen; ohne ihn geht gar nichts.
    Öffentlich ist er im Wortsinn: Er darf in jeder Seite stehen.
    """

    public_key: str
    devices: int


class PushSubscribeIn(BaseModel):
    endpoint: str
    p256dh: str
    auth: str
    #: Ein Wort, an dem man das Gerät später wiedererkennt („iPhone", „iPad Küche").
    label: str = ""
    #: Die Herkunft der Seite (`location.origin`). Sie wird der Absender der Mitteilungen,
    #: solange keine eigene Adresse gesetzt ist.
    origin: str = ""


class ApnsSubscribeIn(BaseModel):
    """Ein Gerät der iOS-App anmelden.

    Derselbe Zuschnitt wie `PushSubscribeIn`, nur dass die Adresse ein Gerätetoken ist und die
    beiden Schlüssel fehlen: APNs verschlüsselt selbst.
    """

    #: Das Gerätetoken, wie APNs es vergibt - 64 Hexzeichen.
    token: str = Field(min_length=8, max_length=200)
    #: Ein Wort, an dem man das Gerät später wiedererkennt („iPad Flur").
    label: str = ""
    #: Ob das Token aus einem Entwicklungsbau kommt.
    #:
    #: Das muss mitkommen und lässt sich nicht erraten: ein Token aus Xcode gilt bei Apple an
    #: einer anderen Adresse als eines aus dem App Store, und wer das verwechselt, bekommt
    #: `BadDeviceToken` ohne weitere Auskunft.
    sandbox: bool = False


class ApnsUnsubscribeIn(BaseModel):
    token: str = Field(min_length=8, max_length=200)


class PushUnsubscribeIn(BaseModel):
    endpoint: str


class PushResultOut(BaseModel):
    ok: bool
    devices: int
    message_de: str
    #: Je Gerät ein Satz, was aus der Mitteilung geworden ist und warum.
    details_de: list[str] = Field(default_factory=list)


class PushGeraetOut(BaseModel):
    """Ein angemeldetes Gerät, soweit der Dienst es kennt: ein Wort und der Stand der Zustellung."""

    label: str
    seit: datetime | None = None
    zuletzt_ok: datetime | None = None
    #: Fehlgeschlagene Versuche seit der letzten angenommenen Mitteilung.
    fehlversuche: int = 0
    #: Der letzte Grund eines Fehlschlags, sonst leer. Nach einem Neustart leer bis zur
    #: nächsten Probe.
    letzter_fehler_de: str = ""


class PushGeraeteOut(BaseModel):
    devices: list[PushGeraetOut] = Field(default_factory=list)


class MorgenbriefOut(BaseModel):
    """Der Morgenbrief: ob er verschickt wird und was heute darin stünde.

    Eine Mitteilung am Morgen mit dem, was der Tag bringt: erwartete Sonne, günstigste und
    teuerste Zeit für Netzstrom, geplante Läufe der Wärmepumpe. `zeilen` ist der Brief, wie er
    jetzt verschickt würde, damit die Seite ihn zeigen kann, bevor jemand ihn einschaltet.
    """

    enabled: bool
    #: Ortszeit, ab der der Brief verschickt wird.
    uhrzeit: str
    #: Für welchen Morgen die Vorschau gilt: „heute" oder „morgen".
    fuer_de: str = "heute"
    titel: str | None = None
    zeilen: list[str] = Field(default_factory=list)
    #: Warum es gerade keinen Brief gibt, sonst leer.
    hinweis_de: str = ""
    #: Wann der Brief zuletzt verschickt wurde und an wie viele Geräte, als Satz. Leer in der
    #: Vorführung, die keinen Zeitplan hat.
    zuletzt_de: str = ""
    #: Wie viele Geräte für Mitteilungen angemeldet sind. Bei null geht der Brief an niemanden.
    geraete: int = 0


class MorgenbriefIn(BaseModel):
    enabled: bool


class WaermepumpeOut(BaseModel):
    """Die Wärmepumpe im Augenblick, für ihre Technikseite.

    Jede Größe ist ein Messwert mit Zeitpunkt und Güte: fehlt einer, steht auf der Seite ein
    Fragezeichen an seiner Stelle und keine Null. Die drei gerechneten Größen am Ende
    entstehen aus diesen Messwerten; wie, steht in `hinweise_de` und in
    `application/waermepumpe.py`.
    """

    now: datetime
    laeuft: bool
    zustand_code: int | None = None
    zustand_de: str
    pumpe_laeuft: bool = False
    # Außengerät und Kältekreis
    aussen_c: Measurement
    verdampfer_c: Measurement
    sauggas_c: Measurement
    heissgas_c: Measurement
    fluessig_c: Measurement
    verdichter_hz: Measurement
    leistung_bus_kw: Measurement
    leistung_zaehler_kw: Measurement
    # Innengerät und Wasserseite
    vorlauf_c: Measurement
    ruecklauf_c: Measurement
    durchfluss_l_min: Measurement
    vorlauf_soll_c: Measurement
    # Speicher: der Fühler, den die Wärmepumpe selbst hat, und die vier eigenen, oben nach unten.
    speicherfuehler_c: Measurement
    puffer_c: list[Measurement] = Field(default_factory=list)
    # Gerechnet aus den Messwerten darüber
    spreizung_k: float | None = None
    waermeleistung_kw: float | None = None
    arbeitszahl: float | None = None
    #: Was der Regler vorgibt: fordert die erste Zone Wärme an, und mit welchem Raum-Sollwert.
    heizanforderung: bool | None = None
    raum_soll_c: Measurement | None = None
    #: Was der Zähler mehr aufnimmt, als die Maschine für sich meldet, wenn es deutlich mehr
    #: ist (ab 1,5 kW): neben dem Verdichter läuft dann etwas anderes, vermutlich der Heizstab.
    zusatz_kw: float | None = None
    #: Was das eBUS-Add-on ab 0.3.0 selbst abfragt. Ventil und Heizstab als Zahl des Reglers:
    #: laut Bus-Beschreibung Ventil 0 Warmwasser, 1 Heizung; Heizstab 1 an. Im Haus noch nicht
    #: gegengeprüft, deshalb keine Wörter.
    ventil_code: int | None = None
    heizstab_code: int | None = None
    verdichter_a: Measurement | None = None
    luefter_drehzahl: Measurement | None = None
    #: Die Betriebsart des Reglers (Kennung c94b des Busses) als Zahl und als Wort.
    kreis_code: int | None = None
    kreis_de: str | None = None
    #: Wohin die Maschine gerade in den Speicher einspeist, soweit die Betriebsart es sagt:
    #: bei Warmwasser oben, im Heizbetrieb tiefer. `None`: steht, oder die Betriebsart sagt es
    #: nicht.
    einspeisung: Literal["oben", "tiefer"] | None = None
    #: Gesetzt, wenn vom Bus der Maschine kein einziger Wert da ist: ein Satz, an welcher Stelle
    #: des Weges es hängt, soweit Dienst und Bridge das wissen (`waermepumpe.bus_auskunft`).
    bus_stumm_de: str | None = None
    hinweise_de: list[str] = Field(default_factory=list)


class ReglerKennzahlOut(BaseModel):
    """Was in den Minuten geschah, in denen der Regler diese Kennzahl sendete."""

    code: int
    minuten: int
    #: Minuten davon, in denen der Verdichter lief.
    lauf_min: int
    #: Mittel über die Minuten im Lauf.
    vorlauf_c: float | None = None
    vorlauf_soll_c: float | None = None
    #: Wie schnell der Speicher im Lauf wärmer wurde, am obersten Fühler und am Fühler Mitte
    #: unten, in Kelvin je Stunde. `None` unter zwanzig Minuten Lauf.
    oben_k_h: float | None = None
    unten_k_h: float | None = None
    #: Anteil der Minuten, in denen Duck Curve Home die Maschine angefordert hatte.
    angefordert_anteil: float | None = None
    #: Was der Zähler im Lauf im Mittel mehr aufnahm, als die Maschine für sich meldete.
    zusatz_kw: float | None = None
    #: Anteil der Minuten mit Heizanforderung der ersten Zone, und mit gesetzter Kennung 1b45
    #: (Bedeutung offen; sie liegt neben der Kennung des Heizstabs).
    heizanforderung_anteil: float | None = None
    flag_1b45_anteil: float | None = None
    #: Anteil der Minuten, in denen das Umschaltventil auf 1 stand und in denen der Regler den
    #: Heizstab als an meldete (beide abgefragt seit dem 14.11.2026).
    ventil_1_anteil: float | None = None
    heizstab_anteil: float | None = None
    zuletzt: datetime | None = None


class ReglerKennzahlenOut(BaseModel):
    now: datetime
    tage: int
    zeilen: list[ReglerKennzahlOut] = Field(default_factory=list)


class ReglerGesendetOut(BaseModel):
    """Ein Stellbefehl, der hinausgegangen ist und dessen Rückmeldung noch aussteht."""

    wert: float
    at: datetime


class ReglerEinstellungOut(BaseModel):
    """Eine Einstellung des Reglers der Wärmepumpe, gelesen über den Bus."""

    schluessel: str
    name_de: str
    gruppe_de: str
    #: Die Kennung des Busses, unter der sie gelesen wird.
    kennung: str
    einheit: str = ""
    stellen: int = 1
    wert: Measurement
    #: Was die Bus-Beschreibung zu dieser Zahl sagt, bei Kennzahlen. Nicht im Haus bestätigt.
    lesart_de: str | None = None
    #: Wie sie sich bedienen lässt: eine Zahl auf einer Skala, eine Auswahl, ein Schalter.
    art: Literal["zahl", "wahl", "schalter"] = "zahl"
    #: Lässt sie sich von hier stellen, und in welchen Grenzen und Schritten.
    stellbar: bool = False
    von: float | None = None
    bis: float | None = None
    schritt: float | None = None
    #: Die Stufen einer Auswahl oder eines Schalters: Zahl des Reglers und Lesart der Liste.
    wahl: dict[str, str] = Field(default_factory=dict)
    #: Jemand hat den Wert mit dem Bediengerät verglichen. Ohne das wird nicht gestellt.
    bestaetigt: bool = False
    #: Die Zeile zum Stellen ist nach dem Muster der übrigen gebildet, nicht aus der Liste.
    muster: bool = False
    hinweis_de: str = ""
    #: Gesendet, aber vom Regler noch nicht so zurückgemeldet.
    gesendet: ReglerGesendetOut | None = None


class ReglerAenderungOut(BaseModel):
    """Eine Zeile des Protokolls: wer wann was gestellt hat."""

    at: datetime
    schluessel: str
    name_de: str
    von_de: str
    auf_de: str
    urheber_de: str | None = None


class ReglerEinstellungenOut(BaseModel):
    """Was am Regler der Wärmepumpe eingestellt ist, und was sich davon stellen lässt."""

    now: datetime
    gelesen: int
    satz_de: str
    werte: list[ReglerEinstellungOut] = Field(default_factory=list)
    #: Kann der Dienst gerade einen Stellbefehl loswerden. Wenn nicht, sagt `hindernis_de`, warum.
    stellen_moeglich: bool = False
    hindernis_de: str | None = None
    stellen_je_tag: int = 0
    protokoll: list[ReglerAenderungOut] = Field(default_factory=list)
    hinweise_de: list[str] = Field(default_factory=list)


class ReglerStellenIn(BaseModel):
    wert: float


class ReglerBestaetigenIn(BaseModel):
    bestaetigt: bool


class ReglerStellenOut(BaseModel):
    """Die Antwort auf einen Stellbefehl oder eine Bestätigung: ob es ging, ein Satz dazu, und
    der Stand danach."""

    ok: bool
    message_de: str
    einstellungen: ReglerEinstellungenOut


class KennlinienPunktOut(BaseModel):
    """Ein Fenster im eingeschwungenen Heizbetrieb (`hems_core.thermal.kennlinie`)."""

    at: datetime
    minuten: int
    aussen_c: float
    vorlauf_c: float
    cop: float
    waerme_kw: float
    strom_kw: float
    #: Stellung des Umschaltventils im Fenster, wenn sie einheitlich war (Zahl des Reglers).
    ventil: int | None = None


class KennlinienFitOut(BaseModel):
    """COP = a + b_aussen * Außentemperatur + c_vorlauf * Vorlauftemperatur, kleinste Quadrate.

    `art` sagt, welche Terme sich aus den Punkten bestimmen ließen: `ebene` beide, `aussen`
    oder `vorlauf` nur einer, `mittel` keiner.
    """

    art: Literal["ebene", "aussen", "vorlauf", "mittel"]
    a: float
    b_aussen: float
    c_vorlauf: float
    n: int
    rmse: float
    r2: float | None = None
    aussen_von_c: float
    aussen_bis_c: float
    vorlauf_von_c: float
    vorlauf_bis_c: float
    formel_de: str
    geltung_de: str


class KennlinienHubOut(BaseModel):
    """COP = a + b_hub * Hub, mit Hub = Vorlauf minus Außentemperatur (`hems_core.thermal.kennlinie`).

    `art` ist `gerade`, wenn der Hub genug streut, sonst `mittel`. Der Gütegrad ist der Anteil
    an der Arbeitszahl eines idealen Kreisprozesses bei denselben Temperaturen.
    """

    art: Literal["gerade", "mittel"]
    a: float
    b_hub: float
    n: int
    rmse: float
    r2: float | None = None
    hub_von_k: float
    hub_bis_k: float
    guetegrad: float | None = None
    formel_de: str
    geltung_de: str
    #: Der Gütegrad als Satz; leer, wenn es keinen gibt.
    guete_de: str = ""


class KennlinienAnnahmeOut(BaseModel):
    """Ein Punkt der Kennlinie, mit der der Fahrplan bisher rechnet."""

    aussen_c: float
    cop: float


class KennlinienBilanzOut(BaseModel):
    """Wo die Minuten des Zeitraums geblieben sind (`hems_core.thermal.kennlinie.Bilanz`).

    Von den Minuten, in denen die Maschine heizte, zählt nur ein Teil: nicht der Anlauf, nicht
    die mit Heizstab, nicht die ohne einen nötigen Wert. Die Zahlen hier addieren sich zu
    `heizen`; eine leere Kennlinie zeigt damit, woran es liegt.
    """

    minuten: int
    heizen: int
    anlauf: int
    zusatz: int
    ohne_wert: int
    ohne_waerme: int
    gueltig: int
    #: Fenster mit mindestens einer gültigen Minute; `punkte` davon waren voll genug.
    fenster: int
    punkte: int
    unglaubwuerdig: int
    #: Welcher Wert in wie vielen Minuten fehlte (eine Minute kann mehrere nennen).
    fehlt: dict[str, int] = Field(default_factory=dict)
    #: Das gewöhnliche Verhältnis von Zähler zu eigener Angabe der Maschine, wenn bestimmt.
    verhaeltnis: float | None = None
    satz_de: str = ""


class KennlinieOut(BaseModel):
    """Die gemessene Kennlinie der Wärmepumpe: Messpunkte, Ausgleich und die bisherige Annahme.

    Die Punkte sind Abschätzungen aus Durchfluss, Spreizung und Zähler; warum, steht in
    `hinweise_de`.
    """

    now: datetime
    von: datetime
    bis: datetime
    tage: int
    punkte: list[KennlinienPunktOut] = Field(default_factory=list)
    fit: KennlinienFitOut | None = None
    #: Die Arbeitszahl über dem Hub; fehlt bei zu wenigen Punkten.
    hub: KennlinienHubOut | None = None
    #: Was dem Ausgleich noch fehlt, wenn es keinen gibt oder ein Term fehlt.
    fehlt_de: str | None = None
    #: Die Kennlinie des Fahrplans, gültig bei `annahme_vorlauf_c`.
    annahme: list[KennlinienAnnahmeOut] = Field(default_factory=list)
    annahme_vorlauf_c: float | None = None
    #: Wo die Minuten geblieben sind; fehlt, wenn es keine Minutenreihen gibt.
    bilanz: KennlinienBilanzOut | None = None
    hinweise_de: list[str] = Field(default_factory=list)


class BetriebTagOut(BaseModel):
    """Ein Ortstag der Wärmepumpe (`hems_core.thermal.betrieb.Tag`)."""

    tag: date
    starts: int
    lauf_min: int
    abtau_min: int
    abtauungen: int
    #: Minuten, in denen neben dem Verdichter etwas anderes Strom aufnahm (erschlossen).
    zusatz_min: int
    strom_kwh: float
    waerme_kwh: float | None = None
    strom_lauf_kwh: float = 0.0
    #: Wärme durch Strom über alle Minuten im Lauf, Abtauen und Heizstab eingeschlossen.
    cop_tag: float | None = None
    #: Dasselbe nur aus den Fenstern der Kennlinie: eingeschwungen, ohne Abtauen und Heizstab.
    cop_heizen: float | None = None
    lauf_median_min: float | None = None
    aussen_c: float | None = None
    waerme_min: int = 0


class BetriebLaufOut(BaseModel):
    """Ein Lauf des Verdichters, vom Anlaufen bis zum Halt."""

    start: datetime
    minuten: int
    abtau_min: int
    abtauungen: int
    zusatz_min: int
    strom_kwh: float
    waerme_kwh: float | None = None
    #: Der Lauf reicht über den Rand der Daten oder an eine Lücke: seine Länge ist unvollständig.
    angeschnitten: bool = False


class BetriebStundeOut(BaseModel):
    """Eine Stunde im Heizbetrieb: was der Regler als Vorlauf verlangte, bei welchem Wetter."""

    at: datetime
    minuten: int
    aussen_c: float
    soll_c: float
    vorlauf_c: float | None = None
    ventil: int | None = None


class BetriebHeizkurveOut(BaseModel):
    """Sollwert = a + b * Außentemperatur, nach kleinsten Quadraten über die Stunden."""

    a: float
    b: float
    n: int
    r2: float | None = None
    aussen_von_c: float
    aussen_bis_c: float
    formel_de: str


class BetriebKlasseOut(BaseModel):
    """Eine Klasse der Lauflängen: von einschließlich, bis ausschließlich (`None`: nach oben offen)."""

    von_min: int
    bis_min: int | None = None
    laeufe: int


class BetriebOut(BaseModel):
    """Der Betrieb der Wärmepumpe über Tage: Läufe, Abtauen, Takten, Heizkurve des Reglers.

    Eine Auszählung gespeicherter Minuten. Was sie taugt, steht in `hinweise_de`.
    """

    now: datetime
    von: datetime
    bis: datetime
    zeitraum_tage: int
    tage: list[BetriebTagOut] = Field(default_factory=list)
    #: Die jüngsten Läufe, der neueste zuletzt.
    laeufe: list[BetriebLaufOut] = Field(default_factory=list)
    stunden: list[BetriebStundeOut] = Field(default_factory=list)
    heizkurve: BetriebHeizkurveOut | None = None
    klassen: list[BetriebKlasseOut] = Field(default_factory=list)
    #: Die Summen des Zeitraums.
    starts: int = 0
    lauf_min: int = 0
    abtau_min: int = 0
    abtauungen: int = 0
    zusatz_min: int = 0
    cop_gesamt: float | None = None
    cop_heizen: float | None = None
    lauf_median_min: float | None = None
    #: Was die Auszählung sagt, je Thema ein Satz.
    saetze_de: list[str] = Field(default_factory=list)
    hinweise_de: list[str] = Field(default_factory=list)


class ShiftDayOut(BaseModel):
    """Ein Tag im Vergleichslauf. `note_de` ist leer, wenn gerechnet wurde."""

    day: date
    saving_eur: float
    heat_pump_kwh: float
    shifted_kwh: float
    note_de: str = ""


class ShiftReportOut(BerichtMitStand):
    """Was das Verschieben der Wärmepumpe gebracht hat - eine Rechnung, keine Messung.

    Der Vergleichslauf legt dieselbe Strommenge in die Stunden, in denen ein gewöhnlicher
    Thermostat sie gebraucht hätte, und stellt die Stromrechnung beider Läufe gegenüber. Die
    Annahmen stehen einzeln in `assumptions_de`, weil eine Zahl ohne sie mehr behauptet, als sie
    weiß.
    """

    period: Literal["day", "week", "month", "year"]
    start: datetime
    end: datetime
    actual_eur: float
    naive_eur: float
    saving_eur: float
    #: Was jede verschobene Kilowattstunde gebracht hat; null, wenn nichts verschoben wurde.
    saving_ct_per_kwh: float | None = None
    heat_pump_kwh: float
    shifted_kwh: float
    days: list[ShiftDayOut] = Field(default_factory=list)
    days_used: int
    days_skipped: int
    skipped_de: str = ""
    method_de: str
    assumptions_de: list[str] = Field(default_factory=list)


class RoomShiftRoomOut(BaseModel):
    """Ein Raum, in dem die Automatik gerade etwas angestellt hat - oder gerade ruht."""

    room_id: int
    name: str
    #: Der Wert des Menschen, auf den zurückgestellt wird.
    base_setpoint_c: float
    offset_k: float
    written_setpoint_c: float
    written_at: datetime
    #: Gesetzt, wenn jemand von Hand gestellt hat: So lange fasst die Automatik den Raum nicht an.
    paused_until: datetime | None = None


class RoomShiftEventOut(BaseModel):
    at: datetime
    text_de: str


class RoomShiftOut(BaseModel):
    """Was die Automatik darf, was sie gerade will und was sie getan hat.

    **Aus, bis jemand sie einschaltet.** Das ist die einzige Stelle in Duck Curve Home, an der das
    Werkzeug von sich aus etwas in der Wohnung verstellt; die Voreinstellung ist deshalb nicht
    „an mit Vorsicht", sondern „aus".
    """

    enabled: bool
    rooms: list[int] = Field(default_factory=list)
    delta_k: float
    draw_k: float
    lead_h: float
    min_spread_ct: float
    #: Was die Automatik in dieser Minute will.
    phase: Literal["laden", "zehren", "aus"]
    offset_k: float
    until: datetime | None = None
    window_start: datetime | None = None
    window_end: datetime | None = None
    spread_ct: float | None = None
    reason_de: str
    #: Räume mit einer Rückfahrkarte: angehoben oder in Ruhe nach einem Eingriff.
    active: list[RoomShiftRoomOut] = Field(default_factory=list)
    #: Die letzten Eingriffe, jüngste zuerst.
    log: list[RoomShiftEventOut] = Field(default_factory=list)
    #: Warum gerade nichts gestellt werden kann, falls etwas im Weg ist.
    note_de: str = ""


class RoomShiftIn(BaseModel):
    """Alles freiwillig: Was fehlt, bleibt, wie es war."""

    enabled: bool | None = None
    rooms: list[int] | None = None
    delta_k: float | None = None
    draw_k: float | None = None
    lead_h: float | None = None
    min_spread_ct: float | None = None


class VentilationRoomOut(BaseModel):
    """Ein Raum, in dem während der Heizzeit ein Fenster offen stand."""

    room_id: int
    name: str
    open_minutes: int
    #: Davon Minuten, in denen zugleich Heizkreise dieses Raums offen standen.
    heating_minutes: int
    kwh: float


class VentilationOut(BaseModel):
    """Wärme, die in Räume mit offenem Fenster ging - geschätzt, nicht gemessen.

    Die Entnahme der Wärmebilanz ist eine Zahl für das ganze Haus. Verteilt wird sie hier nach
    offenen Heizkreisen je Raum; was auf Räume mit offenem Fenster entfällt, steht hier. Das ist
    **nicht** der Lüftungsverlust: Ein Teil dieser Wärme ist im Raum geblieben. Und es ist eher zu
    viel als zu wenig, weil Warmwasser in derselben Entnahme steckt und sich nicht trennen lässt.
    """

    kwh: float
    share: float | None = None
    open_minutes: int
    #: Minuten mit Fenster- und Ventilwerten. Ohne sie ist die Zahl eine Untergrenze.
    minutes_known: int
    rooms: list[VentilationRoomOut] = Field(default_factory=list)
    note_de: str


# ------------------------------------------------------------------ Anlagenschema


class AnlageStromOut(BaseModel):
    """Die Stromseite des Schemas: drei Quellen, ein Knoten, zwei Abgänge.

    Vorzeichen wie im Live-Zustand: Netz positiv ist Bezug, Batterie positiv ist Laden. Die
    Anteile (`share_*`) sagen, woher der Strom im Knoten gerade kommt: PV, Netzbezug und
    Speicherentladung nach ihrer Einspeisung. Das ist eine Zuordnung nach Anteilen, keine Physik,
    aber es ist die Zuordnung, die jede Bilanz benutzt. Sie summieren sich zu 1 oder sind alle 0.
    """

    pv_kw: float | None
    grid_kw: float | None
    battery_kw: float | None
    battery_soc: float | None
    house_kw: float | None
    heat_pump_kw: float | None
    #: Alles außer der Wärmepumpe: Haushalt samt Wallbox.
    rest_kw: float | None
    share_pv: float
    share_grid: float
    share_battery: float


class AnlageWaermepumpeOut(BaseModel):
    """Die Wärmepumpe im Schema. Wärme, Vorlauf und COP bleiben leer, bis der Bus angeschlossen
    ist; die Anzeige sagt dann „Wärme nicht gemessen" statt eine Zahl zu erfinden."""

    running: bool
    running_since: datetime | None
    power_kw: float | None
    thermal_kw: float | None
    flow_c: float | None
    cop: float | None


class AnlageOfenOut(BaseModel):
    """Der Pelletofen im Schema. `water_kw` ist geschätzt aus der Leistungsstufe nach dem
    Datenblatt, dieselbe Rechnung wie in der Wärmebilanz."""

    present: bool
    running: bool | None
    power_level: float | None
    flow_c: float | None
    return_c: float | None
    pump_pct: float | None
    water_kw: float | None


class AnlageSpeicherOut(BaseModel):
    """Das Glas: vier Fühler von oben nach unten, Ladezustand und die gerechnete Nettoleistung.

    `net_kw` ist die Änderung des Energieinhalts über die letzte Viertelstunde, positiv = lädt,
    aus den vier Temperaturen und dem Volumen. `net_word` ist das Wort dazu („lädt", „entlädt",
    „hält"), hier entschieden und nicht in der Anzeige, damit die Schwelle an einer Stelle steht.
    `return_c` ist die Temperatur des gemeinsamen Rücklaufs an der untersten Spitze: der unterste
    Fühler, den Ofen- und Wärmepumpenkreis teilen.
    """

    temps_c: list[float | None]
    soc: float | None
    usable_kwh: float | None
    capacity_kwh: float
    volume_liters: float
    net_kw: float | None
    net_word: str
    return_c: float | None


class AnlageHeizkreisOut(BaseModel):
    """Der Heizkreis: wie viele Räume gerade Wärme nehmen. Eine Leistung gibt es nicht; die
    Wärmebilanz kennt sie nur als Rest, und ein Rest ist keine Anzeige für den Augenblick."""

    rooms_total: int
    rooms_open: int
    #: Mittlerer Anteil offener Heizkreise über alle Räume mit Messwert, 0 bis 1.
    open_share: float | None
    running: bool


class AnlageWarmwasserOut(BaseModel):
    """Das Trinkwasser: ein Anlegefühler am warmen Auslass, sonst nichts.

    `present` ist falsch, solange kein Fühler meldet; dann bleibt die Kachel gedimmt und sagt das.
    `tapping` ist **erkannt**, nicht gemessen: Das Rohr springt auf, sobald warmes Wasser läuft,
    siehe `hems_core.thermal.anlage.zapfung`. Es sagt, dass und seit wann, nicht wie viel.
    """

    present: bool
    outlet_c: float | None
    inlet_c: float | None
    tapping: bool | None
    tapping_since: datetime | None


class AnlageOut(BaseModel):
    """Das Anlagenschema im Augenblick: alles, was die Seite „Anlage" zeichnet, in einer Antwort.

    Keine Zeitreihe, kein Zeitraum: Das Bild ist der Augenblick, und seine Zahlen kommen aus dem
    Live-Zustand, aus den Räumen und aus zwei kurzen Rückblicken in die Minutenreihe für die
    Nettoleistung des Speichers und die Zapferkennung.
    """

    at: datetime
    outdoor_c: float | None
    strom: AnlageStromOut
    waermepumpe: AnlageWaermepumpeOut
    ofen: AnlageOfenOut
    speicher: AnlageSpeicherOut
    heizkreis: AnlageHeizkreisOut
    warmwasser: AnlageWarmwasserOut


class AnlageReplayOut(BaseModel):
    """Ein Ortstag als Folge von Anlagenbildern: die Wiedergabe.

    Dieselben Bilder wie `GET /anlage`, nur aus der Minutenreihe nachgebaut und nicht aus dem
    Augenblick. Die Oberflaeche faehrt mit einem Schieber darueber; das Schema zeichnet jedes Bild
    so, wie es den Augenblick zeichnet.

    **Luecken sind Luecken.** Ein Zeitpunkt ohne Messung in der Toleranz liefert kein Bild, und es
    wird keines erfunden: `frames` ist deshalb nicht notwendig gleichmaessig und kann kuerzer sein
    als der Tag. `erwartet` sagt, wie viele Bilder ein vollstaendiger Tag haette - erst der
    Vergleich macht die Luecke sichtbar, statt sie als dichtes Band erscheinen zu lassen.

    **Was der Rueckblick nicht zeigen kann**, steht in `hinweise_de` und nicht nur im Quelltext:
    beim ersten Bild ist unbekannt, wie lange die Waermepumpe schon lief, und fuer Tage vor dem
    09.11.2026 gibt es keinen aufbewahrten Fahrplan. Der Heizkreis leuchtet, soweit die
    Raumhistorie Ventilstellungen fuer den Tag hat.
    """

    day: date
    step_min: int
    von: datetime
    bis: datetime
    #: Wie viele Bilder ein vollstaendig erfasster Tag ergeben haette.
    erwartet: int
    frames: list[AnlageOut]
    #: Drei Begleitreihen, jede genau so lang wie `frames` und in derselben Reihenfolge. Sie
    #: stehen neben den Bildern und nicht in ihnen, weil das Anlagenbild sie nicht kennt und auch
    #: nicht kennen soll: es zeichnet, was fliesst, nicht was es kostet oder was vorgesehen war.
    #:
    #: `preis_ct_kwh` kommt aus derselben Minutenzeile wie das Bild. `geplant_wp` und
    #: `geplant_ofen` sagen, was der juengste aufbewahrte Fahrplan **vor** dem Zeitpunkt fuer ihn
    #: vorsah: `True` Freigabe beziehungsweise Brennen, `False` ausdruecklich nicht, `None` kein
    #: aufbewahrter Fahrplan. Das dritte ist der Normalfall fuer jeden Tag vor dem 09.11.2026 und
    #: von einem Nein streng zu unterscheiden.
    preis_ct_kwh: list[float | None] = Field(default_factory=list)
    geplant_wp: list[bool | None] = Field(default_factory=list)
    geplant_ofen: list[bool | None] = Field(default_factory=list)
    hinweise_de: list[str] = Field(default_factory=list)


class KontaktwirkungOut(Kontaktwirkung):
    """Was der Freigabekontakt K1 auslöst: die Ereignisstudie über die letzten `days` Tage.

    Jeder Schließvorgang ist ein Ereignis; `ereignisse` enthält zu jedem die Leistung der
    Wärmepumpe von einer halben Stunde davor bis zwei Stunden danach, `faecher` legt sie am
    Nullpunkt übereinander. `quote` ist der Anteil der Schließvorgänge bei stehender Maschine, auf
    die binnen `folge_min` Minuten ein Anlauf folgte, `vergleich.quote` derselbe Anteil ohne
    Schließvorgang zur selben Tageszeit.

    Das Urteil steht in `urteil` und `urteil_de` und wird hier gefällt, nicht in der Oberfläche.
    Es ist ein Zusammenhang in der Zeit und keine Ursache; warum, steht in `methode_de`.
    """

    days: int


class NachbetrachtungOut(Nachbetrachtung):
    """Ein Ortstag in Euro: was der Fahrplan versprach, was er hielt, was der Tag kostete.

    Fünf Linien, alle mit derselben Rechnung über dieselben Viertelstunden bewertet
    (`verglichen`): der erste Fahrplan des Tages mit seinen eigenen Kosten (`versprochen`) und mit
    den eingetretenen Werten (`erster`), der jeweils letzte Stand des Fahrplans (`letzter`), die
    Messung (`wirklich`) und ein Vergleichslauf mit perfekter Voraussicht (`perfekt`).

    `abstaende` sind die Stufen dazwischen. Die ersten drei führen vom Versprechen zur
    Wirklichkeit: Prognosefehler, Nachführen, Eingriff der Maschine. Positiv heißt teurer.

    Eine Linie, die fehlt, hat `verfuegbar=false` und sagt in `grund_de`, warum. Das ist für
    Tage vor dem 09.11.2026 der Normalfall bei allen Fahrplanlinien: aufbewahrt wird erst seitdem.
    """

    day: date
    von: datetime
    bis: datetime
    laeuft_noch: bool = False
    #: Die elektrische Nennleistung, mit der jede Freigabe eines Fahrplans gerechnet ist.
    wp_kw: float
    verguetung_ct: float
    hat_ofen: bool = False
    #: Was das Verschieben gegenüber einem Lauf ohne Preisblick an diesem Tag gebracht hat:
    #: dieselbe Zahl und dieselbe Rechnung wie `GET /energy/shift` für den Tag. Positiv heißt
    #: gespart. `None`, wenn der Tag dafür zu wenig hergibt; `verschieben_de` sagt dann, warum.
    verschieben_eur: float | None = None
    verschieben_de: str = ""


# --- Alfred (docs/ALFRED.md) ---------------------------------------------------------------------


class AlfredWechselIn(BaseModel):
    """Ein früherer Wechsel des Gesprächs. Ungeprüfte Eingabe aus dem Browser: Begrenzt werden Rolle,
    Länge und - in `AlfredFrageIn` - die Zahl; der Dienst nimmt davon nur die letzten."""

    wer: Literal["alfred", "nutzer"]
    inhalt: str = Field(max_length=4000)


class AlfredFrageIn(BaseModel):
    frage: str = Field(min_length=1, max_length=1000)
    #: Die Hilfetexte der Oberfläche zu dem Ort, an dem gefragt wurde. Die einzige zulässige Quelle
    #: über die Bedienung; begrenzt, damit niemand den Systemtext und damit die Kosten aufbläht.
    wissen: str = Field(default="", max_length=8000)
    verlauf: list[AlfredWechselIn] = Field(default_factory=list, max_length=20)


class AlfredVorschlagOut(BaseModel):
    """Ein Vorschlag, noch nicht ausgeführt. `art` sagt, welcher Endpunkt ihn beim Drücken ausführt:
    `schalten` → POST /control/actuators/{ziel}, `sollwert` → POST /rooms/{ziel}/setpoint."""

    art: Literal["schalten", "sollwert"]
    ziel: str | int
    name: str
    an: bool | None = None
    #: Zustand vor dem Schalten, aus dem Live-Zustand; `None`, wenn keiner gemeldet ist.
    war_an: bool | None = None
    alt: float | None = None
    neu: float | None = None


class AlfredAntwortOut(BaseModel):
    bereit: bool
    antwort: str
    vorschlaege: list[AlfredVorschlagOut] = Field(default_factory=list)


class AlfredZustandOut(BaseModel):
    """Ob Alfred antworten kann, und an wen Fragen gehen (KI-Verordnung Art. 50)."""

    bereit: bool
    anbieter: str | None = None
    modell: str | None = None


class AlfredZuordnungIn(BaseModel):
    """Eine eingefügte Entitätenliste aus Home Assistant (Entwicklerwerkzeuge → Zustände)."""

    liste: str = Field(min_length=1, max_length=60_000)


class RegelkreisOut(Regelkreiskarte):
    """Die Regelkreis-Karte: Struktur, geltende Parameter, Entwurf und Lernzustand.

    Alles, was die Karte zeigt, steht hier: je Block seine Erklärung, seine Gleichungen und seine
    Parameter, je Kreis die Strecke, der daraus entworfene Regler, seine Reserven und die
    Frequenzkennlinie, je Parameter die Herkunft - gemessen, geschätzt, angenommen, fest,
    übersteuert -, die Unsicherheit und das Übernahmeprotokoll.

    Koordinaten stehen nicht darin. Wo ein Kästchen liegt, ist eine Frage der Zeichnung; was
    verbunden ist, eine Aussage über das Haus.
    """


class RegelkreisStellenIn(BaseModel):
    """Ein Parameter von Hand. Beschnitten wird auf die Plausibilitätsgrenzen des Registers."""

    wert: float


# --- Updates des Hausgeräts (deploy/haus/dch, routers/update.py) ---------------------------------


class UpdateNeuerungOut(BaseModel):
    """Eine Neuerung aus docs/versionen.json, für Außenstehende geschrieben (tools/version.py).

    `version` ist leer, solange die Neuerung noch zu keiner Version gehört (Kanal `main`).
    `bereich` und `text` sind im Schema nicht Pflicht, obwohl dieser Dienst sie immer füllt: Eine
    App liest damit auch einen Dienst von vorher (`sha`, `titel`), ohne dass der ganze Stand des
    Updates unlesbar wird, und lässt solche Einträge weg (`Hausgeraet.neuerungenNachVersion`)."""

    version: str | None = None
    bereich: str = ""
    text: str = ""


class UpdateErgebnisOut(BaseModel):
    am: str | None = None
    ergebnis: str | None = None
    von: str | None = None
    nach: str | None = None


class UpdateStatusOut(BaseModel):
    """Was der Update-Dienst des Geräts zuletzt festgestellt hat. `unterstuetzt` ist falsch ohne
    Hausgerät (Railway, Entwicklung); dann bietet die Oberfläche nichts an."""

    unterstuetzt: bool = False
    kanal: str | None = None
    aktuell: str | None = None
    verfuegbar: str | None = None
    update_verfuegbar: bool = False
    neuerungen: list[UpdateNeuerungOut] = Field(default_factory=list)
    geprueft_am: str | None = None

    @field_validator("neuerungen", mode="before")
    @classmethod
    def _ohne_commit_titel(cls, wert: Any) -> Any:
        """Ein Update-Dienst von vor dem 26.11.2026 schrieb Commit-Titel (`sha`, `titel`). Die
        sind nicht für Außenstehende geschrieben und erscheinen nicht; bis zur nächsten Prüfung
        steht dann keine Liste da."""
        if not isinstance(wert, list):
            return wert
        return [n for n in wert if not (isinstance(n, dict) and "text" not in n)]

    #: bereit | laeuft | fertig | zurueckgerollt | fehlgeschlagen
    zustand: str = "bereit"
    #: Sicherung | Quelltext | Laden | Neustart | Pruefung | Zurueck, solange `zustand` laeuft
    schritt: str | None = None
    meldung: str | None = None
    zuletzt: UpdateErgebnisOut | None = None
    #: Eine Anfrage liegt bereit und wartet darauf, dass der Dienst sie abholt.
    anfrage_offen: bool = False
    #: Welche: `installieren` (dann läuft ein Update an), `pruefen` (es wird nachgesehen) oder eine
    #: Aktion der Seite Hausgerät. Nur `installieren` zählt als laufendes Update.
    anfrage: str | None = None


class UpdateAnfrageIn(BaseModel):
    aktion: Literal["installieren", "pruefen"]


# ------------------------------------------------------------------------------- Hausgerät
#
# Was die Seite Technik -> Hausgerät zeigt (routers/geraet.py). Die rohen Werte kommen aus dem
# Bericht, den das Gerät jede Minute schreibt (deploy/haus/dch, `dch zustand`); Ampel und Satz
# bildet die API, damit Browser und iOS-App dieselbe Bewertung zeigen und sie nicht zweimal
# gepflegt wird.

Ampel = Literal["gut", "warn", "schlecht", "aus"]


class GeraetDienstOut(BaseModel):
    """Ein Container des Geräts (postgres, api, web, caddy, cloudflared)."""

    name: str
    #: Docker: running, restarting, exited, paused, created - oder `fehlt`, wenn compose.yaml ihn
    #: kennt, er aber nicht angelegt ist.
    zustand: str
    #: healthy, unhealthy, starting; `None`: Der Dienst hat keine Prüfung.
    gesundheit: str | None = None
    #: Die letzte Ausgabe der Prüfung, gekürzt.
    pruefung: str | None = None
    pruefung_fehlschlaege: int | None = None
    gestartet_am: datetime | None = None
    neustarts: int = 0
    exit_code: int | None = None
    image: str | None = None
    revision: str | None = None
    cpu_prozent: float | None = None
    speicher_mb: float | None = None
    ampel: Ampel = "aus"
    text_de: str = ""


class GeraetEinheitOut(BaseModel):
    """Ein systemd-Dienst oder -Zeitgeber des Geräts (Start, Sicherung, Updates, Bericht)."""

    name: str
    beschreibung: str = ""
    aktiv: str = ""
    unterzustand: str = ""
    eingeschaltet: bool = False
    naechster_lauf: datetime | None = None
    ampel: Ampel = "aus"
    text_de: str = ""


class GeraetPlatteOut(BaseModel):
    ort: str
    gesamt_bytes: int
    frei_bytes: int
    ampel: Ampel = "gut"


class GeraetNetzOut(BaseModel):
    schnittstelle: str
    #: Zähler seit dem Start des Geräts.
    empfangen_bytes: int
    gesendet_bytes: int


class GeraetSsdOut(BaseModel):
    """SMART der Platte, auf der das System liegt. NVMe meldet alles; eine Platte am USB-Adapter
    oft nur Temperatur und Betriebsstunden."""

    geraet: str
    modell: str | None = None
    gesund: bool | None = None
    temperatur_c: float | None = None
    betriebsstunden: int | None = None
    #: Verbrauchte Lebensdauer laut Hersteller, 0 bis 100 (darüber: über die zugesagte hinaus).
    abnutzung_prozent: float | None = None
    reserve_prozent: float | None = None
    geschrieben_bytes: int | None = None
    gelesen_bytes: int | None = None
    fehler: int | None = None
    unsichere_abschaltungen: int | None = None
    ampel: Ampel = "aus"
    text_de: str = ""


class GeraetDockerPlatzOut(BaseModel):
    images_bytes: int | None = None
    container_bytes: int | None = None
    #: Darin liegt auch die Datenbank.
    volumes_bytes: int | None = None
    cache_bytes: int | None = None


class GeraetRechnerOut(BaseModel):
    """Der Rechner selbst: Raspberry Pi oder was sonst darunter läuft."""

    name: str = ""
    modell: str | None = None
    system: str | None = None
    kernel: str | None = None
    adresse: str | None = None
    #: Zeitzone, die das Gerät für sich führt (`timedatectl`); `None`: nicht zu erfragen.
    #:
    #: Gemeldet, aber nicht bewertet - und das ist kein Versehen: Keine Uhrzeit, die hier jemand
    #: liest, hängt an dieser Zone. Der Dienst formatiert in `hems_core.domain.zeit.HAUS_ZONE`,
    #: die Oberfläche in `Europe/Berlin` (`apps/web/src/lib/format`), die App in der Zone des
    #: Telefons. Eine Ampel darauf wäre eine Warnung über eine Einstellung, die nichts bewirkt.
    #: Sie steht da für den, der das Gerät aufsetzt (`deploy/haus/README.md`, Abschnitt 1), und
    #: für die Protokolle, die `journalctl` in Ortszeit schreibt.
    zeitzone: str | None = None
    #: Kennt `timedated` einen eingeschalteten Zeitdienst (`NTP=`)?
    #:
    #: Die Ampel entscheidet `zeit_synchron`, nicht dieses Feld: `NTPSynchronized` ist die Auskunft
    #: des Kernels und gilt für jeden Zeitdienst, `NTP=` nur für die, die `timedated` in
    #: `/usr/lib/systemd/ntp-units.d` findet. Ob ein von Hand eingerichteter Dienst dort steht, ist
    #: nicht nachgeprüft (auf dem Entwicklungsrechner gibt es das Verzeichnis nicht); `False` ist
    #: darum kein Befund für sich, sondern verschärft nur eine schon nicht gestellte Uhr.
    zeitdienst_an: bool | None = None
    #: Führt der Kernel die Uhr als synchronisiert (`NTPSynchronized=`)? `None`: unbekannt, weil es
    #: kein `timedatectl` gibt (Railway, Entwicklung, Container) - unbekannt ist nicht schlecht.
    zeit_synchron: bool | None = None
    #: Was eine nicht gestellte Uhr bedeutet. Leer, solange sie synchron oder unbekannt ist.
    zeit_de: str = ""
    zeit_ampel: Ampel = "aus"
    laufzeit_s: int = 0
    kerne: int = 1
    last: list[float] = Field(default_factory=list)
    temperatur_c: float | None = None
    temperatur_ampel: Ampel = "aus"
    #: `vcgencmd get_throttled`, roh (etwa `0x50005`); `None` ohne Raspberry Pi.
    drosselung: str | None = None
    #: Was die Bits bedeuten, als Sätze. Leer: nichts aufgefallen.
    drosselung_de: list[str] = Field(default_factory=list)
    drosselung_ampel: Ampel = "aus"
    speicher_gesamt_mb: int = 0
    speicher_frei_mb: int = 0
    speicher_ampel: Ampel = "aus"
    platten: list[GeraetPlatteOut] = Field(default_factory=list)
    docker: str | None = None
    #: Auslastung aller Kerne über die rund zwei Sekunden, in denen der Bericht entsteht.
    cpu_prozent: float | None = None
    takt_mhz: float | None = None
    #: Spannung am Eingang (Raspberry Pi 5, `vcgencmd pmic_read_adc EXT5V_V`).
    eingangsspannung_v: float | None = None
    spannung_ampel: Ampel = "aus"
    swap_gesamt_mb: int = 0
    swap_frei_mb: int = 0
    netz: GeraetNetzOut | None = None
    ssd: GeraetSsdOut | None = None
    docker_platz: GeraetDockerPlatzOut | None = None


class GeraetSicherungOut(BaseModel):
    letzte: str | None = None
    letzte_am: datetime | None = None
    letzte_bytes: int | None = None
    anzahl: int = 0
    #: Alle Sicherungen auf dem Gerät zusammen.
    gesamt_bytes: int | None = None
    #: Das rclone-Ziel für die Kopie außer Haus; `None`: keine.
    ausser_haus: str | None = None
    ampel: Ampel = "aus"
    text_de: str = ""


class GeraetAktionOut(BaseModel):
    """Die zuletzt aus der App angefragte Aktion und wie sie ausging."""

    aktion: str
    dienst: str | None = None
    #: laeuft, ok, fehler
    zustand: str
    meldung: str = ""
    von: str | None = None
    begonnen_am: datetime | None = None
    beendet_am: datetime | None = None


class ApiSelbstOut(BaseModel):
    """Was die API über sich selbst weiß; auch ohne Hausgerät (Railway) vorhanden."""

    version: str
    commit: str
    modus: str
    laufzeit_s: int
    rss_mb: float
    datenbank_ok: bool | None = None
    datenbank_ms: float | None = None
    datenbank_de: str = ""
    #: Größe der Datenbank auf der Platte; `None` ohne PostgreSQL.
    datenbank_bytes: int | None = None
    bridge_online: bool = False
    verbindung_de: str = ""
    quellen: list[SourceStatusOut] = Field(default_factory=list)
    befunde: list[WatchFindingOut] = Field(default_factory=list)
    sse_clients: int = 0
    alfred_eingerichtet: bool = False
    energy_rebuild: str = ""
    ampel: Ampel = "gut"
    text_de: str = ""


class GeraetOut(BaseModel):
    """Die Seite Hausgerät: Rechner, Dienste, Zeitgeber, Sicherung, API und die letzte Aktion."""

    #: Falsch ohne Hausgerät (Railway, Entwicklung): Dann gibt es nur `api`.
    unterstuetzt: bool
    bericht_am: datetime | None = None
    #: Wahr, wenn der letzte Bericht älter als drei Minuten ist: Der Zeitgeber auf dem Gerät
    #: läuft dann nicht, und alle Werte darunter sind von damals.
    bericht_alt: bool = False
    kanal: str | None = None
    fernzugang: bool = False
    #: Falsch, wenn Docker auf dem Gerät nicht antwortet; dann laufen keine Dienste.
    docker_laeuft: bool | None = None
    rechner: GeraetRechnerOut | None = None
    dienste: list[GeraetDienstOut] = Field(default_factory=list)
    einheiten: list[GeraetEinheitOut] = Field(default_factory=list)
    sicherung: GeraetSicherungOut | None = None
    letzte_aktion: GeraetAktionOut | None = None
    #: Warum gerade keine Aktion angenommen wird (Update läuft, Anfrage offen); `None`: frei.
    beschaeftigt: str | None = None
    api: ApiSelbstOut
    #: Das Gesamturteil: das schlechteste aller Einzelurteile, mit dem Grund.
    ampel: Ampel = "gut"
    text_de: str = ""


class GeraetAktionIn(BaseModel):
    aktion: Literal["neustart", "sichern", "protokoll", "geraet_neustart", "zustand"]
    #: Für `neustart` und `protokoll`: der Dienst aus compose.yaml, für `neustart` auch `alle`.
    dienst: str | None = Field(default=None, pattern=r"^[a-z][a-z0-9_-]{0,30}$")


class GeraetProtokollOut(BaseModel):
    dienst: str
    vorhanden: bool
    erstellt_am: datetime | None = None
    zeilen: list[str] = Field(default_factory=list)


class GeraetVerlaufDienstOut(BaseModel):
    cpu_prozent: float | None = None
    speicher_mb: float | None = None


class GeraetVerlaufPunktOut(BaseModel):
    """Ein Abschnitt im Verlauf: Mittel, Spitzen und Stände am Ende des Abschnitts."""

    t: datetime
    cpu_prozent: float | None = None
    cpu_prozent_max: float | None = None
    last1: float | None = None
    temperatur_c: float | None = None
    temperatur_c_max: float | None = None
    takt_mhz: float | None = None
    eingangsspannung_v: float | None = None
    eingangsspannung_v_min: float | None = None
    speicher_belegt_mb: float | None = None
    speicher_gesamt_mb: float | None = None
    swap_belegt_mb: float | None = None
    platte_belegt_bytes: int | None = None
    platte_gesamt_bytes: int | None = None
    ssd_temperatur_c: float | None = None
    ssd_temperatur_c_max: float | None = None
    ssd_abnutzung_prozent: float | None = None
    #: In diesem Abschnitt auf die SSD geschrieben.
    ssd_geschrieben_bytes: int = 0
    netz_empfangen_bytes_s: float = 0.0
    netz_gesendet_bytes_s: float = 0.0
    datenbank_bytes: int | None = None
    sicherung_bytes: int | None = None
    docker_bytes: int | None = None
    #: Wurde in diesem Abschnitt gedrosselt oder war die Spannung zu niedrig?
    drosselung_jetzt: bool = False
    dienste: dict[str, GeraetVerlaufDienstOut] = Field(default_factory=dict)


class GeraetPrognoseOut(BaseModel):
    """Wachstum je Tag über die letzten 30 Tage (eine Gerade durch die Füllstände), erst ab
    sieben Tagen Verlauf. Eine Schätzung „bei diesem Tempo“, kein Termin."""

    tage_verlauf: float = 0.0
    platte_bytes_pro_tag: int | None = None
    platte_voll_in_tagen: int | None = None
    datenbank_bytes_pro_tag: int | None = None
    sicherung_bytes_pro_tag: int | None = None
    ssd_geschrieben_bytes_pro_tag: int | None = None


class GeraetVerlaufOut(BaseModel):
    unterstuetzt: bool
    spanne: Literal["tag", "woche", "monat", "jahr"] = "tag"
    von: datetime | None = None
    bis: datetime | None = None
    schritt_min: int = 5
    punkte: list[GeraetVerlaufPunktOut] = Field(default_factory=list)
    prognose: GeraetPrognoseOut = Field(default_factory=GeraetPrognoseOut)


# ---------------------------------------------------------------------------
# Anmeldung mit Passkey, Sitzungen, Personen (ADR-0002)
# ---------------------------------------------------------------------------


class ZeremonieOut(BaseModel):
    """Der Beginn einer WebAuthn-Zeremonie.

    `optionen` ist der JSON-Text, den `navigator.credentials` erwartet - unverändert
    weiterzugeben. `schritt` kommt mit der Antwort des Geräts zurück und bindet sie an ihre
    Challenge.
    """

    schritt: str
    optionen: str


class AusweisOut(BaseModel):
    """Wer gerade fragt. Die Oberfläche blendet danach aus, was die Rolle nicht darf - verboten
    wird es am Dienst (`dch_api/auth/rechte.py`)."""

    art: Literal["person", "geraet", "gast", "dienst"]
    rolle: Literal["hausherr", "bewohner", "gast", "service"]
    person_id: str = ""
    name: str = ""
    email: str = ""


class AngemeldetOut(BaseModel):
    """Das Ergebnis einer Anmeldung.

    `token` ist der Ausweis im Klartext und existiert genau hier einmal. Das BFF legt ihn in ein
    HttpOnly-Cookie und gibt ihn nie an den Browser weiter; eine App legt ihn in den
    Schlüsselbund.
    """

    token: str
    laeuft_ab_am: datetime
    ausweis: AusweisOut
    #: Nach dem Einlösen eines Einladungslinks, mit Passkey oder Passwort: die zehn
    #: Wiederherstellungscodes, einmalig im Klartext.
    codes: list[str] = Field(default_factory=list)


class PasskeyOut(BaseModel):
    id: str
    name: str
    #: Ob der Passkey in einer Wolke gesichert ist (iCloud, Google) - dann liegt er auf mehreren
    #: Geräten und ein verlorenes Telefon sperrt niemanden aus.
    gesichert: bool
    erstellt_am: datetime
    zuletzt_benutzt_am: datetime | None = None


class SitzungOut(BaseModel):
    id: str
    erstellt_am: datetime
    laeuft_ab_am: datetime
    zuletzt_benutzt_am: datetime | None = None
    herkunft: str = ""
    #: Ob das die Sitzung ist, mit der gerade gefragt wird.
    diese: bool = False


class PersonOut(BaseModel):
    id: str
    email: str
    anzeigename: str = ""
    rolle: Literal["hausherr", "bewohner", "gast", "service"]
    aktiv: bool = True
    erstellt_am: datetime
    zuletzt_angemeldet_am: datetime | None = None
    passkeys: int = 0
    #: Ob die Person ein Passwort hat.
    passwort: bool = False
    codes_offen: int = 0
    einladung_offen: bool = False


class IchOut(BaseModel):
    """Die eigene Seite: wer ich bin, welche Passkeys und welche Sitzungen ich habe."""

    ausweis: AusweisOut
    passkeys: list[PasskeyOut] = Field(default_factory=list)
    sitzungen: list[SitzungOut] = Field(default_factory=list)
    codes_offen: int = 0
    #: Ob ich ein Passwort habe. Entscheidet, ob die Seite „vergeben" oder „ändern" anbietet.
    passwort: bool = False


class VersandOut(BaseModel):
    """Ob eine Einladung per E-Mail hinausgehen kann - und was sonst fehlt."""

    aktiv: bool = False
    weg: Literal["smtp", "https", ""] = ""
    fehlt: list[str] = Field(default_factory=list)


class ZugangZustandOut(BaseModel):
    """Was die Oberfläche über die Anmeldung wissen muss, bevor jemand angemeldet ist.

    Öffentlich und mit Absicht wortkarg: `personen` ist eine Zahl, keine Liste. Dass es noch
    niemanden gibt, muss die Anmeldeseite sagen können - wer das ist, braucht sie nicht.
    """

    anmeldung: bool = False
    personen: int = 0
    rp_id: str = ""
    versand: VersandOut = Field(default_factory=VersandOut)
    #: Wie lang ein Passwort mindestens sein muss. Steht hier, damit die Anmeldeseite und die
    #: Seite hinter dem Einladungslink die Regel nennen können, ohne sie selbst zu kennen.
    passwort_mindestlaenge: int = 12


class PersonAnlegenIn(BaseModel):
    email: str
    anzeigename: str = ""
    rolle: Literal["hausherr", "bewohner", "gast", "service"] = "bewohner"
    #: Ob die Einladung gleich per E-Mail hinausgehen soll. Der Link kommt in jedem Fall zurück.
    einladen: bool = True


class EinladenIn(BaseModel):
    """Einen neuen Link ausstellen. Die Person steht in der Adresse, nicht hier."""

    #: Ob er zusätzlich per E-Mail hinausgehen soll. Zurück kommt er in jedem Fall.
    einladen: bool = True


class PersonAendernIn(BaseModel):
    rolle: Literal["hausherr", "bewohner", "gast", "service"] | None = None
    aktiv: bool | None = None
    anzeigename: str | None = None


class EinladungOut(BaseModel):
    """Der Einladungslink - einmal, im Klartext, zum Kopieren oder Verschicken."""

    person: PersonOut
    link: str
    laeuft_ab_am: datetime
    verschickt: bool = False


class EinladungPersonOut(BaseModel):
    """Für die Seite hinter dem Link: zu wem er gehört und welche Wege herein es schon gibt."""

    email: str
    anzeigename: str = ""
    rolle: Literal["hausherr", "bewohner", "gast", "service"]
    passkeys: int = 0
    passwort: bool = False


class PasskeyBeginnenIn(BaseModel):
    #: Nur für den Weg über den Einladungslink; angemeldet bleibt es leer.
    token: str = ""


class PasskeyAbschliessenIn(BaseModel):
    schritt: str
    #: Die Antwort des Geräts, wie `@simplewebauthn/browser` sie liefert.
    antwort: dict[str, Any]
    name: str = ""
    token: str = ""


class AnmeldenIn(BaseModel):
    schritt: str
    antwort: dict[str, Any]


class WiederherstellenIn(BaseModel):
    email: str
    code: str


class PasswortAnmeldenIn(BaseModel):
    email: str
    passwort: str


class PasswortUeberLinkIn(BaseModel):
    """Das Passwort hinter dem Einladungslink vergeben."""

    token: str
    passwort: str


class PasswortEntfernenIn(BaseModel):
    """Das eigene Passwort entfernen. Verlangt das bisherige, wie das Wechseln."""

    bisher: str


class PasswortSetzenIn(BaseModel):
    """Das eigene Passwort vergeben oder wechseln."""

    neu: str
    #: Das bisherige Passwort. Leer, solange die Person noch keines hat.
    bisher: str = ""


class NameIn(BaseModel):
    name: str


class HandeingriffOut(BaseModel):
    """Etwas, das gerade von Hand gestellt ist und von der Automatik abweicht."""

    #: Wovon der Eingriff handelt.
    art: Literal["waermepumpe", "ofen", "speicher", "raum"]
    #: Die Seite, auf der man ihn sieht und ändert (`docs/seitenbaum.json`).
    weg: str
    #: Was gestellt ist, als Satz.
    satz_de: str
    #: Bis wann er gilt. `None`, wenn er nicht von selbst endet.
    bis: datetime | None = None
    #: Ob „Alles zurück auf Automatik“ ihn beendet. Ein Raum, den jemand von Hand gestellt hat,
    #: bleibt: sein Sollwert ist eine Vorgabe und kein Eingriff, und die Ruhe der Automatik
    #: endet von selbst.
    zuruecksetzbar: bool = False


class HandeingriffeOut(BaseModel):
    """Was gerade von Hand gestellt ist, oben auf der Seite „Einstellen“."""

    eingriffe: list[HandeingriffOut] = Field(default_factory=list)


class AutomatikZurueckOut(BaseModel):
    """Das Ergebnis von „Alles zurück auf Automatik“."""

    #: Ob alles zurückgestellt ist. Ein Gerät, das nicht antwortet, macht es `False`.
    ok: bool
    meldung_de: str
    #: Die Liste danach, damit die Seite nicht noch einmal fragen muss.
    handeingriffe: HandeingriffeOut


class UebersichtBildOut(BaseModel):
    """Das kleine Bild einer Kachel: eine Form, die sich auf einen Blick lesen lässt.

    Vier Arten, damit Dashboard und App dasselbe zeichnen und keine eine fünfte erfindet:

    - `balken`: der Verlauf des heutigen Tages in Stunden, `werte` in kWh je Stunde. Eine Stunde,
      die noch nicht war, fehlt am Ende; die Kachel zeichnet immer 24 Plätze.
    - `fuellung`: ein Füllstand, `anteil` von 0 bis 1.
    - `abweichung`: eine Abweichung nach unten oder oben, `anteil` von -1 bis 1.
    - `streifen`: was im Horizont geplant ist, `werte` je Abschnitt 1 für „angefordert", sonst 0.

    Das Bild ist Beigabe und trägt keine Zahl, die nicht auch als Leitzahl dasteht.
    """

    art: Literal["balken", "fuellung", "abweichung", "streifen"]
    werte: list[float] = Field(default_factory=list)
    anteil: float | None = None


class UebersichtKarteOut(BaseModel):
    """Eine Karte der Bereichsübersicht: die wichtigste Zahl einer Seite und ihr Zustand.

    Der Dienst rechnet und formuliert, damit Dashboard und App nachweislich dasselbe zeigen. Die
    Karte selbst (Name der Seite, der feste Satz dazu) steht im Seitenbaum; hier steht nur, was
    sich mit der Zeit ändert.
    """

    #: Die Adresse der Seite, wie sie in `docs/seitenbaum.json` steht.
    weg: str
    #: Die Leitzahl als fertiger Text mit Einheit. `None`, wenn es gerade keinen Wert gibt.
    leitzahl_de: str | None = None
    #: Wozu die Zahl gehört, als Wortgruppe unter ihr.
    dazu_de: str = ""
    #: `gut` heißt: nichts zu tun. `warn` heißt: ansehen. `schlecht` heißt: gestört. `aus` heißt:
    #: gerade keine Auskunft.
    ampel: Ampel = "aus"
    #: Der Grund für eine Ampel, die nicht `gut` ist, als Satz. Sonst leer.
    grund_de: str = ""
    #: Das kleine Bild der Kachel. `None`, wenn die Seite keines hat oder gerade keine Werte.
    bild: UebersichtBildOut | None = None


class UebersichtOut(BaseModel):
    """Die Karten eines Bereichs. Eine Seite ohne Karte hat nichts, was sich mit der Zeit ändert."""

    bereich: str
    karten: list[UebersichtKarteOut] = Field(default_factory=list)
