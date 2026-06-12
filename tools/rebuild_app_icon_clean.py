from PIL import Image, ImageFilter, ImageOps

SRC = "Resources/Assets.xcassets/AppIcon.appiconset/appicon_old.png"
DST = "Resources/Assets.xcassets/AppIcon.appiconset/appicon.png"

# Style tuned to match the clean sample icon look.
BG = (247, 244, 236)        # warm off-white
MARK = (45, 152, 166)       # single-tone teal

im = Image.open(SRC).convert("RGB")
w, h = im.size
hsv = im.convert("HSV")

# Detect only teal/cyan shield pixels from source.
mask = Image.new("L", (w, h), 0)
mask_px = mask.load()
for idx, (hh, ss, vv) in enumerate(hsv.getdata()):
    x = idx % w
    y = idx // w
    if 105 <= hh <= 145 and ss >= 45 and vv >= 35:
        mask_px[x, y] = 255

# Clean mask and take bounds.
mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(0.8))
bbox = mask.getbbox()
if bbox is None:
    raise RuntimeError("Could not detect shield mark from source icon")

x0, y0, x1, y1 = bbox
pad = 10
x0 = max(0, x0 - pad)
y0 = max(0, y0 - pad)
x1 = min(w, x1 + pad)
y1 = min(h, y1 + pad)
mark_mask = mask.crop((x0, y0, x1, y1))

# Slightly harden alpha so edges are crisp but anti-aliased.
mark_mask = mark_mask.point(lambda p: 255 if p > 90 else int(p * 0.9))

# Build final icon: single clean background + single-color mark.
out = Image.new("RGB", (1024, 1024), BG)
mark = Image.new("RGB", mark_mask.size, MARK)

# Fit mark prominently while keeping healthy breathing room.
fit_size = (620, 620)
mark = ImageOps.contain(mark, fit_size, Image.Resampling.LANCZOS)
mark_mask = ImageOps.contain(mark_mask, fit_size, Image.Resampling.LANCZOS)

px = (1024 - mark.size[0]) // 2
py = (1024 - mark.size[1]) // 2
out.paste(mark, (px, py), mark_mask)
out.save(DST, "PNG", optimize=True)

print("Saved", DST)
print("Shield bbox", bbox, "Final mark", mark.size, "at", (px, py))
