import os
import time
import pandas as pd
import requests
from influxdb_client import InfluxDBClient
import warnings
from influxdb_client.client.warnings import MissingPivotFunction

warnings.simplefilter("ignore", MissingPivotFunction)

# ---- InfluxDB config ----
TOKEN = os.environ["INFLUXDB_TOKEN"]
ORG = os.environ.get("INFLUXDB_ORG", "Unicamp")
URL = os.environ.get("INFLUXDB_URL", "http://localhost:8086/")
BUCKET = os.environ.get("INFLUXDB_BUCKET", "ic2_parking_twin")
QUERY = f"""
from(bucket: "{BUCKET}")
  |> range(start: -1h)
  |> filter(fn: (r) => exists r._value)
  |> last()
"""

client = InfluxDBClient(url=URL, token=TOKEN, org=ORG)
query_api = client.query_api()

# ---- Orion config ----
ORION_URL = os.environ.get("ORION_URL", "http://orion:1026/ngsi-ld/v1/entities/")
HEADERS = {
    "Content-Type": "application/json",
    "Link": '<http://context/datamodels.context-ngsi.jsonld>; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"'
}

# ---- Helpers ----
def value_to_binary_str(value, bit_length=16):
    return bin(int(value))[2:].zfill(bit_length)

def patch_entity(entity_id, attr, value):
    url = f"{ORION_URL}{entity_id}/attrs/{attr}"
    payload = {
        "type": "Property",
        "value": value
    }
    try:
        r = requests.patch(url, headers=HEADERS, json=payload, timeout=5)
        r.raise_for_status()
        print(f"[OK] Updated {entity_id} {attr} = {value}")
    except Exception as e:
        print(f"[ERROR] Updating {entity_id} {attr}: {e}")

def update_parking(binary_str):
    print("\n===============================")
    print(f"Binary string from InfluxDB: {binary_str}")
    print("===============================")

    occupied_total = 0
    occupied_staff = 0
    occupied_disabled = 0

    # Spots
    for i, bit in enumerate(binary_str):
        status = "occupied" if bit == "1" else "free"
        if bit == "1":
            occupied_total += 1
            if i in [8, 9]:
                occupied_disabled += 1
            else:
                occupied_staff += 1

        spot_id = f"urn:ngsi-ld:ParkingSpot:IC2-{i:03d}"
        print(f"Spot {i:02d} -> {status}")
        patch_entity(spot_id, "status", status)

    # Groups
    available_staff = 14 - occupied_staff
    available_disabled = 2 - occupied_disabled
    print(f"\nGroup IC2-Staff: occupied={occupied_staff}, available={available_staff}")
    print(f"Group IC2-Staff-DisabledOnly: occupied={occupied_disabled}, available={available_disabled}")

    patch_entity("urn:ngsi-ld:ParkingGroup:IC2-Staff", "availableSpotNumber", available_staff)
    patch_entity("urn:ngsi-ld:ParkingGroup:IC2-Staff-DisabledOnly", "availableSpotNumber", available_disabled)

    # OffStreetParking totals
    print(f"\nOffStreetParking totals: occupied={occupied_total}, available={16 - occupied_total}")
    patch_entity("urn:ngsi-ld:OffStreetParking:IC2-OffStreetParking", "occupiedSpotNumber", occupied_total)
    patch_entity("urn:ngsi-ld:OffStreetParking:IC2-OffStreetParking", "availableSpotNumber", 16 - occupied_total)

# ---- Main loop ----
while True:
    try:
        df = query_api.query_data_frame(QUERY, org=ORG)

        if not df.empty:
            last_value = int(df["_value"].iloc[-1])
            binary_str = value_to_binary_str(last_value, bit_length=16)

            # 🔥 Apply the logic
            update_parking(binary_str)

        else:
            print("No data returned from InfluxDB.", flush=True)

    except Exception as e:
        print(f"Error querying InfluxDB: {e}", flush=True)

    time.sleep(30)

