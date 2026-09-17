#!/usr/bin/env python3
"""Sync the canonical icon catalog to both apps and build its visual index."""

import argparse
import html
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "icons/catalog.json"
ANDROID_NS = "http://schemas.android.com/apk/res/android"


def fmt(value):
    return f"{float(value):g}"


def vector_xml(svg_bytes):
    root = ET.fromstring(svg_bytes)
    viewbox = root.attrib["viewBox"].split()
    width, height = viewbox[2:]
    lines = [
        f'<vector xmlns:android="{ANDROID_NS}" android:width="{fmt(width)}dp" android:height="{fmt(height)}dp"',
        f'    android:viewportWidth="{fmt(width)}" android:viewportHeight="{fmt(height)}">',
    ]

    def emit(node, indent="    "):
        tag = node.tag.rsplit("}", 1)[-1]
        if tag == "path":
            attrs = [f'android:pathData="{html.escape(node.attrib["d"], quote=True)}"', 'android:fillColor="#FF000000"']
            opacity = node.attrib.get("opacity", node.attrib.get("fill-opacity"))
            if opacity:
                attrs.append(f'android:fillAlpha="{opacity}"')
            if node.attrib.get("fill-rule") == "evenodd" or node.attrib.get("clip-rule") == "evenodd":
                attrs.append('android:fillType="evenOdd"')
            lines.append(indent + "<path " + " ".join(attrs) + " />")
            return
        transform = node.attrib.get("transform", "")
        match = re.fullmatch(r"translate\(([-.\d]+)[ ,]+([-.\d]+)\)", transform)
        if match:
            lines.append(indent + f'<group android:translateX="{match.group(1)}" android:translateY="{match.group(2)}">')
            for child in node:
                emit(child, indent + "    ")
            lines.append(indent + "</group>")
        else:
            for child in node:
                emit(child, indent)

    emit(root)
    lines.append("</vector>")
    return ("\n".join(lines) + "\n").encode()


def gallery(icons):
    groups = {}
    for icon in icons:
        groups.setdefault(icon["category"], []).append(icon)
    sections = []
    for category, items in groups.items():
        cards = []
        for icon in items:
            key = icon["id"] + ((" / " + icon["variant"]) if icon.get("variant") else "")
            android = icon["android"].get("name", icon["android"].get("path"))
            search = " ".join((category, icon["label"], key, icon["mac"], android)).lower()
            cards.append(f'''<article data-search="{html.escape(search)}"><div class="art"><img src="{html.escape(icon['source'])}" alt=""></div><h3>{html.escape(icon['label'])}</h3><code>{html.escape(key)}</code><dl><dt>macOS</dt><dd>{html.escape(icon['mac'])}</dd><dt>Android</dt><dd>{html.escape(android)}</dd></dl></article>''')
        sections.append(f'<section><h2>{html.escape(category)}</h2><div class="grid">{"".join(cards)}</div></section>')
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Airclip icon library</title><style>
:root{{--ink:#151516;--muted:#696970;--line:#e5e5e8;--card:#f7f7f8;--purple:#7144d5}}*{{box-sizing:border-box}}body{{margin:0;color:var(--ink);font:14px system-ui,-apple-system,sans-serif;background:#fff}}main{{max-width:1160px;margin:auto;padding:48px 28px 80px}}header{{display:flex;align-items:end;justify-content:space-between;gap:24px;border-bottom:1px solid var(--line);padding-bottom:24px}}h1{{font-size:32px;margin:0 0 8px}}p{{color:var(--muted);margin:0}}input{{width:min(360px,100%);padding:12px 14px;border:1px solid var(--line);border-radius:12px;font:inherit}}section{{margin-top:40px}}h2{{font-size:19px;margin:0 0 16px}}.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(245px,1fr));gap:12px}}article{{border:1px solid var(--line);border-radius:16px;background:var(--card);padding:16px;min-width:0}}.art{{height:76px;display:grid;place-items:center;background:#fff;border-radius:11px;margin-bottom:14px}}img{{width:36px;height:36px;object-fit:contain}}h3{{font-size:15px;margin:0 0 5px}}code{{color:var(--purple);font-size:12px}}dl{{display:grid;grid-template-columns:58px minmax(0,1fr);gap:5px 8px;margin:14px 0 0;font-size:11px}}dt{{color:var(--muted)}}dd{{margin:0;overflow-wrap:anywhere}}[hidden]{{display:none}}@media(max-width:650px){{main{{padding:28px 18px}}header{{align-items:stretch;flex-direction:column}}}}
</style></head><body><main><header><div><h1>Airclip icon library</h1><p>{len(icons)} canonical icons · generated from <code>icons/catalog.json</code></p></div><input id="search" type="search" placeholder="Search icons…" aria-label="Search icons"></header>{''.join(sections)}</main><script>const q=document.querySelector('#search');q.addEventListener('input',()=>{{const s=q.value.toLowerCase().trim();document.querySelectorAll('article').forEach(x=>x.hidden=!x.dataset.search.includes(s));document.querySelectorAll('section').forEach(x=>x.hidden=![...x.querySelectorAll('article')].some(c=>!c.hidden))}})</script></body></html>'''.encode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    check = parser.parse_args().check
    icons = json.loads(CATALOG.read_text())["icons"]
    keys, macs, androids = set(), set(), set()
    outputs = {}
    for icon in icons:
        key = (icon["id"], icon.get("variant", "default"))
        target = icon["android"].get("name", icon["android"].get("path"))
        if key in keys or icon["mac"] in macs or target in androids:
            raise SystemExit(f"Duplicate catalog entry: {key}")
        keys.add(key); macs.add(icon["mac"]); androids.add(target)
        source = ROOT / "icons" / icon["source"]
        svg = source.read_bytes()
        asset = ROOT / "mac/Airclip/Assets.xcassets" / f'{icon["mac"]}.imageset'
        outputs[asset / f'{icon["mac"]}.svg'] = svg
        contents = {"images":[{"filename":f'{icon["mac"]}.svg',"idiom":"universal"}],"info":{"author":"xcode","version":1},"properties":{"preserves-vector-representation":True}}
        outputs[asset / "Contents.json"] = (json.dumps(contents, separators=(",", ":")) + "\n").encode()
        if icon["android"]["kind"] == "drawable":
            outputs[ROOT / "android/app/src/main/res/drawable" / f'{target}.xml'] = vector_xml(svg)
        else:
            outputs[ROOT / "android/app/src/main/assets" / target] = svg
    outputs[ROOT / "icons/icon-library.html"] = gallery(icons)
    stale = []
    for path, content in outputs.items():
        if not path.exists() or path.read_bytes() != content:
            stale.append(path.relative_to(ROOT))
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
    if stale:
        if check:
            print("Icon outputs are stale:\n" + "\n".join(map(str, stale)), file=sys.stderr)
            return 1
        print(f"Updated {len(stale)} icon outputs.")
    else:
        print("Icon outputs are current.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
