"""Das Anlagenschema zusammensetzen: aus Live-Zustand, Räumen und Minutenreihe eine Antwort.

Reine Zusammensetzung, kein I/O. Beide Runtimes rufen `zusammensetzen` mit dem, was sie haben; was
eine nicht hat, kommt als fehlende Messung herein und geht als `present=False` oder `None` hinaus.
Die Vorführung hat keinen Ofen und keinen Warmwasserfühler, und ihr Schema sagt das auch.

**Zwei Rückblicke in die Minutenreihe**, sonst nur der Augenblick: Die Nettoleistung des Speichers
braucht eine Viertelstunde Temperaturen, die Zapferkennung die letzten Minuten des Auslassfühlers.
Beides rechnet `hems_core.thermal.anlage`; hier werden nur die Zeilen in Proben übersetzt.

**Der Warmwasserfühler** ist ein Anlegefühler am warmen Auslass oben am Speicher, den es noch
nicht gibt. Sobald die Brücke ihn unter `DHW_OUTLET` liefert, erscheint er; bis dahin bleibt die
Kachel gedimmt. Ein zweiter am Kaltwasserzulauf (`DHW_INLET`) ist freiwillig.
"""

from __future__ import annotations

from datetime import datetime

from dch_api.schemas import (
    AnlageHeizkreisOut,
    AnlageOfenOut,
    AnlageOut,
    AnlageSpeicherOut,
    AnlageStromOut,
    AnlageWaermepumpeOut,
    AnlageWarmwasserOut,
    RoomsLiveOut,
    StoveLiveOut,
)
from hems_core.domain import (
    BufferConfig,
    BufferState,
    EnergySnapshot,
    HeatPumpState,
    HemsConfig,
    Measurement,
)
from hems_core.domain.config import StoveConfig
from hems_core.thermal import TempProbe, buffer_net_kw, netto_wort, stove_output_kw, zapfung

DHW_OUTLET = "dhw_outlet_temp_c"
DHW_INLET = "dhw_inlet_temp_c"
#: Wie weit die Minutenreihe zurückgelesen wird: genug für die Nettoleistung (eine Viertelstunde
#: plus erlaubte Lücke) und für eine Zapfung, die vor über einer Stunde begann und noch läuft.
RUECKBLICK_MIN = 120
BUFFER_KEYS = (
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
)
#: Welche Reihen die Rückblicke brauchen.
KEYS = [*BUFFER_KEYS, DHW_OUTLET]
#: Älter darf ein Einzelwert nicht sein. Die Pufferfühler melden minütlich, der Ofen alle
#: 15 Sekunden, ein Anlegefühler über Home Assistant bei jeder Änderung.
STALE_S = 900.0
#: Unter diesem Anteil zählt der Strom im Knoten nicht mehr als Quelle.
QUELLE_MIN_KW = 0.05

Zeile = dict[str, float | str | None]


def _zeit(ts: object) -> datetime:
    return datetime.fromisoformat(str(ts).replace("Z", "+00:00"))


def _wert(m: Measurement) -> float | None:
    return m.value if m.usable else None


def proben(zeilen: list[Zeile]) -> list[TempProbe]:
    """Minutenzeilen zu Speicherproben; eine Minute ohne alle vier Fühler fällt weg."""
    out: list[TempProbe] = []
    for z in zeilen:
        werte = [z.get(k) for k in BUFFER_KEYS]
        if all(isinstance(w, int | float) for w in werte):
            out.append(TempProbe(at=_zeit(z["ts"]), temps=tuple(float(w) for w in werte)))  # type: ignore[arg-type]
    return out


def punkte(zeilen: list[Zeile], key: str) -> list[tuple[datetime, float]]:
    return [(_zeit(z["ts"]), float(w)) for z in zeilen if isinstance(w := z.get(key), int | float)]


def strom(snap: EnergySnapshot) -> AnlageStromOut:
    """Die Stromseite. Batterie positiv heißt entladen, Netz positiv heißt Bezug, wie überall."""
    pv, grid, bat = (
        _wert(snap.pv_power_kw),
        _wert(snap.grid_power_kw),
        _wert(snap.battery_power_kw),
    )
    house, hp = _wert(snap.house_power_kw), _wert(snap.heat_pump_power_kw)
    rest = round(max(0.0, house - hp), 3) if house is not None and hp is not None else None
    quellen = [max(0.0, pv or 0.0), max(0.0, grid or 0.0), max(0.0, bat or 0.0)]
    summe = sum(quellen)
    anteile = [round(q / summe, 3) for q in quellen] if summe >= QUELLE_MIN_KW else [0.0] * 3
    return AnlageStromOut(
        pv_kw=pv,
        grid_kw=grid,
        battery_kw=bat,
        battery_soc=_wert(snap.battery_soc),
        house_kw=house,
        heat_pump_kw=hp,
        rest_kw=rest,
        share_pv=anteile[0],
        share_grid=anteile[1],
        share_battery=anteile[2],
    )


def waermepumpe(hp: HeatPumpState, snap: EnergySnapshot) -> AnlageWaermepumpeOut:
    """Nur Strom und Takt. Wärme, Vorlauf und COP kommen mit dem Bus; bis dahin stehen sie leer."""
    return AnlageWaermepumpeOut(
        running=hp.running,
        running_since=hp.running_since,
        power_kw=_wert(snap.heat_pump_power_kw),
        thermal_kw=None,
        flow_c=None,
        cop=None,
    )


def ofen(
    stove: StoveLiveOut, cfg: StoveConfig, ruecklauf: Measurement, pumpe: Measurement
) -> AnlageOfenOut:
    if not stove.present:
        return AnlageOfenOut(
            present=False,
            running=None,
            power_level=None,
            flow_c=None,
            return_c=None,
            pump_pct=None,
            water_kw=None,
        )
    wasser: float | None = None
    if stove.running is not None:
        wasser = stove_output_kw(stove.power_level, cfg)[0] if stove.running else 0.0
    return AnlageOfenOut(
        present=True,
        running=stove.running,
        power_level=stove.power_level,
        flow_c=stove.boiler_temp_c,
        return_c=_wert(ruecklauf),
        pump_pct=_wert(pumpe),
        water_kw=wasser,
    )


def speicher(
    snap: EnergySnapshot, buffer: BufferState, cfg: BufferConfig, zeilen: list[Zeile], now: datetime
) -> AnlageSpeicherOut:
    """Das Glas. Die Nettoleistung nimmt die Minutenreihe und den Augenblick zusammen: die Reihe
    endet an der letzten abgeschlossenen Minute, der Augenblick ist frischer."""
    messungen = snap.buffer_temps_c.as_list()
    temps = [_wert(m) for m in messungen]
    reihe = proben(zeilen)
    bekannt = [t for t in temps if t is not None]
    if len(bekannt) == len(temps):
        reihe.append(TempProbe(at=max(m.observed_at for m in messungen), temps=tuple(bekannt)))
    netto = buffer_net_kw(reihe, cfg, now)
    return AnlageSpeicherOut(
        temps_c=temps,
        soc=buffer.soc,
        usable_kwh=buffer.usable_energy_kwh,
        capacity_kwh=buffer.capacity_kwh,
        volume_liters=buffer.volume_liters,
        net_kw=netto,
        net_word=netto_wort(netto),
        return_c=temps[3],
    )


def heizkreis(raeume: RoomsLiveOut) -> AnlageHeizkreisOut:
    """Wie viele Räume nehmen gerade Wärme: ein Raum mit irgendeinem offenen Kreis zählt."""
    bekannt = [r.valve for r in raeume.rooms if r.valve is not None]
    offen = sum(1 for v in bekannt if v > 0)
    return AnlageHeizkreisOut(
        rooms_total=len(raeume.rooms),
        rooms_open=offen,
        open_share=round(sum(bekannt) / len(bekannt), 3) if bekannt else None,
        running=offen > 0,
    )


def warmwasser(
    auslass: Measurement, zulauf: Measurement, zeilen: list[Zeile], now: datetime
) -> AnlageWarmwasserOut:
    aus = _wert(auslass)
    if aus is None:
        return AnlageWarmwasserOut(
            present=False, outlet_c=None, inlet_c=_wert(zulauf), tapping=None, tapping_since=None
        )
    z = zapfung([*punkte(zeilen, DHW_OUTLET), (auslass.observed_at, aus)], now)
    return AnlageWarmwasserOut(
        present=True, outlet_c=aus, inlet_c=_wert(zulauf), tapping=z.aktiv, tapping_since=z.seit
    )


def zusammensetzen(
    *,
    now: datetime,
    snap: EnergySnapshot,
    buffer: BufferState,
    hp: HeatPumpState,
    cfg: HemsConfig,
    stove: StoveLiveOut,
    stove_return: Measurement,
    stove_pump: Measurement,
    dhw_outlet: Measurement,
    dhw_inlet: Measurement,
    raeume: RoomsLiveOut,
    zeilen: list[Zeile],
) -> AnlageOut:
    return AnlageOut(
        at=now,
        outdoor_c=_wert(snap.outdoor_temp_c),
        strom=strom(snap),
        waermepumpe=waermepumpe(hp, snap),
        ofen=ofen(stove, cfg.stove, stove_return, stove_pump),
        speicher=speicher(snap, buffer, cfg.buffer, zeilen, now),
        heizkreis=heizkreis(raeume),
        warmwasser=warmwasser(dhw_outlet, dhw_inlet, zeilen, now),
    )
