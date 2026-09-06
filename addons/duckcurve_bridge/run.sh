#!/usr/bin/with-contenv bashio
# Optionen aus /data/options.json als DCH_BRIDGE_* exportieren; SUPERVISOR_TOKEN liefert der Supervisor.
export DCH_BRIDGE_API_WS_URL="$(bashio::config 'api_ws_url')"
export DCH_BRIDGE_API_TOKEN="$(bashio::config 'api_token')"
export DCH_BRIDGE_BRIDGE_ID="$(bashio::config 'bridge_id')"
export DCH_BRIDGE_ENTITIES_FILE="$(bashio::config 'entities_file')"
export DCH_BRIDGE_ENTITIES_URL="$(bashio::config 'entities_url' '')"
export DCH_BRIDGE_HEARTBEAT_ENTITY="$(bashio::config 'heartbeat_entity')"
export DCH_BRIDGE_OFFLINE_RELEASE_S="$(bashio::config 'offline_release_s')"
export DCH_BRIDGE_LOG_LEVEL="$(bashio::config 'log_level')"
export DCH_BRIDGE_SOURCE_MODE="$(bashio::config 'source_mode')"
export DCH_BRIDGE_MQTT_HOST="$(bashio::config 'mqtt_host')"
export DCH_BRIDGE_MQTT_PORT="$(bashio::config 'mqtt_port')"
export DCH_BRIDGE_MQTT_USERNAME="$(bashio::config 'mqtt_username' '')"
export DCH_BRIDGE_MQTT_PASSWORD="$(bashio::config 'mqtt_password' '')"
export DCH_BRIDGE_SHELLY_DEVICE_ID="$(bashio::config 'shelly_device_id' '')"
export DCH_BRIDGE_MQTT_TOPIC_PREFIX="$(bashio::config 'mqtt_topic_prefix' '')"
export DCH_BRIDGE_MQTT_PUBLISH_INTERVAL_S="$(bashio::config 'mqtt_publish_interval_s')"
export DCH_BRIDGE_MQTT_STALE_S="$(bashio::config 'mqtt_stale_s')"
export DCH_BRIDGE_MQTT_QOS="$(bashio::config 'mqtt_qos')"
export DCH_BRIDGE_MQTT_POLL_INTERVAL_S="$(bashio::config 'mqtt_poll_interval_s')"
export DCH_BRIDGE_HA_WS_URL="ws://supervisor/core/websocket"
export DCH_BRIDGE_HA_REST_URL="http://supervisor/core/api"
export DCH_BRIDGE_OUTBOX_PATH="/data/outbox.sqlite"
# Klare Hinweise statt kryptischer Abbrüche, wenn die Pflichtoptionen noch leer sind
if [ -z "${DCH_BRIDGE_API_TOKEN}" ]; then
  bashio::log.fatal "Option 'api_token' ist leer. In der Add-on-Konfiguration das Bridge-Token eintragen (derselbe Wert wie DCH_BRIDGE_TOKENS im API-Service)."
  sleep 60
  exit 1
fi
if [ -z "${DCH_BRIDGE_API_WS_URL}" ]; then
  bashio::log.fatal "Option 'api_ws_url' ist leer. Erwartet: wss://<öffentliche API-Domain>/bridge/ws, z. B. wss://duckcurvehome-production.up.railway.app/bridge/ws"
  sleep 60
  exit 1
fi
# Das Mapping kommt aus dem Repository; die Datei in /config übersteuert es, wenn sie existiert.
if ! bashio::fs.file_exists "${DCH_BRIDGE_ENTITIES_FILE}"; then
  if [ -z "${DCH_BRIDGE_ENTITIES_URL}" ]; then
    bashio::log.fatal "Weder ${DCH_BRIDGE_ENTITIES_FILE} noch die Option 'entities_url' vorhanden – die Bridge weiß nicht, welche Entitäten sie lesen soll."
    sleep 60
    exit 1
  fi
  bashio::log.info "Kein ${DCH_BRIDGE_ENTITIES_FILE} – das Mapping wird aus dem Repository geladen."
fi
# Geräte kommen entweder aus dem Abschnitt `mqtt:` des Mappings oder ersatzweise aus den Add-on-Optionen.
if [ "${DCH_BRIDGE_SOURCE_MODE}" != "home_assistant" ] \
  && [ -z "${DCH_BRIDGE_SHELLY_DEVICE_ID}" ] \
  && [ -z "${DCH_BRIDGE_MQTT_TOPIC_PREFIX}" ] \
  && ! grep -qE '^mqtt:[[:space:]]*$' "${DCH_BRIDGE_ENTITIES_FILE}"; then
  bashio::log.warning "Modus ${DCH_BRIDGE_SOURCE_MODE}, aber kein MQTT-Gerät: weder ein Abschnitt 'mqtt:' in ${DCH_BRIDGE_ENTITIES_FILE} noch shelly_device_id/mqtt_topic_prefix in den Optionen. Die Bridge fällt auf home_assistant zurück."
fi
# Zugangsdaten und Tokens erscheinen nicht im Protokoll
bashio::log.info "Duck Curve Home Bridge startet (Ziel: ${DCH_BRIDGE_API_WS_URL}, Mapping: ${DCH_BRIDGE_ENTITIES_FILE}, Quelle: ${DCH_BRIDGE_SOURCE_MODE}, MQTT: ${DCH_BRIDGE_MQTT_HOST}:${DCH_BRIDGE_MQTT_PORT})"
exec python3 -m dch_bridge.main
