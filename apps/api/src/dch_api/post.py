"""Der Postausgang: Einladungen und Wiederherstellungslinks per E-Mail.

Konfiguriert allein über die Umgebung (`DCH_SMTP_*`, `DCH_RESEND_SCHLUESSEL`). Ohne
Konfiguration wird nichts verschickt; der Hausherr gibt den Link weiterhin von Hand weiter - er
steht auf der Seite „Zugang" zum Kopieren.

Zwei Regeln halten dieses Modul, übernommen aus `duckcurve/post.py`:

* **Der Versand ist eine Beigabe, kein Torwächter.** Eine Person, deren Einladung nicht hinausging,
  ist trotzdem angelegt; `verschicken` fängt jeden Versandfehler und meldet nur, ob es geklappt
  hat. Alles andere hieße, dass ein falsch eingetragener SMTP-Server das Anlegen von Personen
  verhindert.

* **Das Token fällt nirgends an.** Es steht im Link im Rumpf der Nachricht - nicht im Betreff,
  nicht im Protokoll und nicht in einer Fehlermeldung. Ein Protokolleintrag nennt höchstens die
  gekürzte Empfängeradresse.

Zwei Wege, weil ausgehendes SMTP in manchen Umgebungen gesperrt ist (Railway lässt Port 587 zu,
andere nicht). Ist beides eingetragen, gilt SMTP: ein eingetragener Server ist eine ausdrückliche
Festlegung.
"""

from __future__ import annotations

import asyncio
import smtplib
from email.message import EmailMessage
from email.utils import formataddr

import httpx
import structlog

from dch_api.settings import Settings

log = structlog.get_logger("post")

__all__ = ["aktiv", "fehlende_angaben", "versandweg", "verschicken"]

ABSENDER_NAME = "Duck Curve Home"
RESEND_URL = "https://api.resend.com/emails"

_BETREFF = {
    "einladung": "Ihr Zugang zu Duck Curve Home",
    "wiederherstellung": "Ihr Link für einen neuen Zugang",
}

_EINLEITUNG = {
    "einladung": (
        "für Sie wurde ein Zugang zu Duck Curve Home angelegt, der Steuerung dieses Hauses. "
        "Über den folgenden Link legen Sie einen Passkey an und sind damit angemeldet:"
    ),
    "wiederherstellung": (
        "für Ihren Zugang zu Duck Curve Home wurde ein neuer Link angefordert. Darüber legen Sie "
        "einen neuen Passkey an:"
    ),
}


def _verkuerzt(email: str) -> str:
    """Eine Adresse für das Protokoll: erster Buchstabe und Domäne."""
    name, _, domaene = email.partition("@")
    return f"{name[:1]}…@{domaene}" if domaene else "(ohne Adresse)"


def versandweg(settings: Settings) -> str:
    """Der geltende Weg: „smtp", „https" oder „" für keinen."""
    if settings.smtp_host.strip():
        return "smtp"
    if settings.resend_schluessel.strip():
        return "https"
    return ""


def _absender(settings: Settings) -> str:
    return settings.absender.strip() or settings.smtp_benutzer.strip()


def aktiv(settings: Settings) -> bool:
    """Ob verschickt werden kann: ein Weg, eine Absenderadresse und eine Adresse für den Link."""
    return bool(versandweg(settings) and _absender(settings) and settings.anmeldung_url)


def fehlende_angaben(settings: Settings) -> list[str]:
    """Was fehlt, in den Namen der Umgebungsvariablen - für die Seite „Zugang"."""
    fehlt = []
    if not versandweg(settings):
        fehlt.append("DCH_SMTP_HOST oder DCH_RESEND_SCHLUESSEL")
    if not _absender(settings):
        fehlt.append("DCH_ABSENDER")
    if not settings.anmeldung_url:
        fehlt.append("DCH_ANMELDE_URL")
    return fehlt


def _text(anzeigename: str, link: str, zweck: str, stunden: int) -> str:
    anrede = f"Hallo {anzeigename}," if anzeigename else "Hallo,"
    return (
        f"{anrede}\n\n"
        f"{_EINLEITUNG.get(zweck, _EINLEITUNG['einladung'])}\n\n"
        f"{link}\n\n"
        f"Der Link gilt {stunden} Stunden und nur einmal. Ein Passkey ist kein Passwort: er bleibt "
        "auf Ihrem Gerät und wird mit Fingerabdruck, Gesicht oder Geräte-PIN freigegeben.\n\n"
        "Nach dem Einrichten sehen Sie zehn Wiederherstellungscodes. Bewahren Sie sie auf. Sie "
        "sind der Weg zurück, wenn Ihr Gerät verloren geht.\n\n"
        "Wenn Sie das nicht erwartet haben, ignorieren Sie diese Nachricht; ohne den Link "
        "geschieht nichts.\n\n"
        "Duck Curve Home\n"
    )


def _nachricht(settings: Settings, empfaenger: str, betreff: str, rumpf: str) -> EmailMessage:
    nachricht = EmailMessage()
    nachricht["From"] = formataddr((ABSENDER_NAME, _absender(settings)))
    nachricht["To"] = empfaenger
    nachricht["Subject"] = betreff
    nachricht.set_content(rumpf)
    return nachricht


def _per_smtp(settings: Settings, nachricht: EmailMessage) -> None:
    """Blockierender Versand - läuft in einem Thread, damit die Ereignisschleife frei bleibt."""
    if settings.smtp_sicherheit == "ssl":
        verbindung: smtplib.SMTP = smtplib.SMTP_SSL(
            settings.smtp_host, settings.smtp_port, timeout=settings.smtp_zeitlimit_s
        )
    else:
        verbindung = smtplib.SMTP(
            settings.smtp_host, settings.smtp_port, timeout=settings.smtp_zeitlimit_s
        )
    with verbindung:
        if settings.smtp_sicherheit == "starttls":
            verbindung.starttls()
        if settings.smtp_benutzer:
            verbindung.login(settings.smtp_benutzer, settings.smtp_passwort)
        verbindung.send_message(nachricht)


async def _per_https(settings: Settings, empfaenger: str, betreff: str, rumpf: str) -> None:
    async with httpx.AsyncClient(timeout=settings.smtp_zeitlimit_s) as client:
        antwort = await client.post(
            RESEND_URL,
            headers={"authorization": f"Bearer {settings.resend_schluessel.strip()}"},
            json={
                "from": formataddr((ABSENDER_NAME, _absender(settings))),
                "to": [empfaenger],
                "subject": betreff,
                "text": rumpf,
            },
        )
        antwort.raise_for_status()


async def verschicken(
    settings: Settings, empfaenger: str, anzeigename: str, link: str, zweck: str
) -> bool:
    """Verschickt den Zugangslink. Gibt zurück, ob es geklappt hat - und wirft nie.

    Der Aufrufer hat die Person schon angelegt; ein Versandfehler darf das nicht zurücknehmen.
    Was schiefging, steht im Protokoll, ohne Adresse und ohne Token.
    """
    if not aktiv(settings):
        return False
    betreff = _BETREFF.get(zweck, _BETREFF["einladung"])
    rumpf = _text(anzeigename, link, zweck, settings.zugangstoken_stunden)
    weg = versandweg(settings)
    try:
        if weg == "smtp":
            await asyncio.to_thread(
                _per_smtp, settings, _nachricht(settings, empfaenger, betreff, rumpf)
            )
        else:
            await _per_https(settings, empfaenger, betreff, rumpf)
    except (OSError, smtplib.SMTPException, httpx.HTTPError) as fehler:
        # Nur die Art des Fehlers, nicht die Nachricht: eine Ablehnung des Servers kann die
        # Empfängeradresse enthalten.
        log.warning(
            "einladung nicht verschickt",
            weg=weg,
            empfaenger=_verkuerzt(empfaenger),
            fehler=type(fehler).__name__,
        )
        return False
    log.info("einladung verschickt", weg=weg, empfaenger=_verkuerzt(empfaenger), zweck=zweck)
    return True
