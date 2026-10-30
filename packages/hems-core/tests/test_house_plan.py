"""Der Hausplan prueft, was sich pruefen laesst, und laesst dem Zeichner den Rest.

Das Haus hier ist erfunden. Das Repository ist oeffentlich.
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from hems_core.house import Contact, Deck, HousePlan, Item, Room, WallLine


def _deck(**extra: object) -> dict[str, object]:
    return {
        "key": "eg",
        "name": "Erdgeschoss",
        "shell": [[0, 0], [10, 0], [10, 8], [0, 8]],
        "rooms": [
            {"name": "Wohnen", "room_id": 3, "x0": 0, "z0": 0, "x1": 6, "z1": 8},
            {"name": "Flur", "x0": 6, "z0": 0, "x1": 10, "z1": 8, "minor": True},
        ],
        **extra,
    }


def test_ein_kleiner_plan_geht_durch() -> None:
    plan = HousePlan.model_validate({"decks": [_deck()]})
    assert plan.version == 1
    assert plan.room_ids == [3]
    assert plan.decks[0].room("Wohnen") is not None
    assert plan.decks[0].room("Keller") is None


def test_ein_raum_muss_ein_rechteck_sein() -> None:
    with pytest.raises(ValidationError, match="x1 > x0"):
        Room(name="Verkehrt", x0=5, z0=0, x1=2, z1=3)


def test_eine_wandlinie_liegt_auf_genau_einer_achse() -> None:
    with pytest.raises(ValidationError, match="genau eines"):
        WallLine(a=0, b=1)
    with pytest.raises(ValidationError, match="genau eines"):
        WallLine(x=1, z=1, a=0, b=1)
    with pytest.raises(ValidationError, match="groesser als a"):
        WallLine(x=1, a=2, b=1)


def test_ein_kontakt_braucht_einen_bekannten_raum_und_einen_eigenen_schluessel() -> None:
    kontakt = {
        "name": "Tuer",
        "key": "kontakt_tuer",
        "room": "Wohnen",
        "side": "n",
        "at": 0,
        "a": 1,
        "b": 2,
    }
    Deck.model_validate(_deck(contacts=[kontakt]))
    with pytest.raises(ValidationError, match="unbekannten Raum"):
        Deck.model_validate(_deck(contacts=[{**kontakt, "room": "Keller"}]))
    with pytest.raises(ValidationError, match="mehrfach"):
        Deck.model_validate(_deck(contacts=[kontakt, {**kontakt, "name": "Noch eine"}]))
    with pytest.raises(ValidationError):
        Contact(name="Tuer", key="Kontakt Tuer", side="n", at=0, a=1, b=2)


def test_ein_teilraum_nennt_einen_raum_der_da_ist() -> None:
    teil = {
        "name": "Wohnen",
        "part_of": "Wohnen",
        "x0": 0,
        "z0": 8,
        "x1": 2,
        "z1": 9,
        "silent": True,
    }
    deck = Deck.model_validate(_deck(rooms=[*_deck()["rooms"], teil]))  # type: ignore[misc]
    assert len(deck.rooms) == 3
    with pytest.raises(ValidationError, match="unbekanntem"):
        Deck.model_validate(_deck(rooms=[*_deck()["rooms"], {**teil, "part_of": "Nirgends"}]))  # type: ignore[misc]


def test_zwei_hauptraeume_heissen_nicht_gleich() -> None:
    doppelt = {"name": "Wohnen", "x0": 6, "z0": 0, "x1": 10, "z1": 8}
    with pytest.raises(ValidationError, match="mehrfach"):
        Deck.model_validate(_deck(rooms=[_deck()["rooms"][0], doppelt]))  # type: ignore[index]


def test_seitenbuchstaben_kommen_hoechstens_einmal_vor() -> None:
    Room(name="Galerie", x0=0, z0=0, x1=1, z1=1, no_walls="nwso", railing="ws")
    with pytest.raises(ValidationError):
        Room(name="Galerie", x0=0, z0=0, x1=1, z1=1, no_walls="nn")
    with pytest.raises(ValidationError):
        Room(name="Galerie", x0=0, z0=0, x1=1, z1=1, railing="x")


def test_ein_moebel_kennt_seine_art_und_keine_unendlichen_masse() -> None:
    Item(kind="box", x=1, z=1, b=0.6, t=0.4, h=0.8)
    with pytest.raises(ValidationError):
        Item(kind="sofa", x=1, z=1)  # type: ignore[arg-type]
    with pytest.raises(ValidationError, match="endlich"):
        Item(kind="box", x=float("inf"), z=1)
    with pytest.raises(ValidationError, match="groesser als 0"):
        Item(kind="box", x=1, z=1, b=-1)
    with pytest.raises(ValidationError):
        Item(kind="box", x=1, z=1, farbe="rot")  # type: ignore[call-arg]


def test_deckschluessel_sind_eindeutig_und_hoechstens_drei() -> None:
    with pytest.raises(ValidationError, match="Deckschluessel"):
        HousePlan.model_validate({"decks": [_deck(), _deck()]})
    with pytest.raises(ValidationError):
        HousePlan.model_validate({"decks": [_deck(key=k) for k in ("a", "b", "c", "d")]})


def test_unbekannte_felder_werden_nicht_stillschweigend_geschluckt() -> None:
    """Ein Tippfehler im Feldnamen soll eine Meldung bekommen, nicht ein Moebel, das fehlt."""
    with pytest.raises(ValidationError):
        HousePlan.model_validate({"decks": [_deck()], "nam": "Haus"})
