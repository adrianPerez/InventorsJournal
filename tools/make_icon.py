"""Generate app/icon.ico and app/icon.png (a journal with a light bulb).

Run:  python tools/make_icon.py   (requires Pillow)
"""
from pathlib import Path
from PIL import Image, ImageDraw

S = 1024  # draw large, downsample for crisp edges
NAVY, CREAM, LINE, AMBER, DARK = "#1C4E80", "#FAF6EC", "#CFC7B5", "#F2A65A", "#23211D"

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
# book cover
d.rounded_rectangle((150, 90, 874, 934), radius=70, fill=NAVY)
# pages
d.rounded_rectangle((250, 150, 820, 874), radius=40, fill=CREAM)
# spine binding rings
for y in range(210, 860, 110):
    d.rounded_rectangle((185, y, 300, y + 40), radius=20, fill=LINE, outline=DARK, width=8)
# ruled lines
for y in range(560, 840, 70):
    d.line((330, y, 760, y), fill=LINE, width=14)
# light bulb
cx, cy, r = 545, 340, 135
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=AMBER, outline=DARK, width=14)
d.rectangle((cx - 60, cy + 110, cx + 60, cy + 175), fill=AMBER, outline=DARK, width=14)
d.line((cx - 60, cy + 205, cx + 60, cy + 205), fill=DARK, width=22)
# filament
d.line((cx - 45, cy + 10, cx, cy + 60, cx + 45, cy + 10), fill=DARK, width=12, joint="curve")

out = Path(__file__).resolve().parent.parent / "app"
img.resize((256, 256), Image.LANCZOS).save(out / "icon.png")
img.resize((256, 256), Image.LANCZOS).save(
    out / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("wrote", out / "icon.ico", "and", out / "icon.png")
