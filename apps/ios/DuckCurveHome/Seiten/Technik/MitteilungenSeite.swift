import DuckCurveKit
import SwiftUI

/// Mitteilungen: was aufs Handy kommt - Störungen und das Morning Briefing.
///
/// **Warum es Mitteilungen überhaupt gibt**, in den Worten von `push.py`: „Der Wächter sieht,
/// wenn eine Quelle schweigt. Das nützt nur jemandem, der gerade auf die Wandanzeige sieht - und
/// genau das tat im Oktober 2026 zwei Tage lang niemand. Eine Mitteilung geht den Weg umgekehrt:
/// Sie sucht sich den Menschen.“
///
/// **Hier wird gefragt und nicht beim Start.** Ein Erlaubnisdialog, den niemand einordnen kann,
/// wird abgelehnt - und danach ist die Tür zu, bis jemand in die Systemeinstellungen geht. Auf
/// dieser Seite steht daneben, wofür.
///
/// ## Was diese Seite sagen muss, und bis zum 20.11.2026 verschwieg
///
/// Vorlage sind zwei Karten (`apps/web/src/app/system/mitteilungen/page.tsx:13-16`:
/// `components/settings/Mitteilungen.tsx` und `components/settings/Morgenbrief.tsx`), und in
/// beiden steht derselbe Satz dreimal in verschiedener Gestalt: *wenn etwas nicht in Ordnung
/// ist, sagt die Seite es*.
///
/// 1. **Kein Gerät angemeldet.** Die App ließ die Geräteliste dann ganz verschwinden, und der
///    Morgenbrief schwieg dazu. Die Vorlage warnt an beiden Stellen
///    (`Mitteilungen.tsx:257-260`, `Morgenbrief.tsx:99-103`), und der Kommentar der Vorlage nennt
///    den 12.11.2026, an dem „im Haus keine einzige Mitteilung ankam“
///    (`Mitteilungen.tsx:24-27`). Eine Seite, die dann „Angemeldet“ und einen hübschen Brief
///    zeigt, sagt das Gegenteil der Wahrheit.
/// 2. **Der Zustand je Gerät.** Statt „seit 14:23 · zuletzt 06:12“ steht jetzt der Satz der
///    Vorlage: wann zuletzt eine Mitteilung angenommen wurde, oder woran die letzte scheiterte
///    (``Mitteilungsstand/zeile(_:)``).
/// 3. **Der Grund je Gerät nach einer Probe.** `messageDe` ist die Summe („ging an 2 Geräte; der
///    Push-Dienst hat 1 davon angenommen“, `push.py:157`); `detailsDe` nennt je Gerät den Grund
///    (`push.py:158`). Die Vorlage listet beides (`Mitteilungen.tsx:246-250`), die App zeigte nur
///    die Summe - also genau die Zeile, die am 12.11. nichts erklärte.
///
/// **Gerechnet wird nichts hier.** Die Stufen, Zählwörter, Rückfälle und festen Sätze stehen in
/// ``Mitteilungsstand`` im Kern, wo sie geprüft sind; diese Datei setzt sie nur.
struct MitteilungenSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(Mitteilungen.self) private var mitteilungen
    @Environment(\.horizontalSizeClass) private var breite

    @State private var brief: MorgenbriefOut?
    @State private var geraete: PushGeraeteOut?
    @State private var rueckmeldung: String?
    @State private var einzelheiten: [String] = []
    @State private var briefmeldung: String?
    @State private var briefeinzelheiten: [String] = []
    @State private var laeuft = false

    private var schmal: Bool { breite == .compact }

    /// Die 13 Punkte der Vorlage sind am Telefon 14,5 (`handy.css:189-192`: `text-[13px]` eine
    /// Stufe größer). Das trifft die Fußnote, den Einordnungssatz und `zuletzt_de`.
    private var kleinstufe: CGFloat { schmal ? 14.5 : 13 }

    /// Wie es um dieses Gerät steht, in den Worten des Kerns.
    ///
    /// Die Übersetzung steht hier und nicht im Kern, weil ``Mitteilungen/Stand`` zur Oberfläche
    /// gehört: er kommt von `UNUserNotificationCenter` und von APNs, und beides gibt es unter
    /// Linux nicht. Was *aus* der Lage folgt, rechnet ``Mitteilungsstand``.
    private var lage: Mitteilungsstand.Lage {
        switch mitteilungen.stand {
        case .ungefragt: return .aus
        case .abgelehnt: return .verboten
        case .erlaubt: return .halb
        case .angemeldet: return .an
        case .fehler(let satz): return .fehler(satz)
        }
    }

    var body: some View {
        Seite {
            ueberschrift
            karteMitteilungen
            karteBrief
            Methode([
                "Der Dienst verschickt Mitteilungen auf zwei Wegen: als Web Push an das "
                    + "Dashboard im Browser, und als APNs an diese App. Beide Wege bedienen "
                    + "dieselben Mitteilungen.",
                "Für den App-Weg braucht der Dienst einen Signierschlüssel aus einem "
                    + "Apple-Developer-Konto. Ohne ihn kann kein Dienst eine Mitteilung an eine "
                    + "iOS-App schicken – das ist Apples Entwurf. Wie er eingetragen wird, steht "
                    + "in apps/ios/README.md.",
                "Was ohne ihn trotzdem geht: das Morning Briefing steht hier und lässt sich "
                    + "ansehen. Nur der Weg auf den Sperrbildschirm fehlt.",
            ])
        }
        .task { await lade() }
    }

    /// Die Überschrift der Seite (`page.tsx:14`: `h2`, 18 Punkte halbfett).
    ///
    /// Der Kicker der Hülle („Was aufs Handy kommt …“, `page.tsx:12`) steht nicht hier: den
    /// zeichnet ``Seite`` aus ``Bereiche/kicker(fuer:)``, so wie die Vorlage ihn der Hülle gibt
    /// (`AreaShell.tsx:26`). Zweimal dieselbe Auskunft übereinander wäre keine.
    private var ueberschrift: some View {
        Text("Mitteilungen")
            .font(Schrift.sansHalbfett(18, relativeTo: .title3))
            .foregroundStyle(Farbe.text1)
    }

    // MARK: - Karte „Mitteilungen“

    private var karteMitteilungen: some View {
        Karte(kicker: Mitteilungsstand.kicker) {
            VStack(alignment: .leading, spacing: 14) {
                absatz(Mitteilungsstand.erklaerung, 15, Farbe.text2)
                lagezeile
                knoepfe
                if let r = rueckmeldung {
                    absatz(r, 14, Farbe.text2)
                }
                einzelheitenliste(einzelheiten)
                geraeteabschnitt
                absatz(Mitteilungsstand.fussnote, kleinstufe, Farbe.text3)
            }
        }
        .frame(maxWidth: Self.spalte, alignment: .leading)
    }

    /// Der Satz zur Lage dieses Geräts - Warnton oder Bestätigung, wie der Kern es entscheidet.
    @ViewBuilder private var lagezeile: some View {
        let s = Mitteilungsstand.lagesatz(lage)
        if let satz = s.satz {
            absatz(satz, 14, s.warnt ? Farbe.amberWeich : Farbe.pv)
        }
    }

    /// Die Knöpfe der ersten Karte - am Telefon untereinander.
    ///
    /// **Warum nicht in einer Zeile.** Die Vorlage setzt `flex-wrap` (`Mitteilungen.tsx:220`),
    /// und sie braucht es: „Probe an die angemeldeten Geräte“ ist auf 390 Punkten breiter als
    /// der halbe Schirm. SwiftUIs `HStack` bricht nicht um, er drückt stattdessen die Spalte
    /// auseinander - und ein zu breites Kind kostet hier die ganze Seite ihren Rand
    /// (``Seite``, Begründung dort). Was bleibt, ist die Entscheidung, die `handy.css:3-26` für
    /// alles trifft: am Telefon untereinander, über die ganze Breite.
    @ViewBuilder private var knoepfe: some View {
        let probe = Mitteilungsstand.probeknopf(lage: lage, geraete: geraete?.devices.count)
        if Mitteilungsstand.darfEinschalten(lage) || probe != .keiner || lage == .an {
            Knopfreihe(untereinander: schmal) {
                if Mitteilungsstand.darfEinschalten(lage) {
                    knopf("Auf diesem Gerät einschalten") {
                        Task { await mitteilungen.frage() }
                    }
                }
                switch probe {
                case .diesesGeraet:
                    knopf("Probe senden") { probeSenden() }
                case .fremdeGeraete:
                    knopf("Probe an die angemeldeten Geräte") { probeSenden() }
                case .keiner:
                    EmptyView()
                }
                if lage == .an {
                    knopf("Ausschalten") { abmelden() }
                }
            }
        }
    }

    /// Der Geräteabschnitt: Zählwort, und darunter die Liste oder der Warnsatz.
    ///
    /// **Er erscheint, sobald die Abfrage überhaupt geantwortet hat** (`Mitteilungen.tsx:252`:
    /// `geraete !== null`) - und dann auch mit null Geräten, denn das ist die Auskunft, um die
    /// es geht. Scheitert die Abfrage, steht hier nichts: eine Null, die aus einem Netzfehler
    /// kommt, wäre eine Behauptung über das Haus.
    @ViewBuilder private var geraeteabschnitt: some View {
        if let g = geraete {
            VStack(alignment: .leading, spacing: 8) {
                zweiterKicker(Mitteilungsstand.zaehlwort(g.devices.count))
                if g.devices.isEmpty {
                    absatz(Mitteilungsstand.ohneGeraete, 14, Farbe.amberWeich)
                } else {
                    geraeteliste(Mitteilungsstand.zeilen(g))
                }
            }
        }
    }

    /// Die Liste der Geräte, mit Linie oben **und unter jeder Zeile**.
    ///
    /// Die Vorlage setzt `border-top` an die Liste und `border-bottom` an jede Zeile
    /// (`globals.css:761-762`) - also auch unter der letzten. Das ist kein Zierrat: die letzte
    /// Linie schließt die Liste gegen die Fußnote ab, die unmittelbar darunter steht.
    private func geraeteliste(_ zeilen: [Mitteilungsstand.Geraetezeile]) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Farbe.linie1)
            ForEach(zeilen) { z in
                geraetezeile(z)
                Divider().overlay(Farbe.linie1)
            }
        }
    }

    /// Eine Gerätezeile: Name und Anmeldetag in einer Zeile, der Zustandssatz über beide Spalten.
    ///
    /// Das ist das CSS-Raster der Vorlage (`globals.css:762-765`: zwei Spalten, die zweite Zeile
    /// über `grid-column: 1 / -1`) in SwiftUI - ein `HStack` mit `Spacer` und ein `Text`
    /// darunter.
    ///
    /// **„angemeldet seit“ bleibt bei 13 Punkten, auch am Telefon.** `.geraet-seit` trägt keine
    /// Tailwind-Klasse (`globals.css:764`), und `handy.css:189-192` vergrößert nur die
    /// Tailwind-Stufen - die Spalte rechts soll schmal bleiben.
    private func geraetezeile(_ z: Mitteilungsstand.Geraetezeile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(z.name)
                    .font(Schrift.sansHalbfett(14))
                    .foregroundStyle(Farbe.text1)
                Spacer(minLength: 8)
                if let seit = z.seit {
                    Text(seit)
                        .font(Schrift.sans(13))
                        .foregroundStyle(Farbe.text3)
                        .multilineTextAlignment(.trailing)
                }
            }
            Text(z.stand)
                .font(Schrift.sans(14))
                .foregroundStyle(z.schlecht ? Farbe.amberWeich : Farbe.text2)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Karte „Morning Briefing“

    /// Die zweite Karte.
    ///
    /// **Kicker und Erklärung stehen auch vor der Antwort.** Die Vorlage setzt beide außerhalb
    /// ihrer `stand`-Abfrage (`Morgenbrief.tsx:67-71`) und schreibt die Uhrzeit mit Rückfall
    /// „07:00“ in den Satz. Die App zeigte die Karte erst, wenn die Antwort da war - und bei
    /// einem Dienst, der sie nicht gibt, stand von der halben Seite nichts da.
    private var karteBrief: some View {
        Karte(kicker: Mitteilungsstand.briefKicker) {
            VStack(alignment: .leading, spacing: 14) {
                absatz(Mitteilungsstand.briefErklaerung(uhrzeit: brief?.uhrzeit), 15, Farbe.text2)
                briefinhalt
                if let m = briefmeldung {
                    absatz(m, 14, Farbe.text2)
                }
                einzelheitenliste(briefeinzelheiten)
            }
        }
        .frame(maxWidth: Self.spalte, alignment: .leading)
    }

    @ViewBuilder private var briefinhalt: some View {
        if let b = brief {
            absatz(Mitteilungsstand.einordnung(b), kleinstufe, Farbe.text3)
            vorschau(b)
            briefknoepfe(b)
            if Mitteilungsstand.warntOhneGeraete(b) {
                absatz(Mitteilungsstand.briefOhneGeraete, 14, Farbe.amberWeich)
            }
            if let zuletzt = b.zuletztDe, !zuletzt.isEmpty {
                absatz(zuletzt, kleinstufe, Farbe.text3)
            }
        }
    }

    /// Die Vorschau als Mitteilungsblase des Telefons (`globals.css:756-758`).
    ///
    /// **Warum eine Blase und keine nackten Zeilen.** Was hier steht, ist nicht ein Abschnitt
    /// der Seite, sondern eine Abschrift von etwas, das anderswo erscheint - auf dem
    /// Sperrbildschirm. Die Vorlage gibt ihr dafür die Form einer Mitteilung: Radius 14,
    /// höchstens 460 Punkte breit, eine Fläche heller als der Grund. So ist zu sehen, dass es
    /// eine Vorschau ist und nicht der Text der Seite.
    ///
    /// **Die Fläche ist `rgba(255,255,255,.07)` der Vorlage** und kein Markenwert: ``Marken``
    /// führt keinen Eintrag mit dieser Deckung, und eine zweite Fläche zu erfinden, nur damit
    /// sie einen Namen hat, wäre eine Festlegung ohne Beleg. Weiß mit 7 Prozent legt sich wie
    /// in der Vorlage über das, was dahinter liegt - und das ist am iPad ``Farbe/flaeche1``, am
    /// Telefon ``Farbe/flaeche2``. Siehe `braucht` der Messung.
    ///
    /// **Ohne Zeilen steht `hinweisDe` an ihrer Stelle, grau** (`Morgenbrief.tsx:82`): der
    /// Dienst sagt dort selbst, warum nichts darin steht. Die App erfand hier „Heute stünde
    /// nichts darin.“ und stellte den Hinweis des Dienstes daneben in Warnfarbe - zwei Sätze
    /// über dieselbe Sache, und der erfundene vorn.
    private func vorschau(_ b: MorgenbriefOut) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Mitteilungsstand.vorschautitel(b))
                .font(Schrift.sansHalbfett(14))
                .foregroundStyle(Farbe.text1)
                .fixedSize(horizontal: false, vertical: true)
            if b.zeilen.isEmpty {
                if let hinweis = b.hinweisDe, !hinweis.isEmpty {
                    blasenzeile(hinweis, Farbe.text3)
                }
            } else {
                ForEach(Array(b.zeilen.enumerated()), id: \.offset) { _, z in
                    blasenzeile(z, Farbe.text1)
                }
            }
        }
        .padding(.init(top: 14, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: 460, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Eine Zeile in der Blase: 14 Punkte, Zeilenhöhe 1,45 (`globals.css:757`).
    private func blasenzeile(_ text: String, _ farbe: Color) -> some View {
        Text(text)
            .font(Schrift.sans(14))
            .foregroundStyle(farbe)
            .lineSpacing(2.8)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Zustandssatz und Knöpfe des Briefings (`Morgenbrief.tsx:86-98`).
    ///
    /// **Der Zustandssatz steht neben den Knöpfen und nicht im Kartentitel.** Dort stand er in
    /// der App („kommt täglich um 07:00“), und ein Titel trägt keine Farbe: ein- und
    /// ausgeschaltet sahen gleich aus. Hier ist er die Antwort auf die Frage, die der Knopf
    /// daneben stellt, in ``Farbe/pv`` beziehungsweise ``Farbe/text3``.
    ///
    /// **Die Knöpfe nur mit Vollzugriff.** Die Vorlage sperrt die ganze Seite für Gäste
    /// (`page.tsx:10`, `requireOwner()`); in der App ist der Reiter ebenso dem Hausherrn
    /// vorbehalten (`Bereiche.swift:227`), aber ein Gastzugang auf einem angemeldeten Gerät soll
    /// trotzdem nicht schalten können.
    @ViewBuilder private func briefknoepfe(_ b: MorgenbriefOut) -> some View {
        Knopfreihe(untereinander: schmal) {
            Text(Mitteilungsstand.briefZustand(an: b.enabled))
                .font(Schrift.sans(14))
                .foregroundStyle(b.enabled ? Farbe.pv : Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            if haus.darfSchalten {
                knopf(Mitteilungsstand.schaltwort(an: b.enabled)) { stelleBrief(!b.enabled) }
                knopf("Jetzt senden", gesperrt: !Mitteilungsstand.darfSenden(b)) { sendeBrief() }
            }
        }
    }

    // MARK: - Bausteine

    /// Die Spaltenbreite der Vorlage (`page.tsx:13`, `Mitteilungen.tsx:187`: `max-w-[760px]`).
    ///
    /// ``Seite`` setzt nur den Rand; am iPad liefen die Karten dieser Seite sonst über die ganze
    /// Breite, und ein Satz über 1100 Punkte ist keine Zeile mehr, sondern eine Strecke.
    private static let spalte: CGFloat = 760

    /// Ein Absatz in der Größe der Vorlage, mit ihrem Zeilenabstand.
    ///
    /// `line-height: 1.6` heißt in CSS: die Zeilenschachtel ist 1,6-mal so hoch wie die Schrift.
    /// SwiftUI zählt nicht die Schachtel, sondern den **Zuschlag** - und die Schachtel ist dort
    /// schon etwa 1,25-mal so hoch. Der Zuschlag ist also rund 0,35 der Größe; ohne diese
    /// Umrechnung stünden die Zeilen enger als in der Vorlage.
    private func absatz(_ text: String, _ groesse: CGFloat, _ farbe: Color) -> some View {
        Text(text)
            .font(Schrift.sans(groesse))
            .foregroundStyle(farbe)
            .lineSpacing(groesse * 0.35)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `details_de` als Liste: ein Punkt je Gerät (`Mitteilungen.tsx:246-250`,
    /// `Morgenbrief.tsx:106-110`).
    ///
    /// **Das ist der Grund, warum die Probe etwas nützt.** `message_de` ist die Summe („ging an
    /// 2 Geräte; der Push-Dienst hat 1 davon angenommen“, `push.py:157`); welches der beiden und
    /// warum, steht nur hier (`push.py:158`).
    @ViewBuilder private func einzelheitenliste(_ saetze: [String]) -> some View {
        if !saetze.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(saetze.enumerated()), id: \.offset) { _, satz in
                    absatz(satz, 14, Farbe.text2)
                }
            }
        }
    }

    /// Der zweite Kicker in einer Karte.
    ///
    /// ``Karte`` kennt nur einen (`Gestalt/Karte.swift:16`); die Vorlage hat in diesem Kasten
    /// zwei (`Mitteilungen.tsx:189`, `:254`). Der zweite steht darum im Inhalt - am Telefon
    /// aber ohne Sperrschrift, genau wie ``Karte`` es dort für ihren eigenen Kopf tut
    /// (`Karte.swift:66-71`): `handy.css:3-26` hat die Sperrschrift in Überschriften
    /// ausdrücklich abgeschafft.
    @ViewBuilder private func zweiterKicker(_ wort: String) -> some View {
        if schmal {
            Text(wort).font(Schrift.karte).foregroundStyle(Farbe.text1)
        } else {
            Kicker(wort: wort)
        }
    }

    /// Ein Knopf in der Gestalt der Vorlage (`Mitteilungen.tsx:184`).
    ///
    /// **Durchsichtig mit Haarlinie, nicht gefüllt.** Die App füllte ihn mit ``Farbe/amberWeich``
    /// und schrieb in ``Farbe/deep`` hinein - auf einer Seite mit bis zu vier Knöpfen
    /// nebeneinander sind das vier amberfarbene Flächen, und daneben soll ein amberfarbener
    /// *Warnsatz* auffallen. Die Vorlage hält Amber für die Warnung frei und gibt dem Knopf nur
    /// eine Linie (`border-line-2`, 16/8 Innenrand, 14 Punkte).
    private func knopf(
        _ wort: String, gesperrt: Bool = false, tun: @escaping () -> Void
    ) -> some View {
        let aus = laeuft || gesperrt
        return Button(action: tun) {
            Text(wort)
                .font(Schrift.sans(14))
                .foregroundStyle(Farbe.text1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                        .strokeBorder(Farbe.linie2, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(aus)
        .opacity(aus ? 0.5 : 1)
    }

    // MARK: - Griffe

    /// Eine Probe schicken - an dieses Gerät oder an die angemeldeten.
    ///
    /// **Fehler bleiben nicht stumm.** Hier stand `try?` und darunter ein eigener Satz, der den
    /// Grund nicht kannte („Die Probe ist nicht durchgekommen.“). ``ApiFehler/rat`` weiß ihn, und
    /// ``Mitteilungsstand/hinweis(_:)`` setzt ihn in den Satz der Vorlage
    /// (`Mitteilungen.tsx:55`).
    private func probeSenden() {
        laeuft = true
        rueckmeldung = nil
        einzelheiten = []
        Task {
            do {
                let antwort = try await haus.api.mitteilungProbe()
                rueckmeldung = antwort.messageDe
                einzelheiten = antwort.detailsDe
            } catch let f as ApiFehler {
                rueckmeldung = Mitteilungsstand.hinweis(f.rat)
            } catch {
                rueckmeldung = Mitteilungsstand.hinweis(error.localizedDescription)
            }
            await lade()
            laeuft = false
        }
    }

    /// Dieses Gerät abmelden - und nur sagen, was wirklich geschehen ist.
    ///
    /// **Warum hier nicht ``lade()`` steht.** Dessen letzte Zeile ist `pruefeStand()`, und das
    /// meldet das Gerät beim System wieder an; der Satz „Dieses Gerät bekommt keine Mitteilungen
    /// mehr.“ stünde dann unter einem „Dieses Gerät ist angemeldet.“ in derselben Karte. Die
    /// Vorlage lädt an dieser Stelle nur die Geräteliste nach (`Mitteilungen.tsx:158-160`:
    /// `ladeGeraete()`), und genau das ist die Liste, in der dieses Gerät jetzt fehlt.
    ///
    /// **Und warum der Fehlerfall einen eigenen Satz hat.** Scheitert der Weg zum Dienst, ist
    /// das Gerät dort noch angemeldet (``Mitteilungen/meldeAb()``). Dann gilt derselbe Satz wie
    /// bei einer gescheiterten Probe (`Mitteilungen.tsx:161-162`).
    private func abmelden() {
        laeuft = true
        rueckmeldung = nil
        einzelheiten = []
        Task {
            do {
                try await mitteilungen.meldeAb()
                geraete = try? await haus.api.mitteilungGeraete()
                rueckmeldung = Mitteilungsstand.abgemeldet
            } catch let f as ApiFehler {
                rueckmeldung = Mitteilungsstand.hinweis(f.rat)
            } catch {
                rueckmeldung = Mitteilungsstand.hinweis(error.localizedDescription)
            }
            laeuft = false
        }
    }

    /// Das Briefing ein- oder ausschalten.
    ///
    /// **Und sagen, wenn es nicht geklappt hat.** Hier stand `brief = try? await …`: bei einem
    /// Fehlschlag blieb der alte Stand stehen, und der Knopf sah aus, als hätte er gewirkt. Der
    /// Satz der Vorlage sagt beides (`Morgenbrief.tsx:43`).
    private func stelleBrief(_ an: Bool) {
        laeuft = true
        briefmeldung = nil
        Task {
            do {
                brief = try await haus.api.stelleMorgenbrief(an: an)
            } catch {
                briefmeldung = Mitteilungsstand.schaltenGescheitert
            }
            laeuft = false
        }
    }

    private func sendeBrief() {
        laeuft = true
        briefmeldung = nil
        briefeinzelheiten = []
        Task {
            do {
                let antwort = try await haus.api.sendeMorgenbrief()
                briefmeldung = antwort.messageDe
                briefeinzelheiten = antwort.detailsDe
            } catch {
                briefmeldung = Mitteilungsstand.sendenGescheitert
            }
            laeuft = false
        }
    }

    /// Beide Abfragen zugleich, und der Erlaubnisstand danach.
    ///
    /// **Der Morgenbrief sagt, wenn er nicht zu erreichen ist** (`Morgenbrief.tsx:30`); die
    /// Geräteliste schweigt dazu, und das ist dieselbe Entscheidung wie in der Vorlage
    /// (`Mitteilungen.tsx:84-88`: im Fehlerfall `null`, und der Abschnitt bleibt leer). Der
    /// Unterschied hat einen Grund: ein Brief, der fehlt, ist eine Lücke, die man sieht; eine
    /// Geräteliste mit null Einträgen wäre eine Aussage über das Haus, und die darf ein
    /// Netzfehler nicht machen.
    private func lade() async {
        async let b = haus.api.morgenbrief()
        async let g = haus.api.mitteilungGeraete()
        do {
            brief = try await b
            if briefmeldung == Mitteilungsstand.briefNichtErreichbar { briefmeldung = nil }
        } catch {
            briefmeldung = Mitteilungsstand.briefNichtErreichbar
        }
        geraete = try? await g
        await mitteilungen.pruefeStand()
    }
}

/// Eine Reihe Knöpfe, die am Telefon untereinander steht.
///
/// **Das Gegenstück zu `flex-wrap`** (`Mitteilungen.tsx:220`, `Morgenbrief.tsx:85`). Ein
/// `HStack` bricht nicht um; wo die Vorlage umbricht, ist am Telefon untereinander das, was
/// `handy.css:3-26` für alles vorsieht. In regulärer Breite ist Platz für eine Zeile, und dort
/// steht der Zustandssatz neben seinem Knopf, wie in der Vorlage.
private struct Knopfreihe<Inhalt: View>: View {
    let untereinander: Bool
    @ViewBuilder var inhalt: () -> Inhalt

    var body: some View {
        if untereinander {
            VStack(alignment: .leading, spacing: 10) { inhalt() }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) { inhalt() }
        }
    }
}

/// Das Blatt des Pelletofens: Auto, An für eine Frist, Aus für eine Frist.
///
/// **Zwei Stunden sind die kleinste sinnvolle Anforderung.** Darunter verbrennt der Ofen mehr
/// Pellets im Zünden und Ausbrennen, als er nutzbar in den Puffer bringt - darum fängt die
/// Fristenreihe bei 120 Minuten an und nicht bei 30 wie bei der Wärmepumpe.
struct Ofenblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    private static let fristen = [120, 240, 480]

    @State private var laeuft = false
    @State private var rueckmeldung: String?
    @State private var fehler: ApiFehler?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let o = haus.zustand?.stove {
                        zustand(o)
                        if haus.darfSchalten, o.controlEnabled == true {
                            griffe
                        } else {
                            Karte {
                                Leer(
                                    satz: haus.darfSchalten
                                        ? "Der Ofen ist nicht zum Führen freigegeben."
                                        : "Gastzugang: nur Ansicht.",
                                    dazu: haus.darfSchalten
                                        ? "Es braucht beide Freigaben: stove.control_enabled und "
                                            + "mcz_allow_control. Siehe docs/OFEN_OPTIMIERUNG.md."
                                        : nil
                                )
                            }
                        }
                    } else {
                        Karte { Leer(satz: "Dieses Haus hat keinen geführten Ofen.") }
                    }
                    if let r = rueckmeldung {
                        Text(r).font(Schrift.klein).foregroundStyle(Farbe.text2)
                    }
                    if let f = fehler { Stoerung(fehler: f) }
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle("Pelletofen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
    }

    private func zustand(_ o: StoveLiveOut) -> some View {
        Karte {
            VStack(spacing: 0) {
                Zeile(
                    wort: "Zustand", wert: (o.running ?? false) ? "läuft" : "aus",
                    farbe: (o.running ?? false) ? Farbe.ofen : Farbe.text2
                )
                if let m = o.mode {
                    Zeile(wort: "Betriebsart", wert: m.rawValue)
                }
                if let bis = o.endsAt, let d = Zeit.ausIso(bis) {
                    Zeile(wort: "bis", wert: Formate.hhmm(d))
                }
                if let s = o.powerLevel {
                    Zeile(wort: "Stufe", wert: Formate.zahl(s, stellen: 0))
                }
                if let k = o.boilerTempC {
                    Zeile(wort: "Kessel", wert: Formate.celsius(k, stellen: 1))
                }
                if let r = o.fumeTempC {
                    Zeile(wort: "Rauchgas", wert: Formate.celsius(r, stellen: 0))
                }
                if let geplant = o.plannedOn {
                    Zeile(
                        wort: "im Fahrplan", wert: geplant ? "vorgesehen" : "nicht vorgesehen",
                        dazu: o.planUntil.map { "bis \(Formate.hhmm(iso: $0))" }
                    )
                }
                Zeile(
                    wort: "Führung",
                    wert: o.controlEnabled == true ? "freigegeben" : "gesperrt",
                    farbe: o.controlEnabled == true ? Farbe.text1 : Farbe.achtung
                )
            }
        }
    }

    private var griffe: some View {
        Karte(kicker: "Stellen") {
            VStack(alignment: .leading, spacing: 12) {
                Button { stelle(.auto, frist: 240) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Automatik").font(Schrift.karte).foregroundStyle(Farbe.text1)
                            Text("der Fahrplan entscheidet")
                                .font(Schrift.winzig).foregroundStyle(Farbe.text3)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Farbe.flaeche3)
                    .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach([("An", StoveModeInModeWahl.on), ("Aus", .off)], id: \.0) { wort, art in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wort).font(Schrift.klein).foregroundStyle(Farbe.text2)
                        HStack(spacing: 8) {
                            ForEach(Self.fristen, id: \.self) { minuten in
                                Button { stelle(art, frist: minuten) } label: {
                                    Text(Formate.dauer(minuten: minuten))
                                        .font(Schrift.klein)
                                        .foregroundStyle(Farbe.text1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Farbe.flaeche3)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Text(
                    "Zwei Stunden sind die kleinste sinnvolle Anforderung: darunter verbrennt der "
                        + "Ofen mehr Pellets im Zünden und Ausbrennen, als er nutzbar in den "
                        + "Puffer bringt."
                )
                .font(Schrift.winzig)
                .foregroundStyle(Farbe.text3)
                .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(laeuft)
            .opacity(laeuft ? 0.6 : 1)
        }
    }

    private func stelle(_ art: StoveModeInModeWahl, frist: Int) {
        laeuft = true
        Task {
            do {
                _ = try await haus.api.stelleOfen(StoveModeIn(mode: art, durationMin: frist))
                rueckmeldung = "Gestellt. Der nächste Rahmen zeigt es."
                fehler = nil
                await haus.ersteLadung()
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(error.localizedDescription)
            }
            laeuft = false
        }
    }
}

/// Das Blatt des Speichers: die Betriebsart der Hausbatterie.
struct Batterieblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    @State private var batterie: BatteryLiveOut?
    @State private var laeuft = false
    @State private var rueckmeldung: String?
    @State private var fehler: ApiFehler?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let b = batterie {
                        Karte {
                            VStack(spacing: 0) {
                                Zeile(wort: "Ladestand", wert: Formate.prozent(b.soc.map { $0 > 1 ? $0 / 100 : $0 }))
                                // Die Leistung kommt aus dem Augenblicksbild - diese Antwort
                                // beschreibt die Betriebsart, nicht die Messung.
                                Zeile(
                                    wort: "Leistung",
                                    wert: Formate.kw(haus.augenblick?.batteryPowerKw.belastbar),
                                    einheit: "kW"
                                )
                                Zeile(
                                    wort: "Führung",
                                    wert: b.controlEnabled == true ? "freigegeben" : "gesperrt",
                                    farbe: b.controlEnabled == true ? Farbe.text1 : Farbe.achtung
                                )
                                if let m = b.mode {
                                    Zeile(wort: "Betriebsart", wert: m.rawValue)
                                }
                                if let c = b.command {
                                    Zeile(wort: "Befehl", wert: c.rawValue)
                                }
                                if let bis = b.endsAt, let d = Zeit.ausIso(bis) {
                                    Zeile(wort: "bis", wert: Formate.hhmm(d))
                                }
                                if let r = b.reserveSoc {
                                    Zeile(wort: "Reserve", wert: Formate.prozent(r > 1 ? r / 100 : r))
                                }
                                if let gesendet = b.sentAt, let d = Zeit.ausIso(gesendet) {
                                    Zeile(wort: "gesendet", wert: Formate.hhmm(d))
                                }
                                if let fehler = b.lastError, !fehler.isEmpty {
                                    Zeile(wort: "letzter Fehler", wert: fehler, farbe: Farbe.achtung)
                                }
                            }
                        }
                        if haus.darfSchalten {
                            griffe
                        } else {
                            Karte { Leer(satz: "Gastzugang: nur Ansicht.") }
                        }
                        Methode([b.noteDe])
                    } else {
                        Karte { Leer(satz: "Wird geholt …") }
                    }
                    if let r = rueckmeldung {
                        Text(r).font(Schrift.klein).foregroundStyle(Farbe.text2)
                    }
                    if let f = fehler { Stoerung(fehler: f) }
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle("Speicher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
        .task { batterie = try? await haus.api.batterie() }
    }

    private var griffe: some View {
        Karte(kicker: "Stellen") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(
                    [
                        ("Automatik", BatteryModeInModeWahl.auto, "der Wechselrichter entscheidet"),
                        ("Halten", .hold, "nicht entladen – für ein Preistief später"),
                        ("Aus", .off, "weder laden noch entladen"),
                    ],
                    id: \.0
                ) { wort, art, dazu in
                    Button { stelle(art) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(wort).font(Schrift.karte).foregroundStyle(Farbe.text1)
                                Text(dazu).font(Schrift.winzig).foregroundStyle(Farbe.text3)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Farbe.flaeche3)
                        .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(laeuft)
            .opacity(laeuft ? 0.6 : 1)
        }
    }

    private func stelle(_ art: BatteryModeInModeWahl) {
        laeuft = true
        Task {
            do {
                batterie = try await haus.api.stelleBatterie(
                    BatteryModeIn(mode: art, durationMin: 240)
                )
                rueckmeldung = batterie?.noteDe ?? "Gestellt."
                fehler = nil
            } catch let f as ApiFehler {
                fehler = f
            } catch {
                fehler = .netz(error.localizedDescription)
            }
            laeuft = false
        }
    }
}

/// Die Entscheidungen des Reglers, als Liste.
struct Entscheidungsblatt: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.dismiss) private var schliessen

    /// Was vor dem Verbinden war - der Strom liefert nur, was seitdem kam.
    @State private var archiv: [Decision] = []

    /// Die laufenden zuerst, dann das Archiv ohne Doppelte.
    private var alle: [Decision] {
        var gesehen = Set(haus.entscheidungen.compactMap(\.id))
        var aus = haus.entscheidungen
        for d in archiv {
            guard let id = d.id else { continue }
            if gesehen.insert(id).inserted { aus.append(d) }
        }
        return aus
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if alle.isEmpty {
                        Karte { Leer(satz: "Der Regler hat noch nicht entschieden.") }
                    }
                    ForEach(Array(alle.enumerated()), id: \.offset) { _, d in
                        Karte {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(Formate.hhmm(iso: d.at))
                                        .font(Schrift.zahlKlein).foregroundStyle(Farbe.text3)
                                    Spacer(minLength: 8)
                                    Text(d.k1Release ? "K1 zu" : "K1 offen")
                                        .font(Schrift.winzig)
                                        .foregroundStyle(d.k1Release ? Farbe.waermepumpe : Farbe.text3)
                                }
                                Text(d.explanationDe)
                                    .font(Schrift.klein)
                                    .foregroundStyle(Farbe.text1)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !d.reasons.isEmpty {
                                    Text(d.reasons.map(Grundwort.text).joined(separator: " · "))
                                        .font(Schrift.winzig)
                                        .foregroundStyle(Farbe.mist)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if !d.blockedBy.isEmpty {
                                    Text(d.blockedBy.map(Grundwort.text).joined(separator: " · "))
                                        .font(Schrift.winzig)
                                        .foregroundStyle(Farbe.achtung)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .seitengrund()
            .navigationTitle("Entscheidungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
        .task { archiv = (try? await haus.api.entscheidungen()) ?? [] }
    }
}
