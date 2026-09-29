import os
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'

DEVICES = [
    {"id": "iphone_se", "name": "iPhone SE", "w": 375, "h": 667, "ratio": "16:9", "type": "Compact"},
    {"id": "samsung_galaxy", "name": "Samsung Galaxy", "w": 360, "h": 800, "ratio": "20:9", "type": "Android"},
    {"id": "iphone_15_pro_max", "name": "iPhone 15 Pro Max", "w": 430, "h": 932, "ratio": "19.5:9", "type": "Flagship"},
    {"id": "ipad_10th_gen", "name": "iPad 10th Gen", "w": 1024, "h": 768, "ratio": "4:3", "type": "Tablet"},
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
    {"id": "11_expense_detail", "name": "Expense Detail Inspector", "route": "/expenses/exp_fahim_01"},
    {"id": "12_edit_expense", "name": "Edit Expense Form", "route": "/expenses/exp_fahim_01/edit"},
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

DEFECTS_MAP = {
    "01_splash": [
        {"dev": "iphone_se", "box": [0.10, 0.35, 0.90, 0.65], "label": "AUTH BYPASS ON BOOT"},
        {"dev": "ipad_10th_gen", "box": [0.20, 0.30, 0.80, 0.70], "label": "HARDCODED ROOT ACCESS"}
    ],
    "02_login": [
        {"dev": "iphone_se", "box": [0.08, 0.75, 0.92, 0.92], "label": "OVERFLOW 54PX (NO WRAP)"},
        {"dev": "samsung_galaxy", "box": [0.55, 0.52, 0.92, 0.58], "label": "TOUCH TARGET 20DP < 48DP"},
        {"dev": "ipad_10th_gen", "box": [0.25, 0.20, 0.75, 0.80], "label": "TEST ASSERTIONS GUTTED"}
    ],
    "03_register": [
        {"dev": "iphone_se", "box": [0.05, 0.20, 0.95, 0.90], "label": "UNRESTRICTED ROLE ESCALATION"},
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.92], "label": "1024PX UNCONSTRAINED BLOWOUT"}
    ],
    "04_forgot_password": [
        {"dev": "ipad_10th_gen", "box": [0.05, 0.25, 0.95, 0.75], "label": "1024PX UNCONSTRAINED INPUT BLOWOUT"}
    ],
    "05_reset_password": [
        {"dev": "ipad_10th_gen", "box": [0.05, 0.25, 0.95, 0.80], "label": "1024PX CARD EXTENSION"}
    ],
    "06_home_dashboard": [
        {"dev": "iphone_se", "box": [0.05, 0.15, 0.95, 0.40], "label": "1,098-LINE GOD WIDGET"},
        {"dev": "ipad_10th_gen", "box": [0.03, 0.35, 0.97, 0.65], "label": "5:1 SQUASHED TREND CHART"}
    ],
    "07_main_shell": [
        {"dev": "ipad_10th_gen", "box": [0.01, 0.90, 0.99, 0.99], "label": "STRETCHED 1024PX BOTTOM BAR (LACKS RAIL)"}
    ],
    "08_my_expenses": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.15, 0.98, 0.85], "label": "70% DEAD WHITE SPACE (1D LISTVIEW)"}
    ],
    "09_submit_expense": [
        {"dev": "iphone_se", "box": [0.05, 0.15, 0.95, 0.85], "label": "1,012-LINE MONOLITH (NO AUTOSAVE)"},
        {"dev": "ipad_10th_gen", "box": [0.02, 0.10, 0.98, 0.90], "label": "980PX FORM INPUT STRETCH"}
    ],
    "10_receipt_compliance": [
        {"dev": "samsung_galaxy", "box": [0.05, 0.15, 0.95, 0.45], "label": "MEMORY LEAK (UN-DISPOSED CONTROLLER)"},
        {"dev": "ipad_10th_gen", "box": [0.03, 0.20, 0.97, 0.85], "label": "MISSING TABLET SCANNER PIPELINE"}
    ],
    "11_expense_detail": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.20, 0.98, 0.80], "label": "750PX EMPTY VOID (LACKS SPLIT-VIEW)"}
    ],
    "12_edit_expense": [
        {"dev": "iphone_se", "box": [0.05, 0.20, 0.95, 0.50], "label": "18X DEPRECATED DROPDOWN VALUE API"},
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "TABLET HORIZONTAL BLOWOUT"}
    ],
    "13_approvals_queue": [
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "NO BATCH APPROVAL CTA ON TABLET"}
    ],
    "14_projects_list": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.15, 0.98, 0.85], "label": "70% DEAD WHITE SPACE VOID"}
    ],
    "15_project_detail": [
        {"dev": "iphone_se", "box": [0.05, 0.15, 0.95, 0.55], "label": "804-LINE GOD WIDGET"},
        {"dev": "ipad_10th_gen", "box": [0.03, 0.25, 0.97, 0.70], "label": "NO MULTI-COLUMN METRIC TILES"}
    ],
    "16_add_project": [
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "1024PX UNCONSTRAINED INPUT BLOWOUT"}
    ],
    "17_edit_project": [
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "FORM BLOWOUT & DEPRECATED DROPDOWNS"}
    ],
    "18_add_revenue": [
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "NO CURRENCY SELECTOR (HARDCODED BDT)"}
    ],
    "19_project_team": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.15, 0.98, 0.85], "label": "SINGLE-COLUMN ROSTER ON 1024PX"}
    ],
    "20_client_analysis": [
        {"dev": "iphone_15_pro_max", "box": [0.05, 0.05, 0.95, 0.15], "label": "CRITICAL OWASP A01: UNPROTECTED ROUTE"},
        {"dev": "ipad_10th_gen", "box": [0.02, 0.18, 0.98, 0.50], "label": "FINANCIAL CONTAMINATION (.split)"}
    ],
    "21_cost_estimator": [
        {"dev": "iphone_15_pro_max", "box": [0.05, 0.05, 0.95, 0.15], "label": "CRITICAL OWASP A01: UNPROTECTED ROUTE"},
        {"dev": "ipad_10th_gen", "box": [0.02, 0.55, 0.98, 0.90], "label": "HARDCODED 12% MARGIN FORMULA"}
    ],
    "22_task_detail": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.20, 0.98, 0.80], "label": "STATIC RE-RENDERING & JANK"}
    ],
    "23_add_task": [
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "1024PX HORIZONTAL BLOWOUT"}
    ],
    "24_reports_overview": [
        {"dev": "ipad_10th_gen", "box": [0.03, 0.25, 0.97, 0.65], "label": "5:1 SQUASHED TREND CURVE"}
    ],
    "25_company_dashboard": [
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.55], "label": "TABLET GRID MISALIGNMENT"}
    ],
    "26_company_setup": [
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "980PX UNCONSTRAINED INPUT BLOWOUT"}
    ],
    "27_user_management": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.15, 0.98, 0.85], "label": "LACKS BATCH SUSPEND / DEACTIVATE"}
    ],
    "28_add_user": [
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "UNVALIDATED ROLE ASSIGNMENT BLOWOUT"}
    ],
    "29_category_management": [
        {"dev": "iphone_se", "box": [0.70, 0.30, 0.95, 0.40], "label": "TOUCH TARGET 22DP TRASH ICON"},
        {"dev": "samsung_galaxy", "box": [0.10, 0.40, 0.90, 0.60], "label": "MEMORY LEAK: TEXT CONTROLLER"}
    ],
    "30_audit_log": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.15, 0.98, 0.85], "label": "UNPAGINATED IN-MEMORY LOG LIST"}
    ],
    "31_notifications": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.15, 0.98, 0.85], "label": "NO REAL-TIME WEBSOCKET SYNC"}
    ],
    "32_notification_detail": [
        {"dev": "ipad_10th_gen", "box": [0.45, 0.20, 0.98, 0.80], "label": "STATIC NOTIFICATION (NO DEEP LINK)"}
    ],
    "33_profile": [
        {"dev": "samsung_galaxy", "box": [0.10, 0.40, 0.90, 0.60], "label": "LEAKED CONTROLLER IN MODAL"},
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "LACKS 2FA AUTHENTICATOR SETUP"}
    ],
    "34_settings": [
        {"dev": "iphone_se", "box": [0.05, 0.30, 0.95, 0.50], "label": "6X DEPRECATED SWITCH.ACTIVECOLOR API"},
        {"dev": "ipad_10th_gen", "box": [0.02, 0.15, 0.98, 0.85], "label": "TABLET HORIZONTAL STRETCH"}
    ],
    "35_employee_detail": [
        {"dev": "ipad_10th_gen", "box": [0.70, 0.05, 0.98, 0.15], "label": "NO EXPORT STAFF AUDIT CTA"}
    ]
}

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

def draw_defect_box(draw, x0, y0, x1, y1, label, font):
    # Thick glowing red box
    draw.rectangle([x0-1, y0-1, x1+1, y1+1], outline=(239, 68, 68), width=3)
    
    # Label badge
    bbox = font.getbbox(label)
    bw = (bbox[2] - bbox[0]) + 12
    bh = (bbox[3] - bbox[1]) + 8
    
    tag_x0 = x0
    tag_y0 = max(0, y0 - bh)
    draw.rectangle([tag_x0, tag_y0, tag_x0 + bw, tag_y0 + bh], fill=(220, 38, 38))
    draw.text((tag_x0 + 6, tag_y0 + 3), label, fill=(255, 255, 255), font=font)

def generate_four_device_cards():
    print("Generating High-Resolution 4-Device Annotated Cards for all 35 screens...")
    header_font = load_font(12, bold=True)
    meta_font = load_font(9, bold=False)
    tag_font = load_font(9, bold=True)
    footer_font = load_font(9, bold=False)

    RENDER_H = 340 # Device screenshot height
    CARD_HEADER_H = 32
    STATUS_BADGE_H = 20
    PAD_X = 10
    PAD_Y = 10
    GAP = 8

    for s in SCREENS:
        sc_id = s["id"]
        sc_name = s["name"]

        # Calculate width of each device at RENDER_H
        dev_widths = []
        raw_imgs = []
        for dev in DEVICES:
            dev_id = dev["id"]
            img_file = f"{OUTPUT_DIR}/device4_{dev_id}_{sc_id}.png"
            if os.path.exists(img_file):
                im = Image.open(img_file)
                aspect = im.width / im.height
                calc_w = int(RENDER_H * aspect)
                dev_widths.append(calc_w)
                raw_imgs.append((dev, im, calc_w))
            else:
                dev_widths.append(150)
                raw_imgs.append((dev, None, 150))

        total_w = PAD_X * 2 + sum(dev_widths) + GAP * (len(DEVICES) - 1)
        total_h = PAD_Y * 2 + CARD_HEADER_H + RENDER_H + STATUS_BADGE_H + 28

        # Create master composite canvas
        card_img = Image.new("RGB", (total_w, total_h), (15, 23, 42)) # Deep Slate Navy
        draw = ImageDraw.Draw(card_img)

        # Draw Top Global Card Header
        draw.text((PAD_X, 8), f"SCREEN {sc_id.upper()} • {sc_name.upper()}", fill=(255, 255, 255), font=header_font)
        draw.text((total_w - PAD_X - 160, 8), f"ROUTE: #{s['route']}", fill=(148, 163, 184), font=meta_font)

        cur_x = PAD_X
        dev_y = PAD_Y + CARD_HEADER_H

        for idx, (dev, im, dw) in enumerate(raw_imgs):
            dev_id = dev["id"]

            # Device Header Strip
            draw.rectangle([cur_x, dev_y, cur_x + dw, dev_y + 24], fill=(30, 41, 59))
            draw.text((cur_x + 5, dev_y + 4), f"{dev['name']}", fill=(241, 245, 249), font=load_font(10, bold=True))
            draw.text((cur_x + dw - 65, dev_y + 5), f"{dev['w']}x{dev['h']}", fill=(56, 189, 248), font=meta_font)

            # Device Screenshot Body
            scr_y = dev_y + 24
            if im:
                scaled = im.resize((dw, RENDER_H - 24), Image.Resampling.LANCZOS)
                
                # Check for defects to draw on this specific device
                draw_dev = ImageDraw.Draw(scaled)
                defects_for_screen = DEFECTS_MAP.get(sc_id, [])
                for d in defects_for_screen:
                    if d.get("dev") == dev_id:
                        bx = d["box"]
                        x0 = int(bx[0] * dw)
                        y0 = int(bx[1] * (RENDER_H - 24))
                        x1 = int(bx[2] * dw)
                        y1 = int(bx[3] * (RENDER_H - 24))
                        draw_defect_box(draw_dev, x0, y0, x1, y1, d["label"], tag_font)

                card_img.paste(scaled, (cur_x, scr_y))
                draw.rectangle([cur_x, scr_y, cur_x + dw - 1, scr_y + RENDER_H - 24 - 1], outline=(51, 65, 85), width=1)
            else:
                draw.rectangle([cur_x, scr_y, cur_x + dw - 1, scr_y + RENDER_H - 24 - 1], fill=(2, 6, 23))

            # Bottom Status Badge for Device
            badge_y = scr_y + (RENDER_H - 24) + 4
            status_txt = "PASS"
            status_bg = (16, 149, 106) # Green

            # Detect badge status
            if any(d.get("dev") == dev_id for d in DEFECTS_MAP.get(sc_id, [])):
                status_txt = "VIOLATION MARKED"
                status_bg = (220, 38, 38) # Red
            elif dev_id == "ipad_10th_gen" and sc_id not in ["01_splash"]:
                status_txt = "TABLET STRETCH"
                status_bg = (217, 119, 6) # Amber
            
            draw.rounded_rectangle([cur_x, badge_y, cur_x + dw, badge_y + 18], radius=3, fill=status_bg)
            draw.text((cur_x + 6, badge_y + 2), status_txt, fill=(255, 255, 255), font=tag_font)

            cur_x += dw + GAP

        # Bottom Sub-footer
        draw.text((PAD_X, total_h - 18), "4-DEVICE FORENSIC AUDIT: iPhone SE (16:9), Samsung Galaxy (20:9), iPhone 15 Pro Max (19.5:9), iPad 10th Gen (4:3) • Commit 0d62f0b", fill=(100, 116, 139), font=footer_font)

        out_path = f"{OUTPUT_DIR}/marked_4device_screen_{sc_id}.png"
        card_img.save(out_path, quality=90)
        # print(f"  [Card Created] {out_path}")

    print("ALL 35 4-Device Marked Cards Successfully Generated!")

if __name__ == '__main__':
    generate_four_device_cards()
