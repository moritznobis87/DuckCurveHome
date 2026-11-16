#!/usr/bin/env bash
# Den Dienst so starten, dass die App ihn findet - und sagen, was einzutippen ist.
#
# **Warum ein eigenes Skript neben tools/demo.sh.** Das startet den Dienst auf 127.0.0.1 und das
# Dashboard dazu. Fuer den Browser auf demselben Rechner ist das richtig; fuer ein iPhone im WLAN
# ist es die haeufigste Ursache von „nicht erreichbar": der Dienst horcht, aber nur auf sich
# selbst. Dieses Skript bindet auf alle Schnittstellen und nennt die Adresse, die ins
# Einrichtungsfenster der App gehoert.
#
#     tools/ios-demo.sh            # Demo-Daten, kein Token
#     tools/ios-demo.sh --schnell  # Zeitraffer: ein Tag in fuenf Minuten
#
# Zum Aufhoeren: Strg-C.

set -euo pipefail
cd "$(dirname "$0")/.."

SPEED=1
[[ "${1:-}" == "--schnell" ]] && SPEED=288

# Die Adresse im Heimnetz. Drei Wege, weil kein einzelner ueberall funktioniert: `ipconfig` auf
# macOS, `hostname -I` auf Linux, und als Rueckfall die Route zum Netz.
adresse() {
    if command -v ipconfig >/dev/null 2>&1; then
        for schnittstelle in en0 en1 en2; do
            ip=$(ipconfig getifaddr "$schnittstelle" 2>/dev/null || true)
            [[ -n "$ip" ]] && { echo "$ip"; return; }
        done
    fi
    if command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        [[ -n "$ip" ]] && { echo "$ip"; return; }
    fi
    ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || true
}

IP=$(adresse)

printf '\n\033[1;36mDuck Curve Home - Demo fuer die App\033[0m\n\n'
printf '  Im Simulator eintragen:   \033[1mhttp://localhost:8000\033[0m\n'
if [[ -n "$IP" ]]; then
    printf '  Auf iPhone oder iPad:     \033[1mhttp://%s:8000\033[0m\n' "$IP"
else
    printf '  Auf iPhone oder iPad:     die Adresse dieses Rechners im WLAN, Port 8000\n'
fi
cat <<'ENDE'

  Token:                    leer lassen (die Demo laeuft ohne)
  Name des Geraets:         was du magst, etwa "iPhone"

  Das Geraet muss im selben WLAN sein wie dieser Rechner.
  Zum Aufhoeren: Strg-C.

ENDE

export DCH_MODE=demo
export DCH_DEMO_SPEED="$SPEED"
# Ohne Token: so muss beim Einrichten nichts eingetippt werden, was man sich merken koennte.
export DCH_API_TOKEN=""
# `--host 0.0.0.0` ist der ganze Unterschied zu tools/demo.sh.
exec uv run uvicorn dch_api.main:app --host 0.0.0.0 --port 8000
