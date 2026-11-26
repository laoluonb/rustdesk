"""Export the supplied transparent mark for each native launcher (requires Pillow)."""
import base64
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Image.open(Path(__file__).with_name('source.png')).convert('RGBA')
MARK = SOURCE.crop(SOURCE.getbbox())
OUTPUTS = []


def icon(size, fraction=0.86, opaque=False):
    canvas = Image.new('RGBA', (size, size), (239, 248, 255, 255) if opaque else (0, 0, 0, 0))
    edge = max(1, round(size * fraction))
    scale = edge / max(MARK.size)
    mark = MARK.resize((round(MARK.width * scale), round(MARK.height * scale)),
                       Image.Resampling.LANCZOS)
    canvas.alpha_composite(mark, ((size - mark.width) // 2, (size - mark.height) // 2))
    return canvas.convert('RGB') if opaque else canvas


def save(path, image, **kwargs):
    destination = ROOT / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, **kwargs)
    OUTPUTS.append(path)


for path in ['res/icon.png', 'res/mac-icon.png', 'flutter/assets/icon.png']:
    save(path, icon(1024))
for path in ['res/icon.ico', 'res/tray-icon.ico', 'flutter/windows/runner/resources/app_icon.ico']:
    save(path, icon(256), sizes=[(s, s) for s in [16, 24, 32, 48, 64, 128, 256]])
save('flutter/macos/Runner/AppIcon.icns', icon(1024))
save('fastlane/metadata/android/en-US/images/icon.png', icon(512, opaque=True))
for name, size in [('32x32', 32), ('64x64', 64), ('128x128', 128), ('128x128@2x', 256)]:
    save(f'res/{name}.png', icon(size))
for theme, color in [('dark', 'black'), ('light', 'white')]:
    image = icon(44)
    silhouette = Image.new('RGBA', image.size, color)
    silhouette.putalpha(image.getchannel('A'))
    save(f'res/mac-tray-{theme}-x2.png', silhouette)

for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    base = f'flutter/android/app/src/main/res/mipmap-{density}/'
    for name in ['ic_launcher.png', 'ic_launcher_round.png']:
        save(base + name, icon(round(48 * scale)))
    save(base + 'ic_launcher_foreground.png', icon(round(108 * scale), fraction=0.60))
    image = icon(round(24 * scale))
    silhouette = Image.new('RGBA', image.size, 'white')
    silhouette.putalpha(image.getchannel('A'))
    save(base + 'ic_stat_logo.png', silhouette)

base = 'flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset/'
catalog = json.loads((ROOT / base / 'Contents.json').read_text())
for item in catalog['images']:
    if 'filename' in item:
        size = round(float(item['size'].split('x')[0]) * float(item['scale'].removesuffix('x')))
        save(base + item['filename'], icon(size, opaque=True))

# Linux's scalable launcher accepts an embedded PNG without an external file dependency.
png = base64.b64encode((ROOT / 'res/icon.png').read_bytes()).decode('ascii')
(ROOT / 'res/scalable.svg').write_text(
    '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
    'width="1024" height="1024" viewBox="0 0 1024 1024">'
    f'<image width="1024" height="1024" xlink:href="data:image/png;base64,{png}"/></svg>\n')
OUTPUTS.append('res/scalable.svg')
print(json.dumps(OUTPUTS, indent=2))
