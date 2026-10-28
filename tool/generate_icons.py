"""Generate DUMIYA Android/iOS launcher icons from the approved brand image."""
import base64
import io
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

source = Image.open(ROOT / "tool" / "dumiya_icon.png").convert("RGB")

android_sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for density, size in android_sizes.items():
    output = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}" / "ic_launcher.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    source.resize((size, size), Image.Resampling.LANCZOS).save(output)

# Use the app's native generated AppIcon asset catalog.
catalog = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
catalog.mkdir(parents=True, exist_ok=True)
contents = catalog / "Contents.json"
if contents.exists():
    data = json.loads(contents.read_text(encoding="utf-8"))
    for entry in data.get("images", []):
        filename = entry.get("filename")
        if not filename:
            continue
        point_size = entry.get("size", "1024x1024").split("x")[0]
        scale = entry.get("scale", "1x").rstrip("x")
        pixels = round(float(point_size) * float(scale))
        source.resize((pixels, pixels), Image.Resampling.LANCZOS).save(catalog / filename)

# Keep the original package ID and configure only the display label.
manifest = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
if manifest.exists():
    text = manifest.read_text(encoding="utf-8")
    text = re.sub(r'android:label="[^"]*"', 'android:label="DUMIYA"', text, count=1)
    manifest.write_text(text, encoding="utf-8")

plist = ROOT / "ios" / "Runner" / "Info.plist"
if plist.exists():
    text = plist.read_text(encoding="utf-8")
    if "<key>CFBundleDisplayName</key>" in text:
        text = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
                      r'\1DUMIYA\2', text, count=1)
    else:
        text = text.replace("</dict>", "<key>CFBundleDisplayName</key>\n<string>DUMIYA</string>\n</dict>", 1)
    plist.write_text(text, encoding="utf-8")
print("DUMIYA launcher icons generated for Android and iOS")
