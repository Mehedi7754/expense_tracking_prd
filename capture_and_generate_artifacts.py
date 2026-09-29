import os
import sys
import time
import json
from PIL import Image, ImageDraw, ImageFont
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'
os.makedirs(OUTPUT_DIR, exist_ok=True)

DEVICES = [
    {"id": "iphone_se", "name": "iPhone SE", "category": "Compact (16:9)", "width": 375, "height": 667},
    {"id": "galaxy_s24", "name": "Samsung Galaxy S24", "category": "Tall Android (20:9)", "width": 360, "height": 800},
    {"id": "iphone_15_pro", "name": "iPhone 15 Pro", "category": "Flagship (19.5:9)", "width": 390, "height": 844},
    {"id": "ipad_portrait", "name": "iPad 10th (Portrait)", "category": "Tablet (3:4)", "width": 768, "height": 1024},
    {"id": "ipad_landscape", "name": "iPad 10th (Landscape)", "category": "Tablet / Desktop (4:3)", "width": 1024, "height": 768}
]

SCREENS = [
    {"id": "01_splash", "name": "Splash Screen", "route": "/"},
    {"id": "02_login", "name": "Login Screen", "route": "/login"},
    {"id": "03_register", "name": "Self-Registration Form", "route": "/register"},
    {"id": "04_forgot_password", "name": "Forgot Password", "route": "/forgot-password"},
    {"id": "05_reset_password", "name": "Reset Password", "route": "/reset-password"},
    {"id": "06_home_dashboard", "name": "Home Executive Dashboard", "route": "/home"},
    {"id": "07_main_shell", "name": "Main Shell Scaffold", "route": "/home"},
    {"id": "08_my_expenses", "name": "My Expenses List", "route": "/expenses/my-expenses"},
    {"id": "09_submit_expense", "name": "Submit Expense Form", "route": "/expenses/submit"},
    {"id": "10_receipt_compliance", "name": "Receipt Compliance Audit", "route": "/receipt-compliance"},
    {"id": "11_expense_detail", "name": "Expense Detail Inspector", "route": "/expenses/exp_01"},
    {"id": "12_edit_expense", "name": "Edit Expense Form", "route": "/expenses/exp_01/edit"},
    {"id": "13_approvals_queue", "name": "Approvals Queue", "route": "/approvals"},
    {"id": "14_projects_list", "name": "Projects Portfolio List", "route": "/projects"},
    {"id": "15_project_detail", "name": "Project Detail Hub", "route": "/projects/proj_01"},
    {"id": "16_add_project", "name": "Add Project Form", "route": "/projects/new"},
    {"id": "17_edit_project", "name": "Edit Project Form", "route": "/projects/proj_01/edit"},
    {"id": "18_add_revenue", "name": "Add Revenue Milestone", "route": "/projects/proj_01/revenue/new"},
    {"id": "19_project_team", "name": "Project Team Directory", "route": "/projects/proj_01/team"},
    {"id": "20_client_analysis", "name": "Client Profitability Analysis", "route": "/client-analysis"},
    {"id": "21_cost_estimator", "name": "Project Cost Estimator", "route": "/cost-estimator"},
    {"id": "22_task_detail", "name": "Task Detail Inspector", "route": "/tasks/tsk_01"},
    {"id": "23_add_task", "name": "Add Task Form", "route": "/tasks/new?projectId=proj_01"},
    {"id": "24_reports_overview", "name": "Financial Reports & Charts", "route": "/reports"},
    {"id": "25_company_dashboard", "name": "Company Executive Dashboard", "route": "/company-dashboard"},
    {"id": "26_company_setup", "name": "Company Setup Form", "route": "/admin/company"},
    {"id": "27_user_management", "name": "User Management Directory", "route": "/admin/users"},
    {"id": "28_add_user", "name": "Add User Screen", "route": "/admin/users/new"},
    {"id": "29_category_management", "name": "Category Spending Caps", "route": "/admin/categories"},
    {"id": "30_audit_log", "name": "Immutable Audit Trail", "route": "/admin/audit-log"},
    {"id": "31_notifications", "name": "Notifications Inbox", "route": "/notifications"},
    {"id": "32_notification_detail", "name": "Notification Detail", "route": "/notifications/notif_01"},
    {"id": "33_profile", "name": "User Profile Screen", "route": "/profile"},
    {"id": "34_settings", "name": "Application Settings", "route": "/settings"},
    {"id": "35_employee_detail", "name": "Employee Detail Inspector", "route": "/employees/usr_emp_01"}
]

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

def run_capture():
    print(f"Starting capture of {len(SCREENS)} screens across {len(DEVICES)} device viewports on http://localhost:8085...")
    opts = Options()
    opts.add_argument('--headless=new')
    opts.add_argument('--no-sandbox')
    opts.add_argument('--enable-unsafe-swiftshader')
    opts.add_argument('--window-size=390,844')
    
    driver = webdriver.Chrome(options=opts)
    
    # Warmup
    driver.get('http://localhost:8085/#/home')
    time.sleep(4)

    captured = {}

    for dev in DEVICES:
        dev_id = dev["id"]
        w, h = dev["width"], dev["height"]
        print(f"\n>>> Viewport: {dev['name']} ({w}x{h})")
        driver.set_window_size(w, h)
        time.sleep(1.0)

        for s in SCREENS:
            sc_id = s["id"]
            url = f"http://localhost:8085/#{s['route']}"
            out_file = f"{OUTPUT_DIR}/postpush_{dev_id}_{sc_id}.png"
            
            driver.get(url)
            time.sleep(0.7)
            driver.save_screenshot(out_file)
            captured[(dev_id, sc_id)] = out_file
            print(f"  [Captured] {s['name']} on {dev['name']}: {os.path.getsize(out_file)} bytes")

    # Now capture 5 distinct Role Dashboards on iPhone 15 Pro & iPad Landscape
    print("\n>>> Capturing Role Dashboards...")
    # We can test persona switching or navigate
    # Note: Default auth is mainAdmin. Let's capture the mainAdmin dashboard on mobile & iPad
    driver.set_window_size(390, 844)
    driver.get('http://localhost:8085/#/home')
    time.sleep(1.0)
    driver.save_screenshot(f"{OUTPUT_DIR}/postpush_role_admin_mobile.png")
    
    driver.set_window_size(1024, 768)
    driver.get('http://localhost:8085/#/home')
    time.sleep(1.0)
    driver.save_screenshot(f"{OUTPUT_DIR}/postpush_role_admin_ipad.png")

    # Specific iPad Defect Captures
    ipad_defects = [
        {"id": "postpush_ipad_defect_01_submit_stretched", "route": "/expenses/submit", "name": "Full-Width Form Stretch (1024px)"},
        {"id": "postpush_ipad_defect_02_projects_whitespace", "route": "/projects", "name": "70% Dead Whitespace in Projects List"},
        {"id": "postpush_ipad_defect_03_reports_flattened", "route": "/reports", "name": "Distorted Flattened Trend Chart"},
        {"id": "postpush_ipad_defect_04_client_analysis", "route": "/client-analysis", "name": "Client Analysis Table / Logic"},
        {"id": "postpush_ipad_defect_05_cost_estimator", "route": "/cost-estimator", "name": "Cost Estimator Tablet Layout"},
        {"id": "postpush_ipad_defect_06_compliance_table", "route": "/receipt-compliance", "name": "Receipt Compliance Audit View"},
        {"id": "postpush_ipad_defect_07_register_form", "route": "/register", "name": "Self-Registration Stretched Form"}
    ]
    for d in ipad_defects:
        driver.set_window_size(1024, 768)
        driver.get(f"http://localhost:8085/#{d['route']}")
        time.sleep(0.8)
        out_f = f"{OUTPUT_DIR}/{d['id']}.png"
        driver.save_screenshot(out_f)
        print(f"  [iPad Defect] {d['name']}: {os.path.getsize(out_f)} bytes")

    driver.quit()
    print("Capture complete! Building annotated composite matrices...")
    return captured

def build_annotated_matrices():
    title_font = load_font(13, bold=True)
    meta_font = load_font(10, bold=False)
    status_font = load_font(9, bold=True)
    render_h = 240

    for s in SCREENS:
        sc_id = s["id"]
        sc_name = s["name"]
        
        imgs = []
        for dev in DEVICES:
            dev_id = dev["id"]
            img_p = f"{OUTPUT_DIR}/postpush_{dev_id}_{sc_id}.png"
            if os.path.exists(img_p):
                im = Image.open(img_p)
                w_scaled = int(im.width * (render_h / im.height))
                im_resized = im.resize((w_scaled, render_h), Image.Resampling.LANCZOS)
                imgs.append((dev, im_resized))

        if not imgs:
            continue

        header_h = 42
        footer_h = 32
        gap = 12
        total_w = sum(im.width for dev, im in imgs) + gap * (len(imgs) - 1) + 24
        total_h = header_h + render_h + footer_h

        strip = Image.new('RGB', (total_w, total_h), (255, 255, 255))
        draw = ImageDraw.Draw(strip)

        # Header
        draw.rectangle([0, 0, total_w, header_h], fill=(15, 23, 42))
        draw.text((12, 10), f"SCREEN {sc_id.upper()} • {sc_name.upper()} • 5-DEVICE RESPONSIVE MATRIX (COMMIT 0d62f0b)", fill=(255, 255, 255), font=title_font)
        draw.text((total_w - 180, 12), f"ROUTE: #{s['route']}", fill=(148, 163, 184), font=meta_font)

        curr_x = 12
        for dev, im in imgs:
            strip.paste(im, (curr_x, header_h))
            # border around image
            draw.rectangle([curr_x, header_h, curr_x + im.width, header_h + render_h], outline=(226, 232, 240), width=1)
            
            # footer label
            draw.rectangle([curr_x, header_h + render_h, curr_x + im.width, total_h], fill=(248, 250, 252))
            draw.line([(curr_x, header_h + render_h), (curr_x + im.width, header_h + render_h)], fill=(226, 232, 240), width=1)
            dev_label = f"{dev['name']} ({dev['aspect_ratio']})"
            draw.text((curr_x + 4, header_h + render_h + 8), dev_label, fill=(30, 41, 59), font=status_font)

            curr_x += im.width + gap

        out_matrix = f"{OUTPUT_DIR}/postpush_annotated_{sc_id}.png"
        strip.save(out_matrix, quality=92)

    print("All annotated screen matrices generated successfully!")

if __name__ == '__main__':
    run_capture()
    build_annotated_matrices()
