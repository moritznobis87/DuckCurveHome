"""Rollierende Optimierung der Wärmepumpe als gemischt-ganzzahliges Programm (Stufe 3 des Plans).

Der regelbasierte Planer legt Freigabefenster in die günstigen Viertelstunden. Er tut das gierig:
er sieht ein Fenster, findet es billig, belegt es. Was er nicht kann, ist abwägen -- ob es sich
lohnt, jetzt teurer zu laden, um in sechs Stunden eine noch teurere Phase zu überspringen, und ob
der Puffer das überhaupt trägt. Genau das ist die Aufgabe eines Optimierers: nicht jede Stunde für
sich zu bewerten, sondern den ganzen Horizont auf einmal.

Modell (Zeitschritt 15 min, Horizont 24 bis 36 h):

Variablen je Intervall t
    on[t]    in {0,1}   Wärmepumpe läuft
    start[t] in {0,1}   Anlauf in t
    stop[t]  in {0,1}   Abschaltung in t
    E[t]     >= 0       Pufferenergie am Ende von t (kWh)
    miss[t]  >= 0       Unterschreitung des Komfortminimums (kWh), nur als Strafe
    unmet[t] >= 0       nicht gedeckter Wärmebedarf (kWh), nur als Strafe
    term     >= 0       Fehlbetrag der Endbedingung (kWh), nur als Strafe

Ziel
    Kosten des Wärmepumpenstroms
    + Schaltstrafe je Anlauf          (Verdichterschutz; ohne sie taktet das Optimum)
    + Komfortstrafe je fehlender kWh  (macht das Problem immer lösbar, statt an einem zu
                                       ehrgeizigen Komfortziel zu scheitern)

Nebenbedingungen
    Pufferbilanz     E[t] = E[t-1] + P_th*dt*on[t] - Bedarf[t] - Verlust
    Komfort          E[t] + miss[t] >= E_min
    Anlauf/Abschalt  start[t] - stop[t] = on[t] - on[t-1]
    Mindestlaufzeit  Summe on über k Intervalle ab t >= k * start[t]
    Mindestauszeit   Summe (1-on) über m Intervalle ab t >= m * stop[t]
    Endbedingung     E[N-1] + term >= E_end
    Sperrzeiten      on[t] = 0, wo verboten

Zur Endbedingung: ohne sie fährt jede rollierende Optimierung den Puffer zum Horizontende leer,
weil das nichts kostet und alles danach unsichtbar ist. Sie ist der Preis dafür, dass wir nur
36 Stunden weit sehen.

Drei Schlupfvariablen sorgen dafür, dass das Problem **immer** lösbar ist: miss, unmet und term.
Ein Planer, der alle 15 Minuten laufen soll, darf bei einem zu kalten Puffer oder einer schiefen
Prognose nicht ohne Ergebnis dastehen. Er liefert dann einen Fahrplan und schreibt dazu, was er
nicht halten kann; das ist brauchbar, ein leeres Ergebnis nicht. Die Strafen sind so hoch gesetzt,
dass der Solver sie nur nutzt, wenn es physikalisch nicht anders geht.

Bewusste Vereinfachungen, alle nachprüfbar in den Tests:
* Die Wärmepumpe ist an oder aus, sie moduliert im Modell nicht. Der Verdichter der Aerotop
  moduliert real; die Regelung entscheidet das aber selbst, wir geben nur frei.
* Der Preis je Intervall ist vorab festgelegt: liegt genug PV-Überschuss an, gilt die entgangene
  Einspeisevergütung, sonst der Bezugspreis. Beides gleichzeitig zu modellieren erforderte eine
  Kopplung an die Batterie und machte aus dem Problem ein deutlich größeres.
* Der Pufferverlust ist je Intervall konstant statt temperaturabhängig. Der Fehler liegt unter
  den Prognoseunsicherheiten, gegen die hier optimiert wird.

scipy wird erst beim Aufruf geladen: hems_core soll ohne Solver importierbar bleiben.
"""

from __future__ import annotations

import time
from collections.abc import Sequence

from pydantic import BaseModel, ConfigDict, Field


class OptimizerConfig(BaseModel):
    """Stellschrauben des Optimierers. Die Strafen sind Gewichte, keine echten Geldbeträge."""

    model_config = ConfigDict(frozen=True)

    step_min: int = 15
    switch_penalty_eur: float = 0.05  # je Anlauf; hält das Optimum vom Takten ab
    comfort_penalty_eur_per_kwh: float = 5.0  # je fehlender kWh unter dem Komfortminimum
    terminal_soc: float = 0.5  # Mindest-Ladezustand am Horizontende
    time_limit_s: float = 5.0
    mip_gap: float = 0.005


class Interval(BaseModel):
    """Ein Planungsintervall mit allem, was der Optimierer über es wissen muss."""

    model_config = ConfigDict(frozen=True)

    price_ct_kwh: float  # Bezugspreis
    feed_in_ct_kwh: float  # entgangene Vergütung, gilt bei PV-Überschuss
    surplus_kw: float = 0.0  # erwarteter Überschuss vor der Wärmepumpe
    demand_kwh: float = 0.0  # Wärmeentnahme in diesem Intervall
    blocked: bool = False  # Sperrzeit: die Wärmepumpe darf nicht laufen


class OptimizerResult(BaseModel):
    """Ergebnis eines Laufs. `status` sagt, wie ernst die Zahlen zu nehmen sind."""

    model_config = ConfigDict(frozen=True)

    status: str  # "optimal", "feasible", "infeasible", "unavailable"
    on: list[bool] = Field(default_factory=list)
    buffer_kwh: list[float] = Field(default_factory=list)
    energy_cost_eur: float = 0.0
    starts: int = 0
    comfort_miss_kwh: float = 0.0
    unmet_demand_kwh: float = 0.0
    runtime_min: int = 0
    solve_ms: int = 0
    note_de: str = ""


class SolverUnavailableError(RuntimeError):
    """scipy fehlt. Kein Grund, den Dienst zu beenden -- der regelbasierte Planer trägt weiter."""


def optimize(
    intervals: Sequence[Interval],
    *,
    electric_kw: float,
    thermal_kw: float,
    buffer_start_kwh: float,
    buffer_min_kwh: float,
    buffer_max_kwh: float,
    buffer_loss_kwh_per_step: float,
    min_runtime_min: float,
    min_offtime_min: float,
    running_now: bool = False,
    cfg: OptimizerConfig | None = None,
) -> OptimizerResult:
    """Den günstigsten Fahrplan der Wärmepumpe über den Horizont bestimmen."""
    try:
        import numpy as np
        from scipy.optimize import Bounds, LinearConstraint, milp  # type: ignore[import-untyped]
    except ImportError as exc:  # pragma: no cover - hängt an der Installation
        raise SolverUnavailableError(
            "scipy ist nicht installiert; der MILP-Planer steht nicht zur Verfügung."
        ) from exc

    c = cfg or OptimizerConfig()
    n = len(intervals)
    if n == 0:
        return OptimizerResult(status="infeasible", note_de="Kein Planungshorizont übergeben.")

    dt_h = c.step_min / 60.0
    k_run = max(1, round(min_runtime_min / c.step_min))
    k_off = max(1, round(min_offtime_min / c.step_min))

    # Variablenblöcke: on | start | stop | E | miss | unmet, dahinter die eine Endschlupfvariable
    i_on, i_start, i_stop, i_e, i_miss, i_unmet = (i * n for i in range(6))
    i_term = 6 * n
    nvar = 6 * n + 1

    # Zielfunktion. Der Preis je Intervall steht vorab fest (siehe Modulkopf).
    cost = np.zeros(nvar)
    for t, iv in enumerate(intervals):
        ct = iv.feed_in_ct_kwh if iv.surplus_kw >= electric_kw else iv.price_ct_kwh
        cost[i_on + t] = ct / 100.0 * electric_kw * dt_h
        cost[i_start + t] = c.switch_penalty_eur
        cost[i_miss + t] = c.comfort_penalty_eur_per_kwh
        # Ungedeckter Bedarf wiegt schwerer als ein kurzes Unterschreiten des Komfortminimums:
        # das eine heißt kalte Wohnung, das andere nur einen knapperen Puffer.
        cost[i_unmet + t] = c.comfort_penalty_eur_per_kwh * 3.0
    cost[i_term] = c.comfort_penalty_eur_per_kwh

    lower = np.zeros(nvar)
    upper = np.ones(nvar)
    upper[i_e : i_e + n] = buffer_max_kwh
    upper[i_miss : i_miss + n] = buffer_max_kwh
    upper[i_unmet : i_unmet + n] = np.inf
    upper[i_term] = buffer_max_kwh
    for t, iv in enumerate(intervals):
        if iv.blocked:
            upper[i_on + t] = 0.0

    integrality = np.zeros(nvar)
    integrality[i_on : i_on + n] = 1
    integrality[i_start : i_start + n] = 1
    integrality[i_stop : i_stop + n] = 1

    rows: list[np.ndarray] = []
    lo: list[float] = []
    hi: list[float] = []

    def add(row: np.ndarray, low: float, high: float) -> None:
        rows.append(row)
        lo.append(low)
        hi.append(high)

    for t, iv in enumerate(intervals):
        # Pufferbilanz: E[t] - E[t-1] - P_th*dt*on[t] = -Bedarf - Verlust
        r = np.zeros(nvar)
        r[i_e + t] = 1.0
        if t > 0:
            r[i_e + t - 1] = -1.0
        r[i_on + t] = -thermal_kw * dt_h
        r[i_unmet + t] = -1.0
        rhs = -iv.demand_kwh - buffer_loss_kwh_per_step + (buffer_start_kwh if t == 0 else 0.0)
        add(r, rhs, rhs)

        # Komfort: E[t] + miss[t] >= E_min
        r = np.zeros(nvar)
        r[i_e + t] = 1.0
        r[i_miss + t] = 1.0
        add(r, buffer_min_kwh, np.inf)

        # Anlauf/Abschaltung: start[t] - stop[t] - on[t] + on[t-1] = 0
        r = np.zeros(nvar)
        r[i_start + t] = 1.0
        r[i_stop + t] = -1.0
        r[i_on + t] = -1.0
        prev = 1.0 if (t == 0 and running_now) else 0.0
        if t > 0:
            r[i_on + t - 1] = 1.0
            add(r, 0.0, 0.0)
        else:
            add(r, -prev, -prev)

        # Mindestlaufzeit: Summe on[t..t+k-1] >= k * start[t]
        end = min(n, t + k_run)
        r = np.zeros(nvar)
        r[i_on + t : i_on + end] = 1.0
        r[i_start + t] = -(end - t)
        add(r, 0.0, np.inf)

        # Mindestauszeit: Summe (1-on[t..t+m-1]) >= m * stop[t]
        end = min(n, t + k_off)
        r = np.zeros(nvar)
        r[i_on + t : i_on + end] = -1.0
        r[i_stop + t] = -(end - t)
        add(r, -(end - t), np.inf)

    # Endbedingung: der Puffer darf am Horizontende nicht leer sein. Mit Schlupf, damit ein zu
    # kalter Start den ganzen Lauf nicht unlösbar macht.
    r = np.zeros(nvar)
    r[i_e + n - 1] = 1.0
    r[i_term] = 1.0
    add(r, min(buffer_max_kwh, c.terminal_soc * buffer_max_kwh), np.inf)

    t0 = time.perf_counter()
    res = milp(
        c=cost,
        integrality=integrality,
        bounds=Bounds(lower, upper),
        constraints=LinearConstraint(np.vstack(rows), np.array(lo), np.array(hi)),
        options={"time_limit": c.time_limit_s, "mip_rel_gap": c.mip_gap},
    )
    solve_ms = int((time.perf_counter() - t0) * 1000)

    if res.x is None:
        return OptimizerResult(
            status="infeasible",
            solve_ms=solve_ms,
            note_de=f"Kein zulässiger Fahrplan gefunden ({res.message.strip()[:120]}).",
        )
    x = res.x
    on = [bool(round(x[i_on + t])) for t in range(n)]
    buf = [round(float(x[i_e + t]), 3) for t in range(n)]
    starts = round(sum(x[i_start + t] for t in range(n)))
    miss = float(sum(x[i_miss + t] for t in range(n)))
    unmet = float(sum(x[i_unmet + t] for t in range(n)))
    energy = sum(
        (iv.feed_in_ct_kwh if iv.surplus_kw >= electric_kw else iv.price_ct_kwh)
        / 100.0
        * electric_kw
        * dt_h
        for iv, run in zip(intervals, on, strict=True)
        if run
    )
    status = "optimal" if res.status == 0 else "feasible"
    return OptimizerResult(
        status=status,
        on=on,
        buffer_kwh=buf,
        energy_cost_eur=round(energy, 4),
        starts=starts,
        comfort_miss_kwh=round(miss, 3),
        unmet_demand_kwh=round(unmet, 3),
        runtime_min=sum(on) * c.step_min,
        solve_ms=solve_ms,
        note_de=(
            f"{sum(on)} von {n} Intervallen Freigabe, {starts} Anläufe, "
            f"{energy:.2f} EUR Stromkosten über {round(n * dt_h)} h."
            + (f" Komfortminimum um {miss:.1f} kWh unterschritten." if miss > 0.05 else "")
            + (
                f" {unmet:.1f} kWh Wärmebedarf bleiben ungedeckt - die Anlage kann den Bedarf"
                " im Horizont nicht decken."
                if unmet > 0.05
                else ""
            )
        ),
    )
