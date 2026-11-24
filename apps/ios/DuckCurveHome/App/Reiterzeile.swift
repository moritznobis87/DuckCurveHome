import DuckCurveKit
import SwiftUI

/// Die Reiter eines Bereichs, als Zeile darunter.
///
/// **Diese Ansicht fehlte** – benutzt von `WandRahmen` und `HandRahmen`, geschrieben nie. Wie
/// `Ansichtswahl` ist sie dem Parser nicht aufgefallen: ein Aufruf eines Namens, den es nicht
/// gibt, ist syntaktisch einwandfrei. Der Kommentar an `Reiter.unter` im Kern nennt sie sogar
/// („Sie stehen als Umschalter unter der Reiterzeile") – sie war die ganze Zeit vorgesehen.
///
/// **`darfAlles` blendet aus, es sperrt nicht.** Ein Reiter mit `nurHausherr` verschwindet für
/// einen Gast aus der Zeile. Das ist Höflichkeit und keine Sicherheit: wer die Adresse kennt,
/// käme trotzdem hin. Gesperrt wird dort, wo es zählt – im Dienst, und im Dashboard im
/// BFF-Proxy (`apps/web/src/app/api/dch/[...path]/route.ts`). Dasselbe gilt hier: die App
/// zeigt einem Gast die Kachel nicht, aber verlassen darf sich darauf niemand.
///
/// **Sie rollt waagerecht**, wo sie nicht passt: eine Zeile, die umbricht, verschiebt den Inhalt
/// darunter bei jedem Wechsel. Rollen ist das kleinere Übel als ein springendes Gerippe.
///
/// **Ein Bereich mit Gruppen rollt am Telefon nicht mehr** (seit dem 23.11.2026, wie
/// `AreaNav.tsx`, `AreaTabs`). Am iPad stehen alle Gruppen in der Zeile, je mit ihrem Namen
/// davor. Am Telefon bleibt nur die Gruppe der Seite, auf der man steht, und davor der Weg
/// zurück zur Übersicht; die anderen Gruppen erreicht man dort.
struct Reiterzeile: View {
    let bereich: Bereich
    let aktiv: Reiter?
    let darfAlles: Bool
    /// Der Weg zur Übersicht eines Bereichs. Bereiche ohne Übersicht rufen ihn nie.
    var zurUebersicht: () -> Void = {}
    let waehle: (Reiter) -> Void

    private var sichtbar: [Reiter] {
        bereich.reiter.filter { darfAlles || !$0.nurHausherr }
    }

    /// Die Gruppen, die diese Zeile zeigt: am iPad alle, von denen dieser Betrachter etwas
    /// sieht, am Telefon nur die des gewählten Reiters.
    private var gruppen: [Gruppe] {
        bereich.gruppen.filter { gruppe in
            guard sichtbar.contains(where: { $0.gruppe == gruppe.name }) else { return false }
            return !schmal || aktiv?.gruppe == gruppe.name
        }
    }

    @Environment(\.horizontalSizeClass) private var breite
    private var schmal: Bool { breite == .compact }

    var body: some View {
        ScrollViewReader { leser in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Vor den Reitern steht der Weg zur Übersicht, wenn der Bereich eine hat
                    // (`AreaNav.tsx`, `mitUebersicht`). Gruppen ordnen danach nur, was folgt.
                    if bereich.hatUebersicht {
                        uebersichtsknopf
                    }
                    if bereich.gruppen.isEmpty {
                        ForEach(sichtbar) { r in
                            knopf(r, gewaehlt: r.weg == aktiv?.weg)
                                .id(r.weg)
                        }
                    } else {
                        ForEach(gruppen) { gruppe in
                            if !schmal {
                                Kicker(wort: gruppe.name, groesse: 10, farbe: Farbe.text3)
                                    .padding(.leading, 14)
                                    .accessibilityHidden(true)
                            }
                            ForEach(sichtbar.filter { $0.gruppe == gruppe.name }) { r in
                                knopf(r, gewaehlt: r.weg == aktiv?.weg)
                                    .id(r.weg)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            // **Zum gewaehlten Reiter rollen.** Technik hat fuer den Hausherrn elf Reiter, und
            // die Zeile faengt immer links an: wer aus einer Mitteilung direkt auf den neunten
            // springt, sieht eine Zeile ohne eine einzige markierte Pille und glaubt, er sei
            // woanders.
            .onAppear { zeige(leser, sofort: true) }
            .onChange(of: aktiv?.weg) { _, _ in zeige(leser, sofort: false) }
        }
        // Ohne das wächst die Zeile am Telefon in die Höhe des Rollbereichs.
        .frame(height: 44)
        // **Keine Trennlinie darunter** (`handy.css:163`: `border-bottom: 0`). Pillen brauchen
        // keinen Strich, der sie von der Seite trennt - sie liegen ohnehin auf ihr.
        .mask(rand)
    }

    /// Am Rand ausblenden, damit eine angeschnittene Pille nicht wie ein Fehler aussieht,
    /// sondern wie „da geht es weiter" (`handy.css:168-169`).
    ///
    /// **Nur am Telefon.** Am iPad passen die Reiter in eine Zeile; dort frisst die Maske in
    /// Pillen, die gar nicht angeschnitten sind.
    @ViewBuilder private var rand: some View {
        if schmal {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.035),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            Rectangle()
        }
    }

    private func zeige(_ leser: ScrollViewProxy, sofort: Bool) {
        guard let weg = aktiv?.weg else { return }
        if sofort {
            leser.scrollTo(weg, anchor: .center)
        } else {
            withAnimation(.easeInOut(duration: Marken.dauer)) {
                leser.scrollTo(weg, anchor: .center)
            }
        }
    }

    /// Der Weg zur Übersicht: am iPad das Wort, am Telefon nur der Pfeil. Mit dem Wort daneben
    /// passten drei Reiter einer Gruppe am Telefon nicht mehr in die Breite (`handy.css`,
    /// `.area-zurueck`). Gewählt ist er, wenn kein Reiter es ist: dann steht man auf ihr.
    private var uebersichtsknopf: some View {
        let gewaehlt = aktiv == nil
        return Button {
            if !gewaehlt { zurUebersicht() }
        } label: {
            pille(schmal ? "‹" : "Übersicht", gewaehlt: gewaehlt)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Übersicht \(bereich.name)")
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : [.isButton])
    }

    private func knopf(_ r: Reiter, gewaehlt: Bool) -> some View {
        Button {
            if !gewaehlt { waehle(r) }
        } label: {
            pille(r.name, gewaehlt: gewaehlt)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : [.isButton])
    }

    /// Die Pille, in der ein Reiter steht.
    private func pille(_ wort: String, gewaehlt: Bool) -> some View {
        Text(wort)
            .font(Schrift.sans(14))
            .fontWeight(gewaehlt ? .semibold : .regular)
            // **Weiss auf dunkel fuer den gewaehlten Reiter** (`handy.css:175`). Eine Pille,
            // die nur eine Spur heller ist als ihre Nachbarinnen, sagt nicht, wo man ist.
            .foregroundStyle(gewaehlt ? Farbe.deep : Farbe.text2)
            .lineLimit(1)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(gewaehlt ? Farbe.text1 : Color.white.opacity(0.07))
            )
    }
}

/// Das Zahnrad: der Weg zu „Einstellen“ und von dort zum System (`AreaNav.tsx`, `Systemknopf`).
///
/// Seit dem 24.11.2026 öffnet es „Einstellen“ und steht für jeden da, der im Haus stellen darf.
/// Die Systemseiten dahinter bleiben dem Hausherrn.
///
/// Die Verwaltung (Mitteilungen, Haustür, Hausgerät, Zugang, Daten prüfen) stand bis zum
/// 23.11.2026 als fünf Reiter zwischen den Seiten, die man täglich ansieht. Sie wird selten
/// gebraucht; darum liegt sie hinter einem Knopf im Kopf und belegt keinen Platz in der Leiste.
/// Ein Gast sieht den Knopf nicht.
struct Systemknopf: View {
    @Environment(Hauszustand.self) private var haus
    let wegweiser: Wegweiser
    /// Die Größe des Zeichens: 22 Punkte im Kopf der Wandanzeige, 20 am Telefon.
    var groesse: CGFloat = 22

    var body: some View {
        // Wer im Haus stellen darf, sieht das Zahnrad: dahinter liegt „Einstellen“ (24.11.2026).
        if haus.darfSchalten, let system = Bereiche.alle.first(where: { $0.schluessel == .system }) {
            let istAktiv = wegweiser.bereich.schluessel == .system
            Button {
                wegweiser.merkeReiter()
                wegweiser.geheZuBereich(system)
            } label: {
                Zeichen(
                    bereich: system.zeichen,
                    groesse: groesse,
                    farbe: istAktiv ? Farbe.petrol : Farbe.text3
                )
                .padding(8)
                .background(istAktiv ? Farbe.amber : .clear)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(system.name)
            .accessibilityAddTraits(istAktiv ? [.isSelected, .isButton] : .isButton)
        }
    }
}

/// Die Person: der Weg zum eigenen Zugang (`AreaNav.tsx`, `Kontoknopf`).
///
/// Passwort und Abmelden gehören jeder angemeldeten Person und nicht nur dem Hausherrn. Bis zum
/// 24.11.2026 standen sie auf „Zugang und Sicherung“ hinter dem Zahnrad, das ein Bewohner nicht
/// hat. Der Knopf steht deshalb neben dem Zahnrad und nicht dahinter. Ein Gerät mit dem
/// API-Token hat keinen eigenen Zugang und sieht den Knopf nicht.
struct Kontoknopf: View {
    @Environment(Hauszustand.self) private var haus
    let wegweiser: Wegweiser
    /// Die Größe des Zeichens: 22 Punkte im Kopf der Wandanzeige, 20 am Telefon.
    var groesse: CGFloat = 22

    var body: some View {
        if haus.zugang.istPerson, let seite = Bereiche.einzelseite(Bereiche.kontoweg) {
            let istAktiv = wegweiser.einzelseite?.weg == seite.weg
            Button {
                wegweiser.merkeReiter()
                wegweiser.gehe(seite.weg)
            } label: {
                Zeichen(
                    bereich: seite.zeichen,
                    groesse: groesse,
                    farbe: istAktiv ? Farbe.petrol : Farbe.text3
                )
                .padding(8)
                .background(istAktiv ? Farbe.amber : .clear)
                .clipShape(RoundedRectangle(cornerRadius: Marken.radius3, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(seite.name)
            .accessibilityAddTraits(istAktiv ? [.isSelected, .isButton] : .isButton)
        }
    }
}

#if DEBUG
    #Preview("Reiterzeile") {
        let anlage = Bereiche.alle.first { $0.schluessel == .anlage }!
        return VStack(spacing: 24) {
            Reiterzeile(bereich: anlage, aktiv: anlage.reiter.first, darfAlles: true) { _ in }
            // Als Gast: die Reiter mit `nurHausherr` fallen weg.
            Reiterzeile(bereich: anlage, aktiv: nil, darfAlles: false) { _ in }
        }
        .background(Farbe.grund)
    }
#endif
