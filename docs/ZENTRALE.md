# Die Zentrale: was sie leistet, was sie nie hält, und was ohne sie gilt

Sobald es mehr als ein Haus gibt, braucht Duck Curve Home einen Dienst außerhalb der Häuser. Nicht,
damit sich jemand anmelden kann - das geht lokal -, sondern damit ein Kunde **eine Box in die
Steckdose stecken** und sie ohne IT-Wissen erreichen kann, von innen und von außen. Die Entscheidungen
dahinter stehen in [ADR-0002](decisions/ADR-0002-identitaet-und-berechtigung.md) (wer jemand ist und
was er darf) und [ADR-0003](decisions/ADR-0003-erreichbarkeit-und-flotte.md) (wie man ihn erreicht).
Diese Seite beschreibt das **Zielbild** und den Vertrag, an dem es zu messen ist.

**Stand 20.11.2026: von der Zentrale ist nichts gebaut, vom Gerät darunter schon Stufe 1.** Das
Hausgerät selbst - Rechner, Dienste, Kiosk, Marke, Sicherung, Update mit Rückkehr, Zugang von unterwegs
über `cloudflared` - steht in [HAUSGERAET.md](HAUSGERAET.md) und in `deploy/haus/`. Was dort für **ein**
Haus entschieden ist, genügt für ein Haus; diese Seite beschreibt, was dazukommt, sobald ein Gerät zu
einem Kunden geht. Der Umbau ist vorgemerkt, nicht freigegeben (Q12 in
[OPEN_QUESTIONS.md](OPEN_QUESTIONS.md)).

## Kurz gesagt

- **Die Box hält alle Daten und regelt autonom.** Die Zentrale steht im Sichtkreis, nie im
  Regelkreis.
- **Die Box ruft hinaus, niemand ruft herein.** Keine Portfreigabe, kein DynDNS, kein UPnP. Den
  Mechanismus gibt es schon: `apps/bridge/src/dch_bridge/uplink/client.py`.
- **Schlüssel wandern nie.** Jeder private Schlüssel entsteht dort, wo er benutzt wird. Es wandern
  nur Zertifikate und kurzlebige Nachweise.
- **Die Zentrale ist die Wahrheit über Personen, die Box über Hausdaten.** Berechtigungen kommen als
  signiertes Dokument herunter, nicht als Abfrage nach oben.
- **Ein Beratungszugang wird erteilt, ist befristet und ist sichtbar** - und kann nie die Haustür
  öffnen.

## Die sechs Dienste

**1 · Geräteverzeichnis und Beitritt.** Serie, öffentlicher Schlüssel, Modell, Firmware-Stand,
Zustand, und wem die Box gehört. Die Box weist sich mit **Signatur** aus, nicht mit einem Token: ein
Token in einer Konfigurationsdatei lässt sich abschreiben, ein Schlüssel in einem Sicherheitsbaustein
nicht.

Der Beitritt ist der einzige Moment, in dem ein Mensch etwas tut:

1. Die Box startet, erzeugt ein Schlüsselpaar und gibt den privaten Teil nie her.
2. Sie ruft hinaus: „Ich bin Gerät ⟨öffentlicher Schlüssel⟩, noch niemandem zugeordnet." Die Leitung
   steht, aber sie darf nichts.
3. Der Kunde meldet sich in der App mit Passkey an und scannt einen Code - Aufkleber am Gehäuse oder
   Anzeige in der lokalen Einrichtung.
4. Die Zentrale bindet Gerät an Person. Dieses eine Mal.

Danach: keine Adresse, kein Token, keine Zertifikatsarbeit. Das ersetzt die beiden Felder, die heute
abzutippen sind (`api_ws_url` und `api_token` in `addons/duckcurve_bridge/config.yaml`).

**2 · Eine kleine CA und ein Zertifikatsdienst.** Die Box schickt Signieranfragen (CSR) nach oben und
bekommt Zertifikate zurück, selbsttätig und rechtzeitig. Drei Strecken, drei Antworten - die Tabelle
steht in ADR-0003. Für die Strecke Box ↔ Zentrale eine eigene CA (beide Enden sind unsere), für alles,
was ein Browser sieht, eine öffentliche.

**3 · DNS.** Eine eigene Zone, je Box ein Name wie `<box>.lokal.<domain>` mit einem A-Record auf die
**LAN-Adresse** (TTL 60 s); die Box meldet ihre lokale Adresse über die Leitung. Nur so gibt es ein
grünes Schloss im Heimnetz, ohne dass der Kunde etwas einstellt. Vorbehalt: Router mit
DNS-Rebind-Schutz verwerfen solche Antworten - deshalb ist die native App mit Schlüssel-Pinning der
verlässliche lokale Weg und der Browser die Zugabe.

**4 · Rendezvous und Relais.** Die Zentrale weiß, welcher Arbeiter welche Box-Leitung hält, und
reicht durch - **nach SNI weiter, ohne zu terminieren**. Damit liegt zwischen Kunde und Box eine
durchgehende Verschlüsselung, und die Zentrale kann die Hausdaten nicht lesen. Geprüft wird in zwei
Schichten: die Zentrale erlaubt die **Verbindung**, die Box erlaubt die **Anfrage**.

Die App probiert immer zuerst lokal. Das ist nicht Höflichkeit, sondern Rechnung: der Live-Strom sind
gemessene 4,5 kB alle fünf Sekunden ([HAUSGERAET.md](HAUSGERAET.md), Abschnitt 1), also etwa 2,3 GB im
Monat je Dauerdisplay - über ein Relais Egress, über das LAN nichts.

**5 · Benutzerverwaltung als signiertes Dokument.** Die Zentrale kennt Personen, ihre Passkeys und
ihre Zuordnungen. Sie signiert ein kleines Dokument - *diese Personen, diese Rollen, diese
Zugangsschlüssel-Kennungen, Version N, gültig bis T* - und schiebt es auf die Box, die es gegen den
beim Beitritt erhaltenen öffentlichen Schlüssel prüft. Die Box braucht damit für keine Anmeldung das
Internet; eine Änderung ist in Sekunden unten, und bei getrennter Leitung gilt der letzte Stand bis
`T` (Vorschlag: ein Monat).

**6 · Vollmachten.** Befristete, erteilte, sichtbare Zugänge für Dritte - siehe unten.

## Beratungszugang

Dafür braucht es die zentrale Verwaltung überhaupt: sonst müsste der Kunde einem Fremden von Hand ein
Konto auf seiner Box anlegen. Die Rolle und ihre Regeln sind in [HAUSGERAET.md](HAUSGERAET.md)
Abschnitt 7 schon angelegt - dort als `service` für den Techniker vor Ort, mit Zustimmung des Kunden,
Protokollierung und einem Vertrag zur Auftragsverarbeitung. Das hier ist dieselbe Rolle aus der Ferne,
und dieselben vier Regeln gelten:

- **Der Kunde erteilt ihn**, auf Knopfdruck in der App („Support für 2 Stunden erlauben"). Kein
  Dauerzugang, keine Voreinstellung, dass es an ist. HAUSGERAET nennt denselben Schalter für die
  Fernwartung.
- **Befristet und eng.** Rolle `service`: Diagnose und Einstellungen sehen, klar benannte
  Eingriffe. **Nicht** Rechnungen, nicht die PV-Abrechnung, nicht der Datenexport - und **niemals die
  Haustür** ([TUEROEFFNUNG.md](TUEROEFFNUNG.md)). Dass ein Supportmitarbeiter eine Haustür öffnen
  kann, darf technisch nicht möglich sein, nicht bloß nicht vorgesehen.
- **Sichtbar.** Die Box zeigt eine laufende Vollmacht im Betrieb an, und jede Zeile im Protokoll
  nennt `art: person` samt der Kennung der Vollmacht. Die Felder dafür gibt es
  ([URHEBER.md](URHEBER.md)).
- **Widerrufbar** in Sekunden, solange die Leitung steht, und sonst spätestens mit dem Ablauf.
- **Notfall** - Kunde ausgesperrt, Box stumm: eine Vollmacht ohne Zustimmung muss es geben, dann aber
  *nachträglich sichtbar*: Mitteilung an den Kunden, Eintrag im Protokoll, und wer es ernst nimmt,
  verlangt in der Zentrale vier Augen. Das ist eine Richtlinienentscheidung, keine technische - und
  noch nicht getroffen.

Davon streng getrennt: **Fernwartung** (Shell, Firmware, Betriebssystem) ist kein Benutzerzugang und
hängt nicht an einem Benutzerkonto, sondern an Schlüsseln je Gerät und signierten Freischaltdateien -
die vier Wege dafür stehen in [HAUSGERAET.md](HAUSGERAET.md) Abschnitt 7. Die Zentrale ergänzt sie nur
um eines: sie kann einen Geräteschlüssel einzeln sperren.

## Was die Zentrale nie hält

Damit der Vertrag unten hält, und damit die Antwort auf „was wisst ihr über mein Haus" kurz ist:

- keine Messwerte, keine Historie, keinen Fahrplan, keine Entscheidung des Reglers;
- keinen privaten Schlüssel - von keiner Box und von keinem Kunden;
- keine Zugangsdaten des Kunden zu Tibber, myenergi oder einem Zähler. Die gehören auf die Box,
  eingegeben in der lokalen Oberfläche oder über OAuth;
- keine Sicherung im Klartext. Was sie lagert, ist auf der Box verschlüsselt worden.

Was bleibt, ist ein Verzeichnis, eine CA und eine Vermittlung: klein, langweilig, selten geändert.
Genau das, was ein so kritisches Stück sein sollte.

## Der Ausfallvertrag

Die Prüfliste für jede künftige Änderung. Wer etwas baut, das eine Zeile in Spalte 2 von **läuft** auf
**aus** schiebt, hat den Entwurf verlassen.

| | Zentrale nicht erreichbar | Internet im Haus weg |
|---|---|---|
| Regelung: Wärmepumpe, Ofen, Puffer | **läuft** | **läuft** |
| Dashboard und App im Heimnetz, bestehende Sitzung | **läuft** | **läuft** |
| Anmeldung im Heimnetz, neu | **läuft**, solange das Berechtigungsdokument gilt | **läuft** |
| Protokoll, Historie, Export | **läuft** | **läuft** |
| Strompreise, Wetter, Prognose | **läuft** (Box holt selbst) | aus, Plan rechnet mit dem letzten Stand |
| Zugriff von außen | aus | aus (ein schreibgeschützter Spiegel der Zusammenfassungen wäre die Antwort darauf, [HAUSGERAET.md](HAUSGERAET.md) Abschnitt 1 - bewusst nicht in der ersten Stufe) |
| Neue Box in Betrieb nehmen | aus | aus |
| Beratungszugang erteilen oder widerrufen | aus | aus |
| Benutzer anlegen oder entfernen | aus (wirkt mit der nächsten Verbindung) | aus |
| Zertifikat erneuern | aus - deshalb Laufzeit 30-90 Tage und Erneuerung bei 2/3 | aus |
| Firmware-Update | aus | aus |

Zwei Zeilen verdienen eine Erklärung. **Zertifikate** sind der stille Zeitzünder: fällt die Zentrale
länger aus als die Restlaufzeit, verlieren Boxen ihre Verbindung - darum kurze Laufzeiten mit viel
Vorlauf und keine Panik bei einem Ausfall von Tagen. Und **die Uhr**: ohne richtige Zeit schlägt jede
Zertifikatsprüfung fehl, weshalb die Box eine Echtzeituhr mit Batterie braucht und keine Box ohne
Netz in einen Zustand kommen darf, aus dem sie nicht mehr herausfindet.
