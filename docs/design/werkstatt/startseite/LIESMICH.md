# Werkstatt: Redesign der Startseite

Der Hausherr hat am 25.11.2026 ein komplettes Redesign der Startseite verlangt: „noch besser und
vor allem noch viel stylischer“. Hier liegen Auftrag, Grundlage, Entwürfe und Urteile, damit die
Arbeit einen Abbruch der Sitzung übersteht. Gebaut wird in Dashboard und App erst, wenn der
Hausherr einen Entwurf freigegeben hat (CLAUDE.md: Gliederung und Bedienung entscheidet er).

## Stand

| Schritt | Stand |
|---|---|
| Bestandsaufnahme: was die Seite heute zeigt | fertig, siehe „Pflichtinhalt“ und `bestand/` |
| Grundlage für Entwürfe (`grundlage/`) | fertig |
| Entwurf `buehne/` | fertig, mit Bildern und Begründung |
| Entwurf `kacheln/` | fertig, mit Bildern und Begründung |
| Entwurf `uhr/` | fertig, mit Bildern und Begründung |
| Entwurf `strom/` | nicht gebaut: die breiten Bänder sind in die „Bühne“ eingegangen |
| Urteile in eigenen Prüfläufen | nicht gemacht: ein Lauf mit mehreren Agenten wurde abgelehnt |
| Empfehlung und Vorlage an den Hausherrn | vorgelegt am 25.11.2026, Entscheidung steht aus |

Die Entwürfe hat eine Sitzung allein gebaut, einen nach dem anderen, jeder mit eigenem Commit.
Empfohlen ist die „Bühne“; die Gründe stehen in `empfehlung.md`.

## Der Bestand

`bestand/wand.png` und `bestand/handy.png` zeigen die Startseite vom 25.11.2026 im Demo-Betrieb.
Was an ihr schwach ist:

- Der Energiefluss ist ein Stern aus dünnen Linien mit kleinen Knoten und verstreuten Zahlen. Er
  füllt die halbe Wand und wirkt wie ein Schaltplan, nicht wie ein Bild des Hauses.
- Die Seite hat keine Rangfolge: Satz, Fluss, Puffer, Kurve, Zahlen und Schalter sind gleich leise.
- Sie nutzt die Kartensprache nicht, die der Hausherr inzwischen auf allen anderen Seiten
  freigegeben hat (Zeichenfeld, Farbschimmer, runde Knöpfe, Zustand als Farbe).
- Am Handy trägt der Block „Die nächsten 24 Stunden“ fünf Sätze Text.
- Die vier Zahlen am Fuß und die Schalter sind klein und ohne Gewicht; an der Wand verdeckt
  Alfreds Ente den letzten Schalter.

## Pflichtinhalt

Ein Entwurf darf alles umstellen, anders zeichnen und zusammenfassen. Weglassen darf er nichts aus
dieser Liste, ohne es in seiner Begründung zu sagen. Die Seite beantwortet eine Frage: **Was tut
das Haus gerade, und warum.**

1. **Kopf.** Marke „Duck Curve“; die fünf Bereiche Jetzt, Haus, Energie, Geld, Anlage; das Zahnrad
   („Einstellen“) und die Person („Mein Zugang“); Datum, Uhrzeit, Außentemperatur; der Zustand der
   Verbindung (live, demo oder „unterbrochen · 18:26“). Am Handy stehen die fünf Bereiche als
   Leiste am unteren Rand (rund 86 Pixel hoch, immer sichtbar), und die Uhrzeit entfällt, weil das
   Telefon sie selbst zeigt.
2. **Der Satz.** Die Begründung der Regelung in einem Satz, darunter eine Zeile: wer entscheidet
   (Automatik oder von Hand) und was als Nächstes kommt.
3. **Die Wache.** Bis zu zwei Befunde als Hinweis oder Störung. Ohne Befund steht nichts da.
4. **Der Energiefluss jetzt.** Sonne (kW; nachts der Mond mit „Sonne ab 07:52“), Netz (kW, Bezug
   oder Einspeisung), Haus (kW, die Summe), Speicher (Prozent, lädt, entlädt oder hält),
   Wärmepumpe (kW, läuft oder steht), Wallbox (kW, lädt oder steht). Jede Sache ist antippbar und
   führt auf ihre Seite.
5. **Der Puffer.** Ladestand in Prozent, sein Zustand (lädt, hält), vier Fühlertemperaturen von
   oben nach unten und der Farbverlauf von warm nach kalt.
6. **Die nächsten 24 Stunden.** Strompreis jetzt mit einem Wort (günstig, teuer), der Verlauf des
   Preises, die erwartete Sonne, die geplanten Läufe der Wärmepumpe, das Preistief und die beste
   Sonnenzeit als Zeitspannen. Heute sind das an der Wand drei Zeilen und am Handy fünf Sätze.
7. **Die Kurve des Tages** mit dem Schalter Gestern, Heute, Morgen: Sonne gemessen, Prognose,
   gestern als Schatten, Hausverbrauch, Strompreis, Preistief, die Marke „jetzt“.
8. **Vier Zahlen des Tages:** Sonne geerntet, ohne Netz, bezahlt bis jetzt, Strom gerade. Sie
   wechseln mit Gestern, Heute, Morgen.
9. **Die Schalter.** Kaffee, Terrasse, Hof, Zaun schalten sofort; Wärmepumpe, Ofen und Alarm
   öffnen eine Auswahl. Jeder zeigt, ob er an ist.
10. **Alfred.** Die Ente als schwebender runder Knopf, 56 Pixel, unten rechts. Sie darf nichts
    verdecken, was man bedienen muss.

## Vorgaben

- **Wand:** 1280 × 800 quer (und 1180 × 820 am iPad). Alles steht auf einem Schirm, die Wand rollt
  nicht. Die wichtigsten Zahlen sind aus drei Metern lesbar, also mindestens 40 Pixel hoch.
  Berührziele sind mindestens 44 Pixel groß.
- **Handy:** 390 × 844 hoch. Eine Spalte, die Seite rollt, die Leiste der Bereiche bleibt unten
  stehen. Der erste Schirm muss die Frage der Seite schon beantworten.
- **Dashboard und App zeigen dasselbe.** Der Entwurf muss sich im Web (SVG, CSS) und in SwiftUI
  (Canvas, Swift Charts, Verläufe, Formen) bauen lassen. Keine Fotos, keine 3D-Bibliothek, keine
  anderen Schriften als IBM Plex Sans und IBM Plex Mono.
- **Farben nur aus `grundlage/grund.css`.** Jede Sache hat ihre Farbe: Sonne Bernstein, Netzbezug
  Violett, Einspeisung helles Bernstein, Speicher Nebelgrau, Wärmepumpe Terrakotta, Wallbox Blau,
  Haus Weiß. Grün steht nur für „in Ordnung“, Rot nur für eine Störung.
- **Wenig Text.** Je Karte höchstens ein Satz. Was sich zeichnen lässt, wird gezeichnet. Wo Text
  steht, ist er ausformuliert: keine Stichwortketten, keine angehängten Gedankenstriche.
- **Nacht ist im Winter der Normalfall.** Der Entwurf muss ohne Sonne so gut aussehen wie mit.
- **Zustände zeigen:** Wärmepumpe läuft, Verbindung unterbrochen (das Bild ist dann von eben),
  ein Befund der Wache.
- **Bewegung** ist erwünscht, wo sie etwas sagt: Energie, die fließt, darf sich bewegen. Sie darf
  nicht ablenken und muss sich abschalten lassen (`prefers-reduced-motion`).

## Der Geschmack des Hausherrn

Aus seinen Rückmeldungen im November 2026:

- Zu den alten Übersichten: „grafisch, echt schwach und viel zu viel Text. Bitte besser.“ Danach
  kamen Kacheln mit Zeichen, großer Zahl und kleinem Bild. Die gefielen.
- Zu „Einstellen“ und „Mein Zugang“: „könnten noch deutlich stylisher gestaltet werden“. Danach
  kamen Karten mit Zeichenfeld und Farbschimmer aus der Ecke, eine Zustandskarte, die grün oder
  bernsteinfarben ist, runde Knöpfe und Marken. Das hat er auf alle Systemseiten ausdehnen lassen.
- Zu „Zugang und Sicherung“: „der ganze Kilometer lange Text … muss weg“.
- Zur Startseite: „komplettes Redesign“, „noch viel stylischer“.

Er sieht die Seite an drei Orten: als Anzeige an der Wand, am iPad und am iPhone. Er urteilt nach
dem Bild und ist ungeduldig mit Erklärungen.

## Die vier Richtungen

Jede Richtung liegt in einem eigenen Ordner und folgt einer Leitidee. Mutig sein: ein Entwurf, der
aussieht wie die Seite von heute mit runderen Ecken, hat sein Ziel verfehlt.

| Ordner | Leitidee |
|---|---|
| `buehne/` | **Die Bühne.** Die obere Hälfte ist ein Bild des Hauses unter seinem Himmel: der Sonnenbogen von Aufgang bis Untergang mit der Sonne an ihrer Stelle, nachts der Mond. Energie fließt als leuchtende Bänder, deren Breite die Leistung zeigt. Der Satz steht als Überschrift auf der Bühne. |
| `kacheln/` | **Das Kachelfeld.** Ein Raster aus verschieden großen Kacheln wie die Widgets eines iPhone, in der eingeführten Kartensprache. Jede Kachel ist eine Sache mit Zeichenfeld, großer Zahl und kleinem Bild; der Zustand färbt die Kachel. Größte Stimmigkeit mit den übrigen Seiten. |
| `uhr/` | **Die Uhr.** Die Mitte ist ein großer Ring, der 24 Stunden zeigt: außen der Strompreis als Farbband, innen die erwartete Sonne und die Läufe der Wärmepumpe, ein Zeiger für jetzt. In der Mitte steht, was das Haus gerade braucht. Ein Instrument statt eines Diagramms. |
| `strom/` | **Der Strom.** Ein Flussbild quer über die Seite: links die Quellen, rechts die Verbraucher, dazwischen breite, weich geschwungene Bänder in der Farbe der Quelle, deren Breite die Leistung zeigt. Darunter der Tag als ein Band mit Preis, Sonne und Fahrplan. |

## Was ein Entwurf abliefert

Im eigenen Ordner, und nur dort:

- `entwurf.html`: eine Datei mit ihrer Aufteilung und ihrem Hauptbild. Sie lädt nur die Dateien
  aus `../grundlage/`. Sie liest `window.SZENE` und zeichnet
  daraus; feste Zahlen im HTML sind nicht erlaubt. Über 900 Pixel Breite ist sie die Wand,
  unter 720 das Handy. Am Handy rollt das Dokument selbst.
- `bilder/`: die Aufnahmen aus `node ../grundlage/aufnehmen.cjs entwurf.html`. Das Skript meldet,
  wenn die Wand über ihren Schirm läuft oder das Handy seitwärts rollt; beides ist zu beheben.
- `begruendung.md`: die Leitidee in drei Sätzen; was wo steht; was gegenüber heute wegfällt,
  wandert oder zusammengefasst ist; wie die schwierigen Teile in SwiftUI gebaut würden; was offen
  ist. Höchstens eine Seite.

Die Aufnahmen werden angesehen, bevor der Entwurf als fertig gilt: Überlappungen, abgeschnittene
Schrift, leere Flächen und zu kleine Zahlen sind Fehler, die man nur im Bild sieht.

## Die Grundlage

- `grundlage/grund.css`: Farben, Schriften und die eingeführte Kartensprache (`.karte`,
  `.zeichenfeld`, `.knopf`, `.marke`).
- `grundlage/zeichen.js`: die 34 Zeichen des Dashboards, `zeichen("sun", 22)` liefert das SVG.
- `grundlage/daten.js`: drei Szenen desselben Tages. `?szene=mittag` (Sonne, Wärmepumpe läuft,
  Speicher lädt, Einspeisung), `?szene=abend` (dunkel, Netzbezug, Speicher entlädt, Strom teuer;
  die Vorgabe) und `?szene=stoerung` (der Abend mit einem Befund und unterbrochener Verbindung).
- `grundlage/bausteine.css` und `grundlage/bausteine.js`: was alle Entwürfe gemeinsam haben
  (Kopf, Satz, Wache, Puffer, die nächsten 24 Stunden, Tageskurve, Schalter, Leiste, Alfred).
  Ein Entwurf setzt diese Teile zusammen und zeichnet nur sein Hauptbild selbst.
- `grundlage/aufnehmen.cjs`: nimmt Wand, iPad und Handy auf.
