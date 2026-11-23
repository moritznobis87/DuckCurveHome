import Foundation

/// Der Hinweis auf der Startseite des Telefons: dieses Gerät bekommt noch keine Mitteilungen.
///
/// **Der Anlass steht wörtlich in der Vorlage** (`MitteilungsHinweis.tsx:11-14`, Nutzer am
/// 12.11.2026): „Ich bekomme gar keine Push-Nachrichten auf mein Handy. Da war doch ein Morning
/// Briefing geplant.“ Der Brief war eingeschaltet, aber jedes Gerät meldet sich einzeln an, und
/// die Stelle dafür liegt unter Technik. Wer das nicht weiß, wartet auf einen Brief, der an
/// niemanden geht.
///
/// **Warum die vier Bedingungen im Kern stehen.** Ob der Hinweis dasteht, hängt an vier Dingen
/// zugleich (`MitteilungsHinweis.tsx:36-56`): an der Rolle, an der Lage der Mitteilungen, am
/// Wegtippen und an der Breite des Schirms. Jede einzelne ist ein `if` in einer `View`, und alle
/// vier zusammen sind die Entscheidung, ob jemand einen Kasten auf seiner Startseite sieht.
/// Genau diese Entscheidung ging in der App bisher gar nicht ein - der Hinweis fehlte ganz.
///
/// **Die Fälle der Vorlage, die es hier nicht gibt.** `ios-browser` beschreibt einen Browser,
/// der auf den Home-Bildschirm gelegt werden muss; diese App *ist* die Home-Bildschirm-App.
/// Dieselbe Beschneidung begründet ``Mitteilungsstand/Lage``.
public enum Startseitenhinweis {

    /// Unter welchem Schlüssel das Wegtippen im Gerät steht (`MitteilungsHinweis.tsx:25`).
    ///
    /// Derselbe Name wie in der Vorlage, damit eine Fehlersuche an einem Haus beide Seiten
    /// unter demselben Wort findet.
    public static let merker = "dch-mitteilungen-hinweis"

    /// Ob der Hinweis dasteht.
    ///
    /// - Parameters:
    ///   - lage: wie es um die Mitteilungen auf diesem Gerät steht.
    ///   - istHausherr: die Seite dahinter ist die seine (`MitteilungsHinweis.tsx:40`).
    ///   - weggetippt: wer ihn wegtippt, will ihn nicht wiedersehen (`:50-54`).
    ///   - schmal: nur am Telefon (`Home.tsx:225`: `isMobile ? <MitteilungsHinweis /> : null`).
    ///
    /// **``Mitteilungsstand/Lage/verboten`` zeigt nichts**, und das ist Absicht: „Hat jemand
    /// Mitteilungen abgelehnt, steht nichts da: das war eine Entscheidung“
    /// (`MitteilungsHinweis.tsx:19-21`). ``Mitteilungsstand/Lage/halb`` und ``/fehler`` zeigen
    /// auch nichts - dort ist das Einschalten schon geschehen und nur die Anmeldung beim Dienst
    /// hängt; die Mitteilungsseite sagt dazu mehr, als eine Pille mit „Einschalten“ könnte.
    public static func zeigt(
        lage: Mitteilungsstand.Lage, istHausherr: Bool, weggetippt: Bool, schmal: Bool
    ) -> Bool {
        guard schmal, istHausherr, !weggetippt else { return false }
        return Mitteilungsstand.darfEinschalten(lage)
    }

    /// Was dasteht (`MitteilungsHinweis.tsx:78-79`).
    ///
    /// **Das Morning Briefing steht im Satz.** Ohne es wäre der Hinweis eine Einstellung;
    /// mit ihm ist er die Antwort auf die Frage, die der Nutzer gestellt hat.
    public static let satz =
        "Dieses Telefon bekommt noch keine Mitteilungen, auch nicht das Morning Briefing."

    /// Das Wort auf der Pille (`MitteilungsHinweis.tsx:84`).
    public static let losWort = "Einschalten"

    /// Und auf dem stillen Knopf daneben (`MitteilungsHinweis.tsx:85`).
    public static let zuWort = "Nicht jetzt"

    /// Wohin die Pille führt (`MitteilungsHinweis.tsx:84`).
    public static let weg = "/system/mitteilungen"
}
