import json
import argparse
import math

def subdivide_trapezoid_depthwise(input_file, n_rects, output_file):
    with open(input_file) as f:
        data = json.load(f)

    coords = data["features"][0]["geometry"]["coordinates"][0]
    p0 = [coords[0][0], coords[0][1]]  # top-left
    p1 = [coords[1][0], coords[1][1]]  # bottom-left
    p2 = [coords[2][0], coords[2][1]]  # bottom-right
    p3 = [coords[3][0], coords[3][1]]  # top-right

    # We'll slice along the depth direction: from front (P0,P3) to back (P1,P2)
    # Each rectangle will span full width at that depth slice

    rects = []
    for i in range(n_rects):
        t = i / n_rects
        t_next = (i + 1) / n_rects

        # Interpolate left side (P0 -> P1)
        x_left_start = p0[0] + t * (p1[0] - p0[0])
        y_left_start = p0[1] + t * (p1[1] - p0[1])
        x_left_end = p0[0] + t_next * (p1[0] - p0[0])
        y_left_end = p0[1] + t_next * (p1[1] - p0[1])

        # Interpolate right side (P3 -> P2)
        x_right_start = p3[0] + t * (p2[0] - p3[0])
        y_right_start = p3[1] + t * (p2[1] - p3[1])
        x_right_end = p3[0] + t_next * (p2[0] - p3[0])
        y_right_end = p3[1] + t_next * (p2[1] - p3[1])

        # Rectangle corners: top-left, top-right, bottom-right, bottom-left
        rect = [
            [x_left_start, y_left_start],
            [x_right_start, y_right_start],
            [x_right_end, y_right_end],
            [x_left_end, y_left_end],
            [x_left_start, y_left_start]
        ]

        rects.append(rect)

    features = []
    for i, rect in enumerate(rects):
        features.append({
            "type": "Feature",
            "properties": {"id": i + 1},
            "geometry": {
                "type": "Polygon",
                "coordinates": [rect]
            }
        })

    out = {"type": "FeatureCollection", "features": features}
    with open(output_file, "w") as f:
        json.dump(out, f, indent=2)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Subdivide trapezoid GeoJSON into rectangles along depth")
    parser.add_argument("input_file", help="Input GeoJSON file")
    parser.add_argument("n_rects", type=int, help="Number of rectangles to subdivide into")
    parser.add_argument("output_file", help="Output GeoJSON file")
    args = parser.parse_args()

    subdivide_trapezoid_depthwise(args.input_file, args.n_rects, args.output_file)
