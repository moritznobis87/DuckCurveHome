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
fatal() { log "FEHLER: $*"; sleep "${DCH_EBUSD_FEHLERPAUSE:-60}"; exit 1; }
# Nicht `.[$k] // $d`: für jq ist auch `false` "nichts", und aus einem ausgeschalteten Schalter
# würde die Voreinstellung (so stand es bis 0.2.3: `read_only: false` blieb wirkungslos).
opt() { jq -r --arg k "$1" --arg d "${2-}" 'if has($k) and .[$k] != null then .[$k] | tostring else $d end' "$OPTIONS"; }

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

# --- Arbeitsfassung: ebusd liest nie die Quelle selbst, sondern eine Kopie, die bei jedem Start
# neu entsteht. So lässt sich aus ihr entfernen, was ebusd nicht können soll, ohne die geladene
# oder die eigene Bus-Beschreibung anzufassen.
QUELLE="$CONFIGPATH"
CONFIGPATH="$DATA/ebusd-config/aktiv"
rm -rf "$CONFIGPATH" && mkdir -p "$CONFIGPATH" && cp "$QUELLE"/*.csv "$CONFIGPATH"/ \
  || fatal "Kann die Arbeitsfassung der Bus-Beschreibung nicht anlegen ($CONFIGPATH)."
EIGENE="${DCH_EBUSD_EIGENE:-/etc/duckcurve}"

# Die eigenen Zeilen für die Wärmepumpe dieses Hauses liegen im Abbild und kommen bei jedem
# Start dazu: so wirkt ein Update des Add-ons, ohne dass die Bus-Beschreibung neu geladen werden
# muss. Wer eigene Dateien unter $LOCAL hat, bekommt sie nicht dazugemischt.
if [ "$QUELLE" != "$LOCAL" ] && [ -r "$EIGENE/aerotop_split.csv" ]; then
  cp "$EIGENE/aerotop_split.csv" "$CONFIGPATH/aerotop_split.csv" \
    && log "Eigene Zeilen für die Aerotop Split dazugelegt."
fi

READ_ONLY="$(opt read_only true)"
ABFRAGEN="$(opt abfragen false)"

# Zeilen zum Stellen zählen und entfernen. Die erste Spalte nennt die Art; mehrere stehen mit
# Semikolon nebeneinander ("r;w"), ein Stern davor setzt Vorgaben. Was mit w beginnt, stellt.
# "uw" beginnt mit u: das ist eine mitgelesene fremde Stellnachricht und bleibt.
stellzeilen() {
  cat "$CONFIGPATH"/*.csv | awk -F, '!/^#/ && NF { n = split($1, t, ";"); for (i = 1; i <= n; i++) { x = t[i]; sub(/^\*/, "", x); if (x ~ /^w/) c++ } } END { print c + 0 }'
}
ohne_stellen() {
  awk -F, 'BEGIN { OFS = "," }
    /^#/ || !NF { print; next }
    { n = split($1, t, ";"); neu = ""
      for (i = 1; i <= n; i++) { x = t[i]; sub(/^\*/, "", x); if (x !~ /^w/) neu = (neu == "" ? t[i] : neu ";" t[i]) }
      if (neu == "") next
      $1 = neu; print }' "$1" > "$1.neu" && mv "$1.neu" "$1"
}

ARGS=(--foreground --updatecheck=off "--device=$ADAPTER" "--latency=$(opt latency_ms 120)"
  "--configpath=$CONFIGPATH" "--log=all:$(opt log_level notice)"
  "--mqtthost=$MQTT_HOST" "--mqttport=$MQTT_PORT" "--mqtttopic=$(opt mqtt_topic ebusd)" --mqttjson)
[ -n "$MQTT_USER" ] && ARGS+=("--mqttuser=$MQTT_USER" "--mqttpass=$MQTT_PASS")
if [ "$ABFRAGEN" = "true" ] && [ -r "$EIGENE/aerotop_abfragen.csv" ]; then
  # Die geladene Bus-Beschreibung kennt dieselben Kennungen unter anderem Namen, und ebusd nimmt
  # eine Kennung nur einmal ("duplicate ID", im Probelauf am 14.11.2026 gesehen: die Zeilen zum
  # Abfragen fielen stillschweigend weg). Deshalb weichen die fremden Zeilen den eigenen.
  for datei in "$CONFIGPATH"/*.csv; do
    awk -F, 'NR == FNR { if ($1 ~ /^r[1-9]$/) k[tolower($6 FS $7 FS $8)] = 1; next }
      !($1 ~ /^r/ && (tolower($6 FS $7 FS $8) in k))' "$EIGENE/aerotop_abfragen.csv" "$datei" > "$datei.neu" \
      && mv "$datei.neu" "$datei" || fatal "Kann $(basename "$datei") nicht für die Abfragen vorbereiten."
  done
  cp "$EIGENE/aerotop_abfragen.csv" "$CONFIGPATH/aerotop_abfragen.csv" \
    || fatal "Kann die Zeilen zum Abfragen nicht dazulegen."
  # ebusd selbst fragen, ob es die Zeilen nimmt. Lehnt es sie ab, liefe es sonst ohne sie weiter
  # und niemand sähe es.
  # Am Rückgabewert lässt sich das nicht ablesen (er ist mit dieser Bus-Beschreibung immer 1,
  # wegen "max message ID length exceeded"), wohl aber an der Ausgabe: ebusd nennt, wie viele
  # Zeilen zum Abfragen es gefunden hat.
  pruefung="$(ebusd --checkconfig "--configpath=$CONFIGPATH" 2>&1)"
  soll="$(grep -c '^r[1-9],' "$EIGENE/aerotop_abfragen.csv")"
  ist="$(echo "$pruefung" | sed -n 's/.*[ (]\([0-9][0-9]*\) poll.*/\1/p' | tail -n 1)"
  if [ "$ist" != "$soll" ] || echo "$pruefung" | grep -q "ERR:"; then
    log "ebusd nimmt die Zeilen zum Abfragen nicht an (${ist:-keine} von $soll). Es wird nur gelauscht. Die Meldung:"
    echo "$pruefung" | grep "ERR:\|found messages" | head -n 5 | while IFS= read -r zeile; do log "  $zeile"; done
    rm -f "$CONFIGPATH/aerotop_abfragen.csv"
    ABFRAGEN="false"
  fi
else
  ABFRAGEN="false"
fi
if [ "$READ_ONLY" = "true" ] && [ "$ABFRAGEN" != "true" ]; then
  ARGS+=(--readonly)
  log "Nur lesend: ebusd schreibt nichts auf den Bus."
elif [ "$READ_ONLY" = "true" ]; then
  vorher="$(stellzeilen)"
  for datei in "$CONFIGPATH"/*.csv; do
    ohne_stellen "$datei" || fatal "Kann die Zeilen zum Stellen nicht aus $(basename "$datei") entfernen."
  done
  [ "$(stellzeilen)" = "0" ] || fatal "In der Bus-Beschreibung stehen noch Zeilen zum Stellen. Nicht gestartet."
  ARGS+=("--pollinterval=$(opt abfrage_takt_s 10)")
  log "Abfragen an: ebusd fragt $(grep -c '^r[1-9],' "$CONFIGPATH/aerotop_abfragen.csv") Werte reihum ab, alle $(opt abfrage_takt_s 10) s einen."
  log "Stellen kann ebusd nichts: $vorher Zeilen zum Stellen aus der Bus-Beschreibung entfernt, keine übrig."
else
  if [ "$ABFRAGEN" = "true" ]; then ARGS+=("--pollinterval=$(opt abfrage_takt_s 10)"); fi
  log "ACHTUNG: read_only ist aus. ebusd darf auf den Bus schreiben (Werte abfragen und, wenn jemand es verlangt, stellen)."
fi
while IFS= read -r extra; do
  [ -n "$extra" ] || continue
  # Diese beiden Schalter öffnen einen Weg, beliebige Telegramme zu senden. Mit read_only nie.
  case "$extra" in --enablehex*|--enabledefine*)
    [ "$READ_ONLY" = "true" ] && fatal "extra_args enthält $extra. Das verträgt sich nicht mit read_only." ;;
  esac
  ARGS+=("$extra")
done < <(jq -r '.extra_args // [] | .[]' "$OPTIONS")

# Das Passwort gehört nicht ins Protokoll.
log "ebusd ${ARGS[*]//--mqttpass=*/--mqttpass=***}"
exec ebusd "${ARGS[@]}"
