# Das Hausgerät: Duck Curve Home auf einem eigenen Rechner

Stand 19.11.2026. **Stufe 1 ist gebaut** (Home Assistant bleibt, Datenbank, Regelung und Oberfläche
auf dem Gerät): Installation und Bedienung in [`deploy/haus/README.md`](../deploy/haus/README.md). Der
Rest dieses Papiers ist Plan. Ausgangspunkt ist Profil A aus Abschnitt 15 des
[Projektplans](PROJECT_PLAN.md): alles im Haus auf einem Mini-Rechner, Railway entfällt. Dieses Papier
ergänzt, was dort fehlt: Geschwindigkeit von unterwegs, Transferdienst, Betriebssystem, Kioskmodus, Marke,
Wartungszugänge und wie ein Gerät zum Kunden kommt. Der Umbau ist vorgemerkt, aber noch nicht freigegeben
([Q12](OPEN_QUESTIONS.md)).

Alle Zeiten und Datenmengen ohne Quelle sind **geschätzt** und werden am ersten Gerät gemessen.

## 1. Geschwindigkeit: Ist die Leitung nach Hause der Engpass?

**Zu Hause wird es schneller als heute.** Heute geht jede Anfrage des iPads ins Internet zu Railway und
zurück. Künftig bleibt sie im eigenen Netz, und Regelung und Anzeige laufen bei einem Internetausfall weiter.

**Von unterwegs ist der Upload des Hausanschlusses die Engstelle, aber die Mengen sind klein.** Der
Live-Zustand ist 4,5 kB je Meldung (gemessen 03.11.2026, `settings.py` zu `live_push_min_s`), alle fünf
Sekunden, also rund 1 kB/s. Eine Auswertungsseite ist JSON von einigen 10 kB, komprimiert ein Fünftel bis ein
Zehntel davon. Spürbar ist eher die zusätzliche Laufzeit über den Tunnel, geschätzt 30 bis 80 ms mehr als
heute.

**Ladeanzeigen entstehen durch drei andere Dinge, und gegen die wird gebaut:**

1. *Rechenzeit auf dem Pi.* Seiten lesen vorberechnete Stunden- und Tagesbilanzen, nie Rohwerte. Die
   Datenbank liegt auf einer NVMe-SSD, nicht auf einer SD-Karte.
2. *Viele Anfragen hintereinander.* Eine Seite stellt eine oder zwei Anfragen, nicht zehn nacheinander.
3. *Nichts zeigen, bis alles da ist.* Der Service Worker (`apps/web/public/sw.js`) hält den zuletzt
   bekannten Stand; die Seite zeigt ihn sofort und frischt im Hintergrund auf.

Dazu: Antworten komprimiert (Caddy), statische Teile der App (JavaScript, Schriften, Bilder) bei Cloudflare
zwischengespeichert, damit über den Upload nur Daten laufen.

**Das eigentliche Risiko** ist ein Internetausfall zu Hause: Dann ist das Haus von unterwegs nicht erreichbar.
Ein schreibgeschützter Spiegel der Zusammenfassungen in der Cloud wäre die Antwort darauf; er ist bewusst
nicht Teil der ersten Ausbaustufe.

## 2. Hardware

| Teil | Warum |
|---|---|
| Raspberry Pi 5, 8 GB | 4 GB reichen für den Stack (Messung in `DEPLOYMENT.md`, Abschnitt 2b); 8 GB, falls Home Assistant mit auf das Gerät soll. Der Arbeitsspeicher ist aufgelötet und lässt sich nicht nachrüsten |
| NVMe-SSD am M.2 HAT+ | Datenbank und System; eine SD-Karte hält das dauernde Schreiben nicht lange aus |
| Offizielles 27-W-Netzteil, aktiver Lüfter | Unterspannung und Hitze bremsen den Pi und blenden Warnsymbole ein |
| RTC-Batterie am Uhrenanschluss des Pi 5 | Nach einem Stromausfall ohne Internet kennt der Rechner sonst die Uhrzeit nicht, und Preisfenster brauchen sie |
| Kleine USV oder USV-HAT | sauberes Herunterfahren statt hartem Abschalten |
| Geschlossenes Gehäuse mit Duck-Curve-Aufdruck | siehe Abschnitt 6 |

**Keine SD-Karte im ausgelieferten Gerät.** Siehe Abschnitt 8.

## 3. Die Dienste

Ein Gerät, Docker Compose, dieselben Images wie heute (`DCH_GATEWAY=inprocess`, Projektplan 15.4).

| Dienst | Aufgabe |
|---|---|
| `postgres` | PostgreSQL 16 oder 17, offizielles arm64-Image, Daten auf der SSD. Keine Zeitreihen-Datenbank nötig: Der Bestand bleibt laut Projektplan 16.3 unter etwa 5 GB. `shared_buffers` auf 512 MB bis 1 GB |
| `migrate` | Alembic vor dem Start von `api` und `worker`, nur additiv (Projektplan 23.4) |
| `api` | FastAPI: REST, Live-Strom, Alfred |
| `worker` | Regelung, Planer, Prognosen, Verdichtung, direkte Geräteanbindung |
| `web` | Next.js-Oberfläche |
| `mosquitto` | MQTT-Broker für die Shellys, heute ein Home-Assistant-Add-on |
| `ebusd` | eBUS der Wärmepumpe, heute das Add-on `addons/duckcurve_ebusd` |
| `bridge` | Transferdienst zu Home Assistant, siehe unten |
| `guardian` | unabhängiger Wächter, schaltet die Kontakte bei einem Absturz sicher ab (Projektplan 11.2, E1) |
| `caddy` | lokales HTTPS (`https://home.local`) und Kompression |
| `cloudflared` | Zugang von unterwegs ohne offenen Port, Cloudflare Access als Login davor |
| `backup` | nächtlicher `pg_dump`: eine Kopie lokal, eine außer Haus (R2 oder B2). Ohne Railway sichert sonst niemand |
| `kiosk` | nur mit angeschlossenem Display, Abschnitt 5; läuft als Systemdienst, nicht im Container |

**Der Transferdienst ist die vorhandene Bridge.** Sie spricht heute schon mit Home Assistant auf der einen und
mit der API auf der anderen Seite; auf dem Hausgerät zeigt sie auf die lokale API statt auf Railway. Zu holen
bleiben laut Q12 die Alarmanlage (Lupusec) und drei Shelly-Einträge. Sind sie direkt angebunden, wird die
HA-Verbindung abgeschaltet. Was dafür im Code zu tun ist, steht in Q12.

**Home Assistant** bleibt während des Umzugs auf dem bisherigen Pi. Danach läuft es als Container mit auf dem
Hausgerät oder entfällt, sobald auch die Alarmanlage direkt angebunden ist.

## 4. Betriebssystem

Raspberry Pi OS **Lite**, 64 Bit, ohne Desktop. Ein Desktop wäre Angriffsfläche und etwas, das ein Nutzer
sehen könnte.

- **Schreibgeschütztes System** (Overlay-Dateisystem): Nur Datenbank, Docker-Daten und Einstellungen liegen auf
  einer beschreibbaren Partition. Das Gerät übersteht hartes Ausschalten wie ein Haushaltsgerät.
- **Updates:** Anwendung über Images aus der GitHub Container Registry. **Gebaut:** Das Gerät sieht alle
  sechs Stunden nach, die App zeigt dem Hausherrn einen Hinweis, installiert wird auf Knopfdruck mit Sicherung
  vorher, Gesundheitsprüfung danach und automatischer Rückkehr zur vorherigen Fassung
  (`deploy/haus/README.md`, Abschnitt 10). Heute folgt das eigene Haus dem Kanal `main`; für Kundengeräte
  ist ein Release-Tag als Kanal und ein Wartungsfenster vorgesehen (Projektplan 15.2). Sicherheitsupdates
  des Systems automatisch (`unattended-upgrades`). Ein Gerät wird für ein Update nie neu bespielt.
- **Firewall** lässt nur das Nötige aus dem Heimnetz zu (HTTPS, MQTT für die Shellys).

## 5. Kioskmodus: nur die Anwendung

Gilt, wenn ein Display am Gerät hängt. Das iPad an der Wand braucht nichts davon.

- **Ein Programm statt eines Desktops:** `cage`, ein Wayland-Compositor für genau eine Anwendung, startet
  Chromium im Modus `--kiosk` mit `http://localhost:3000`. Keine Taskleiste, keine Fenster, nichts zum
  Umschalten.
- **Start:** ein systemd-Dienst als eigener Benutzer `kiosk` ohne Rechte und ohne Passwort. Er startet erst,
  wenn `web` gesund antwortet, und zeigt bis dahin die lokale Ladeseite (Abschnitt 6). Stürzt Chromium ab,
  startet systemd es neu (`Restart=always`).
- **Chromium-Richtlinien** (`/etc/chromium/policies/managed/`): nur `localhost` und `home.local` erlaubt,
  alles andere gesperrt (`URLBlocklist: *`, damit auch `chrome://` und `file://`), keine Entwicklerwerkzeuge
  (`DeveloperToolsAvailability`), keine Downloads (`DownloadRestrictions`), kein Drucken (`PrintingEnabled`),
  kein Inkognito, keine Übersetzungsleiste, kein Hinweis „wurde nicht richtig beendet“.
- **Kein Weg auf die Konsole:** Wechsel auf die Textkonsolen gesperrt (laut Erinnerung bei `cage` ohne
  Schalter ohnehin aus; am Gerät zu prüfen), `kernel.sysrq=0`, `ctrl-alt-del.target` maskiert, kein Login
  auf dem Bildschirm, kein automatisches Einhängen von USB-Sticks, Mauszeiger bei Touch ausgeblendet.
- **Grenze:** Das schützt vor jemandem vor dem Bildschirm, nicht vor jemandem, der das Gehäuse öffnet und
  die SSD ausbaut. Eine Verschlüsselung ohne Sicherheitschip ist auf dem Pi mühsam; für ein Gerät im Haus des
  Kunden ist das vertretbar.

## 6. Marke: vom Einschalten an nur Duck Curve

Ein Kunde soll den Eindruck haben, ein Duck-Curve-Gerät vor sich zu haben. Jede Stelle, an der der Pi von
sich aus etwas zeigt, wird ersetzt oder abgeschaltet:

| Was der Pi zeigen würde | Lösung |
|---|---|
| Diagnosebildschirm des Bootloaders (Pi-Logo, Infos, QR-Code) | im Bootloader abschalten (`DISABLE_HDMI=1` per `rpi-eeprom-config`) |
| Regenbogen-Bildschirm | `disable_splash=1` in `config.txt` |
| Himbeeren und Kernelmeldungen | `logo.nologo quiet loglevel=0 vt.global_cursor_default=0`, Konsole auf tty3 (`cmdline.txt`) |
| Raspberry-Pi-Startbild (Plymouth „pix“) | eigenes Plymouth-Theme aus `apps/web/public/brand/` (Ente, Logo), beim Hoch- und Herunterfahren |
| Blitz- oder Thermometer-Symbol | `avoid_warnings=1`, vor allem aber das richtige Netzteil |
| Login, Desktop, Hintergrundbild | gibt es nicht (Abschnitt 5) |
| Chromium-Fehlerseite, solange die Dienste starten | lokale Duck-Curve-Ladeseite auf dem Gerät, die wartet und dann in die App wechselt; dieselbe Seite, falls die App hängt |
| „raspberrypi“ in der Geräteliste des Routers | Hostname `duckcurve-home` |

Ablauf für den Kunden: ein bis zwei Sekunden schwarz (Hardware), dann das Duck-Curve-Logo mit Animation,
bis die Dienste bereit sind (geschätzt 30 bis 60 Sekunden), dann nahtlos Ladeseite und App.

Was bleibt: Manche Router zeigen anhand der Netzwerkkarte den Hersteller „Raspberry Pi Trading“, und auf der
Platine steht das Pi-Logo; das geschlossene Gehäuse deckt Letzteres ab. Der Einsatz in einem eigenen Produkt
ist erlaubt, solange nicht mit der Marke Raspberry Pi geworben wird.

**Abnahme:** Beim ersten echten Gerät den Startvorgang filmen und Bild für Bild prüfen.

## 7. Wartungszugänge

Für den Kunden unsichtbar, nur mit einem Schlüssel zu öffnen, den er nicht hat. Sortiert danach, wie oft man
sie braucht:

1. **Fernwartung über ein privates Netz** (Tailscale oder Cloudflare Tunnel mit SSH). Das Gerät meldet sich
   von sich aus an; beim Kunden wird kein Port geöffnet. SSH nur mit Schlüssel, jedes Gerät mit eigener
   Kennung, einzeln sperrbar. Deckt Protokolle, Neustarts, Updates und Sicherungen ab.
2. **Versteckter Wartungsmodus in der App** für den Techniker vor Ort: eine geheime Geste und ein Geräte-PIN
   öffnen eine Wartungsseite in Duck-Curve-Optik. Darauf: WLAN einrichten, Netzwerkstatus, Dienste neu
   starten, Update, Protokolle, Werksreset, Schalter „Fernwartung erlauben“. Keine Kommandozeile, sondern eine
   feste Liste von Aktionen, die ein kleiner Systemdienst ausführt. Neue Rolle `service` neben `owner` und
   `guest`.
   **Teilweise gebaut (20.11.2026), für den Hausherrn statt für den Techniker:** die Seite *System →
   Hausgerät* in Browser und iOS-App mit Gesundheit aller Dienste und des Rechners, Protokollen, Neustarts,
   Sicherung und Updates, ausgeführt über eine feste Liste von Handgriffen (`dch anfrage`,
   `deploy/haus/README.md`, Abschnitt 11). Offen: WLAN, Werksreset, Fernwartungsschalter, Rolle `service`.
3. **Wartungs-USB-Stick** ohne Netz: Ein Stick mit einer **signierten** Freischaltdatei öffnet den Zugang für
   einige Stunden (SSH im lokalen Netz oder Textkonsole). Ohne gültige Signatur geschieht nichts.
4. **Gehäuse auf:** serielle Konsole am eigenen Anschluss des Pi 5; notfalls Wiederherstellungsstick, Image
   neu, Daten aus der Sicherung außer Haus.

Regeln dazu:

- **Keine Standardpasswörter**, auch nicht vorübergehend; Schlüssel je Gerät.
- **Jeder Zugriff wird protokolliert** (wer, wann, welcher Weg), im vorhandenen Ereignisprotokoll.
- **Der Kunde stimmt zu.** Aus Verbrauchsdaten lässt sich ablesen, wann jemand zu Hause ist. Fernwartung
  gehört in den Vertrag (Auftragsverarbeitung nach DSGVO) und bekommt einen Schalter, den der Kunde sieht.

Für das eigene Haus genügt Weg 1; die Wege 2 bis 4 kommen mit dem ersten Kundengerät.

## 8. Wie ein Gerät zum Kunden kommt

**Ein Image, individuell erst beim ersten Start.** Jedes Gerät bekommt dasselbe fertige Abbild auf die
NVMe-SSD. Was ein Gerät einzigartig macht, entsteht beim ersten Einschalten durch einen Erststart-Dienst:
Hostname, Schlüssel für die Fernwartung, Anmeldung im Wartungsnetz, Tokens für Kiosk und API, Geräte-PIN.
Das Abbild enthält deshalb kein einziges Geheimnis, und ein verlorenes Abbild öffnet kein Gerät.

**Keine SD-Karte beim Kunden.** Der Pi 5 startet direkt von der NVMe-SSD. Eine SD-Karte im Gerät wäre eine
zweite Startquelle, die sich herausziehen lässt, die schneller verschleißt und die beim nächsten Neustart
etwas anderes starten könnte. Der Kartenschlitz bleibt leer.

**Zwei Wege, die SSD zu bespielen:**

| Weg | Ablauf | Wofür |
|---|---|---|
| SSD vor dem Einbau | SSD per USB-NVMe-Adapter am eigenen Rechner bespielen (Raspberry Pi Imager oder `bmaptool`), einbauen, einschalten | die ersten Geräte, das eigene Haus |
| Werkstatt-Stick | Das fertig montierte Gerät startet einmal von einem USB-Stick. Der schreibt das Abbild auf die NVMe, stellt den Bootloader ein, prüft das Ergebnis und meldet „fertig“ auf dem Bildschirm oder per LED. Stick ab, Gerät verpacken | ab einer Kleinserie: kein Adapter, kein Aufschrauben, mehrere Geräte nebeneinander |

Der Werkstatt-Stick bleibt in der Werkstatt; der Kunde bekommt nie einen Stick oder eine Karte.

**Bootloader-Einstellungen leben auf der Platine, nicht auf der SSD** (`DISABLE_HDMI`, Startreihenfolge).
Ein neues Abbild auf der SSD ändert sie nicht. Der Werkstatt-Stick setzt sie mit; beim Weg über den Adapter
setzt der Erststart-Dienst sie per `rpi-eeprom-config` und startet einmal neu.

**Später, bei größeren Stückzahlen:** ein Compute Module 5 mit fest verlötetem eMMC auf einer eigenen
Trägerplatine. Es wird in der Fertigung über USB bespielt, hat keinen herausnehmbaren Speicher und wirkt noch
mehr wie ein eigenes Produkt. Für die ersten Geräte ist der normale Pi 5 einfacher.

## 9. Umzug des eigenen Hauses

1. Hausgerät mit dem Stack im Demo-Modus aufsetzen, mit Kiosk, Marke und Backup.
2. Datenbank von Railway übernehmen (`pg_dump`, `pg_restore`).
3. Bridge in Home Assistant auf die API des Hausgeräts umstellen, zunächst **ohne Schalten**
   (`DCH_HEAT_PUMP_ACTUATION_ENABLED=false`): Railway regelt weiter, das Hausgerät rechnet im Schatten mit.
   Zwei Regler an denselben Kontakten schalten nie gleichzeitig.
4. Nach einigen Tagen Vergleich die Rollen tauschen.
5. Mosquitto und eBUS auf das Hausgerät umziehen; die Shellys bekommen die neue Broker-Adresse.
6. iPad auf `home.local`, Zugang von unterwegs über den Tunnel.
7. Railway nach zwei bis drei Wochen abschalten.

## 10. Bausteine im Repository

| Baustein | Inhalt |
|---|---|
| `deploy/haus/compose.yaml` | **gebaut (Stufe 1):** postgres, api, web, caddy, cloudflared; Mosquitto, eBUS und Bridge folgen in Stufe 2 |
| `deploy/haus/einrichten.sh`, `deploy/haus/dch` | **gebaut:** Docker, Dienste, Sicherung, Updates aus der App mit Rückkehr, Gesundheitsbericht und Handgriffe für die Seite „Hausgerät“, Bootloader, Kiosk, Marke, Übernahme von Railway; offen: Firewall, Overlay |
| `deploy/haus/marke/`, `deploy/haus/kiosk/` | **gebaut:** Plymouth-Theme, Ladeseite, Chromium-Richtlinien |
| `deploy/haus/erststart/` | Erststart-Dienst: Hostname, Schlüssel, Wartungsnetz, Bootloader |
| `deploy/haus/werkstatt/` | Werkstatt-Stick: Abbild schreiben, prüfen, melden |
| Image-Bau | aus dem Einrichtungsskript ein Abbild (pi-gen oder `rpi-image-gen`), erst wenn das Skript steht |
| Code (Q12) | HA-Verbindung der Bridge abschaltbar, Container ohne Add-on-Basis, Wartungsseite und Rolle `service` |

## Offene Punkte

- Alle Zeiten (Antwortzeiten von unterwegs, Startdauer) am ersten Gerät messen.
- Ob `cage` den Wechsel auf die Textkonsole ohne Schalter wirklich sperrt, am Gerät prüfen.
- Tailscale oder Cloudflare für die Fernwartung: Kosten und Bedingungen für mehrere Kundengeräte vergleichen.
- Vertragstext zur Fernwartung (Auftragsverarbeitung) mit einer Fachperson klären.
- Freigabe des Umbaus durch den Hausherrn (Q12).
