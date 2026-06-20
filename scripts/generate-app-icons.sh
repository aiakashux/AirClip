#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SOURCE="${1:-$ROOT_DIR/docs/app-icon/AirClipAppIcon.png}"

if [ ! -f "$SOURCE" ]; then
  echo "Missing source icon: $SOURCE" >&2
  echo "Export the Figma app icon as a 1024x1024 PNG, then rerun this script." >&2
  exit 1
fi

WIDTH="$(sips -g pixelWidth "$SOURCE" 2>/dev/null | awk '/pixelWidth/ {print $2; exit}')"
HEIGHT="$(sips -g pixelHeight "$SOURCE" 2>/dev/null | awk '/pixelHeight/ {print $2; exit}')"

if [ "$WIDTH" != "$HEIGHT" ]; then
  echo "Source icon must be square. Got ${WIDTH}x${HEIGHT}." >&2
  exit 1
fi

if [ "$WIDTH" -lt 1024 ]; then
  echo "Source icon should be at least 1024x1024. Got ${WIDTH}x${HEIGHT}." >&2
  exit 1
fi

make_png() {
  size="$1"
  out="$2"
  mkdir -p "$(dirname "$out")"
  sips -s format png -z "$size" "$size" "$SOURCE" --out "$out" >/dev/null
}

write_apple_catalog() {
  catalog="$1"
  platform="$2"
  mkdir -p "$catalog"
  cat > "$catalog/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "AirClipAppIcon-1024.png",
      "idiom" : "$platform",
      "platform" : "$platform",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
  make_png 1024 "$catalog/AirClipAppIcon-1024.png"
}

write_apple_catalog "$ROOT_DIR/mac/AirClip/Assets.xcassets/AppIcon.appiconset" "mac"
write_apple_catalog "$ROOT_DIR/ios/AirClip/Assets.xcassets/AppIcon.appiconset" "ios"

MAC_ICONSET="$ROOT_DIR/mac/AirClip/Resources/AirClip.iconset"
mkdir -p "$MAC_ICONSET"
make_png 16 "$MAC_ICONSET/icon_16x16.png"
make_png 32 "$MAC_ICONSET/icon_16x16@2x.png"
make_png 32 "$MAC_ICONSET/icon_32x32.png"
make_png 64 "$MAC_ICONSET/icon_32x32@2x.png"
make_png 128 "$MAC_ICONSET/icon_128x128.png"
make_png 256 "$MAC_ICONSET/icon_128x128@2x.png"
make_png 256 "$MAC_ICONSET/icon_256x256.png"
make_png 512 "$MAC_ICONSET/icon_256x256@2x.png"
make_png 512 "$MAC_ICONSET/icon_512x512.png"
make_png 1024 "$MAC_ICONSET/icon_512x512@2x.png"
iconutil -c icns "$MAC_ICONSET" -o "$ROOT_DIR/mac/AirClip/Resources/AirClip.icns"

python3 - "$SOURCE" "$ROOT_DIR/android/app/src/main/res" <<'PY'
import os
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

source = Path(sys.argv[1])
res_root = Path(sys.argv[2])
adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def read_png(path):
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")

    pos = 8
    raw = b""
    w = h = color_type = bit_depth = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            w, h, bit_depth, color_type, comp, filt, inter = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or color_type not in (2, 6) or comp or filt or inter:
                raise ValueError(f"Unsupported PNG format: {path}")
        elif kind == b"IDAT":
            raw += chunk
        elif kind == b"IEND":
            break

    channels = 4 if color_type == 6 else 3
    decoded = zlib.decompress(raw)
    stride = w * channels
    rows = []
    index = 0
    prev = [0] * stride
    for _ in range(h):
        filter_type = decoded[index]
        index += 1
        scan = list(decoded[index:index + stride])
        index += stride
        row = [0] * stride
        bpp = channels
        for i, value in enumerate(scan):
            left = row[i - bpp] if i >= bpp else 0
            up = prev[i]
            up_left = prev[i - bpp] if i >= bpp else 0
            if filter_type == 0:
                result = value
            elif filter_type == 1:
                result = (value + left) & 255
            elif filter_type == 2:
                result = (value + up) & 255
            elif filter_type == 3:
                result = (value + ((left + up) // 2)) & 255
            elif filter_type == 4:
                guess = left + up - up_left
                pa, pb, pc = abs(guess - left), abs(guess - up), abs(guess - up_left)
                predictor = left if pa <= pb and pa <= pc else up if pb <= pc else up_left
                result = (value + predictor) & 255
            else:
                raise ValueError(f"Unsupported PNG filter: {filter_type}")
            row[i] = result

        if channels == 3:
            rgba = []
            for x in range(w):
                offset = x * 3
                rgba.extend([row[offset], row[offset + 1], row[offset + 2], 255])
            rows.append(rgba)
        else:
            rows.append(row)
        prev = row

    return w, h, rows


def write_png(path, w, h, rows):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(png)


def resized_png(size):
    fd, temp_path = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    try:
        subprocess.run(
            ["sips", "-s", "format", "png", "-z", str(size), str(size), str(source), "--out", temp_path],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return read_png(temp_path)[2]
    finally:
        try:
            os.remove(temp_path)
        except FileNotFoundError:
            pass


def transparent_canvas(size):
    return [[0] * (size * 4) for _ in range(size)]


def black_canvas(size):
    row = []
    for _ in range(size):
        row.extend([0, 0, 0, 255])
    return [row[:] for _ in range(size)]


def overlay(dst, src, x0, y0):
    for y, src_row in enumerate(src):
        dst_row = dst[y0 + y]
        for x in range(len(src_row) // 4):
            src_offset = x * 4
            dst_offset = (x0 + x) * 4
            sr, sg, sb, sa = src_row[src_offset:src_offset + 4]
            if not sa:
                continue
            dr, dg, db, da = dst_row[dst_offset:dst_offset + 4]
            alpha = sa / 255
            inverse = 1 - alpha
            out_alpha = sa + da * inverse
            if out_alpha <= 0:
                dst_row[dst_offset:dst_offset + 4] = [0, 0, 0, 0]
            else:
                dst_row[dst_offset] = round((sr * sa + dr * da * inverse) / out_alpha)
                dst_row[dst_offset + 1] = round((sg * sa + dg * da * inverse) / out_alpha)
                dst_row[dst_offset + 2] = round((sb * sa + db * da * inverse) / out_alpha)
                dst_row[dst_offset + 3] = round(out_alpha)


def padded_icon(canvas_size, content_size, opaque_black=False):
    rows = black_canvas(canvas_size) if opaque_black else transparent_canvas(canvas_size)
    content = resized_png(content_size)
    offset = (canvas_size - content_size) // 2
    overlay(rows, content, offset, offset)
    return rows


for density, size in adaptive.items():
    content = round(size * 2 / 3)
    write_png(res_root / f"mipmap-{density}/ic_launcher_foreground.png", size, size, padded_icon(size, content))
    write_png(res_root / f"mipmap-{density}/ic_launcher_background.png", size, size, black_canvas(size))

for density, size in legacy.items():
    content = round(size * 2 / 3)
    write_png(res_root / f"mipmap-{density}/ic_launcher.png", size, size, padded_icon(size, content, opaque_black=True))
PY

cat > "$ROOT_DIR/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML

cat > "$ROOT_DIR/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML

MANIFEST="$ROOT_DIR/android/app/src/main/AndroidManifest.xml"
if ! grep -q 'android:icon="@mipmap/ic_launcher"' "$MANIFEST"; then
  perl -0pi -e 's/<application\n        android:allowBackup="false"/<application\n        android:allowBackup="false"\n        android:icon="@mipmap\\/ic_launcher"/' "$MANIFEST"
fi

if ! grep -q 'android:roundIcon="@mipmap/ic_launcher_round"' "$MANIFEST"; then
  perl -0pi -e 's/android:networkSecurityConfig="@xml\\/network_security_config"/android:networkSecurityConfig="@xml\\/network_security_config"\n        android:roundIcon="@mipmap\\/ic_launcher_round"/' "$MANIFEST"
fi

echo "Generated app icons from $SOURCE"
