#!/usr/bin/env python3
"""Source-backed dark palette checks; run from any directory, no dependencies."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
def rgb(value):
    return tuple(int(value[i:i+2], 16) / 255 for i in (0, 2, 4))
def blend(front, back, alpha):
    return tuple(a * alpha + b * (1-alpha) for a, b in zip(front, back))
def luminance(color):
    return sum(w * (v / 12.92 if v <= .04045 else ((v + .055) / 1.055)**2.4)
               for w, v in zip((.2126, .7152, .0722), color))
def contrast(a, b):
    x, y = sorted((luminance(a), luminance(b)))
    return (y + .05) / (x + .05)
mac = (ROOT / 'mac/Airclip/DesignTokens.swift').read_text()
android = (ROOT / 'android/app/src/main/java/com/airclip/airclip/ui/theme/AirclipTheme.kt').read_text()
palettes = {
    'mac': {name: rgb(value) for name, value in re.findall(r'static let (\w+)\s*= adaptive\("#([A-Fa-f0-9]{6})"', mac)},
    'android': {name: rgb(value) for name, value in re.findall(r'(\w+)\s*= Color\(0xFF([A-Fa-f0-9]{6})\)', android.split('fun darkAirclipColors()')[1].split('// ── CompositionLocal')[0])},
}
failures=[]; count=0
for platform, p in palettes.items():
    surfaces={key:p[key] for key in ('bgBase','bgElevated','bgFloating')}
    surfaces['active on floating']=blend(rgb('FFFFFF'),p['bgFloating'],.10)
    if platform=='mac': surfaces['selected segment']=rgb('36373A')
    surfaces['selected on floating']=blend(p['accent'],p['bgFloating'],.14)
    for token in ('textPrimary','textSecondary','textTertiary'):
        ratios=[contrast(p[token], bg) for bg in surfaces.values()]
        print(f'{platform:7} {token:20} minimum {min(ratios):.2f}:1')
        for name, bg in surfaces.items():
            count+=1
            if contrast(p[token],bg)<4.5: failures.append(f'{platform} {token} / {name}: {contrast(p[token],bg):.2f}')
    for token in (('accent','encryptedGreen','syncBlue','warningYellow','destructiveRed') if platform=='mac' else ('accent','green','blue','yellow','destructive')):
        for name in ('bgBase','bgElevated','bgFloating'):
            bg=surfaces[name]; count+=1
            if contrast(p[token],bg)<4.5: failures.append(f'{platform} {token} / {name}: {contrast(p[token],bg):.2f}')
    red=p['destructiveRed' if platform=='mac' else 'destructive']
    ink=p['onDestructive'] if platform=='mac' else rgb(re.search(r'onError\s*= Color\(0xFF([A-Fa-f0-9]{6})\)',android.split('internal fun buildDarkM3()')[1])[1])
    for alpha in (1,.86,.82):
        count+=1
        ratio=contrast(ink,blend(red,p['bgFloating'],alpha))
        print(f'{platform:7} destructive alpha {alpha:.2f}: {ratio:.2f}:1')
        if ratio<4.5: failures.append(f'{platform} destructive alpha {alpha}: {ratio:.2f}')
# Explicit content/overlay pairs that intentionally do not use a dark surface.
widget = (ROOT / 'android/app/src/main/java/com/airclip/airclip/widget/AirclipWidget.kt').read_text()
widget_accent = rgb(re.search(r'COLOR_ACCENT = Color.parseColor\("#([A-Fa-f0-9]{6})"', widget)[1])
extra = [
    ('widget action status dot', widget_accent, rgb('1C1C1E'), 3),
    ('QR loading on white', rgb('6740BF'), rgb('FFFFFF'), 3),
    ('swatch label over worst-case white', rgb('FFFFFF'), blend(rgb('000000'), rgb('FFFFFF'), .75), 4.5),
]
for platform, p in palettes.items():
    for key in (('syncBlue', 'destructiveRed') if platform == 'mac' else ('blue', 'destructive')):
        alpha = .08 if key.startswith('destructive') else .12
        extra.append((f'{platform} pairing {key}', p[key], blend(p[key], p['bgBase'], alpha), 4.5))
for name, fg, bg, target in extra:
    count += 1
    if contrast(fg, bg) < target: failures.append(f'{name}: {contrast(fg, bg):.2f}')
print(f'{count} contrast pairs checked')
if failures:
    raise SystemExit('\n'.join(failures))
print('PASS')
