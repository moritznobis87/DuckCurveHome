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
/// In einer Ansicht verstreut wäre das genau die Art Code, die beim zweiten Mal nicht mehr
/// anläuft.
///
/// **Was das Gerät erkennt und was es verschickt.** `requiresOnDeviceRecognition` wird gesetzt,
/// wo das Gerät es kann; dann verlässt die Aufnahme das Telefon nicht. Kann es das Modell für
/// Deutsch nicht, erkennt Apple auf seinen Rechnern – das ist dieselbe Abmachung wie beim
/// Diktatknopf der Tastatur, und es steht im Hinweis unter dem Gespräch.
///
/// **Es gibt keinen Test dafür.** Mikrofon und Spracherkennung gibt es unter Linux nicht, und
/// dieser Typ ist fast nur Ablauf. Was sich prüfen lässt – die Texte, die er zurückgibt –
/// steht im Kern.
@MainActor
@Observable
final class Sprachhoerer {

    /// Wo die Aufnahme gerade steht.
    enum Lage: Equatable {
        case still
        /// Der Hörer läuft, der Finger liegt auf der Ente.
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
    /// Was beim Loslassen mit dem letzten Text geschehen soll.
    private var fertig: ((String?) -> Void)?

    var laeuft: Bool { lage != .still }

    // MARK: - Anfangen

    /// Zuhören, bis ``beende()`` gerufen wird. `fertig` bekommt den erkannten Text, oder `nil`.
    func beginne(fertig: @escaping (String?) -> Void) async {
        guard lage == .still else { return }
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
        do {
            try starteMaschine(erkenner)
            lage = .hoert
        } catch {
            scheitere(Alfred.Texte.sprachNichtAngelaufen)
        }
    }

    /// Beide Erlaubnisse: die Spracherkennung und das Mikrofon. Eine allein reicht nicht.
    private func darfHoeren() async -> Bool {
        let sprache = await withCheckedContinuation { weiter in
            SFSpeechRecognizer.requestAuthorization { weiter.resume(returning: $0) }
        }
        guard sprache == .authorized else { return false }
        return await withCheckedContinuation { weiter in
            AVAudioApplication.requestRecordPermission { weiter.resume(returning: $0) }
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
        eingang.installTap(onBus: 0, bufferSize: 1024, format: format) { puffer, _ in
            neu.append(puffer)
        }
        maschine.prepare()
        try maschine.start()

        aufgabe = erkenner.recognitionTask(with: neu) { [weak self] ergebnis, fehler in
            guard let self else { return }
            let satz = ergebnis?.bestTranscription.formattedString
            let endgueltig = ergebnis?.isFinal ?? false
            Task { @MainActor in
                if let satz { self.text = satz }
                if endgueltig || fehler != nil { self.loese(fehler: fehler) }
            }
        }
    }

    private enum Hoerfehler: Error { case keinEingang }

    // MARK: - Aufhören

    /// Die Ente ist losgelassen: anhalten und auf das letzte Ergebnis warten.
    func beende() {
        guard lage == .hoert else { return }
        lage = .wartet
        maschine.inputNode.removeTap(onBus: 0)
        maschine.stop()
        anfrage?.endAudio()
        // Eine Wache: antwortet die Erkennung nach dem Anhalten nicht mehr, gilt das, was
        // bis dahin verstanden wurde. Ohne sie bliebe „Einen Moment …" stehen.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, self.lage == .wartet else { return }
            self.loese(fehler: nil)
        }
    }

    /// Abbrechen, ohne zu fragen – das Blatt wird geschlossen, der Finger ist verrutscht.
    func brich() {
        guard lage != .still else { return }
        fertig = nil
        loese(fehler: nil)
    }

    /// Das Ende, von welcher Seite auch immer: aufräumen, einmal melden.
    private func loese(fehler: (any Error)?) {
        guard lage != .still else { return }
        aufgabe?.cancel()
        aufgabe = nil
        anfrage = nil
        if maschine.isRunning {
            maschine.inputNode.removeTap(onBus: 0)
            maschine.stop()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        lage = .still

        let gesagt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ruf = fertig
        fertig = nil
        if gesagt.isEmpty {
            // Ein Fehler der Erkennung und „nichts gesagt" sind zwei verschiedene Sätze.
            meldung = fehler == nil ? Alfred.Texte.sprachNichtsGehoert : Alfred.Texte.sprachFehler
            ruf?(nil)
        } else {
            ruf?(gesagt)
        }
    }

    /// Die Meldung ist gelesen. Ohne das bliebe der Hinweis stehen und käme beim nächsten
    /// Öffnen wieder.
    func loescheMeldung() {
        meldung = nil
    }

    private func scheitere(_ satz: String) {
        meldung = satz
        lage = .still
        let ruf = fertig
        fertig = nil
        ruf?(nil)
    }
}
