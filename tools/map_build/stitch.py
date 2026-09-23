import math
from PIL import Image
from bbox import *
Z = 14
def px(lon, lat):
    n = 2 ** Z * 256
    return (lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
X0, Y0 = px(WEST, NORTH); X1, Y1 = px(EAST, SOUTH)
tx0, ty0 = int(X0 // 256), int(Y0 // 256)
tx1, ty1 = int(X1 // 256), int(Y1 // 256)
big = Image.new("RGB", ((tx1 - tx0 + 1) * 256, (ty1 - ty0 + 1) * 256))
for tx in range(tx0, tx1 + 1):
    for ty in range(ty0, ty1 + 1):
        big.paste(Image.open(f"tiles/{Z}_{tx}_{ty}.jpg").convert("RGB"), ((tx - tx0) * 256, (ty - ty0) * 256))
crop = big.crop((int(X0 - tx0 * 256), int(Y0 - ty0 * 256), int(X1 - tx0 * 256), int(Y1 - ty0 * 256)))
crop.save("satellite_raw.png")
print(crop.size)
