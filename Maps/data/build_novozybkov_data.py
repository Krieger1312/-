"""One-off data-prep tool, not run by the game. Converts a raw Overpass API
export for Novozybkov into the compact novozybkov_map.json that
Maps/OsmMapBuilder.gd reads at runtime.

To regenerate novozybkov_osm.json (not checked in -- ~2MB, this script's
input), POST this Overpass QL query to https://overpass-api.de/api/interpreter
(Content-Type: application/x-www-form-urlencoded, body `data=<query>`):

    [out:json][timeout:60];
    (
      way["highway"~"^(trunk|primary|secondary|tertiary|unclassified|residential|track)$"](52.45,31.82,52.62,32.05);
      way["waterway"="river"](52.45,31.82,52.62,32.05);
      way["natural"="water"](52.45,31.82,52.62,32.05);
      way["landuse"="forest"](52.45,31.82,52.62,32.05);
      way["natural"="wood"](52.45,31.82,52.62,32.05);
      way["landuse"="residential"](52.45,31.82,52.62,32.05);
    );
    out body geom;

Then run: python3 build_novozybkov_data.py
"""

import json
import math
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(SCRIPT_DIR, "novozybkov_osm.json")
DST = os.path.join(SCRIPT_DIR, "novozybkov_map.json")

# Novozybkov town center, from Nominatim (osm relation 19111379).
LAT0, LON0 = 52.5364885, 31.9335455
M_PER_DEG_LAT = 111320.0
M_PER_DEG_LON = 111320.0 * math.cos(math.radians(LAT0))

# The Overpass bbox also swept up separate outlying villages; keep the town
# core tight and cap roads/forest/river to the town's immediate surroundings
# ("прилегающие территории"), not those unrelated villages.
CITY_RADIUS = 3500.0
SURROUNDING_RADIUS = 8000.0

ROAD_TIERS = {
    "trunk": {"width": 10.0, "tier": 5},
    "primary": {"width": 9.0, "tier": 4},
    "secondary": {"width": 7.5, "tier": 3},
    "tertiary": {"width": 6.5, "tier": 2},
    "unclassified": {"width": 5.5, "tier": 1},
    "residential": {"width": 5.0, "tier": 1},
    "track": {"width": 3.0, "tier": 0},
}


def tagkey(element):
    tags = element.get("tags", {})
    for key in ("highway", "waterway", "natural", "landuse"):
        if key in tags:
            return key, tags[key]
    return None, None


def project(lat, lon):
    x = (lon - LON0) * M_PER_DEG_LON
    z = (lat - LAT0) * M_PER_DEG_LAT
    return round(x, 1), round(z, 1)


def within(points, radius):
    return any(math.hypot(x, z) <= radius for x, z in points)


def rdp(points, tolerance):
    """Ramer-Douglas-Peucker simplification on a list of (x, z) tuples."""
    if len(points) < 3:
        return points

    def perp_dist(pt, a, b):
        (x, z), (ax, az), (bx, bz) = pt, a, b
        dx, dz = bx - ax, bz - az
        if dx == 0 and dz == 0:
            return math.hypot(x - ax, z - az)
        t = ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)
        t = max(0.0, min(1.0, t))
        px, pz = ax + t * dx, az + t * dz
        return math.hypot(x - px, z - pz)

    dmax, index = 0.0, 0
    for i in range(1, len(points) - 1):
        d = perp_dist(points[i], points[0], points[-1])
        if d > dmax:
            dmax, index = d, i

    if dmax > tolerance:
        left = rdp(points[: index + 1], tolerance)
        right = rdp(points[index:], tolerance)
        return left[:-1] + right
    return [points[0], points[-1]]


def merge_lines(lines, snap=15.0):
    """Joins line strands end-to-end where their endpoints nearly touch."""
    lines = [list(line) for line in lines]
    changed = True
    while changed:
        changed = False
        for i in range(len(lines)):
            for j in range(len(lines)):
                if i == j or not lines[i] or not lines[j]:
                    continue
                a, b = lines[i], lines[j]
                if math.hypot(a[-1][0] - b[0][0], a[-1][1] - b[0][1]) < snap:
                    lines[i] = a + b[1:]
                    lines[j] = []
                    changed = True
        lines = [line for line in lines if line]
    return lines


def bounds_of(points):
    xs = [p[0] for p in points]
    zs = [p[1] for p in points]
    return {"min_x": min(xs), "max_x": max(xs), "min_z": min(zs), "max_z": max(zs)}


def main():
    with open(SRC) as f:
        elements = json.load(f)["elements"]

    roads = []
    river_lines = []
    water_polys = []
    forest_polys = []
    city_points = []

    for element in elements:
        geometry = element.get("geometry") or []
        if not geometry or any(node is None for node in geometry):
            continue
        points = [project(node["lat"], node["lon"]) for node in geometry]
        key, value = tagkey(element)

        if key == "highway" and value in ROAD_TIERS:
            if not within(points, SURROUNDING_RADIUS):
                continue
            info = ROAD_TIERS[value]
            roads.append(
                {"width": info["width"], "tier": info["tier"], "points": rdp(points, 3.0)}
            )
        elif key == "waterway" and value == "river" and within(points, SURROUNDING_RADIUS):
            river_lines.append(rdp(points, 5.0))
        elif key == "natural" and value == "water" and within(points, SURROUNDING_RADIUS):
            water_polys.append(rdp(points, 8.0))
        elif (
            key in ("natural", "landuse")
            and value in ("wood", "forest", "scrub")
            and within(points, SURROUNDING_RADIUS)
        ):
            forest_polys.append(rdp(points, 10.0))
        elif key == "landuse" and value == "residential" and within(points, CITY_RADIUS):
            city_points.extend(points)

    river_lines = merge_lines(river_lines)
    river_lines.sort(key=len, reverse=True)

    # Nearest real road point to the origin, so spawn markers land on an
    # actual street instead of an arbitrary coordinate that might sit inside
    # a city block.
    nearest_road_point = min(
        (p for r in roads for p in r["points"]),
        key=lambda p: p[0] * p[0] + p[1] * p[1],
        default=(0.0, 0.0),
    )

    out = {
        "source": "OpenStreetMap contributors, ODbL, fetched via Overpass API",
        "origin_lat": LAT0,
        "origin_lon": LON0,
        "city_bounds": bounds_of(city_points),
        "forest_bounds": bounds_of([p for poly in forest_polys for p in poly]),
        "roads": roads,
        "river_lines": river_lines[:3],
        "water_polys": water_polys,
        "town_center_road_point": nearest_road_point,
    }

    with open(DST, "w") as f:
        json.dump(out, f)

    print(f"roads: {len(roads)}, river strands: {len(river_lines)}, water polys: {len(water_polys)}")
    print(f"town_center_road_point: {nearest_road_point}")
    print(f"wrote {DST} ({os.path.getsize(DST)} bytes)")


if __name__ == "__main__":
    main()
