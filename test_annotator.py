import os
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'

def load_font(size, bold=False):
    for fp in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
    ]:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, size)
            except Exception:
                pass
    return ImageFont.load_default()

def create_screen_annotated_card(sc_id, sc_name, route, defects):
    mob_path = f"{OUTPUT_DIR}/recapture_mobile_{sc_id}.png"
    ipad_path = f"{OUTPUT_DIR}/recapture_ipad_{sc_id}.png"
    
    mob_img = Image.open(mob_path)
    ipad_img = Image.open(ipad_path)

    # Scale images to standard height
    target_h = 420
    mob_scaled_w = int(mob_img.width * (target_h / mob_img.height))
    mob_scaled = mob_img.resize((mob_scaled_w, target_h), Image.Resampling.LANCZOS)

    ipad_scaled_w = int(ipad_img.width * (target_h / ipad_img.height))
    ipad_scaled = ipad_img.resize((ipad_scaled_w, target_h), Image.Resampling.LANCZOS)

    header_h = 46
    footer_h = 36
    gap = 20
    pad = 16
    total_w = mob_scaled_w + ipad_scaled_w + gap + pad * 2
    total_h = header_h + target_h + footer_h + pad * 2

    canvas = Image.new('RGB', (total_w, total_h), (248, 250, 252))
    draw = ImageDraw.Draw(canvas)

    # Header
    draw.rectangle([0, 0, total_w, header_h], fill=(15, 23, 42))
    draw.text((pad, 12), f"SCREEN {sc_id.upper()} • {sc_name.upper()}", fill=(255, 255, 255), font=load_font(13, bold=True))
    draw.text((total_w - 220, 14), f"ROUTE: #{route}", fill=(148, 163, 184), font=load_font(10, bold=False))

    # Paste Mobile Image
    mob_x = pad
    mob_y = header_h + pad
    canvas.paste(mob_scaled, (mob_x, mob_y))
    draw.rectangle([mob_x, mob_y, mob_x + mob_scaled_w, mob_y + target_h], outline=(203, 213, 225), width=2)
    # Mobile Label Badge
    draw.rectangle([mob_x, mob_y - 20, mob_x + 130, mob_y], fill=(30, 41, 59))
    draw.text((mob_x + 6, mob_y - 16), "iPhone 15 Pro (9:19.5)", fill=(255, 255, 255), font=load_font(8, bold=True))

    # Paste iPad Image
    ipad_x = mob_x + mob_scaled_w + gap
    ipad_y = header_h + pad
    canvas.paste(ipad_scaled, (ipad_x, ipad_y))
    draw.rectangle([ipad_x, ipad_y, ipad_x + ipad_scaled_w, ipad_y + target_h], outline=(203, 213, 225), width=2)
    # iPad Label Badge
    draw.rectangle([ipad_x, ipad_y - 20, ipad_x + 160, ipad_y], fill=(30, 41, 59))
    draw.text((ipad_x + 6, ipad_y - 16), "iPad 10th Gen (1024x768 - 4:3)", fill=(255, 255, 255), font=load_font(8, bold=True))

    # Draw Red Defect Callouts / Markings on iPad or Mobile based on defect specs
    for d in defects:
        target = d.get('target', 'ipad')
        box = d.get('box', [0.1, 0.2, 0.9, 0.4]) # normalized [x1, y1, x2, y2]
        label = d.get('label', 'DEFECT DETECTED')
        
        bx = ipad_x if target == 'ipad' else mob_x
        bw = ipad_scaled_w if target == 'ipad' else mob_scaled_w
        by = ipad_y if target == 'ipad' else mob_y
        bh = target_h

        x1 = int(bx + box[0] * bw)
        y1 = int(by + box[1] * bh)
        x2 = int(bx + box[2] * bw)
        y2 = int(by + box[3] * bh)

        # Red bounding box
        draw.rectangle([x1, y1, x2, y2], outline=(239, 68, 68), width=3)
        # Red callout badge
        badge_w = min(len(label) * 7 + 16, bw - 20)
        draw.rectangle([x1, max(y1 - 22, by), x1 + badge_w, max(y1, by + 22)], fill=(239, 68, 68))
        draw.text((x1 + 6, max(y1 - 18, by + 4)), label[:35], fill=(255, 255, 255), font=load_font(9, bold=True))

    # Footer
    draw.rectangle([0, total_h - footer_h, total_w, total_h], fill=(241, 245, 249))
    draw.line([(0, total_h - footer_h), (total_w, total_h - footer_h)], fill=(226, 232, 240), width=1)
    status_summary = f"FORENSIC STATUS: {len(defects)} DEFECT(S) IDENTIFIED & MARKED • POST-PUSH AUDIT COMMIT 0d62f0b"
    draw.text((pad, total_h - footer_h + 10), status_summary, fill=(15, 23, 42), font=load_font(9, bold=True))

    out_file = f"{OUTPUT_DIR}/marked_screen_{sc_id}.png"
    canvas.save(out_file, quality=92)
    print(f"Generated marked screen card: {out_file} ({os.path.getsize(out_file)} bytes)")
    return out_file

# Test on 02_login and 09_submit_expense
create_screen_annotated_card(
    "02_login", "Login Screen", "/login",
    [
        {"target": "mob", "box": [0.08, 0.45, 0.92, 0.52], "label": "TOUCH TARGET 20DP < 48DP"},
        {"target": "mob", "box": [0.05, 0.82, 0.95, 0.92], "label": "COMPACT OVERFLOW 54PX"}
    ]
)
create_screen_annotated_card(
    "09_submit_expense", "Submit Expense Form", "/expenses/submit",
    [
        {"target": "ipad", "box": [0.04, 0.15, 0.96, 0.75], "label": "1024PX FULL-WIDTH BLOWOUT"},
        {"target": "mob", "box": [0.05, 0.05, 0.95, 0.95], "label": "1,012-LINE GOD WIDGET"}
    ]
)
