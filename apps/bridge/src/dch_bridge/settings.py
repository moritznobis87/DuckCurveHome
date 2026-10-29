"""Einstellungen der Bridge. Als HA-Add-on kommen sie aus /data/options.json (run.sh exportiert sie als
Umgebungsvariablen DCH_BRIDGE_*), lokal aus .env."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Annotated, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

#: Wie eine Entität in Home Assistant aussieht: Bereich, Punkt, Name.
ENTITAET = re.compile(r"[a-z_]+\.[a-z0-9_]+")


def ist_entitaet(text: str) -> bool:
    """Taugt der Text als Ziel für einen Dienstaufruf?

    Gefragt wird, bevor etwas an Home Assistant geht. Was dort ankommt und keine Entität ist,
    beantwortet Home Assistant mit `invalid_format: expected 'all' or 'none' at
    'target.entity_id'` - ein Satz, der die Ursache nicht nennt und beim Druck auf den Knopf
    erscheint, nicht beim Einrichten.
    """
    return bool(ENTITAET.fullmatch(text.strip()))


class BridgeSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DCH_BRIDGE_", env_file=".env", extra="ignore")

    bridge_id: str = "haus"
    # Home Assistant: im Add-on über den Supervisor-Proxy, lokal per URL + Long-Lived Token
    ha_ws_url: str = "ws://supervisor/core/websocket"
    ha_rest_url: str = "http://supervisor/core/api"
    ha_token: str = Field(default="", validation_alias="SUPERVISOR_TOKEN")
    # API auf Railway
    api_ws_url: str = "wss://api-home.duckcurve.de/bridge/ws"
    api_token: str = ""
    # Mapping
    entities_file: Path = Path("/config/duckcurve/entities.yaml")  # übersteuert das Repository
    entities_url: str = "https://raw.githubusercontent.com/moritznobis87/DuckCurveHome/main/config/entities.home.yaml"
    entities_cache: Path = Path("/data/entities.cache.yaml")
    # Verhalten
    telemetry_interval_s: float = 1.0
    state_refresh_s: float = (
        30.0  # kompletter get_states-Refresh, damit unveränderte Werte frisch bleiben
    )
    heartbeat_entity: str = "sensor.duckcurve_bridge_heartbeat"
    heartbeat_interval_s: int = 30
    offline_release_s: int = 180  # ohne Cloud: Wärmepumpen-Kontakte zurücksetzen
    outbox_path: Path = Path("/data/outbox.sqlite")
    outbox_max_age_h: int = 24 * 7
    log_level: str = "INFO"
    # Datenquelle für den Shelly 3EM (Wärmepumpenzähler): HA-Entitäten, MQTT direkt oder beides vergleichen
    source_mode: Literal["home_assistant", "mqtt", "compare"] = "mqtt"
    mqtt_host: str = "core-mosquitto"  # offizielles Mosquitto-Add-on im HA-Netz
    mqtt_port: int = 1883
    mqtt_username: str = ""
    mqtt_password: str = ""
    shelly_device_id: str = ""  # z. B. 485519DB56D2 (Hostname shellyem3-<id>)
    mqtt_topic_prefix: str = ""  # leer = shellies/shellyem3-<shelly_device_id>
    mqtt_publish_interval_s: float = 10.0  # Takt für konsistente Datensätze an die API
    mqtt_stale_s: float = 90.0  # ohne Nachricht so lange → nicht verfügbar
    mqtt_qos: int = 1
    mqtt_poll_interval_s: float = 120.0  # Vollstand der Gen-2-Geräte abrufen; 0 = aus
    mqtt_key_prefix: str = (
        "heat_pump"  # Domänenschlüssel: heat_pump_power_kw, heat_pump_energy_kwh, …
    )
    # Pelletofen: MCZ mit Maestro-Modul, direkt über dessen WebSocket. Nur lesend.
    mcz_host: str = ""  # IP oder Hostname des Ofens im Heimnetz; leer = Quelle aus
    mcz_port: int = 81
    mcz_poll_interval_s: float = 15.0
    # Darf die Bridge den Ofen ein- und ausschalten? Standardmäßig nein. Eine Feuerstätte
    # fernzustarten ist eine andere Klasse von Eingriff als ein Relais, und die Entscheidung
    # gehört dem Hausherrn, nicht der Voreinstellung.
    mcz_allow_control: bool = False
    # Einzelraumregelung: der Mini-Server der Heizungsregelung im Heimnetz. Nur lesend.
    #
    # Die Haus-Kennung bleibt auf 0 und wird gesucht. Die Dokumentation des Herstellers sagt,
    # sie sei "aus unterschiedlichen Gruenden manchmal 2 und nicht 1"; auf der Anlage, gegen die
    # das gebaut wurde, ist sie 2. Eine Einstellung, die niemand erraten kann, waere nur eine
    # Quelle fuer Rueckfragen.
    #
    # Benutzer und Passwort sind leer, weil die Lese-Endpunkte im Heimnetz ohne Anmeldung
    # antworten (gemessen 21.10.2026). Die Felder stehen trotzdem da: das ist eine Schwaeche des
    # Herstellers, und wenn er sie behebt, soll hier nur ein Wert zu setzen sein.
    # Alarmanlage. Gelesen wird sie ueber die Entity-Zuordnung wie jede andere Groesse; diese
    # beiden Werte brauchen nur das Scharfschalten. Ohne `alarm_arm_enabled` bleibt es beim Lesen.
    alarm_entity: str = ""
    alarm_arm_enabled: bool = False

    controme_host: str = ""  # IP oder Hostname; leer = Quelle aus
    controme_house_id: int = 0  # 0 = suchen
    controme_poll_interval_s: float = 120.0
    controme_user: str = ""
    controme_password: str = ""
    # Haustür: Gesichtsscan am UniFi-Access-Reader öffnet das Nuki-Schloss. Beides im Heimnetz,
    # ohne Cloud. Leer = aus.
    #
    # Der Token für Access entsteht in dessen Oberfläche unter Einstellungen → Allgemein →
    # API-Token, der für Nuki in der Nuki-App unter „Geräte verwalten" beim Einschalten der
    # HTTP-API. Beide gehören in die Umgebung der Bridge und nirgendwo sonst hin.
    unifi_host: str = ""  # IP der UniFi-Konsole; leer = Türdienst aus
    unifi_port: int = 12445
    unifi_token: str = ""
    unifi_verify_tls: bool = False  # die Konsole stellt ihr Zertifikat selbst aus
    # Wer die Tür tatsächlich aufmacht.
    #
    # `home_assistant` ruft einen Dienst auf der Matter-Entität des Schlosses auf. Das Schloss
    # bleibt dabei auf Thread, sein WLAN bleibt aus, die Batterie hält - dafür stehen Home
    # Assistant und der Border Router in der Kette.
    #
    # `nuki_bridge` spricht über das Steckdosengerät von Nuki und dessen lokale HTTP-API, das
    # Schloss erreicht es per Bluetooth. Damit fallen HA und der HomePod aus dem Türweg heraus.
    # Diesen Weg gibt es hier, weil er der Ausweg ist, falls sich die Strecke über Home Assistant
    # im Betrieb als unzuverlässig erweist - die Verfügbarkeit wird als `door_lock_online`
    # mitgeschrieben, die Entscheidung fällt also an Daten und nicht an Vermutungen.
    door_opener: Literal["home_assistant", "nuki_bridge"] = "home_assistant"
    door_entity: str = ""  # z. B. lock.haupteingang_nuki
    # `lock.open` zieht die Falle, `lock.unlock` dreht nur den Riegel zurück. Ob die Matter-
    # Anbindung des Schlosses das Öffnen hergibt, hängt von Gerät, Firmware und HA-Version ab und
    # ist in zehn Sekunden auszuprobieren - deshalb Einstellung und nicht Quelltext.
    door_service: str = "lock.open"
    nuki_host: str = ""  # nur für door_opener=nuki_bridge: IP der Nuki-Bridge
    nuki_port: int = 8080
    nuki_token: str = ""
    nuki_id: str = ""  # leer = das erste Schloss aus /list
    # Die Freigabe selbst. Ohne sie läuft der Dienst im Beobachtungsbetrieb: er protokolliert jedes
    # Zutrittsereignis und rührt das Schloss nicht an. So findet man die Werte für die Listen
    # unten an der eigenen Tür heraus, statt sie zu raten.
    door_enabled: bool = False
    # `NoDecode`, weil pydantic-settings eine Liste aus der Umgebung sonst als JSON zu lesen
    # versucht und an „Haustür" scheitert, bevor der Validator unten überhaupt drankommt.
    door_doors: Annotated[list[str], NoDecode] = Field(default_factory=list)
    door_actors: Annotated[list[str], NoDecode] = Field(default_factory=list)
    door_methods: Annotated[list[str], NoDecode] = Field(default_factory=list)

    @property
    def door_configured(self) -> bool:
        """Läuft der Türdienst? Beide Hälften müssen stehen: Ereignisse und ein Weg zum Schloss."""
        if not (self.unifi_host and self.unifi_token):
            return False
        if self.door_opener == "nuki_bridge":
            return bool(self.nuki_host and self.nuki_token)
        return bool(self.door_entity)

    @property
    def shelly_topic_prefix(self) -> str:
        """Topic-Präfix des Shelly, tolerant gegenüber der Schreibweise in der Geräteoberfläche.

        Gen-1-Geräte veröffentlichen unter `shellies/<geräte-id>/…`. In der Shelly-App steht je nach Ansicht
        die vollständige Kennung (`shellyem3-485519db56d2`), nur die MAC oder bereits der Pfad mit
        `shellies/`. Alle drei Schreibweisen führen hier zum selben Präfix."""
        raw = (self.mqtt_topic_prefix or self.shelly_device_id).strip().strip("/")
        if not raw:
            return ""
        if "/" in raw:
            return raw  # bereits ein Pfad, z. B. shellies/shellyem3-485519db56d2
        device = raw if raw.startswith("shellyem3-") else f"shellyem3-{raw}"
        return f"shellies/{device}"

    @field_validator("alarm_entity", "door_entity", "heartbeat_entity", mode="before")
    @classmethod
    def _entitaet(cls, value: object) -> str:
        """Eine Entität aus dem Eingabefeld, auch wenn die ganze Zeile hineingeraten ist.

        In den Add-on-Optionen steht je Option ein eigenes Feld; in der Anleitung steht die Zeile
        `alarm_entity: alarm_control_panel.lupusec_alarm`. Wer sie ganz kopiert, trägt den
        Optionsnamen mit ein, und Home Assistant bekommt als Ziel den Text
        „alarm_entity: alarm_control_panel.lupusec_alarm". Die Antwort darauf lautet
        `invalid_format: expected 'all' or 'none' at 'target.entity_id'`, und sie erscheint beim
        Druck auf den Knopf in der Küche, nicht beim Einrichten (gesehen am 29.10.2026).

        Repariert wird nur, was eindeutig ist: Leerraum, Anführungszeichen und ein vorangestellter
        Optionsname. Eine Entität enthält selbst keinen Doppelpunkt, deshalb ist der Schnitt
        sicher. Was danach keine Entität ist, bleibt stehen, wie es ist: Der Dienst, der sie
        braucht, sagt dann, was fehlt, statt sich eine auszudenken.
        """
        if value is None:
            return ""
        raw = str(value).strip().strip("'\"").strip()
        if ":" in raw:
            kopf, _, rest = raw.partition(":")
            if "." not in kopf:
                raw = rest.strip().strip("'\"").strip()
        return raw

    @field_validator("door_doors", "door_actors", "door_methods", mode="before")
    @classmethod
    def _lists(cls, value: object) -> list[str]:
        """Aus der Umgebung kommen Listen als Text: „Haustür, Nebentür" oder als JSON-Liste."""
        if value is None or value == "":
            return []
        if isinstance(value, str):
            raw = value.strip()
            if raw.startswith("["):
                parsed = json.loads(raw)
                return [str(v) for v in parsed] if isinstance(parsed, list) else []
            return [p.strip() for p in raw.split(",") if p.strip()]
        return [str(v) for v in value] if isinstance(value, list) else []
