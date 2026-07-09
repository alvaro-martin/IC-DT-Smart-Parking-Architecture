#!/bin/bash

# Variables
IOTA_HOST="http://localhost:4041"
FIWARE_SERVICE="unicamp"
FIWARE_SERVICEPATH="/parking"
API_KEY="12345"
CBROKER="http://orion:1026"
ENTITY_TYPE="OffStreetParking"
RESOURCE="/iot/json"

echo "📡 Creating IoT Agent service group..."

curl -iX POST "$IOTA_HOST/iot/services" \
  -H "Content-Type: application/json" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH" \
  -d "{
    \"services\": [
      {
        \"apikey\": \"$API_KEY\",
        \"cbroker\": \"$CBROKER\",
        \"entity_type\": \"$ENTITY_TYPE\",
        \"resource\": \"$RESOURCE\"
      }
    ]
  }"

echo ""
echo "✅ Verifying service group registration..."
curl -X GET "$IOTA_HOST/iot/services" \
  -H "fiware-service: $FIWARE_SERVICE" \
  -H "fiware-servicepath: $FIWARE_SERVICEPATH"

