import Foundation

/// Die festen Sätze der Fahrplanseite.
///
/// **Warum sie im Kern stehen.** Jede andere Seite holt ihren Methodentext aus einem
/// `*_de`-Feld des Dienstes; diese drei Absätze kommen von nirgends her - sie stehen in der
/// Vorlage im Quelltext (`apps/web/src/components/waerme/Fahrplan.tsx:650-661`). Irgendwo
/// müssen sie also wohnen, und im Kern sind sie geprüft, übersetzbar auf jedem Rechner und
/// nicht in einer Ansicht vergraben, die nur ein Mac lesen kann.
///
/// **Sie sagen, was die Zahlen *nicht* sind.** Das ist der Grund, warum sie nicht wegdürfen:
/// Der Wärmebedarf ist gerechnet und nicht gemessen, und links der Jetzt-Linie stehen zwei
/// verschiedene Dinge nebeneinander. Wer das nicht weiß, hält eine Abweichung für einen
/// Fehler.
public enum Fahrplanworte {

    /// Die Zeile, die im zugeklappten Zustand dasteht.
    public static let methodeKurz =
        "Preis und Sonne sind Prognosen, der Wärmebedarf ist ein Modell · links der "
        + "Jetzt-Linie stehen Messung und Regel nebeneinander"

    public static let methodeTitel = "Woher die Zahlen kommen"

    /// Die drei Absätze, wortgleich mit der Vorlage.
    public static let methode: [String] = [
        "Preis und PV-Erwartung sind Prognosen, der Wärmebedarf ist ein Modell: "
            + "Heizgradstunden gegen die Wettervorhersage plus ein Warmwasserprofil über den "
            + "Tag. Es ist derselbe Bedarf, gegen den der Optimierer rechnet, nicht ein "
            + "zweiter daneben. Gemessen wird er noch nicht; das kommt mit dem "
            + "Wärmemengenzähler über den eBUS-Anschluss. Der COP folgt aus der "
            + "Außentemperatur, noch nicht aus der Vorlauftemperatur, denn die liefert "
            + "bislang kein Fühler.",
        "Links der Jetzt-Linie stehen zwei verschiedene Dinge nebeneinander. Gemessen sind "
            + "die PV-Leistung, die Leistung der Wärmepumpe und die Anforderung an sie; sie "
            + "enden an der letzten abgeschlossenen Viertelstunde, denn die laufende ist erst "
            + "zum Teil vorbei und sähe aus wie ein Einbruch. Der geplante Zustand der "
            + "Wärmepumpe ist dort dagegen keine Erinnerung: der Optimierer rechnet ab jetzt, "
            + "für die vergangenen Stunden greift die Preisregel, also steht da, was sie "
            + "heute für diese Stunde sagen würde. Weicht der gemessene Kontakt davon ab, ist "
            + "das deshalb kein Widerspruch, sondern der Abstand zwischen zwei verschiedenen "
            + "Fragen.",
        "Was aus einem Fahrplan geworden ist, steht im Rückblick: dort liegt der aufbewahrte "
            + "Fahrplan von damals neben der Messung, in Euro. Wie gut die Prognosen waren, "
            + "steht unter System → Prognose. Noch nicht gebaut ist der Lernschritt, der das "
            + "Hüllenmodell aus den Prognosefehlern nachzieht.",
    ]

    /// Der Satz rechts im Kartenkopf der Entscheidungen.
    public static let entscheidungenDazu =
        "die teuersten und die billigsten Viertelstunden, mit Begründung"

    /// Was an der Stelle der Zeichnung steht, solange kein Plan gerechnet ist.
    public static let ohnePlan = "Noch kein Fahrplan gerechnet."

    /// Was in der Entscheidungskarte steht, solange keine Viertelstunde einen Preis hat.
    ///
    /// **Nicht derselbe Satz wie ``ohnePlan``.** Die Vorlage hält die beiden auseinander
    /// (`Fahrplan.tsx:595` gegen `:690`), und sie meinen Verschiedenes: Der Planer hat nicht
    /// gerechnet - oder er hat gerechnet und kennt für den Horizont keine Preise. Im zweiten
    /// Fall steht die Zeichnung vollständig da, nur die Tabelle bleibt leer.
    public static let ohnePreise = "Noch keine Preise im Horizont."
}
