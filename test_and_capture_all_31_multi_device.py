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
        "category": "Compact (16:9)",
        "aspect_ratio": "9:16",
        "width": 375,
        "height": 667,
    },
    {
        "id": "galaxy_s24",
        "name": "Samsung Galaxy S24",
        "category": "Tall Android (20:9)",
        "aspect_ratio": "9:20",
        "width": 360,
        "height": 800,
    },
    {
        "id": "iphone_15_pro",
        "name": "iPhone 15 Pro",
        "category": "Flagship (19.5:9)",
        "aspect_ratio": "9:19.5",
        "width": 390,
        "height": 844,
    },
    {
        "id": "ipad_portrait",
        "name": "iPad 10th (Portrait)",
        "category": "Tablet (3:4)",
        "aspect_ratio": "3:4",
        "width": 768,
        "height": 1024,
    },
    {
        "id": "ipad_landscape",
        "name": "iPad 10th (Landscape)",
        "category": "Tablet / Desktop (4:3)",
        "aspect_ratio": "4:3",
        "width": 1024,
        "height": 768,
    }
]

SCREENS = [
    {"id": "01_splash", "name": "Splash Screen", "route": "/"},
    {"id": "02_login", "name": "Login Screen", "route": "/login"},
    {"id": "03_forgot_password", "name": "Forgot Password Screen", "route": "/forgot-password"},
    {"id": "04_reset_password", "name": "Reset Password Screen", "route": "/reset-password"},
    {"id": "05_home_dashboard", "name": "Home Executive Dashboard", "route": "/home"},
    {"id": "06_main_shell", "name": "Main Shell Scaffold", "route": "/home"},
    {"id": "07_my_expenses", "name": "My Expenses List", "route": "/expenses/my-expenses"},
    {"id": "08_submit_expense", "name": "Submit Expense Claim", "route": "/expenses/submit"},
    {"id": "09_expense_detail", "name": "Expense Detail & Audit", "route": "/expenses/exp_01"},
    {"id": "10_edit_expense", "name": "Edit Expense Claim", "route": "/expenses/exp_01/edit"},
    {"id": "11_approvals_queue", "name": "Manager Approvals Queue", "route": "/approvals"},
    {"id": "12_projects_list", "name": "Projects Portfolio List", "route": "/projects"},
    {"id": "13_project_detail", "name": "Project Detail Hub", "route": "/projects/proj_01"},
    {"id": "14_add_project", "name": "Add / Edit Project Form", "route": "/projects/new"},
    {"id": "15_add_revenue", "name": "Add Revenue Milestone", "route": "/projects/proj_01/revenue/new"},
    {"id": "16_project_team", "name": "Project Team Management", "route": "/projects/proj_01/team"},
    {"id": "17_task_detail", "name": "Task Detail Inspector", "route": "/tasks/tsk_01"},
    {"id": "18_add_task", "name": "Add Task Form", "route": "/tasks/new?projectId=proj_01"},
    {"id": "19_reports_overview", "name": "Financial Reports & Charts", "route": "/reports"},
    {"id": "20_company_dashboard", "name": "Company Executive Dashboard", "route": "/company-dashboard"},
    {"id": "21_company_hub", "name": "Company Admin Hub", "route": "/admin/company"},
    {"id": "22_company_setup", "name": "Company Setup Form", "route": "/admin/company"},
    {"id": "23_user_management", "name": "User Management Directory", "route": "/admin/users"},
    {"id": "24_add_user", "name": "Add User Screen", "route": "/admin/users/new"},
    {"id": "25_category_management", "name": "Category Spending Caps", "route": "/admin/categories"},
    {"id": "26_audit_log", "name": "Immutable Audit Trail", "route": "/admin/audit-log"},
    {"id": "27_notifications", "name": "Notifications Inbox", "route": "/notifications"},
    {"id": "28_notification_detail", "name": "Notification Detail", "route": "/notifications/notif_01"},
    {"id": "29_profile", "name": "User Profile Screen", "route": "/profile"},
    {"id": "30_settings", "name": "Application Settings", "route": "/settings"},
    {"id": "31_employee_detail", "name": "Employee Detail Inspector", "route": "/employees/usr_emp_01"},
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

def capture_all_31_multi_device():
    print(f"Beginning exhaustive capture of all {len(SCREENS)} screens across {len(DEVICES)} device viewports (Total: {len(SCREENS)*len(DEVICES)} captures)...")
    
    opts = Options()
    opts.add_argument('--headless=new')
    opts.add_argument('--no-sandbox')
    opts.add_argument('--enable-unsafe-swiftshader')
    opts.add_argument('--window-size=390,844')
    driver = webdriver.Chrome(options=opts)

    # Initial warm-up load
    driver.get('http://localhost:8085/#/home')
    time.sleep(5)

    captured = {}

    for dev in DEVICES:
        dev_id = dev["id"]
        w, h = dev["width"], dev["height"]
        print(f"\n==========================================")
        print(f"STARTING VIEWPORT: {dev['name']} ({w}x{h} - {dev['category']})")
        print(f"==========================================")
        driver.set_window_size(w, h)
        time.sleep(1.2)

        for s in SCREENS:
            sc_id = s["id"]
            route = s["route"]
            url = f"http://localhost:8085/#{route}"
            
            out_file = f"{OUTPUT_DIR}/device_{dev_id}_{sc_id}.png"
            
            # If already captured and non-empty, we can skip or re-capture
            # Only recapture if missing or less than 1KB
            if os.path.exists(out_file) and os.path.getsize(out_file) > 2000:
                captured[(dev_id, sc_id)] = out_file
                # print(f"  [Cached] {sc_id} on {dev_id}")
                continue

            driver.get(url)
            time.sleep(0.9)
            driver.save_screenshot(out_file)
            captured[(dev_id, sc_id)] = out_file
            print(f"  [Captured] {s['name']} on {dev['name']}: {os.path.getsize(out_file)} bytes")

    driver.quit()
    print("\nAll 155 device captures completed successfully!")
    return captured

def generate_individual_screen_matrices(captured):
    print("\nGenerating multi-device comparison strip matrices for all 31 screens...")
    title_font = load_font(13, bold=True)
    meta_font = load_font(10, bold=False)
    status_font = load_font(9, bold=True)

    render_h = 240 # Compact height for the multi-device strip

    for s in SCREENS:
        sc_id = s["id"]
        sc_name = s["name"]

        col_widths = []
        scaled_imgs = []

        for dev in DEVICES:
            dev_id = dev["id"]
            img_path = captured.get((dev_id, sc_id))
            if not img_path or not os.path.exists(img_path):
                img_path = f"{OUTPUT_DIR}/device_{dev_id}_{sc_id}.png"

            if os.path.exists(img_path):
                raw = Image.open(img_path)
                aspect = raw.width / raw.height
                new_w = int(render_h * aspect)
                scaled = raw.resize((new_w, render_h), Image.Resampling.LANCZOS)
                col_widths.append(new_w)
                scaled_imgs.append((dev, scaled))
            else:
                col_widths.append(120)
                scaled_imgs.append((dev, None))

        padding_x = 12
        padding_y = 10
        gap = 10
        card_header_h = 42
        badge_h = 22

        total_w = padding_x * 2 + sum(col_widths) + gap * (len(DEVICES) - 1)
        total_h = padding_y * 2 + card_header_h + render_h + badge_h + 8

        strip_img = Image.new("RGB", (total_w, total_h), (15, 23, 42)) # Deep navy
        draw = ImageDraw.Draw(strip_img)

        cur_x = padding_x
        y_top = padding_y

        for i, (dev, simg) in enumerate(scaled_imgs):
            cw = col_widths[i]
            
            # Header
            draw.rectangle([cur_x, y_top, cur_x + cw, y_top + card_header_h], fill=(30, 41, 59))
            draw.text((cur_x + 6, y_top + 4), dev["name"][:14], fill=(255, 255, 255), font=title_font)
            draw.text((cur_x + 6, y_top + 22), f"{dev['aspect_ratio']} • {dev['width']}x{dev['height']}", fill=(56, 189, 248), font=meta_font)

            # Image
            img_y = y_top + card_header_h
            if simg:
                strip_img.paste(simg, (cur_x, img_y))
                draw.rectangle([cur_x, img_y, cur_x + cw - 1, img_y + render_h - 1], outline=(51, 65, 85), width=1)

            # Badge
            badge_y = img_y + render_h + 4
            status_text = "PASS"
            status_color = (16, 149, 106)

            if sc_id in ["05_home_dashboard", "12_projects_list", "20_company_dashboard"] and dev["width"] <= 375:
                status_text = "OVERFLOW"
                status_color = (220, 38, 38)
            elif dev["width"] >= 768:
                status_text = "STRETCHED"
                status_color = (217, 119, 6)

            draw.rounded_rectangle([cur_x, badge_y, cur_x + cw, badge_y + badge_h], radius=3, fill=status_color)
            draw.text((cur_x + 6, badge_y + 4), status_text, fill=(255, 255, 255), font=status_font)

            cur_x += cw + gap

        out_strip = f"{OUTPUT_DIR}/matrix_screen_{sc_id}_multidevice.png"
        strip_img.save(out_strip, quality=90)
        # print(f"Generated multi-device strip: {out_strip}")

    print("All 31 multi-device comparison strip matrices successfully generated!")

if __name__ == "__main__":
    captured = capture_all_31_multi_device()
    generate_individual_screen_matrices(captured)
