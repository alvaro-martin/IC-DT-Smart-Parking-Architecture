#!/bin/bash
set -euo pipefail

# Require one positional argument
if [ "${1-}" = "" ]; then
  echo "Usage: $0 <number_of_devices>"
  exit 1
fi

NUM_DEVICES="$1"

# Validate numeric positive integer
if ! [[ "$NUM_DEVICES" =~ ^[0-9]+$ ]] || [ "$NUM_DEVICES" -le 0 ]; then
  echo "Error: <number_of_devices> must be a positive integer."
  exit 2
fi

IOTA_URL="http://localhost:4041/iot/devices"
FIWARE_SERVICE="unicamp"
FIWARE_SERVICEPATH="/parking"

echo "📡 Fetching registered devices from IoT Agent..."

# Get all devices provisioned
RESPONSE=$(curl -s -X GET "$IOTA_URL" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH")

MISSING=0

for i in $(seq -w 1 "$NUM_DEVICES"); do
  DEVICE_ID="$i"
  if echo "$RESPONSE" | grep -q "\"device_id\"[[:space:]]*:[[:space:]]*\"$DEVICE_ID\""; then
    echo "[✔] Device $DEVICE_ID is provisioned."
  else
    echo "[✘] Device $DEVICE_ID is MISSING."
    ((MISSING++))
  fi
done

echo ""
if [ "$MISSING" -eq 0 ]; then
  echo "✅ All $NUM_DEVICES devices are correctly provisioned in the IoT Agent."
else
  echo "⚠️ $MISSING devices are missing in the IoT Agent."
fi
