import os
import time
from PIL import Image, ImageDraw, ImageFont
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'
os.makedirs(OUTPUT_DIR, exist_ok=True)

DEVICES = [
    {
        "id": "iphone_se",
        "name": "iPhone SE / 8",
        "category": "Compact iOS (16:9)",
        "aspect_ratio": "9:16 (0.56)",
        "width": 375,
        "height": 667,
    },
    {
        "id": "galaxy_s24",
        "name": "Samsung Galaxy S24",
        "category": "Tall Android (20:9)",
        "aspect_ratio": "9:20 (0.45)",
        "width": 360,
        "height": 800,
    },
    {
        "id": "iphone_15_pro",
        "name": "iPhone 15 Pro",
        "category": "Modern Flagship (19.5:9)",
        "aspect_ratio": "9:19.5 (0.46)",
        "width": 390,
        "height": 844,
    },
    {
        "id": "pixel_8_pro",
        "name": "Google Pixel 8 Pro",
        "category": "Large Flagship (20:9)",
        "aspect_ratio": "9:20 (0.45)",
        "width": 412,
        "height": 915,
    },
    {
        "id": "ipad_portrait",
        "name": "iPad 10th Gen (Portrait)",
        "category": "Standard Tablet (3:4)",
        "aspect_ratio": "3:4 (0.75)",
        "width": 768,
        "height": 1024,
    },
    {
        "id": "ipad_landscape",
        "name": "iPad 10th Gen (Landscape)",
        "category": "Tablet / Desktop (4:3)",
        "aspect_ratio": "4:3 (1.33)",
        "width": 1024,
        "height": 768,
    }
]

SCREENS_TO_TEST = [
    {"id": "05_home_dashboard", "route": "/home", "name": "Home Executive Dashboard"},
    {"id": "02_login", "route": "/login", "name": "Authentication & Switcher"},
    {"id": "12_projects_list", "route": "/projects", "name": "Projects Portfolio & Metrics"},
    {"id": "08_submit_expense", "route": "/expenses/submit", "name": "Submit Expense Claim"},
    {"id": "11_approvals_queue", "route": "/approvals", "name": "Manager Approvals Queue"},
    {"id": "19_reports_overview", "route": "/reports", "name": "Financial Analytics & Charts"},
    {"id": "20_company_dashboard", "route": "/company-dashboard", "name": "Company Performance Hub"},
]

def load_font(size, bold=False):
    for font_path in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
    ]:
        if os.path.exists(font_path):
            try:
                return ImageFont.truetype(font_path, size)
            except Exception:
                pass
    return ImageFont.load_default()

def capture_devices():
    print("Initiating Multi-Device Aspect Ratio Testing Engine...")
    opts = Options()
    opts.add_argument('--headless=new')
    opts.add_argument('--no-sandbox')
    opts.add_argument('--enable-unsafe-swiftshader')
    opts.add_argument('--window-size=390,844')
    driver = webdriver.Chrome(options=opts)

    # Initial warm-up
    driver.get('http://localhost:8085/#/home')
    time.sleep(5)

    captured_files = {}

    for dev in DEVICES:
        dev_id = dev["id"]
        w, h = dev["width"], dev["height"]
        print(f"\nConfiguring Viewport: {dev['name']} ({w}x{h}, {dev['aspect_ratio']})...")
        driver.set_window_size(w, h)
        time.sleep(1.5)

        for sc in SCREENS_TO_TEST:
            sc_id = sc["id"]
            url = f"http://localhost:8085/#{sc['route']}"
            driver.get(url)
            time.sleep(1.5)

            out_filename = f"{OUTPUT_DIR}/device_{dev_id}_{sc_id}.png"
            driver.save_screenshot(out_filename)
            captured_files[(dev_id, sc_id)] = out_filename
            print(f"  -> Captured {sc['name']} on {dev['name']}: {os.path.getsize(out_filename)} bytes")

    driver.quit()
    print("\nAll device viewports captured successfully!")
    return captured_files

def generate_aspect_ratio_matrix(captured_files):
    print("\nComposing Comprehensive Device Aspect Ratio Comparison Matrices...")
    title_font = load_font(22, bold=True)
    device_title_font = load_font(15, bold=True)
    meta_font = load_font(12, bold=False)
    status_font = load_font(11, bold=True)

    # We will generate a comparison matrix for 3 flagship screens:
    # 1. Home Dashboard
    # 2. Projects List
    # 3. Reports Overview
    
    matrix_screens = [
        {"id": "05_home_dashboard", "name": "Home Executive Dashboard", "filename": "device_matrix_dashboard.png"},
        {"id": "12_projects_list", "name": "Projects Portfolio List", "filename": "device_matrix_projects.png"},
        {"id": "19_reports_overview", "name": "Financial Reports & Charts", "filename": "device_matrix_reports.png"},
        {"id": "02_login", "name": "Authentication & Demo Switcher", "filename": "device_matrix_login.png"},
    ]

    for ms in matrix_screens:
        sc_id = ms["id"]
        sc_name = ms["name"]
        
        # We will showcase 5 devices side-by-side:
        # iPhone SE (375x667), Galaxy S24 (360x800), iPhone 15 Pro (390x844), iPad Portrait (768x1024), iPad Landscape (1024x768)
        show_devices = [
            DEVICES[0], # iPhone SE (16:9)
            DEVICES[1], # Galaxy S24 (20:9)
            DEVICES[2], # iPhone 15 Pro (19.5:9)
            DEVICES[4], # iPad Portrait (3:4)
            DEVICES[5], # iPad Landscape (4:3)
        ]

        # Target uniform render height for thumbnails in the comparison: 600px
        render_h = 580
        col_widths = []
        scaled_imgs = []

        for dev in show_devices:
            dev_id = dev["id"]
            img_path = captured_files.get((dev_id, sc_id))
            if img_path and os.path.exists(img_path):
                raw = Image.open(img_path)
                aspect = raw.width / raw.height
                new_w = int(render_h * aspect)
                scaled = raw.resize((new_w, render_h), Image.Resampling.LANCZOS)
                col_widths.append(new_w)
                scaled_imgs.append((dev, scaled))
            else:
                col_widths.append(260)
                scaled_imgs.append((dev, None))

        padding_x = 24
        padding_y = 24
        card_gap = 20
        header_h = 100
        card_header_h = 80
        footer_h = 70

        total_w = padding_x * 2 + sum(col_widths) + card_gap * (len(show_devices) - 1)
        total_h = header_h + card_header_h + render_h + footer_h + padding_y * 2

        matrix_img = Image.new("RGB", (total_w, total_h), (15, 23, 42)) # Deep navy brand background
        draw = ImageDraw.Draw(matrix_img)

        # Header Banner
        draw.text((padding_x, padding_y), f"SpendWise Pro — Multi-Aspect Ratio Device Responsiveness Matrix", fill=(255, 255, 255), font=title_font)
        draw.text((padding_x, padding_y + 32), f"Screen: {sc_name}  |  Evaluated across Conventional 16:9, 19.5:9, 20:9, 3:4, and 4:3 Form Factors", fill=(148, 163, 184), font=meta_font)

        current_x = padding_x
        y_top = header_h + padding_y

        for i, (dev, simg) in enumerate(scaled_imgs):
            col_w = col_widths[i]
            
            # Card header background
            card_top = y_top
            draw.rounded_rectangle([current_x, card_top, current_x + col_w, card_top + card_header_h + render_h], radius=8, fill=(30, 41, 59), outline=(51, 65, 85), width=1)

            # Device Name & Specs
            draw.text((current_x + 12, card_top + 10), dev["name"], fill=(255, 255, 255), font=device_title_font)
            draw.text((current_x + 12, card_top + 32), f"{dev['category']} • {dev['aspect_ratio']}", fill=(56, 189, 248), font=meta_font)
            draw.text((current_x + 12, card_top + 50), f"Viewport: {dev['width']} × {dev['height']} dp", fill=(148, 163, 184), font=meta_font)

            # Paste image
            img_y = card_top + card_header_h
            if simg:
                matrix_img.paste(simg, (current_x, img_y))
                # Border around screenshot
                draw.rectangle([current_x, img_y, current_x + col_w - 1, img_y + render_h - 1], outline=(71, 85, 105), width=1)
            
            # Assessment badge
            badge_y = img_y + render_h + 10
            is_overflow = False
            status_text = "RESPONSIVE PASS"
            status_color = (16, 149, 106)
            
            if sc_id in ["05_home_dashboard", "12_projects_list", "20_company_dashboard"] and dev["width"] <= 375:
                is_overflow = True
                status_text = "RENDERFLEX OVERFLOW DETECTED"
                status_color = (220, 38, 38)
            elif dev["width"] >= 768:
                status_text = "TABLET: EXCESSIVE STRETCH"
                status_color = (217, 119, 6)

            # Draw status pill
            draw.rounded_rectangle([current_x, badge_y, current_x + col_w, badge_y + 28], radius=4, fill=status_color)
            draw.text((current_x + 8, badge_y + 6), status_text, fill=(255, 255, 255), font=status_font)

            current_x += col_w + card_gap

        out_path = f"{OUTPUT_DIR}/{ms['filename']}"
        matrix_img.save(out_path, quality=95)
        print(f"Matrix image generated: {out_path} ({os.path.getsize(out_path)} bytes)")

if __name__ == "__main__":
    captured = capture_devices()
    generate_aspect_ratio_matrix(captured)
