import json
import argparse

def calculate_polygon_center(coordinates):
    """Calculate the centroid of a polygon given its coordinates."""
    x_coords = [point[0] for point in coordinates[:-1]]  # Exclude last point (duplicate of first)
    y_coords = [point[1] for point in coordinates[:-1]]
    
    center_x = sum(x_coords) / len(x_coords)
    center_y = sum(y_coords) / len(y_coords)
    
    return [center_x, center_y]

def extract_centers(input_file, output_file):
    with open(input_file, 'r') as f:
        data = json.load(f)
    
    centers = []
    
    for feature in data['features']:
        coords = feature['geometry']['coordinates'][0]  # Get the outer ring of the polygon
        center = calculate_polygon_center(coords)
        
        center_feature = {
            "type": "Feature",
            "properties": feature.get("properties", {}),
            "geometry": {
                "type": "Point",
                "coordinates": center
            }
        }
        centers.append(center_feature)
    
    result = {
        "type": "FeatureCollection",
        "features": centers
    }
    
    with open(output_file, 'w') as f:
        json.dump(result, f, indent=2)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract centers of rectangles from GeoJSON")
    parser.add_argument("input_file", help="Input GeoJSON file with rectangles")
    parser.add_argument("output_file", help="Output GeoJSON file with center points")
    args = parser.parse_args()
    
    extract_centers(args.input_file, args.output_file)
