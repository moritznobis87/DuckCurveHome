# Tibber-Rechnungen prüfen

Erreichbar über **Haus → Netzbezug → Rechnungsprüfung** (`/haus/rechnungen`). Rechnungen lassen sich per
Drag-and-drop oder Dateiauswahl hochladen, auch mehrere auf einmal. Jede geprüfte Rechnung bleibt gespeichert
und ist später wieder aufrufbar; das PDF selbst wird **nicht** abgelegt, nur die gelesenen Werte, die Befunde
und eine Prüfsumme der Datei.

## Was geprüft wird

**Rechnerisch, allein aus der Rechnung.** Eine Abweichung über die Rundung hinaus ist hier ein echter Fehler.

| Prüfung | Erwartung |
|---|---|
| Jede Position | ct/kWh × abgerechnete Menge = ausgewiesener Betrag |
| Summe der Positionen | ergibt die Kosten für den Stromverbrauch |
| Summe der Einzelpreise | ergibt den Durchschnittspreis netto |
| Durchschnittspreis | Kosten ÷ Menge, brutto = netto × 1,19 |
| Grundgebühr | €/Monat und €/Tag × Tage, und die Tage passen zum Abrechnungszeitraum |
| Gesamtbetrag | Stromkosten + Grundgebühr, brutto und Mehrwertsteuer samt Steuersatz |
| Zählerstände | Endstand − Anfangsstand = abgerechnete Menge |
| Anschluss | Endstand der Vorrechnung = Anfangsstand dieser Rechnung, ohne Lücke im Zeitraum |

Die Toleranz folgt der Rundung: Wie genau ein Posten stimmen muss, ergibt sich aus den angegebenen
Nachkommastellen seines ct-Preises. Tibber rundet die Mehrwertsteuer je Position und summiert danach – der
Bruttobetrag einer Summe weicht deshalb um bis zu einen halben Cent je Position ab (Juni 2026: 86,05 € statt
86,06 €). Das wird als Rundung erkannt und nicht als Fehler gemeldet.

**Abgleich mit unseren Daten.** Hinweise, keine harten Fehler.

* Abgerechnete Menge gegen den gemessenen Netzbezug im selben Zeitraum, auf die Datenabdeckung hochgerechnet.
  Unser Wert stammt aus der CT-Messung des myenergi-Hubs, nicht aus dem geeichten Zähler; ein paar Prozent
  Unterschied sind normal. Ab 5 % Abweichung erscheint eine Warnung.
* Durchschnittspreis der Rechnung gegen den bezugsgewichteten Mittelwert der gespeicherten Tibber-Preise.
* Liegen für den Zeitraum keine eigenen Messwerte vor, sagt der Bericht das ausdrücklich.

## Schnittstelle für Automatisierungen

Die Prüfung liegt hinter demselben API-Token wie das Dashboard. Eine Automatisierung (z. B. OpenClaw, das im
Postfach eine neue Tibber-Rechnung findet) lädt sie so hoch:

```bash
curl -X POST "https://<api>/api/v1/import/tibber-invoice?file_name=Rechnung_5349264.pdf" \
  -H "authorization: Bearer $DCH_API_TOKEN" \
  -H "content-type: application/pdf" \
  --data-binary @Rechnung_5349264.pdf
```

Die Antwort ist der vollständige Prüfbericht:

```json
{
  "invoice": { "number": "5349264", "period_label": "August 2026", "kwh": 239.81, "positions": [...] },
  "findings": [ { "code": "position:Stromsteuer", "severity": "ok", "expected": 4.92, "actual": 4.92, "unit": "€", "delta": 0.0 } ],
  "verdict": "info",
  "measured": { "import_kwh": 220.4, "coverage": 0.976, "avg_price_ct_kwh": 35.22 },
  "already_known": false
}
```

* `verdict` ist die Ampel über alle Befunde: `ok`, `info`, `warning`, `error`. Ab `warning` lohnt ein Blick.
* `severity` je Befund ebenso; `expected`, `actual` und `delta` sind die Zahlen dahinter.
* Der Aufruf ist idempotent: dieselbe Rechnungsnummer ersetzt den gespeicherten Bericht, statt eine zweite
  Zeile anzulegen. Mehrfaches Hochladen schadet nicht, und eine erneute Prüfung nutzt die inzwischen
  vollständigeren Messwerte.
* Unlesbare oder fremde PDFs antworten mit `422` und einer Begründung im Feld `error.message`, ein leerer
  Rumpf mit `400`.

Weitere Endpunkte:

* `GET /api/v1/import/tibber-invoices` – alle geprüften Rechnungen, neueste zuerst, mit Menge, Beträgen,
  Durchschnittspreis, eigenem Vergleichswert und Ampel.
* `GET /api/v1/import/tibber-invoices/{nummer}` – ein vollständiger Bericht.

## Auswertung auf der Seite

* Menge je Abrechnungszeitraum: Rechnung gegen eigene Messung
* Rechnungsbetrag gestapelt nach Arbeitspreis, Grundgebühr und Mehrwertsteuer
* Durchschnittspreis brutto über die Zeit, daneben der aus unseren Preisdaten errechnete Wert
* Preisbestandteile der gewählten Rechnung als liegende Balken (ct/kWh)
* Tabelle aller Rechnungen; ein Klick zeigt jeden einzelnen Prüfschritt mit Erwartung, Rechnungswert und
  Abweichung
