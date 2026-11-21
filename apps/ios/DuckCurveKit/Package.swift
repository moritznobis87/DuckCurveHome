// swift-tools-version:6.0
import PackageDescription

/// **DuckCurveKit - der Kern der App, ohne Oberflaeche.**
///
/// Hier liegt alles, was nichts von SwiftUI wissen muss: die Modelle aus dem OpenAPI-Schema, der
/// API-Client, der Leser des Ereignisstroms, der Live-Speicher, die Zahlen- und Zeitformate, die
/// Seitenstruktur und das Rechnen, das die Bilder der Oberflaeche vorbereitet.
///
/// **Warum die Trennung so scharf gezogen ist.** Dieses Paket baut und testet auf Linux, also
/// auch dort, wo kein Xcode steht. Was hier liegt, ist durch den Compiler und durch Tests
/// gegangen; was in `../DuckCurveHome` liegt, ist SwiftUI und laesst sich nur auf einem Mac
/// pruefen. Je mehr Last dieses Paket traegt, desto weniger kann die App beim ersten Bauen
/// schiefgehen. Darum steht hier auch das Rechnen der Diagramme und nicht in der Ansicht.
///
///     swift build && swift test        # geht auf Linux und auf dem Mac
let package = Package(
    name: "DuckCurveKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DuckCurveKit", targets: ["DuckCurveKit"]),
    ],
    targets: [
        .target(
            name: "DuckCurveKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DuckCurveKitTests",
            dependencies: ["DuckCurveKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
