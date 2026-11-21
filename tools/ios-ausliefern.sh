#!/usr/bin/env bash
# Die App archivieren und nach App Store Connect bringen - TestFlight wie Store.
#
# **Warum ein Skript, wenn Xcode einen Knopf dafuer hat.** Hat es, und fuer den ersten Upload
# ist der Knopf auch der bessere Weg: der Organizer prueft Icon, Berechtigungen und Plist und
# sagt in Worten, was fehlt. Dieses Skript ist fuer den zehnten Upload - damit die drei Dinge,
# die man dabei vergisst, nicht vom Gedaechtnis abhaengen: die Baunummer hochzaehlen, das
# eingecheckte Projekt gegen project.yml halten, und Xcode die Nummer nicht selbst verstellen
# lassen (`manageAppVersionAndBuildNumber`).
#
#     tools/ios-ausliefern.sh                    # archivieren und .ipa ablegen
#     tools/ios-ausliefern.sh --hochzaehlen      # Baunummer + 1, dann archivieren
#     tools/ios-ausliefern.sh --hochzaehlen --hochladen   # und zu App Store Connect schicken
#
# **Dieses Skript braucht einen Mac.** `xcodebuild` gibt es nur dort, und die Oberflaeche
# uebersetzt nur dort. Alles, was ohne Mac geht, steht in `tools/ios-pruefen.sh`.
#
# **Und PyYAML**, weil die Wache `tools/xcodeproj-pruefen.py` project.yml damit liest. Das
# python3 neben einem frischen Xcode hat es nicht:  python3 -m pip install --user pyyaml
#
# **Die Team-Kennung** kommt aus `$DEVELOPMENT_TEAM` oder aus `project.yml`. Zu finden unter
# developer.apple.com/account -> Membership details.
#
# **Zum Hochladen** braucht es einen API-Schluessel von App Store Connect (Users and Access ->
# Integrations -> App Store Connect API -> Keys). Die drei Angaben in die Umgebung:
#
#     export ASC_KEY_ID=ABCD123456
#     export ASC_ISSUER_ID=11111111-2222-3333-4444-555555555555
#     export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_ABCD123456.p8
#
# Ohne `--hochladen` entsteht nur die .ipa; die laesst sich auch von Hand im Organizer oder mit
# der Transporter-App schicken.

set -euo pipefail
cd "$(dirname "$0")/.."

HOCHZAEHLEN=0
HOCHLADEN=0
for argument in "$@"; do
    case "$argument" in
        --hochzaehlen) HOCHZAEHLEN=1 ;;
        --hochladen)   HOCHLADEN=1 ;;
        -h|--help)     sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unbekanntes Argument: $argument" >&2; exit 2 ;;
    esac
done

rot()  { printf '\033[0;31m%s\033[0m\n' "$1" >&2; }
blau() { printf '\n\033[0;34m%s\033[0m\n' "$1"; }
gruen(){ printf '\033[0;32m  %s\033[0m\n' "$1"; }

# ------------------------------------------------------------------ 1. Geht das hier ueberhaupt

if ! command -v xcodebuild >/dev/null 2>&1; then
    rot "Kein xcodebuild - dieses Skript braucht einen Mac mit Xcode."
    rot "Was ohne Mac geht:  tools/ios-pruefen.sh"
    exit 1
fi

TEAM="${DEVELOPMENT_TEAM:-}"
if [[ -z "$TEAM" ]]; then
    TEAM=$(sed -n 's/^ *DEVELOPMENT_TEAM: *"\([^"]*\)".*/\1/p' apps/ios/project.yml | head -1)
fi
if [[ -z "$TEAM" ]]; then
    rot "Keine Team-Kennung. Entweder in apps/ios/project.yml eintragen (dann xcodegen"
    rot "generate und mit einchecken) oder einmalig:  export DEVELOPMENT_TEAM=XXXXXXXXXX"
    rot "Zu finden unter developer.apple.com/account -> Membership details."
    exit 1
fi

# **Die API-Schluessel werden hier gebaut, nicht erst vor dem Hochladen - und sie gehen an
# beide xcodebuild-Laeufe.** `-allowProvisioningUpdates` darf ein Verteilprofil anlegen, und
# dafuer muss sich xcodebuild bei Apple ausweisen. Auf einem Rechner, an dem niemand in Xcode
# angemeldet ist (ein Laeufer, ein frisch eingerichteter Mac), gibt es dafuer nur diesen
# Schluessel. Lagen die Angaben erst beim Export vor, scheiterte schon das Archivieren.
#
# Fehlt etwas, sagt das Skript es jetzt - und nicht nach den Minuten, die ein Archiv braucht.
SCHLUESSEL=()
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
    PFAD="${ASC_KEY_PATH/#\~/$HOME}"
    if [[ ! -f "$PFAD" ]]; then
        rot "ASC_KEY_PATH zeigt auf keine Datei: $PFAD"
        exit 1
    fi
    SCHLUESSEL=(
        -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
        -authenticationKeyPath "$PFAD"
    )
elif [[ $HOCHLADEN -eq 1 ]]; then
    rot "--hochladen braucht ASC_KEY_ID, ASC_ISSUER_ID und ASC_KEY_PATH - siehe Kopf dieses"
    rot "Skripts. Ohne sie entsteht nur die .ipa; die schickt dann der Organizer."
    exit 1
fi

# ------------------------------------------------------- 2. Stimmt das Projekt mit project.yml

blau "1/5  Das eingecheckte Projekt gegen project.yml halten"
python3 tools/xcodeproj-pruefen.py
python3 tools/ios-version.py --pruefen

# ------------------------------------------------------------------- 3. Baunummer

blau "2/5  Baunummer"
if [[ $HOCHZAEHLEN -eq 1 ]]; then
    python3 tools/ios-version.py --hochzaehlen
    gruen "Nicht vergessen, die beiden geaenderten Dateien einzuchecken."
else
    python3 tools/ios-version.py
    gruen "Ohne --hochzaehlen bleibt die Nummer - App Store Connect nimmt sie nur einmal an."
fi

# ------------------------------------------------------------------- 4. Archivieren

BAU="$PWD/apps/ios/build"
ARCHIV="$BAU/DuckCurveHome.xcarchive"
AUSGANG="$BAU/export"
rm -rf "$ARCHIV" "$AUSGANG"
mkdir -p "$BAU"

blau "3/5  Archivieren (Release, echtes Geraet)"
# `generic/platform=iOS` ist das allgemeine Geraeteziel: kein angeschlossenes Telefon noetig,
# aber arm64 und kein Simulator. `-allowProvisioningUpdates` laesst die automatische
# Signierung das Verteilprofil anlegen, wenn es noch keines gibt.
xcodebuild archive \
    -project apps/ios/DuckCurveHome.xcodeproj \
    -scheme DuckCurveHome \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIV" \
    -allowProvisioningUpdates \
    "${SCHLUESSEL[@]+"${SCHLUESSEL[@]}"}" \
    DEVELOPMENT_TEAM="$TEAM"
gruen "Archiv liegt in apps/ios/build/"

# --------------------------------------------------------------- 5. Ausfuehren und schicken

# **manageAppVersionAndBuildNumber: false ist der Punkt dieser Datei.** Steht es auf true (der
# Vorgabe), zaehlt Xcode die Baunummer beim Hochladen selbst weiter. Dann steht im Store eine
# andere Nummer als im Repository, und `tools/ios-version.py` sagt die Unwahrheit.
#
# `app-store-connect` heisst die Methode seit Xcode 15.3; aeltere Fassungen wollen `app-store`.
ZIEL="export"
[[ $HOCHLADEN -eq 1 ]] && ZIEL="upload"
cat > "$BAU/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>$ZIEL</string>
	<key>teamID</key>
	<string>$TEAM</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST

blau "4/5  Ausfuehren"
xcodebuild -exportArchive \
    -archivePath "$ARCHIV" \
    -exportOptionsPlist "$BAU/ExportOptions.plist" \
    -exportPath "$AUSGANG" \
    -allowProvisioningUpdates \
    "${SCHLUESSEL[@]+"${SCHLUESSEL[@]}"}"

blau "5/5  Fertig"
if [[ $HOCHLADEN -eq 1 ]]; then
    gruen "Hochgeladen. Die Verarbeitung in App Store Connect dauert Minuten bis zu einer Stunde."
    gruen "Danach unter TestFlight an die Tester geben - nach Export-Compliance fragt"
    gruen "App Store Connect nicht, die steht schon in der Plist (ITSAppUsesNonExemptEncryption)."
else
    ls -la "$AUSGANG"/*.ipa 2>/dev/null || true
    gruen "Die .ipa liegt in apps/ios/build/export/."
    gruen "Schicken: dieses Skript mit --hochladen, oder in Xcode Window -> Organizer -> Distribute App."
fi
