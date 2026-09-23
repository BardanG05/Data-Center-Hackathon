"""Turns OpenStreetMap land use + Sentinel-2 imagery into the game's Bournemouth grid.

Inputs:  osm.json (Overpass, ODbL), satellite_raw.png (stitch.py output)
Outputs: town-builder/data/map.json, town-builder/assets/map/satellite.png, preview.png
"""
import json, math, collections
from PIL import Image, ImageDraw
from bbox import *

GRID_W, GRID_H = 48, 30
Z = 14
OUT = "../../town-builder"

def px(lon, lat):
    n = 2 ** Z * 256
    return (lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n

X0, Y0 = px(WEST, NORTH)
sat = Image.open("satellite_raw.png")
W, H = sat.size

def to_img(pt):
    x, y = px(pt["lon"], pt["lat"])
    return (x - X0, y - Y0)

# Class ids in paint order: later wins where polygons overlap.
CLASSES = ["residential", "town_centre", "open", "industrial", "green", "water", "sea"]
CID = {c: i for i, c in enumerate(CLASSES)}
TAGS = [
    ("landuse", {"residential"}, "residential"),
    ("landuse", {"commercial", "retail"}, "town_centre"),
    ("landuse", {"farmland", "meadow", "grass", "greenfield", "brownfield", "farmyard", "allotments", "orchard", "plant_nursery"}, "open"),
    ("leisure", {"golf_course", "pitch", "recreation_ground"}, "open"),
    ("landuse", {"industrial", "railway", "construction", "depot", "landfill", "quarry"}, "industrial"),
    ("leisure", {"park", "nature_reserve"}, "green"),
    ("natural", {"heath", "wood", "scrub", "wetland", "grassland"}, "green"),
    ("landuse", {"forest", "cemetery", "recreation_ground", "village_green"}, "green"),
    ("natural", {"water", "beach", "sand"}, "water"),
    ("landuse", {"reservoir", "basin"}, "water"),
]

def classify(tags):
    found = None
    for key, values, cls in TAGS:
        if tags.get(key) in values:
            if found is None or CID[cls] > CID[found]:
                found = cls
    return found

def rings_from_members(members):
    segs = [[to_img(p) for p in m["geometry"]] for m in members
            if m.get("type") == "way" and m.get("role", "outer") in ("outer", "") and m.get("geometry")]
    rings = []
    while segs:
        ring = segs.pop(0)
        changed = True
        while changed and ring[0] != ring[-1]:
            changed = False
            for i, s in enumerate(segs):
                if s[0] == ring[-1]: ring += s[1:]
                elif s[-1] == ring[-1]: ring += s[::-1][1:]
                elif s[-1] == ring[0]: ring = s + ring[1:]
                elif s[0] == ring[0]: ring = s[::-1] + ring[1:]
                else: continue
                segs.pop(i); changed = True; break
        rings.append(ring)
    return rings

data = json.load(open("osm.json", encoding="utf-8"))["elements"]
layers = collections.defaultdict(list)
coast, places = [], []
for el in data:
    tags = el.get("tags", {})
    if el["type"] == "node":
        if tags.get("name"):
            places.append((tags["name"], tags.get("place"), to_img(el)))
        continue
    if tags.get("natural") == "coastline":
        coast.append([to_img(p) for p in el["geometry"]])
        continue
    cls = classify(tags)
    if cls is None:
        continue
    if el["type"] == "way" and el.get("geometry"):
        layers[cls].append([to_img(p) for p in el["geometry"]])
    elif el["type"] == "relation":
        layers[cls] += rings_from_members(el.get("members", []))

# Label raster; default land is treated as residential (unlabelled urban fabric).
label = Image.new("L", (W, H), CID["residential"])
draw = ImageDraw.Draw(label)
for cls in CLASSES:
    for ring in layers.get(cls, []):
        if len(ring) >= 3:
            draw.polygon(ring, fill=CID[cls])

# Sea: flood from open water, bounded by the OSM coastline.
sea = Image.new("L", (W, H), 0)
sd = ImageDraw.Draw(sea)
for line in coast:
    sd.line(line, fill=255, width=3)
for seed in [(int(W * 0.7), H - 5), (5, H - 5), (W - 5, int(H * 0.75))]:
    if sea.getpixel(seed) == 0:
        ImageDraw.floodfill(sea, seed, 128)
lp, sp = label.load(), sea.load()
for y in range(H):
    for x in range(W):
        if sp[x, y] == 128:
            lp[x, y] = CID["sea"]

cw, ch = W / GRID_W, H / GRID_H
cells = []
for gy in range(GRID_H):
    row = ""
    for gx in range(GRID_W):
        counts = collections.Counter()
        for sy in range(8):
            for sx in range(8):
                counts[lp[int((gx + (sx + 0.5) / 8) * cw), int((gy + (sy + 0.5) / 8) * ch)]] += 1
        total = sum(counts.values())
        if counts[CID["sea"]] + counts[CID["water"]] > total * 0.5:
            cls = "sea" if counts[CID["sea"]] >= counts[CID["water"]] else "water"
        else:
            cls = CLASSES[max((c for c in counts if CLASSES[c] not in ("sea", "water")), key=lambda c: counts[c], default=CID["residential"])]
        row += {"residential": "r", "town_centre": "c", "open": "o", "industrial": "i", "green": "g", "water": "w", "sea": "s"}[cls]
    cells.append(row)

labels = []
wanted = {"Poole", "Parkstone", "Westbourne", "Bournemouth", "Boscombe", "Southbourne", "Winton", "Kinson", "Moordown",
          "Pokesdown", "Tuckton", "Christchurch", "Canford Heath", "Broadstone", "Branksome", "Charminster", "Queen's Park", "Throop", "Iford", "Talbot Village", "Wallisdown", "Ensbury Park", "Springbourne", "Littledown"}
seen = set()
for name, kind, (x, y) in places:
    if name in wanted and name not in seen and 0 <= x < W and 0 <= y < H:
        seen.add(name)
        labels.append({"name": name, "cell": [int(x / cw), int(y / ch)]})

json.dump({
    "schema_version": 1,
    "source": "OpenStreetMap contributors (ODbL), processed by tools/map_build/build_map.py",
    "imagery": "Sentinel-2 cloudless 2023 by EOX IT Services GmbH (contains modified Copernicus Sentinel data 2023), CC BY-NC-SA 4.0",
    "bbox": {"west": WEST, "east": EAST, "south": SOUTH, "north": NORTH},
    "legend": {"r": "residential", "c": "town_centre", "o": "open", "i": "industrial", "g": "green", "w": "water", "s": "sea"},
    "width": GRID_W, "height": GRID_H, "rows": cells, "labels": labels,
}, open(f"{OUT}/data/map.json", "w", encoding="utf-8"), indent=1)

import os
os.makedirs(f"{OUT}/assets/map", exist_ok=True)
sat.resize((GRID_W * 40, GRID_H * 40), Image.LANCZOS).save(f"{OUT}/assets/map/satellite.jpg", quality=88)

colors = {"r": (214, 160, 120), "c": (230, 90, 90), "o": (190, 220, 110), "i": (150, 150, 170), "g": (60, 140, 70), "w": (80, 160, 220), "s": (30, 70, 140)}
prev = sat.resize((GRID_W * 20, GRID_H * 20)).convert("RGB")
ov = Image.new("RGB", prev.size)
od = ImageDraw.Draw(ov)
for gy, row in enumerate(cells):
    for gx, c in enumerate(row):
        od.rectangle([gx * 20, gy * 20, gx * 20 + 19, gy * 20 + 19], fill=colors[c])
Image.blend(prev, ov, 0.6).save("preview.png")
print(collections.Counter("".join(cells)), [l["name"] for l in labels])
