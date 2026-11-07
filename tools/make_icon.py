"""Builds the 1024 x 1024 App Store icon from the website icon (tools/icon-base-512.png).

The pixel gamepad shape is kept exactly; this adds depth: a rich blue gradient with a soft glow, a lit white body, a drop
shadow, a dark d-pad and an amber button cluster (the site's accent colour). Run: python tools/make_icon.py
"""
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 1024
src = Image.open("tools/icon-base-512.png").convert("RGB")

# 1. the pad: bright pixels of the original icon, enlarged without blurring so the pixel grid stays crisp
gray = np.asarray(src.convert("L"))
mask512 = Image.fromarray(((gray > 205) * 255).astype("uint8"))
ys, xs = np.where(np.asarray(mask512) > 0)
box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
pad = mask512.crop(box)
scale = 2.5                      # the pad is 256 px wide in the original; 640 px here
pad = pad.resize((int(pad.width * scale), int(pad.height * scale)), Image.NEAREST)
mask = Image.new("L", (S, S), 0)
ox, oy = (S - pad.width) // 2, (S - pad.height) // 2 - 8
mask.paste(pad, (ox, oy))

# 2. enclosed holes (the d-pad and the buttons): everything not reachable from the outside
flood = mask.copy()
ImageDraw.floodfill(flood, (2, 2), 128)
holes = Image.fromarray(((np.asarray(flood) == 0) * 255).astype("uint8"))
cx = ox + pad.width / 2
left = Image.fromarray((np.asarray(holes) * (np.arange(S)[None, :] < cx)).astype("uint8"))
right = ImageChops.subtract(holes, left)
body = ImageChops.lighter(mask, holes)       # the pad including its holes

# 3. background: deep blue gradient + glow
yy, xx = np.mgrid[0:S, 0:S].astype("float32")
t = (yy / (S - 1))
top = np.array([34, 120, 255], np.float32)
mid = np.array([22, 84, 214], np.float32)
bot = np.array([16, 34, 120], np.float32)
bg = np.where(t[..., None] < 0.5, top + (mid - top) * (t[..., None] / 0.5), mid + (bot - mid) * ((t[..., None] - 0.5) / 0.5))
glow = np.exp(-(((xx - S / 2) ** 2 + (yy - S * 0.38) ** 2) / (2 * (S * 0.34) ** 2)))[..., None]
bg = bg + glow * np.array([55, 70, 60], np.float32)
vign = 1 - 0.28 * (((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / ((S * 0.72) ** 2))[..., None]
bg = np.clip(bg * vign, 0, 255)
img = Image.fromarray(bg.astype("uint8")).convert("RGBA")

# 4. shadow, then the pad body
shadow = Image.new("RGBA", (S, S), (6, 14, 60, 0))
shadow.putalpha(ImageChops.offset(body, 0, 26).filter(ImageFilter.GaussianBlur(26)).point(lambda v: int(v * 0.55)))
img = Image.alpha_composite(img, shadow)

pbody = np.asarray(body).astype("float32") / 255
g = np.clip((yy - oy) / pad.height, 0, 1)[..., None]
light = np.array([255, 255, 255], np.float32)
dark = np.array([196, 214, 255], np.float32)
fill = light + (dark - light) * g
rim = np.asarray(ImageChops.subtract(body, ImageChops.offset(body, 0, 10))).astype("float32")[..., None] / 255   # lit top edge
fill = fill + rim * 0.0
layer = Image.fromarray(np.clip(fill, 0, 255).astype("uint8")).convert("RGBA")
layer.putalpha(body)
img = Image.alpha_composite(img, layer)

# bottom edge of each pixel mass, slightly darker, gives the body a little thickness
edge = ImageChops.subtract(body, ImageChops.offset(body, 0, -12))
edge_layer = Image.new("RGBA", (S, S), (120, 150, 235, 0))
edge_layer.putalpha(edge.point(lambda v: int(v * 0.55)))
img = Image.alpha_composite(img, edge_layer)

# 5. holes: dark navy d-pad, amber buttons with a little light
dpad = Image.new("RGBA", (S, S), (14, 40, 130, 0))
dpad.putalpha(left)
img = Image.alpha_composite(img, dpad)

amber_top, amber_bot = np.array([255, 195, 82], np.float32), np.array([255, 150, 20], np.float32)
r_ys, r_xs = np.where(np.asarray(right) > 0)
ry0, ry1 = r_ys.min(), r_ys.max() + 1
ga = np.clip((yy - ry0) / max(1, ry1 - ry0), 0, 1)[..., None]
amber = Image.fromarray((amber_top + (amber_bot - amber_top) * ga).astype("uint8")).convert("RGBA")
amber.putalpha(right)
buttons_glow = Image.new("RGBA", (S, S), (255, 176, 32, 0))
buttons_glow.putalpha(right.filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.6)))
img = Image.alpha_composite(img, buttons_glow)
img = Image.alpha_composite(img, amber)

img.convert("RGB").save("RetroManette/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png", optimize=True)
print("icon written", img.size)
