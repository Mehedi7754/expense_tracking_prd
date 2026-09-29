import os
from PIL import Image, ImageDraw

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'

# Compare Projects List Mobile vs Tablet
mobile_path = f"{OUTPUT_DIR}/annotated_screen_12_projects_list.png"
tablet_path = f"{OUTPUT_DIR}/raw_screen_12_projects_list_tablet.png"

im_mob = Image.open(mobile_path)
im_tab = Image.open(tablet_path)

# Resize to standard comparison height = 800
h = 800
mob_w = int(im_mob.width * (h / im_mob.height))
tab_w = int(im_tab.width * (h / im_tab.height))

im_mob_resized = im_mob.resize((mob_w, h), Image.Resampling.LANCZOS)
im_tab_resized = im_tab.resize((tab_w, h), Image.Resampling.LANCZOS)

comp_w = mob_w + tab_w + 60
comp_h = h + 130

canvas = Image.new("RGB", (comp_w, comp_h), (15, 23, 42))
draw = ImageDraw.Draw(canvas)

# Title
draw.text((25, 20), "MOBILE (390x844) VS TABLET (768x1024) RESPONSIVE AUDIT", fill=(255, 255, 255))
draw.text((25, 42), "Comparative Layout Evaluation on Projects Portfolio Screen", fill=(148, 163, 184))

# Paste Mobile
mob_x = 25
mob_y = 75
canvas.paste(im_mob_resized, (mob_x, mob_y))
draw.rectangle([mob_x, mob_y, mob_x + mob_w, mob_y + h], outline=(59, 130, 246), width=2)
draw.text((mob_x + 10, mob_y - 20), "MOBILE VIEWPORT (390 x 844 dp)", fill=(96, 165, 250))

# Paste Tablet
tab_x = mob_x + mob_w + 25
tab_y = 75
canvas.paste(im_tab_resized, (tab_x, tab_y))
draw.rectangle([tab_x, tab_y, tab_x + tab_w, tab_y + h], outline=(234, 179, 8), width=2)
draw.text((tab_x + 10, tab_y - 20), "TABLET VIEWPORT (768 x 1024 dp)", fill=(250, 204, 21))

# Problem Callouts on Tablet
draw.rounded_rectangle([tab_x + 20, tab_y + 120, tab_x + 480, tab_y + 175], radius=6, fill=(217, 119, 6), outline=(180, 83, 9), width=1)
draw.text((tab_x + 30, tab_y + 128), "RESPONSIVE FLAW: Unadapted Single-Column Card", fill=(255, 255, 255))
draw.text((tab_x + 30, tab_y + 148), "Card stretches across 740px; recommend 2-column masonry grid on tablet", fill=(254, 243, 199))

draw.rounded_rectangle([tab_x + 20, tab_y + 700, tab_x + 480, tab_y + 755], radius=6, fill=(217, 119, 6), outline=(180, 83, 9), width=1)
draw.text((tab_x + 30, tab_y + 708), "NAVIGATION INEFFICIENCY: Bottom Navigation Bar", fill=(255, 255, 255))
draw.text((tab_x + 30, tab_y + 728), "Bottom bar spans full iPad width; should adapt to vertical NavigationRail", fill=(254, 243, 199))

out_path = f"{OUTPUT_DIR}/mobile_vs_tablet_comparison.png"
canvas.save(out_path)
print(f"Saved mobile vs tablet comparison: {out_path} ({os.path.getsize(out_path)} bytes)")
