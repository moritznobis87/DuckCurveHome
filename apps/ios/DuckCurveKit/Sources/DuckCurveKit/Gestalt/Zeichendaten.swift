// Erzeugt von tools/gen-zeichen.py aus apps/web/src/components/ui/Icon.tsx.
// Nicht von Hand aendern - neu erzeugen mit `tools/gen-zeichen.py`.
//
// Die Zeichen des Dashboards: 33 Strichzeichnungen auf einem 24-Punkt-Raster, 1,75 Punkt
// Strich, runde Enden, kein Emoji. Kreise und Rechtecke sind beim Uebernehmen zu
// Pfadangaben gerechnet worden.

/// Die Zeichen, unter ihren Namen in der App.
public enum Zeichenart: String, Sendable, Hashable, CaseIterable {
    case anzeige
    case auto
    case batterie
    case blitz
    case diagramm
    case ente
    case euro
    case flamme
    case geraet
    case glocke
    case haus
    case kaffee
    case kalender
    case kreis
    case lampe
    case lupe
    case mond
    case netz
    case ofen
    case person
    case schieber
    case schild
    case schloss
    case schluessel
    case sonne
    case tabelle
    case thermometer
    case tuer
    case uhr
    case waermepumpe
    case warnung
    case zahnrad
    case ziel
}

extension Zeichenart {
    /// Das Raster, auf dem alle Zeichen gezeichnet sind.
    public static let raster: Double = 24

    /// Die Formen dieses Zeichens: Pfadangabe und ob sie gefuellt wird.
    public var formen: [(d: String, gefuellt: Bool)] {
        switch self {
        case .anzeige:
            return [
                (d: "M 4.5 3.0 L 9.0 3.0 C 9.82842712474619 3.0 10.5 3.6715728752538097 10.5 4.5 L 10.5 9.0 C 10.5 9.82842712474619 9.82842712474619 10.5 9.0 10.5 L 4.5 10.5 C 3.6715728752538097 10.5 3.0 9.82842712474619 3.0 9.0 L 3.0 4.5 C 3.0 3.6715728752538097 3.6715728752538097 3.0 4.5 3.0 Z", gefuellt: false),
                (d: "M 15.0 3.0 L 19.5 3.0 C 20.32842712474619 3.0 21.0 3.6715728752538097 21.0 4.5 L 21.0 9.0 C 21.0 9.82842712474619 20.32842712474619 10.5 19.5 10.5 L 15.0 10.5 C 14.17157287525381 10.5 13.5 9.82842712474619 13.5 9.0 L 13.5 4.5 C 13.5 3.6715728752538097 14.17157287525381 3.0 15.0 3.0 Z", gefuellt: false),
                (d: "M 4.5 13.5 L 9.0 13.5 C 9.82842712474619 13.5 10.5 14.17157287525381 10.5 15.0 L 10.5 19.5 C 10.5 20.32842712474619 9.82842712474619 21.0 9.0 21.0 L 4.5 21.0 C 3.6715728752538097 21.0 3.0 20.32842712474619 3.0 19.5 L 3.0 15.0 C 3.0 14.17157287525381 3.6715728752538097 13.5 4.5 13.5 Z", gefuellt: false),
                (d: "M 15.0 13.5 L 19.5 13.5 C 20.32842712474619 13.5 21.0 14.17157287525381 21.0 15.0 L 21.0 19.5 C 21.0 20.32842712474619 20.32842712474619 21.0 19.5 21.0 L 15.0 21.0 C 14.17157287525381 21.0 13.5 20.32842712474619 13.5 19.5 L 13.5 15.0 C 13.5 14.17157287525381 14.17157287525381 13.5 15.0 13.5 Z", gefuellt: false),
            ]
        case .auto:
            return [
                (d: "M3.5 14.3 5.1 9.9a2 2 0 0 1 1.9-1.4h8.6a2 2 0 0 1 1.7 1l2.5 4.8", gefuellt: false),
                (d: "M3.5 14.3h17v3.4a1 1 0 0 1-1 1h-1.4M3.5 14.3v3.4a1 1 0 0 0 1 1h1.4", gefuellt: false),
                (d: "M 8.1 16.5 C 9.149341024678508 16.5 10.0 17.35065897532149 10.0 18.4 C 10.0 19.449341024678507 9.149341024678508 20.299999999999997 8.1 20.299999999999997 C 7.050658975321491 20.299999999999997 6.199999999999999 19.449341024678507 6.199999999999999 18.4 C 6.199999999999999 17.35065897532149 7.050658975321491 16.5 8.1 16.5 Z", gefuellt: false),
                (d: "M 15.9 16.5 C 16.949341024678507 16.5 17.8 17.35065897532149 17.8 18.4 C 17.8 19.449341024678507 16.949341024678507 20.299999999999997 15.9 20.299999999999997 C 14.850658975321492 20.299999999999997 14.0 19.449341024678507 14.0 18.4 C 14.0 17.35065897532149 14.850658975321492 16.5 15.9 16.5 Z", gefuellt: false),
                (d: "M10 18.7h4", gefuellt: false),
            ]
        case .batterie:
            return [
                (d: "M 4.7 7.0 L 16.8 7.0 C 18.015026449627747 7.0 19.0 7.984973550372254 19.0 9.2 L 19.0 14.8 C 19.0 16.015026449627747 18.015026449627747 17.0 16.8 17.0 L 4.7 17.0 C 3.4849735503722545 17.0 2.5 16.015026449627747 2.5 14.8 L 2.5 9.2 C 2.5 7.984973550372254 3.4849735503722545 7.0 4.7 7.0 Z", gefuellt: false),
                (d: "M21.5 10.4v3.2", gefuellt: false),
                (d: "M 6.1 9.6 L 10.5 9.6 C 11.052284749830793 9.6 11.5 10.047715250169206 11.5 10.6 L 11.5 13.399999999999999 C 11.5 13.952284749830792 11.052284749830793 14.399999999999999 10.5 14.399999999999999 L 6.1 14.399999999999999 C 5.547715250169206 14.399999999999999 5.1 13.952284749830792 5.1 13.399999999999999 L 5.1 10.6 C 5.1 10.047715250169206 5.547715250169206 9.6 6.1 9.6 Z", gefuellt: true),
            ]
        case .blitz:
            return [
                (d: "M13.2 2.5 5.6 13.4h5.2L10.6 21.5l7.8-11.2h-5.3z", gefuellt: false),
            ]
        case .diagramm:
            return [
                (d: "M3 20h18", gefuellt: false),
                (d: "M5.5 17v-6", gefuellt: false),
                (d: "M10.2 17V6.5", gefuellt: false),
                (d: "M14.8 17v-4.5", gefuellt: false),
                (d: "M19.5 17V8.5", gefuellt: false),
            ]
        case .ente:
            return [
                (d: "M 2 15.46 C 4.48 13.11 6.35 15.9 9.01 15.99 C 13.18 16.12 13.88 12.84 16.24 9.52 C 17.39 7.88 19.25 8.19 19.69 9.74 C 19.96 10.67 20.71 10.85 22 11.07 C 21.07 11.56 20.27 11.6 19.43 12.04", gefuellt: false),
            ]
        case .euro:
            return [
                (d: "M18.2 6.6A7.4 7.4 0 1 0 18.2 17.4", gefuellt: false),
                (d: "M4 10.4h10M4 13.6h10", gefuellt: false),
            ]
        case .flamme:
            return [
                (d: "M12 2.5c.9 3.3 4.6 5 5.6 8.6 1.1 4-1.6 8.4-5.6 8.4s-6.7-4.4-5.6-8.4c.4-1.6 1.4-2.9 2.4-4.1.4 1.4 1.1 2.4 2.2 2.9C10.5 7.6 10.8 5 12 2.5z", gefuellt: false),
                (d: "M12 19.5c-1.8 0-3-1.4-2.7-3 .2-1 .9-1.8 1.6-2.6.3.8.8 1.3 1.5 1.5.3-1 .5-1.8 1-2.6 1.1 1.1 1.9 2.4 1.6 3.8-.3 1.7-1.4 2.9-3 2.9z", gefuellt: false),
            ]
        case .geraet:
            return [
                (d: "M 8.9 2.5 L 15.1 2.5 C 16.425483399593904 2.5 17.5 3.5745166004060955 17.5 4.9 L 17.5 19.1 C 17.5 20.425483399593904 16.425483399593904 21.5 15.1 21.5 L 8.9 21.5 C 7.5745166004060955 21.5 6.5 20.425483399593904 6.5 19.1 L 6.5 4.9 C 6.5 3.5745166004060955 7.5745166004060955 2.5 8.9 2.5 Z", gefuellt: false),
                (d: "M10.8 18.4h2.4", gefuellt: false),
            ]
        case .glocke:
            return [
                (d: "M6.2 16.8h11.6c-1.1-1.2-1.6-2.9-1.6-4.9v-1.1a4.2 4.2 0 0 0-8.4 0v1.1c0 2-.5 3.7-1.6 4.9z", gefuellt: false),
                (d: "M10.3 19.6a1.8 1.8 0 0 0 3.4 0", gefuellt: false),
                (d: "M12 4.1v2.5", gefuellt: false),
            ]
        case .haus:
            return [
                (d: "M3.5 11.2 12 4l8.5 7.2", gefuellt: false),
                (d: "M5.8 9.8V20h12.4V9.8", gefuellt: false),
                (d: "M10 20v-5.5h4V20", gefuellt: false),
                (d: "M16.3 4.9h2v2.9", gefuellt: false),
            ]
        case .kaffee:
            return [
                (d: "M4.5 9h11.5v5.4a4.6 4.6 0 0 1-4.6 4.6H9.1a4.6 4.6 0 0 1-4.6-4.6z", gefuellt: false),
                (d: "M16 10.6h1.8a2.2 2.2 0 0 1 0 4.4H16", gefuellt: false),
                (d: "M8.3 3.6c-.9 1-.9 1.9 0 2.9M11.7 3.6c-.9 1-.9 1.9 0 2.9", gefuellt: false),
            ]
        case .kalender:
            return [
                (d: "M 5.0 4.0 L 19.0 4.0 C 20.104569499661586 4.0 21.0 4.895430500338413 21.0 6.0 L 21.0 19.0 C 21.0 20.104569499661586 20.104569499661586 21.0 19.0 21.0 L 5.0 21.0 C 3.8954305003384126 21.0 3.0 20.104569499661586 3.0 19.0 L 3.0 6.0 C 3.0 4.895430500338413 3.8954305003384126 4.0 5.0 4.0 Z", gefuellt: false),
                (d: "M3 9h18", gefuellt: false),
                (d: "M9 9v12M15 9v12", gefuellt: false),
                (d: "M3 15h18", gefuellt: false),
            ]
        case .kreis:
            return [
                (d: "M3 8h5", gefuellt: false),
                (d: "M 9.4 5.0 L 14.6 5.0 C 15.373198649763111 5.0 16.0 5.62680135023689 16.0 6.4 L 16.0 9.6 C 16.0 10.373198649763111 15.373198649763111 11.0 14.6 11.0 L 9.4 11.0 C 8.626801350236889 11.0 8.0 10.373198649763111 8.0 9.6 L 8.0 6.4 C 8.0 5.62680135023689 8.626801350236889 5.0 9.4 5.0 Z", gefuellt: false),
                (d: "M16 8h5", gefuellt: false),
                (d: "M18.5 8v9.5h-13v-6.9", gefuellt: false),
                (d: "M3.6 12.4l1.9-1.9 1.9 1.9", gefuellt: false),
            ]
        case .lampe:
            return [
                (d: "M9.3 17.6h5.4", gefuellt: false),
                (d: "M10.2 20.5h3.6", gefuellt: false),
                (d: "M8.6 14.3a5.7 5.7 0 1 1 6.8 0c-.7.6-1.1 1.5-1.1 2.4H9.7c0-.9-.4-1.8-1.1-2.4z", gefuellt: false),
            ]
        case .lupe:
            return [
                (d: "M 10.6 4.199999999999999 C 14.13462239891708 4.199999999999999 17.0 7.06537760108292 17.0 10.6 C 17.0 14.13462239891708 14.13462239891708 17.0 10.6 17.0 C 7.06537760108292 17.0 4.199999999999999 14.13462239891708 4.199999999999999 10.6 C 4.199999999999999 7.06537760108292 7.06537760108292 4.199999999999999 10.6 4.199999999999999 Z", gefuellt: false),
                (d: "M15.3 15.3 20.5 20.5", gefuellt: false),
            ]
        case .mond:
            return [
                (d: "M20.3 14.2A8.4 8.4 0 1 1 9.8 3.7a6.7 6.7 0 0 0 10.5 10.5z", gefuellt: false),
            ]
        case .netz:
            return [
                (d: "M9.4 3h5.2", gefuellt: false),
                (d: "M10.2 3 5.5 21M13.8 3l4.7 18", gefuellt: false),
                (d: "M3.8 8.6h16.4", gefuellt: false),
                (d: "M6.4 14.4h11.2", gefuellt: false),
            ]
        case .ofen:
            return [
                (d: "M 6.0 2.6 L 18.0 2.6 C 19.104569499661586 2.6 20.0 3.4954305003384123 20.0 4.6 L 20.0 18.400000000000002 C 20.0 19.50456949966159 19.104569499661586 20.400000000000002 18.0 20.400000000000002 L 6.0 20.400000000000002 C 4.895430500338413 20.400000000000002 4.0 19.50456949966159 4.0 18.400000000000002 L 4.0 4.6 C 4.0 3.4954305003384123 4.895430500338413 2.6 6.0 2.6 Z", gefuellt: false),
                (d: "M4 7.5h16", gefuellt: false),
                (d: "M12 10.6c1.7 1.7 2.7 2.9 2.7 4.3a2.7 2.7 0 0 1-5.4 0c0-1.4 1-2.6 2.7-4.3z", gefuellt: false),
                (d: "M7.5 20.4v1.4M16.5 20.4v1.4", gefuellt: false),
            ]
        case .person:
            return [
                (d: "M 12.0 4.1 C 14.153910524340095 4.1 15.9 5.846089475659905 15.9 8.0 C 15.9 10.153910524340095 14.153910524340095 11.9 12.0 11.9 C 9.846089475659905 11.9 8.1 10.153910524340095 8.1 8.0 C 8.1 5.846089475659905 9.846089475659905 4.1 12.0 4.1 Z", gefuellt: false),
                (d: "M4.3 20.5c.7-3.9 3.8-6.4 7.7-6.4s7 2.5 7.7 6.4", gefuellt: false),
            ]
        case .schieber:
            return [
                (d: "M4 7h9M17 7h3M4 12h3M11 12h9M4 17h11M19 17h1", gefuellt: false),
                (d: "M 15.0 5.0 C 16.104569499661586 5.0 17.0 5.895430500338413 17.0 7.0 C 17.0 8.104569499661586 16.104569499661586 9.0 15.0 9.0 C 13.895430500338414 9.0 13.0 8.104569499661586 13.0 7.0 C 13.0 5.895430500338413 13.895430500338414 5.0 15.0 5.0 Z", gefuellt: false),
                (d: "M 9.0 10.0 C 10.104569499661586 10.0 11.0 10.895430500338414 11.0 12.0 C 11.0 13.104569499661586 10.104569499661586 14.0 9.0 14.0 C 7.895430500338413 14.0 7.0 13.104569499661586 7.0 12.0 C 7.0 10.895430500338414 7.895430500338413 10.0 9.0 10.0 Z", gefuellt: false),
                (d: "M 17.0 15.0 C 18.104569499661586 15.0 19.0 15.895430500338414 19.0 17.0 C 19.0 18.104569499661586 18.104569499661586 19.0 17.0 19.0 C 15.895430500338414 19.0 15.0 18.104569499661586 15.0 17.0 C 15.0 15.895430500338414 15.895430500338414 15.0 17.0 15.0 Z", gefuellt: false),
            ]
        case .schild:
            return [
                (d: "M12 3 5 5.8v5.3c0 4.3 3 7.7 7 8.9 4-1.2 7-4.6 7-8.9V5.8z", gefuellt: false),
                (d: "M9.2 12.2l2 2 3.8-4", gefuellt: false),
            ]
        case .schloss:
            return [
                (d: "M 6.7 10.5 L 17.3 10.5 C 18.515026449627747 10.5 19.5 11.484973550372253 19.5 12.7 L 19.5 18.8 C 19.5 20.015026449627747 18.515026449627747 21.0 17.3 21.0 L 6.7 21.0 C 5.4849735503722545 21.0 4.5 20.015026449627747 4.5 18.8 L 4.5 12.7 C 4.5 11.484973550372253 5.4849735503722545 10.5 6.7 10.5 Z", gefuellt: false),
                (d: "M8 10.5V7.6a4 4 0 0 1 8 0v2.9", gefuellt: false),
                (d: "M12 14.6v2.4", gefuellt: false),
            ]
        case .schluessel:
            return [
                (d: "M 7.8 11.899999999999999 C 10.174824424272412 11.899999999999999 12.1 13.825175575727588 12.1 16.2 C 12.1 18.57482442427241 10.174824424272412 20.5 7.8 20.5 C 5.425175575727588 20.5 3.5 18.57482442427241 3.5 16.2 C 3.5 13.825175575727588 5.425175575727588 11.899999999999999 7.8 11.899999999999999 Z", gefuellt: false),
                (d: "M10.9 13.1 20 4", gefuellt: false),
                (d: "M16.6 7.4l2.6 2.6", gefuellt: false),
                (d: "M14 10l1.9 1.9", gefuellt: false),
            ]
        case .sonne:
            return [
                (d: "M 12.0 8.1 C 14.153910524340095 8.1 15.9 9.846089475659905 15.9 12.0 C 15.9 14.153910524340095 14.153910524340095 15.9 12.0 15.9 C 9.846089475659905 15.9 8.1 14.153910524340095 8.1 12.0 C 8.1 9.846089475659905 9.846089475659905 8.1 12.0 8.1 Z", gefuellt: false),
                (d: "M12 2.5v2.3M12 19.2v2.3M2.5 12h2.3M19.2 12h2.3M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6", gefuellt: false),
            ]
        case .tabelle:
            return [
                (d: "M 5.0 4.0 L 19.0 4.0 C 20.104569499661586 4.0 21.0 4.895430500338413 21.0 6.0 L 21.0 18.0 C 21.0 19.104569499661586 20.104569499661586 20.0 19.0 20.0 L 5.0 20.0 C 3.8954305003384126 20.0 3.0 19.104569499661586 3.0 18.0 L 3.0 6.0 C 3.0 4.895430500338413 3.8954305003384126 4.0 5.0 4.0 Z", gefuellt: false),
                (d: "M3 9h18", gefuellt: false),
                (d: "M9 9v11", gefuellt: false),
                (d: "M6 16.5l2.2-3 2.6 2 3-4.2 2.4 2.6 2-2.4", gefuellt: false),
            ]
        case .thermometer:
            return [
                (d: "M10 4.5a2 2 0 0 1 4 0v8.7a4 4 0 1 1-4 0z", gefuellt: false),
                (d: "M12 9.5v5.3", gefuellt: false),
                (d: "M 12.0 15.100000000000001 C 12.82842712474619 15.100000000000001 13.5 15.771572875253812 13.5 16.6 C 13.5 17.428427124746193 12.82842712474619 18.1 12.0 18.1 C 11.17157287525381 18.1 10.5 17.428427124746193 10.5 16.6 C 10.5 15.771572875253812 11.17157287525381 15.100000000000001 12.0 15.100000000000001 Z", gefuellt: true),
            ]
        case .tuer:
            return [
                (d: "M5.5 21V4.5A1.5 1.5 0 0 1 7 3h10a1.5 1.5 0 0 1 1.5 1.5V21", gefuellt: false),
                (d: "M3.5 21h17", gefuellt: false),
                (d: "M 14.6 11.5 C 15.207513224813873 11.5 15.7 11.992486775186126 15.7 12.6 C 15.7 13.207513224813873 15.207513224813873 13.7 14.6 13.7 C 13.992486775186126 13.7 13.5 13.207513224813873 13.5 12.6 C 13.5 11.992486775186126 13.992486775186126 11.5 14.6 11.5 Z", gefuellt: true),
            ]
        case .uhr:
            return [
                (d: "M 12.0 3.0 C 16.970562748477143 3.0 21.0 7.029437251522858 21.0 12.0 C 21.0 16.970562748477143 16.970562748477143 21.0 12.0 21.0 C 7.029437251522858 21.0 3.0 16.970562748477143 3.0 12.0 C 3.0 7.029437251522858 7.029437251522858 3.0 12.0 3.0 Z", gefuellt: false),
                (d: "M12 7v5l3 2", gefuellt: false),
            ]
        case .waermepumpe:
            return [
                (d: "M 5.5 4.5 L 18.5 4.5 C 19.880711874576985 4.5 21.0 5.619288125423016 21.0 7.0 L 21.0 15.0 C 21.0 16.380711874576985 19.880711874576985 17.5 18.5 17.5 L 5.5 17.5 C 4.119288125423016 17.5 3.0 16.380711874576985 3.0 15.0 L 3.0 7.0 C 3.0 5.619288125423016 4.119288125423016 4.5 5.5 4.5 Z", gefuellt: false),
                (d: "M7 17.5v2M17 17.5v2", gefuellt: false),
                (d: "M 9.25 7.5 C 11.182996624407778 7.5 12.75 9.067003375592222 12.75 11.0 C 12.75 12.932996624407778 11.182996624407778 14.5 9.25 14.5 C 7.317003375592223 14.5 5.75 12.932996624407778 5.75 11.0 C 5.75 9.067003375592222 7.317003375592223 7.5 9.25 7.5 Z", gefuellt: false),
                (d: "M9.25 11L6.78 8.53M9.25 11L12.63 10.09M9.25 11L8.34 14.38", gefuellt: false),
                (d: "M16 9h1.75M16 13h1.75", gefuellt: false),
            ]
        case .warnung:
            return [
                (d: "M12 3l10 18H2z", gefuellt: false),
                (d: "M12 10v5", gefuellt: false),
                (d: "M12 18v.5", gefuellt: false),
            ]
        case .zahnrad:
            return [
                (d: "M21.86 10.36 L21.86 13.64 L19.18 13.78 L18.34 15.82 L20.14 17.81 L17.81 20.14 L15.82 18.34 L13.78 19.18 L13.64 21.86 L10.36 21.86 L10.22 19.18 L8.18 18.34 L6.19 20.14 L3.86 17.81 L5.66 15.82 L4.82 13.78 L2.14 13.64 L2.14 10.36 L4.82 10.22 L5.66 8.18 L3.86 6.19 L6.19 3.86 L8.18 5.66 L10.22 4.82 L10.36 2.14 L13.64 2.14 L13.78 4.82 L15.82 5.66 L17.81 3.86 L20.14 6.19 L18.34 8.18 L19.18 10.22 Z", gefuellt: false),
                (d: "M 12.0 8.4 C 13.988225099390856 8.4 15.6 10.011774900609144 15.6 12.0 C 15.6 13.988225099390856 13.988225099390856 15.6 12.0 15.6 C 10.011774900609144 15.6 8.4 13.988225099390856 8.4 12.0 C 8.4 10.011774900609144 10.011774900609144 8.4 12.0 8.4 Z", gefuellt: false),
            ]
        case .ziel:
            return [
                (d: "M 12.0 3.5 C 16.694420373561744 3.5 20.5 7.305579626438255 20.5 12.0 C 20.5 16.694420373561744 16.694420373561744 20.5 12.0 20.5 C 7.305579626438255 20.5 3.5 16.694420373561744 3.5 12.0 C 3.5 7.305579626438255 7.305579626438255 3.5 12.0 3.5 Z", gefuellt: false),
                (d: "M 12.0 7.4 C 14.54050984922165 7.4 16.6 9.45949015077835 16.6 12.0 C 16.6 14.54050984922165 14.54050984922165 16.6 12.0 16.6 C 9.45949015077835 16.6 7.4 14.54050984922165 7.4 12.0 C 7.4 9.45949015077835 9.45949015077835 7.4 12.0 7.4 Z", gefuellt: false),
                (d: "M 12.0 10.8 C 12.662741699796952 10.8 13.2 11.337258300203048 13.2 12.0 C 13.2 12.662741699796952 12.662741699796952 13.2 12.0 13.2 C 11.337258300203048 13.2 10.8 12.662741699796952 10.8 12.0 C 10.8 11.337258300203048 11.337258300203048 10.8 12.0 10.8 Z", gefuellt: true),
            ]
        }
    }

    /// Der Name dieses Zeichens im Dashboard (`Icon.tsx`).
    public var vorlage: String {
        switch self {
        case .anzeige: return "dashboard"
        case .auto: return "car"
        case .batterie: return "battery"
        case .blitz: return "bolt"
        case .diagramm: return "chart"
        case .ente: return "duck"
        case .euro: return "euro"
        case .flamme: return "flame"
        case .geraet: return "device"
        case .glocke: return "bell"
        case .haus: return "house"
        case .kaffee: return "coffee"
        case .kalender: return "calendar"
        case .kreis: return "loop"
        case .lampe: return "bulb"
        case .lupe: return "search"
        case .mond: return "moon"
        case .netz: return "grid"
        case .ofen: return "stove"
        case .person: return "person"
        case .schieber: return "sliders"
        case .schild: return "shield"
        case .schloss: return "lock"
        case .schluessel: return "key"
        case .sonne: return "sun"
        case .tabelle: return "table"
        case .thermometer: return "thermo"
        case .tuer: return "door"
        case .uhr: return "clock"
        case .waermepumpe: return "pump"
        case .warnung: return "alert"
        case .zahnrad: return "gear"
        case .ziel: return "target"
        }
    }

    /// Das Zeichen zu einem Namen des Dashboards, wie `docs/seitenbaum.json` ihn nennt.
    public init?(vorlage: String) {
        switch vorlage {
        case "alert": self = .warnung
        case "battery": self = .batterie
        case "bell": self = .glocke
        case "bolt": self = .blitz
        case "bulb": self = .lampe
        case "calendar": self = .kalender
        case "car": self = .auto
        case "chart": self = .diagramm
        case "clock": self = .uhr
        case "coffee": self = .kaffee
        case "dashboard": self = .anzeige
        case "device": self = .geraet
        case "door": self = .tuer
        case "duck": self = .ente
        case "euro": self = .euro
        case "flame": self = .flamme
        case "gear": self = .zahnrad
        case "grid": self = .netz
        case "home": self = .haus
        case "house": self = .haus
        case "key": self = .schluessel
        case "lock": self = .schloss
        case "loop": self = .kreis
        case "moon": self = .mond
        case "person": self = .person
        case "pump": self = .waermepumpe
        case "search": self = .lupe
        case "shield": self = .schild
        case "sliders": self = .schieber
        case "stove": self = .ofen
        case "sun": self = .sonne
        case "table": self = .tabelle
        case "target": self = .ziel
        case "thermo": self = .thermometer
        default: return nil
        }
    }
}
