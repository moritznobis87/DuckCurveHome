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

    /// Die gemessene Breite des Kachelfelds - sie entscheidet über zwei, vier oder sieben
    /// Spalten. Vor der ersten Messung null, und ``Fahrplanraster/spalten(breite:)`` antwortet
    /// darauf mit den zwei Spalten, mit denen die Vorlage ohne Medienabfrage anfängt.
    @State private var kachelbreite: CGFloat = 0

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
    private func kopf(_ p: PlanOut?) -> some View {
        Kachelfeld(
            kacheln: Fahrplankacheln.kacheln(p).map(Kacheldaten.init),
            spalten: Fahrplanraster.spalten(breite: Double(kachelbreite))
        )
        // **Die Breite wird gemessen und nicht erraten.** `horizontalSizeClass` kennt nur
        // „schmal“ und „breit“ und kann die obere Stufe der Vorlage nicht treffen - zwischen
        // einem iPad hochkant und einem quer liegt sie. Der Leser steht im Hintergrund, weil
        // eine Flaeche dort die Groesse ihres Vordergrunds annimmt und damit nichts an der
        // Anordnung aendert; `GeometryReader` als Huelle wuerde die Hoehe des Kachelfelds
        // auffressen.
        .background {
            GeometryReader { raum in
                Color.clear
                    .onChange(of: raum.size.width, initial: true) { _, neu in
                        kachelbreite = neu
                    }
            }
        }
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
    private func horizontbeiwerk(_ p: PlanOut?) -> AnyView? {
        guard let p else { return nil }
        let spanne = "\(Formate.tagUndUhr(iso: p.horizonStart, jetzt: haus.jetzt)) bis "
            + "\(Formate.tagUndUhr(iso: p.horizonEnd, jetzt: haus.jetzt)) · \(p.planner)"
        return AnyView(
            Text(spanne)
                .font(schmal ? Schrift.mono(13) : Schrift.zahlKlein)
                .foregroundStyle(Farbe.text3)
                .multilineTextAlignment(.trailing)
        )
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
            beiwerk: AnyView(
                Text(Fahrplanworte.entscheidungenDazu)
                    .font(schmal ? Schrift.sans(13) : Schrift.sans(12))
                    .foregroundStyle(Farbe.text3)
                    .multilineTextAlignment(.trailing))
        ) {
            if zeilen.isEmpty {
                Text(Fahrplanworte.ohnePreise)
                    .font(Schrift.klein).foregroundStyle(Farbe.text3)
            } else if schmal {
                bloecke(zeilen)
            } else {
                tabelle(zeilen)
            }
        }
    }

    /// Am iPad die sieben Spalten nebeneinander, im gemeinsamen Gerippe aller Berichtsseiten.
    ///
    /// **Drei Spalten tragen Farbe** (`Fahrplan.tsx:715-721`): Puffer, Wärmepumpe und Ofen
    /// sagen dasselbe wie die Streifen der Zeichnung, und sie sollen es in derselben Sprache
    /// sagen.
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
                    farben: zeilen.map { rollenfarbe($0.ofenrolle) }),
                .init(name: Fahrplanraster.spaltennamen[6], zellen: zeilen.map(\.warum)),
            ]
        )
    }

    /// Am Telefon je Zeile ein Block, in dem **alle sieben Werte gleichzeitig** stehen.
    ///
    /// **Warum nicht die Liste des Gerippes.** ``Tabelle`` zeigt am Telefon eine Spalte,
    /// umgeschaltet über eine Pillenreihe - zu sehen waren Zeit und Preis, und Bedarf, Puffer,
    /// Zustandswort, Ofen und die Begründung waren weg, bis man tippt. Die Karte heißt „die
    /// teuersten und die billigsten Viertelstunden, **mit Begründung**“, und die Begründung war
    /// genau das, was dort nicht stand.
    ///
    /// Die Vorlage baut dieselbe Tabelle am Telefon zu einem Raster aus vier Spalten und drei
    /// Zeilen um (`handy.css:319-329`): oben die Zeit über drei Spalten und rechts das
    /// Zustandswort, darunter Preis, Bedarf und Puffer und rechts der Ofen mit dem Wort „Ofen“
    /// vor sich, darunter die Begründung über die ganze Breite und umbrechend. Jede Zeile ist
    /// dort ein eigenes Raster, also gibt es keine Spalten über Zeilen hinweg - drei `HStack`
    /// sind dasselbe.
    ///
    /// **Dieselbe Fassung bräuchten `.kosten-tabelle`, `.nb-tabelle` und `.fenster-tabelle`**
    /// (`handy.css:305`). Sie gehört damit in ``Tabelle`` und nicht in diese Seite; der
    /// Baustein ist in dieser Runde gesperrt, und der Wunsch steht im Bericht.
    private func bloecke(_ zeilen: [Fahrplanraster.Entscheidungszeile]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(zeilen.enumerated()), id: \.offset) { stelle, z in
                if stelle > 0 {
                    Divider().overlay(Farbe.linie1)
                }
                block(z)
                    // `padding: 12px 0`, die erste Zeile nur `padding-top: 2px`.
                    .padding(.top, stelle == 0 ? 2 : 12)
                    .padding(.bottom, 12)
            }
        }
    }

    private func block(_ z: Fahrplanraster.Entscheidungszeile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(z.zeit).font(Schrift.mono(15)).foregroundStyle(Farbe.text1)
                Spacer(minLength: 8)
                Text(z.zustand)
                    .font(Schrift.sans(14))
                    .foregroundStyle(rollenfarbe(z.zustandsrolle) ?? Farbe.text1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(z.preis)
                    .font(Schrift.mono(13.5))
                    .foregroundStyle(Farbe.text1)
                Text(z.bedarf)
                    .font(Schrift.mono(13.5))
                    .foregroundStyle(Farbe.text1)
                Text(z.puffer)
                    .font(Schrift.mono(13.5))
                    .foregroundStyle(rollenfarbe(z.pufferrolle) ?? Farbe.text1)
                Spacer(minLength: 8)
                // Ohne Kopfzeile sagt „brennt“ allein in der rechten Ecke nicht, was brennt
                // (`handy.css:328`: `::before { content: "Ofen " }`). Das Wort kommt aus dem
                // Kern, damit es nicht in zwei Fassungen verschieden heisst.
                Text(z.ofenMitWort)
                    .font(Schrift.sans(13.5))
                    .foregroundStyle(Farbe.text3)
            }
            // Die Begruendung ist der leiseste Teil der Zeile, nicht der lauteste:
            // `Fahrplan.tsx:722` gibt dem siebten `td` die Klasse `text-text-3`, und
            // `handy.css:329` aendert daran nur Lage und Zeilenhoehe (`line-height: 1.4`).
            Text(z.warum)
                .font(Schrift.sans(13.5))
                .foregroundStyle(Farbe.text3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
