#!/bin/bash

# Check if number of devices is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <number_of_devices>"
  exit 1
fi

NUM_DEVICES=$1
IOTA_URL="http://localhost:4041/iot/devices"
FIWARE_SERVICE="unicamp"
FIWARE_SERVICEPATH="/parking"
API_KEY="12345"

for i in $(seq -w 1 $NUM_DEVICES); do
  DEVICE_ID="$i"
  ENTITY_ID="urn:ngsi-ld:OffStreetParking:$i"

  echo "📦 Provisioning device $DEVICE_ID -> $ENTITY_ID..."

  curl -s -o /dev/null -w "%{http_code}\n" -X POST "$IOTA_URL" \
    -H "fiware-service: $FIWARE_SERVICE" \
    -H "fiware-servicepath: $FIWARE_SERVICEPATH" \
    -H "Content-Type: application/json" \
    -d "{
      \"devices\": [
        {
          \"device_id\": \"$DEVICE_ID\",
          \"entity_name\": \"$ENTITY_ID\",
          \"entity_type\": \"OffStreetParking\",
          \"apikey\": \"$API_KEY\",
          \"attributes\": [
            {
              \"object_id\": \"occupied_spots\",
              \"name\": \"occupiedSpotNumber\",
              \"type\": \"Property\"
            }
          ]
        }
      ]
    }"
done

echo "✅ Done provisioning $NUM_DEVICES devices."
