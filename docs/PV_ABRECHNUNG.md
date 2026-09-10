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

### Die Rangfolge: der Speicher bekommt die PV zuerst

Gab es in einer Minute mindestens so viel Erzeugung wie Ladeleistung, gilt die Ladung vollständig
als Sonnenstrom. Auch dann, wenn der Zähler in derselben Minute Bezug meldet, weil das Haus mehr
wollte, als übrig war. Dieser Bezug gehört dann zum **Haus**.

Ein Beispiel um acht Uhr morgens:

| | |
|---|---|
| PV | 3,0 kW |
| Hausverbrauch (die Wärmepumpe macht Warmwasser) | 2,0 kW |
| Speicher lädt | 2,0 kW |
| Zähler | 1,0 kW Bezug |

Zusammen wollten Haus und Speicher 4 kW, die Sonne lieferte 3. Ein Kilowatt kam aus dem Netz. Die
Frage ist nicht, ob es floss, sondern wem man es zuschreibt.

**Warum dem Haus.** Die umgekehrte Rangfolge - Haus zuerst, Speicher aus dem Rest - war hier zuerst
eingebaut und ist ebenso vertretbar; die Physik kennt keine Etiketten auf Elektronen. Gegen sie
spricht, was sie anrichtet: sie schreibt dem Speicher Netzladung zu, obwohl er nur genommen hat, was
die Sonne hergab. Wer dann „Netzladung" liest, sucht den Fehler beim Speicher. Er liegt aber beim
Verbrauch, der zur falschen Zeit lief, und genau dorthin gehört er in der Bilanz. Dass die Regelung
des Speichers das Haus ans Netz zwingt, bleibt ein Problem - es ist nur nicht dasselbe Problem wie
„der Speicher lädt aus dem Netz".

**Der Preis.** Der direkte PV-Anteil am Hausverbrauch fällt kleiner aus, der Netzanteil größer, und
damit sinkt die ausgewiesene Autarkie. Die PV-Menge verschiebt sich dabei nur: was nicht direkt ins
Haus geht, liegt im Speicher und kommt später heraus. Für die steuerliche Bewertung heißt das, dass
ein Teil des Eigenverbrauchs nicht mehr zum Mittagspreis, sondern zum Abendpreis der Entladung
bewertet wird.

**Was stehen bleibt.** Deckt die Erzeugung die Ladeleistung nicht, bleibt die Differenz Netzladung:
`Netz → Speicher = max(0, Ladeleistung − Erzeugung)`. Nachts ist die Erzeugung null, also ist dort
jede Ladung Netzladung, und die Kachel „Netzladung ohne PV" zeigt genau diesen Teil.

### Warum die Ladung gegen ein kurzes Fenster geprüft wird

Die Rangfolge vergleicht zwei Größen aus **zwei verschiedenen Geräten**: die Erzeugung von den
Generation-CTs, die Ladung vom Libbi. `apps/api/src/dch_api/integrations/myenergi/mapping.py` gibt
jedem seinen eigenen Zeitstempel. An einer Wolkenkante hinkt der eine dem anderen um eine Minute
nach, und in dieser Minute sieht es aus, als habe der Speicher ohne Sonne geladen.

`with_charge_window` legt deshalb je Minute ein zentriertes Fenster von ±2 Minuten und bildet darin
den **Anteil**, den die dortige Erzeugung an der dort geladenen Energie hat; dieser Anteil wird auf
die Minute angewandt. Der Anteil, nicht die geglättete Erzeugung selbst: eine Minutenladung gegen
ein Fenstermittel zu halten vergleicht Ungleiches und verschiebt den Fehler nur, statt ihn
aufzuheben.

Zwei Minuten sind kurz genug, dass eine echte Netzladung nicht darin verschwindet, und lang genug
für den Zeitversatz zwischen zwei Geräten.

### Die Auflösung der Eingangsdaten

Stunden, die der Historienimport aus **Stundenmitteln** gebildet hat, tragen richtige Summen. Mit
der früheren Rangfolge war ihre Zuordnung zusätzlich verzerrt, weil sich im Mittel einer Stunde der
PV-Überschuss der Sonnenminuten und der Netzbezug der Wolkenminuten gegenseitig auslöschten und die
Differenz als Netzladung im Speicher landete; über einen Wintermonat wurden daraus dreistellige
Kilowattstunden, die nie geflossen sind.

Seit die Ladung die PV zuerst bekommt, entfällt dieser Unterschied: die Zuordnung hängt nur noch an
Erzeugung und Ladeleistung, und beide überstehen die Mittelung. `coarse_minutes` zählt die
betroffenen Minuten trotzdem weiter und wird auf den Auswertungsseiten genannt - nicht mehr, weil
dort anders gerechnet würde, sondern weil eine Jahresansicht nicht verschweigen soll, dass ein Teil
ihrer Zahlen aus gröberen Daten stammt.

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
