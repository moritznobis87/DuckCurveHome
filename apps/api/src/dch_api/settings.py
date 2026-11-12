"""Einstellungen (pydantic-settings). Alle Variablen mit Präfix DCH_ - siehe CONFIGURATION.md."""

from __future__ import annotations

import json
from datetime import datetime
from functools import lru_cache
from typing import Annotated, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


def parse_list(value: object) -> list[str]:
    """Listen aus Umgebungsvariablen tolerant lesen: JSON-Liste, kommagetrennt oder ein einzelner Wert."""
    if value is None:
        return []
    if isinstance(value, list | tuple):
        return [str(v).strip() for v in value if str(v).strip()]
    text = str(value).strip()
    if not text:
        return []
    if text.startswith("["):
        parsed = json.loads(text)
        if not isinstance(parsed, list):
            raise ValueError("JSON-Liste erwartet")
        return [str(v).strip() for v in parsed if str(v).strip()]
    return [part.strip().strip("'\"") for part in text.split(",") if part.strip().strip("'\"")]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DCH_", env_file=".env", extra="ignore")

    mode: Literal["demo", "live"] = "demo"
    role: Literal["all", "api", "worker"] = "all"
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "INFO"
    cors_origins: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: ["http://localhost:3000"]
    )

    # Demo-Modus
    demo_speed: float = 1.0  # Simulationssekunden je Echtzeitsekunde (288 = 24 h in 5 min)
    demo_seed: int = 7
    demo_start: datetime | None = None  # None = jetzt
    demo_warmup_hours: float = 30.0  # Vorlauf, damit Chart und Historie sofort gefüllt sind
    demo_autostart: bool = True  # False in Tests: Simulation nur auf Abruf vorrücken

    # Wie oft der Live-Zustand an die offenen Bildschirme geht.
    #
    # Er war auf eine Sekunde eingestellt, und das kostete je Bildschirm 549 MB am Tag (gemessen
    # 03.11.2026: 4,5 kB je Momentaufnahme). Die Fuehler dahinter melden alle 15 bis 30 Sekunden;
    # haeufiger zu senden wiederholt nur dieselben Zahlen. Fuenf Sekunden fuehlen sich auf einer
    # Wandanzeige unveraendert an und senken die Menge auf ein Fuenftel.
    #
    # Der Hoechstabstand ist die Gegenprobe zum Wiederholungsfilter: Einmal je Minute geht der
    # Zustand auch dann hinaus, wenn er gleich geblieben ist, damit ein Bildschirm, der eine
    # Meldung verpasst hat, nicht beliebig lange auf dem alten Stand bleibt.
    live_push_min_s: float = 5.0
    live_push_max_s: float = 60.0

    # Regelung
    tick_s: int = 10
    history_retention_hours: int = 72
    # Zwei getrennte Schalter, weil zwei verschiedene Risiken: eine Lichterkette anzutippen ist harmlos,
    # den Wärmepumpen-Kontakt selbsttätig zu stellen nicht.
    actuation_enabled: bool = True  # vom Bedienenden ausgelöstes Schalten (Lichter, Kaffeemaschine)
    # Selbsttätiges Stellen von K1 aus der Regelentscheidung.
    #
    # **Seit dem 09.11.2026 an, auf ausdrückliche Anweisung des Hausherrn** („die Planung live
    # schalten"). Bis dahin stand hier `False`, und der ganze Regelweg lief im Schatten: der Regler
    # entschied, die Entscheidung wurde abgelegt und angezeigt, aber der Kontakt wurde nie gestellt.
    #
    # Die Voreinstellung und nicht die Umgebungsvariable, weil der Live-Dienst seine Variablen nicht
    # aus diesem Repository bekommt: `docker-compose.yml` ist Demo-Modus, `railway.json` trägt keine.
    # Eine Änderung hier ist damit der einzige Griff, der im Haus ankommt.
    #
    # **Was das voraussetzt und wer es schuldet.** Der Entwurf nennt zwei Rückfallebenen im Haus,
    # und keine davon ist Software dieses Repositories: E0, ein Auto-Off-Timer von 30 min im Relais,
    # das K1 schaltet, und E1, die Wächter-Automation in Home Assistant auf den Bridge-Heartbeat
    # (`addons/duckcurve_bridge/DOCS.md`). E2 und E3 stehen im Code. Für K1 sind E0 und E1 nicht
    # zusätzliche Gurte, sondern die einzigen: die Freigabe geht zwingend über Home Assistant, und
    # dieser Weg überträgt die Laufzeitbegrenzung nicht. Wer diesen Wert auf `True` lässt, ohne dass
    # E0 und E1 stehen, hat für den Fall „DCH gibt frei und verstummt" keine Rückfallebene.
    #
    # Sichtbar ist der Zustand in `SystemStatusOut.hp_actuation`; der Dienst sagt ihn beim Start
    # auch als Warnung, damit er nicht still an ist.
    heat_pump_actuation_enabled: bool = True
    plan_refresh_min: int = 15
    # Wer die Mitteilung schickt. Web Push verlangt im VAPID-Anspruch eine Adresse, unter der der
    # Absender erreichbar waere. Eine echte Adresse gehoert nicht ins Repository, also steht hier
    # ein Platzhalter (derselbe wie `application.push.PLATZHALTER`). Bis zum 12.11.2026 endete er
    # auf `.invalid`, und Apples Push-Dienst lehnte damit jede Mitteilung ab (403 BadJwtToken):
    # er nimmt nur Absender an, deren Endung im oeffentlichen Netz vergeben ist. Solange der
    # Platzhalter steht, versucht der Dienst zuerst die Adresse der Oberflaeche, die das
    # angemeldete Geraet nennt; wer will, setzt DCH_PUSH_SUBJECT.
    push_subject: str = "mailto:duck-curve-home@example.org"

    # Live-Modus
    database_url: str = Field(default="", validation_alias="DATABASE_URL")
    db_create_all: bool = False  # nur SQLite/Tests: Schema ohne Alembic anlegen
    # Klartext-Tokens der Bridges (Secrets): JSON-Liste, kommagetrennt oder ein einzelnes Token
    bridge_tokens: Annotated[list[str], NoDecode] = Field(default_factory=list)
    api_token: str = (
        ""  # Bearer, den das Web-BFF mitschickt; leer = keine Prüfung (nur Entwicklung)
    )
    config_file: str = ""  # YAML mit site/pv_system/hems (config/hems.example.yaml)
    tibber_token: str = ""
    tibber_home_id: str = ""
    # Auflösung der Tibber-Preishistorie. Leer heißt: beim ersten Abruf im GraphQL-Schema nachsehen
    # und die feinste angebotene Auflösung nehmen - die Börse rechnet seit Oktober 2025 in
    # Viertelstunden. Ein hier gesetzter Wert überspringt die Abfrage und erzwingt ihn (z. B.
    # "HOURLY"). Die Tages- und Morgenpreise folgen ohnehin dem, was Tibber liefert.
    tibber_price_resolution: str = ""
    # myenergi-Cloud direkt (ohne Home Assistant): Hub-Seriennummer + API-Key aus der myenergi-App
    myenergi_serial: str = ""
    myenergi_api_key: str = ""
    myenergi_poll_s: float = 30.0
    myenergi_backfill_hours: int = 48  # Minutenhistorie beim Start nachladen; 0 = aus
    # Amtlicher Zähler bei inexogy (vormals Discovergy). Angemeldet wird mit der Kontomail und dem
    # Kontopasswort über HTTP Basic; einen API-Schlüssel gibt es dort nicht, und die dokumentierte
    # OAuth-Kette wäre vier Aufrufe für dasselbe Ergebnis. Das Passwort gehört in die Umgebung des
    # Dienstes und nirgendwo sonst hin.
    #
    # `inexogy_meter` darf leer bleiben: dann gewinnt der Zähler, der zuletzt gemeldet hat. Sonst
    # nimmt das Feld `meterId` oder eine der Seriennummern - die lange steht auf dem Gerät.
    inexogy_email: str = ""
    inexogy_password: str = ""
    inexogy_meter: str = ""
    inexogy_poll_s: float = 30.0
    inexogy_backfill_hours: int = 48  # Lücken beim Start nachtragen; 0 = aus
    # Entity-Mapping für den Import der HA-Historie (Sensorregeln wie im Bridge-YAML)
    import_entities_file: str = "config/entities.home.yaml"
    weather_refresh_min: int = 60
    price_refresh_min: int = 30
    # Wie lange Rohwerte liegen bleiben, nachdem sie zu Minutenzeilen verdichtet wurden.
    #
    # Sie werden dafür nur Minuten gebraucht: die Verdichtung läuft alle fünf Minuten, und danach
    # steht jede Minute dauerhaft in `measurements_minute`. Vierzehn Tage waren Vorrat für einen
    # Fall, der nicht eintrat, und `measurements_raw` ist mit Abstand die breiteste Tabelle: eine
    # Zeile je Messwert statt je Minute, dazu ein Schlüsselfeld, das in jeder Zeile und noch einmal
    # im Primärindex steht. Bei einer verwalteten Datenbank, die nach Arbeitsspeicher abgerechnet
    # wird, ist das der teuerste Posten im ganzen Programm.
    #
    # Drei Tage lassen einen Dienst, der zwei Tage stillstand, seine Rohwerte beim Start noch
    # verdichten. Der Platzbedarf steht in den Einstellungen unter „Platzbedarf".
    raw_retention_days: int = 3
    # Wie lange Prognoselaeufe vollstaendig liegen bleiben.
    #
    # Dreissig Tage reichen fuer die Frage, die sie beantworten sollen: wie viel besser die Prognose
    # wird, je naeher die Lieferung kommt. Wer das fuer einen Monat sehen kann, sieht es.
    # Darueber hinaus bleibt je Ortstag ein kanonischer Lauf, und der wird nie geloescht.
    forecast_run_retention_days: int = 30
    # Welche Stunde Ortszeit den kanonischen Day-ahead-Lauf bestimmt.
    #
    # Sechs Uhr, weil `forecast_evaluation` seine Tageswertung schon gegen diese Stunde rechnet. Zwei
    # verschiedene Begriffe von "der Lauf von gestern" waeren eine Fehlerquelle, die niemand findet.
    forecast_canonical_hour: int = 6

    @field_validator("cors_origins", "bridge_tokens", mode="before")
    @classmethod
    def _lists(cls, value: object) -> list[str]:
        return parse_list(value)

    @property
    def runs_api(self) -> bool:
        return self.role in ("all", "api")

    @property
    def runs_worker(self) -> bool:
        return self.role in ("all", "worker")


@lru_cache
def get_settings() -> Settings:
    return Settings()
