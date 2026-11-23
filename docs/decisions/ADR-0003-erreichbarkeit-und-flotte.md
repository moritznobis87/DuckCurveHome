# ADR-0003 - Erreichbarkeit: Beitritt, Verzeichnis, Relais und Flotte

**Status:** angenommen für das Produkt, Umsetzung offen · **Datum:** 2026-11-20

## Kontext

Zwei Festlegungen des Hausherrn machen aus einer Nebenfrage die Architekturfrage:

- **Duck Curve Home soll ein eigenes Ökosystem werden** (13.11.2026, Q12 in
  [`docs/OPEN_QUESTIONS.md`](../OPEN_QUESTIONS.md)).
- **Im Kundenrollout gibt es kein Home Assistant** (20.11.2026). Die Box im Haus ist autark. Der
  Kunde muss **im Heimnetz lokal** und **von außen** auf sein System zugreifen können, und zwar
  ohne DynDNS, ohne Portfreigabe, ohne Zertifikate und ohne irgendein Token abzutippen. Benutzer
  sollen zentral verwaltbar sein, damit ein **Beratungszugang** möglich ist.

Heute ist genau das der Schmerz: wer die Bridge in Betrieb nimmt, füllt in
`addons/duckcurve_bridge/config.yaml` zwei Felder aus -

```yaml
api_ws_url: ""
api_token: ""
```

- und das ist für einen Endkunden zu viel. Dasselbe gilt für die iOS-App, die Adresse, Präfix und
Token verlangt (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Zugang.swift`).

**Der Mechanismus existiert dagegen schon.** `apps/bridge/src/dch_bridge/uplink/client.py` hält eine
**ausgehende** WSS-Verbindung aus dem Haus: `hello`/`welcome`, Telemetrie mit Sequenzen und Acks,
Heartbeat, Reconnect mit Backoff, SQLite-Outbox - und `CommandFrame` → `CommandResultFrame` in die
andere Richtung. Das ist ein Rendezvous-Tunnel im Kleinen, mit Anfrage und Antwort. Heute fließen
Messwerte hoch und Schaltbefehle herunter; gebraucht wird dasselbe Rohr mit anderer Nutzlast.

Und was mit Home Assistant wegfällt, muss ersetzt werden: Updates mit Rückfall, Einrichtung im
Netzwerk, Sicherungen, Supervisor. **Ein großer Teil davon ist seit dem 19.11.2026 entschieden und in
Stufe 1 gebaut:** [`docs/HAUSGERAET.md`](../HAUSGERAET.md) beschreibt das Gerät selbst - Pi 5 mit
NVMe und RTC-Batterie, Dienste in Docker Compose, schreibgeschütztes System, Kioskmodus, Marke,
Wartungszugänge, ein Erststart-Dienst, der jedes Gerät erst beim Einschalten einzigartig macht (das
Abbild enthält kein Geheimnis), und ein Update aus der App mit Sicherung davor, Gesundheitsprüfung
danach und automatischer Rückkehr zur vorherigen Fassung (`deploy/haus/`).

Diese Entscheidung baut darauf auf und beantwortet die Frage, die dort offen bleibt: **wie ein Gerät zu
seinem Benutzer findet und umgekehrt**, sobald es nicht mehr das eigene Haus ist. Damit wird die
Zentrale vom Anmeldedienst zur **Flottenverwaltung**. An drei Stellen weicht sie von HAUSGERAET ab;
die stehen unten ausdrücklich als solche.

## Grundsatz

> **Schlüssel wandern nie. Es wandern nur Zertifikate und kurzlebige Nachweise.**

Jeder private Schlüssel entsteht dort, wo er benutzt wird, und verlässt diesen Ort nicht. Die Box
erzeugt ihn beim ersten Start, schickt eine Signieranfrage (CSR) nach oben und bekommt ein Zertifikat
zurück. Geht die Box kaputt, ist der Schlüssel verloren - und das ist richtig: die neue Box bekommt
einen neuen und wird neu gebunden. Wer anfängt, Schlüssel zu kopieren, zu sichern oder zu verteilen,
hat ein Geheimnis an N Stellen und kann nicht mehr sagen, wer gerade spricht.

Alles, was „automatisiert im Hintergrund" laufen muss, ist damit: CSR hoch, Zertifikat herunter,
rechtzeitig erneuern - über die Leitung, die ohnehin steht.

## Optionen

| | A - Portfreigabe / DynDNS | B - fremder Tunnel | **C - eigene Zentrale** | D - Daten in der Cloud (heute) |
|---|---|---|---|---|
| Was der Kunde tun muss | Router konfigurieren | nichts (Dienst auf der Box) | nichts (Code scannen) | Adresse und Token eintippen |
| Lokal im LAN | direkt | direkt | direkt | nur über das Internet |
| Zertifikat im LAN | selbst | je nach Anbieter | eigene Zone, DNS-01 | entfällt |
| Beitritt einer Box | Handarbeit | Anbieterkonto | **eigenes Verfahren** | Handarbeit |
| Beratungszugang | nicht vorgesehen | Anbieterrechte | **eigene Vollmacht** | Token weitergeben |
| Betreiber sieht Hausdaten | nein | möglich | **nein (SNI-Weiterleitung)** | ja |
| Aufwand | gering | gering | hoch | gebaut |
| Für ein Produkt | unzumutbar | abhängig von einem Dritten | **passend** | Datenhaltung beim Betreiber |

## Entscheidung

**Option C für das Produkt, Option B als Übergang,** solange es um einzelne Häuser geht: ein
benannter Tunnel je Box (`cloudflared`) kostet nichts und keinen eigenen Code - Preis ist ein Dritter
im Pfad. Dazu diese Festlegungen:

**1 · Lokal zuerst, Relais nur wenn nötig.** Nicht aus Eleganz: der Live-Strom ist ein Dauerstrom.
Gemessen am 03.11.2026 sind es 4,5 kB je Meldung alle fünf Sekunden (`live_push_min_s`, zitiert in
[HAUSGERAET.md](../HAUSGERAET.md) Abschnitt 1), also rund 0,9 kB/s: **etwa 2,3 GB im Monat je
Dauerdisplay** - über das LAN kostenlos, über ein Relais Egress (bei ~0,10 $/GB gut 20 Cent je Haus und
Monat), und das für den einen Client, der das Relais nie braucht, weil die Wandanzeige immer im eigenen
Netz hängt. Die App probiert lokal und fällt erst dann auf das Relais zurück. Das ist die Bedingung
dafür, dass ein Relais bezahlbar bleibt, kein Feinschliff.

**2 · Die native App geht lokal direkt und prüft den Box-Schlüssel aus dem Beitritt** (Pinning). Kein
DNS, kein Zertifikat, keine Router-Einstellung - die Box hat seit dem Beitritt eine Identität, genau
dafür ist sie da. Der Browser im Heimnetz ist die **Zugabe**: er braucht einen echten Namen und ein
echtes Zertifikat, und das klappt bei vielen und bei manchen nicht (siehe offene Punkte,
DNS-Rebind-Schutz). Wo es nicht klappt, nimmt der Browser den Tunnel.

**3 · Das Relais reicht nach SNI weiter und terminiert nicht.** Dann liegt zwischen Kunde und Box
eine durchgehende Verschlüsselung, und die Zentrale **kann** die Hausdaten nicht lesen - nicht nur
„tut es nicht". Preis: die Zentrale kann keine einzelnen Anfragen prüfen. Das ist richtig so, denn die
Prüfung gehört in zwei Schichten: **die Zentrale erlaubt die Verbindung** (ist diese Person dieser Box
zugeordnet), **die Box erlaubt die Anfrage** (welche Rolle, welcher Endpunkt).

**4 · Berechtigungen kommen als signiertes Dokument, nicht als Abfrage.** Die Zentrale ist die
Wahrheit über Personen und Zuordnungen. Sie signiert ein kleines Dokument - *diese Personen, diese
Rollen, diese Zugangsschlüssel-Kennungen, Version N, gültig bis T* - und schiebt es über die Leitung
auf die Box. Die Box prüft es gegen den öffentlichen Schlüssel der Zentrale, den sie beim Beitritt
bekommen hat, und legt es ab. Damit braucht sie für **keine** Anmeldung das Internet. Eine Änderung
ist in Sekunden unten, wenn die Leitung steht; steht sie nicht, gilt der letzte Stand bis `T`. Ein
Monat ist ein guter Wert: lang genug für jeden Ausfall, kurz genug, dass eine gestohlene Box nicht
dauerhaft widerrufene Personen hereinlässt.

**5 · Die Box antwortet im Heimnetz unter einer eigenen registrierbaren Domain,** nicht unter einer
Subdomain der Konto-Domain. Sonst könnte eine kompromittierte Firmware Passkeys für das Konto
abfragen. Der Preis ist ein zweiter, hausgebundener Passkey je Person; die Box legt ihn still an,
sobald die Person mit gültiger Sitzung im eigenen Netz ist (vgl. [ADR-0002](ADR-0002-identitaet-und-berechtigung.md)).

**6 · Drei Zertifikatsstrecken, drei verschiedene Antworten:**

| Strecke | Lösung | Erneuerung |
|---|---|---|
| Box ↔ Zentrale | eigene CA, mTLS, Gerätezertifikat aus dem Beitritt, 30-90 Tage | automatisch bei 2/3 Laufzeit, über die bestehende Leitung |
| Client ↔ Box **im LAN** | öffentlich vertrauenswürdiges Zertifikat auf `<box>.lokal.<domain>`, Schlüssel auf der Box, DNS-01 durch die Zentrale | wie oben, unsichtbar |
| Client ↔ Box **von außen** | durchgereichter Tunnel, Zertifikat der Box; die Zentrale terminiert nicht | entfällt |

Dazu hält die Zentrale eine DNS-Zone und setzt je Box einen A-Record auf die **LAN-Adresse** (TTL
60 s); die Box meldet ihre aktuelle lokale Adresse über die Leitung. Das ist das Muster von Plex
(`*.plex.direct`) und Tailscale (`*.ts.net`) und der einzige Weg zu einem grünen Schloss im Heimnetz
ohne Zutun des Kunden.

**7 · Die Zentrale steht nie im Regelkreis, nur im Sichtkreis.** Die Box regelt autonom weiter, wenn
die Zentrale fehlt. Was dann noch gilt, steht als Prüfliste in [`docs/ZENTRALE.md`](../ZENTRALE.md)
und ist der Maßstab für jede künftige Änderung. ADR-1 (Regler-Kern ohne I/O, „später auf Edge
verschiebbar") ist die Vorarbeit dafür und wird damit eingelöst.

## Was sich gegenüber HAUSGERAET.md ändert

Drei Punkte, und alle drei sind für ein Haus richtig entschieden und für den Rollout nicht:

**`home.local` kann kein öffentlich vertrauenswürdiges Zertifikat bekommen.** Abschnitt 3 dort sieht
Caddy mit `https://home.local` vor. `.local` gehört dem mDNS, keine öffentliche CA stellt darauf aus;
Caddy nimmt dann sein eigenes - und dessen Wurzel müsste auf jedem Telefon, Tablet und Rechner des
Kunden installiert werden. Genau das soll niemand tun müssen. Darum Punkt 6 oben: ein Name je Box unter
einer eigenen Domain, Zertifikat über DNS-01. Der Kioskbrowser auf dem Gerät ist davon nicht betroffen,
er öffnet `http://localhost:3000`, und `localhost` gilt dem Browser als sicherer Kontext - Passkeys
funktionieren dort also auch ohne Zertifikat.

**Cloudflare Access als Anmeldung endet mit dem eigenen Haus.** Für ein Gerät ist der gebaute Weg
(`cloudflared` plus Access davor) der kürzeste, den es gibt. Für Kundengeräte nicht: die Identität läge
dann bei Cloudflare, und weder der Beitritt einer Box noch eine befristete Vollmacht für den
Beratungszugang lassen sich dort abbilden. Im Rollout steht deshalb die eigene Anmeldung
([ADR-0002](ADR-0002-identitaet-und-berechtigung.md)) vor dem Tunnel, und der Tunnel reicht nur durch.

**Updates bleiben, wie sie gebaut sind.** Abschnitt 4 dort entscheidet: Anwendung über Images aus der
Registry, Sicherung davor, Gesundheitsprüfung danach, automatische Rückkehr, und „ein Gerät wird für
ein Update nie neu bespielt". Das ist gebaut und nicht zu ersetzen. A/B-Partitionen mit einem
Abbildwerkzeug (RAUC, Mender, SWUpdate) wären erst dann ein Thema, wenn auch das **Betriebssystem** als
Abbild aktualisiert werden soll - für Kundengeräte offen, heute nicht nötig, weil das System
schreibgeschützt ist und Sicherheitsupdates einzeln kommen.

**Und eine Umbenennung:** die Rolle für den Support heißt `service`, wie in Abschnitt 7 dort eingeführt,
nicht `berater`. Eine Rolle, ein Name.

## Konsequenzen

**Die Zentrale besteht aus sechs kleinen, datenarmen Diensten** - Geräteverzeichnis und Beitritt, CA
und Zertifikatsdienst, DNS, Rendezvous und Relais, Benutzerverwaltung mit signiertem Dokument,
Vollmachten für den Beratungszugang. Einzeln beschrieben in [`docs/ZENTRALE.md`](../ZENTRALE.md),
samt der Liste dessen, was sie **nie** halten darf (keine Messwerte, keine Historie, keine privaten
Schlüssel, keine Zugangsdaten des Kunden zu Tibber oder myenergi).

**Ohne Home Assistant kommt dazu, was der Supervisor bisher erledigt hat:**

- **Ein Kanal je Flotte.** Gebaut ist der Update-Weg samt Rückkehr; offen bleibt laut HAUSGERAET
  Abschnitt 4 der **Release-Tag als Kanal** statt `main` und ein Wartungsfenster. Das gehört der
  Zentrale: sie sagt einem Gerät, welchem Kanal es folgt, und rollt gestaffelt aus. Ohne das bedeutet
  ein schlechtes Update eine Fahrt zu jedem Haus.
- **Sicherungen außer Haus verschlüsselt.** Der nächtliche `pg_dump` mit einer Kopie außer Haus ist
  gebaut; für Kundengeräte muss der Schlüssel dafür **auf der Box** abgeleitet werden, damit der
  Betreiber Chiffrat lagert, das er nicht lesen kann. Heute ist das eine Entscheidung über den eigenen
  Bestand, später über fremden.
- **Gesundheitsmeldungen aus der Ferne.** `HeartbeatFrame` und `DeviceHealthFrame` gibt es, und die
  Seite *System → Hausgerät* zeigt sie dem Hausherrn. Was fehlt, ist der Weg zum Betreiber: ein
  Ausfall soll auffallen, bevor der Kunde anruft.
- **Die Echtzeituhr ist entschieden** (RTC-Batterie, HAUSGERAET Abschnitt 2) und bekommt hier ihren
  zweiten Grund: ohne richtige Zeit schlägt jede Zertifikatsprüfung fehl.
- **Fernwartung ist kein Benutzerzugang.** Die vier Wege stehen in HAUSGERAET Abschnitt 7; sie hängen
  an Schlüsseln je Gerät und an signierten Freischaltdateien, nicht an einem Benutzerkonto. Diese
  Entscheidung ergänzt sie nur um eines: die Zentrale ist die Stelle, die einen Schlüssel je Gerät
  sperren kann.

**Für dieses Repository heißt das noch nichts.** Q12 gilt: der Umbau ist vorgemerkt und ausdrücklich
noch nicht gewünscht. Die Reihenfolge, wenn es losgeht: zuerst ADR-0002 (das lokale Benutzersystem,
nötig in jedem Zielbild, auch offline), dann Beitritt und Verzeichnis, zuletzt das Relais - weil es
laufende Kosten macht und weil die Leitung schon existiert, nur andersherum benutzt.

## Offene Punkte

- **Sicherheitsbaustein für den Geräteschlüssel - ja oder nein?** Mit ihm (TPM 2.0, ATECC608, SE050)
  ist die Geräteidentität nicht kopierbar und der ganze Entwurf ruht auf Fels; ohne ihn liegt der
  Schlüssel in einer Datei, und wer die Box aufschraubt, kann sie klonen. Nachrüsten geht nicht. Als
  **Q14** in [`docs/OPEN_QUESTIONS.md`](../OPEN_QUESTIONS.md) vermerkt. Das Hausgerät ist ein Pi 5
  (HAUSGERAET Abschnitt 2) und hat keinen; Abschnitt 5 dort nimmt dasselbe für die Verschlüsselung der
  SSD bereits in Kauf, mit derselben Begründung - im Haus des Kunden vertretbar.
- **DNS-Rebind-Schutz.** Die Fritz!Box verwirft DNS-Antworten mit privaten Adressen, und das betrifft
  einen großen Teil deutscher Haushalte; der Kunde müsste von Hand eine Ausnahme eintragen - genau
  das, was vermieden werden soll. Deshalb ist die native App mit Pinning der verlässliche lokale Weg
  und der Browser im LAN die Zugabe. Ungemessen, wie viele Router betroffen sind.
- **Mengengrenzen der öffentlichen CA.** Let's Encrypt begrenzt Zertifikate je registrierter Domain
  (Größenordnung 50 je Woche, Erneuerungen ausgenommen; Stand vor dem Rollout am aktuellen
  Regelwerk prüfen). Reicht für Jahre, nicht für einen Rollout - Erhöhung beantragen oder mehrere
  Domains vorsehen.
- **Eine eigene CA ist eine Verpflichtung.** Der Wurzelschlüssel muss aufbewahrt, geschützt und
  irgendwann gewechselt werden. Für die Strecke Box ↔ Zentrale ist das vertretbar, weil beide Enden
  unsere sind; für alles, was ein Browser sieht, nie.
- **Einrichtung im WLAN ohne Bildschirm.** „In die Steckdose stecken" verlangt auch ein Netz. Die
  Wartungsseite soll das können (HAUSGERAET Abschnitt 7, Punkt 2, dort offen) - nur erreicht man sie
  ohne Netz nicht. Also entweder Ethernet voraussetzen oder Bluetooth- oder Captive-AP-Einrichtung
  bauen; letzteres ist mehr Arbeit, als es klingt. Noch nicht entschieden.
- **Tailscale oder eigenes Relais?** HAUSGERAET Abschnitt 7 hat dieselbe Frage für die Fernwartung
  offen („Kosten und Bedingungen für mehrere Kundengeräte vergleichen"). Es ist dieselbe Entscheidung
  und sollte einmal getroffen werden, nicht zweimal: ein fremder Tunnel bedient Fernwartung und
  Kundenzugang, ein eigenes Relais ebenso.
- **Das Relais ist zustandsbehaftet.** Welcher Arbeiter hält welche Box? Klebende Weiterleitung oder
  eine gemeinsame Tabelle - noch nicht entworfen.
