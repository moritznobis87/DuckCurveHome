import DuckCurveKit
import SwiftUI

/// Fahrplan · Voraus: was der Optimierer für die nächsten Stunden vorhat, Viertelstunde um
/// Viertelstunde.
///
/// **Die Begründung gehört zur Zeile.** Ein Plan, der sagt „23:15 bis 02:00 an“, ohne zu sagen
/// warum, ist eine Ansage. Der Dienst liefert zu jeder Viertelstunde einen `reason_code` und oft
/// einen Satz; beide stehen hier - am Telefon im Block unter den Zahlen und nicht hinter einem
/// Umschalter.
///
/// **Die Seite bleibt stehen, wenn der Plan fehlt.** Hier klammerte `!p.intervals.isEmpty` die
/// Horizontkarte **und** die Entscheidungskarte, und ohne Plan blieb von der ganzen Seite eine
/// leere Karte: keine Kacheln, keine Legende, keine Methode. Die Vorlage zeigt in beiden Fällen
/// weiter die sieben Kacheln (`waerme/Fahrplan.tsx:491-531, 543-574`), die Horizontkarte mit dem
/// Satz und der vollständigen Legende (`:590-640`), die Entscheidungskarte mit ihrem Satz
/// (`:646-649, 690`) und die Methode (`:651-661`). Der Kern kann das längst:
/// ``Fahrplankacheln/kacheln(_:)`` nimmt `nil`, und ``Fahrplanbild/legende(_:)`` braucht kein
/// gebautes Bild. Eine Seite, die beim Fehlen einer Zahl verschwindet, sagt nicht, dass die Zahl
/// fehlt - sie sagt nichts.
struct FahrplanSeite: View {
    @Environment(Hauszustand.self) private var haus
    @Environment(\.horizontalSizeClass) private var breite

    private var schmal: Bool { breite == .compact }

    var body: some View {
        Seite {
            kopf(haus.plan)
            horizontkarte(haus.plan)
            entscheidungskarte(haus.plan)
            // **Genau die drei Absätze der Vorlage.** Hier hingen zwei selbstgebaute Zeilen
            // daran: „Planer: … · erstellt hh:mm“ und ein Satz zur Freigabe. Weder
            // `planner_status` noch `created_at` kommen auf der Vorlageseite vor, und die
            // Freigabe steht dort im Hinweis der ersten Kachel (`Fahrplan.tsx:555`) - wo die
            // App sie ebenfalls schon hat (``Fahrplankacheln/kacheln(_:)``), also zweimal. Der
            // Planername steht jetzt dort, wo die Vorlage ihn hat: im Beiwerk der Horizontkarte.
            Methode(
                Fahrplanworte.methode.map(Optional.init),
                kurz: Fahrplanworte.methodeKurz,
                titel: Fahrplanworte.methodeTitel
            )
        }
    }

    // MARK: - Die sieben Kacheln

    /// Die sieben Zahlen der Vorlage, gerechnet in ``Fahrplankacheln``.
    ///
    /// Vorher standen hier vier andere: erwartete Sonne, die *Zahl* der geplanten Laeufe, das
    /// naechste Preistief und die Puffergroesse. Drei Laeufe koennen zwanzig Minuten oder acht
    /// Stunden sein - die Stunden sind das, was man der gemessenen Laufzeit gegenueberstellt.
    ///
    /// **Zwei Spalten am Telefon, vier am iPad, sieben an der Wand** (`Fahrplan.tsx:548`:
    /// `grid-cols-2 md:grid-cols-4 xl:grid-cols-7`). Hier stand fest `spalten: 4`, und
    /// ``Kachelfeld`` zerlegt in Zeilen fester Laenge unabhaengig von der Breite: die sechs
    /// Kacheln hinter der fuehrenden standen auf 390 Punkten zu vier in einer Reihe. Die obere
    /// Stufe fehlte ganz.
    ///
    /// **Gemessen wird in ``Kachelfeld``.** Dafuer standen hier ein `@State` und ein
    /// `GeometryReader` im Hintergrund der Karte - ein Messaufbau in einer Seite, die davon
    /// nichts wissen will, und der erste von inzwischen mehreren. Die Staffelung selbst steht
    /// in ``Fahrplanraster/raster``, also im Kern.
    ///
    /// **Die Werte sind Spannen** („2,8 bis 3,6“), und die Vorlage gibt ihnen am Telefon eine
    /// Stufe weniger (`handy.css:381-382`, `.kpi-handy`).
    private func kopf(_ p: PlanOut?) -> some View {
        Kachelfeld(
            kacheln: Fahrplankacheln.kacheln(p).map(Kacheldaten.init),
            spannen: true,
            staffelung: Fahrplanraster.raster
        )
    }

    // MARK: - Die Karte „Horizont“

    /// Die Zeichnung, und wo sie fehlt der Satz - die Legende steht in beiden Fällen.
    ///
    /// **Die Horizontspanne und der Planer stehen im Beiwerk und nicht als Titel**
    /// (`Fahrplan.tsx:577-586`, `ui/Card.tsx:22-27`: `right`, auf derselben Grundlinie rechts,
    /// 12 px, `--text-3`, die Spanne in Mono). Als `titel` setzt ``Karte`` sie auf breitem
    /// Schirm unter den Kicker, in Kartenschrift und Textfarbe - also als zweite Überschrift,
    /// und „heute 00:00 bis übermorgen 00:00 · k1“ ist keine.
    @ViewBuilder private func horizontkarte(_ p: PlanOut?) -> some View {
        Karte(kicker: "Horizont", beiwerk: horizontbeiwerk(p)) {
            // **Der Fehlschlag der Abfrage ist zu sehen, und die Seite bleibt stehen.** Die
            // Vorlage ersetzt in diesem Fall die ganze Seite durch eine Karte mit dem
            // Fehlersatz (`:534-541`); ``Stoerung`` ist der Weg des Projekts, denselben Satz zu
            // zeigen, ohne die Kacheln von vorhin wegzuwerfen - und sie bringt den Weg zum
            // Wiederholen mit, den die Vorlage nicht hat. Hier stand stattdessen „Noch kein
            // Fahrplan gerechnet.“, derselbe Satz wie fuer „der Planer hat noch nicht
            // gerechnet“: zwei verschiedene Lagen unter einem Wort.
            if let fehler = haus.fehler {
                Stoerung(fehler: fehler) { Task { await haus.ersteLadung() } }
            }
            if let p, !p.intervals.isEmpty {
                Fahrplanzeichnung(bild: Fahrplanbild.baue(p), plan: p, jetzt: haus.jetzt)
            } else {
                Text(Fahrplanworte.ohnePlan)
                    .font(Schrift.klein)
                    .foregroundStyle(Farbe.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                Fahrplanlegende(stuecke: Fahrplanbild.legende(p))
            }
            // **Die beiden Sätze des Planers stehen unter der Zeichnung**
            // (`Fahrplan.tsx:642-643`), nicht in einer eigenen Karte davor und nicht in der
            // zugeklappten Methode: die Notiz blass, die Warnung rot. Hier hatte die Warnung
            // eine Karte für sich, mit dem erfundenen Vorsatz „Der Planer meldet etwas.“ und
            // in Textfarbe - eine Warnung, die aussieht wie eine Auskunft, ist keine.
            //
            // 12 px, am Telefon 13,5 (`handy.css:191`). ``Schrift/winzig`` stand hier
            // breitenunabhaengig auf 11,5.
            if let notiz = p?.plannerNoteDe, !notiz.isEmpty {
                Text(notiz)
                    .font(planerschrift)
                    .foregroundStyle(Farbe.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let warnung = p?.plannerWarnDe, !warnung.isEmpty {
                Text(warnung)
                    .font(planerschrift)
                    .foregroundStyle(Farbe.alarm)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var planerschrift: Font {
        schmal ? Schrift.sans(13.5) : Schrift.sans(12)
    }

    /// „heute 00:00 bis übermorgen 00:00 · k1“ in Zahlenschrift.
    ///
    /// Groesse und Ausrichtung stehen in ``Kartenhinweis`` und ``Karte/beiwerkzeile(_:)``; hier
    /// stand beides noch einmal, samt der Umschaltung auf 13 Punkte am Telefon.
    private func horizontbeiwerk(_ p: PlanOut?) -> AnyView? {
        guard let p else { return nil }
        let spanne = "\(Formate.tagUndUhr(iso: p.horizonStart, jetzt: haus.jetzt)) bis "
            + "\(Formate.tagUndUhr(iso: p.horizonEnd, jetzt: haus.jetzt)) · \(p.planner)"
        return Kartenhinweis.beiwerk(spanne, mono: true)
    }

    // MARK: - Die Karte „Die Entscheidungen“

    /// Die Viertelstunden an den Preisenden – so wie es das Dashboard zeigt.
    ///
    /// Nicht alle 96 und nicht die naechsten 32: an einem ruhigen Tag steht in fast allen
    /// dasselbe, und auf dem Telefon stand das als zweiunddreissig Zeilen „aus“ untereinander.
    private func entscheidungskarte(_ p: PlanOut?) -> some View {
        let zeilen = Fahrplanraster.zeilen(
            Planauswahl.entscheidungen(p?.intervals ?? []), jetzt: haus.jetzt)
        return Karte(
            kicker: "Die Entscheidungen",
            beiwerk: Kartenhinweis.beiwerk(Fahrplanworte.entscheidungenDazu)
        ) {
            if zeilen.isEmpty {
                Text(Fahrplanworte.ohnePreise)
                    .font(Schrift.klein).foregroundStyle(Farbe.text3)
            } else {
                tabelle(zeilen)
            }
        }
    }

    /// Die sieben Spalten im gemeinsamen Gerippe aller Berichtsseiten - am iPad nebeneinander,
    /// am Telefon je Zeile als Raster.
    ///
    /// **Drei Spalten tragen Farbe** (`Fahrplan.tsx:715-721`): Puffer, Wärmepumpe und Ofen
    /// sagen dasselbe wie die Streifen der Zeichnung, und sie sollen es in derselben Sprache
    /// sagen.
    ///
    /// **Die Blockfassung ist hergezogen, nicht gebaut.** Hier standen `bloecke(_:)` und
    /// `block(_:)` - das Raster aus `handy.css:319-329` von Hand, weil ``Tabelle`` damals
    /// gesperrt war. Jetzt steht es dort (``Tabelle/Handyfassung/block``), und zwar fuer alle
    /// vier Tabellen, die die Vorlage so umbaut. „Spitze“ ist das Zustandswort, „Fuss“ die
    /// Begruendung (`handy.css:323`, `:329`).
    ///
    /// **„Ofen brennt“ steht nur am Telefon so da** (`handy.css:328`: `::before`). Das Wort
    /// kommt aus dem Kern, damit es nicht in zwei Fassungen verschieden heisst.
    private func tabelle(_ zeilen: [Fahrplanraster.Entscheidungszeile]) -> some View {
        Tabelle(
            // „03:15“ allein steht im Horizont zweimal: er reicht ueber zwei Tage.
            zeilennamen: zeilen.map(\.zeit),
            spalten: [
                .init(name: Fahrplanraster.spaltennamen[1], zellen: zeilen.map(\.preis)),
                .init(name: Fahrplanraster.spaltennamen[2], zellen: zeilen.map(\.bedarf)),
                .init(
                    name: Fahrplanraster.spaltennamen[3], zellen: zeilen.map(\.puffer),
                    farben: zeilen.map { rollenfarbe($0.pufferrolle) }),
                .init(
                    name: Fahrplanraster.spaltennamen[4], zellen: zeilen.map(\.zustand),
                    farben: zeilen.map { rollenfarbe($0.zustandsrolle) }),
                .init(
                    name: Fahrplanraster.spaltennamen[5], zellen: zeilen.map(\.ofen),
                    farben: zeilen.map { rollenfarbe($0.ofenrolle) },
                    handyzellen: zeilen.map(\.ofenMitWort)),
                // Die Begruendung ist ein Satz und kein Wert: links, in Satzschrift und leise
                // (`Fahrplan.tsx:703`, `:722`).
                .init(
                    name: Fahrplanraster.spaltennamen[6], zellen: zeilen.map(\.warum),
                    linksbuendig: true),
            ],
            handyfassung: .block(spitze: 3, fuss: 5),
            namenskopf: Fahrplanraster.spaltennamen[0]
        )
    }

    /// Dieselben Farben wie im Streifen darüber - nur „frei“ und „aus“ lesbar gemacht.
    ///
    /// Im Bild sind das Flächen in 30 und 14 Prozent Deckung (`Fahrplan.tsx:51-56`); als Text
    /// wären sie nicht zu lesen. Begründet steht das an ``Fahrplanbild/Rolle/bildfarbe``.
    private func rollenfarbe(_ r: Fahrplanbild.Rolle) -> Color? {
        switch r {
        case .angefordert, .wpGemessen: return Farbe.waermepumpe
        case .gemieden: return Farbe.alarm
        case .frei: return Farbe.text2
        case .aus: return Farbe.text3
        case .ofenAn: return Farbe.ofen
        case .ofenAus, .neutral: return nil
        case .pv: return Farbe.pv
        case .puffer: return Farbe.puffer
        case .heizen: return Farbe.haus
        case .warmwasser: return Farbe.warmwasser
        case .vorhersage: return Farbe.mist
        }
    }

}
