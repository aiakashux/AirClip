"""Import the ten original 24px Figma file icons into both app asset sets.

Usage: python3 scripts/import-file-icons.py /path/to/figma/svg/exports
"""

import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


SOURCE_NAMES = {
    "Any document file like word, doc": "document",
    "ppt": "presentation",
    "exe Or any other Windows installer file": "windows_installer",
    "dmg, ipa": "apple_installer",
    "Android APK.": "android_installer",
    "Any code file, HTML,CSS, and others": "code",
    "Any audio": "audio",
    "Any video": "video",
    "zip": "zip",
    "rar": "rar",
}

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
android = root / "android/app/src/main/res/drawable"
mac = root / "mac/Airclip/Assets.xcassets"
android.mkdir(parents=True, exist_ok=True)

for figma_name, name in SOURCE_NAMES.items():
    original = source / (figma_name + ".svg")
    svg = ET.parse(original).getroot()
    image_set = mac / ("FileIcon" + "".join(part.title() for part in name.split("_")) + ".imageset")
    image_set.mkdir(parents=True, exist_ok=True)
    (image_set / "icon.svg").write_bytes(original.read_bytes())
    (image_set / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "icon.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }, indent=2) + "\n")

    vector = ET.Element("vector", {
        "xmlns:android": "http://schemas.android.com/apk/res/android",
        "android:width": "24dp", "android:height": "24dp",
        "android:viewportWidth": "24", "android:viewportHeight": "24",
    })
    for path in svg.findall("{http://www.w3.org/2000/svg}path"):
        attrs = {
            "android:pathData": path.attrib["d"],
            "android:fillColor": {"white": "#FFFFFF", "black": "#000000"}.get(
                path.attrib.get("fill", "#000000"), path.attrib.get("fill", "#000000")
            ),
        }
        if "fill-opacity" in path.attrib:
            attrs["android:fillAlpha"] = path.attrib["fill-opacity"]
        ET.SubElement(vector, "path", attrs)
    ET.indent(vector, space="    ")
    ET.ElementTree(vector).write(android / f"file_icon_{name}.xml", encoding="utf-8", xml_declaration=True)
