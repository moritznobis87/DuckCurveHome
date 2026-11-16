#!/usr/bin/env bash
# Alles pruefen, was sich ohne Xcode pruefen laesst.
#
# Das ist die Grenze, an der dieses Projekt entlanggebaut ist: der Kern (DuckCurveKit) baut und
# testet auf jedem Rechner mit einer Swift-Toolchain, auch ohne macOS. Die Oberflaeche (SwiftUI)
# laesst sich nur auf einem Mac uebersetzen - geparst wird sie aber auch hier, und das faengt
# Klammern, Kommata und falsch geschriebene Namen, bevor sie Xcode erreichen.
#
#     tools/ios-pruefen.sh            # alles
#     tools/ios-pruefen.sh --schnell  # ohne Pruefstand
#
# Auf einem Mac zusaetzlich (das hier prueft es nicht):
#     xcodebuild -scheme DuckCurveHome -destination 'generic/platform=iOS' build

set -euo pipefail
cd "$(dirname "$0")/.."

SCHNELL=0
[[ "${1:-}" == "--schnell" ]] && SCHNELL=1

# Swift finden: im Pfad, oder an der Stelle, an der die Toolchain unter Linux ueblich liegt.
if command -v swift >/dev/null 2>&1; then
    SWIFT=swift
    SWIFTC=swiftc
elif [[ -x /opt/swift/usr/bin/swift ]]; then
    SWIFT=/opt/swift/usr/bin/swift
    SWIFTC=/opt/swift/usr/bin/swiftc
else
    echo "Keine Swift-Toolchain gefunden." >&2
    echo "Linux: https://www.swift.org/install/linux/ · macOS: Xcode" >&2
    exit 1
fi

blau() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
gruen() { printf '\033[0;32m  %s\033[0m\n' "$*"; }

blau "1/5  Erzeugte Dateien gegen ihre Quellen halten"
python3 tools/gen-swift.py --pruefen
python3 tools/gen-zeichen.py --pruefen
gruen "Schema und Zeichen sind auf dem Stand von docs/openapi.json und Icon.tsx."

blau "2/5  Den Kern bauen"
(cd apps/ios/DuckCurveKit && "$SWIFT" build)

blau "3/5  Den Kern testen"
if [[ $SCHNELL -eq 1 ]]; then
    (cd apps/ios/DuckCurveKit && "$SWIFT" test)
    gruen "Ohne Pruefstand: die Tests der Netzschicht sind uebersprungen."
else
    # Der Pruefstand ist ein echter HTTP-Dienst. Ohne ihn werden die Tests der Netzschicht
    # uebersprungen, und dann ist gerade die Naht ungeprueft, an der sie bricht.
    PORT=${DCH_PRUEFSTAND_PORT:-8111}
    python3 apps/ios/pruefstand/dienst.py "$PORT" >/dev/null 2>&1 &
    PRUEFSTAND=$!
    trap 'kill $PRUEFSTAND 2>/dev/null || true' EXIT
    for _ in $(seq 1 40); do
        if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then break; fi
        sleep 0.1
    done
    (cd apps/ios/DuckCurveKit && DCH_PRUEFSTAND="http://127.0.0.1:$PORT" "$SWIFT" test)
    kill $PRUEFSTAND 2>/dev/null || true
    trap - EXIT
fi

blau "4/5  Die Oberflaeche parsen (SwiftUI, nicht uebersetzbar ohne macOS)"
DATEIEN=$(find apps/ios/DuckCurveHome apps/ios/Widget -name '*.swift' 2>/dev/null | sort)
if [[ -z "$DATEIEN" ]]; then
    echo "  Keine Quelldateien der Oberflaeche gefunden." >&2
    exit 1
fi
ANZAHL=$(echo "$DATEIEN" | wc -l | tr -d ' ')
# Datei fuer Datei: so nennt die Meldung die Datei, in der es klemmt.
FEHLER=0
while IFS= read -r datei; do
    if ! "$SWIFTC" -parse "$datei" >/tmp/ios-parse.log 2>&1; then
        echo "  FEHLER in $datei" >&2
        sed 's/^/    /' /tmp/ios-parse.log >&2
        FEHLER=1
    fi
done <<< "$DATEIEN"
[[ $FEHLER -eq 0 ]] || exit 1
gruen "$ANZAHL Dateien der Oberflaeche sind syntaktisch in Ordnung."

blau "4b/5  Gegen den echten Dienst (wenn einer laeuft)"
# Der Pruefstand antwortet mit dem, was fuer richtig gehalten wird - und wenn das falsch ist,
# antwortet er falsch mit. Der Demo-Dienst antwortet mit dem, was wirklich kommt.
if curl -fsS --max-time 2 http://localhost:8000/health >/dev/null 2>&1; then
    (cd apps/ios/DuckCurveKit && DCH_DEMO=http://localhost:8000 "$SWIFT" test --filter DemoLaufTests)
    gruen "Die erzeugten Modelle lesen die Antworten des echten Dienstes."
else
    gruen "Uebersprungen: kein Dienst auf Port 8000. Starten mit tools/ios-demo.sh"
fi

blau "5/5  Was dieser Lauf nicht prueft"
cat <<'ENDE'
  - Ob die Oberflaeche typpruefend uebersetzt (braucht macOS und Xcode).
  - Ob sie richtig aussieht (braucht ein Geraet oder den Simulator).
  - Die Diagramme in Swift Charts und das Glasmodell als Zeichnung.
  Auf einem Mac:  xcodegen generate && xcodebuild -scheme DuckCurveHome \
      -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
ENDE
printf '\n\033[0;32mFertig.\033[0m\n'
