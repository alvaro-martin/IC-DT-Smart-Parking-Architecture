# IC2 Parking Grafana Dashboard

This folder contains all the components needed for the Grafana parking dashboard visualization.

![IC2 Parking Dashboard](IC2_Parking.png)

## Overview

The dashboard displays real-time parking occupancy for the IC2 building at UNICAMP, showing:
- **Free spots count** for general and disabled parking
- **Last update timestamp**
- **Geomap** with parking spot rectangles colored by status (free/occupied)
- **Gauge panels** with percentage indicators

## Directory Structure

```
grafana-user/
├── IC2_Parking.json      # Dashboard definition (import into Grafana)
├── IC2_Parking.png        # Screenshot of the dashboard
├── geojson_layer/         # GeoJSON files for map visualization
│   ├── ps_00_07.geojson   # Parking spots 00-07 (general)
│   ├── ps_08_09.geojson   # Parking spots 08-09 (disabled)
│   └── ps_10_15.geojson   # Parking spots 10-15 (general)
├── queries/               # SQL queries and HTML templates
│   ├── free_spots_general
│   ├── free_spots_disabled
│   ├── free_spots_general_percentage
│   ├── free_spots_disabled_percentage
│   ├── individual_spots_coords
│   └── last_time_updated
└── variables/             # Grafana template variables
    ├── free_general_spots
    ├── free_disabled_spots
    ├── last_seen_date
    └── last_seen_hour
```

## Setup Instructions

### 1. Copy GeoJSON Files to Grafana

The GeoJSON files must be copied into the Grafana container so it can access them for the map visualization:

```bash
# Run from the geojson_layer/ directory
docker cp ps_00_07.geojson grafana:/usr/share/grafana/public/gazetteer/
docker cp ps_08_09.geojson grafana:/usr/share/grafana/public/gazetteer/
docker cp ps_10_15.geojson grafana:/usr/share/grafana/public/gazetteer/
```

### 2. Import the Dashboard

1. Open Grafana (default: `https://your-domain/grafana/`)
2. Go to **Dashboards** → **Import**
3. Upload `IC2_Parking.json` or paste its contents
4. Select the **CrateDB** datasource (PostgreSQL protocol)
5. Click **Import**

## Component Details

### GeoJSON Layer Files

These files define the rectangles representing parking spot groups on the Geomap:

<table>
<tr><th>File</th><th>Parking Spots</th><th>Type</th></tr>
<tr><td><code>ps_00_07.geojson</code></td><td>IC2-000 to IC2-007</td><td>General (8 spots)</td></tr>
<tr><td><code>ps_08_09.geojson</code></td><td>IC2-008 to IC2-009</td><td>Disabled (2 spots)</td></tr>
<tr><td><code>ps_10_15.geojson</code></td><td>IC2-010 to IC2-015</td><td>General (6 spots)</td></tr>
</table>

### Queries

SQL queries and HTML templates used to display data in the dashboard:

<table>
<tr><th>File</th><th>Description</th></tr>
<tr><td><code>free_spots_general</code></td><td>HTML showing general free spots count with car icon</td></tr>
<tr><td><code>free_spots_disabled</code></td><td>HTML showing disabled free spots count with wheelchair icon</td></tr>
<tr><td><code>free_spots_general_percentage</code></td><td>Percentage of free general spots</td></tr>
<tr><td><code>free_spots_disabled_percentage</code></td><td>Percentage of free disabled spots</td></tr>
<tr><td><code>individual_spots_coords</code></td><td>SQL query to get all 16 parking spots with GPS coordinates</td></tr>
<tr><td><code>last_time_updated</code></td><td>HTML showing last update time with clock icon</td></tr>
</table>

### Variables

Grafana template variables for dynamic queries:

<table>
<tr><th>Variable</th><th>Description</th></tr>
<tr><td><code>free_general_spots</code></td><td>Available general spots from ParkingGroup</td></tr>
<tr><td><code>free_disabled_spots</code></td><td>Available disabled spots from ParkingGroup</td></tr>
<tr><td><code>last_seen_date</code></td><td>Last update date (DD/MM/YYYY)</td></tr>
<tr><td><code>last_seen_hour</code></td><td>Last update time (HH:MM:SS)</td></tr>
</table>

## Dashboard Features

- **Geomap Panel**: Displays parking lot with colored rectangles (green=free, red=occupied)
- **Gauge Panels**: Show free spot counts with icons (car for general, wheelchair for disabled)
- **Text Panel**: Displays last update timestamp
- **Datasource**: CrateDB via PostgreSQL protocol

## Dependencies

- Grafana 8.5.27
- CrateDB (time-series database)
- Grafana plugins: `orchestracities-map-panel`, `grafana-clock-panel`, `grafana-worldmap-panel`
