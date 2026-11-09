# Was der Freigabekontakt K1 auslöst

Stand 09.11.2026. Seite `Wärme → Wirkung`, Endpunkt `GET /api/v1/anlage/kontaktwirkung?days=7|30|90`,
Rechnung in `packages/hems-core/src/hems_core/thermal/kontaktwirkung.py`.

## Die Frage

K1 ist eine Anforderung, keine Sperre. Der Planer schließt den Kontakt in den günstigen Stunden
und rechnet damit, dass die Wärmepumpe dann läuft. Ob sie das tut, entscheidet ihre eigene
Regelung. Der Projektplan führt das seit September als offene Frage 25.8. Beide Reihen,
`hp_release_contact` und `heat_pump_power_kw`, liegen minütlich und dauerhaft im Bestand; bis zum
09.11.2026 hat sie niemand gegeneinandergestellt.

## Die Methode: eine Ereignisstudie

Jeder Schließvorgang des Kontakts ist ein Ereignis. Um jedes Ereignis wird die Leistung der
Maschine ausgeschnitten, von 30 Minuten davor bis 120 Minuten danach, und alle Ausschnitte werden
an ihrem Nullpunkt übereinandergelegt. Rechts der Null steht, was auf den Kontakt folgte; links,
was ohnehin geschah.

| Festlegung | Wert | Warum |
|---|---|---|
| Ein Schließvorgang | Übergang von offen zu geschlossen nach 10 Minuten durchgehend offenem Kontakt | Ohne die Ruhe davor zählte jedes Flattern als neues Ereignis. Über eine Lücke in der Erfassung hinweg entsteht keines: wo der Kontakt unbekannt war, ist auch sein Schließen unbekannt. |
| „Läuft“ | Leistung ab `heat_pump.running_threshold_kw` (0,5 kW), die Schwelle selbst zählt | Dieselbe Schwelle wie im Taktzähler, im Fahrplan und in der Wiedergabe. Darunter liegt die Grundlast der Anlage. |
| Auswertbar | Die Maschine stand in der Minute vor dem Schließen, und das Folgefenster ist zu mindestens 80 Prozent gemessen oder zeigt einen Anlauf | An einer schon laufenden Maschine lässt sich nicht ablesen, ob der Kontakt etwas auslöst. Fehlt die Messung, ist das Ausbleiben eines Anlaufs keine Aussage. |
| Gefolgt | Anlauf binnen 30 Minuten | Startverzögerung und Entprellung liegen bei wenigen Minuten; eine halbe Stunde lässt Luft, ohne den nächsten ohnehin fälligen Lauf mitzunehmen. |

Die Festlegungen stehen als Konstanten am Kopf des Moduls. Sie sind gesetzt, nicht gemessen; wer
sie ändert, ändert die Quote.

## Der Vergleich

„Nach dem Schließen läuft sie in 70 Prozent der Fälle an“ sagt nichts, wenn sie zu dieser
Tageszeit ohnehin alle vierzig Minuten anläuft. Neben der Folgequote steht deshalb dieselbe Quote
für Momente **ohne** Schließvorgang:

* Der Zeitraum wird in halbe Stunden geteilt, die sich nicht überlappen. Überlappende Fenster
  sähen fast dasselbe und gäben eine Sicherheit vor, die in ihnen nicht steckt.
* Eine halbe Stunde zählt, wenn die Maschine an ihrem Anfang steht und der Kontakt von 10 Minuten
  davor bis zu ihrem Ende durchgehend offen ist.
* Verglichen wird **zur selben Tageszeit**: die Quote je Ortsstunde, gewichtet mit der Zahl der
  Ereignisse in dieser Stunde. K1 schließt nicht zufällig über den Tag verteilt, sondern in den
  günstigen Stunden, und in denen hat das Haus seinen eigenen Rhythmus.

Schließt K1 an jedem Tag zur selben Stunde, gibt es zu dieser Stunde keinen Moment ohne K1 und
damit keinen Vergleich. Die Antwort sagt das, statt auf den ganzen Tag auszuweichen.

## Das Urteil

Beide Quoten bekommen einen 95-Prozent-Bereich nach Wilson. Wilson und nicht die Schulformel,
weil die bei kleinen Zahlen Grenzen außerhalb von null bis hundert Prozent liefert und bei
„7 von 7“ einen Bereich der Breite null.

| Urteil | Bedingung |
|---|---|
| `offen` | weniger als 8 auswertbare Ereignisse, oder weniger als 20 Vergleichsmomente zur selben Tageszeit |
| `wirkt` | der Bereich mit K1 liegt ganz über dem Bereich ohne K1 |
| `seltener` | der Bereich mit K1 liegt ganz unter dem Bereich ohne K1 |
| `kein_unterschied` | die Bereiche überlappen |

Dass sich die Bereiche nicht überlappen dürfen, ist strenger als ein üblicher Test auf dem
5-Prozent-Niveau. Das ist Absicht: an diesem Urteil hängt, ob der Planer dem Kontakt etwas
zutrauen darf, und ein vorschnelles Ja kostet mehr als ein spätes. Das Urteil fällt der Server;
die Oberfläche zeichnet es.

## Was die Seite zeigt

1. **Der Satz und die beiden Quoten** mit ihren Bereichen auf einer Spur von 0 bis 100 Prozent.
   Die Regel des Urteils ist dort zu sehen: überlappen die Balken, gibt es keines.
2. **Der Antwortfächer.** Oben jede einzelne Antwort als dünne Kurve und darüber die mittlere
   Leistung. Das Mittel und nicht der Median: die Maschine läuft oder steht, und bei drei
   laufenden und drei stehenden läge der Median auf halber Höhe, wo keine Kurve je lag. Das Mittel
   ist Anteil mal Leistung, also das, womit ein Planer nach dem Schließen rechnen kann. Unten der
   Anteil der Ereignisse, die bis zu dieser Minute angelaufen sind, und gestrichelt dieselbe Kurve
   ohne K1. Zwei Flächen statt zweier Achsen in einem Gitter.
3. **Das Raster.** Jeder Schließvorgang eine Zeile, sortiert nach Verzögerung. Eine Zeile öffnet
   die Wiedergabe dieses Tages zu dieser Stunde.

## Grenzen

* **Zusammenhang, keine Ursache.** Der Regler schließt K1, wenn der Puffer Platz hat und der Strom
  günstig ist; ein Anlauf danach kann auch am leeren Puffer liegen. Der Vergleich zur selben
  Tageszeit nimmt den Tagesrhythmus heraus, nicht den Pufferzustand. Die saubere Antwort wäre ein
  Versuch: den Kontakt zu zufälligen Zeiten schließen. Das ist ein Eingriff in den Betrieb und eine
  Entscheidung des Hausherrn; gebaut ist es nicht.
* **Der Bereich des Vergleichs** steht auf den zusammengelegten Zählungen der Ereignisstunden, die
  Vergleichsquote selbst ist nach Ereignisstunden gewichtet. Bei ungleich verteilten Ereignissen
  liegen beide leicht auseinander.
* **Die Tageszeit ist die einzige Schichtung.** Außentemperatur, Wochentag und Jahreszeit gehen
  nicht ein. Über 90 Tage im Herbst mischt die Auswertung milde und kalte Wochen.
* **Was K1 in der Maschine bewirkt**, also Sollwertanhebung oder Warmwasserladung und um wie viel
  Kelvin, beantwortet diese Auswertung nicht. Sie sagt, ob und wann die Maschine anläuft und wie
  viel sie dann zieht, nicht wohin die Wärme geht.
* **Vor dem 09.11.2026 hat Duck Curve Home K1 im Haus nicht gestellt.** Schließvorgänge aus dieser
  Zeit stammen von der Hausautomation oder von Hand. Sie gehen in die Auswertung ein wie alle
  anderen; ob sie unter denselben Umständen fielen wie die des Planers, ist nicht geprüft.
* **Der Kontakt muss Minute für Minute bekannt sein.** Ein Schließvorgang braucht zehn bekannte
  offene Minuten davor, ein Vergleichsmoment vierzig. Die Brücke liest alle Zustände seit dem
  29.10.2026 alle 30 Sekunden nach, auch unveränderte; davor schrieben manche Quellen nur bei
  Änderung. Für die Zeit davor kann der Kontakt deshalb lückenhaft im Bestand stehen, und dann
  findet die Auswertung dort wenig oder nichts. Sie verschweigt das nicht: die Antwort nennt den
  Anteil der Minuten, in denen Kontakt und Leistung bekannt sind (`abdeckung_kontakt`,
  `abdeckung_leistung`), und warnt unter 90 Prozent. Den letzten bekannten Zustand über die Lücke
  fortzuschreiben wäre die Abhilfe; gebaut ist sie nicht, weil erst der Blick auf den Bestand des
  Hauses zeigt, ob es die Lücken gibt.
* **In der Vorführung** reicht das Gedächtnis 72 Stunden zurück. Die Seite zeigt dort ihre Form;
  für ein Urteil reicht es fast nie, und die Antwort sagt das.
* **Gemessen am 09.11.2026 nur an der Vorführung**, nicht am Bestand des Hauses. Was die Seite
  dort zeigt, ist offen, bis jemand sie im Haus aufruft.
