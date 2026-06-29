#!/bin/bash

# Base URL for Orion
ORION_URL="http://localhost:1026/ngsi-ld/v1/subscriptions"
TENANT=""

# Get all subscription IDs that notify QuantumLeap
SUB_IDS=$(curl -s -X GET \
  "${ORION_URL}" \
  -H 'Link: <http://context/datamodels.context-ngsi.jsonld>; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"' \
  | jq -r '.[] | select(.notification.endpoint.uri | contains("http://quantumleap:8668")) | .id')

# Loop through and delete each subscription
for ID in $SUB_IDS; do
  echo "Deleting subscription: $ID"
  curl -s -X DELETE \
    -H "NGSILD-Tenant: ${TENANT}" \
    "${ORION_URL}/${ID}"
done

echo "✅ Finished deleting QuantumLeap subscriptions."
