import Foundation

/// Ein Absatz, in dem ein Wort mitten im Satz auf eine andere Seite der App führt.
///
/// **Warum dafür überhaupt eine Adresse gerechnet wird.** Die Vorlage schreibt den Verweis als
/// `<Link href="/waerme/bilanz">` mitten in den Satz (`waerme/annahmen/page.tsx:23`), und der
/// Absatz bricht um ihn herum um. SwiftUI hat dafür genau ein Mittel: ein `link`-Merkmal in einer
/// `AttributedString`, das der Absatz mitträgt und beim Antippen über `openURL` meldet. `openURL`
/// kennt aber nur `URL`, und ein Weg dieser App („/waerme/bilanz“) ist keine - ohne Schema
/// entsteht beim Zusammensetzen eine relative Adresse, die iOS an den Browser gibt, und dann
/// öffnet ein Tippen im Satz eine leere Seite im Safari.
///
/// Darum diese Übersetzung: Weg zu Adresse und zurück. Sie ist eine Rechnung über Zeichenketten,
/// steht deshalb hier und nicht in der Ansicht, und beide Richtungen stehen zusammen - eine
/// Adresse, die anders zusammengesetzt als zerlegt wird, ist genau der Fehler, der sich als
/// „ein Verweis, der nichts tut“ zeigt und an keiner Stelle sichtbar ist.
///
/// **Das Schema verlässt die App nicht.** Es ist in keiner `Info.plist` angemeldet und soll das
/// nicht sein: es lebt zwischen der `AttributedString` eines Absatzes und dem `OpenURLAction`,
/// der unmittelbar darüber liegt. Angemeldet wäre es eine Einladung von draußen.
public enum Verweisabsatz {
    /// Das Schema der hausinternen Adressen.
    ///
    /// Nicht `http`: dann griffe die Abfangung auch für die echten Verweise nach draußen, die
    /// `Annahmenfelder.Textstueck`-Absätze eines Tages tragen könnten.
    public static let schema = "duckcurve"

    /// Aus einem Weg der App die Adresse, die ein `link`-Merkmal tragen kann.
    ///
    /// Ein Weg ohne führenden Schrägstrich bekommt einen - `URLComponents` setzt sonst eine
    /// Adresse ohne Pfadwurzel zusammen, die ``weg(aus:)`` nicht wiedererkennt.
    public static func adresse(_ weg: String) -> URL? {
        var teile = URLComponents()
        teile.scheme = schema
        teile.path = weg.hasPrefix("/") ? weg : "/" + weg
        return teile.url
    }

    /// Der Weg zurück aus der Adresse - `nil`, wenn sie nicht von hier stammt.
    ///
    /// **`nil` ist die wichtigere Hälfte.** Der `OpenURLAction` eines Absatzes bekommt jede
    /// Adresse, die darin angetippt wird. Was nicht dieses Schema trägt, muss er an das System
    /// weitergeben und nicht als Weg der App deuten, sonst führt ein Tippen auf „duckcurve.de“
    /// in eine Seite, die es nicht gibt.
    public static func weg(aus adresse: URL) -> String? {
        guard adresse.scheme == schema else { return nil }
        let pfad = adresse.path
        guard pfad.hasPrefix("/") else { return nil }
        return pfad
    }
}
