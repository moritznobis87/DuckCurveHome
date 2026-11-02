# Marktübersicht: Wer macht schon, was Duck Curve Home vorhat?

Stand: 01.11.2026. Anlass ist die Überlegung, aus Duck Curve Home ein Produkt zu machen: Regelkern
lokal auf einem Raspberry Pi oder ähnlichem Gerät, ohne Home Assistant, Einzelraumregelung der
Fußbodenheizung eingeschlossen, Hardware von Dritten offen als solche ausgewiesen, Vertrieb mit
Heizungsbauern. Die Frage war, ob das Feld schon besetzt ist.

Belegt ist, was eine Quelle `[n]` trägt. Was nur aus Vorwissen stammt, steht als **ungeprüft** da.
Herstellerangaben zu Ersparnissen sind Werbeaussagen und hier bewusst weggelassen.

## Kurzfassung

Das Feld ist belebt, aber fast alle optimieren den **Strom** (PV, Speicher, Wallbox, Tarif) und
behandeln die Wärmepumpe als Schalter, meist über SG Ready. Vom **Raum und vom Gebäude als
Wärmespeicher** her denkt kaum jemand. Dort liegt die Nische für Duck Curve Home. Am nächsten
kommen ihr tado (Heizungsseite, Endkundenmarke) und Loxone (Breite, Installateurskanal).

## 1. Komplettanbieter mit eigenem Energiemanager

Verkaufen Anlage, Montage und Tarif aus einer Hand und haben eigene Monteure. Konkurrenz um den
Endkunden, nicht um Heizungsbauer.

| Anbieter | Was | Quelle |
| --- | --- | --- |
| 1KOMMA5° (Heartbeat) | steuert Speicher, Wärmepumpe und Wallbox nach dem Börsenstrompreis, eigener Tarif (Dynamic Pulse) | [3], [4] |
| Enpal | eigener Tarif (Enpal.One+) | [5] |
| Octopus Energy (Heat Pilot) | steuert die Wärmepumpe nach Strompreisen | [6] |
| Thermondo | Tarif laut einer Vergleichstabelle über einen Partner; eigener Energiemanager nicht gefunden | [5] |

## 2. White-Label-Plattformen für Installateure

Der Kanal, den ein Produkt mit Heizungsbauern bräuchte. Er wird gerade besetzt.

- **gridX:** Plattform mit lokalem Gateway und Cloud, vertrieben über Partner wie Viessmann, nicht
  direkt an Endkunden [8]. Das Installateursnetz PV Green installiert sie unter dem Namen „ELIO“ und
  will bis Ende 2026 rund 600 Anlagen erreichen [7]. E.ON übernahm im September 2021 die Mehrheit
  [15] und kaufte gridX danach vollständig [16]; den Zeitpunkt nennen die Quellen unterschiedlich
  (Ende 2022 oder Anfang 2023). Ein Beispiel für den Weg „Plattform für andere, dann übernommen“.
- **Kiwigrid:** Dresden, eigenständig ohne Mutterkonzern [17]; auf seiner Plattform läuft unter
  anderem der Energiemanager von Solarwatt [17]. Vertrieb direkt an Installateure, über den Großhandel und als White Label; über 200 getestete
  Geräteanbindungen, davon 79 Wärmepumpen [9]. Seit Januar 2026 erweiterte Wärmepumpensteuerung
  über SG Ready und EEBus [2].
- **E.ON:** Partnerprogramm seit Februar 2026, bis zu 120 € Prämie je installiertem
  Energiemanager, drei Partnerstufen [1].

## 3. Von der Heizung her gedacht

- **tado X:** Raumthermostate auch für Fußbodenheizung, „Wärmepumpen-Optimierer X“ mit Einfluss
  auf die Heizkurve [10], [11], dazu ein eigener dynamischer Tarif [12].
- **Loxone:** Einzelraumregelung mit eigenen Stellantrieben, Wärmepumpe und PV in einem System,
  vertrieben über Partner-Installateure [13]. Eine komplette Smart-Home-Installation, die der
  Installateur konfiguriert, kein Optimierer.
- **Heizungshersteller** (Uponor, Rehau, Danfoss, Möhlenhoff u. a.) haben eigene
  Raumregelungen, meist ohne Strombezug: **ungeprüft**.

## 4. Für Bastler

Home Assistant und evcc, beide kostenlos. Wer viel selbst macht, zahlt nicht.

## Die Lücke

Die großen Energiemanager sprechen die Wärmepumpe über SG Ready an, einzelne seit 2026 auch über
EEBus [2]. Vom Raum wissen sie nichts. Duck Curve Home kennt die Zeitkonstanten der Räume
(`packages/hems-core/src/hems_core/thermal/room_shift.py`), den Ladezustand des Puffers, die
Sollwerte je Raum (über Controme, `docs/SENSORIK.md`), plant mit MILP und rechnet gegen einen
gewöhnlichen Thermostat (`packages/hems-core/src/hems_core/accounting/counterfactual.py`). Das
Haus als Wärmespeicher, Raum für Raum, zusammen mit PV, Batterie und Preis, hat diese Recherche
bei keinem der Genannten in dieser Tiefe gefunden. Ausschließen lässt es sich damit nicht.

## Zwei Warnungen für den Kanal Heizungsbau

1. **Viele Heizungsbauer halten Einzelraumregelung bei Wärmepumpen für unnötig oder schädlich.**
   Sie raten zu sauberem Abgleich mit offenen Kreisen; zu viele geschlossene Kreise können die
   Wärmepumpe unter ihren Mindestdurchfluss drücken [14]. Laut Loxone verlangt das GEG eine
   Einzelraumregelung [13]; am Gesetzestext **ungeprüft**. Folgerung: Das Argument für
   Heizungsbauer ist „automatischer Abgleich, effizientere Wärmepumpe, mit Nachweis“, nicht
   „Einzelraumregelung“. Den Nachweis kann die Gegenrechnung liefern.
2. **Installateure fassen nur an, was die Garantie nicht gefährdet.** Die Wärmepumpe muss über
   offizielle Schnittstellen angesprochen werden (SG Ready, EEBus, Hersteller-Modbus), die Montage
   muss schnell gehen, und die Plattformen zahlen Prämien [1]. Das macht den Kanal teuer.

## Folgerung

Als „noch ein Energiemanager“ gegen 1KOMMA5°, Enpal oder gridX anzutreten, ist aussichtslos. Als
„die Heizungsseite, die alle anderen weglassen“ gibt es eine Nische, solange tado, Loxone und die
Heizungshersteller nicht nachziehen. Zu prüfen wäre, ob sich der Wärmekern an eine der
White-Label-Plattformen anbinden lässt, statt gegen sie anzutreten.

## Grenzen und offene Punkte

- Eine Suchrunde mit Websuche, keine Gespräche mit Heizungsbauern oder Anbietern.
- Preise der B2B-Plattformen sind nicht öffentlich [9].
- Nicht recherchiert: Viessmann ViCare mit Gridbox, Bosch, Vaillant, Stiebel Eltron, evcc im Detail,
  die Raumregelungen der Heizungshersteller.
- Rechtliches (Händler- oder Herstellerrolle, Cyber Resilience Act, GEG) ist nicht geprüft.

## Quellen

1. pv magazine, 24.02.2026: [Eon startet HEMS-Partnerprogramm für Installateure](https://www.pv-magazine.de/2026/02/24/eon-startet-hems-partnerprogramm-fuer-installateure/)
2. enyo: [HEMS-Vergleich 2026: 12 Systeme im Überblick](https://enyo-energy.de/magazin/hems-vergleich)
3. 1KOMMA5°: [Heartbeat](https://1komma5.com/de/heartbeat/)
4. 42watt: [1KOMMA5° Erfahrungen 2026](https://42watt.de/magazin/1komma5-erfahrungen)
5. dezentralo: [Dynamischer Stromtarif: Welche Alternativen gibt es zu 1komma5 und Enpal?](https://dezentralo.com/blog/dynamische-stromtarife-welche-alternativen-anbieter-gibt-es)
6. energiefluss24: [Octopus Energy Wärmepumpe: Erfahrungen & Kosten 2026](https://www.energiefluss24.de/waermepumpe/octopus-energy-erfahrungen)
7. gridX: [PV Green’s installer network installs gridX’s white-label HEMS in Germany](https://www.gridx.ai/press-releases/pv-greens-installer-network-installs-gridxs-white-label-hems-in-germany)
8. enter.de: [Home Energy Management System (HEMS) im Vergleich 2026](https://www.enter.de/blog/home-energy-management-system-vergleich)
9. pv magazine: [Kiwigrid: Heimenergiemanagement mit über 200 getesteten Konnektivitäten](https://www.pv-magazine.de/produkte/kiwigrid-heimenergiemanagement-mit-ueber-200-getesteten-konnektivitaeten/)
10. appgefahren: [Tado Wärmepumpen-Optimierer X](https://www.appgefahren.de/?p=358012)
11. Notebookcheck: [Heizoptimierungs-Funktion von tado für Wärmepumpen](https://notebookcheck.com/Mit-neuer-Heizoptimierungs-Funktion-von-tado-sollen-Waermepumpen-effizienter-arbeiten-und-mehr-Energie-einsparen.953588.0.html)
12. ZfK: [tado vertreibt stundengenauen dynamischen Tarif](https://www.zfk.de/unternehmen/nachrichten/tado-vertreibt-stundengenauen-dynamsichen-tarif)
13. Loxone: [Einzelraumregelung für Fußbodenheizung mit dem Loxone Stellantrieb](https://www.loxone.com/dede/blog/einzelraumregelung-fussbodenheizung-stellantrieb/)
14. energiesparhaus.at: [Forum Heizung, Lüftung, Klima](https://www.energiesparhaus.at/forum/58625)
15. gridX: [E.ON acquires majority stake in leading smart grid company gridX](https://www.gridx.ai/press-releases/e-on-acquires-majority-stake-in-leading-smart-grid-company-gridx)
16. Handelsblatt: [Eon übernimmt Start-up GridX komplett](https://www.handelsblatt.com/unternehmen/energie/energiebranche-eon-uebernimmt-start-up-gridx-komplett/28862594.html)
17. dezentralo: [Welches HEMS ist das beste? Vergleich 2026 mit 79 Systemen](https://dezentralo.com/blog/home-energy-management-systeme-im-vergleich)
