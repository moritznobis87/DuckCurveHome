import Foundation

/// Die Worte der Anmeldung mit Passwort und des Abschnitts „Mein Passwort“.
///
/// Der Hausherr hat am 24.11.2026 entschieden, dass es neben dem Passkey ein Passwort gibt und
/// dass in der App dieselbe Anmeldelogik gilt wie im Dashboard. Die Sätze hier sind die des
/// Dashboards (`apps/web/src/app/anmeldung/passkey.tsx`,
/// `apps/web/src/components/zugang/MeinPasswort.tsx`), damit beide dasselbe sagen. Sie stehen im
/// Kern und nicht in der Ansicht, damit sich das auf dem Prüfrechner festhalten lässt.
public enum Anmeldeworte {
    // MARK: - Anmelden

    public static let emailfeld = "E-Mail-Adresse"
    public static let passwortfeld = "Passwort"
    public static let anmeldeknopf = "Mit Passwort anmelden"
    public static let prueft = "Prüfe…"

    /// Was dasteht, wenn der Dienst die Anmeldung ablehnt und keinen eigenen Satz mitgibt.
    public static let abgelehnt = "Die Anmeldung ist nicht möglich."

    /// Der Satz über den beiden Feldern beim Einrichten der App.
    public static let erklaerung =
        "Die App meldet sich wie das Dashboard als Person an, mit E-Mail-Adresse und Passwort. "
        + "Was du sehen und stellen darfst, richtet sich nach deiner Rolle im Haus."

    /// Für wen der zweite Weg beim Einrichten gedacht ist.
    public static let tokenerklaerung =
        "Mit dem API-Token aus DCH_API_TOKEN spricht die App als Gerät und nicht als Person. "
        + "Das Token darf am Dienst alles; es ist der Weg für den, der den Dienst betreibt."

    // MARK: - Das Demo-Haus

    /// Der Knopf unter der Anmeldung, der das Demo-Haus öffnet (`Zugang.demo`).
    public static let demoknopf = "Demo ansehen"

    /// Der Satz über dem Knopf. Er sagt, was man bekommt und dass nichts einzutragen ist.
    public static let demoerklaerung =
        "Wer noch kein eigenes Haus verbunden hat, sieht sich die App an einem Beispielhaus mit "
        + "simulierten Werten an. Dafür ist keine Anmeldung nötig."

    // MARK: - Mein Passwort

    public static let ueberschrift = "Mein Passwort"

    public static func stand(vorhanden: Bool) -> String {
        vorhanden
            ? "Du hast ein Passwort und kannst dich damit an jedem Gerät anmelden."
            : "Du hast kein Passwort. Mit einem Passwort kommst du auch an Geräten herein, die keinen Passkey können."
    }

    public static func knopf(vorhanden: Bool) -> String {
        vorhanden ? "Passwort wechseln" : "Passwort vergeben"
    }

    public static let bisherfeld = "Bisheriges Passwort"

    public static func neufeld(mindestlaenge: Int) -> String {
        "Neues Passwort, mindestens \(mindestlaenge) Zeichen"
    }

    public static let wiederholfeld = "Neues Passwort wiederholen"
    public static let abbrechen = "abbrechen"
    public static let verschieden = "Die beiden Eingaben sind verschieden."

    public static func gespeichert(vorher vorhanden: Bool) -> String {
        vorhanden
            ? "Das Passwort ist gewechselt. Deine anderen Geräte sind abgemeldet."
            : "Das Passwort ist vergeben. Du kannst dich jetzt auch mit E-Mail-Adresse und Passwort anmelden."
    }

    public static let entfernen = "Passwort entfernen"
    public static let entfernenGesperrt = "Entfernen geht erst mit einem Passkey"
    public static let entfernt = "Das Passwort ist entfernt."

    /// Die Mindestlänge, wenn der Dienst sie nicht nennt. Dieselbe Zahl wie
    /// `auth/passwort.py`, `MINDESTLAENGE`; maßgeblich bleibt, was der Dienst prüft.
    public static let mindestlaengeErsatz = 12

    /// Was vor dem Absenden schon hier auffällt: zwei verschiedene Eingaben. Alles andere, auch
    /// die Länge, prüft der Dienst und sagt es in seinem eigenen Satz.
    public static func einwand(neu: String, wiederholung: String) -> String? {
        neu == wiederholung ? nil : verschieden
    }
}
