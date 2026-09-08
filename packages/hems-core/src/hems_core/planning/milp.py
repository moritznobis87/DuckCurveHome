"""Rollierende Optimierung der Wärmepumpe als gemischt-ganzzahliges Programm (Stufe 3 des Plans).

Der regelbasierte Planer legt Freigabefenster in die günstigen Viertelstunden. Er tut das gierig:
er sieht ein Fenster, findet es billig, belegt es. Was er nicht kann, ist abwägen -- ob es sich
lohnt, jetzt teurer zu laden, um in sechs Stunden eine noch teurere Phase zu überspringen, und ob
der Puffer das überhaupt trägt. Genau das ist die Aufgabe eines Optimierers: nicht jede Stunde für
sich zu bewerten, sondern den ganzen Horizont auf einmal.

**Zwei Wärmequellen.** Wärmepumpe und Pelletofen laden denselben Puffer, und welche von beiden
das tun soll, ist je nach Außentemperatur und Strompreis verschieden. Der Ofen kommt mit einer
Eigenheit, die das Problem verändert: sein Brennstoff ist **knapp**. In den Behälter passen 15 kg,
nachgefüllt wird einmal am Tag. Damit ist die Ofenentscheidung kein Preisvergleich je Stunde mehr,
sondern ein Rucksackproblem über den Tag: jede Ofenstunde muss sich gegen jede andere Stunde
desselben Budgetfensters durchsetzen. Genau das kann ein MILP und eine Regel nicht.

Modell (Zeitschritt 15 min, Horizont 24 bis 36 h):

Variablen je Intervall t
    on[t]      in {0,1}   Wärmepumpe läuft
    start[t]   in {0,1}   Anlauf in t
    stop[t]    in {0,1}   Abschaltung in t
    E[t]       >= 0       Pufferenergie am Ende von t (kWh)
    miss[t]    >= 0       Unterschreitung des Komfortminimums (kWh), nur als Strafe
    unmet[t]   >= 0       nicht gedeckter Wärmebedarf (kWh), nur als Strafe
    s_on[t]    in {0,1}   Ofen brennt          nur wenn ein Ofen übergeben wird
    s_start[t] in {0,1}   Zündung in t
    s_stop[t]  in {0,1}   Ausbrand in t
    term       >= 0       Fehlbetrag der Endbedingung (kWh), nur als Strafe

Ziel
    Kosten des Wärmepumpenstroms
    + Kosten des Ofenbetriebs         (Pellets, Eigenstrom, abzüglich angerechneter Raumwärme;
                                       der Aufrufer rechnet das je Intervall aus)
    + Schaltstrafe je Anlauf          (Verdichterschutz; ohne sie taktet das Optimum)
    + Zündstrafe je Ofenstart         (Zündwiderstand, unverbrannte Pellets, Wartungszähler)
    + Komfortstrafe je fehlender kWh  (macht das Problem immer lösbar, statt an einem zu
                                       ehrgeizigen Komfortziel zu scheitern)

Nebenbedingungen
    Pufferbilanz     E[t] = E[t-1] + P_th*dt*on[t] + P_ofen*dt*s_on[t] - Bedarf[t] - Verlust
    Komfort          E[t] + miss[t] >= E_min
    Anlauf/Abschalt  start[t] - stop[t] = on[t] - on[t-1]        (für beide Geräte getrennt)
    Mindestlaufzeit  Summe on über k Intervalle ab t >= k * start[t]
    Mindestauszeit   Summe (1-on) über m Intervalle ab t >= m * stop[t]
    Brennstoff       Summe kg/h*dt*s_on[t] über ein Budgetfenster <= verfügbare Kilogramm
    Endbedingung     E[N-1] + term >= E_end
    Sperrzeiten      on[t] = 0, wo verboten

In die Pufferbilanz geht beim Ofen nur die **Wasserleistung**, also 10 der 11,9 kW. Die Wärme, die
im Aufstellraum bleibt, füllt keinen Speicher; sie gehört auf die Kostenseite und wird dort vom
Aufrufer eingepreist. Wer sie in die Bilanz schreibt, lädt einen Puffer mit Küchenwärme.

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
* Der Ofen ebenso, und zwar auf Volllast. Er moduliert real, aber je Kilowattstunde Nutzwärme
  kostet Teillast dasselbe, und je Kilogramm Pellets liefert Volllast 42 % mehr Pufferwärme.
  Bei knappem Brennstoff ist Volllast damit immer die richtige Wahl, und eine Teillastvariable
  brächte nur Modellgröße. Nachgerechnet in `hems_core.accounting.stove_cost`.
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
    stove_start_penalty_eur: float = 0.30  # je Zündung; deutlich höher als beim Verdichter
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

    # Ofen. Die Kosten je Betriebsstunde rechnet der Aufrufer aus: Pellets plus Eigenstrom, abzüglich
    # der angerechneten Raumwärme. Sie stehen hier je Intervall, weil der Eigenstrom und der Wert der
    # Raumwärme am Strompreis der Stunde hängen.
    stove_eur_per_h: float = 0.0
    stove_blocked: bool = False
    # Zu welchem Brennstoff-Budgetfenster dieses Intervall gehört. Der Planungstag des Ofens läuft
    # von Füllung zu Füllung, nicht von Mitternacht zu Mitternacht; die Zuordnung macht der
    # Aufrufer, weil sie Ortszeit braucht und hems_core keine Zeitzonen kennt.
    budget_window: int = 0


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
    # Ofen. Leer, wenn keiner übergeben wurde.
    stove_on: list[bool] = Field(default_factory=list)
    stove_starts: int = 0
    stove_runtime_min: int = 0
    stove_cost_eur: float = 0.0
    stove_pellet_kg: float = 0.0
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
    stove_thermal_kw: float = 0.0,
    stove_kg_per_h: float = 0.0,
    stove_min_runtime_min: float = 120.0,
    stove_min_offtime_min: float = 60.0,
    stove_running_now: bool = False,
    fuel_budget_kg: Sequence[float] | None = None,
    cfg: OptimizerConfig | None = None,
) -> OptimizerResult:
    """Den günstigsten Fahrplan über den Horizont bestimmen, für eine oder beide Wärmequellen.

    Ohne `stove_thermal_kw` bleibt das Problem exakt so groß wie zuvor: keine Ofenvariablen, keine
    Brennstoffbedingung. Ein Haus ohne Ofen zahlt für dessen Modellierung nichts.

    `fuel_budget_kg` ist je Budgetfenster ein Kilogrammwert, indiziert wie `Interval.budget_window`.
    Das erste Fenster trägt üblicherweise den **Rest** im Behälter, die folgenden je eine volle
    Füllung. Fehlt die Angabe, bleibt der Brennstoff unbeschränkt; das ist für Vergleichsläufe
    nützlich und im Betrieb falsch.
    """
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
    has_stove = stove_thermal_kw > 0.0
    ks_run = max(1, round(stove_min_runtime_min / c.step_min))
    ks_off = max(1, round(stove_min_offtime_min / c.step_min))

    # Variablenblöcke: on | start | stop | E | miss | unmet [| s_on | s_start | s_stop],
    # dahinter die eine Endschlupfvariable.
    i_on, i_start, i_stop, i_e, i_miss, i_unmet = (i * n for i in range(6))
    i_s_on, i_s_start, i_s_stop = (6 * n, 7 * n, 8 * n) if has_stove else (0, 0, 0)
    blocks = 9 if has_stove else 6
    i_term = blocks * n
    nvar = blocks * n + 1

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
        if has_stove:
            cost[i_s_on + t] = iv.stove_eur_per_h * dt_h
            cost[i_s_start + t] = c.stove_start_penalty_eur
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
        if has_stove and iv.stove_blocked:
            upper[i_s_on + t] = 0.0

    integrality = np.zeros(nvar)
    integrality[i_on : i_on + n] = 1
    integrality[i_start : i_start + n] = 1
    integrality[i_stop : i_stop + n] = 1
    if has_stove:
        integrality[i_s_on : i_s_on + 3 * n] = 1

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
        if has_stove:
            # Nur die Wasserleistung. Die Wärme, die im Aufstellraum bleibt, füllt keinen Speicher.
            r[i_s_on + t] = -stove_thermal_kw * dt_h
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

        if not has_stove:
            continue

        # Dieselbe Schaltlogik für den Ofen, mit eigenen Zeiten: er läuft mindestens zwei Stunden
        # und pausiert mindestens eine. Ein Pelletofen ist keine Klingel.
        r = np.zeros(nvar)
        r[i_s_start + t] = 1.0
        r[i_s_stop + t] = -1.0
        r[i_s_on + t] = -1.0
        if t > 0:
            r[i_s_on + t - 1] = 1.0
            add(r, 0.0, 0.0)
        else:
            prev_s = 1.0 if stove_running_now else 0.0
            add(r, -prev_s, -prev_s)

        end = min(n, t + ks_run)
        r = np.zeros(nvar)
        r[i_s_on + t : i_s_on + end] = 1.0
        r[i_s_start + t] = -(end - t)
        add(r, 0.0, np.inf)

        end = min(n, t + ks_off)
        r = np.zeros(nvar)
        r[i_s_on + t : i_s_on + end] = -1.0
        r[i_s_stop + t] = -(end - t)
        add(r, -(end - t), np.inf)

    # Brennstoff: je Budgetfenster höchstens so viele Kilogramm, wie im Behälter liegen. Das ist
    # die Bedingung, die aus dem Preisvergleich ein Rucksackproblem macht: der Planer muss die
    # Füllung über den Tag verteilen und dabei entscheiden, wann sie am meisten wert ist.
    if has_stove and fuel_budget_kg is not None and stove_kg_per_h > 0.0:
        windows: dict[int, list[int]] = {}
        for t, iv in enumerate(intervals):
            windows.setdefault(iv.budget_window, []).append(t)
        for w, idx in sorted(windows.items()):
            if w >= len(fuel_budget_kg):
                continue  # kein Budget angegeben: dieses Fenster bleibt unbeschränkt
            r = np.zeros(nvar)
            for t in idx:
                r[i_s_on + t] = stove_kg_per_h * dt_h
            add(r, 0.0, max(fuel_budget_kg[w], 0.0))

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
    s_on: list[bool] = []
    s_starts = 0
    s_cost = 0.0
    s_kg = 0.0
    if has_stove:
        s_on = [bool(round(x[i_s_on + t])) for t in range(n)]
        s_starts = round(sum(x[i_s_start + t] for t in range(n)))
        s_cost = sum(
            iv.stove_eur_per_h * dt_h for iv, run in zip(intervals, s_on, strict=True) if run
        )
        s_kg = sum(s_on) * stove_kg_per_h * dt_h
    return OptimizerResult(
        status=status,
        on=on,
        buffer_kwh=buf,
        energy_cost_eur=round(energy, 4),
        starts=starts,
        comfort_miss_kwh=round(miss, 3),
        unmet_demand_kwh=round(unmet, 3),
        runtime_min=sum(on) * c.step_min,
        stove_on=s_on,
        stove_starts=s_starts,
        stove_runtime_min=sum(s_on) * c.step_min,
        stove_cost_eur=round(s_cost, 4),
        stove_pellet_kg=round(s_kg, 2),
        solve_ms=solve_ms,
        note_de=(
            f"{sum(on)} von {n} Intervallen Freigabe, {starts} Anläufe, "
            f"{energy:.2f} EUR Stromkosten über {round(n * dt_h)} h."
            + (
                f" Ofen {sum(s_on) * c.step_min} min in {s_starts} Phasen, {s_kg:.1f} kg Pellets,"
                f" {s_cost:.2f} EUR."
                if has_stove and any(s_on)
                else " Ofen bleibt aus."
                if has_stove
                else ""
            )
            + (f" Komfortminimum um {miss:.1f} kWh unterschritten." if miss > 0.05 else "")
            + (
                f" {unmet:.1f} kWh Wärmebedarf bleiben ungedeckt - die Anlage kann den Bedarf"
                " im Horizont nicht decken."
                if unmet > 0.05
                else ""
            )
        ),
    )
