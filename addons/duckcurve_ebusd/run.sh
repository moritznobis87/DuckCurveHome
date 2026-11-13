#!/usr/bin/with-contenv bash
# Duck Curve eBUS: ebusd starten, mit dem Adapter am Bus der Wärmepumpe und dem Mosquitto-Broker.
#
# Was ebusd ist und was nicht: ebusd (github.com/john30/ebusd) ist das Programm, das die Sprache
# des Busses versteht. Dieses Skript baut nur seine Befehlszeile aus den Optionen des Add-ons.
# Gelernt am Add-on von Lukas Grebe (github.com/LukasGrebe/ha-addons), das dasselbe allgemeiner
# tut; hier steht nur, was dieses Haus braucht.
#
# Absichtlich ohne bashio: so läuft das Skript auch außerhalb von Home Assistant und lässt sich
# prüfen, bevor es an einer Heizung hängt.
#
# `with-contenv` in der ersten Zeile ist nötig: das Grundabbild startet über s6, und ohne es kämen
# weder die Fassung des Add-ons noch SUPERVISOR_TOKEN im Skript an (am 13.11.2026 im Probelauf
# gesehen: "Add-on ?").
set -u

OPTIONS="${DCH_EBUSD_OPTIONS:-/data/options.json}"
DATA="${DCH_EBUSD_DATA:-/data}"
LOCAL="${DCH_EBUSD_LOCAL:-/config/duckcurve/ebusd}"

# Die geprüfte Fassung der Bus-Beschreibung und ihre Prüfsummen. Wer eine andere Fassung wählt,
# bekommt sie ungeprüft und liest das im Protokoll.
PINNED_REF="f2c9a631c1b0bcb73f8d72898915fa0e041699d8"
PINNED_SUMS="748525e65f0ba7b4072ca86353b81b7a70b8dc2c334a2566e44eb6447a366146  ariston.csv
fcd8816cb24c03649c2f938ac6936b7ceb2ff0f5590c5c979d420a8259fe130d  _templates.csv"
CONFIG_REPO="https://raw.githubusercontent.com/wrongisthenewright/ebusd-configuration-ariston-bridgenet"

log() { echo "[duckcurve-ebusd] $*"; }
fatal() { log "FEHLER: $*"; sleep 60; exit 1; }
opt() { jq -r --arg k "$1" --arg d "${2-}" '.[$k] // $d | if . == null then $d else tostring end' "$OPTIONS"; }

[ -r "$OPTIONS" ] || fatal "Keine Optionen unter $OPTIONS."
log "Add-on ${DCH_ADDON_VERSION:-?}, $(ebusd --version 2>/dev/null | head -n 1)"

ADAPTER="$(opt adapter)"
[ -n "$ADAPTER" ] || fatal "Option 'adapter' ist leer. Erwartet wird die Angabe von der Seite des Adapters, z. B. ens:192.168.1.50"

# --- Broker: eigene Angaben gelten; fehlen Name und Passwort, fragt das Skript den Supervisor.
MQTT_HOST="$(opt mqtt_host core-mosquitto)"
MQTT_PORT="$(opt mqtt_port 1883)"
MQTT_USER="$(opt mqtt_username)"
MQTT_PASS="$(opt mqtt_password)"
if [ -z "$MQTT_USER" ] && [ -n "${SUPERVISOR_TOKEN:-}" ]; then
  antwort="$(curl -fsS -m 10 -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/services/mqtt 2>/dev/null || true)"
  if [ -n "$antwort" ] && [ "$(echo "$antwort" | jq -r '.result // empty')" = "ok" ]; then
    MQTT_HOST="$(echo "$antwort" | jq -r '.data.host')"
    MQTT_PORT="$(echo "$antwort" | jq -r '.data.port')"
    MQTT_USER="$(echo "$antwort" | jq -r '.data.username // empty')"
    MQTT_PASS="$(echo "$antwort" | jq -r '.data.password // empty')"
    log "Zugang zum Broker vom Supervisor übernommen (${MQTT_HOST}:${MQTT_PORT})."
  else
    log "Der Supervisor nennt keinen Broker. Läuft das Add-on 'Mosquitto broker'? Es geht ohne Anmeldung weiter."
  fi
fi

# --- Bus-Beschreibung: eigene Dateien gehen vor, sonst die geprüfte Fassung aus dem Netz.
REF="$(opt config_ref)"; REF="${REF:-$PINNED_REF}"
if ls "$LOCAL"/*.csv >/dev/null 2>&1; then
  CONFIGPATH="$LOCAL"
  log "Bus-Beschreibung aus $LOCAL (eigene Dateien, ungeprüft)."
else
  CONFIGPATH="$DATA/ebusd-config/$REF"
  if [ ! -s "$CONFIGPATH/ariston.csv" ] || [ ! -s "$CONFIGPATH/_templates.csv" ]; then
    mkdir -p "$CONFIGPATH.neu" || fatal "Kann $CONFIGPATH.neu nicht anlegen."
    for datei in ariston.csv _templates.csv; do
      curl -fsS -m 60 -o "$CONFIGPATH.neu/$datei" "$CONFIG_REPO/$REF/$datei" \
        || fatal "Die Bus-Beschreibung ($datei, Fassung $REF) ließ sich nicht laden. Ohne Netz hilft es, die Dateien nach $LOCAL zu legen."
    done
    if [ "$REF" = "$PINNED_REF" ]; then
      (cd "$CONFIGPATH.neu" && echo "$PINNED_SUMS" | sha256sum -c --quiet -) \
        || fatal "Die geladene Bus-Beschreibung stimmt nicht mit der geprüften Fassung überein. Nicht verwendet."
      log "Bus-Beschreibung geladen und geprüft (Fassung ${REF:0:12})."
    else
      log "Bus-Beschreibung geladen, Fassung ${REF:0:12}: eine andere als die geprüfte, ohne Prüfsumme."
    fi
    rm -rf "$CONFIGPATH" && mv "$CONFIGPATH.neu" "$CONFIGPATH"
  fi
fi

# Die eigenen Zeilen für die Wärmepumpe dieses Hauses liegen im Abbild und kommen bei jedem
# Start neben die geladene Bus-Beschreibung: so wirkt ein Update des Add-ons, ohne dass die
# Bus-Beschreibung neu geladen werden muss. Eigene Dateien unter $LOCAL bleiben unberührt.
if [ "$CONFIGPATH" != "$LOCAL" ] && [ -r /etc/duckcurve/aerotop_split.csv ]; then
  cp /etc/duckcurve/aerotop_split.csv "$CONFIGPATH/aerotop_split.csv" \
    && log "Eigene Zeilen für die Aerotop Split dazugelegt."
fi

ARGS=(--foreground --updatecheck=off "--device=$ADAPTER" "--latency=$(opt latency_ms 120)"
  "--configpath=$CONFIGPATH" "--log=all:$(opt log_level notice)"
  "--mqtthost=$MQTT_HOST" "--mqttport=$MQTT_PORT" "--mqtttopic=$(opt mqtt_topic ebusd)" --mqttjson)
[ -n "$MQTT_USER" ] && ARGS+=("--mqttuser=$MQTT_USER" "--mqttpass=$MQTT_PASS")
if [ "$(opt read_only true)" = "true" ]; then
  ARGS+=(--readonly)
  log "Nur lesend: ebusd schreibt nichts auf den Bus."
else
  log "ACHTUNG: read_only ist aus. ebusd darf auf den Bus schreiben (Werte abfragen und, wenn jemand es verlangt, stellen)."
fi
while IFS= read -r extra; do [ -n "$extra" ] && ARGS+=("$extra"); done < <(jq -r '.extra_args // [] | .[]' "$OPTIONS")

# Das Passwort gehört nicht ins Protokoll.
log "ebusd ${ARGS[*]//--mqttpass=*/--mqttpass=***}"
exec ebusd "${ARGS[@]}"
