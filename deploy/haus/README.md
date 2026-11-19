# Duck Curve Home auf dem Hausgerät installieren

Stand 19.11.2026. Diese Anleitung bringt Duck Curve Home auf einen Raspberry Pi (CM5 auf der IO-Platine,
genauso ein Pi 5) mit NVMe-SSD. Hintergrund und Entscheidungen: [`docs/HAUSGERAET.md`](../../docs/HAUSGERAET.md).

## Was diese Stufe tut

**Stufe 1: Home Assistant bleibt, wie er ist.** Datenbank, Regelung und Oberfläche ziehen auf das
Hausgerät; die Bridge in Home Assistant schickt ihre Daten künftig dorthin statt zu Railway.

```
Home Assistant (bisheriger Pi)                Hausgerät (CM5)
┌───────────────────────────────┐             ┌────────────────────────────────────────────┐
│ Bridge-Add-on ───── ws:8001 ──┼────────────▶│ caddy ── api (Regelung, Live, Alfred)      │
│ Mosquitto, eBUS (Add-ons)     │             │   │        └── postgres (eigene Datenbank) │
│ Shellys, Alarm, Ofen, ...     │             │   └── web (Oberfläche) ◀── Kiosk-Display   │
└───────────────────────────────┘             │ Sicherung jede Nacht                        │
                                              └────────────────────────────────────────────┘
iPad / Handy im Heimnetz ── https://duckcurve-home.local ──▶ caddy ──▶ web
unterwegs (optional) ── home.duckcurve.de ── Cloudflare Tunnel ──▶ web
```

| Dienst | Aufgabe |
|---|---|
| `postgres` | die eigene Datenbank (PostgreSQL 17) |
| `api` | Regelung, Live-Zustand, Auswertungen, Alfred; spielt beim Start die Migrationen ein |
| `web` | die Oberfläche |
| `caddy` | HTTPS im Heimnetz, Stammzertifikat zum Herunterladen, Port 8001 nur für die Bridge |
| `cloudflared` | optional: Zugang von unterwegs ohne offenen Port |
| Sicherung | jede Nacht gegen 03:15 ein `pg_dump`, 14 bleiben, optional eine Kopie außer Haus |
| Kiosk | optional: nur die Anwendung auf einem angeschlossenen Display, mit Duck-Curve-Startbild |

Mosquitto, eBUS-Dienst und die Bridge selbst bleiben vorerst Add-ons in Home Assistant. Sie ziehen
in Stufe 2 um (unten, „Was noch fehlt“).

## 1. Raspberry Pi OS auf die SSD

1. Die SSD in einen USB-NVMe-Adapter stecken und am eigenen Rechner mit dem
   **Raspberry Pi Imager** bespielen: Gerät „Raspberry Pi 5“ (gilt auch für den CM5),
   Betriebssystem **Raspberry Pi OS Lite (64-bit)**.
2. In den Einstellungen des Imagers vorab setzen: Hostname `duckcurve-home`, Benutzer mit eigenem
   Passwort, **SSH mit öffentlichem Schlüssel**, WLAN (falls kein Kabel), Zeitzone Europe/Berlin.
3. SSD auf die IO-Platine setzen (Abstandshalter in das Loch für die Länge der SSD), einschalten.
   Startet der CM5 nicht von der SSD, zeigt die Startreihenfolge noch auf eMMC oder SD; das
   Einrichtungsskript stellt sie unten ein, für den allerersten Start hilft eine SD-Karte mit
   demselben System und danach `sudo rpi-eeprom-config --edit` (`BOOT_ORDER=0xf461`).
4. Im Router dem Gerät eine **feste IP-Adresse** geben. Die Bridge in Home Assistant spricht es
   über diese Adresse an.

## 2. Die Images freigeben (einmalig, auf GitHub)

GitHub baut die Images bei jedem Push auf `main` für arm64 und amd64 und legt sie unter
`ghcr.io/moritznobis87/duckcurve-api` und `…/duckcurve-web` ab. Neue Pakete sind dort zunächst
**privat**. Entweder einmal auf öffentlich stellen (GitHub → Profil → Packages → Paket →
Package settings → Change visibility → Public), für beide Pakete. Oder auf dem Gerät anmelden:

```bash
echo <GitHub-Token mit read:packages> | sudo docker login ghcr.io -u moritznobis87 --password-stdin
```

Ohne Freigabe endet der erste Start mit „denied“ beim Laden der Images. Notfalls baut das Gerät
selbst (`einrichten.sh --bauen`), das dauert aber und braucht viel Speicher.

## 3. Einrichten

Per SSH auf dem Gerät:

```bash
sudo apt-get install -y git
```

```bash
sudo git clone https://github.com/moritznobis87/DuckCurveHome.git /opt/duckcurve-quelle
```

```bash
sudo /opt/duckcurve-quelle/deploy/haus/einrichten.sh
```

Mit angeschlossenem Display zusätzlich `--kiosk`. Weitere Schalter: `--help`. Das Skript installiert
Docker, legt `/opt/duckcurve` mit eigenen Geheimnissen an, richtet die Systemdienste und die nächtliche
Sicherung ein, stellt den Bootloader ein (SD-Karte vor NVMe, damit eine eingelegte Karte zur Wartung
startet; mit Marke ohne Pi-Diagnosebildschirm) und ersetzt das Startbild. Am Ende steht, ob ein
Neustart nötig ist.

Es lässt sich jederzeit erneut ausführen. Die Einstellungen in `/opt/duckcurve/.env` werden dabei nie
überschrieben.

## 4. Einstellungen von Railway übernehmen

```bash
sudo nano /opt/duckcurve/.env
```

Unter „Von Railway übernehmen“ die Werte aus den Variablen des Railway-Dienstes **api** eintragen:
Tibber, myenergi, inexogy, die Mitteilungen an die iOS-App und, falls gewünscht, der Schlüssel für
Alfred. Danach:

```bash
sudo dch neustart
```

Die Zugangsdaten (`DCH_API_TOKEN`, `DCH_BRIDGE_TOKENS`, `DCH_SESSION_SECRET`, `DCH_KIOSK_TOKEN`)
sind neu erzeugt und bleiben so; die alten von Railway braucht das Gerät nicht.

## 5. Die Daten von Railway übernehmen

In Railway beim Dienst **Postgres** unter „Connect“ die öffentliche Adresse kopieren
(`DATABASE_PUBLIC_URL`, beginnt mit `postgresql://`). Dann:

```bash
sudo dch uebernehmen 'postgresql://…'
```

Das lädt die Datenbank herunter, sichert vorher den Stand auf dem Gerät und spielt sie ein. Die API
startet danach neu und bringt das Schema auf den Stand ihres Codes. Die Übernahme lässt sich
wiederholen, etwa unmittelbar vor dem Umstellen der Bridge, damit möglichst wenig fehlt.

## 6. Die Bridge umstellen

```bash
sudo dch koppeln
```

zeigt die beiden Werte für das **Bridge-Add-on** in Home Assistant (Einstellungen → Add-ons →
Duck Curve Home Bridge → Konfiguration): `api_ws_url` (`ws://<IP des Geräts>:8001/bridge/ws`) und
`api_token`. Eintragen, Add-on neu starten. Im Protokoll des Add-ons erscheint „uplink connected“.

Ab jetzt regelt das Hausgerät. **Geschaltet wird nur über die Bridge**: Solange sie mit Railway
verbunden war, hat das Gerät nichts geschaltet, und ab jetzt schaltet Railway nichts mehr. Zwei
Regler an denselben Kontakten gibt es dadurch nie.

Zwei Dinge danach:

- Die **Speicher-Automatik** steht nach jedem Start eines Dienstes auf „aus“ und sendet dann nichts
  an den Libbi. Wer sie auf Railway benutzt hat, stellt sie auf dem Gerät wieder auf „Auto“ und auf
  Railway auf „aus“.
- **Zurück zu Railway** geht jederzeit: die alten Werte im Add-on eintragen und neu starten.

## 7. iPad und Handy im Heimnetz

`sudo dch koppeln` nennt auch diese beiden Schritte:

1. `http://duckcurve-home.local/zertifikat` öffnen und das Profil installieren. Auf dem iPad danach
   unter Einstellungen → Allgemein → Info → Zertifikatsvertrauenseinstellungen „Caddy Local
   Authority“ einschalten. Ohne das zeigt Safari eine Warnung, und die Anmeldung hält nicht.
2. Den Pairing-Link öffnen (`https://duckcurve-home.local/pair?token=…&name=iPad-Flur`). Das Gerät
   bleibt 180 Tage angemeldet.

## 8. Zugang von unterwegs (optional)

Mit Cloudflare Tunnel, ohne offenen Port am Router:

1. In Cloudflare Zero Trust → Networks → Tunnels einen Tunnel anlegen, Typ „cloudflared“, und das
   Token kopieren.
2. Im Tunnel einen Public Hostname anlegen: `home.duckcurve.de` → Service `http://web:3000`.
   Damit zeigt der Name nicht mehr auf Railway, sondern auf das Gerät.
3. In `/opt/duckcurve/.env` `CLOUDFLARE_TUNNEL_TOKEN=…` und `DCH_FERNZUGANG=1` setzen, dann
   `sudo dch neustart`.
4. Empfohlen: in Cloudflare Access eine Anmeldung vor den Namen legen (E-Mail-Code), als zweite
   Schranke vor dem Pairing der Anwendung.

## 9. Sicherung

Jede Nacht gegen 03:15 sichert das Gerät die Datenbank nach `/var/lib/duckcurve/sicherung`; die
neuesten 14 bleiben (`DCH_SICHERUNG_BEHALTEN`). Für eine Kopie außer Haus einmal ein Ziel mit
`sudo rclone config` einrichten (etwa Cloudflare R2 oder Backblaze B2) und in `.env`
`DCH_SICHERUNG_ZIEL=<ziel>:<ordner>` setzen. Vor jedem `dch aktualisieren` sichert das Gerät
zusätzlich von selbst.

## Im Alltag: `dch`

| Befehl | Wirkung |
|---|---|
| `sudo dch status` | Dienste, Gesundheit, Version |
| `sudo dch logs [api\|web\|postgres\|caddy]` | Protokoll folgen |
| `sudo dch neustart` | nach einer Änderung an `.env` |
| `sudo dch aktualisieren [version]` | neue Images ziehen und neu starten (vorher Sicherung) |
| `sudo dch selbst-aktualisieren` | Quelltext holen und die Einrichtung erneut ausführen |
| `sudo dch sichern` / `sicherungen` | jetzt sichern / Sicherungen auflisten |
| `sudo dch wiederherstellen <datei>` | Datenbank aus einer Sicherung |
| `sudo dch uebernehmen <url>` | Datenbank von Railway oder einem anderen Postgres |
| `sudo dch koppeln` | Werte für das Bridge-Add-on, Zertifikat- und Pairing-Link |

## Kiosk und Startbild

Mit `--kiosk` startet das Gerät ohne Desktop direkt in die Anwendung: `cage` zeigt genau ein
Programm, Chromium im Kioskmodus, als Benutzer `kiosk` ohne Rechte. Bis die Dienste bereit sind,
zeigt es eine Duck-Curve-Ladeseite statt einer Fehlerseite des Browsers. Chromium-Richtlinien
sperren alles außer der Anwendung (keine anderen Adressen, keine Entwicklerwerkzeuge, keine
Downloads), Textkonsole, SysRq und Strg+Alt+Entf sind aus.

Ohne `--ohne-marke` ersetzt das Skript das Startbild durch das Duck-Curve-Symbol, schaltet
Regenbogen, Himbeeren und Kernelmeldungen ab und den Diagnosebildschirm des Bootloaders aus.

**Am Gerät noch zu prüfen**, weil es hier keine Hardware dafür gab: ob das Touch Display 2 an der
IO-Platine läuft und wie es ins Querformat gedreht wird, ob `cage` den Wechsel auf die Textkonsole
wirklich sperrt, und ob beim Start irgendwo noch etwas Fremdes aufblitzt (den Start einmal filmen).

## Was noch fehlt (Stufe 2 und später)

- Mosquitto, eBUS-Dienst und die Bridge als Dienste auf dem Gerät; danach Home Assistant nur noch
  für die Alarmanlage (Q12 in `docs/OPEN_QUESTIONS.md`).
- Der Wächter (guardian) auf dem Gerät. Heute liegt die Rückfallebene E1 als Automation in Home
  Assistant und bleibt dort, solange die Bridge dort läuft.
- Firewall, schreibgeschütztes System, Wartungsmodus, Erststart-Dienst und Werkstatt-Stick
  (`docs/HAUSGERAET.md`, Abschnitte 4, 7 und 8).

## Wie das hier getestet wurde

Am 19.11.2026 in einem Linux-Container (amd64) mit Docker, nicht auf einem Pi: Einrichtung im
Dateimodus (`DCH_NUR_DATEIEN=1`), Stack mit selbst gebauten Images gestartet, Migrationen auf einer
leeren Datenbank, HTTPS mit dem heruntergeladenen Stammzertifikat, Koppeln und Sperre ohne Sitzung,
Kompression, Bridge-Verbindung über Port 8001 (richtiges Token verbunden, falsches mit 403
abgewiesen), Sicherung, Aufbewahrung, Wiederherstellung, Übernahme aus einer zweiten Postgres-Instanz
und die Ladeseite des Kiosks bis in die Anwendung. Nicht getestet: Pakete, systemd, Bootloader,
Startbild und Kiosk auf echter Hardware.
