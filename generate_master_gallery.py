import os
from PIL import Image, ImageDraw, ImageFont

SCREENSHOTS_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'

# We have 31 screens. Let's arrange them in a 6-column grid (5 rows: 6, 6, 6, 6, 7)
screens_sorted = sorted([f for f in os.listdir(SCREENSHOTS_DIR) if f.startswith('annotated_screen_') and f.endswith('.png')])
print(f"Found {len(screens_sorted)} annotated screens.")

thumb_w, thumb_h = 195, 422
cols = 6
rows = (len(screens_sorted) + cols - 1) // cols

canvas_w = cols * (thumb_w + 16) + 32
canvas_h = rows * (thumb_h + 40) + 120

gallery = Image.new("RGB", (canvas_w, canvas_h), (15, 23, 42))
draw = ImageDraw.Draw(gallery)

# Header
draw.text((32, 28), "SPENDWISE PRO — 31-SCREEN AUDIT CONTACT SHEET", fill=(255, 255, 255))
draw.text((32, 54), "Complete Mobile Viewport (390 x 844) Automated UI/UX Inspection Across All 10 Application Modules", fill=(148, 163, 184))

for idx, fname in enumerate(screens_sorted):
    c = idx % cols
    r = idx // cols
    x = 32 + c * (thumb_w + 16)
    y = 90 + r * (thumb_h + 40)
    
    path = os.path.join(SCREENSHOTS_DIR, fname)
    im = Image.open(path)
    im_thumb = im.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
    
    # White card border
    draw.rounded_rectangle([x - 2, y - 2, x + thumb_w + 2, y + thumb_h + 2], radius=6, outline=(51, 65, 85), width=2)
    gallery.paste(im_thumb, (x, y))
    
    # Label
    # Extract clean title from fname: annotated_screen_01_splash.png -> 01 Splash
    clean_title = fname.replace("annotated_screen_", "").replace(".png", "").replace("_", " ").title()
    draw.text((x, y + thumb_h + 6), clean_title[:24], fill=(226, 232, 240))

out_path = os.path.join(SCREENSHOTS_DIR, "master_31_screen_gallery.png")
gallery.save(out_path)
print(f"Master gallery saved: {out_path} ({os.path.getsize(out_path)} bytes)")
