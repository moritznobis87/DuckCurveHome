"""LiveState: letzter Wert je Schlüssel → EnergySnapshot mit Bilanz und Alterung."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, replace
from datetime import UTC, datetime

from hems_core.balance import balance, pv_bei_nacht
from hems_core.domain import BufferTemperatures, EnergySnapshot, HemsConfig, Measurement, Quality
from hems_core.protocol import RawReading

POWER_KEYS = (
    "pv_power_kw",
    "grid_power_kw",
    "battery_power_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
)


@dataclass(frozen=True)
class Stillstandsspur:
    """Wie lange ein Schlüssel schon denselben Wert meldet - und wie oft er ihn gemeldet hat.

    **Warum das mitgeführt wird.** Die Alterung am Messwert sieht nur den Zeitstempel: ein toter,
    aber plappernder Fühler bleibt damit für immer `ok` (siehe `hems_core.watch.stillstand`). Um
    das zu bemerken, braucht es die eine Auskunft, die der letzte Wert allein nicht hat - seit
    wann er sich nicht mehr bewegt. Vier Zahlen je Schlüssel genügen dafür; eine Zeitreihe aus der
    Datenbank wäre für dieselbe Aussage eine Abfrage je Antwort.

    `bis` ist die **letzte Meldung** dieses Werts und nicht „jetzt": die Zeit nach der letzten
    Meldung ist Stille, und die hat ihre eigene Regel.
    """

    wert: float
    seit: datetime
    bis: datetime
    meldungen: int

    @property
    def unveraendert_min(self) -> float:
        return (self.bis - self.seit).total_seconds() / 60.0


class LiveState:
    def __init__(
        self, cfg: HemsConfig, sonnenhoehe: Callable[[datetime], float] | None = None
    ) -> None:
        self.cfg = cfg
        #: Sonnenhöhe in Grad am Ort des Hauses. Damit wird eine nachts fehlende Erzeugung zu
        #: null statt zu einer Lücke (`pv_bei_nacht`). Ohne sie bleibt alles wie gemeldet.
        self.sonnenhoehe = sonnenhoehe
        self.readings: dict[str, RawReading] = {}
        #: Je Schlüssel: seit wann derselbe Wert gemeldet wird (siehe `Stillstandsspur`).
        self.unchanged: dict[str, Stillstandsspur] = {}
        self.updated_at: datetime | None = None

    def apply(self, items: list[RawReading]) -> None:
        for r in items:
            cur = self.readings.get(r.key)
            # Eine leere Meldung (unavailable/unknown) einer anderen Quelle verdrängt keinen gültigen Wert:
            # liefert myenergi PV direkt, darf der ausgefallene HA-Sensor ihn nicht auf „-“ setzen.
            if (
                r.value is None
                and cur is not None
                and cur.value is not None
                and (cur.source or "") != (r.source or "")
            ):
                continue
            if cur is None or r.observed_at >= cur.observed_at:
                self.readings[r.key] = r
                self._spur(r)
        self.updated_at = datetime.now(UTC)

    def _spur(self, r: RawReading) -> None:
        """Die Stillstandsspur eines Schlüssels nachführen.

        Verglichen wird auf Gleichheit und nicht auf „fast gleich": Ein Fühler, der sich um eine
        Stelle bewegt, lebt. Die Frage ist nicht, ob er sich *genug* bewegt, sondern ob überhaupt.
        """
        if r.value is None:
            # Eine Lücke ist kein Stillstand. Der nächste Wert fängt die Spur neu an - sonst
            # überspannte sie einen Ausfall und meldete danach einen Fühler, der nur geschwiegen
            # hat.
            self.unchanged.pop(r.key, None)
            return
        spur = self.unchanged.get(r.key)
        if spur is not None and spur.wert == r.value:
            self.unchanged[r.key] = replace(
                spur, bis=max(spur.bis, r.observed_at), meldungen=spur.meldungen + 1
            )
        else:
            self.unchanged[r.key] = Stillstandsspur(
                wert=r.value, seit=r.observed_at, bis=r.observed_at, meldungen=1
            )

    def zuletzt_gesehen(self, now: datetime) -> dict[str, datetime | None]:
        """Wann zu jedem Schlüssel zuletzt etwas **bekannt** war - die Vorlage für den Wächter.

        Nicht einfach `observed_at` je Meldung, sondern mit derselben Ausnahme, die auch der
        Snapshot kennt: **Nachts ist eine fehlende Erzeugung null und keine Lücke**
        (`pv_bei_nacht`). Wechselrichter schlafen, und manche Quellen melden dann gar nichts mehr.

        **Warum das hier stehen muss.** Seit dem 22.11.2026 fällt eine Gruppenregel des Wächters
        nach dem Schlüssel, der am längsten schweigt - vorher deckte der jüngste die anderen zu.
        Richtig so, nur gilt es auch für `power` (Erzeugung, Netz, Speicher), und damit stand
        zwanzig Minuten nach Sonnenuntergang ein **Alarm** auf dem einen Platz des Ruhebilds, jede
        Nacht bis zum Sonnenaufgang - während der Dienst zwei Module weiter festhält, dass dieser
        Wert nachts bekannt ist. Ausgeführt am Prüfstand: `pv_power_kw` 200 Minuten still, alles
        andere frisch, Ergebnis „Die Leistungen sind unvollständig: 1 von 3 Messstellen schweigt
        seit 3 Stunden."

        Die Ausnahme gehört deshalb dorthin, wo sie schon einmal steht, und nicht in die Regel:
        der Wächter fragt „wann war das zuletzt bekannt?", und die Antwort ist nachts „jetzt".
        Fällt der Wechselrichter mitten am Tag aus, meldet der Wächter ihn wie bisher; die
        Meldung verschwindet bei Sonnenuntergang und kommt beim Aufgang zurück, weil genau dann
        wieder etwas fehlt.
        """
        zuletzt: dict[str, datetime | None] = {k: r.observed_at for k, r in self.readings.items()}
        hoehe = self.sonnenhoehe(now) if self.sonnenhoehe else None
        pv = pv_bei_nacht(self._m("pv_power_kw", now, self.cfg.timeouts.power_s), now, hoehe)
        if pv.source and pv.source.startswith("nacht:"):
            zuletzt["pv_power_kw"] = now
        return zuletzt

    def _m(self, key: str, now: datetime, stale_after_s: float) -> Measurement:
        r = self.readings.get(key)
        if r is None:
            return Measurement.missing(Quality.UNAVAILABLE, now, key)
        m = Measurement(
            value=r.value, observed_at=r.observed_at, quality=r.quality, source=r.source or key
        )
        return m.aged(now, stale_after_s)

    def measurement(self, key: str, now: datetime, stale_after_s: float) -> Measurement:
        """Ein einzelner Schlüssel mit Alterung. Für Größen, die nicht im Snapshot stehen."""
        return self._m(key, now, stale_after_s)

    def snapshot(self, now: datetime | None = None) -> EnergySnapshot:
        now = now or datetime.now(UTC)
        t = self.cfg.timeouts
        pv = pv_bei_nacht(
            self._m("pv_power_kw", now, t.power_s),
            now,
            self.sonnenhoehe(now) if self.sonnenhoehe else None,
        )
        grid = self._m("grid_power_kw", now, t.power_s)
        bat = self._m("battery_power_kw", now, t.battery_s)
        hp = self._m("heat_pump_power_kw", now, t.power_s)
        ev = self._m("ev_power_kw", now, t.power_s)
        house_measured = (
            self._m("house_power_kw", now, t.power_s) if "house_power_kw" in self.readings else None
        )
        b = balance(
            now=now,
            pv=pv,
            grid=grid,
            battery=bat,
            heat_pump=hp,
            ev=ev,
            house_measured=house_measured,
            cfg=self.cfg.balance,
        )
        actuators = {
            k.removeprefix("actuator:"): self._m(k, now, 3600.0)
            for k in self.readings
            if k.startswith("actuator:")
        }
        return EnergySnapshot(
            timestamp=now,
            pv_power_kw=pv,
            grid_power_kw=grid,
            battery_power_kw=bat,
            battery_soc=self._m("battery_soc", now, t.battery_s),
            house_power_kw=b.house_power_kw,
            base_load_kw=b.base_load_kw,
            heat_pump_power_kw=hp,
            ev_power_kw=ev,
            electricity_price_ct_kwh=self._m("electricity_price_ct_kwh", now, t.price_s),
            outdoor_temp_c=self._m("outdoor_temp_c", now, 3 * 3600.0),
            buffer_temps_c=BufferTemperatures(
                top=self._m("buffer_temp_top_c", now, t.temperature_s),
                mid_top=self._m("buffer_temp_mid_top_c", now, t.temperature_s),
                mid_bottom=self._m("buffer_temp_mid_bottom_c", now, t.temperature_s),
                bottom=self._m("buffer_temp_bottom_c", now, t.temperature_s),
            ),
            hp_release_contact=self._m("actuator:hp_release_contact", now, 3600.0),
            hp_block_contact=self._m("actuator:hp_block_contact", now, 3600.0),
            actuators=actuators,
            balance_residual_kw=b.residual_kw,
        )
