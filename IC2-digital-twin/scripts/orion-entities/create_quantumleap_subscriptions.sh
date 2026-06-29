#!/usr/bin/env bash

set -euo pipefail

echo "➡️ Creating subscription: OffStreetParking number of occupied and available spots."
# Create a Subscription to send the changes in the attribute "occupiedSpotNumber" and "availableSpotNumber" of the "OffStreetParking" entity to the QuantumLeap component that will write it to CrateDB.
curl -L -X POST 'http://localhost:1026/ngsi-ld/v1/subscriptions/' \
-H 'Content-Type: application/ld+json' \
--data-raw '{
  "description": "OffStreetParking number of occupied and available spots.",
  "type": "Subscription",
  "entities": [{"type": "OffStreetParking"}],
  "watchedAttributes": ["occupiedSpotNumber", "availableSpotNumber"],
  "notification": {
    "attributes": ["occupiedSpotNumber","availableSpotNumber"],
    "format": "normalized",
    "endpoint": {
      "uri": "http://quantumleap:8668/v2/notify",
      "accept": "application/json",
      "receiverInfo": [
        {
          "key": "fiware-service",
          "value": ""
        }
      ]
    }
  },
   "@context": "http://context/datamodels.context-ngsi.jsonld"
}'

echo "➡️ Creating subscription: ParkingGroup number of available spots."
# Create a Subscription to send the changes in the attribute "availableSpotNumber" of the "ParkingGroup" entity to the QuantumLeap component that will write it to CrateDB.
curl -L -X POST 'http://localhost:1026/ngsi-ld/v1/subscriptions/' \
-H 'Content-Type: application/ld+json' \
--data-raw '{
  "description": "ParkingGroup number of available spots.",
  "type": "Subscription",
  "entities": [{"type": "ParkingGroup"}],
  "watchedAttributes": ["availableSpotNumber"],
  "notification": {
    "attributes": ["availableSpotNumber"],
    "format": "normalized",
    "endpoint": {
      "uri": "http://quantumleap:8668/v2/notify",
      "accept": "application/json",
      "receiverInfo": [
        {
          "key": "fiware-service",
          "value": ""
        }
      ]
    }
  },
   "@context": "http://context/datamodels.context-ngsi.jsonld"
}'

echo "➡️ Creating subscription: Parking Spot status."
# Create a Subscription to send the changes in the attribute "status" of the "ParkingSpot" entity to the QuantumLeap component that will write it to CrateDB.
curl -L -X POST 'http://localhost:1026/ngsi-ld/v1/subscriptions/' \
-H 'Content-Type: application/ld+json' \
--data-raw '{
  "description": "Parking Spot status.",
  "type": "Subscription",
  "entities": [{"type": "ParkingSpot"}],
  "watchedAttributes": ["status"],
  "notification": {
    "attributes": ["status"],
    "format": "normalized",
    "endpoint": {
      "uri": "http://quantumleap:8668/v2/notify",
      "accept": "application/json",
      "receiverInfo": [
        {
          "key": "fiware-service",
          "value": ""
        }
      ]
    }
  },
   "@context": "http://context/datamodels.context-ngsi.jsonld"
}'

echo "Verifying subscriptions to QuantumLeap."
# Verify if the Subscription to QuantumLeap exists.
curl -X GET \
  'http://localhost:1026/ngsi-ld/v1/subscriptions/' \
  -H 'Link: <http://context/datamodels.context-ngsi.jsonld>; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"'

