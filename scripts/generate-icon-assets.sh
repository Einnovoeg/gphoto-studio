#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCES_DIR="${ROOT_DIR}/resources"
PNG_PATH="${PNG_PATH:-${RESOURCES_DIR}/gphoto-studio-1024.png}"
ICNS_PATH="${ICNS_PATH:-${RESOURCES_DIR}/gphoto-studio.icns}"
ICONSET_DIR="${ICONSET_DIR:-${RESOURCES_DIR}/gphoto-studio.iconset}"

mkdir -p "${RESOURCES_DIR}"

python3 - <<'PY' "${PNG_PATH}"
from PIL import Image, ImageDraw, ImageFilter
import math
import sys

out_path = sys.argv[1]
size = 1024

img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Deep teal gradient background.
for y in range(size):
    t = y / (size - 1)
    r = int(10 + 18 * t)
    g = int(28 + 42 * t)
    b = int(44 + 70 * t)
    draw.line((0, y, size, y), fill=(r, g, b, 255))

# Subtle vignette to add depth.
vignette = Image.new("L", (size, size), 0)
vdraw = ImageDraw.Draw(vignette)
margin = 70
vdraw.ellipse((margin, margin, size - margin, size - margin), fill=255)
vignette = vignette.filter(ImageFilter.GaussianBlur(90))
img.putalpha(vignette)

# Camera body.
body = Image.new("RGBA", (size, size), (0, 0, 0, 0))
bdraw = ImageDraw.Draw(body)
body_color = (236, 245, 250, 245)
shadow_color = (0, 0, 0, 110)

shadow_box = (180, 300, 844, 770)
bdraw.rounded_rectangle(shadow_box, radius=120, fill=shadow_color)
body = body.filter(ImageFilter.GaussianBlur(12))
img = Image.alpha_composite(img, body)

body = Image.new("RGBA", (size, size), (0, 0, 0, 0))
bdraw = ImageDraw.Draw(body)
main_box = (170, 280, 854, 760)
bdraw.rounded_rectangle(main_box, radius=120, fill=body_color)

# Top hump / prism shape.
bdraw.rounded_rectangle((260, 210, 530, 350), radius=45, fill=(245, 251, 255, 250))

# Lens rings.
center = (512, 520)
for radius, color in [
    (205, (16, 36, 58, 255)),
    (176, (30, 66, 98, 255)),
    (140, (44, 104, 148, 255)),
    (92, (12, 32, 54, 255)),
]:
    bdraw.ellipse((center[0]-radius, center[1]-radius, center[0]+radius, center[1]+radius), fill=color)

# Shutter blades.
blade_color = (120, 206, 245, 190)
for i in range(6):
    a0 = math.radians(i * 60 - 10)
    a1 = math.radians(i * 60 + 38)
    r0 = 24
    r1 = 110
    p0 = (center[0] + r0 * math.cos(a0), center[1] + r0 * math.sin(a0))
    p1 = (center[0] + r1 * math.cos(a0), center[1] + r1 * math.sin(a0))
    p2 = (center[0] + r1 * math.cos(a1), center[1] + r1 * math.sin(a1))
    p3 = (center[0] + r0 * math.cos(a1), center[1] + r0 * math.sin(a1))
    bdraw.polygon((p0, p1, p2, p3), fill=blade_color)

# Lens center + glossy highlight.
bdraw.ellipse((center[0]-56, center[1]-56, center[0]+56, center[1]+56), fill=(6, 18, 30, 255))
bdraw.ellipse((center[0]-32, center[1]-118, center[0]+118, center[1]+32), fill=(190, 240, 255, 80))

# Small status light.
bdraw.ellipse((715, 375, 762, 422), fill=(248, 76, 68, 240))

img = Image.alpha_composite(img, body)

# Rounded app mask.
mask = Image.new("L", (size, size), 0)
mdraw = ImageDraw.Draw(mask)
mdraw.rounded_rectangle((22, 22, size - 22, size - 22), radius=220, fill=255)
img.putalpha(mask)

img.save(out_path)
print(f"Wrote {out_path}")
PY

rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

sips -z 16 16     "${PNG_PATH}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32     "${PNG_PATH}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "${PNG_PATH}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64     "${PNG_PATH}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "${PNG_PATH}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256   "${PNG_PATH}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "${PNG_PATH}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512   "${PNG_PATH}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "${PNG_PATH}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
cp "${PNG_PATH}" "${ICONSET_DIR}/icon_512x512@2x.png"

iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}"

echo "Wrote ${ICNS_PATH}"
