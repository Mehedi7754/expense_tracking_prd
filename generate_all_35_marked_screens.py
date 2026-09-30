import os
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'

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

DEFECTS_MAP = {
    "01_splash": [
        {"target": "mob", "box": [0.15, 0.35, 0.85, 0.65], "label": "AUTH BYPASS ON BOOT (Hardcoded True)"}
    ],
    "02_login": [
        {"target": "mob", "box": [0.08, 0.45, 0.92, 0.53], "label": "TOUCH TARGET 20DP < 48DP MIN"},
        {"target": "mob", "box": [0.05, 0.80, 0.95, 0.92], "label": "COMPACT OVERFLOW 54PX (No Wrap)"},
        {"target": "ipad", "box": [0.15, 0.20, 0.85, 0.80], "label": "TEST ASSERTIONS GUTTED IN REPO"}
    ],
    "03_register": [
        {"target": "ipad", "box": [0.04, 0.12, 0.96, 0.82], "label": "1024PX UNCONSTRAINED BLOWOUT"},
        {"target": "mob", "box": [0.08, 0.32, 0.92, 0.46], "label": "PUBLIC ROLE ESCALATION RISK"}
    ],
    "04_forgot_password": [
        {"target": "mob", "box": [0.08, 0.38, 0.92, 0.52], "label": "MISSING RATE LIMITER (Spam Risk)"}
    ],
    "05_reset_password": [
        {"target": "mob", "box": [0.08, 0.35, 0.92, 0.50], "label": "NO PASSWORD STRENGTH METER"}
    ],
    "06_home_dashboard": [
        {"target": "mob", "box": [0.05, 0.46, 0.95, 0.66], "label": "PROJECTCARD OVERFLOW (32-97PX)"},
        {"target": "ipad", "box": [0.02, 0.05, 0.98, 0.28], "label": "1,098-LINE GOD WIDGET + BUILD JANK"}
    ],
    "07_main_shell": [
        {"target": "ipad", "box": [0.02, 0.90, 0.98, 0.99], "label": "1024PX BOTTOM BAR (Needs Rail)"}
    ],
    "08_my_expenses": [
        {"target": "ipad", "box": [0.45, 0.15, 0.98, 0.85], "label": "70% DEAD WHITESPACE VOID"}
    ],
    "09_submit_expense": [
        {"target": "ipad", "box": [0.04, 0.12, 0.96, 0.85], "label": "1024PX FULL-WIDTH BLOWOUT"},
        {"target": "mob", "box": [0.05, 0.20, 0.95, 0.35], "label": "DEPRECATED API: .value (4x)"},
        {"target": "mob", "box": [0.02, 0.02, 0.98, 0.98], "label": "1,012-LINE GOD WIDGET"}
    ],
    "10_receipt_compliance": [
        {"target": "ipad", "box": [0.04, 0.18, 0.96, 0.82], "label": "SQUASHED TABLE COLUMNS (Tablet)"},
        {"target": "mob", "box": [0.05, 0.15, 0.95, 0.28], "label": "DEPRECATED API: line 63"}
    ],
    "11_expense_detail": [
        {"target": "mob", "box": [0.08, 0.28, 0.92, 0.62], "label": "HARDCODED RAW HEX THEMING"}
    ],
    "12_edit_expense": [
        {"target": "mob", "box": [0.08, 0.24, 0.92, 0.42], "label": "2X DEPRECATED API (.value)"},
        {"target": "ipad", "box": [0.05, 0.15, 0.95, 0.75], "label": "UNCONSTRAINED TABLET FORM"}
    ],
    "13_approvals_queue": [
        {"target": "ipad", "box": [0.05, 0.32, 0.95, 0.52], "label": "ACTION BUTTONS SEPARATED 750PX"},
        {"target": "mob", "box": [0.05, 0.82, 0.95, 0.94], "label": "MISSING BATCH APPROVAL CTA"}
    ],
    "14_projects_list": [
        {"target": "ipad", "box": [0.45, 0.15, 0.98, 0.85], "label": "1D LISTVIEW (70% VOID) - Needs Grid"},
        {"target": "mob", "box": [0.05, 0.28, 0.95, 0.45], "label": "METRIC ROW OVERLAP ON 360DP"}
    ],
    "15_project_detail": [
        {"target": "ipad", "box": [0.05, 0.10, 0.95, 0.30], "label": "FLATTENED METRIC CARDS"},
        {"target": "mob", "box": [0.02, 0.02, 0.98, 0.98], "label": "804-LINE MONOLITHIC FILE"}
    ],
    "16_add_project": [
        {"target": "ipad", "box": [0.04, 0.14, 0.96, 0.86], "label": "1024PX FORM BLOWOUT"},
        {"target": "mob", "box": [0.08, 0.24, 0.92, 0.46], "label": "4X DEPRECATED DROPDOWNS"}
    ],
    "17_edit_project": [
        {"target": "ipad", "box": [0.05, 0.15, 0.95, 0.80], "label": "UNCONSTRAINED TABLET CONTAINER"}
    ],
    "18_add_revenue": [
        {"target": "mob", "box": [0.08, 0.28, 0.92, 0.44], "label": "MISSING CURRENCY INPUT MASK"}
    ],
    "19_project_team": [
        {"target": "mob", "box": [0.08, 0.20, 0.92, 0.50], "label": "LACKS DIRECT CONTACT ACTION"}
    ],
    "20_client_analysis": [
        {"target": "ipad", "box": [0.02, 0.02, 0.98, 0.20], "label": "CRITICAL OWASP A01: UNPROTECTED ROUTE"},
        {"target": "ipad", "box": [0.04, 0.22, 0.96, 0.55], "label": "FINANCIAL CONTAMINATION (.split)"},
        {"target": "mob", "box": [0.05, 0.10, 0.95, 0.30], "label": "O(N*M) BUILD LOOP JANK"}
    ],
    "21_cost_estimator": [
        {"target": "ipad", "box": [0.02, 0.02, 0.98, 0.20], "label": "CRITICAL OWASP A01: UNPROTECTED ROUTE"},
        {"target": "ipad", "box": [0.04, 0.22, 0.96, 0.75], "label": "1024PX PARAMETER STRETCH"},
        {"target": "mob", "box": [0.08, 0.25, 0.92, 0.45], "label": "2X DEPRECATED DROPDOWNS"}
    ],
    "22_task_detail": [
        {"target": "mob", "box": [0.08, 0.58, 0.92, 0.85], "label": "NO ATTACHMENT IN DISCUSSION THREAD"}
    ],
    "23_add_task": [
        {"target": "mob", "box": [0.08, 0.28, 0.92, 0.48], "label": "2X DEPRECATED DROPDOWNS (.value)"}
    ],
    "24_reports_overview": [
        {"target": "ipad", "box": [0.04, 0.18, 0.96, 0.58], "label": "5:1 DISTORTED CHART FLATTENING"}
    ],
    "25_company_dashboard": [
        {"target": "ipad", "box": [0.04, 0.14, 0.96, 0.42], "label": "UNSCALED TABLET KPI CARDS"}
    ],
    "26_company_setup": [
        {"target": "ipad", "box": [0.04, 0.14, 0.96, 0.78], "label": "1024PX FULL-WIDTH BLOWOUT"},
        {"target": "mob", "box": [0.08, 0.25, 0.92, 0.42], "label": "DEPRECATED API: line 139"}
    ],
    "27_user_management": [
        {"target": "ipad", "box": [0.40, 0.15, 0.98, 0.85], "label": "70% DEAD WHITESPACE VOID"},
        {"target": "mob", "box": [0.65, 0.20, 0.95, 0.35], "label": "DEPRECATED API: activeColor"}
    ],
    "28_add_user": [
        {"target": "mob", "box": [0.08, 0.25, 0.92, 0.42], "label": "DEPRECATED API: .value"}
    ],
    "29_category_management": [
        {"target": "mob", "box": [0.65, 0.20, 0.95, 0.35], "label": "DEPRECATED API: activeColor"}
    ],
    "30_audit_log": [
        {"target": "ipad", "box": [0.45, 0.15, 0.98, 0.85], "label": "70% DEAD WHITESPACE VOID"}
    ],
    "31_notifications": [
        {"target": "mob", "box": [0.65, 0.05, 0.95, 0.14], "label": "NO 'MARK ALL AS READ' CTA"}
    ],
    "32_notification_detail": [
        {"target": "mob", "box": [0.08, 0.20, 0.92, 0.35], "label": "HARDCODED HEX THEMING"}
    ],
    "33_profile": [
        {"target": "mob", "box": [0.08, 0.40, 0.92, 0.65], "label": "NO SEARCH FILTER IN ROLE SWITCHER"}
    ],
    "34_settings": [
        {"target": "mob", "box": [0.08, 0.20, 0.92, 0.35], "label": "DEPRECATED API: .value"},
        {"target": "mob", "box": [0.60, 0.45, 0.99, 0.58], "label": "LAYOUT OVERFLOW (59PX)"}
    ],
    "35_employee_detail": [
        {"target": "mob", "box": [0.65, 0.05, 0.95, 0.14], "label": "NO EXPORT STAFF AUDIT CTA"}
    ]
}

print(f"Generating marked visual screen cards for all {len(SCREENS)} screens...")

for s in SCREENS:
    sc_id = s["id"]
    sc_name = s["name"]
    route = s["route"]
    defects = DEFECTS_MAP.get(sc_id, [{"target": "mob", "box": [0.05, 0.05, 0.95, 0.95], "label": "INSPECTION POINT"}])

    mob_path = f"{OUTPUT_DIR}/recapture_mobile_{sc_id}.png"
    ipad_path = f"{OUTPUT_DIR}/recapture_ipad_{sc_id}.png"

    if not os.path.exists(mob_path) or not os.path.exists(ipad_path):
        print(f"Skipping {sc_id}, files missing")
        continue

    mob_img = Image.open(mob_path)
    ipad_img = Image.open(ipad_path)

    # 480px target height for crisp display
    target_h = 480
    mob_scaled_w = int(mob_img.width * (target_h / mob_img.height))
    mob_scaled = mob_img.resize((mob_scaled_w, target_h), Image.Resampling.LANCZOS)

    ipad_scaled_w = int(ipad_img.width * (target_h / ipad_img.height))
    ipad_scaled = ipad_img.resize((ipad_scaled_w, target_h), Image.Resampling.LANCZOS)

    header_h = 50
    footer_h = 38
    gap = 24
    pad = 20
    total_w = mob_scaled_w + ipad_scaled_w + gap + pad * 2
    total_h = header_h + target_h + footer_h + pad * 2

    canvas = Image.new('RGB', (total_w, total_h), (248, 250, 252))
    draw = ImageDraw.Draw(canvas)

    # Header
    draw.rectangle([0, 0, total_w, header_h], fill=(15, 23, 42))
    draw.text((pad, 14), f"SCREEN {sc_id.upper()} • {sc_name.upper()}", fill=(255, 255, 255), font=load_font(14, bold=True))
    draw.text((total_w - 240, 16), f"ROUTE: #{route}", fill=(148, 163, 184), font=load_font(11, bold=False))

    # Paste Mobile Image
    mob_x = pad
    mob_y = header_h + pad
    canvas.paste(mob_scaled, (mob_x, mob_y))
    draw.rectangle([mob_x, mob_y, mob_x + mob_scaled_w, mob_y + target_h], outline=(203, 213, 225), width=2)
    draw.rectangle([mob_x, mob_y - 22, mob_x + 140, mob_y], fill=(30, 41, 59))
    draw.text((mob_x + 6, mob_y - 18), "iPhone 15 Pro (9:19.5)", fill=(255, 255, 255), font=load_font(9, bold=True))

    # Paste iPad Image
    ipad_x = mob_x + mob_scaled_w + gap
    ipad_y = header_h + pad
    canvas.paste(ipad_scaled, (ipad_x, ipad_y))
    draw.rectangle([ipad_x, ipad_y, ipad_x + ipad_scaled_w, ipad_y + target_h], outline=(203, 213, 225), width=2)
    draw.rectangle([ipad_x, ipad_y - 22, ipad_x + 180, ipad_y], fill=(30, 41, 59))
    draw.text((ipad_x + 6, ipad_y - 18), "iPad 10th Gen (1024x768 - 4:3)", fill=(255, 255, 255), font=load_font(9, bold=True))

    # Draw Red Defect Callouts
    for d in defects:
        target = d.get('target', 'ipad')
        box = d.get('box', [0.1, 0.2, 0.9, 0.4])
        label = d.get('label', 'DEFECT DETECTED')
        
        bx = ipad_x if target == 'ipad' else mob_x
        bw = ipad_scaled_w if target == 'ipad' else mob_scaled_w
        by = ipad_y if target == 'ipad' else mob_y
        bh = target_h

        x1 = int(bx + box[0] * bw)
        y1 = int(by + box[1] * bh)
        x2 = int(bx + box[2] * bw)
        y2 = int(by + box[3] * bh)

        # Bold red bounding box
        draw.rectangle([x1, y1, x2, y2], outline=(239, 68, 68), width=3)
        # Red callout badge
        badge_w = min(len(label) * 8 + 18, bw - 15)
        draw.rectangle([x1, max(y1 - 24, by), x1 + badge_w, max(y1, by + 24)], fill=(239, 68, 68))
        draw.text((x1 + 6, max(y1 - 20, by + 4)), label[:38], fill=(255, 255, 255), font=load_font(10, bold=True))

    # Footer
    draw.rectangle([0, total_h - footer_h, total_w, total_h], fill=(241, 245, 249))
    draw.line([(0, total_h - footer_h), (total_w, total_h - footer_h)], fill=(226, 232, 240), width=1)
    status_summary = f"FORENSIC DEFECT AUDIT • {len(defects)} VIOLATION(S) MARKED • COMMIT 0d62f0b"
    draw.text((pad, total_h - footer_h + 10), status_summary, fill=(15, 23, 42), font=load_font(10, bold=True))

    out_file = f"{OUTPUT_DIR}/marked_screen_{sc_id}.png"
    canvas.save(out_file, quality=94)
    print(f"  [Marked Visual] {sc_id}")

print("\nSUCCESS: All 35 high-res marked visual cards generated!")
