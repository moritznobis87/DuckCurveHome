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
bashio::log.info "Duck Curve Home Bridge startet (Ziel: ${DCH_BRIDGE_API_WS_URL})"
exec python3 -m dch_bridge.main
