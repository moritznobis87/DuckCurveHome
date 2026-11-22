# Der Regelkreis des Hauses

Stand: 22.11.2026. **Umsetzungsstand:** Struktur, Entwurf und Lernebene sind gebaut und liegen in
`packages/hems-core/src/hems_core/regelkreis/`. Die Seite `Technik → Regelkreis`
(`/waerme/regelkreis`) zeichnet sie. Zwei Schätzer sind angeschlossen und laufen über echten
Auswertungen: die COP-Ebene aus der gemessenen Kennlinie und die Totzeit der Wärmepumpe aus der
Ereignisstudie. Alles andere steht auf Startwerten aus Konfiguration und Datenblatt und ist auf der
Karte als Annahme gekennzeichnet.

Dieses Dokument beschreibt, **was** geregelt wird, **wie** die Regler entstehen und **wann** eine
Schätzung den geltenden Wert ersetzt.

## 1. Warum es diese Karte gibt

Die Anlage regelt auf fünf Ebenen mit Zeitkonstanten von Sekunden bis Stunden. Ihre rund dreißig
Parameter sind zu verschiedenen Teilen gemessen, geschätzt und geraten - der Verlustkoeffizient des
Hauses stand bis zuletzt als „Schätzung bis zur Messung" im Quelltext, die Arbeitszahl kommt aus
einer Ausgleichsebene über echten Fenstern, die Wärmekapazität des Puffers aus seiner Geometrie.
Verstreut über Module und Einstellungsseiten sieht das alles gleich aus: eine Gleitkommazahl neben
der anderen.

Genau diese Gleichheit ist das Problem. Wer den Verlustkoeffizienten für gemessen hält, zieht aus
dem Fahrplan Schlüsse, die er nicht ziehen darf. Die Karte trägt deshalb an jeder Zahl ihre
**Herkunft**: gemessen, geschätzt, angenommen, fest, Entwurf, übersteuert.

## 2. Die Kaskade

Von außen nach innen, und das ist zugleich von langsam nach schnell:

| Ebene | Kreis | Regelgröße | Stellgröße | Takt | Art |
|---|---|---|---|---|---|
| 4 | R4 | Kosten über 48 h | Führungsgrößen der unteren Kreise | 15 min | Planung (MILP) |
| 3 | R3 | Zuordnung der Wärmeanforderung | Anforderung und Ofenstufe | 10 min | hybrid |
| 3 | R2 | thermischer Ladestand | Anforderung (Kontakt) | 10 s | Zweipunkt |
| 1 | R1 | Vorlauftemperatur | Mischerstellung | 10 s | stetig |
| 0 | R0 | Raumlufttemperatur (10 ×) | Ventilhub | 60 s | stetig |

Dass R1 schneller ist als R0, ist kein Widerspruch zur Kaskade, sondern ihr Sinn: der schnelle
Kreis liegt **innen** und hält die Störungen vom langsamen fern. Zwischen R1 und R2 liegt mehr als
der Faktor fünf, den die Faustregel verlangt.

**R3 und R4 haben keine Frequenzkennlinie.** Ihre Stellgrößen sind Entscheidungen zwischen
Maschinen mit Mindestlaufzeiten, nicht stetige Größen. Eine Phasenreserve wäre dort eine Zahl ohne
Bedeutung; beurteilt werden sie am Umschaltpunkt und in Euro.

## 3. Die Störgrößen, und wie sie behandelt werden

Der regelungstechnisch interessante Unterschied ist nicht, **welche** Störgrößen es gibt, sondern
ob sie vor ihrer Wirkung bekannt sind. Deshalb trägt jede in `struktur.py` eine `behandlung`:

| Störgröße | Behandlung | Bemerkung |
|---|---|---|
| Strompreis | geplant | die einzige, die man kennt, bevor sie wirkt |
| Globalstrahlung | geplant / aufgeschaltet | Prognose im Fahrplan, Messung im Raum |
| Außentemperatur | aufgeschaltet | wirkt an vier Stellen verschieden |
| PV-Erzeugung, Hausbatterie | aufgeschaltet | bilden den effektiven Strompreis |
| Warmwasserzapfung | beobachtet | nicht gemessen, aus dem Bilanzrest geschätzt |
| Aufstellraum des Puffers | aufgeschaltet | halber Verlust ist nützlich |
| Abtauzyklus | erkannt | fällt aus der COP-Schätzung heraus |
| Interne Gewinne | aufgeschaltet | als Tagesprofil |
| Fensterlüftung | erkannt | Integrator wird angehalten |
| Raumwärme des Ofens | aufgeschaltet | aus dem Fahrplan, nicht nachträglich ausgeregelt |

## 4. Der Entwurf: SIMC

Die Regler werden **gerechnet, nicht eingestellt**. Aus den Streckenparametern folgt der PI-Regler
nach der Regel von Skogestad, mit der Ersatzzeitkonstante λ als einziger freier Zahl:

```
Strecke 1. Ordnung mit Totzeit:   KR = T1 / (K·(λ + Tt)),   Tn = min(T1, 4(λ + Tt))
Integrierer mit Totzeit:          KR = 1 / (k′·(λ + Tt)),   Tn = 4(λ + Tt)
Halbregel bei zwei Zeitkonstanten: T1′ = T1 + T2/2,  Tt′ = Tt + T2/2
```

Die Begrenzung der Nachstellzeit auf `4(λ + Tt)` ist der Teil der Regel, der gegen Laststörungen
hilft. Beim Estrich dieses Hauses greift genau das: ohne sie bliebe eine Störung stundenlang stehen.

**Die Hysterese wird abgeleitet, nicht gewählt.** Die Anforderung ist ein Kontakt, der Pufferkreis
also ein Zweipunktregler. Dessen Taktzahl folgt aus der Schaltdifferenz und den Steigungen davor
und danach; umgekehrt gelesen legt die Grenze von acht Starts am Tag die Breite fest:

```
Δ = Tzyklus / (1/ṙauf + 1/ṙab)
```

Beide Steigungen kommen aus gelernten Größen. Steigt der Verbrauch, wird die Hysterese von selbst
breiter - und das ist richtig, weil sonst die Taktzahl steigt.

**Geprüft wird im Frequenzbereich.** Die Phase wird dabei aus den Summanden der Glieder gebildet
und nicht aus einem komplexen Zeiger gelesen: die Phase einer Totzeit wächst ohne Grenze, und jede
Funktion, die sie auf ±180° zurückfaltet, verliert genau die Information, um die es geht. Unter 45°
Phasenreserve meldet die Karte einen Hinweis.

## 5. Die Lernebene

### 5.1 Drei Schritte

Ein Schätzer läuft mit und liefert einen Kandidaten mit Unsicherheit. Eine Prüfung entscheidet, ob
der Kandidat den geltenden Wert ersetzen darf. Erst dann ändert sich etwas an der Regelung, und es
steht mit Datum, Zahlen und Grund im Protokoll.

Der geltende Wert springt also nur, wenn sich der Sprung begründen lässt. Ein Regler, dessen
Verstärkung minütlich eine andere ist, wäre kein lernender Regler, sondern ein unruhiger.

### 5.2 Die fünf Hürden

| Code | Bedeutung |
|---|---|
| `zu_wenig_daten` | weniger als 30 Stützstellen |
| `grenzen` | außerhalb der Plausibilitätsgrenzen - abgelehnt, **nicht** beschnitten |
| `innerhalb_unsicherheit` | Abweichung kleiner als 1,35 σ |
| `zu_frueh` | weniger als 14 Tage seit der letzten Übernahme |
| `nicht_besser` | Restfehler im Vergleich nicht um 2 % kleiner |
| `uebernommen` | alle Hürden genommen |

Jeder Code hat genau einen deutschen Satz und einen Test, wie die Reason-Codes des Reglers. Auf der
Oberfläche steht deshalb nicht nur, **dass** nichts übernommen wurde, sondern **warum** nicht.

**Damit kann das Modell nie schlechter werden als sein Startwert.** Das ist die Eigenschaft, die
den Aufbau rechtfertigt: Lernen ist hier kein Versprechen auf Verbesserung, sondern eine Reihe von
Prüfungen, die im Zweifel nichts tun.

### 5.3 Woher die Kandidaten kommen

Nichts wird doppelt gemessen. Die Kandidaten kommen aus Auswertungen, die der Dienst ohnehin
rechnet:

| Parameter | Quelle | Stand |
|---|---|---|
| COP-Ebene a, b, c | `thermal.kennlinie.ausgleich` | **angeschlossen** |
| Totzeit und Anlaufzeit der Wärmepumpe | `thermal.kontaktwirkung` (Ereignisstudie) | **angeschlossen** |
| Verlustbeiwert des Puffers | Abkühlung in Nächten ohne Betrieb | Funktion da, Daten noch nicht angebunden |
| Verlustkoeffizient des Hauses, interne Gewinne | Wärmebilanz gegen Gradstunden | RLS da, Datenpfad offen |
| Raumkapazitäten, solare Apertur, Ventilautorität | Raumhistorie | offen |

Die Unsicherheit der Kennliniensteigung hängt an der Spanne der Punkte: eine Kennlinie aus einer
einzigen Kältewoche gibt die Vorlaufabhängigkeit nicht her, und `ausgleich` setzt den Term dann auf
null, statt eine Zahl zu erfinden. Eine solche Null wird **nicht** als Kandidat vorgeschlagen.

### 5.4 Wo der Zustand liegt

In `model_calibrations` unter dem Schlüssel `regelkreis_v1`, wie der PV-Korrektor unter
`pv_forecast_v1`. Eine eigene Tabelle braucht er nicht: er ist ein Zustand je Modell. Der Lernlauf
findet höchstens stündlich statt; die Übernahmeprüfung wartet ohnehin vierzehn Tage.

In der Vorführung läuft derselbe Lernlauf über den Auswertungen des Vorführhauses, aber nur im
Arbeitsspeicher - eine Vorführung, in der ein Lernstand einen Neustart überlebt, behauptet eine
Dauer, die sie nicht einlösen kann.

## 6. Übersteuern

Jeder Parameter lässt sich von Hand setzen (`POST /regelkreis/parameter/{pid}`). Die Übersteuerung
gewinnt gegen jede Schätzung, bis sie freigegeben wird; der Schätzer läuft weiter und schreibt mit,
was er gesagt hätte. Beschnitten wird auf die Plausibilitätsgrenzen - wer sich vertippt, bringt die
Regelung nicht zum Stehen.

Die abgeleiteten Reglerwerte ändern sich mit. Das ist der Zweck: so lässt sich sehen, was eine
andere Streckenannahme aus dem Regler macht, ohne dass jemand am Regler dreht.

## 7. Der Arbeitspunkt

Die Verstärkung der Wärmepumpe ändert sich zwischen einem milden und einem kalten Tag um den Faktor
zwei. Die Karte wird deshalb für den Augenblick gerechnet, und die Antwort sagt, woher ihre
Temperaturen kamen: `aussen_gemessen` und `vorlauf_gemessen`. Wo die Vorlauftemperatur fehlt, wird
sie aus der Heizkennlinie gerechnet - also aus dem Sollwert, auf den die Anlage gerade zielt.

Wer die Seite an zwei verschiedenen Tagen aufruft, sieht zwei verschiedene Regler. Das ist
Verstärkungsplanung, und sie ist damit sichtbar.

## 8. Was offen ist

1. **Die übrigen Schätzer anschließen.** Die Reihen liegen vor; es fehlt der Datenpfad von der
   Minutenreihe in den RLS. Die Reihenfolge nach Nutzen: H des Hauses, Verlustbeiwert des Puffers,
   Steilheit der Heizkennlinie.
2. **Je Raum statt ein Raum.** Das Register führt einen Satz Raumparameter; das Haus hat zehn
   Kreise. Die Plausibilitätsprüfung (Summe der Raumverluste gegen H) setzt zehn Sätze voraus.
3. **Der Regler nutzt den Entwurf noch nicht.** Die Karte rechnet KR und Tn aus den gelernten
   Parametern; der laufende Regler arbeitet weiter mit seiner Zustandsmaschine aus
   `control/heat_pump_controller.py`. Die Verbindung ist der nächste Schritt und braucht einen
   dokumentierten Freigabetest.
4. **Zweiter Knoten im Raummodell.** Die Estrichtemperatur wird nicht gemessen; für die gemeinsame
   Zustands- und Parameterschätzung fehlt der erweiterte Kalman-Filter.

## Dateien

| Pfad | Inhalt |
|---|---|
| `hems_core/regelkreis/struktur.py` | Blöcke, Signale, Störgrößen, Kreise - als geprüfte Daten |
| `hems_core/regelkreis/parameter.py` | das Register: Symbol, Einheit, Startwert, Grenzen, Herkunft |
| `hems_core/regelkreis/entwurf.py` | Streckenmodelle, SIMC, Frequenzkennlinie, Reserven, Hysterese |
| `hems_core/regelkreis/schaetzer.py` | RLS, EWMA, Übernahmeprüfung, Schätzstand |
| `hems_core/regelkreis/messung.py` | Kandidaten aus den bestehenden Auswertungen |
| `hems_core/regelkreis/karte.py` | setzt alles zu einer Antwort zusammen |
| `dch_api/application/regelkreis.py` | Lernlauf, Arbeitspunkt, Persistenz |
| `dch_api/routers/regelkreis.py` | `GET /regelkreis`, `POST`/`DELETE /regelkreis/parameter/{pid}` |
| `apps/web/src/components/regelkreis/` | die Zeichnung: Layout, Karte, Detailblatt |
