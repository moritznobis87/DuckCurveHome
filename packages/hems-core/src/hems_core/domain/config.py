"""Konfiguration der Regelung und der thermischen Modelle.

Alle Werte sind Defaults und werden aus YAML/Env überschrieben (CONFIGURATION.md).
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class HeatPumpConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    minimum_electric_power_kw: float = 3.5
    nominal_electric_power_kw: float = 4.5
    nominal_thermal_power_kw: float = 12.0
    running_threshold_kw: float = 0.5
    running_debounce_s: int = 60
    min_runtime_min: int = 30
    min_offtime_min: int = 20
    start_timeout_min: int = 10
    max_starts_per_day: int = 8
    release_ttl_min: int = 20
    hw_auto_off_release_s: int = 1800
    hw_auto_off_block_s: int = 1200


class PvRuleConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    on_surplus_kw: float = 4.0
    off_import_kw: float = 1.5
    on_delay_min: float = 5.0
    off_delay_min: float = 10.0
    count_battery_charging_above_soc: float = 0.8
    heat_pump_before_ev: bool = False
    min_buffer_headroom_soc: float = 0.10


class PriceRuleConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    negative_price_release: bool = True
    cheap_quantile: float = 0.10
    min_window_min: int = 30
    price_max_age_h: float = 30.0
    expensive_quantile: float = 0.85


class BlockRuleConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    enabled: bool = False
    max_duration_min: int = 120
    max_per_day: int = 2
    min_soc: float = 0.6
    min_outdoor_temp_c: float = 3.0
    block_ttl_min: int = 15


class ControlConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    tick_s: int = 10
    ewma_seconds: float = 180.0
    sensor_grace_min: float = 5.0
    max_toggles_per_hour: int = 4
    failsafe_hold_min: int = 60
    pv: PvRuleConfig = PvRuleConfig()
    price: PriceRuleConfig = PriceRuleConfig()
    block: BlockRuleConfig = BlockRuleConfig()


class BufferConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    # Kombipuffer: Wärmepumpe und Pelletofen speisen ein, Heizung und Warmwasser entnehmen
    volume_liters: float = 1000.0
    layers: list[float] = Field(default_factory=lambda: [0.25, 0.25, 0.25, 0.25])
    min_useful_temperature_c: float = 35.0
    target_temperature_c: float = 50.0
    max_temperature_c: float = 62.0
    comfort_min_top_c: float = 42.0
    loss_kw_per_k: float = 0.004
    soc_method: Literal["layered_energy_v1", "weighted_mean_v1"] = "layered_energy_v1"
    weights: list[float] = Field(default_factory=lambda: [0.25, 0.25, 0.25, 0.25])
    status_thresholds: tuple[float, float, float] = (0.2, 0.6, 0.9)  # cold|partial|warm|full
    soc_full: float = 0.95  # ab hier gilt „voll“ für den Regler


class BalanceConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    tolerance_kw: float = 0.3
    min_flow_kw: float = 0.05  # darunter gilt „kein Fluss“


class SensorTimeouts(BaseModel):
    model_config = ConfigDict(frozen=True)

    power_s: float = 180.0  # HA-Integrationen (myenergi, Shelly) melden teils nur alle 60-120 s
    battery_s: float = 180.0
    temperature_s: float = 900.0
    price_s: float = 3600.0 * 2


class TariffConfig(BaseModel):
    """Geldseite: Einspeisevergütung, Ersatzpreis und die umsatzsteuerliche Einordnung der Anlage.

    Netto und brutto sauber zu trennen ist hier keine Förmlichkeit: die Tibber-Preise der Zeitreihe sind
    Bruttopreise (Energie, Netz, Steuern, Abgaben - so zeigt Tibber sie), die Einspeisevergütung nach EEG
    ist ein Nettosatz, und die steuerliche Bemessungsgrundlage des Eigenverbrauchs ist ebenfalls netto.
    """

    model_config = ConfigDict(frozen=True)

    feed_in_ct_kwh: float = 7.41  # Einspeisevergütung netto laut Bescheid des Netzbetreibers
    fallback_import_ct_kwh: float = 30.0  # Ersatzpreis für Minuten ohne Preisdaten (brutto)
    vat_rate: float = 0.19  # Umsatzsteuersatz auf Einspeisung und unentgeltliche Wertabgabe
    price_includes_vat: bool = True  # Tibber liefert Bruttopreise
    small_business: bool = (
        False  # § 19 UStG: dann keine Umsatzsteuer, weder erhalten noch geschuldet
    )


class HeatDemandConfig(BaseModel):
    """Wärmebedarfsmodell v1 (Plan 20.2): Heizgradstunden, Warmwasserprofil, COP-Kennlinie."""

    model_config = ConfigDict(frozen=True)

    heat_loss_kw_per_k: float = 0.22  # H: Verlustkoeffizient des Hauses (Schätzung bis zur Messung)
    indoor_target_c: float = 21.0
    heating_limit_c: float = 15.0  # darüber keine Heizung
    internal_gains_kw: float = 0.4  # Personen, Geräte, Sonne
    dhw_kwh_per_day: float = 8.0  # Warmwasser thermisch je Tag
    # Gewichte je Stunde (0-23) für die Warmwasserentnahme, morgens und abends erhöht
    dhw_profile: list[float] = Field(
        default_factory=lambda: [
            0.2,
            0.1,
            0.1,
            0.1,
            0.2,
            0.6,
            1.6,
            2.2,
            1.8,
            1.0,
            0.8,
            0.8,
            0.9,
            0.7,
            0.6,
            0.6,
            0.8,
            1.2,
            1.8,
            2.0,
            1.6,
            1.0,
            0.6,
            0.3,
        ]
    )
    # COP über Außentemperatur bei Puffer-Zieltemperatur (Plan 20.1)
    cop_curve: list[tuple[float, float]] = Field(
        default_factory=lambda: [(-7.0, 2.4), (2.0, 3.0), (7.0, 3.5), (15.0, 4.2)]
    )


class StoveConfig(BaseModel):
    """Der Pelletofen als zweite Wärmequelle am selben Puffer.

    Die Zahlen stammen vom Gerät und vom Betreiber, nicht aus einer Messung; der Wärmemengenzähler
    steht noch aus. Sie sind trotzdem belastbar genug für eine Kostenentscheidung, weil der Ofen
    praktisch immer unter Volllast läuft und die Aufteilung zwischen Wasser und Raum dann fest ist.

    **Die Kette:** aus der Nennleistung und dem Verbrennungswirkungsgrad folgt die Feuerungsleistung,
    daraus über den Heizwert der Pelletdurchsatz, daraus über den Preis die Kosten je Stunde. Geteilt
    durch die Wärme, die tatsächlich ankommt, ergibt das den Wärmepreis, mit dem sich der Ofen gegen
    die Wärmepumpe vergleichen lässt. Gerechnet wird das in `hems_core.accounting.stove_cost`.
    """

    model_config = ConfigDict(frozen=True)

    present: bool = True
    # Ob der Planer den Ofen schalten darf. Bewusst aus: eine Feuerstätte fernzustarten ist eine
    # andere Klasse von Eingriff als ein Relais, und die Entscheidung gehört dem Hausherrn.
    control_enabled: bool = False

    # Datenblatt: MCZ STAR HYDROMATIC 12 M1, Rev. 09_2019.
    nominal_heat_kw: float = 11.9  # Nominale Nutzleistung, Wasser und Raum zusammen
    water_heat_kw: float = 10.0  # davon in den Pufferspeicher
    combustion_efficiency: float = 0.911  # Wirkungsgrad bei Maximalbetrieb
    # Teillast. Der Ofen ist dort **wirkungsgradbesser** (96,1 gegen 91,1 %), weil das Rauchgas
    # kühler abzieht: 48 statt 123 °C. Zugleich geht weniger davon ins Wasser, 1,8 von 3,2 kW statt
    # 10 von 11,9. Beides hebt sich im Wärmepreis fast genau auf, siehe stove_cost.
    min_heat_kw: float = 3.2
    min_water_heat_kw: float = 1.8
    min_combustion_efficiency: float = 0.961

    electric_w: float = 75.0  # Eigenverbrauch im Betrieb: Gebläse, Schnecke, Steuerung
    electric_ignition_w: float = 390.0  # Spitze beim Zünden (Zündwiderstand)

    # Gegenprobe für die gerechnete Kette, an beiden Lastpunkten.
    pellet_kg_per_hour_max: float = 2.7
    pellet_kg_per_hour_min: float = 0.7
    # 31 l Behälter, rund 0,65 kg/l Schüttdichte. Bei Volllast reicht das für gut sieben Stunden,
    # das Datenblatt nennt acht. Eine Nacht durchheizen geht also, zwei Nächte nicht: der Planer
    # darf keine Laufzeit einplanen, für die kein Brennstoff im Gerät ist.
    hopper_kg: float = 20.0

    pellet_price_eur_per_t: float = 450.0
    # 4,9 kWh/kg ist der Normwert für ENplus A1 bei 8 % Feuchte. Die Norm verlangt mindestens 4,6,
    # gute Ware liegt zwischen 4,9 und 5,3. Wer seinen Lieferschein hat, trägt den echten Wert ein.
    pellet_kwh_per_kg: float = 4.9

    # Wie viel der Raumwärme als Nutzen zählt. Der Ofen steht in der Küche und heizt sie mit 1,9 kW
    # mit; in der Heizperiode ersetzt das Wärme, die sonst die Wärmepumpe liefern müsste. Der
    # Hausherr rechnet die gesamte Nutzwärme an, also 1,0. Im Sommer oder bei ohnehin überheizter
    # Küche wäre 0 ehrlicher. Bei diesem Gerät ist der Unterschied klein, weil fast alles ins Wasser
    # geht: 10,3 gegen 12,2 ct/kWh.
    room_heat_credit: float = 1.0

    # Ein Ofen wird nicht für zwanzig Minuten angeworfen: Zünden kostet Strom und unverbrannte
    # Pellets, und jede Zündung zählt auf die Wartung.
    min_runtime_min: float = 120.0
    min_offtime_min: float = 60.0
    start_cost_eur: float = 0.10


class BatteryConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    capacity_kwh: float = 5.1  # myenergi libbi
    max_power_kw: float = 3.7


class HemsConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    heat_pump: HeatPumpConfig = HeatPumpConfig()
    control: ControlConfig = ControlConfig()
    buffer: BufferConfig = BufferConfig()
    balance: BalanceConfig = BalanceConfig()
    timeouts: SensorTimeouts = SensorTimeouts()
    tariff: TariffConfig = TariffConfig()
    heat_demand: HeatDemandConfig = HeatDemandConfig()
    battery: BatteryConfig = BatteryConfig()
    stove: StoveConfig = StoveConfig()
