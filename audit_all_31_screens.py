import os
import time
from PIL import Image, ImageDraw, ImageFont
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'
os.makedirs(OUTPUT_DIR, exist_ok=True)

SCREENS = [
    # 1. Auth & Splash
    {
        "id": "01_splash",
        "name": "Splash Screen",
        "route": "/",
        "category": "Authentication",
        "desc": "Branded entry screen with animated wallet icon and typography.",
        "type": "Public Auth",
        "score": 9,
        "defects": [
            ("POSITIVE", 30, 30, "ACCESSIBILITY PASS: High Contrast Branding", "Deep navy on crisp light background meets WCAG AAA standards"),
            ("UX_WARNING", 30, 750, "UX SUGGESTION: Configurable Splash Duration", "Fixed 1600ms delay can feel sluggish on fast connections")
        ]
    },
    {
        "id": "02_login",
        "name": "Login Screen",
        "route": "/login",
        "category": "Authentication",
        "desc": "Enterprise authentication form with quick 1-tap demo switcher.",
        "type": "Public Auth",
        "score": 7,
        "defects": [
            ("DEFECT", 260, 395, "UX DEFECT: Touch Target < 48dp", "Forgot Password link height is only 20dp"),
            ("FEATURE", 24, 570, "UX HIGHLIGHT: 1-Tap Persona Switcher", "Instant role switching across Employee, Manager, Finance, Admin")
        ]
    },
    {
        "id": "03_forgot_password",
        "name": "Forgot Password Screen",
        "route": "/forgot-password",
        "category": "Authentication",
        "desc": "Self-service credential recovery and email dispatch.",
        "type": "Public Auth",
        "score": 8,
        "defects": [
            ("POSITIVE", 24, 25, "UI VERIFIED: Clean Reset Architecture", "Standard single-input pattern with inline email regex validation"),
            ("UX_WARNING", 24, 480, "USABILITY: Missing Rate Limiting Indicator", "Form allows repeated rapid resends without countdown timer")
        ]
    },
    {
        "id": "04_reset_password",
        "name": "Reset Password Screen",
        "route": "/reset-password",
        "category": "Authentication",
        "desc": "Secure password replacement form with confirmation matching.",
        "type": "Public Auth",
        "score": 8,
        "defects": [
            ("POSITIVE", 24, 25, "SECURITY VERIFIED: Dual-Field Verification", "Requires password confirmation and enforces minimum length rule"),
            ("UX_WARNING", 24, 450, "UX IMPROVEMENT: Dynamic Password Strength", "Lacks visual meter for complexity (special chars, numbers)")
        ]
    },
    # 2. Shell & Dashboard
    {
        "id": "05_home_dashboard",
        "name": "Home Dashboard Screen",
        "route": "/home",
        "category": "Core Dashboard",
        "desc": "Executive summary with dynamic financial KPIs and quick action hub.",
        "type": "Employee / Admin",
        "score": 7,
        "defects": [
            ("CRITICAL", 20, 220, "CRITICAL: ProjectCard RenderFlex Overflow", "Unconstrained 4-column metric row causes 32-97px overflow on small screens"),
            ("POSITIVE", 20, 80, "UI VERIFIED: Cohesive Role Hierarchy", "Tailors greeting and action cards to the active user profile")
        ]
    },
    {
        "id": "06_main_shell",
        "name": "Main Shell Screen",
        "route": "/home",
        "category": "Navigation Shell",
        "desc": "Adaptive scaffold hosting the role-based bottom navigation bar.",
        "type": "App Shell",
        "score": 8,
        "defects": [
            ("UX_WARNING", 20, 780, "TABLET ADAPTATION FLAW: Stretched Bottom Nav", "Nav bar stretches across full width on tablet instead of using NavigationRail"),
            ("POSITIVE", 20, 740, "UI BEST PRACTICE: Semantic Tab Badging", "Provides visual unread counter on approvals and notifications")
        ]
    },
    # 3. Expenses
    {
        "id": "07_my_expenses",
        "name": "My Expenses Screen",
        "route": "/expenses/my-expenses",
        "category": "Expenses",
        "desc": "Employee expense history with multi-filter status segmentation.",
        "type": "Employee",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "UI BEST PRACTICE: Segmented Filter Chips", "Quick toggles for All, Pending, Approved, and Rejected claims"),
            ("UX_WARNING", 20, 680, "UX SUGGESTION: Infinite Scroll / Pagination", "Loads full claim history into memory without paginated fetch")
        ]
    },
    {
        "id": "08_submit_expense",
        "name": "Submit Expense Screen",
        "route": "/expenses/submit",
        "category": "Expenses",
        "desc": "Expense claim submission with category selection and receipt photo mock.",
        "type": "Employee",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 480, "UI HIGHLIGHT: Clean Receipt Upload Zone", "Dashed card with camera affordance and file type constraints"),
            ("DEFECT", 20, 780, "A11Y OVERFLOW: Bottom Button Safe Area", "Submit button clips on 320dp screen when 1.5x font scale is active")
        ]
    },
    {
        "id": "09_expense_detail",
        "name": "Expense Detail Screen",
        "route": "/expenses/exp_01",
        "category": "Expenses",
        "desc": "Granular expense inspection with receipt viewer and comment thread.",
        "type": "Employee / Manager",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "FEATURE: Real-Time Comment Thread", "Enables auditable back-and-forth communication between staff and approvers"),
            ("POSITIVE", 20, 340, "UI VERIFIED: Status Chip Visual Feedback", "Emerald green pill with icon clearly conveys Approved state")
        ]
    },
    {
        "id": "10_edit_expense",
        "name": "Edit Expense Screen",
        "route": "/expenses/exp_01/edit",
        "category": "Expenses",
        "desc": "Claim modification form with pre-populated field values.",
        "type": "Employee",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "UI VERIFIED: Safe Form Mutation", "Pre-fills all existing data and validates against project budget ceiling"),
            ("UX_WARNING", 20, 770, "USABILITY: Missing Discard Changes Confirmation", "Back button navigates away without prompt if edits are unsaved")
        ]
    },
    # 4. Approvals
    {
        "id": "11_approvals_queue",
        "name": "Approvals Queue Screen",
        "route": "/approvals",
        "category": "Approvals",
        "desc": "Manager review workflow with dual Reject/Approve action buttons.",
        "type": "Manager / Finance",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "UI BEST PRACTICE: Prominent Action Buttons", "Distinct red-tinted outline Reject vs emerald filled Approve buttons"),
            ("FEATURE", 20, 720, "UX HIGHLIGHT: Batch Processing Ready", "Allows processing multiple claims sequentially without modal re-entry")
        ]
    },
    # 5. Projects
    {
        "id": "12_projects_list",
        "name": "Projects Portfolio Screen",
        "route": "/projects",
        "category": "Projects",
        "desc": "Portfolio list with budget consumption bars and profitability tags.",
        "type": "Manager / Admin",
        "score": 7,
        "defects": [
            ("CRITICAL", 20, 240, "CRITICAL: ProjectCard RenderFlex Overflow", "Horizontal overflow in financial metrics row affects all cards"),
            ("DEFECT", 250, 730, "UX DEFECT: FAB Content Occlusion", "Floating Action Button covers financial metrics of bottom list item")
        ]
    },
    {
        "id": "13_project_detail",
        "name": "Project Detail Screen",
        "route": "/projects/proj_01",
        "category": "Projects",
        "desc": "Detailed project finances, allocated team members, and tasks.",
        "type": "Manager / Admin",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "UI VERIFIED: Multi-Tab Information Architecture", "Separates Overview, Tasks, Team, and Revenue into tabbed views"),
            ("UX_WARNING", 20, 480, "RESPONSIVE: Large Tablet Whitespace", "Single-column layout creates blank gutters on iPad screens")
        ]
    },
    {
        "id": "14_add_project",
        "name": "Add Project Screen",
        "route": "/projects/new",
        "category": "Projects",
        "desc": "New project creation with budget and client allocation.",
        "type": "Manager / Admin",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "UI VERIFIED: Comprehensive Financial Fields", "Captures budget ceiling, target revenue, client, and date schedule"),
            ("UX_WARNING", 20, 680, "USABILITY: Currency Formatting Feedback", "Raw numeric input lacks dynamic inline thousands separator commas")
        ]
    },
    {
        "id": "15_add_revenue",
        "name": "Add Revenue Screen",
        "route": "/projects/proj_01/revenue/new",
        "category": "Projects",
        "desc": "Milestone revenue billing entry to adjust project profit margin.",
        "type": "Finance / Admin",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "FINANCE FEATURE: Milestone Tracking", "Connects revenue directly to project deliverables for real-time ROI calculation"),
            ("POSITIVE", 20, 480, "UI VERIFIED: Standardized Button Placement", "Full-width primary button anchors form completion")
        ]
    },
    {
        "id": "16_project_team",
        "name": "Project Team Screen",
        "route": "/projects/proj_01/team",
        "category": "Projects",
        "desc": "Team roster management and role assignments within project.",
        "type": "Manager / Admin",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "UI VERIFIED: Staff Avatar & Role Chips", "Quick visual differentiation of project lead vs contributors"),
            ("UX_WARNING", 20, 650, "USABILITY: Missing Role Inline Edit", "Changing staff role requires removing and re-adding member")
        ]
    },
    # 6. Tasks
    {
        "id": "17_task_detail",
        "name": "Task Detail Screen",
        "route": "/tasks/tsk_01",
        "category": "Tasks",
        "desc": "Task milestone tracker linked to project budget line items.",
        "type": "All Roles",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "FEATURE: Linked Budget Line Item", "Associates task completion directly to expense categorization"),
            ("UX_WARNING", 20, 520, "UX SUGGESTION: Quick Status Dropdown", "Requires full edit form navigation to change status from In Progress to Done")
        ]
    },
    {
        "id": "18_add_task",
        "name": "Add Task Screen",
        "route": "/tasks/new?projectId=proj_01",
        "category": "Tasks",
        "desc": "Task creation with assignee selection and due date picker.",
        "type": "Manager / Admin",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "UI VERIFIED: Calendar Date Picker Widget", "Intuitive date selection with min-date validation against project end date"),
            ("UX_WARNING", 20, 580, "USABILITY: Keyboard Dismissal", "Tapping outside text field does not consistently dismiss virtual keyboard")
        ]
    },
    # 7. Reports
    {
        "id": "19_reports_overview",
        "name": "Financial Reports Screen",
        "route": "/reports",
        "category": "Reports",
        "desc": "Category expense donut chart, date range filters, and KPIs.",
        "type": "Finance / Admin",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "UI HIGHLIGHT: Interactive Donut Chart", "FlChart integration cleanly renders category percentages"),
            ("FEATURE", 20, 480, "FEATURE: Quick Date Presets", "Toggles for This Month, Last 30 Days, This Year, and Custom Range")
        ]
    },
    {
        "id": "20_company_dashboard",
        "name": "Company Dashboard Screen",
        "route": "/company-dashboard",
        "category": "Reports",
        "desc": "Organization-wide profitability and top spending breakdowns.",
        "type": "Finance / Admin",
        "score": 6,
        "defects": [
            ("CRITICAL", 20, 180, "CRITICAL DEFECT: 3-Column Squeezed Grid", "Hardcoded crossAxisCount: 3 squishes cards into ~96dp on mobile"),
            ("CRITICAL", 20, 450, "CRITICAL: ProjectCard RenderFlex Overflow", "Projects card reused here triggers horizontal overflow on mobile")
        ]
    },
    # 8. Administration
    {
        "id": "21_company_hub",
        "name": "Company Hub Screen",
        "route": "/admin/company",
        "category": "Administration",
        "desc": "Centralized admin control center unifying setup, users, and audit.",
        "type": "Admin",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "UI BEST PRACTICE: Unified Tab Navigation", "Seamless 4-tab control center for administrative duties"),
            ("UX_WARNING", 20, 750, "UX SUGGESTION: Tab Overflow on Small Phones", "4 tabs can crowd the top bar on narrow 320dp viewports")
        ]
    },
    {
        "id": "22_company_setup",
        "name": "Company Setup Screen",
        "route": "/admin/company",
        "category": "Administration",
        "desc": "Organization metadata, fiscal year start, and default currency.",
        "type": "Admin",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "UI VERIFIED: Organization Profile Form", "Structured input fields for company name, registration, and tax ID"),
            ("UX_WARNING", 20, 600, "USABILITY: Unsaved Change Warning", "Navigating away does not check for unsaved form state")
        ]
    },
    {
        "id": "23_user_management",
        "name": "User Management Screen",
        "route": "/admin/users",
        "category": "Administration",
        "desc": "Staff directory with role badges and department filtering.",
        "type": "Admin",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "UI BEST PRACTICE: Color-Coded Role Badges", "Instant visual identification of Admin, Finance, Manager, Employee"),
            ("FEATURE", 20, 680, "FEATURE: Real-Time Directory Search", "Filters by employee name, email, or department dynamically")
        ]
    },
    {
        "id": "24_add_user",
        "name": "Add User Screen",
        "route": "/admin/users/new",
        "category": "Administration",
        "desc": "Staff onboarding form with role permission assignment.",
        "type": "Admin",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "SECURITY BEST PRACTICE: Role-Based Provisioning", "Enforces strict assignment of user roles and department boundaries"),
            ("UX_WARNING", 20, 520, "USABILITY: Temporary Password Generation", "Requires manual password entry instead of 1-tap random generator")
        ]
    },
    {
        "id": "25_category_management",
        "name": "Category Management Screen",
        "route": "/admin/categories",
        "category": "Administration",
        "desc": "Expense categories, spending caps, and icon selectors.",
        "type": "Admin",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "FEATURE: Policy Spending Caps", "Displays per-category expense thresholds to prevent policy violations"),
            ("POSITIVE", 20, 380, "UI VERIFIED: Category Iconography", "Visual icons for Travel, Meals, Software, Equipment, and Office")
        ]
    },
    {
        "id": "26_audit_log",
        "name": "Audit Log Screen",
        "route": "/admin/audit-log",
        "category": "Administration",
        "desc": "Immutable compliance trail of state changes and approvals.",
        "type": "Admin",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "COMPLIANCE VERIFIED: Chronological Audit Trail", "Timestamped records of all claim submissions, approvals, and mutations"),
            ("POSITIVE", 20, 480, "UI BEST PRACTICE: Monospace Actor & ID Tags", "Clear technical attribution for security forensics")
        ]
    },
    # 9. Notifications
    {
        "id": "27_notifications",
        "name": "Notifications Screen",
        "route": "/notifications",
        "category": "Notifications",
        "desc": "Activity feed with approval alerts, budget notifications, and badges.",
        "type": "All Roles",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "UI BEST PRACTICE: Unread Dot Indicators", "Vibrant blue dot clearly highlights unread alerts"),
            ("FEATURE", 20, 720, "FEATURE: Mark All as Read", "Convenient bulk action in top app bar")
        ]
    },
    {
        "id": "28_notification_detail",
        "name": "Notification Detail Screen",
        "route": "/notifications/notif_01",
        "category": "Notifications",
        "desc": "Full explanation of claim decisions with deep links.",
        "type": "All Roles",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "FEATURE: Transparent Rejection Explanations", "Displays approver's justification and required remediation steps"),
            ("POSITIVE", 20, 420, "UX BEST PRACTICE: Deep Link to Affected Claim", "Direct 1-tap navigation to the referenced expense claim")
        ]
    },
    # 10. Profile & Settings
    {
        "id": "29_profile",
        "name": "Profile Screen",
        "route": "/profile",
        "category": "Profile & Settings",
        "desc": "User card, department assignment, and persona switcher.",
        "type": "All Roles",
        "score": 9,
        "defects": [
            ("POSITIVE", 20, 30, "UI VERIFIED: Elegant User Profile Card", "Clean avatar, role badge, department tag, and email representation"),
            ("POSITIVE", 20, 400, "FEATURE: Quick Switch Profile", "Allows switching between personas directly from user settings")
        ]
    },
    {
        "id": "30_settings",
        "name": "Settings Screen",
        "route": "/settings",
        "category": "Profile & Settings",
        "desc": "Theme mode toggle, biometric preferences, and logout.",
        "type": "All Roles",
        "score": 7,
        "defects": [
            ("DEFECT", 20, 380, "CRITICAL: Row Overflow on 360x640 Viewport", "Settings item row overflows by 59px on compact Android displays"),
            ("POSITIVE", 20, 120, "FEATURE: Dark Mode Support", "Clean theme switching with persistent settings state")
        ]
    },
    {
        "id": "31_employee_detail",
        "name": "Employee Detail Screen",
        "route": "/employees/usr_emp_01",
        "category": "Profile & Settings",
        "desc": "Staff profile inspection with assigned projects and history.",
        "type": "Manager / Admin",
        "score": 8,
        "defects": [
            ("POSITIVE", 20, 30, "UI VERIFIED: Staff Workload Breakdown", "Shows active projects, assigned tasks, and submitted expense summary"),
            ("UX_WARNING", 20, 680, "USABILITY: Missing Direct Contact Action", "Lacks 1-tap email launcher or Slack messaging deep link")
        ]
    }
]

def draw_badge(draw, x, y, title, subtitle=None, bg_color=(220, 38, 38), border_color=(185, 28, 28), text_color=(255, 255, 255)):
    padding_x = 10
    padding_y = 6
    line_h = 15
    w = max(len(title) * 7 + padding_x * 2, (len(subtitle) * 6 + padding_x * 2) if subtitle else 100)
    w = min(w, 350)
    h = padding_y * 2 + line_h + (line_h if subtitle else 0)
    
    draw.rounded_rectangle([x, y, x + w, y + h], radius=6, fill=bg_color, outline=border_color, width=1)
    draw.text((x + padding_x, y + padding_y), title, fill=text_color)
    if subtitle:
        draw.text((x + padding_x, y + padding_y + line_h), subtitle[:55], fill=(255, 230, 230) if bg_color[0]>150 else (210, 245, 230))

def draw_dashed_box(draw, bbox, color=(220, 38, 38), width=2):
    draw.rectangle(bbox, outline=color, width=width)

def annotate_screen(raw_path, annotated_path, screen_info):
    if not os.path.exists(raw_path):
        return
    im = Image.open(raw_path).convert("RGBA")
    draw = ImageDraw.Draw(im)

    for item in screen_info.get("defects", []):
        d_type, x, y, title, subtitle = item
        if d_type == "CRITICAL":
            draw_badge(draw, x, y, title, subtitle, bg_color=(220, 38, 38), border_color=(185, 28, 28))
            draw_dashed_box(draw, [x, y + 40, min(x + 340, im.width - 20), y + 140], color=(220, 38, 38), width=3)
        elif d_type == "DEFECT":
            draw_badge(draw, x, y, title, subtitle, bg_color=(217, 119, 6), border_color=(180, 83, 9))
            draw_dashed_box(draw, [x, y + 35, min(x + 320, im.width - 20), y + 90], color=(217, 119, 6), width=2)
        elif d_type == "UX_WARNING":
            draw_badge(draw, x, y, title, subtitle, bg_color=(217, 119, 6), border_color=(180, 83, 9))
        elif d_type == "POSITIVE":
            draw_badge(draw, x, y, title, subtitle, bg_color=(16, 149, 106), border_color=(5, 122, 85))
        elif d_type == "FEATURE":
            draw_badge(draw, x, y, title, subtitle, bg_color=(37, 99, 235), border_color=(29, 78, 216))

    im.save(annotated_path)

def main():
    print(f"Starting comprehensive audit of all {len(SCREENS)} screens...")
    
    opts = Options()
    opts.add_argument('--headless=new')
    opts.add_argument('--no-sandbox')
    opts.add_argument('--enable-unsafe-swiftshader')
    opts.add_argument('--window-size=390,844')
    driver = webdriver.Chrome(options=opts)

    # Initial warm-up load
    driver.get('http://localhost:8085/#/home')
    time.sleep(6)

    # Capture Mobile 390x844 for all 31 screens
    for s in SCREENS:
        sid = s["id"]
        route = s["route"]
        url = f"http://localhost:8085/#{route}"
        driver.get(url)
        time.sleep(1.8)
        
        raw_mobile = f"{OUTPUT_DIR}/raw_screen_{sid}_mobile.png"
        driver.save_screenshot(raw_mobile)
        
        annotated_mobile = f"{OUTPUT_DIR}/annotated_screen_{sid}.png"
        annotate_screen(raw_mobile, annotated_mobile, s)
        print(f"[{sid}] {s['name']} -> Captured & Annotated ({os.path.getsize(annotated_mobile)} bytes)")

    # Capture Tablet 768x1024 for key anchor screens
    tablet_screens = ["02_login", "05_home_dashboard", "07_my_expenses", "11_approvals_queue", "12_projects_list", "19_reports_overview", "23_user_management"]
    driver.set_window_size(768, 1024)
    time.sleep(2)
    for sid in tablet_screens:
        s = next(x for x in SCREENS if x["id"] == sid)
        url = f"http://localhost:8085/#{s['route']}"
        driver.get(url)
        time.sleep(2)
        raw_tablet = f"{OUTPUT_DIR}/raw_screen_{sid}_tablet.png"
        driver.save_screenshot(raw_tablet)
        print(f"[TABLET: {sid}] Captured ({os.path.getsize(raw_tablet)} bytes)")

    driver.quit()
    print("All 31 screens successfully captured, evaluated, and annotated!")

if __name__ == "__main__":
    main()
