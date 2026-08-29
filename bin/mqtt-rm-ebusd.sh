#!/bin/bash
# Clear retained Home Assistant MQTT discovery topics for ebusd.
# Needed after changing mqtt-hassio filters so stale timer/status entities
# disappear. ebusd republishes the whitelist on the next start.
set -euo pipefail

BROKER="${MQTT_BROKER:-localhost}"
PORT="${MQTT_PORT:-1883}"
USERNAME="${MQTT_USER:-ebus}"
PASSWORD="${MQTT_PASSWORD:-}"

if [ -z "$PASSWORD" ]; then
  echo "Set MQTT_PASSWORD (ebus MQTT user) before running." >&2
  echo "Example: MQTT_PASSWORD=... $0" >&2
  exit 1
fi

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

echo "Collecting retained ebusd discovery topics (15s)..."
mosquitto_sub -h "$BROKER" -p "$PORT" -u "$USERNAME" -P "$PASSWORD" \
  -t "homeassistant/#" -W 15 -v > "$TEMP_FILE" || true

echo "Clearing topics..."
grep "ebusd" "$TEMP_FILE" | cut -d' ' -f1 | sort -u | while IFS= read -r topic; do
  if [ -n "$topic" ] && ! echo "$topic" | grep -q '[+#]'; then
    echo "Clearing: $topic"
    mosquitto_pub -h "$BROKER" -p "$PORT" -u "$USERNAME" -P "$PASSWORD" -t "$topic" -n -r
  fi
done

echo "Done. Restart ebusd to republish the filtered discovery set."
