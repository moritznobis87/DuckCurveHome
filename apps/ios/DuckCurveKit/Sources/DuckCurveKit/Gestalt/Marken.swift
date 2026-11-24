import Foundation

/// Die Design-Tokens, eine Quelle.
///
/// Uebersetzt aus `apps/web/src/styles/tokens.css`, mit den Begruendungen von dort - sie sind
/// keine Verzierung, sondern Auflagen an jede Grafik, die diese Farben benutzt.
///
/// **Warum hier Zahlen und keine `Color`.** Dieses Paket kennt kein SwiftUI, damit es unter Linux
/// baut und getestet werden kann. Die Umsetzung nach `Color` steht in
/// `../DuckCurveHome/Gestalt/Farben.swift` und ist eine Zeile je Marke. Der Vorteil: die
/// Palettenpruefung (`MarkenTests`) laeuft hier mit und faellt auf, wenn jemand eine Serienfarbe
/// aendert, ohne den Abstand zu ihren Nachbarn nachzurechnen.
public enum Marken {
    // MARK: - Marke, identisch zur Website

    public static let petrol = Farbwert(0x0F2E3D)
    public static let deep = Farbwert(0x082431)
    public static let amber = Farbwert(0xF2A900)
    public static let amberWeich = Farbwert(0xFFD778)
    public static let mist = Farbwert(0x7FA3B3)
    public static let papier = Farbwert(0xFFFFFF)
    public static let wolke = Farbwert(0xF1F5F5)
    public static let tinte = Farbwert(0x102E3C)

    // MARK: - Dunkle Oberflaechen

    public static let grund = deep
    public static let flaeche1 = Farbwert(0x0F2E3D)
    public static let flaeche2 = Farbwert(0x123544)
    public static let flaeche3 = Farbwert(0x173F50)
    public static let flaecheGlas = Farbwert(0x082431, deckung: 0.38)
    public static let linie1 = Farbwert(0xFFFFFF, deckung: 0.10)
    public static let linie2 = Farbwert(0xFFFFFF, deckung: 0.17)
    public static let rasterlinie = Farbwert(0xFFFFFF, deckung: 0.09)

    /// Der Grund einer gedrückten Zeile in einer anklickbaren Liste.
    ///
    /// **Eine eigene Stufe unter ``linie1``, und der Unterschied ist zu sehen.** Die Vorlage
    /// legt der Zeile unter dem Zeiger `rgba(255,255,255,.06)` unter (`globals.css:664`,
    /// `a.wk-zeile:hover`); die Wirkungsseite nahm dafür ``linie1`` (Weiss auf 0,10) und war
    /// damit um zwei Drittel zu kräftig. Bei achtzig Zeilen übereinander ist das der
    /// Unterschied zwischen „diese Zeile liegt unter dem Finger“ und „diese Zeile ist
    /// ausgewählt“ - und ausgewählt wird dort nichts.
    ///
    /// Eigener Name und nicht ``linie1`` mit anderer Deckung: ``linie1`` ist eine **Linie**,
    /// und wer deren Deckung hebt, soll damit nicht die Rückmeldung jeder Liste mitheben.
    public static let zeileGedrueckt = papier.mitDeckung(0.06)

    /// Der Rand der berührten Zelle einer Rasterkarte.
    ///
    /// `rgba(255,255,255,.85)` (`charts.ts:540`, `emphasis.itemStyle.borderColor`). **Nicht
    /// ``text1`` auf 0,85, wie die Abdeckungskarte es rechnete:** SwiftUI multipliziert
    /// `opacity` mit der vorhandenen Deckung, und `text1` trägt schon 0,92 - heraus kamen 0,78
    /// und damit ein blasserer Rahmen als in der Vorlage. Der Rand ist ausserdem keine
    /// Schrift: er sagt „hier liegt der Finger“, und das ist eine andere Sache als Text erster
    /// Stufe.
    public static let zelleBeruehrt = papier.mitDeckung(0.85)

    /// Die Spur der Tagesuhr: wo gemessen wurde, aber nichts lief.
    ///
    /// **Eine eigene Stufe und nicht die nächste vorhandene.** Die Vorlage setzt
    /// `rgba(255,255,255,.055)` (`waerme/Tagesuhr.tsx:51`, Konstante `SPUR`), und das liegt
    /// zwischen `rasterlinie` (0,09) und nichts. Beide Nachbarn wären falsch: mit 0,09 liest
    /// sich die Spur als Messwert statt als Untergrund, mit 0,10 (`linie1`) als Rahmen. Die
    /// Uhr trägt damit drei Aussagen - Spur heißt „gemessen, aber nein“, eine Füllung heißt
    /// „ja“, und gar nichts heißt „keine Messung“ -, und die schwächste von ihnen braucht
    /// ihren eigenen Wert.
    public static let spur = papier.mitDeckung(0.055)

    /// Der Verlauf des Hintergrunds, 130 Grad wie im Dashboard.
    public static let grundVerlauf: [(farbe: Farbwert, stelle: Double)] = [
        (deep, 0.0), (petrol, 0.62), (Farbwert(0x153C4C), 1.0),
    ]

    // MARK: - Die Bühne der Anlagenzeichnung

    /// Die Fläche, auf der das Anlagenschema steht - oben.
    ///
    /// **Warum sie keine Kartenfläche ist.** `rgba(10,39,53,.85)` über dem Seitenverlauf
    /// (`globals.css:565`, `.anlage-buehne`), und das ist dunkler als jede Karte der App. Die
    /// Deckungen der Zeichnung - die Lichtpunkte in den Rohren, der Sonnenschein hinter der
    /// PV, die Glaskacheln - sind für diesen Grund gerechnet; auf `flaeche1` verlieren genau
    /// die Teile ihren Kontrast, die das Bild tragen. Zwei Seiten teilen die Bühne
    /// (`globals.css:606-609`), darum steht sie hier und nicht in einer von ihnen.
    public static let buehneOben = Farbwert(0x0A2735, deckung: 0.85)

    /// Dieselbe Fläche unten: `rgba(5,22,31,.9)` (`globals.css:565`). Der Verlauf nach unten
    /// ins Dunklere lässt die Zeichnung auf dem Boden stehen statt im Nichts zu schweben.
    public static let buehneUnten = Farbwert(0x05161F, deckung: 0.9)

    /// Der Rand der Bühne, als Verlauf und nicht als Strich.
    ///
    /// `linear-gradient(180deg, rgba(255,255,255,.14), rgba(255,255,255,.03) 30%,
    /// rgba(255,255,255,.02))` (`globals.css:564`). **Der Stopp bei 30 Prozent ist der Sinn
    /// der Sache:** er macht aus dem Verlauf eine Lichtkante oben statt eines gleichmäßigen
    /// Grauwerts. Eine Haarlinie in einer Farbe wäre oben zu dunkel und unten zu hell - die
    /// Stellen gehören darum zum Wert und stehen mit ihm an einer Stelle.
    public static let buehneRand: [(farbe: Farbwert, stelle: Double)] = [
        (papier.mitDeckung(0.14), 0.0), (papier.mitDeckung(0.03), 0.3),
        (papier.mitDeckung(0.02), 1.0),
    ]

    // MARK: - Text auf Dunkel

    public static let text1 = Farbwert(0xFFFFFF, deckung: 0.92)
    public static let text2 = Farbwert(0xFFFFFF, deckung: 0.72)
    /// Die blasse Stufe traegt Beschriftungen in 10 bis 13 Punkten. Mit 48 % Deckung lag sie auf
    /// den Karten unter 4,5:1 (4,41 auf Flaeche 1, 4,22 auf Flaeche 2, 3,88 auf Flaeche 3). Mit
    /// 58 % sind es 5,76, 5,42 und 4,92 (`tokens.css`, `--text-3`, gemessen am 24.11.2026).
    public static let text3 = Farbwert(0xFFFFFF, deckung: 0.58)
    /// Die Stichwortzeile. Eine Stufe heller als ``mist``: das Nebelgrau selbst lag als Schrift
    /// auf Flaeche 3 bei 4,18:1, dieses bei 4,96 (`tokens.css`, `--text-kicker`). ``mist`` bleibt
    /// die Farbe der Reihen und Marken.
    public static let textKicker = Farbwert(0x8AB2C4)

    // MARK: - Energie-Semantik (Serienfarben, auf flaeche2 geprueft)

    // **Eine Farbe je Sache, seit dem 24.11.2026** (Vorgabe des Hausherrn, `tokens.css` und
    // `charts/palette.ts` nennen dieselben Werte). Vorher faerbten Energiefluss und Diagramm
    // den Netzbezug, den Speicher, die Wallbox und die Einspeisung verschieden. Gemessen in
    // docs/design/werkstatt/LIESMICH.md, „Vorschlag fuer Zustaende und Reihen“.

    public static let pv = amber
    /// Netzbezug: ein Violett. Er war im Fluss Nebelgrau und im Diagramm das Rot der Stoerung;
    /// das Rot gehoert jetzt der Stoerung allein. 4,98:1 zur Karte, 25,5 von ``alarm``.
    public static let netzBezug = Farbwert(0xB48DF4)
    public static let netzEinspeisung = amberWeich
    /// Speicher: die Farbe des Diagramms. #4F7B88 stand nur 2,79:1 zur Karte.
    public static let batterie = mist

    /// Warmes Terrakotta statt Fastweiss: Weiss ist im Energiefluss dem Haus vorbehalten (Knoten
    /// der Summe). Deutlich abgesetzt von `amber` (PV) und von `alarm`, damit die Waermepumpe
    /// nicht wie eine Stoerung aussieht.
    public static let waermepumpe = Farbwert(0xE0966B)

    /// Pelletofen: die zweite Waermequelle am selben Puffer, steht also direkt neben
    /// `waermepumpe` und muss von ihm unterscheidbar sein. Der warme Bereich ist eng: gegen
    /// `waermepumpe`, `amber` und `alarm` gleichzeitig zu bestehen, gelingt nur hier. Geprueft auf
    /// `flaeche2`: ΔE 15,3 zu `waermepumpe`, 20,7 zu `amber`, 18,3 zu `batterie`, jeweils ueber
    /// der Schwelle von 15.
    ///
    /// **Zwei Auflagen.** Erstens liegt der Kontrast zur Flaeche bei 2,99:1 und damit knapp unter
    /// 3:1; die Farbe darf deshalb nie allein tragen, es gehoert immer eine sichtbare
    /// Beschriftung daneben. Zweitens ist der Abstand zu `alarm` und `netzBezug` nur ΔE 9,3: Ofen
    /// und Netzbezug duerfen nicht ohne Zweitkodierung in dieselbe Grafik.
    public static let ofen = Farbwert(0xB5651D)

    /// Der Hausverbrauch als Summe, nicht als Quelle - und das Heizen, denn es ist der Verlust
    /// der Huelle. Eigene Farbe, weil er in der Pruefansicht neben PV, Netz und Speicher steht;
    /// dort scheitert das Sandfarbene des Haushalts an der PV (ΔE 9,3). Geprueft: schlechtestes
    /// Paar dieser vier ΔE 18,5 normal / 15,1 CVD. Entspricht `house` in palette.ts.
    public static let haus = Farbwert(0xCFD8DC)

    /// Das Warmwasser im gestapelten Waermebedarf. Das Heizen nimmt die Farbe des Hauses, das
    /// Warmwasser bekommt sein eigenes Blau: ΔE 21,9 normal / 18,1 protan gegen `flaeche2`. Es
    /// ist das einzige **gestapelte** Paar der Fahrplanseite und damit das einzige, an dem diese
    /// Liste streng sein muss. Entspricht `dhw` in palette.ts.
    public static let warmwasser = Farbwert(0x4AA3C7)

    /// Der Pufferinhalt: eine einzelne Linie in einer eigenen Flaeche. Ihr naechster Nachbar auf
    /// der Fahrplanseite ist der Strompreis drei Flaechen hoeher, ΔE 14,6 normal / 13,7 deutan -
    /// knapp unter der Grenze 15, die hier sonst gilt. Zulaessig, weil die beiden nie im selben
    /// Gitter stehen: eigene Achse in kWh, eigener Titel, eine Luecke dazwischen.
    /// Entspricht `puffer` in palette.ts.
    public static let puffer = Farbwert(0x8FBF6B)

    /// Wallbox: die Farbe des Diagramms. #5C8FA3 lag nur 7,5 vom Nebelgrau entfernt.
    public static let wallbox = Farbwert(0x2F89B5)
    public static let preis = mist
    public static let last = Farbwert(0xFFFFFF, deckung: 0.62)

    /// Die Hauslinie der Tageskurve: die Linie, gegen die man die Sonne liest.
    ///
    /// `rgba(255,255,255,.88)` (`DayCurve.tsx:127`; `:146` nennt dieselbe Farbe in der
    /// Legende). **Nicht ``last`` (Weiss auf 0,62)** - auf 0,62 verschwand die Linie hinter der
    /// Sonnenfläche, und in der Legende stand ein Strich, den man im Bild nicht wiederfand.
    /// Und nicht ``text1`` mit anderer Deckung, wie die App sie bisher rechnete: `text1` ist
    /// die Schriftfarbe erster Stufe, und wer die hebt oder senkt, soll damit nicht eine
    /// Diagrammlinie verstellen.
    public static let hauslinie = papier.mitDeckung(0.88)

    // MARK: - Status

    public static let gut = mist
    public static let achtung = amber
    public static let alarm = Farbwert(0xE0533D)
    /// Alarm als Schrift (`tokens.css`, `--alert-text`). ``alarm`` traegt Flaechen, Marken und
    /// grosse Zahlen; als kleine Schrift lag es ueberall unter 4,5:1 (3,70 auf Flaeche 1, 3,38
    /// auf Flaeche 2). Dieses hellere Rot liegt bei 5,31 und 4,85. Es steht naeher am Terrakotta
    /// der Waermepumpe und ist deshalb nur fuer Text gedacht, nie fuer eine Reihe oder Flaeche.
    public static let alarmText = Farbwert(0xFF7266)

    // MARK: - Thermische Skala

    /// Abweichung vom Raumsollwert, fuenfstufig und zweiseitig. Null ist nicht farblos, sondern
    /// gedeckt: ein Raum auf Sollwert soll als Zustand zu sehen sein, nicht als Luecke. Die
    /// Nachbarstufen liegen in ihrer Helligkeit ueber der Unterscheidungsschwelle, und die beiden
    /// Enden sind auch ohne Farbwahrnehmung zu trennen.
    public static let abwKalt2 = Farbwert(0x6FD0F2)
    public static let abwKalt1 = Farbwert(0x3F88A8)
    public static let abwNull = Farbwert(0x3A5560)
    public static let abwWarm1 = Farbwert(0xA8781F)
    public static let abwWarm2 = Farbwert(0xFFC247)

    /// Ein offenes Ventil. Nicht amber: die Farbe steht in dieser Anwendung fuer Preis und Sonne,
    /// und ein offener Heizkreis ist weder das eine noch das andere.
    public static let ventilOffen = Farbwert(0xCFD8DC)

    // MARK: - Die Farben der Diagramme
    //
    // **Warum sie nicht die des Flussbilds sind.** Im Fluss steht jede Groesse fuer sich, in
    // einem gestapelten Balken stehen drei uebereinander - und was uebereinander liegt, muss
    // sich unterscheiden lassen. `charts/palette.ts` hat das durchgerechnet (CIEDE2000, normal
    // und bei Farbfehlsichtigkeit).
    //
    // **Seit dem 24.11.2026 sind Netz, Wallbox und Speicher hier dieselben Farben wie im Fluss.**
    // Die drei Namen bleiben, weil die Diagramme sie benutzen; sie zeigen auf die eine Marke der
    // Sache. Wer eine davon aendert, aendert sie fuer Fluss und Diagramm zugleich, und so soll
    // es sein.

    /// Netzbezug im Diagramm: ``netzBezug``.
    public static let diagrammNetz = netzBezug
    /// Wallbox im Diagramm: ``wallbox``.
    public static let diagrammWallbox = wallbox
    /// Speicher im Diagramm: ``batterie``.
    public static let diagrammSpeicher = batterie
    /// Der Haushalt ohne Waermepumpe und Wallbox.
    ///
    /// Hell und nicht sandfarben: neben dem Orange der Waermepumpe waere Sand bei Deuteranopie
    /// dieselbe Farbe (Abstand 0,2).
    public static let diagrammHaushalt = Farbwert(0xCFD8DC)

    // MARK: Die beiden Reihen des Rechnungsbetrags

    /// Die Grundgebühr im gestapelten Balken „Rechnungsbetrag“.
    ///
    /// **Eigener Name, obwohl `abdeckungTeils` dieselbe Zahl trägt.** `C.base` ist #C2A86B
    /// (`charts/palette.ts:39`, dort als „Haushalt ohne Wärmepumpe und Wallbox“ geführt), und
    /// die Rechnungsseite nimmt denselben Sandton für die Grundgebühr
    /// (`reports/charts.ts:300`). Derselbe Hexwert heißt in dieser Liste schon einmal etwas
    /// anderes - der Sandton der Mitte der Abdeckungsrampe. Wer den einen verschiebt, soll
    /// nicht den anderen mitverschieben: eine Farbe gehört zur Sache, die sie bezeichnet.
    public static let grundgebuehr = Farbwert(0xC2A86B)

    /// Die Mehrwertsteuer im selben Balken: `C.export`, `rgba(228,236,239,.5)`
    /// (`charts/palette.ts:44`, dort die Einspeisung der PV-Berichte;
    /// `reports/charts.ts:301`).
    ///
    /// **Die halbe Deckung ist der Wert und kein Zufall.** Der oberste Abschnitt des Stapels
    /// ist die Steuer, und ein fast weißer, deckender Block zöge den Blick auf das, was am
    /// wenigsten zu entscheiden ist. #E4ECEF steht in dieser Liste auch als oberster Stopp
    /// von `rampeNetz`; dort ist es die Spitze einer Helligkeitsrampe und hier eine
    /// Serienfarbe - zwei Sachen, zwei Namen.
    public static let umsatzsteuer = Farbwert(0xE4ECEF, deckung: 0.5)

    /// Die Sonne eines anderen Tages: hinter heute liegt gestern.
    ///
    /// Dieselbe Familie wie `pv`, nur dunkler - nach dem Maßstab der übrigen Farben zu nah.
    /// **Hier ist das der Sinn:** es ist dieselbe Größe an einem anderen Tag, und wer die
    /// beiden für verwandt hält, hat richtig gelesen. Unterschieden werden sie an der Form
    /// (keine Fläche, dünner, hinter allem) und in der Legende, die den Tag nennt
    /// (`charts/palette.ts`, `pvSchatten`).
    public static let pvSchatten = Farbwert(0xC8902F)

    /// Die vier Schichten des Puffers, warm nach kuehl - wie die Schichtung selbst.
    ///
    /// **Keine vier Kategorienfarben, sondern eine Folge.** Die Linien liegen fast immer in
    /// ihrer Reihenfolge uebereinander; eine Folge liest man als eine Sache in vier Hoehen,
    /// vier bunte Linien als vier Sachen. Der unterste Fuehler war im Dashboard einmal
    /// dunkelblau und hob sich mit 1,41:1 kaum von der Karte ab; jetzt halten alle vier
    /// mindestens 3:1 (gemessen 10.11.2026). Entspricht den vier Farben in
    /// `apps/web/src/components/reports/charts.ts`, Funktion `bufferChart`.
    public static let pufferschichten: [Farbwert] = [
        amber, amberWeich, mist, Farbwert(0x2F89B5),
    ]

    /// Die Waermeskala der Jahreskarte und des Puffers, kalt nach heiss.
    public static let waerme: [Farbwert] = [
        Farbwert(0x1F4C66), Farbwert(0x7FA3B3), Farbwert(0xFFD778), Farbwert(0xF2A900), Farbwert(0xE0533D),
    ]

    /// Die Stützstellen der Wassertemperatur, in Grad.
    ///
    /// **Dieselben wie im Dashboard** (`anlage/schema.ts`, `STOPS`) – und das war nicht so.
    /// Die Farben stimmten, die Temperaturen daneben nicht: ich hatte `7FA3B3` auf 40 °C und
    /// `FFD778` auf 50 °C gelegt statt auf 35 und 45. Bei den Temperaturen, die ein Puffer
    /// wirklich hat (um die 40 °C), landete damit alles im blassen Übergang zwischen den
    /// beiden – ein Glas in Creme statt in Gold. Dieselbe Skala in zwei Oberflächen muss
    /// dieselben Zahlen an denselben Stellen zeigen, sonst ist es nicht dieselbe Skala.
    public static let wasserstufen: [(grad: Double, farbe: Farbwert)] = [
        (10, Farbwert(0x1A3A52)), (25, Farbwert(0x1F4C66)), (35, Farbwert(0x7FA3B3)),
        (45, Farbwert(0xFFD778)), (55, Farbwert(0xF2A900)), (65, Farbwert(0xE0533D)),
    ]

    /// Die Farbe einer Wassertemperatur – für das Glas und für die Rohre.
    ///
    /// Zwischen den Stützstellen wird gemischt: ein Speicher hat keine Stufen. Ohne Wert
    /// kommt das neutrale Blaugrau der Skala, wie im Dashboard.
    public static func wasserfarbe(_ grad: Double?) -> Farbwert {
        guard let grad, grad.isFinite else { return Farbwert(0x7FA3B3) }
        guard let erste = wasserstufen.first, let letzte = wasserstufen.last else {
            return Farbwert(0x7FA3B3)
        }
        if grad <= erste.grad { return erste.farbe }
        if grad >= letzte.grad { return letzte.farbe }
        for i in 1..<wasserstufen.count where grad <= wasserstufen[i].grad {
            let (g0, f0) = wasserstufen[i - 1]
            let (g1, f1) = wasserstufen[i]
            let t = (grad - g0) / (g1 - g0)
            return Farbwert(
                rot: f0.rot + (f1.rot - f0.rot) * t,
                gruen: f0.gruen + (f1.gruen - f0.gruen) * t,
                blau: f0.blau + (f1.blau - f0.blau) * t
            )
        }
        return letzte.farbe
    }

    // MARK: - Die Nachbetrachtung: Treppe und Streifen

    /// Der Balken einer Treppenstufe in der Kostentreppe.
    ///
    /// `rgba(255,255,255,.62)` (`Kostentreppe.tsx:29`, der Zweig `s.art === "stufe"`).
    /// Dieselbe Zahl wie ``last`` und doch ein eigener Name: ``last`` ist die Hauslast im
    /// Flussbild, diese Farbe ist der Weg von einer Zahl zur nächsten. Wer die Hauslast
    /// verschiebt, soll nicht die Kostentreppe mitverschieben.
    public static let stufenbalken = papier.mitDeckung(0.62)

    /// Die Helligkeitsstufe null eines Streifens im Tagesvergleich.
    ///
    /// `rgba(255,255,255,.07)` (`Tagesvergleich.tsx:156`). **Stufe null ist eine Aussage und
    /// keine Lücke:** die Linie sagt „aus“, und das muss sich von „sagt nichts“ unterscheiden,
    /// das leer bleibt. Darum ein schwacher Grund und nicht gar keiner - und darum eine eigene
    /// Marke, denn die übrigen Stufen desselben Streifens sind ``waermepumpe`` mit Deckung.
    public static let stufeNull = papier.mitDeckung(0.07)

    // MARK: - Die Rampe der Verfügbarkeit

    /// Die drei Stopps der Abdeckungskarte: rot, sandfarben, ruhiges Blaugrau.
    ///
    /// **Sie läuft absichtlich herum.** Üblich wäre grün für „alles da“; hier ist das ruhige
    /// Ende blaugrau und das laute Ende rot, denn eine Karte ohne Lücken soll langweilig
    /// aussehen (`rooms/../CoverageMap.tsx:32`). Wer darauf sieht, sucht die roten Spalten -
    /// und eine Wand aus Grün hätte dieselbe Aufmerksamkeit verlangt wie eine aus Rot.
    public static let abdeckungFehlend = alarm
    /// Der Sandton der Mitte. Er steht zwischen Rot und Blaugrau und ist von beiden auch ohne
    /// Farbwahrnehmung durch seine Helligkeit zu trennen.
    public static let abdeckungTeils = Farbwert(0xC2A86B)
    public static let abdeckungVoll = mist

    /// Die drei Stufen in der Reihenfolge der Rampe.
    public static let abdeckung: [Farbwert] = [
        abdeckungFehlend, abdeckungTeils, abdeckungVoll,
    ]

    /// Die Farbe zu einem Anteil der Rampe, 0 bis 1 - zwischen den Stopps gemischt.
    ///
    /// **Die Karte hat keine Stufen.** In der Vorlage ist die Skala stetig (`charts.ts:517-536`,
    /// `visualMap` mit `type: "continuous"` ueber genau diese drei Farben), und das ist der
    /// Punkt: eine Stunde mit 55 von 60 Minuten soll anders aussehen als eine mit 48. Drei
    /// Stufen machten aus beiden dasselbe Feld. `Abdeckungsstufe` bleibt daneben stehen - sie
    /// benennt die drei Stopps fuer die Lesehilfe, und benennen kann man nur Stufen.
    public static func abdeckungsfarbe(anteil: Double) -> Farbwert {
        rampenfarbe(abdeckung, anteil: anteil)
    }

    // MARK: - Rampen allgemein

    /// Die Farbe an einer Stelle einer Rampe, `anteil` 0 bis 1 - zwischen den Stopps gemischt.
    ///
    /// **Eine Rechnung für alle Rampen.** Die Abdeckungskarte hatte sie zuerst; die Jahreskarte
    /// braucht dieselbe über vier andere Stopplisten (`charts.ts:409-412`), und zwei Kopien
    /// derselben Mischung wären zwei Stellen, an denen die Skala auseinanderläuft. Werte
    /// ausserhalb von 0 bis 1 werden beschnitten, ein Unwert gibt den ersten Stopp: eine
    /// erfundene Farbe wäre schlimmer als eine stumme.
    public static func rampenfarbe(_ rampe: [Farbwert], anteil: Double) -> Farbwert {
        guard let erste = rampe.first, let letzte = rampe.last else { return text3 }
        guard anteil.isFinite else { return erste }
        let lage = min(1, max(0, anteil)) * Double(rampe.count - 1)
        if lage <= 0 { return erste }
        if lage >= Double(rampe.count - 1) { return letzte }
        let unten = Int(lage)
        return rampe[unten].gemischt(mit: rampe[unten + 1], anteil: lage - Double(unten))
    }

    // MARK: - Die Rampen der Jahreskarte

    /// **In OKLab zwischen Markenfarben gerechnet, nicht von Hand gewählt** - so steigt die
    /// wahrgenommene Helligkeit gleichmässig, und nur so liest sich „mehr“ als „heller“
    /// (`charts.ts:400-412`). Die Werte sind darum aus der Vorlage übernommen und nicht hier
    /// neu bestimmt: dieselbe Skala in zwei Oberflächen muss dieselben Farben an denselben
    /// Stellen zeigen.
    ///
    /// Der dunkelste Schritt jeder einfarbigen Rampe ist die Kartenfläche selbst (`#123544`),
    /// damit „fast nichts“ mit dem Grund verschmilzt. Die Zuordnung ist die des Energieflusses:
    /// Bernstein ist eigene Energie, Mist das Netz, Terrakotta die Wärmepumpe.
    public static let rampeEigen: [Farbwert] = [
        Farbwert(0x123544), Farbwert(0x6A6448), Farbwert(0xC39234),
        Farbwert(0xF5B22E), Farbwert(0xFAC558), Farbwert(0xFFD778),
    ]

    /// Das Netz: von der Kartenfläche bis fast ins Weisse.
    public static let rampeNetz: [Farbwert] = [
        Farbwert(0x123544), Farbwert(0x3C5F6E), Farbwert(0x688C9B),
        Farbwert(0x93B1BF), Farbwert(0xBBCED7), Farbwert(0xE4ECEF),
    ]

    /// Die Wärmepumpe in Terrakotta.
    public static let rampeWaerme: [Farbwert] = [
        Farbwert(0x123544), Farbwert(0x655C57), Farbwert(0xB68365),
        Farbwert(0xE5A17A), Farbwert(0xEEB797), Farbwert(0xF6CDB4),
    ]

    /// Die Netzbilanz, divergierend: Einspeisung (Bernstein) über eine flächennahe Mitte zum
    /// Bezug (Mist).
    ///
    /// **Beide Pole gleich hell, sonst schrie eine Seite lauter als die andere**
    /// (`charts.ts:405-407`). Die Mitte ist der Kartenfläche nah, damit eine Stunde um null
    /// nicht als Ereignis gelesen wird. Sieben Stopps, damit die Mitte wirklich in der Mitte
    /// liegt.
    public static let rampeNetzBilanz: [Farbwert] = [
        Farbwert(0xF2A900), Farbwert(0xAC833B), Farbwert(0x695F44), Farbwert(0x2B3A41),
        Farbwert(0x4C646E), Farbwert(0x70909F), Farbwert(0x96C0D3),
    ]

    /// Die fuenf Stufen der Abweichung, kalt nach warm.
    public static let abweichung: [Farbwert] = [abwKalt2, abwKalt1, abwNull, abwWarm1, abwWarm2]

    /// Die Farbe zu einer Abweichung in Kelvin. Die Schwellen sind dieselben wie im Dashboard.
    public static func abweichungsfarbe(kelvin: Double?) -> Farbwert {
        // **Ohne Wert gibt es keine Farbe.** Hier stand `abwNull` - ein stummer Fuehler sah
        // damit aus wie ein Raum, der genau am Ziel steht. Das ist die unangenehmste Sorte
        // Falschaussage: sie beruhigt. Wer keinen Wert hat, zeichnet eine Schraffur und ruft
        // diese Funktion gar nicht.
        guard let k = kelvin, k.isFinite else { return abwNull }
        // Die Grenzen sind die des Dashboards (`rooms/palette.ts`); sie stehen in
        // `Raumabweichung.stufe` und werden hier nur nachgeschlagen.
        return abweichung[Raumabweichung.stufe(k)]
    }

    // MARK: - Das Akzentband der Karte

    /// Der Verlauf des Akzentbalkens oben an einer Karte, drei Stopps.
    ///
    /// `--accent-bar: linear-gradient(90deg, var(--amber), var(--amber-soft), transparent 86%)`
    /// (`tokens.css:98`). **Die mittlere Stelle steht hier und bleibt nicht ungenannt:** ein
    /// Stopp ohne eigene Stelle liegt in CSS mittig zwischen seinen Nachbarn, also bei 43 % -
    /// wer das im Kopf behalten muss, rechnet es beim nächsten Mal anders.
    ///
    /// **Ausgeblendet wird in durchsichtiges Bernstein und nicht in Schwarz.** CSS
    /// `transparent` ist durchsichtiges Schwarz; der Browser mischt vormultipliziert und kommt
    /// damit ohne Grau durch die Mitte. SwiftUI tut das nicht, und ein Verlauf nach
    /// `Color.clear` wird dort grau. Der letzte Stopp trägt deshalb dieselbe Farbe mit Deckung
    /// null.
    public static let akzentband: [(farbe: Farbwert, stelle: Double)] = [
        (amber, 0.0), (amberWeich, 0.43), (amberWeich.mitDeckung(0), 0.86),
    ]

    // MARK: - Die Wache

    /// Die Deckung, auf der der Grund einer Wachzeile steht.
    ///
    /// `globals.css:205-206` färbt Kante, Zeichen und Grund nach der Schwere: `--alert` auf
    /// `rgba(224,83,61,.10)` beim Alarm, `--amber-soft` auf `rgba(255,215,120,.10)` bei einer
    /// Warnung. Es ist jedes Mal dieselbe Farbe, einmal voll und einmal auf einem Zehntel.
    public static let wachgrundDeckung: Double = 0.10

    /// Kante und Grund einer Wachzeile zu ihrer Schwerefarbe.
    ///
    /// **Ein Paar und nicht zwei Werte.** Die Zehn-Prozent-Rechnung stand in der Wache selbst;
    /// sie gilt aber für jede Schwere und für jede, die noch dazukommt. Wer die Wache leiser
    /// oder lauter machen will, ändert hier eine Zahl und nicht drei Fälle - und sieht an
    /// dieser Stelle, dass Kante und Grund zusammengehören.
    public static func wachzeile(_ schwere: Farbwert) -> (kante: Farbwert, grund: Farbwert) {
        (schwere, schwere.mitDeckung(wachgrundDeckung))
    }

    // MARK: - Form

    public static let radius1: Double = 2
    public static let radius2: Double = 3
    public static let radius3: Double = 6

    /// Der Fokusring eines Eingabefeldes: Stärke und Farbe.
    ///
    /// `--focus-ring: 0 0 0 6px rgba(242, 169, 0, 0.12)` (`tokens.css:97`) - kein
    /// Weichzeichner, sechs Punkte Stärke, ausserhalb des Randes. **Die beiden Zahlen gehören
    /// zusammen und darum in einen Wert:** ein Ring von sechs Punkten trägt nur bei dieser
    /// schwachen Deckung, und diese Deckung ist bei einem Punkt Stärke nicht mehr zu sehen.
    /// Getrennt stehen sie in zwei Seiten und laufen auseinander.
    public static let fokusring: (staerke: Double, farbe: Farbwert) = (6, amber.mitDeckung(0.12))

    /// Die Lesebreite eines Fliesstextes, in Punkten.
    ///
    /// `max-w-[90ch]` (`ReportShell.tsx:143-145`), und die Vorlage begründet es an derselben
    /// Stelle selbst: über die volle Breite eines 1440er Schirms geriet die Methodenangabe auf
    /// gut 200 Zeichen je Zeile, und beim Zeilenwechsel findet das Auge den Anfang der nächsten
    /// Zeile nicht wieder.
    ///
    /// **Nachgerechnet und nicht geschätzt.** `1ch` ist die Vorschubbreite der Null, und die
    /// ist in IBM Plex Sans 600 von 1000 Einheiten (nachgemessen in
    /// `Ressourcen/Marke/IBMPlexSans-Regular.otf`). Bei den 11,5 Punkten des Hinweisabsatzes
    /// sind 90 Zeichen also 90 × 0,6 × 11,5 = 621 Punkte. Zwei Seiten trugen dafür je eine
    /// eigene 560 - rund zehn Prozent zu schmal, und zweimal dieselbe Zahl von Hand.
    public static let lesebreite: Double = 621

    // MARK: - Bewegung

    /// Die Dauer eines Uebergangs. Im Dashboard 0,18 s.
    public static let dauer: Double = 0.18
}

/// Eine Farbe als Zahl, ohne SwiftUI: Rot, Gruen, Blau und Deckung, jeweils 0 bis 1.
public struct Farbwert: Sendable, Hashable {
    public var rot: Double
    public var gruen: Double
    public var blau: Double
    public var deckung: Double

    public init(rot: Double, gruen: Double, blau: Double, deckung: Double = 1) {
        self.rot = rot
        self.gruen = gruen
        self.blau = blau
        self.deckung = deckung
    }

    /// Aus `0xF2A900`.
    public init(_ hex: UInt32, deckung: Double = 1) {
        self.rot = Double((hex >> 16) & 0xFF) / 255
        self.gruen = Double((hex >> 8) & 0xFF) / 255
        self.blau = Double(hex & 0xFF) / 255
        self.deckung = deckung
    }

    /// `#F2A900` - fuer Beschriftungen, die als Text aus dem Kern kommen.
    public var hex: String {
        String(format: "#%02X%02X%02X", Int((rot * 255).rounded()), Int((gruen * 255).rounded()), Int((blau * 255).rounded()))
    }

    /// Dieselbe Farbe mit anderer Deckung.
    public func mitDeckung(_ d: Double) -> Farbwert {
        Farbwert(rot: rot, gruen: gruen, blau: blau, deckung: d)
    }

    /// Diese Farbe mit einer anderen gemischt: `anteil` 0 ist diese, 1 die andere.
    ///
    /// Gemischt wird kanalweise in sRGB - dasselbe, was `visualMap` in der Vorlage tut
    /// (`charts.ts:536`, `inRange: { color: ramp }`). Kein Lab, keine Gammakorrektur: eine
    /// andere Mischung ergaebe andere Zwischentoene als im Browser, und genau das soll sie
    /// nicht.
    public func gemischt(mit andere: Farbwert, anteil: Double) -> Farbwert {
        guard anteil.isFinite else { return self }
        let t = min(1, max(0, anteil))
        return Farbwert(
            rot: rot + (andere.rot - rot) * t,
            gruen: gruen + (andere.gruen - gruen) * t,
            blau: blau + (andere.blau - blau) * t,
            deckung: deckung + (andere.deckung - deckung) * t)
    }

    // MARK: - Pruefung der Palette

    /// Relative Leuchtdichte nach WCAG.
    public var leuchtdichte: Double {
        func kanal(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * kanal(rot) + 0.7152 * kanal(gruen) + 0.0722 * kanal(blau)
    }

    /// Kontrastverhaeltnis zu einer anderen Farbe, 1 bis 21.
    public func kontrast(zu andere: Farbwert) -> Double {
        let a = leuchtdichte
        let b = andere.leuchtdichte
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// CIE Lab, Bezugsweiss D65 - die Grundlage fuer den Farbabstand.
    public var lab: (l: Double, a: Double, b: Double) {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linear(rot), g = linear(gruen), bl = linear(blau)
        let x = (r * 0.4124564 + g * 0.3575761 + bl * 0.1804375) / 0.95047
        let y = r * 0.2126729 + g * 0.7151522 + bl * 0.0721750
        let z = (r * 0.0193339 + g * 0.1191920 + bl * 0.9503041) / 1.08883
        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0 / 3.0) : (7.787 * t) + 16.0 / 116.0
        }
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    /// Der Farbabstand ΔE76 - die alte, einfache Formel: der Abstand zweier Punkte im Lab-Raum.
    ///
    /// Sie ueberschaetzt den Unterschied bei gesaettigten Farben erheblich. Fuer die Palette ist
    /// `abstand(zu:)` (ΔE2000) zustaendig; diese Formel steht hier, weil sie sich von Hand
    /// nachrechnen laesst und damit die Probe auf die Lab-Umrechnung ist.
    public func abstand76(zu andere: Farbwert) -> Double {
        let a = lab
        let b = andere.lab
        return sqrt(pow(a.l - b.l, 2) + pow(a.a - b.a, 2) + pow(a.b - b.b, 2))
    }

    /// Der Farbabstand ΔE2000 (CIEDE2000) zu einer anderen Farbe.
    ///
    /// Das ist das Mass, das die Anleitung der Datenvisualisierung meint, wenn sie 15 als
    /// Schwelle fuer Serienfarben nennt, die nebeneinander stehen. Der Unterschied zur alten
    /// Formel ist nicht klein: `ofen` gegen `waermepumpe` sind nach ΔE76 fast 25 Punkte und nach
    /// ΔE2000 knapp 17 - die alte Formel haelt fuer sicher unterscheidbar, was es kaum ist.
    ///
    /// Die Umsetzung folgt der Veroeffentlichung von Sharma, Wu und Dalal (2005), samt der
    /// Rotationskorrektur im Blaubereich, an der die meisten Kurzfassungen scheitern.
    public func abstand(zu andere: Farbwert) -> Double {
        let (l1, a1, b1) = lab
        let (l2, a2, b2) = andere.lab

        let c1 = sqrt(a1 * a1 + b1 * b1)
        let c2 = sqrt(a2 * a2 + b2 * b2)
        let cMittel = (c1 + c2) / 2
        let c7 = pow(cMittel, 7)
        let g = cMittel > 0 ? 0.5 * (1 - sqrt(c7 / (c7 + pow(25, 7)))) : 0

        let a1s = (1 + g) * a1
        let a2s = (1 + g) * a2
        let c1s = sqrt(a1s * a1s + b1 * b1)
        let c2s = sqrt(a2s * a2s + b2 * b2)

        func winkel(_ a: Double, _ b: Double) -> Double {
            if a == 0, b == 0 { return 0 }
            let w = atan2(b, a) * 180 / .pi
            return w < 0 ? w + 360 : w
        }
        let h1s = winkel(a1s, b1)
        let h2s = winkel(a2s, b2)

        let dL = l2 - l1
        let dC = c2s - c1s

        var dh: Double = 0
        if c1s * c2s != 0 {
            let roh = h2s - h1s
            if abs(roh) <= 180 {
                dh = roh
            } else if roh > 180 {
                dh = roh - 360
            } else {
                dh = roh + 360
            }
        }
        let dH = 2 * sqrt(c1s * c2s) * sin(dh * .pi / 360)

        let lMittel = (l1 + l2) / 2
        let cMittelS = (c1s + c2s) / 2

        var hMittel: Double = 0
        if c1s * c2s == 0 {
            hMittel = h1s + h2s
        } else if abs(h1s - h2s) <= 180 {
            hMittel = (h1s + h2s) / 2
        } else if h1s + h2s < 360 {
            hMittel = (h1s + h2s + 360) / 2
        } else {
            hMittel = (h1s + h2s - 360) / 2
        }

        func grad(_ w: Double) -> Double { cos(w * .pi / 180) }
        let t = 1 - 0.17 * grad(hMittel - 30) + 0.24 * grad(2 * hMittel)
            + 0.32 * grad(3 * hMittel + 6) - 0.20 * grad(4 * hMittel - 63)

        let dTheta = 30 * exp(-pow((hMittel - 275) / 25, 2))
        let cs7 = pow(cMittelS, 7)
        let rC = cMittelS > 0 ? 2 * sqrt(cs7 / (cs7 + pow(25, 7))) : 0
        let sL = 1 + (0.015 * pow(lMittel - 50, 2)) / sqrt(20 + pow(lMittel - 50, 2))
        let sC = 1 + 0.045 * cMittelS
        let sH = 1 + 0.015 * cMittelS * t
        let rT = -sin(2 * dTheta * .pi / 180) * rC

        return sqrt(
            pow(dL / sL, 2) + pow(dC / sC, 2) + pow(dH / sH, 2)
                + rT * (dC / sC) * (dH / sH)
        )
    }
}
