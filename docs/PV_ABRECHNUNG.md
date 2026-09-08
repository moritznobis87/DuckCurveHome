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

### Warum die Ladung gegen ein Fenster geprüft wird

In einer Minute, in der der Speicher lädt, ist die Zuordnung rechnerisch zwingend:

```
Netz → Speicher = min(Ladeleistung, Netzbezug)
```

Die PV-Leistung kommt darin gar nicht vor, weil der Hausverbrauch selbst aus der Bilanz stammt
(`house = pv + grid + battery`). Damit hängt alles daran, dass Netzzähler und Speicher **im selben
Moment** gemessen haben. Sie tun es nicht: `apps/api/src/dch_api/integrations/myenergi/mapping.py`
vergibt der Erzeugung `gen_at`, dem Netzbezug `grid_at` und dem Speicher die Zeit des Libbi, drei
Geräte mit drei Zeitstempeln. An einer Wolkenkante meldet der Zähler bereits den Bezug der
Wolkenminute, während der Libbi noch die Ladung der Sonnenminute meldet, und die Bilanz macht daraus
Netzladung.

Am 03.09.2026 waren das 3,2 kWh zwischen 14 und 16 Uhr, zur besten PV-Zeit; von der Tagessumme
fielen nur 0,6 kWh in die Dunkelheit, wo Netzladung echt gewesen wäre.

`with_charge_window` legt deshalb je Minute ein zentriertes Fenster von ±2 Minuten und bildet darin
den **Anteil**, den der PV-Überschuss an der geladenen Energie hat; dieser Anteil wird auf die
Minute angewandt. Der Anteil, nicht der geglättete Überschuss selbst: eine Minutenladung gegen ein
Fenstermittel zu halten vergleicht Ungleiches und verschiebt den Fehler nur. Der Überschuss ergibt
sich dabei ohne PV-Wert aus `max(0, -grid - battery)`.

Nachts ist der Überschuss null, der Anteil null, und echte Netzladung bleibt dem Netz zugeschrieben.
Auch eine Netzladung am Tag, bei der die PV die Ladeleistung nicht deckt, bleibt stehen. Verschoben
wird nur die Herkunft: der gemessene Netzbezug der Minute bleibt unverändert und zählt dann als
Bezug des Hauses, was an einer Wolkenkante auch das ist, was geschehen ist.

### Warum die Auflösung der Eingangsdaten die Zuordnung entscheidet

Bei Minutenwerten gilt in jeder Minute eine physikalische Bilanz, und die Rangfolge „PV deckt erst
das Haus, der Rest lädt den Speicher" ist richtig: mehr als den Überschuss dieser Minute kann der
Speicher nicht bekommen. Liegt der Zeitraum dagegen nur als Stundenmittel vor - so kamen die Monate
aus dem Home-Assistant-Import in die Datenbank -, ist dieselbe Rangfolge falsch und erfindet
Netzladung. Nachgerechnet an einer Stunde mit 20 min Sonne (der Speicher lädt aus dem Überschuss)
und 40 min Wolke (das Haus hängt am Netz):

| | je Minute | aus dem Stundenmittel |
|---|---|---|
| PV | 1,467 kWh | 1,467 kWh |
| Hausverbrauch | 1,000 kWh | 1,000 kWh |
| Speicherladung | 0,667 kWh | 0,667 kWh |
| **davon aus dem Netz** | **0,000 kWh** | **0,200 kWh** |

Die Summen überstehen die Mittelung, die Zuordnung nicht: im Mittel löschen sich der PV-Überschuss
der Sonnenminuten und der Netzbezug der Wolkenminuten gegenseitig aus, und die Differenz landet als
Netzladung im Speicher. Über einen Wintermonat summiert sich das zu dreistelligen Kilowattstunden,
die nie geflossen sind.

Ab `COARSE_RESOLUTION_MIN` (5 min) gilt deshalb die umgekehrte Rangfolge: PV lädt zuerst den
Speicher, Netzladung wird nur ausgewiesen, wenn die Ladung die gesamte PV-Erzeugung der Stunde
übersteigt - dann hat sie wirklich stattgefunden, etwa nachts. Auch das ist nicht gemessen, aber es
irrt in die harmlosere Richtung; der Preis ist ein etwas zu hoher direkter PV-Anteil am
Hausverbrauch. Wie viele Minuten so gerechnet wurden, steht in `coarse_minutes` und wird auf den
Auswertungsseiten genannt, damit eine Jahresansicht nicht zwei Rechnungsarten mischt, ohne dass man
es ihr ansieht.

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
