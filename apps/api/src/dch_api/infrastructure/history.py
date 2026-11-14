"""In-Memory-Historie in 1-Minuten-Bins (Phase 1). Phase 2 ersetzt dies durch PostgreSQL."""

from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass, field
from datetime import datetime, timedelta

from hems_core.domain import EnergySnapshot

SERIES = (
    "pv_power_kw",
    "grid_power_kw",
    "battery_power_kw",
    "battery_soc",
    "house_power_kw",
    "base_load_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
    "electricity_price_ct_kwh",
    "outdoor_temp_c",
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
    "hp_release_contact",
    # Vorlauftemperatur des Waermepumpenkreises. Noch liefert sie niemand: in Home Assistant gibt
    # es laut Influx-Inventar eine Entitaet `vorlauf_temperature`, sie ist in entities.home.yaml
    # aber nicht zugeordnet, und der eBUS-Adapter ist erst gekauft.
    #
    # Die Reihe steht hier trotzdem, und das ist Absicht: sie ist die Senkentemperatur im COP, also
    # die Groesse, ohne die der Wirkungsgrad der Waermepumpe eine Annahme bleibt. Solange kein Wert
    # eintrifft, bleibt der Platz leer - als fehlende Messung mit Qualitaetsvermerk, nicht als NaN
    # in der Spalte: NaN ist in JSON nicht darstellbar und wuerde jedes Minutenmittel vergiften, in
    # dem es einmal auftaucht. Die Anzeige sagt dafuer "Vorlauf ?", und das ist dieselbe Aussage.
    "flow_temp_c",
    # Die Wärmepumpe über ihren eigenen Bus (eBUS, seit dem 13.11.2026). Vier Größen, die es
    # vorher nicht gab und aus denen sich zum ersten Mal eine Wärmeleistung rechnen lässt:
    # Durchfluss mal Spreizung zwischen Vorlauf (`flow_temp_c`) und Rücklauf.
    "heat_pump_flow_l_min",  # Durchflussmesser der Wärmepumpe, Liter je Minute
    "heat_pump_return_temp_c",  # Rücklauf; die Zuordnung der Kennung ist begründet, nicht bestätigt
    "heat_pump_flow_setpoint_c",  # Vorlauf-Sollwert, den der Regler der Maschine vorgibt
    "heat_pump_bus_power_kw",  # Leistungsaufnahme nach eigener Auskunft der Maschine
    "heat_pump_compressor_hz",  # Verdichterfrequenz: wie weit die Maschine gerade moduliert
    "heat_pump_mode_code",  # Betriebszustand als Zahl der Maschine: 3 heizt, 9 taut ab, 15 steht
    # Der Kältekreis und der Speicherfühler der Maschine, für die Technikseite der Wärmepumpe.
    "heat_pump_evaporator_temp_c",  # Verdampfer am Außengerät
    "heat_pump_suction_temp_c",  # Sauggas vor dem Verdichter
    "heat_pump_discharge_temp_c",  # Heißgas nach dem Verdichter
    "heat_pump_liquid_temp_c",  # Flüssigkeitsleitung zurück zum Außengerät
    "heat_pump_tank_temp_c",  # Speicherfühler der Wärmepumpe (Kennung 759e, Lesart nicht bestätigt)
    "heat_pump_cycle_code",  # Betriebsart des Reglers als Zahl: 2 Heizen, 3 Warmwasser, 16 PV
    # Pelletofen (MCZ Maestro). Zweite Wärmequelle am selben Puffer: ohne sie ist der Anteil
    # der Wärmepumpe an einer Pufferladung nicht zu beziffern.
    "stove_state",  # Zustandscode der Maestro-Firmware
    "stove_running",  # abgeleitet: erzeugt er gerade Wärme
    "stove_power_level",  # Leistungsstufe 1 bis 5
    "stove_fume_temp_c",  # Rauchgastemperatur, der ehrlichste Betriebsindikator
    "stove_fume_fan_rpm",  # Rauchgasgebläse
    "stove_auger_rpm",  # Förderschnecke: der Brennstoffeintrag
    "stove_boiler_temp_c",  # Vorlauf des Ofenkreises
    "stove_return_temp_c",  # Rücklauf des Ofenkreises
    "stove_buffer_temp_c",  # eigener Pufferfühler des Ofens
    "stove_ambient_temp_c",  # Raumfühler des Ofens
    "stove_pump_pct",  # Modulation der Ofenpumpe
    "stove_dhw_mode",  # Dreiwegeventil: 1 = Warmwasser
    "stove_operating_hours",  # Betriebsstundenzähler, monoton
    "stove_ignitions",  # Zündungszähler, monoton
    # Amtlicher Zähler (inexogy), zweite Meinung zum Netzanschluss. Die beiden Zählerstände sind
    # für den Vergleich die wichtigeren Zahlen als die Leistung: über eine Stunde gerechnet hebt
    # sich der Messversatz zwischen den Geräten auf, je Minute misst man vor allem ihn.
    "grid_power_meter_kw",
    "grid_import_meter_kwh",
    "grid_export_meter_kwh",
    # Haustür: ist der Weg zum Schloss offen (1) oder nicht (0). Keine Energiegröße, aber dieselbe
    # Frage wie beim Zähler - kommt an, was ankommen soll -, und damit dieselbe Karte.
    "door_lock_online",
)


@dataclass
class Bin:
    sums: dict[str, float] = field(default_factory=dict)
    counts: dict[str, int] = field(default_factory=dict)

    def add(self, key: str, value: float | None) -> None:
        if value is None:
            return
        self.sums[key] = self.sums.get(key, 0.0) + value
        self.counts[key] = self.counts.get(key, 0) + 1

    def mean(self, key: str) -> float | None:
        n = self.counts.get(key, 0)
        return round(self.sums[key] / n, 3) if n else None


class HistoryStore:
    def __init__(self, retention: timedelta) -> None:
        self.retention = retention
        self._bins: OrderedDict[datetime, Bin] = OrderedDict()

    @staticmethod
    def _values(s: EnergySnapshot) -> dict[str, float | None]:
        t = s.buffer_temps_c
        return {
            "pv_power_kw": s.pv_power_kw.value,
            "grid_power_kw": s.grid_power_kw.value,
            "battery_power_kw": s.battery_power_kw.value,
            "battery_soc": s.battery_soc.value,
            "house_power_kw": s.house_power_kw.value,
            "base_load_kw": s.base_load_kw.value,
            "heat_pump_power_kw": s.heat_pump_power_kw.value,
            "ev_power_kw": s.ev_power_kw.value,
            "electricity_price_ct_kwh": s.electricity_price_ct_kwh.value,
            "outdoor_temp_c": s.outdoor_temp_c.value,
            "buffer_temp_top_c": t.top.value,
            "buffer_temp_mid_top_c": t.mid_top.value,
            "buffer_temp_mid_bottom_c": t.mid_bottom.value,
            "buffer_temp_bottom_c": t.bottom.value,
            "hp_release_contact": s.hp_release_contact.value,
        }

    def add(self, s: EnergySnapshot) -> None:
        minute = s.timestamp.replace(second=0, microsecond=0)
        b = self._bins.get(minute)
        if b is None:
            b = Bin()
            self._bins[minute] = b
            self._prune(minute)
        for k, v in self._values(s).items():
            b.add(k, v)

    def _prune(self, now_minute: datetime) -> None:
        cutoff = now_minute - self.retention
        while self._bins and next(iter(self._bins)) < cutoff:
            self._bins.popitem(last=False)

    def series(self, start: datetime, end: datetime) -> list[dict[str, float | str | None]]:
        rows: list[dict[str, float | str | None]] = []
        for minute, b in self._bins.items():
            if start <= minute < end:
                row: dict[str, float | str | None] = {"ts": minute.isoformat()}
                for k in SERIES:
                    row[k] = b.mean(k)
                rows.append(row)
        return rows

    def energy_kwh(
        self, key: str, start: datetime, end: datetime, positive_only: bool = True
    ) -> float:
        total = 0.0
        for minute, b in self._bins.items():
            if start <= minute < end:
                v = b.mean(key)
                if v is None:
                    continue
                if positive_only:
                    v = max(0.0, v)
                total += v / 60.0
        return round(total, 3)
