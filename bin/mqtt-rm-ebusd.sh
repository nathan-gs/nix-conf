#!/bin/bash

# Configuration
BROKER="localhost"  # Replace with your MQTT broker address
PORT=1883           # Default MQTT port
TOPIC="homeassistant/#"  # Matches homeassistant/*/ebusd_*
USERNAME="homeassistant" # Replace with your MQTT username
PASSWORD="" # Replace with your MQTT password

# Temporary file to store topics
TEMP_FILE=$(mktemp)

# Step 1: Collect all topics containing "ebusd_"
echo "Collecting topics (this may take a moment)..."
mosquitto_sub -h "$BROKER" -p "$PORT" -u "$USERNAME" -P "$PASSWORD" -t "$TOPIC" -v > "$TEMP_FILE" &
SUB_PID=$!

# Wait to ensure all topics are collected
sleep 15  # Adjust if needed
kill $SUB_PID

# Step 2: Clear all topics with "ebusd_"
echo "Clearing topics..."
grep "ebusd_" "$TEMP_FILE" | cut -d' ' -f1 | while IFS= read -r topic; do
    # Skip empty or invalid topics
    if [ -n "$topic" ] && ! echo "$topic" | grep -q '[+#]'; then
        echo "Clearing: $topic"
        mosquitto_pub -h "$BROKER" -p "$PORT" -u "$USERNAME" -P "$PASSWORD" -t "$topic" -n -r
    else
        echo "Skipping invalid topic: '$topic'"
    fi
done

# Clean up
rm "$TEMP_FILE"
echo "Done!"