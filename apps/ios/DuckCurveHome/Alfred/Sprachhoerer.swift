import AVFoundation
import DuckCurveKit
import Observation
import Speech
import SwiftUI

/// Zuhören, solange die Ente gedrückt ist.
///
/// **Warum das ein eigener Typ ist und nicht drei `@State` in der Ansicht.** Eine Aufnahme hat
/// einen Lebenslauf: fragen, ob man darf; den Hörer einschalten; Zwischenergebnisse liefern;
/// beim Loslassen anhalten und auf das *letzte* warten. Jeder dieser Schritte kann schiefgehen,
/// und jeder muss das Mikrofon und die Tonsitzung wieder freigeben – auch der, der schiefgeht.
///
/// **Das Loslassen kann vor dem Anlaufen kommen, und beim ersten Mal tut es das immer.**
/// `beginne` wartet auf zwei Systemdialoge; der Finger ist lange vorher weg. Stünde die Lage
/// erst nach dem Warten auf „hört", liefe das Loslassen ins Leere, und das Mikrofon bliebe
/// danach offen – für immer, denn niemand hält es mehr an. Darum wird die Lage **vor** dem
/// ersten `await` gesetzt, und ein Loslassen während des Anlaufens wird gemerkt und nachgeholt.
///
/// **Aufgeräumt wird an einer Stelle.** Jeder Ausgang – das reguläre Ende, ein Fehler beim
/// Anlaufen, ein Abbruch – geht durch ``raeumeAuf()``. Der erste Entwurf hatte zwei Ausgänge,
/// und der für den Fehlerfall ließ Tonsitzung und Abgriff stehen.
///
/// **Was das Gerät erkennt und was es verschickt.** `requiresOnDeviceRecognition` wird gesetzt,
/// wo das Gerät es kann; dann verlässt die Aufnahme das Telefon nicht. Kann es das Modell für
/// Deutsch nicht, erkennt Apple auf seinen Rechnern – dieselbe Abmachung wie beim Diktatknopf
/// der Tastatur.
///
/// **Es gibt keinen Test dafür.** Mikrofon und Spracherkennung gibt es unter Linux nicht. Was
/// sich prüfen lässt – die Texte, die er zurückgibt – steht im Kern.
@MainActor
@Observable
final class Sprachhoerer {

    /// Wo die Aufnahme gerade steht.
    enum Lage: Equatable {
        case still
        /// Erlaubnis und Hörer laufen an. Der Finger liegt, aber es wird noch nichts gehört.
        case startet
        /// Der Hörer läuft.
        case hoert
        /// Losgelassen, das letzte Ergebnis steht aus.
        case wartet
    }

    private(set) var lage: Lage = .still
    /// Was bisher verstanden wurde – während des Sprechens, Wort für Wort.
    private(set) var text: String = ""
    /// Eine Meldung, wenn es nicht geklappt hat. Aus ``Alfred/Texte``, nie aus dem System.
    private(set) var meldung: String?

    private let erkenner = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private var anfrage: SFSpeechAudioBufferRecognitionRequest?
    private var aufgabe: SFSpeechRecognitionTask?
    private let maschine = AVAudioEngine()
    /// Was beim Loslassen mit dem erkannten Text geschehen soll.
    private var fertig: ((String?) -> Void)?
    /// Der Finger ist gegangen, bevor der Hörer stand.
    private var losgelassen = false
    /// Die Wache nach dem Loslassen – sie gehört genau einer Aufnahme und wird mit ihr beendet.
    private var wache: Task<Void, Never>?

    var laeuft: Bool { lage != .still }

    // MARK: - Anfangen

    /// Zuhören, bis ``beende()`` gerufen wird. `fertig` bekommt den erkannten Text, oder `nil`.
    func beginne(fertig: @escaping (String?) -> Void) async {
        // **Ein zweites Halten waehrend der Wache beendet die erste Aufnahme.** Nach dem
        // Loslassen wartet der Hoerer bis zu drei Sekunden auf das endgueltige Ergebnis - und
        // drei Sekunden sind bei einem Haltenknopf lang. Wer in dieser Zeit noch einmal
        // drueckt, bekam vorher gar nichts: der Druck lief in den Riegel und verschwand ohne
        // jede Rueckmeldung.
        if lage == .wartet { brich() }
        guard lage == .still else { return }
        // **Vor dem ersten `await`.** Ab hier zählt ein Loslassen, auch wenn noch kein Ton
        // fließt.
        lage = .startet
        losgelassen = false
        self.fertig = fertig
        text = ""
        meldung = nil

        guard let erkenner, erkenner.isAvailable else {
            scheitere(Alfred.Texte.sprachKeineSprache)
            return
        }
        guard await darfHoeren() else {
            scheitere(Alfred.Texte.sprachNichtErlaubt)
            return
        }
        // Der Finger war schneller als der Erlaubnisdialog - beim ersten Mal der Normalfall.
        // Nichts aufnehmen, aber sagen, dass es jetzt ginge.
        if losgelassen {
            scheitere(Alfred.Texte.sprachJetztErlaubt)
            return
        }
        do {
            try starteMaschine(erkenner)
        } catch {
            raeumeAuf()
            scheitere(Alfred.Texte.sprachNichtAngelaufen)
            return
        }
        lage = .hoert
        // Zwischen `starteMaschine` und hier kann der Finger gegangen sein.
        if losgelassen { beende() }
    }

    /// Beide Erlaubnisse: die Spracherkennung und das Mikrofon. Eine allein reicht nicht.
    ///
    /// Beide Rückrufe sind ausdrücklich `@Sendable`. Ohne das leitet der Compiler sie in einer
    /// `@MainActor`-Klasse als hauptakteurgebunden ab – und die Frameworks rufen sie auf ihrer
    /// eigenen Warteschlange.
    private func darfHoeren() async -> Bool {
        let sprache = await withCheckedContinuation { weiter in
            SFSpeechRecognizer.requestAuthorization { @Sendable stand in
                weiter.resume(returning: stand)
            }
        }
        guard sprache == .authorized else { return false }
        return await withCheckedContinuation { weiter in
            AVAudioApplication.requestRecordPermission { @Sendable darf in
                weiter.resume(returning: darf)
            }
        }
    }

    private func starteMaschine(_ erkenner: SFSpeechRecognizer) throws {
        let sitzung = AVAudioSession.sharedInstance()
        try sitzung.setCategory(.record, mode: .measurement, options: .duckOthers)
        try sitzung.setActive(true, options: .notifyOthersOnDeactivation)

        let neu = SFSpeechAudioBufferRecognitionRequest()
        neu.shouldReportPartialResults = true
        // Wo das Gerät es kann, bleibt die Aufnahme auf dem Gerät.
        if erkenner.supportsOnDeviceRecognition { neu.requiresOnDeviceRecognition = true }
        anfrage = neu

        let eingang = maschine.inputNode
        let format = eingang.outputFormat(forBus: 0)
        // Ein Format ohne Kanäle heisst: kein Mikrofon. Ohne diese Prüfung wirft `installTap`
        // eine Ausnahme, die kein `try` fängt.
        guard format.channelCount > 0 else { throw Hoerfehler.keinEingang }
        eingang.removeTap(onBus: 0)
        // **`nonisolated(unsafe)` und `@Sendable`, und beides mit Grund.** Der Abgriff läuft
        // auf dem Echtzeitfaden der Tonmaschine, nicht auf dem Hauptakteur; ein Verschluss,
        // den der Compiler als hauptakteurgebunden ableitet, ist dort eine Grenzverletzung.
        // `append` ist von Apple genau für diesen Aufruf vorgesehen.
        nonisolated(unsafe) let fuerAbgriff = neu
        eingang.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable puffer, _ in
            fuerAbgriff.append(puffer)
        }
        maschine.prepare()
        try maschine.start()

        aufgabe = erkenner.recognitionTask(with: neu) { @Sendable [weak self] ergebnis, fehler in
            // Nur Sendbares über die Grenze: `SFSpeechRecognitionResult` und `any Error` sind
            // es nicht.
            let satz = ergebnis?.bestTranscription.formattedString
            let endgueltig = ergebnis?.isFinal ?? false
            let schiefgegangen = fehler != nil
            Task { @MainActor in
                guard let self else { return }
                if let satz { self.text = satz }
                if endgueltig || schiefgegangen {
                    self.loese(schiefgegangen: schiefgegangen)
                }
            }
        }
    }

    private enum Hoerfehler: Error { case keinEingang }

    // MARK: - Aufhören

    /// Die Ente ist losgelassen: anhalten und auf das letzte Ergebnis warten.
    func beende() {
        switch lage {
        case .still, .wartet:
            return
        case .startet:
            // Der Hörer steht noch nicht. ``beginne`` holt das Ende nach, sobald er steht -
            // oder bricht ab, wenn er gar nicht erst anläuft.
            losgelassen = true
            return
        case .hoert:
            break
        }
        lage = .wartet
        maschine.inputNode.removeTap(onBus: 0)
        maschine.stop()
        anfrage?.endAudio()
        // **Eine Wache, und sie gehört dieser Aufnahme.** Antwortet die Erkennung nach dem
        // Anhalten nicht mehr, gilt das, was bis dahin verstanden wurde. Der erste Entwurf
        // liess sie frei laufen: ein zweites Drücken innerhalb von drei Sekunden - bei einem
        // Haltenknopf der Normalfall - wurde dann von der Wache der ersten Aufnahme beendet.
        wache?.cancel()
        wache = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.lage == .wartet else { return }
            self.loese(schiefgegangen: false)
        }
    }

    /// Abbrechen, ohne zu fragen – das Blatt wird geschlossen, der Finger ist verrutscht.
    func brich() {
        guard lage != .still else { return }
        fertig = nil
        loese(schiefgegangen: false)
    }

    /// Die Meldung ist gelesen. Ohne das bliebe der Hinweis stehen und käme beim nächsten
    /// Öffnen wieder.
    func loescheMeldung() {
        meldung = nil
    }

    // MARK: - Aufräumen

    /// Mikrofon, Abgriff, Erkennung und Tonsitzung freigeben. **Jeder Ausgang kommt hier
    /// vorbei** – auch der, der schiefgegangen ist.
    private func raeumeAuf() {
        wache?.cancel()
        wache = nil
        aufgabe?.cancel()
        aufgabe = nil
        anfrage = nil
        maschine.inputNode.removeTap(onBus: 0)
        if maschine.isRunning { maschine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Das Ende, von welcher Seite auch immer: aufräumen, einmal melden.
    private func loese(schiefgegangen: Bool) {
        guard lage != .still else { return }
        raeumeAuf()
        lage = .still
        losgelassen = false

        let gesagt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ruf = fertig
        fertig = nil
        if gesagt.isEmpty {
            // Ein Fehler der Erkennung und „nichts gesagt" sind zwei verschiedene Sätze.
            meldung = schiefgegangen ? Alfred.Texte.sprachFehler : Alfred.Texte.sprachNichtsGehoert
            ruf?(nil)
        } else {
            ruf?(gesagt)
        }
    }

    /// Es ist gar nicht erst angelaufen: aufräumen, Grund nennen, niemanden fragen.
    private func scheitere(_ satz: String) {
        raeumeAuf()
        meldung = satz
        lage = .still
        losgelassen = false
        let ruf = fertig
        fertig = nil
        ruf?(nil)
    }
}
