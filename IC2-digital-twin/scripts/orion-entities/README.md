# Orion Entity Setup Scripts

Bash scripts for creating and managing NGSI-LD entities in the Orion Context Broker for the IC2 Parking system.

## Overview

These scripts automate the setup of the FIWARE IoT infrastructure, including entity creation, IoT Agent configuration, and QuantumLeap subscriptions.

## Scripts

<table>
<tr><th>Script</th><th>Description</th></tr>
<tr><td><code>run_ic2_poc.sh</code></td><td>Main orchestrator - runs all scripts in sequence</td></tr>
<tr><td><code>validate_containers.sh</code></td><td>Validates Docker containers are healthy before setup</td></tr>
<tr><td><code>create_building_entity.sh</code></td><td>Creates the IC2 Building entity</td></tr>
<tr><td><code>create_offstreet_parking.sh</code></td><td>Creates the OffStreetParking entity</td></tr>
<tr><td><code>create_parking_group.sh</code></td><td>Creates ParkingGroup entities (Staff + Disabled)</td></tr>
<tr><td><code>create_parking_spots.sh</code></td><td>Creates all 16 ParkingSpot entities</td></tr>
<tr><td><code>create_iot_agent_indices.sh</code></td><td>Creates MongoDB indices for IoT Agent</td></tr>
<tr><td><code>create_quantumleap_subscriptions.sh</code></td><td>Creates subscriptions for QuantumLeap time-series persistence</td></tr>
<tr><td><code>rm_quantumleap_subscriptions.sh</code></td><td>Removes all QuantumLeap subscriptions</td></tr>
</table>

## Usage

### Run Full Setup

```bash
./run_ic2_poc.sh
```

This will:
1. Start Docker infrastructure (`docker compose up -d`)
2. Wait 60 seconds for services to stabilize
3. Validate all containers are healthy
4. Create Building entity
5. Create OffStreetParking entity
6. Create ParkingGroup entities
7. Create ParkingSpot entities
8. Create IoT Agent MongoDB indices
9. Create QuantumLeap subscriptions

### Run Individual Scripts

```bash
# Validate containers are running
./validate_containers.sh

# Create specific entities
./create_building_entity.sh
./create_offstreet_parking.sh
./create_parking_group.sh
./create_parking_spots.sh

# Setup IoT Agent
./create_iot_agent_indices.sh

# Setup QuantumLeap subscriptions
./create_quantumleap_subscriptions.sh

# Remove QuantumLeap subscriptions
./rm_quantumleap_subscriptions.sh
```

## Prerequisites

- Docker and Docker Compose installed
- FIWARE infrastructure running (Orion, IoT Agent, MongoDB, QuantumLeap, Grafana)
- Run from the `IC2-digital-twin/` directory or adjust paths accordingly

## Entity Hierarchy

```
Building:IC2
└── OffStreetParking:IC2-OffStreetParking
    ├── ParkingGroup:IC2-Staff (14 spots)
    │   ├── ParkingSpot:IC2-000 to IC2-007
    │   └── ParkingSpot:IC2-010 to IC2-015
    └── ParkingGroup:IC2-Staff-DisabledOnly (2 spots)
        └── ParkingSpot:IC2-008 to IC2-009
```

## Notes

- The `validate_containers.sh` script checks health endpoints with retry logic (20 attempts, 5s intervals)
- All scripts use `set -euo pipefail` for strict error handling
- The `rm_quantumleap_subscriptions.sh` script is useful when there's a failure in the subscriptions mechanism. It allows you to quickly remove all existing subscriptions and recreate them using `create_quantumleap_subscriptions.sh`
