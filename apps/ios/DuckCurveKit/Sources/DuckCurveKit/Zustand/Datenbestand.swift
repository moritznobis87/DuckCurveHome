import Foundation

/// Womit die Datenbank ihren Platz füllt - die Zeilen und Zustände der Platzbedarfstabelle.
///
/// **Warum das im Kern steht und nicht in der Seite.** Die Vorlage
/// (`apps/web/src/components/settings/StorageReport.tsx:30-83`) trifft hier vier Entscheidungen,
/// und jede davon ist eine Rechnung: welche Tabellen überhaupt dastehen (`:45`, Filter
/// `total_bytes > 0` und höchstens acht), in welcher Form jede Zahl geschrieben wird (`:21-28`),
/// welcher von drei Zuständen gilt (`:41-43`) und was in der Schlusszeile steht (`:71-77`).
/// In einer `View` wäre keine davon prüfbar - und genau dort stand sie bis jetzt, auf der
/// Datenseite (`DuckCurveHome/Seiten/Technik/DatenSeite.swift`), ohne Filter und ohne
/// Obergrenze.
///
/// **Die Obergrenze ist keine Schönheit.** `measurements_raw` und `measurements_minute` sind in
/// jedem Haus die beiden größten Posten; dahinter folgen zwanzig Tabellen mit ein paar Kilobyte,
/// die die Frage „welche Tabelle ist das?“ nicht beantworten, sondern verdecken. Acht Zeilen
/// zeigen den Kopf der Rangliste, und die Schlusszeile nennt die Summe aller - auch der
/// weggelassenen.
public enum Datenbestand {

    /// Wie viele Tabellen höchstens dastehen (`StorageReport.tsx:45`: `.slice(0, 8)`).
    public static let hoechstens = 8

    /// Die Schlusszeile unter der Tabelle (`StorageReport.tsx:72`).
    ///
    /// **Eine Zeile und kein Kartentitel.** Die Datenseite trug diese Summe bisher im Titel
    /// ihrer Karte - dort steht sie neben dem Namen des Abschnitts und liest sich wie seine
    /// Überschrift. In der Vorlage steht sie unter der letzten Tabelle, in derselben Spalte wie
    /// die Einzelsummen, und *das* ist ihre Aussage: so viel ist es zusammen, und so viel davon
    /// ist die größte Tabelle.
    public static let summenwort = "alle Tabellen"

    /// Was dasteht, wenn die Abfrage scheitert (`StorageReport.tsx:41`).
    public static let fehlerwort = "Die Größen konnten nicht abgefragt werden."

    /// Was dasteht, solange die Antwort unterwegs ist (`StorageReport.tsx:42`).
    public static let ladewort = "lädt …"

    /// Die Spalten in der Reihenfolge der Vorlage (`StorageReport.tsx:52-56`).
    ///
    /// **„Indizes“ steht eigens, und das ist der Grund für die ganze Tabelle.** Die Vorlage
    /// begründet es an `StorageReport.tsx:65-66`: „bei schmalen Zeilen sind sie oft der größere
    /// Posten, und das sieht man nur, wenn es getrennt dasteht.“ Eine Tabelle mit nur einer
    /// Gesamtspalte beantwortete die Frage nicht, zu der sie da ist.
    ///
    /// Die Reihenfolge ist die der Vorlage und nicht die der Datenseite („gesamt“ zuerst):
    /// gelesen wird von den Teilen zur Summe, und die Summe trägt deshalb die Farbe.
    public static let spalten = ["Zeilen", "Daten", "Indizes", "gesamt"]

    /// Eine Zeile der Tabelle, fertig geschrieben.
    ///
    /// Zeichenketten und keine Zahlen: welche Form eine Zahl hier bekommt, ist Teil der
    /// Entscheidung (``Formate/megabyte(_:)`` binär, ``Formate/zeilen(_:)`` ab tausend
    /// abgekürzt), und sie soll an einer Stelle fallen und nicht in jeder Seite neu.
    public struct Posten: Sendable, Hashable {
        /// Der Name der Tabelle, wie der Dienst ihn nennt - `measurements_raw`.
        public let name: String
        /// Die geschätzte Zeilenzahl, „1.235 Tsd.“.
        public let zeilen: String
        /// Die Daten ohne Indizes.
        public let daten: String
        /// Die Indizes allein.
        public let indizes: String
        /// Daten und Indizes zusammen - die Spalte, die in ``Marken/amber`` steht.
        public let gesamt: String

        public init(name: String, zeilen: String, daten: String, indizes: String, gesamt: String) {
            self.name = name
            self.zeilen = zeilen
            self.daten = daten
            self.indizes = indizes
            self.gesamt = gesamt
        }

        /// Die vier Zahlen in der Reihenfolge von ``Datenbestand/spalten``.
        public var zellen: [String] { [zeilen, daten, indizes, gesamt] }
    }

    /// Welcher der vier Zustände gilt - in der Reihenfolge, in der die Vorlage sie prüft.
    ///
    /// **Die Reihenfolge ist die Aussage.** `StorageReport.tsx:41-43` fragt zuerst nach dem
    /// Fehler, dann nach der fehlenden Antwort, dann nach der leeren Liste. Wer zuerst auf
    /// „noch nichts da“ prüft, zeigt nach einem Fehlschlag für immer „lädt …“ - und das ist der
    /// Zustand, in dem eine Wandanzeige am längsten steht, ohne dass es jemandem auffällt.
    public enum Stand: Sendable, Hashable {
        /// Die Abfrage ist gescheitert; der Satz ist ``Datenbestand/fehlerwort``.
        case fehler(String)
        /// Die Antwort ist unterwegs; das Wort ist ``Datenbestand/ladewort``.
        case laedt
        /// Der Dienst meldet keine Tabellen - dann steht sein eigener Satz da (`note_de`).
        case leer(String)
        /// Die Tabelle, schon gefiltert und beschnitten.
        case tabelle([Posten])
    }

    /// Die Zeilen der Tabelle: leere weg, höchstens acht, Reihenfolge wie geliefert.
    ///
    /// **Sortiert wird nicht.** Die Vorlage sortiert auch nicht (`StorageReport.tsx:45`: nur
    /// `filter` und `slice`) - der Dienst liefert nach Größe absteigend, und eine zweite
    /// Sortierung hier würde eine andere Reihenfolge erzeugen, sobald er seine einmal ändert.
    /// Dann stünde in der App eine andere Rangliste als an der Wand.
    public static func posten(_ bericht: StorageReportOut) -> [Posten] {
        bericht.tables
            .filter { $0.totalBytes > 0 }
            .prefix(hoechstens)
            .map { t in
                Posten(
                    name: t.name,
                    zeilen: Formate.zeilen(t.rowsEstimate),
                    daten: Formate.megabyte(t.tableBytes),
                    indizes: Formate.megabyte(t.indexBytes),
                    gesamt: Formate.megabyte(t.totalBytes)
                )
            }
    }

    /// Die Summe über alle Tabellen - auch über die, die oben nicht dastehen.
    ///
    /// Genommen wird `total_bytes` des Berichts und nicht die Summe der acht gezeigten Zeilen:
    /// die Vorlage macht es so (`StorageReport.tsx:76`), und sie hat recht damit - gefragt ist
    /// der Platz der Datenbank, nicht der ihrer größten acht Tabellen.
    public static func gesamt(_ bericht: StorageReportOut) -> String {
        Formate.megabyte(bericht.totalBytes)
    }

    /// Wie lange Rohwerte liegen bleiben, als Satz für die Zeile darunter.
    ///
    /// Die Frist gehört in diesen Abschnitt, weil sie der einzige Regler ist, der von außen
    /// zu stellen ist (`StorageReport.tsx:14-18`): `measurements_raw` ist ein Durchlauferhitzer
    /// für die Verdichtung zu Minutenwerten, und was darüber hinaus liegen bleibt, ist Vorrat
    /// für einen Fall, der selten eintritt.
    public static func aufbewahrung(_ bericht: StorageReportOut) -> String {
        String(bericht.rawRetentionDays)
    }

    /// Welcher Zustand gilt. `fehlgeschlagen` ist wahr, sobald die Abfrage einen Fehler ergab.
    public static func stand(_ bericht: StorageReportOut?, fehlgeschlagen: Bool) -> Stand {
        if fehlgeschlagen { return .fehler(fehlerwort) }
        guard let bericht else { return .laedt }
        if bericht.tables.isEmpty { return .leer(bericht.noteDe) }
        return .tabelle(posten(bericht))
    }
}
