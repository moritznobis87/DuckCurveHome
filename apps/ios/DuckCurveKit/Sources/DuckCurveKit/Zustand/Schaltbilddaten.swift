// Erzeugt von tools/gen-schaltbild.py aus docs/regelkreis-schaltbild.json.
// Nicht von Hand aendern - neu erzeugen mit `tools/gen-schaltbild.py`.
//
// Die Geometrie des Regelkreis-Schaltbilds: wo jedes Kaestchen liegt, wie jede Leitung
// laeuft und was an ihr steht. Dieselben Zahlen wie im Dashboard
// (`apps/web/src/components/regelkreis/layout.ts`).

public enum Schaltbilddaten {
    public static let breite: Double = 1400
    public static let hoehe: Double = 1300

    /// Die Ebenen zum Hineinzoomen, in der Reihenfolge ihrer Knoepfe.
    public static let sichten: [Schaltbild.Sicht] = [
        Schaltbild.Sicht(schluessel: "alles", name: "Alles", ausschnitt: Schaltbild.Rechteck(x: 0, y: 0, w: 1400, h: 1300)),
        Schaltbild.Sicht(schluessel: "e4", name: "E4 Ökonomie", ausschnitt: Schaltbild.Rechteck(x: 0, y: 20, w: 1400, h: 340)),
        Schaltbild.Sicht(schluessel: "e3", name: "E3+E2 Erzeuger", ausschnitt: Schaltbild.Rechteck(x: 0, y: 330, w: 1400, h: 420)),
        Schaltbild.Sicht(schluessel: "e1", name: "E1 Vorlauf", ausschnitt: Schaltbild.Rechteck(x: 0, y: 700, w: 1400, h: 320)),
        Schaltbild.Sicht(schluessel: "e0", name: "E0 Räume", ausschnitt: Schaltbild.Rechteck(x: 0, y: 960, w: 1400, h: 340)),
    ]

    /// Hauptrechteck je Block, dazu die Wiederholungen.
    public static let plaetze: [String: Schaltbild.Platz] = [
        "preis": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 28, y: 62, w: 118, h: 40), wdh: []),
        "pv_ist": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 160, y: 62, w: 118, h: 40), wdh: []),
        "speicher": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 292, y: 62, w: 118, h: 40), wdh: []),
        "pelletpreis": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 424, y: 62, w: 118, h: 40), wdh: []),
        "strahlung": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 556, y: 62, w: 118, h: 40), wdh: [Schaltbild.Rechteck(x: 594, y: 996, w: 112, h: 34)]),
        "aussen": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 688, y: 62, w: 118, h: 40), wdh: [Schaltbild.Rechteck(x: 330, y: 366, w: 140, h: 34), Schaltbild.Rechteck(x: 28, y: 736, w: 118, h: 34), Schaltbild.Rechteck(x: 470, y: 996, w: 112, h: 34)]),
        "kosten_wp": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 28, y: 150, w: 168, h: 84), wdh: []),
        "kosten_ofen": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 216, y: 150, w: 160, h: 84), wdh: []),
        "pv": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 396, y: 150, w: 150, h: 84), wdh: []),
        "bedarf": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 566, y: 150, w: 170, h: 84), wdh: []),
        "komfort": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 756, y: 150, w: 172, h: 84), wdh: []),
        "fahrplan": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 1000, y: 150, w: 280, h: 170), wdh: []),
        "abtauung": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 330, y: 408, w: 140, h: 34), wdh: []),
        "cop": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 486, y: 360, w: 184, h: 100), wdh: []),
        "warmwasser": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 700, y: 408, w: 150, h: 34), wdh: []),
        "aufstellraum": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 872, y: 408, w: 132, h: 34), wdh: []),
        "summe_soc": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 57, y: 511, w: 34, h: 34), wdh: []),
        "puffer_regler": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 112, y: 486, w: 162, h: 84), wdh: []),
        "zuordnung": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 302, y: 486, w: 160, h: 84), wdh: []),
        "wp": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 486, y: 486, w: 184, h: 84), wdh: []),
        "ofen": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 486, y: 612, w: 184, h: 84), wdh: [Schaltbild.Rechteck(x: 970, y: 996, w: 140, h: 34)]),
        "summe_waerme": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 683, y: 511, w: 34, h: 34), wdh: []),
        "puffer": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 752, y: 458, w: 196, h: 122), wdh: []),
        "beobachter": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 988, y: 486, w: 184, h: 84), wdh: []),
        "kennlinie": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 28, y: 796, w: 172, h: 84), wdh: []),
        "leitventil": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 228, y: 796, w: 172, h: 84), wdh: []),
        "summe_vl": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 421, y: 821, w: 34, h: 34), wdh: []),
        "vl_regler": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 476, y: 796, w: 160, h: 84), wdh: []),
        "heizkreis": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 664, y: 796, w: 190, h: 84), wdh: []),
        "vl_fuehler": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 900, y: 872, w: 160, h: 44), wdh: []),
        "intern": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 718, y: 996, w: 112, h: 34), wdh: []),
        "fenster": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 842, y: 996, w: 112, h: 34), wdh: []),
        "summe_raum": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 57, y: 1111, w: 34, h: 34), wdh: []),
        "raum_regler": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 112, y: 1086, w: 170, h: 84), wdh: []),
        "ventil": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 310, y: 1086, w: 160, h: 84), wdh: []),
        "raum": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 560, y: 1068, w: 220, h: 120), wdh: []),
        "raum_fuehler": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 560, y: 1216, w: 160, h: 44), wdh: []),
        "weitere_raeume": Schaltbild.Platz(rect: Schaltbild.Rechteck(x: 900, y: 1086, w: 200, h: 120), wdh: []),
    ]

    /// Die Leitungen, nach „von→nach“ der Topologie.
    public static let wege: [String: Schaltbild.Weg] = [
        "preis→kosten_wp": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 87, y: 102), Schaltbild.Punkt(x: 87, y: 122), Schaltbild.Punkt(x: 60, y: 122), Schaltbild.Punkt(x: 60, y: 150)], bogen: nil),
        "pv_ist→kosten_wp": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 219, y: 102), Schaltbild.Punkt(x: 219, y: 130), Schaltbild.Punkt(x: 112, y: 130), Schaltbild.Punkt(x: 112, y: 150)], bogen: nil),
        "speicher→kosten_wp": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 351, y: 102), Schaltbild.Punkt(x: 351, y: 138), Schaltbild.Punkt(x: 170, y: 138), Schaltbild.Punkt(x: 170, y: 150)], bogen: nil),
        "pelletpreis→kosten_ofen": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 483, y: 102), Schaltbild.Punkt(x: 483, y: 114), Schaltbild.Punkt(x: 360, y: 114), Schaltbild.Punkt(x: 360, y: 150)], bogen: nil),
        "strahlung→pv": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 615, y: 102), Schaltbild.Punkt(x: 615, y: 110), Schaltbild.Punkt(x: 430, y: 110), Schaltbild.Punkt(x: 430, y: 150)], bogen: nil),
        "aussen→bedarf": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 747, y: 102), Schaltbild.Punkt(x: 747, y: 118), Schaltbild.Punkt(x: 700, y: 118), Schaltbild.Punkt(x: 700, y: 150)], bogen: nil),
        "pv→bedarf": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 546, y: 192), Schaltbild.Punkt(x: 566, y: 192)], bogen: nil),
        "kosten_wp→fahrplan": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 112, y: 234), Schaltbild.Punkt(x: 112, y: 294), Schaltbild.Punkt(x: 1000, y: 294)], bogen: nil),
        "kosten_ofen→fahrplan": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 296, y: 234), Schaltbild.Punkt(x: 296, y: 282), Schaltbild.Punkt(x: 1000, y: 282)], bogen: nil),
        "pv→fahrplan": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 471, y: 234), Schaltbild.Punkt(x: 471, y: 270), Schaltbild.Punkt(x: 1000, y: 270)], bogen: nil),
        "bedarf→fahrplan": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 651, y: 234), Schaltbild.Punkt(x: 651, y: 258), Schaltbild.Punkt(x: 1000, y: 258)], bogen: nil),
        "komfort→fahrplan": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 842, y: 234), Schaltbild.Punkt(x: 842, y: 246), Schaltbild.Punkt(x: 1000, y: 246)], bogen: nil),
        "fahrplan→summe_soc": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 1140, y: 320), Schaltbild.Punkt(x: 1140, y: 338), Schaltbild.Punkt(x: 14, y: 338), Schaltbild.Punkt(x: 14, y: 528), Schaltbild.Punkt(x: 57, y: 528)], bogen: nil),
        "fahrplan→kennlinie": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 14, y: 560), Schaltbild.Punkt(x: 14, y: 838), Schaltbild.Punkt(x: 28, y: 838)], bogen: nil),
        "fahrplan→summe_raum": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 14, y: 860), Schaltbild.Punkt(x: 14, y: 1128), Schaltbild.Punkt(x: 57, y: 1128)], bogen: nil),
        "fahrplan→zuordnung": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 320, y: 338), Schaltbild.Punkt(x: 320, y: 486)], bogen: nil),
        "aussen→cop": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 470, y: 383), Schaltbild.Punkt(x: 486, y: 383)], bogen: nil),
        "aussen→kennlinie": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 87, y: 770), Schaltbild.Punkt(x: 87, y: 796)], bogen: nil),
        "aussen→raum": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 526, y: 1030), Schaltbild.Punkt(x: 526, y: 1040), Schaltbild.Punkt(x: 580, y: 1040), Schaltbild.Punkt(x: 580, y: 1068)], bogen: nil),
        "strahlung→raum": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 650, y: 1030), Schaltbild.Punkt(x: 650, y: 1046), Schaltbild.Punkt(x: 620, y: 1046), Schaltbild.Punkt(x: 620, y: 1068)], bogen: nil),
        "abtauung→wp": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 400, y: 442), Schaltbild.Punkt(x: 400, y: 468), Schaltbild.Punkt(x: 520, y: 468), Schaltbild.Punkt(x: 520, y: 486)], bogen: nil),
        "cop→wp": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 600, y: 460), Schaltbild.Punkt(x: 600, y: 486)], bogen: nil),
        "bedarf→puffer_regler": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 620, y: 234), Schaltbild.Punkt(x: 620, y: 330), Schaltbild.Punkt(x: 193, y: 330), Schaltbild.Punkt(x: 193, y: 486)], bogen: nil),
        "summe_soc→puffer_regler": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 91, y: 528), Schaltbild.Punkt(x: 112, y: 528)], bogen: nil),
        "puffer_regler→zuordnung": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 274, y: 528), Schaltbild.Punkt(x: 302, y: 528)], bogen: nil),
        "zuordnung→wp": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 462, y: 528), Schaltbild.Punkt(x: 486, y: 528)], bogen: nil),
        "zuordnung→ofen": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 462, y: 528), Schaltbild.Punkt(x: 474, y: 528), Schaltbild.Punkt(x: 474, y: 654), Schaltbild.Punkt(x: 486, y: 654)], bogen: nil),
        "wp→summe_waerme": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 670, y: 528), Schaltbild.Punkt(x: 683, y: 528)], bogen: nil),
        "ofen→summe_waerme": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 670, y: 654), Schaltbild.Punkt(x: 700, y: 654), Schaltbild.Punkt(x: 700, y: 545)], bogen: nil),
        "summe_waerme→puffer": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 717, y: 528), Schaltbild.Punkt(x: 752, y: 528)], bogen: nil),
        "warmwasser→puffer": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 765, y: 442), Schaltbild.Punkt(x: 765, y: 450), Schaltbild.Punkt(x: 800, y: 450), Schaltbild.Punkt(x: 800, y: 458)], bogen: nil),
        "aufstellraum→puffer": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 938, y: 442), Schaltbild.Punkt(x: 938, y: 450), Schaltbild.Punkt(x: 920, y: 450), Schaltbild.Punkt(x: 920, y: 458)], bogen: nil),
        "heizkreis→puffer": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 800, y: 796), Schaltbild.Punkt(x: 800, y: 580)], bogen: Schaltbild.Punkt(x: 800, y: 716)),
        "puffer→beobachter": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 948, y: 528), Schaltbild.Punkt(x: 988, y: 528)], bogen: nil),
        "beobachter→summe_soc": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 1172, y: 528), Schaltbild.Punkt(x: 1300, y: 528), Schaltbild.Punkt(x: 1300, y: 716), Schaltbild.Punkt(x: 74, y: 716), Schaltbild.Punkt(x: 74, y: 545)], bogen: nil),
        "kennlinie→leitventil": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 200, y: 838), Schaltbild.Punkt(x: 228, y: 838)], bogen: nil),
        "leitventil→summe_vl": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 400, y: 838), Schaltbild.Punkt(x: 421, y: 838)], bogen: nil),
        "summe_vl→vl_regler": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 455, y: 838), Schaltbild.Punkt(x: 476, y: 838)], bogen: nil),
        "vl_regler→heizkreis": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 636, y: 838), Schaltbild.Punkt(x: 664, y: 838)], bogen: nil),
        "heizkreis→vl_fuehler": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 854, y: 838), Schaltbild.Punkt(x: 1090, y: 838), Schaltbild.Punkt(x: 1090, y: 950), Schaltbild.Punkt(x: 1060, y: 950)], bogen: nil),
        "vl_fuehler→summe_vl": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 900, y: 950), Schaltbild.Punkt(x: 438, y: 950), Schaltbild.Punkt(x: 438, y: 855)], bogen: nil),
        "heizkreis→ventil": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 854, y: 838), Schaltbild.Punkt(x: 884, y: 838), Schaltbild.Punkt(x: 884, y: 912), Schaltbild.Punkt(x: 420, y: 912), Schaltbild.Punkt(x: 420, y: 1086)], bogen: nil),
        "heizkreis→weitere_raeume": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 884, y: 838), Schaltbild.Punkt(x: 955, y: 838), Schaltbild.Punkt(x: 955, y: 1086)], bogen: nil),
        "heizkreis→cop": Schaltbild.Weg(punkte: [], bogen: nil),
        "cop→kosten_wp": Schaltbild.Weg(punkte: [], bogen: nil),
        "raum_regler→leitventil": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 296, y: 1128), Schaltbild.Punkt(x: 296, y: 880)], bogen: nil),
        "weitere_raeume→leitventil": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 900, y: 1146), Schaltbild.Punkt(x: 840, y: 1146)], bogen: nil),
        "summe_raum→raum_regler": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 91, y: 1128), Schaltbild.Punkt(x: 112, y: 1128)], bogen: nil),
        "raum_regler→ventil": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 282, y: 1128), Schaltbild.Punkt(x: 310, y: 1128)], bogen: nil),
        "ventil→raum": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 470, y: 1128), Schaltbild.Punkt(x: 560, y: 1128)], bogen: nil),
        "intern→raum": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 774, y: 1030), Schaltbild.Punkt(x: 774, y: 1052), Schaltbild.Punkt(x: 660, y: 1052), Schaltbild.Punkt(x: 660, y: 1068)], bogen: nil),
        "fenster→raum": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 898, y: 1030), Schaltbild.Punkt(x: 898, y: 1058), Schaltbild.Punkt(x: 700, y: 1058), Schaltbild.Punkt(x: 700, y: 1068)], bogen: nil),
        "ofen→raum": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 1040, y: 1030), Schaltbild.Punkt(x: 1040, y: 1064), Schaltbild.Punkt(x: 740, y: 1064), Schaltbild.Punkt(x: 740, y: 1068)], bogen: nil),
        "raum→raum_fuehler": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 700, y: 1188), Schaltbild.Punkt(x: 700, y: 1216)], bogen: nil),
        "raum_fuehler→summe_raum": Schaltbild.Weg(punkte: [Schaltbild.Punkt(x: 560, y: 1238), Schaltbild.Punkt(x: 74, y: 1238), Schaltbild.Punkt(x: 74, y: 1145)], bogen: nil),
    ]

    /// Beschriftungen, die nicht am Kaestchen, sondern an der Leitung stehen.
    public static let beschriftungen: [Schaltbild.Beschriftung] = [
        Schaltbild.Beschriftung(x: 520, y: 331, text: "Führungsgrößen: wSOC(t) · Fahrplan Ofen · Freigabefenster · wi", anker: .middle),
        Schaltbild.Beschriftung(x: 680, y: 710, text: "SOCth und Q̇ab als Rückführung des Beobachters", anker: .middle),
        Schaltbild.Beschriftung(x: 302, y: 1000, text: "hi aller Räume", anker: .start),
        Schaltbild.Beschriftung(x: 430, y: 906, text: "TVL in die Heizkreise", anker: .start),
        Schaltbild.Beschriftung(x: 806, y: 640, text: "Q̇HK (Entnahme)", anker: .start),
        Schaltbild.Beschriftung(x: 320, y: 1232, text: "Ti als Rückführung", anker: .middle),
    ]

    /// Die Ebenenaufschriften.
    public static let ebenen: [Schaltbild.Beschriftung] = [
        Schaltbild.Beschriftung(x: 28, y: 44, text: "EBENE 4 · ÖKONOMISCHE FÜHRUNG · TAKT 15 MIN, HORIZONT 48 H", anker: .start),
        Schaltbild.Beschriftung(x: 28, y: 380, text: "EBENE 3 + 2 ·", anker: .start),
        Schaltbild.Beschriftung(x: 28, y: 394, text: "SPEICHER UND ERZEUGER", anker: .start),
        Schaltbild.Beschriftung(x: 28, y: 786, text: "EBENE 1 · VORLAUFTEMPERATUR UND VERTEILUNG", anker: .start),
        Schaltbild.Beschriftung(x: 28, y: 1062, text: "EBENE 0 · EINZELRAUMREGELUNG · 10 KREISE", anker: .start),
    ]
}
