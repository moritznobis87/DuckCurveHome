# PV-Abrechnung

Die Seite `/pv/abrechnung` beantwortet drei Fragen für Tag, Woche, Monat und Kalenderjahr:

1. Wie viel Einspeisevergütung ist angefallen - netto, Umsatzsteuer, brutto?
2. Wie viel Strom wurde selbst verbraucht und was hätte seine Beschaffung aus dem Netz gekostet?
3. Wie viel Umsatzsteuer ist für den Zeitraum abzuführen?

Sie ist nur mit Vollzugriff erreichbar; für Gäste ist auch der Endpunkt gesperrt. Die Zahlen bereiten
Beträge auf und ersetzen keine Steuerberatung.

## Einspeisung

`export_kwh` ist die ins Netz abgegebene Energie aus der Minutenbilanz (`grid_kw < 0`). Bewertet wird
sie mit `hems.tariff.feed_in_ct_kwh` - dem **Nettosatz** aus dem Bescheid des Netzbetreibers, derzeit
7,41 ct/kWh. Bei Regelbesteuerung zahlt der Netzbetreiber zusätzlich die Umsatzsteuer aus; sie ist ein
durchlaufender Posten und wird mit der Voranmeldung wieder abgeführt.

## Eigenverbrauch

Eigenverbrauch ist PV, die im Haus geblieben ist: direkt (`pv_direct_kwh`) plus der PV-Anteil der
Speicherentladung (`battery_pv_to_house_kwh`). Bemessungsgrundlage der unentgeltlichen Wertabgabe ist
nach § 10 Abs. 4 UStG der Einkaufspreis im Zeitpunkt des Umsatzes - für Strom also das, was der Bezug
derselben Menge aus dem Netz gekostet hätte. Bei einem Tarif mit stündlichem Preis ist das keine
Pauschale: jede Minute wird mit dem Preis ihrer Stunde bewertet, netto (Tibber-Bruttopreis ÷ 1,19).

## Der Speicher

Ein Speicher nimmt auch Netzstrom auf. Was aus dem Netz in den Speicher ging und später ins Haus
fließt, ist kein Eigenverbrauch eigener Erzeugung - es war beim Bezug bereits Netzstrom. Deshalb führt
`BatteryOrigin` (in `hems_core.accounting.energy`) ein Herkunftskonto über die Stunden hinweg:

* Beim Laden werden PV- und Netzanteil getrennt gutgeschrieben.
* Beim Entladen wird anteilig abgebucht; nur der PV-Anteil dessen, was ins Haus geht, zählt.
* Der Inhalt wird auf die Speicherkapazität begrenzt. Ladeverluste bedeuten, dass über die Zeit mehr
  hinein- als herausgeht; ohne Deckel wüchse das Konto unbegrenzt.
* Ist das Konto leer und wird trotzdem entladen - beim ersten Start, oder nach einer Lücke in den
  Messwerten -, gilt die Entnahme als PV. Der Umfang dieser Annahme steht in
  `battery_origin_estimated_kwh` und wird auf der Seite ausgewiesen.

Der Kontostand am Stundenende wird in `energy_hourly` mitgespeichert (`battery_pv_stored_kwh`,
`battery_grid_stored_kwh`), damit eine Neuberechnung dort fortsetzt, wo die vorige aufgehört hat,
statt wieder bei null zu beginnen. Er ist ein Bestand und wird nie über Stunden aufsummiert.

## Umsatzsteuer

| Posten | Grundlage | Richtung |
| --- | --- | --- |
| Einspeisung | Menge × Nettosatz | erhalten, abzuführen |
| Unentgeltliche Wertabgabe | Eigenverbrauch × Netto-Bezugspreis | geschuldet |

Die Zahllast der Seite ist die Summe beider. Steht `hems.tariff.small_business` auf `true` (§ 19
UStG), entfallen beide Posten.

## Rundung

Geldbeträge werden auf den Cent gerundet, und Summen werden aus den **gerundeten** Teilbeträgen
gebildet. Auf einer Seite, von der Zahlen in eine Voranmeldung übernommen werden, muss die angezeigte
Summe die angezeigten Posten ergeben. Die Zeilen der Aufstellung sind jede für sich gerundet, die
Gesamtsumme stammt aus den ungerundeten Stundenwerten; ihre Addition kann deshalb um wenige Cent
abweichen. Die Seite sagt das dazu.

## Grenzen

* Zeiträume vor dem Aufsetzen dieser Rechnung weisen keinen Eigenverbrauch aus: die Spalten wurden
  nachträglich ergänzt und stehen für alte Stunden auf 0. Neu gerechnet werden können nur Stunden,
  für die noch Minutenwerte vorliegen (14 Tage).
* Fehlt für eine Minute der Tibber-Preis, gilt `fallback_import_ct_kwh`; die Zahl der betroffenen
  Minuten steht in `price_missing_minutes`.
* Die Datenabdeckung des Zeitraums steht unter der Aufstellung. Ein Jahr mit 96 % Abdeckung ist kein
  Jahresabschluss.
