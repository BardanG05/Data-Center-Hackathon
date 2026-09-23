# Downloads Sentinel-2 cloudless (EOX, CC BY-NC-SA 4.0) tiles covering the game bbox.
import math, os, urllib.request
from bbox import *
Z = 14
def tile(lon, lat, z=Z):
    n = 2 ** z
    x = (lon + 180) / 360 * n
    y = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
    return x, y
x0, y0 = tile(WEST, NORTH); x1, y1 = tile(EAST, SOUTH)
os.makedirs("tiles", exist_ok=True)
for tx in range(int(x0), int(x1) + 1):
    for ty in range(int(y0), int(y1) + 1):
        p = f"tiles/{Z}_{tx}_{ty}.jpg"
        if os.path.exists(p): continue
        url = f"https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2023_3857/default/g/{Z}/{ty}/{tx}.jpg"
        req = urllib.request.Request(url, headers={"User-Agent": "uni-hackathon-map/1.0"})
        open(p, "wb").write(urllib.request.urlopen(req, timeout=30).read())
print("tiles", int(x0), int(x1), int(y0), int(y1))
