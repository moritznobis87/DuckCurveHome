#!/usr/bin/with-contenv bashio
# Optionen aus /data/options.json als DCH_BRIDGE_* exportieren; SUPERVISOR_TOKEN liefert der Supervisor.
export DCH_BRIDGE_API_WS_URL="$(bashio::config 'api_ws_url')"
export DCH_BRIDGE_API_TOKEN="$(bashio::config 'api_token')"
export DCH_BRIDGE_BRIDGE_ID="$(bashio::config 'bridge_id')"
export DCH_BRIDGE_ENTITIES_FILE="$(bashio::config 'entities_file')"
export DCH_BRIDGE_HEARTBEAT_ENTITY="$(bashio::config 'heartbeat_entity')"
export DCH_BRIDGE_OFFLINE_RELEASE_S="$(bashio::config 'offline_release_s')"
export DCH_BRIDGE_LOG_LEVEL="$(bashio::config 'log_level')"
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
if ! bashio::fs.file_exists "${DCH_BRIDGE_ENTITIES_FILE}"; then
  bashio::log.fatal "Entity-Mapping ${DCH_BRIDGE_ENTITIES_FILE} nicht gefunden. Datei anlegen (Vorlage: config/entities.home.yaml im Repository)."
  sleep 60
  exit 1
fi
bashio::log.info "Duck Curve Home Bridge startet (Ziel: ${DCH_BRIDGE_API_WS_URL}, Mapping: ${DCH_BRIDGE_ENTITIES_FILE})"
exec python3 -m dch_bridge.main
