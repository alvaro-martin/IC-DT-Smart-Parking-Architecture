#!/bin/bash
set -euo pipefail

# Run IoT infrastructure
docker compose -f ../../compose.yaml up -d
sleep 60
# Validate containers are running healthy
./validate_containers.sh

# Create and verify IC2 Building entity
./create_building_entity.sh

# Create and verify IC2 OffStreetParking entity
./create_offstreet_parking.sh

# Create and verify IC2 Parking Groups entities
./create_parking_group.sh

# Create and verify IC2 Parking Spots entities
./create_parking_spots.sh

# Create IoT Agent indices in MongoDB
./create_iot_agent_indices.sh

# Create and verify the Service Group for the IoT Agent

# Provisioned the IoT JSON Devices

# Create and verify QuantumLeap subscriptions
./create_quantumleap_subscriptions.sh
