#!/usr/bin/env python3
"""Haelt das eingecheckte Xcode-Projekt gegen project.yml und gegen die Platte.

**Warum es dieses Skript gibt.** Das Projekt und zwei weitere Dateien (`Info.plist`,
`DuckCurveHome.entitlements`) entstehen aus `apps/ios/project.yml` und liegen trotzdem im
Repository - damit man Xcode oeffnen kann, ohne vorher XcodeGen zu installieren. Der Preis
dafuer ist eine zweite Wahrheit, die veralten kann: wer eine Swift-Datei anlegt oder in
project.yml etwas verstellt und nicht neu erzeugt, baut gegen den alten Stand. Das faellt
nicht auf - es ist kein Fehler, nur eine Datei, die stumm nicht mitgebaut wird.

Dieses Skript ist die Wache davor. Es braucht XcodeGen **nicht**: es liest die
`project.pbxproj` selbst und vergleicht, was darin steht, mit project.yml und mit dem, was
auf der Platte liegt. Damit laeuft es auf jedem Linux-Laeufer, ohne Swift und ohne Mac.

    tools/xcodeproj-pruefen.py

Was es prueft, und warum gerade das:

1. **Die pbxproj liest sich.**  Eine kaputte Datei oeffnet Xcode gar nicht.
2. **Jede gebaute Datei liegt da.**  Ein Verweis ins Leere ist ein roter Build.
3. **Jede Swift-Datei unter DuckCurveHome/ ist im Build - und umgekehrt.**  Das ist der
   wichtigste Punkt. Eine neue Datei, die niemand erzeugt hat, wird nicht uebersetzt; ihre
   Fehler zeigt kein Compiler, und ihre Ansicht ist zur Laufzeit einfach nicht da.
4. **DuckCurveKit haengt als lokales Paket drin.**  Fehlt es, ist jede Zeile rot.
5. **Info.plist und entitlements tragen, was project.yml sagt.**  Hier faellt auf, wenn
   project.yml verstellt und nicht neu erzeugt wurde.
6. **Die Schriften in UIAppFonts liegen wirklich da.**  Eine Schrift, die im Verzeichnis
   fehlt oder anders heisst, faellt stumm auf die Systemschrift zurueck - das ist in dieser
   App einmal passiert und war von aussen nicht zu sehen.
7. **Das Mindestsystem stimmt mit project.yml.**  Sonst baut man gegen ein anderes iOS, als
   man glaubt.
"""

from __future__ import annotations

import os
import plistlib
import re
import sys

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IOS = os.path.join(WURZEL, "apps", "ios")
PROJEKT = os.path.join(IOS, "DuckCurveHome.xcodeproj", "project.pbxproj")
SPEZIFIKATION = os.path.join(IOS, "project.yml")

maengel: list[str] = []


def maengel_melden(text: str) -> None:
    maengel.append(text)


# ---------------------------------------------------------------- pbxproj lesen

class PbxLeser:
    """Ein Leser fuer das alte NeXTSTEP-ASCII-Plist, in dem eine pbxproj steht.

    Pythons `plistlib` kennt nur XML und binaer; eine pbxproj ist keines von beiden. Das
    Format ist aber einfach: Woerterbuecher in `{}`, Listen in `()`, Zeichenketten in
    Anfuehrungszeichen oder nackt, Kommentare in `/* */`.
    """

    def __init__(self, text: str) -> None:
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)   # Blockkommentare
        text = re.sub(r"^\s*//[^\n]*\n", "", text)           # die Kopfzeile // !$*UTF8*$!
        self.s = text
        self.i = 0

    def _leerraum(self) -> None:
        while self.i < len(self.s) and self.s[self.i] in " \t\r\n":
            self.i += 1

    def wert(self):
        self._leerraum()
        z = self.s[self.i]
        if z == "{":
            self.i += 1
            d = {}
            while True:
                self._leerraum()
                if self.s[self.i] == "}":
                    self.i += 1
                    return d
                schluessel = self.wert()
                self._leerraum()
                if self.s[self.i] != "=":
                    raise ValueError(f"'=' erwartet bei {schluessel!r}")
                self.i += 1
                d[schluessel] = self.wert()
                self._leerraum()
                if self.s[self.i] == ";":
                    self.i += 1
        if z == "(":
            self.i += 1
            a = []
            while True:
                self._leerraum()
                if self.s[self.i] == ")":
                    self.i += 1
                    return a
                a.append(self.wert())
                self._leerraum()
                if self.s[self.i] == ",":
                    self.i += 1
        if z == '"':
            self.i += 1
            teile = []
            while self.s[self.i] != '"':
                if self.s[self.i] == "\\":
                    teile.append(self.s[self.i + 1])
                    self.i += 2
                else:
                    teile.append(self.s[self.i])
                    self.i += 1
            self.i += 1
            return "".join(teile)
        anfang = self.i
        while self.s[self.i] not in " \t\r\n=;,(){}":
            self.i += 1
        return self.s[anfang:self.i]


def main() -> int:
    if not os.path.exists(PROJEKT):
        print(f"Kein Projekt unter {os.path.relpath(PROJEKT, WURZEL)}.", file=sys.stderr)
        print("Erzeugen mit:  cd apps/ios && xcodegen generate", file=sys.stderr)
        return 1

    # 1. liest sich die Datei?
    try:
        wurzel = PbxLeser(open(PROJEKT, encoding="utf-8").read()).wert()
        objekte = wurzel["objects"]
        projektobjekt = objekte[wurzel["rootObject"]]
    except Exception as fehler:                              # noqa: BLE001
        print(f"Die pbxproj liest sich nicht: {fehler}", file=sys.stderr)
        return 1

    import yaml
    spezifikation = yaml.safe_load(open(SPEZIFIKATION, encoding="utf-8"))
    ziel_spezifikation = spezifikation["targets"]["DuckCurveHome"]

    # Den Gruppenbaum ablaufen: ein Pfad in der pbxproj ist relativ zu seiner Gruppe.
    aufgeloest: dict[str, tuple[str, str]] = {}

    def lauf(kennung: str, vorfahr: str) -> None:
        knoten = objekte[kennung]
        art = knoten.get("isa")
        pfad = knoten.get("path", "")
        quelle = knoten.get("sourceTree", "")
        if quelle in ("SOURCE_ROOT", "<absolute>"):
            hier = pfad
        else:
            hier = os.path.join(vorfahr, pfad) if pfad else vorfahr
        if art in ("PBXGroup", "PBXVariantGroup"):
            for kind in knoten.get("children", []):
                lauf(kind, hier)
        elif art == "PBXFileReference":
            aufgeloest[kennung] = (hier, quelle)

    lauf(projektobjekt["mainGroup"], "")

    ziele = [v for v in objekte.values() if v.get("isa") == "PBXNativeTarget"]
    if len(ziele) != 1 or ziele[0].get("name") != "DuckCurveHome":
        maengel_melden(f"Erwartet war ein Ziel „DuckCurveHome“, gefunden: "
                       f"{[z.get('name') for z in ziele]}")
        return bericht()
    ziel = ziele[0]

    gebaut: list[tuple[str, str]] = []
    for phase_kennung in ziel["buildPhases"]:
        phase = objekte[phase_kennung]
        if phase.get("isa") in ("PBXSourcesBuildPhase", "PBXResourcesBuildPhase"):
            for datei in phase.get("files", []):
                verweis = objekte[datei].get("fileRef")
                if verweis in aufgeloest:
                    gebaut.append(aufgeloest[verweis])

    # 2. jede gebaute Datei liegt da
    for pfad, quelle in gebaut:
        if quelle == "BUILT_PRODUCTS_DIR":
            continue
        if not os.path.exists(os.path.join(IOS, pfad)):
            maengel_melden(f"Im Build, aber nicht auf der Platte: {pfad}")

    # 3. Swift-Dateien: Platte gegen Build
    quellpfad = ziel_spezifikation["sources"][0]["path"]
    auf_platte = {
        os.path.relpath(os.path.join(r, d), IOS)
        for r, _, dateien in os.walk(os.path.join(IOS, quellpfad))
        for d in dateien
        if d.endswith(".swift")
    }
    im_build = {p for p, _ in gebaut if p.endswith(".swift")}
    for fehlend in sorted(auf_platte - im_build):
        maengel_melden(f"Liegt da, wird aber nicht gebaut: {fehlend}")
    for ueberzaehlig in sorted(im_build - auf_platte):
        maengel_melden(f"Im Build, aber es gibt sie nicht: {ueberzaehlig}")

    # 4. der Kern als lokales Paket
    pakete = [v.get("relativePath") for v in objekte.values()
              if v.get("isa") == "XCLocalSwiftPackageReference"]
    produkte = [v.get("productName") for v in objekte.values()
                if v.get("isa") == "XCSwiftPackageProductDependency"]
    if "DuckCurveKit" not in pakete:
        maengel_melden(f"DuckCurveKit haengt nicht als lokales Paket drin (gefunden: {pakete})")
    if "DuckCurveKit" not in produkte:
        maengel_melden(f"DuckCurveKit ist nicht als Produkt verknuepft (gefunden: {produkte})")

    # 5. Info.plist und entitlements tragen, was project.yml sagt
    def plist_gegen_spezifikation(abschnitt: str) -> None:
        teil = ziel_spezifikation.get(abschnitt)
        if not teil:
            return
        pfad = os.path.join(IOS, teil["path"])
        if not os.path.exists(pfad):
            maengel_melden(f"{abschnitt}: {teil['path']} fehlt - erzeugen mit xcodegen generate")
            return
        ist = plistlib.load(open(pfad, "rb"))
        for schluessel, soll in (teil.get("properties") or {}).items():
            if schluessel not in ist:
                maengel_melden(f"{teil['path']}: {schluessel} fehlt (project.yml sagt {soll!r})")
            elif ist[schluessel] != soll:
                maengel_melden(
                    f"{teil['path']}: {schluessel} ist {ist[schluessel]!r}, "
                    f"project.yml sagt {soll!r} - nicht neu erzeugt?")

    plist_gegen_spezifikation("info")
    plist_gegen_spezifikation("entitlements")

    # 6. die Schriften in UIAppFonts liegen wirklich da
    info = ziel_spezifikation.get("info")
    if info and os.path.exists(os.path.join(IOS, info["path"])):
        ist = plistlib.load(open(os.path.join(IOS, info["path"]), "rb"))
        ressourcen = ziel_spezifikation.get("resources") or []
        wurzeln = [os.path.join(IOS, r["path"]) for r in ressourcen]
        for schrift in ist.get("UIAppFonts", []):
            if not any(os.path.exists(os.path.join(w, schrift)) for w in wurzeln):
                maengel_melden(
                    f"UIAppFonts nennt {schrift}, die Datei liegt in keiner Ressourcenwurzel - "
                    f"die Schrift faellt stumm auf die Systemschrift zurueck")

    # 7. das Mindestsystem
    soll_ios = str(ziel_spezifikation.get("deploymentTarget")
                   or spezifikation["options"]["deploymentTarget"]["iOS"])
    gefunden = set()
    for kennung in objekte[ziel["buildConfigurationList"]]["buildConfigurations"]:
        einstellungen = objekte[kennung].get("buildSettings", {})
        if "IPHONEOS_DEPLOYMENT_TARGET" in einstellungen:
            gefunden.add(str(einstellungen["IPHONEOS_DEPLOYMENT_TARGET"]))
    if gefunden and gefunden != {soll_ios}:
        maengel_melden(f"Mindestsystem im Projekt: {sorted(gefunden)}, project.yml sagt {soll_ios}")

    print(f"Projekt: {len(objekte)} Objekte, Ziel „{ziel['name']}“, "
          f"{len(im_build)} Swift-Dateien, {len(gebaut) - len(im_build)} Ressourcen.")
    return bericht()


def bericht() -> int:
    if maengel:
        print(f"\n{len(maengel)} Abweichung(en) zwischen project.yml, Projekt und Platte:",
              file=sys.stderr)
        for m in maengel:
            print(f"  - {m}", file=sys.stderr)
        print("\nMeist behoben mit:  cd apps/ios && xcodegen generate", file=sys.stderr)
        return 1
    print("Das eingecheckte Projekt ist auf dem Stand von project.yml und der Platte.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
