# GeoJSON Coordinate Processing Scripts

Scripts for processing GeoJSON files to create parking spot visualizations for the Grafana GeoMap dashboard.

## Overview

For the IC2 Parking, parking spots are grouped into 3 rectangles that represent the physical layout. These scripts help:

1. **Subdivide** large parking group rectangles into individual parking spot rectangles
2. **Calculate** the center point of each parking spot for status indicators

## Workflow

### 1. Draw Parking Groups

Use [geojson.io](https://geojson.io/) to draw rectangles representing parking groups. Export the GeoJSON file.

### 2. Subdivide into Individual Spots

```bash
python3 subdivide_rectangles.py <input_file> <num_spots> <output_file>
```

**Example:**
```bash
python3 subdivide_rectangles.py input_ps_00_07.geojson 8 ps_00_07.geojson
```

This takes a parking group rectangle and subdivides it into 8 individual parking spot rectangles.

### 3. Calculate Center Points

```bash
python3 get_rect_center.py <input_file> <output_file>
```

**Example:**
```bash
python3 get_rect_center.py ps_08_09.geojson center_ps_08_09.geojson
```

This calculates the center point of each rectangle, used to place status circles (free/occupied) on the GeoMap.

### 4. Use in Grafana

The resulting GeoJSON files are placed in the `grafana-user/geojson_layer/` directory and used as a GeoJSON Layer in Grafana's GeoMap panel.

## Scripts

### `subdivide_rectangles.py`

Divides a trapezoid/rectangle GeoJSON polygon into N equal rectangles along the depth direction.

**Arguments:**
- `input_file` - Input GeoJSON file with a single polygon
- `n_rects` - Number of rectangles to create
- `output_file` - Output GeoJSON file path

### `get_rect_center.py`

Extracts the centroid of each polygon in a GeoJSON FeatureCollection.

**Arguments:**
- `input_file` - Input GeoJSON file with polygons
- `output_file` - Output GeoJSON file with center points

## Sample Files

The `sample_files/` directory contains example input and output files:

- `input_ps_08_09.geojson` - Input parking group rectangle
- `ps_08_09.geojson` - Subdivided parking spot rectangles
- `center_ps_08_09.geojson` - Center points for status indicators

## Dependencies

- Python 3.x
- Standard library only (`json`, `argparse`, `math`)
