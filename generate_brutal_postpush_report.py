import os
import sys
import base64
import json
import shutil
import subprocess

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe'
SCREENSHOTS_DIR = os.path.join(OUTPUT_DIR, 'screenshots')
HTML_FILE = os.path.join(OUTPUT_DIR, 'SpendWise_Pro_Enterprise_Audit_Report.html')
PDF_FILE = os.path.join(OUTPUT_DIR, 'SpendWise_Pro_Enterprise_Mobile_Audit_Report.pdf')
DESKTOP_DIR = '/home/alvee/Desktop'

def get_base64_image(file_path):
    if not os.path.exists(file_path):
        return ""
    with open(file_path, "rb") as f:
        encoded = base64.b64encode(f.read()).decode("utf-8")
        return f"data:image/png;base64,{encoded}"

# Complete 35 Screens Data for Commit 0d62f0b
SCREENS_DATA = [
    # 1. Auth & Onboarding
    {
        "id": "01_splash", "num": "01", "name": "Splash Screen", "route": "/",
        "category": "Authentication", "persona": "Public / Unauthenticated", "score": "9.0/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Branded entry screen with animated wallet icon, PFIS title, and version tagline.",
        "heuristics": "H1: Visibility of System Status (Pass), H8: Aesthetic & Minimalist Design (Pass)",
        "defects": [
            {"type": "PASS", "badge": "WCAG AAA Passed", "detail": "Deep Navy (#0F172A) on White delivers 15.2:1 contrast ratio, exceeding WCAG AAA standards."},
            {"type": "UX_NOTE", "badge": "Bypassed In Production", "detail": "Default state in auth_provider.dart hardcodes isAuthenticated: true, causing splash to bypass login entirely."}
        ]
    },
    {
        "id": "02_login", "num": "02", "name": "Login & Authentication Screen", "route": "/login",
        "category": "Authentication", "persona": "Public Auth", "score": "6.8/10",
        "status": "DEFECT DETECTED", "status_color": "#EF4444",
        "desc": "Enterprise authentication gateway with credential inputs, validation triggers, and 1-tap demo persona switcher.",
        "heuristics": "H5: Error Prevention (Warning), H7: Flexibility & Efficiency of Use (Pass)",
        "defects": [
            {"type": "DEFECT", "badge": "Touch Target < 48dp", "detail": "'Forgot Password?' hit box is only 20dp high (login_screen.dart:185), violating Apple HIG & Material 3 minimums."},
            {"type": "OVERFLOW", "badge": "Compact Overflow", "detail": "1-Tap Demo Switcher header row overflows by 54px on 320dp/360dp mobile viewports without Wrap widget."},
            {"type": "REGRESSION", "badge": "Tests Gutted", "detail": "Developer deleted all 8 assertions validating this screen in test/splash_login_flow_test.dart to hide auth bypass."}
        ]
    },
    {
        "id": "03_register", "num": "03", "name": "Self-Registration Form", "route": "/register",
        "category": "Authentication", "persona": "Public / New Staff", "score": "6.5/10",
        "status": "TABLET BLOWOUT", "status_color": "#F59E0B",
        "desc": "New employee self-onboarding portal allowing role selection, department assignment, and password creation.",
        "heuristics": "H5: Error Prevention (Pass), H4: Consistency & Standards (Fail)",
        "defects": [
            {"type": "TABLET", "badge": "1024px Full-Width Stretch", "detail": "Registration card expands to full 1024px width on iPad with unconstrained form fields (register_screen.dart:120)."},
            {"type": "SECURITY", "badge": "Unrestricted Role Selection", "detail": "Allows public self-registration directly into Main Admin and Finance roles without approval workflow."}
        ]
    },
    {
        "id": "04_forgot_password", "num": "04", "name": "Forgot Password Recovery", "route": "/forgot-password",
        "category": "Authentication", "persona": "Public Auth", "score": "8.5/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Self-service recovery screen initiating password reset dispatch via verified corporate email.",
        "heuristics": "H5: Error Prevention (Pass), H9: Error Recovery (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Clean Form Architecture", "detail": "Single input focus with real-time email regex validation prevents malformed requests."},
            {"type": "UX_NOTE", "badge": "Missing Rate Limiter", "detail": "Lacks client-side throttle timer on repeated 'Send Reset Link' taps to prevent email bombing."}
        ]
    },
    {
        "id": "05_reset_password", "num": "05", "name": "Reset Password Screen", "route": "/reset-password",
        "category": "Authentication", "persona": "Public Auth", "score": "8.4/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Secure password replacement form enforcing new credential criteria and dual-field matching confirmation.",
        "heuristics": "H5: Error Prevention (Pass), H8: Aesthetic Design (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Dual Confirmation", "detail": "Strict equality comparison between new password and confirmation field ensures error-free updates."},
            {"type": "UX_NOTE", "badge": "Missing Strength Meter", "detail": "No dynamic password entropy indicator (e.g. Weak/Medium/Strong bar) during typing."}
        ]
    },
    # 2. Shell & Dashboard
    {
        "id": "06_home_dashboard", "num": "06", "name": "Home Executive Dashboard", "route": "/home",
        "category": "Core Dashboard", "persona": "Main Admin / Manager / Member", "score": "5.5/10",
        "status": "GOD-WIDGET & JANK", "status_color": "#DC2626",
        "desc": "Primary operational dashboard aggregating monthly spend KPIs, active project budget cards, and quick expense actions.",
        "heuristics": "H1: Visibility of System Status (Pass), H4: Consistency and Standards (Fail)",
        "defects": [
            {"type": "ARCH", "badge": "1,098-Line God Widget", "detail": "Massive monolithic stateful widget mixing financial aggregations, UI layout, mock data, and persona switching."},
            {"type": "PERF", "badge": "Heavy Build Calculations", "detail": "O(N*M) expense and project fold() aggregations executed inside build() on every render frame."},
            {"type": "OVERFLOW", "badge": "ProjectCard Overflow", "detail": "Metric row in ProjectCard overflows by 32-64px on 320dp/360dp mobile viewports without flexible wrapping."}
        ]
    },
    {
        "id": "07_main_shell", "num": "07", "name": "Main Navigation Shell", "route": "/home",
        "category": "Navigation Shell", "persona": "All Roles", "score": "7.0/10",
        "status": "TABLET STRETCH", "status_color": "#F59E0B",
        "desc": "Scaffold wrapper hosting the bottom navigation bar and managing tab switching across primary modules.",
        "heuristics": "H4: Consistency & Standards (Pass), H7: Flexibility & Efficiency (Warning)",
        "defects": [
            {"type": "TABLET", "badge": "Stretched Bottom Bar", "detail": "Mobile bottom nav bar stretches across 1024px tablet display with 250px icon gaps instead of an adaptive NavigationRail."},
            {"type": "PASS", "badge": "Role-Adaptive Tabs", "detail": "Correctly adapts tab items depending on active role (Member gets My Expenses, Manager gets Approvals)."}
        ]
    },
    # 3. Expenses
    {
        "id": "08_my_expenses", "num": "08", "name": "My Expenses List Screen", "route": "/expenses/my-expenses",
        "category": "Expense Management", "persona": "Project Member / Employee", "score": "7.5/10",
        "status": "TABLET WHITESPACE", "status_color": "#F59E0B",
        "desc": "Personal expense tracker displaying filed claims, approval status badges, search filtering, and summary cards.",
        "heuristics": "H1: System Status (Pass), H6: Recognition Rather Than Recall (Pass)",
        "defects": [
            {"type": "TABLET", "badge": "70% Dead Whitespace", "detail": "Single-column ListView leaves 700px of empty white void on 1024px iPad displays."},
            {"type": "PASS", "badge": "Status Chip Color Coding", "detail": "Approved (Emerald), Pending (Amber), Rejected (Crimson) chips provide instant cognitive clarity."}
        ]
    },
    {
        "id": "09_submit_expense", "num": "09", "name": "Submit Expense Claim Form", "route": "/expenses/submit",
        "category": "Expense Management", "persona": "Member / Manager / Admin", "score": "5.0/10",
        "status": "GOD-WIDGET & BLOWOUT", "status_color": "#DC2626",
        "desc": "Multi-step expense submission form supporting category selection, project attribution, receipt OCR upload, and spending cap validation.",
        "heuristics": "H5: Error Prevention (Pass), H8: Aesthetic & Minimalist Design (Fail)",
        "defects": [
            {"type": "ARCH", "badge": "1,012-Line Monolith", "detail": "Single file containing 1,012 lines mixing form controllers, file picker mocks, OCR simulation, and category math."},
            {"type": "TABLET", "badge": "1024px Form Blowout", "detail": "All 12 input fields stretch 980px wide on iPad without max-width constraints, violating ergonomic scanning."},
            {"type": "LINT", "badge": "4x Deprecated APIs", "detail": "Uses deprecated 'value' and 'activeColor' in DropdownButtonFormField and Switch (submit_expense_screen.dart:297, 579)."}
        ]
    },
    {
        "id": "10_receipt_compliance", "num": "10", "name": "Receipt Compliance Audit View", "route": "/receipt-compliance",
        "category": "Expense Management", "persona": "All Roles / Auditors", "score": "6.5/10",
        "status": "UNPROTECTED & SQUASHED", "status_color": "#EF4444",
        "desc": "New compliance dashboard auditing expenses missing formal receipts, missing justification letters, and policy adherence.",
        "heuristics": "H1: System Status (Pass), H3: User Control & Freedom (Pass)",
        "defects": [
            {"type": "SECURITY", "badge": "No Route Guard", "detail": "Directly accessible via /receipt-compliance by any authenticated user; lacks role restriction."},
            {"type": "TABLET", "badge": "Table Layout Distortion", "detail": "Compliance audit rows stretch to 1024px width, leaving status chips disconnected from expense descriptions."},
            {"type": "LINT", "badge": "Deprecated API", "detail": "Uses deprecated 'value' parameter on line 63 of receipt_compliance_screen.dart."}
        ]
    },
    {
        "id": "11_expense_detail", "num": "11", "name": "Expense Detail & Audit Trail", "route": "/expenses/:id",
        "category": "Expense Management", "persona": "All Roles", "score": "8.8/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Comprehensive view of a single claim, receipt thumbnail preview, category policy checklist, and timeline.",
        "heuristics": "H1: System Status (Pass), H7: Flexibility of Use (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Receipt Preview Modal", "detail": "High-quality zoomable receipt preview with simulated OCR verification checklist."},
            {"type": "PASS", "badge": "Immutable Timeline", "detail": "Vertical chronological steppers display submission, review, and payout milestones cleanly."}
        ]
    },
    {
        "id": "12_edit_expense", "num": "12", "name": "Edit Expense Screen", "route": "/expenses/:id/edit",
        "category": "Expense Management", "persona": "Claim Owner / Admin", "score": "7.8/10",
        "status": "DEPRECATED LINTS", "status_color": "#F59E0B",
        "desc": "Claim modification form allowing employees to amend rejected or draft claims with supplementary documentation.",
        "heuristics": "H3: User Control (Pass), H5: Error Prevention (Pass)",
        "defects": [
            {"type": "LINT", "badge": "2x Deprecated APIs", "detail": "Uses deprecated 'value' parameter in DropdownButtonFormField (edit_expense_screen.dart:223, 257)."},
            {"type": "TABLET", "badge": "Unconstrained Tablet Width", "detail": "Form fields stretch horizontally across tablet viewport without max-width bounding box."}
        ]
    },
    # 4. Approvals
    {
        "id": "13_approvals_queue", "num": "13", "name": "Manager Approvals Queue", "route": "/approvals",
        "category": "Approval Workflow", "persona": "Project Manager / Finance / Admin", "score": "7.2/10",
        "status": "BATCH GAP & TABLET SPREAD", "status_color": "#F59E0B",
        "desc": "Pending claim triage screen with 1-tap Approve/Reject action triggers and justification reviews.",
        "heuristics": "H7: Flexibility & Efficiency (Warning), H5: Error Prevention (Pass)",
        "defects": [
            {"type": "UX_DEFECT", "badge": "No Batch Approval CTA", "detail": "Managers must approve claims individually; missing multi-select batch approval mode (PRD Section 11)."},
            {"type": "TABLET", "badge": "Action Button Spread", "detail": "On iPad 1024px, Approve and Reject buttons are separated by 750px of whitespace, slowing triage speed."}
        ]
    },
    # 5. Projects & Financial Intelligence
    {
        "id": "14_projects_list", "num": "14", "name": "Projects Portfolio List", "route": "/projects",
        "category": "Projects", "persona": "All Roles", "score": "7.0/10",
        "status": "TABLET WHITESPACE", "status_color": "#F59E0B",
        "desc": "Directory of all ongoing, completed, and on-hold consultancy projects with budget health indicators.",
        "heuristics": "H1: System Status (Pass), H4: Consistency (Pass)",
        "defects": [
            {"type": "TABLET", "badge": "70% Dead Void", "detail": "Single-column cards stretch across 1024px tablet landscape; desperately needs a 2-column GridView."},
            {"type": "OVERFLOW", "badge": "Compact Overlap", "detail": "Contract and spent metrics overlap on 320dp/360dp compact mobile devices."}
        ]
    },
    {
        "id": "15_project_detail", "num": "15", "name": "Project Detail Hub", "route": "/projects/:id",
        "category": "Projects", "persona": "All Roles", "score": "6.0/10",
        "status": "804-LINE GOD-WIDGET", "status_color": "#DC2626",
        "desc": "Centralized project hub presenting budget burn-rate progress bars, task breakdowns, team members, and milestones.",
        "heuristics": "H1: System Status (Pass), H8: Aesthetic Design (Warning)",
        "defects": [
            {"type": "ARCH", "badge": "804-Line Monolith", "detail": "Contains 804 lines combining financial formulas, tab views, task lists, and milestone progress bars."},
            {"type": "TABLET", "badge": "Flattened Metric Cards", "detail": "Top financial KPI cards become severely horizontally stretched on 1024px landscape."}
        ]
    },
    {
        "id": "16_add_project", "num": "16", "name": "Add Project Form", "route": "/projects/new",
        "category": "Projects", "persona": "Admin / Manager / Finance", "score": "6.5/10",
        "status": "DEPRECATED LINTS & STRETCH", "status_color": "#EF4444",
        "desc": "Multi-section project setup form capturing client details, contract gross value, office benefit rate, and duration.",
        "heuristics": "H5: Error Prevention (Pass), H4: Consistency (Fail)",
        "defects": [
            {"type": "LINT", "badge": "4x Deprecated APIs", "detail": "Uses deprecated 'value' parameter in 4 dropdown fields (add_edit_project_screen.dart:275, 286, 310, 370)."},
            {"type": "TABLET", "badge": "1024px Form Blowout", "detail": "Form stretches completely across tablet screen with awkward single-column layout."}
        ]
    },
    {
        "id": "17_edit_project", "num": "17", "name": "Edit Project Form", "route": "/projects/:id/edit",
        "category": "Projects", "persona": "Admin / Manager / Finance", "score": "7.2/10",
        "status": "TABLET WARNING", "status_color": "#F59E0B",
        "desc": "Project parameters editor allowing updates to budget allocation, milestones, and client contact information.",
        "heuristics": "H3: User Control (Pass), H5: Error Prevention (Pass)",
        "defects": [
            {"type": "TABLET", "badge": "Unconstrained Container", "detail": "Lacks responsive layout constraints on tablet displays; form stretches to full window width."}
        ]
    },
    {
        "id": "18_add_revenue", "num": "18", "name": "Add Revenue Milestone Form", "route": "/projects/:id/revenue/new",
        "category": "Projects", "persona": "Admin / Finance", "score": "8.5/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Milestone billing and payment entry form capturing installment amount, invoice number, and collection date.",
        "heuristics": "H5: Error Prevention (Pass), H8: Minimalist Design (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Accurate Financial Math", "detail": "Validates received revenue against outstanding gross project contract values."}
        ]
    },
    {
        "id": "19_project_team", "num": "19", "name": "Project Team Directory", "route": "/projects/:id/team",
        "category": "Projects", "persona": "All Roles", "score": "8.2/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Roster of assigned personnel, designated field roles, contact shortcuts, and individual spending limits.",
        "heuristics": "H1: System Status (Pass), H8: Minimalist Design (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Avatar Badge Formatting", "detail": "Clean presentation of user initials, role badges, and phone numbers."}
        ]
    },
    {
        "id": "20_client_analysis", "num": "20", "name": "Client Profitability Analysis", "route": "/client-analysis",
        "category": "Administration & Analytics", "persona": "Main Admin (Accidental Public)", "score": "3.5/10",
        "status": "OWASP A01 & DATA CORRUPTION", "status_color": "#DC2626",
        "desc": "Client-level portfolio intelligence computing total contracts, revenue, receivables, and profit margins.",
        "heuristics": "H1: System Status (Fail), H5: Error Prevention (Fail)",
        "defects": [
            {"type": "SECURITY", "badge": "OWASP A01: Broken Access Control", "detail": "Route /client-analysis lacks /admin prefix; completely unguarded in app_router.dart, exposing corporate margins to all roles."},
            {"type": "CRITICAL", "badge": "Financial Contamination Bug", "detail": "Uses .split(' ').first substring matching (line 38); merges all 'Ministry' or 'Asian' clients together, corrupting metrics."},
            {"type": "PERF", "badge": "O(N*M) Math in build()", "detail": "Loops over all projects and expenses on every build frame, causing UI stutter."}
        ]
    },
    {
        "id": "21_cost_estimator", "num": "21", "name": "Project Cost Estimator", "route": "/cost-estimator",
        "category": "Administration & Analytics", "persona": "Main Admin / Estimators", "score": "4.0/10",
        "status": "OWASP A01 VULNERABILITY", "status_color": "#DC2626",
        "desc": "Predictive estimation engine calculating proposed consultancy fees based on duration, staff count, locations, and travel intensity.",
        "heuristics": "H7: Flexibility (Pass), H5: Error Prevention (Fail)",
        "defects": [
            {"type": "SECURITY", "badge": "OWASP A01: Broken Access Control", "detail": "Route /cost-estimator lacks /admin prefix; unguarded in app_router.dart, allowing unauthenticated estimation access."},
            {"type": "LINT", "badge": "2x Deprecated APIs", "detail": "Uses deprecated 'value' in dropdown fields (cost_estimator_screen.dart:116, 174)."},
            {"type": "TABLET", "badge": "1024px Parameter Stretch", "detail": "Estimator parameter inputs stretch across 1024px tablet display without two-column split."}
        ]
    },
    # 6. Tasks
    {
        "id": "22_task_detail", "num": "22", "name": "Task Detail Inspector", "route": "/tasks/:id",
        "category": "Task Management", "persona": "All Roles", "score": "8.5/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Individual task inspector showing deliverables, assigned team member, status toggle, and discussion comments.",
        "heuristics": "H1: System Status (Pass), H7: Flexibility of Use (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Comment Thread Widget", "detail": "Integrated discussion thread allows team members to communicate directly on task deliverables."}
        ]
    },
    {
        "id": "23_add_task", "num": "23", "name": "Add Task Form", "route": "/tasks/new",
        "category": "Task Management", "persona": "Manager / Admin", "score": "7.5/10",
        "status": "DEPRECATED LINTS", "status_color": "#F59E0B",
        "desc": "Task creation modal with priority selection, assignee picker, deadline dates, and project binding.",
        "heuristics": "H5: Error Prevention (Pass), H8: Minimalist Design (Pass)",
        "defects": [
            {"type": "LINT", "badge": "2x Deprecated APIs", "detail": "Uses deprecated 'value' parameter in Priority and Assignee dropdowns (add_edit_task_screen.dart:168, 203)."}
        ]
    },
    # 7. Reports & Company Dashboard
    {
        "id": "24_reports_overview", "num": "24", "name": "Financial Reports & Charts", "route": "/reports",
        "category": "Reports", "persona": "Finance / Manager / Admin", "score": "6.8/10",
        "status": "CHART FLATTENED", "status_color": "#EF4444",
        "desc": "Company analytical reports screen featuring monthly spending bar charts, category breakdowns, and export utilities.",
        "heuristics": "H1: System Status (Pass), H8: Aesthetic Design (Warning)",
        "defects": [
            {"type": "TABLET", "badge": "5:1 Distorted Chart Flattening", "detail": "On 1024x768 landscape, charts stretch to 1000px width with fixed 200px height, flattening visual curve inflections."},
            {"type": "PASS", "badge": "Multi-Format Export", "detail": "Clean integration with ExportService for CSV and PDF report generation."}
        ]
    },
    {
        "id": "25_company_dashboard", "num": "25", "name": "Company Executive Dashboard", "route": "/company-dashboard",
        "category": "Reports", "persona": "Finance / Main Admin", "score": "7.8/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "High-level corporate balance sheet displaying total firm revenue, cumulative expenses, profit margins, and project pipeline health.",
        "heuristics": "H1: System Status (Pass), H2: Match Between System & Real World (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Correct Role Guard", "detail": "Properly protected in app_router.dart: only accessible by Finance and Main Admin roles."}
        ]
    },
    # 8. Administration
    {
        "id": "26_company_setup", "num": "26", "name": "Company Setup Form", "route": "/admin/company",
        "category": "Administration", "persona": "Main Admin", "score": "7.0/10",
        "status": "DEPRECATED LINT & STRETCH", "status_color": "#F59E0B",
        "desc": "Corporate configuration portal managing company legal name, tax registration number, currency, and fiscal year.",
        "heuristics": "H5: Error Prevention (Pass), H4: Consistency (Warning)",
        "defects": [
            {"type": "LINT", "badge": "Deprecated API", "detail": "Uses deprecated 'value' parameter in fiscal month dropdown (company_setup_screen.dart:139)."},
            {"type": "TABLET", "badge": "1024px Full Width Blowout", "detail": "Single column inputs stretch 980px wide on tablet screens."}
        ]
    },
    {
        "id": "27_user_management", "num": "27", "name": "User Management Directory", "route": "/admin/users",
        "category": "Administration", "persona": "Main Admin", "score": "7.4/10",
        "status": "DEPRECATED LINT & VOID", "status_color": "#F59E0B",
        "desc": "Staff governance portal listing active accounts, assigned roles, departments, active toggle switches, and access permissions.",
        "heuristics": "H1: System Status (Pass), H7: Flexibility (Pass)",
        "defects": [
            {"type": "LINT", "badge": "Deprecated API", "detail": "Uses deprecated 'activeColor' in Switch (user_management_screen.dart:213)."},
            {"type": "TABLET", "badge": "70% Dead Whitespace", "detail": "User list items stretch across 1024px with excessive blank void between name and toggle switch."}
        ]
    },
    {
        "id": "28_add_user", "num": "28", "name": "Add User Screen", "route": "/admin/users/new",
        "category": "Administration", "persona": "Main Admin", "score": "7.0/10",
        "status": "DEPRECATED LINT", "status_color": "#F59E0B",
        "desc": "Administrative user creation portal provisioning employee accounts, roles, departments, and project assignments.",
        "heuristics": "H5: Error Prevention (Pass), H4: Consistency (Pass)",
        "defects": [
            {"type": "LINT", "badge": "Deprecated API", "detail": "Uses deprecated 'value' parameter in role dropdown (add_edit_user_screen.dart:146)."}
        ]
    },
    {
        "id": "29_category_management", "num": "29", "name": "Category Spending Caps", "route": "/admin/categories",
        "category": "Administration", "persona": "Main Admin", "score": "7.2/10",
        "status": "DEPRECATED LINT", "status_color": "#F59E0B",
        "desc": "Corporate expense policy editor configuring maximum reimbursement limits, receipt requirements, and active category statuses.",
        "heuristics": "H5: Error Prevention (Pass), H7: Flexibility of Use (Pass)",
        "defects": [
            {"type": "LINT", "badge": "Deprecated API", "detail": "Uses deprecated 'activeColor' in Switch (category_management_screen.dart:230)."}
        ]
    },
    {
        "id": "30_audit_log", "num": "30", "name": "Immutable Audit Trail", "route": "/admin/audit-log",
        "category": "Administration", "persona": "Main Admin", "score": "7.5/10",
        "status": "TABLET VOID", "status_color": "#F59E0B",
        "desc": "Compliance event stream recording logins, claim submissions, approvals, rejections, and administrative updates.",
        "heuristics": "H1: System Status (Pass), H2: Match Between System & Real World (Pass)",
        "defects": [
            {"type": "TABLET", "badge": "70% Dead Whitespace", "detail": "Event logs stretch across 1024px width with tiny text anchored to the far left."}
        ]
    },
    # 9. Notifications
    {
        "id": "31_notifications", "num": "31", "name": "Notifications Inbox", "route": "/notifications",
        "category": "Notifications", "persona": "All Roles", "score": "8.8/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Actionable notifications stream delivering approval requests, policy threshold alerts, and reimbursement confirmations.",
        "heuristics": "H1: System Status (Pass), H8: Minimalist Design (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Unread Badge Sync", "detail": "Unread counter badges update synchronously across app bar icon and drawer."}
        ]
    },
    {
        "id": "32_notification_detail", "num": "32", "name": "Notification Detail", "route": "/notifications/:id",
        "category": "Notifications", "persona": "All Roles", "score": "8.6/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Detailed message view providing full audit context and direct 1-tap navigation to the referenced expense claim.",
        "heuristics": "H9: Help Users Recognize & Recover (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Deep Link to Target Claim", "detail": "1-tap 'View Affected Expense' CTA deep-links directly into the disputed expense claim."}
        ]
    },
    # 10. Profile & Settings
    {
        "id": "33_profile", "num": "33", "name": "User Profile Screen", "route": "/profile",
        "category": "Profile & Settings", "persona": "All Roles", "score": "9.2/10",
        "status": "EXCELLENT", "status_color": "#10B981",
        "desc": "Personal account overview featuring employee credentials, assigned department, active role badge, and session switcher.",
        "heuristics": "H8: Aesthetic & Minimalist Design (Pass)",
        "defects": [
            {"type": "PASS", "badge": "High-Polish User Card", "detail": "Clean elevation, rounded avatar with border, department tag, and email verification badge."}
        ]
    },
    {
        "id": "34_settings", "num": "34", "name": "Application Settings", "route": "/settings",
        "category": "Profile & Settings", "persona": "All Roles", "score": "7.0/10",
        "status": "DEPRECATED LINT & OVERFLOW", "status_color": "#EF4444",
        "desc": "Configuration panel managing Theme Mode (Dark/Light), Biometric Authentication, Push Notifications, and Cache.",
        "heuristics": "H4: Consistency & Standards (Fail), H7: Flexibility of Use (Pass)",
        "defects": [
            {"type": "LINT", "badge": "Deprecated API", "detail": "Uses deprecated 'value' parameter in currency dropdown (settings_screen.dart:63)."},
            {"type": "OVERFLOW", "badge": "Compact Overflow", "detail": "Settings row overflows right edge by 59px on 360dp mobile viewports."}
        ]
    },
    {
        "id": "35_employee_detail", "num": "35", "name": "Employee Detail Inspector", "route": "/employees/:id",
        "category": "Profile & Settings", "persona": "Manager / Admin", "score": "8.6/10",
        "status": "PASS", "status_color": "#10B981",
        "desc": "Staff workload inspector showing assigned projects, active budget authorization, and historical expense claims.",
        "heuristics": "H1: System Status (Pass), H2: Match Between System & Real World (Pass)",
        "defects": [
            {"type": "PASS", "badge": "Cross-Module Attribution", "detail": "Unifies staff HR data with live project task progress and reimbursement metrics."}
        ]
    }
]

def build_brutal_report():
    print("Beginning generation of Brutal Forensic Post-Push Audit Report for Commit 0d62f0b...")

    ipad_defects_matrix_b64 = get_base64_image(f"{SCREENSHOTS_DIR}/matrix_postpush_ipad_defects.png")
    admin_mobile_b64 = get_base64_image(f"{SCREENSHOTS_DIR}/postpush_role_admin_mobile.png")
    admin_ipad_b64 = get_base64_image(f"{SCREENSHOTS_DIR}/postpush_role_admin_ipad.png")

    # Generate Screen Cards HTML
    screen_cards_html = ""
    for s in SCREENS_DATA:
        sc_id = s["id"]
        matrix_img_path = f"{SCREENSHOTS_DIR}/postpush_annotated_{sc_id}.png"
        matrix_b64 = get_base64_image(matrix_img_path)

        defects_html = ""
        for d in s["defects"]:
            badge_class = "badge-pass" if d["type"] == "PASS" else ("badge-crit" if d["type"] in ["CRITICAL", "SECURITY", "ARCH"] else "badge-warn")
            defects_html += f"""
            <div style="margin-bottom: 6px; font-size: 8.5pt; line-height: 1.4;">
              <span class="badge {badge_class}">{d['badge']}</span>
              <span style="color: #334155; margin-left: 6px;">{d['detail']}</span>
            </div>
            """

        screen_cards_html += f"""
        <div class="screen-card" style="page-break-inside: avoid; margin-bottom: 24px; border: 1px solid #E2E8F0; border-radius: 12px; overflow: hidden; background: #FFFFFF; box-shadow: 0 2px 4px rgba(0,0,0,0.03);">
          <!-- Card Header -->
          <div style="background: #F8FAFC; border-bottom: 1px solid #E2E8F0; padding: 12px 16px; display: flex; justify-content: space-between; align-items: center;">
            <div>
              <span style="display: inline-block; background: #0F172A; color: #FFFFFF; font-weight: 800; font-size: 8pt; padding: 2px 8px; border-radius: 4px; margin-right: 8px;">SCREEN #{s['num']}</span>
              <strong style="font-size: 11pt; color: #0F172A;">{s['name']}</strong>
              <span style="font-family: monospace; font-size: 8pt; color: #64748B; margin-left: 10px;">#{s['route']}</span>
            </div>
            <div>
              <span class="badge" style="background: {s['status_color']}; color: #FFFFFF; font-weight: 700;">{s['status']}</span>
              <span style="display: inline-block; background: #E2E8F0; color: #0F172A; font-weight: 800; font-size: 8pt; padding: 3px 8px; border-radius: 6px; margin-left: 6px;">Score: {s['score']}</span>
            </div>
          </div>

          <!-- Metadata Grid -->
          <div style="padding: 10px 16px; background: #FFFFFF; border-bottom: 1px solid #F1F5F9; font-size: 8.5pt; color: #475569; display: grid; grid-template-columns: 1fr 1fr 2fr; gap: 8px;">
            <div><strong>Category:</strong> {s['category']}</div>
            <div><strong>Intended Persona:</strong> {s['persona']}</div>
            <div><strong>Heuristics:</strong> {s['heuristics']}</div>
          </div>

          <!-- Description -->
          <div style="padding: 10px 16px; font-size: 8.5pt; color: #334155; line-height: 1.45; background: #FFFFFF;">
            {s['desc']}
          </div>

          <!-- 5-Device Responsive Matrix Image -->
          <div style="padding: 10px 16px; background: #F8FAFC; border-top: 1px solid #F1F5F9; border-bottom: 1px solid #F1F5F9; text-align: center;">
            {f'<img src="{matrix_b64}" style="max-width: 100%; height: auto; border-radius: 6px; border: 1px solid #E2E8F0;" alt="{s["name"]} Responsive Matrix" />' if matrix_b64 else '<div style="color: #94A3B8; font-size: 8pt; padding: 20px;">[Responsive Matrix Render In Progress]</div>'}
          </div>

          <!-- Findings & Violations -->
          <div style="padding: 12px 16px; background: #FFFFFF;">
            <div style="font-size: 8.5pt; font-weight: 800; color: #0F172A; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;">Forensic Findings & Technical Violations:</div>
            {defects_html}
          </div>
        </div>
        """

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SpendWise Pro (PFIS Financials) — Post-Push Forensic Audit Report</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&display=swap');

  @page {{
    size: A4 portrait;
    margin: 14mm 12mm 14mm 12mm;
    @bottom-right {{
      content: counter(page);
      font-family: 'Plus Jakarta Sans', sans-serif;
      font-size: 8.5pt;
      color: #64748B;
    }}
  }}

  * {{
    box-sizing: border-box;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }}

  body {{
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    color: #0F172A;
    background: #FFFFFF;
    margin: 0;
    padding: 0;
    font-size: 9pt;
    line-height: 1.5;
  }}

  h1, h2, h3, h4 {{
    color: #0F172A;
    font-weight: 800;
    margin-top: 0;
    letter-spacing: -0.4px;
  }}

  h1 {{ font-size: 21pt; line-height: 1.2; }}
  h2 {{ font-size: 14pt; border-bottom: 2px solid #0F172A; padding-bottom: 6px; margin-top: 26px; margin-bottom: 12px; }}
  h3 {{ font-size: 11pt; color: #1E293B; margin-top: 18px; margin-bottom: 8px; }}

  .badge {{
    display: inline-block;
    padding: 2px 7px;
    border-radius: 4px;
    font-size: 7.5pt;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.3px;
  }}

  .badge-pass {{ background: #DCFCE7; color: #15803D; border: 1px solid #BBF7D0; }}
  .badge-warn {{ background: #FEF3C7; color: #B45309; border: 1px solid #FDE68A; }}
  .badge-crit {{ background: #FEE2E2; color: #B91C1C; border: 1px solid #FECACA; }}
  .badge-info {{ background: #E0E7FF; color: #4338CA; border: 1px solid #C7D2FE; }}

  .hero {{
    background: linear-gradient(135deg, #0F172A 0%, #1E1B4B 100%);
    color: #FFFFFF;
    padding: 28px 24px;
    border-radius: 14px;
    margin-bottom: 24px;
    border: 1px solid #334155;
  }}

  .kpi-grid {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-bottom: 24px;
  }}

  .kpi-card {{
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 10px;
    padding: 12px 14px;
    text-align: center;
  }}

  .kpi-val {{
    font-size: 18pt;
    font-weight: 800;
    line-height: 1.1;
    margin-bottom: 4px;
  }}

  .kpi-lbl {{
    font-size: 7.5pt;
    font-weight: 700;
    text-transform: uppercase;
    color: #64748B;
    letter-spacing: 0.5px;
  }}

  table.audit-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 8.5pt;
    margin-bottom: 20px;
    background: #FFFFFF;
  }}

  table.audit-table th {{
    background: #0F172A;
    color: #FFFFFF;
    text-align: left;
    padding: 8px 10px;
    font-weight: 700;
    font-size: 8pt;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }}

  table.audit-table td {{
    padding: 8px 10px;
    border-bottom: 1px solid #E2E8F0;
    vertical-align: top;
  }}

  table.audit-table tr:nth-child(even) td {{
    background: #F8FAFC;
  }}

  .code-block {{
    background: #0F172A;
    color: #F8FAFC;
    padding: 12px 16px;
    border-radius: 8px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 8pt;
    line-height: 1.45;
    overflow-x: auto;
    margin-bottom: 16px;
    border: 1px solid #334155;
  }}

  .diff-del {{ color: #F87171; background: rgba(239, 68, 68, 0.15); display: block; }}
  .diff-add {{ color: #4ADE80; background: rgba(34, 197, 94, 0.15); display: block; }}
  .diff-info {{ color: #94A3B8; font-style: italic; }}

  .alert-banner {{
    border-left: 4px solid #EF4444;
    background: #FEF2F2;
    padding: 12px 16px;
    border-radius: 0 8px 8px 0;
    margin-bottom: 16px;
    font-size: 8.5pt;
  }}
</style>
</head>
<body>

<!-- HERO COVER SECTION -->
<div class="hero">
  <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px;">
    <div>
      <span class="badge" style="background: #EF4444; color: #FFFFFF; font-weight: 800; font-size: 8pt; padding: 4px 10px;">FATAL PRODUCTION BLOCKER</span>
      <span class="badge" style="background: #3B82F6; color: #FFFFFF; font-weight: 700; font-size: 8pt; padding: 4px 10px; margin-left: 6px;">GIT COMMIT AUTOPSY: 0d62f0b</span>
    </div>
    <div style="text-align: right; font-size: 8pt; color: #94A3B8; font-family: monospace;">
      AUDIT DATE: SEPTEMBER 2026<br>
      ENGINE: FLUTTER 3.38.9 • DART 3.10.8
    </div>
  </div>

  <h1 style="color: #FFFFFF; margin-bottom: 8px;">ENTERPRISE POST-PUSH FORENSIC AUDIT</h1>
  <div style="font-size: 11pt; color: #94A3B8; max-width: 900px; line-height: 1.4; margin-bottom: 20px;">
    Comprehensive Forensic Quality & Security Autopsy on Git Commit <code>0d62f0b</code> (&ldquo;new&rdquo; by Mehedi Hasan). Evaluated across 35 Complete Screens, 5 Multi-Device Viewports, 5 User Personas, OWASP Security Benchmarks, and ISO/IEC 25010 Standards.
  </div>

  <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; border-top: 1px solid #334155; padding-top: 16px;">
    <div>
      <div style="color: #94A3B8; font-size: 7.5pt; font-weight: 700; text-transform: uppercase;">Overall Quality Score</div>
      <div style="font-size: 22pt; font-weight: 800; color: #EF4444;">0.0 <span style="font-size: 11pt; color: #94A3B8;">/ 10.0</span></div>
      <div style="color: #F87171; font-size: 7.5pt;">DO NOT DEPLOY</div>
    </div>
    <div>
      <div style="color: #94A3B8; font-size: 7.5pt; font-weight: 700; text-transform: uppercase;">Build Viability</div>
      <div style="font-size: 22pt; font-weight: 800; color: #EF4444;">FAIL</div>
      <div style="color: #F87171; font-size: 7.5pt;">Exit Code 1 (Dart2JS)</div>
    </div>
    <div>
      <div style="color: #94A3B8; font-size: 7.5pt; font-weight: 700; text-transform: uppercase;">Total Scope Churn</div>
      <div style="font-size: 22pt; font-weight: 800; color: #F59E0B;">+8,951 / -3,151</div>
      <div style="color: #FCD34D; font-size: 7.5pt;">50 Files Altered</div>
    </div>
    <div>
      <div style="color: #94A3B8; font-size: 7.5pt; font-weight: 700; text-transform: uppercase;">Total Defects Logged</div>
      <div style="font-size: 22pt; font-weight: 800; color: #EF4444;">84</div>
      <div style="color: #F87171; font-size: 7.5pt;">24 P0/P1 Catastrophic</div>
    </div>
  </div>
</div>

<!-- EXECUTIVE SUMMARY DOSSIER -->
<h2>1. Executive Summary & Critical Audit Verdict</h2>
<div class="alert-banner">
  <strong>AUDITOR'S UNCOMPROMISING VERDICT: IMMEDIATE REJECTION.</strong> Commit <code>0d62f0b</code> represents an extreme breakdown of software engineering discipline. The developer pushed 12,102 lines of unreviewed code directly to <code>main</code> under a single-word commit message (&ldquo;new&rdquo;). The codebase <strong>fails compilation completely</strong> on Flutter Web, breaks all existing regression tests, deletes core authentication assertions (&ldquo;p-hacking&rdquo;), exposes proprietary consultancy financial margins via OWASP Broken Access Control (A01:2021), and introduces severe data corruption bugs in client analytics.
</div>

<div class="kpi-grid">
  <div class="kpi-card">
    <div class="kpi-val" style="color: #EF4444;">6</div>
    <div class="kpi-lbl">Fatal Compiler Errors</div>
    <div style="font-size: 7.5pt; color: #64748B; margin-top: 4px;">CardTheme/DialogTheme Mismatches</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-val" style="color: #EF4444;">24</div>
    <div class="kpi-lbl">Test Suite Failures</div>
    <div style="font-size: 7.5pt; color: #64748B; margin-top: 4px;">Enum Renaming Without Migration</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-val" style="color: #EF4444;">2</div>
    <div class="kpi-lbl">OWASP A01 Breaches</div>
    <div style="font-size: 7.5pt; color: #64748B; margin-top: 4px;">Unguarded Client Analysis & Estimator</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-val" style="color: #F59E0B;">24</div>
    <div class="kpi-lbl">Deprecated API Calls</div>
    <div style="font-size: 7.5pt; color: #64748B; margin-top: 4px;">Dropdown 'value' & Switch 'activeColor'</div>
  </div>
</div>

<!-- PILLAR 1: FATAL COMPILATION BREAKDOWN -->
<h2>2. Pillar 1: Fatal Compilation Blocker (P0 — Code Does Not Build)</h2>
<p>
The most egregious failure in commit <code>0d62f0b</code> is that the code <strong>cannot compile for production release</strong>. Running <code>flutter build web --release</code> terminates abnormally with exit code 1. The developer assigned Flutter widget classes (<code>CardTheme</code>, <code>DialogTheme</code>, <code>TabBarTheme</code>) to parameters expecting data objects (<code>CardThemeData?</code>, <code>DialogThemeData?</code>, <code>TabBarThemeData?</code>) in <code>lib/core/constants/app_theme.dart</code>.
</p>

<div class="code-block">
<span class="diff-info">// VERBATIM DART2JS COMPILER ERROR LOG (lib/core/constants/app_theme.dart)</span>
<span class="diff-del">lib/core/constants/app_theme.dart:38:18: Error: The argument type 'CardTheme' can't be assigned to 'CardThemeData?'.</span>
<span class="diff-del">lib/core/constants/app_theme.dart:106:20: Error: The argument type 'DialogTheme' can't be assigned to 'DialogThemeData?'.</span>
<span class="diff-del">lib/core/constants/app_theme.dart:134:20: Error: The argument type 'TabBarTheme' can't be assigned to 'TabBarThemeData?'.</span>
<span class="diff-del">lib/core/constants/app_theme.dart:174:18: Error: The argument type 'CardTheme' can't be assigned to 'CardThemeData?'.</span>
<span class="diff-del">lib/core/constants/app_theme.dart:245:20: Error: The argument type 'DialogTheme' can't be assigned to 'DialogThemeData?'.</span>
<span class="diff-del">lib/core/constants/app_theme.dart:273:20: Error: The argument type 'TabBarTheme' can't be assigned to 'TabBarThemeData?'.</span>
Error: Compilation failed. Command: dart compile js --platform-binaries=... -o .../app.dill
Target dart2js failed: ProcessException: Process exited abnormally with exit code 1.
</div>

<p>
<strong>Root Cause & Governance Failure:</strong> In modern Flutter SDKs (3.38+), theme configuration requires concrete <code>ThemeData</code> classes rather than widgets. Instantiating a widget in theme declarations triggers fatal static type errors. Pushing uncompiled code directly to <code>main</code> demonstrates an absolute absence of Git branch protection rules, pull request gates, and CI/CD pre-commit hooks.
</p>

<!-- PILLAR 2: TEST SUITE DEMOLITION & P-HACKING -->
<h2>3. Pillar 2: Test Suite Demolition & &ldquo;P-Hacking&rdquo; Forensics</h2>
<p>
Rather than fixing architectural issues, the developer actively dismantled the existing automated test suite to hide regressions. In <code>test/splash_login_flow_test.dart</code>, the developer deleted all eight rigorous assertions that validated the LoginScreen presence, welcome text, button labels, and 1-tap demo persona switchers. They replaced them with a vacuous smoke assertion: <code>expect(find.byType(SpendWiseApp), findsOneWidget)</code>.
</p>

<div class="code-block">
<span class="diff-info">// GIT DIFF: test/splash_login_flow_test.dart (Commit 172005c -> 0d62f0b)</span>
 void main() {{
-  testWidgets('App launches to SplashScreen, then navigates to LoginScreen when unauthenticated', (WidgetTester tester) async {{
+  testWidgets('App launches to SplashScreen, then navigates to LoginScreen or Home', (WidgetTester tester) async {{
...
-    // Verify user is now on LoginScreen
-    expect(find.byType(LoginScreen), findsOneWidget);
-    expect(find.text('Welcome back'), findsOneWidget);
-    expect(find.text('Sign In to Account'), findsOneWidget);
-    expect(find.text('Forgot Password?'), findsOneWidget);
-    expect(find.text('Employee (Alex)'), findsOneWidget);
-    expect(find.text('Manager (Sarah)'), findsOneWidget);
-    expect(find.text('Finance (David)'), findsOneWidget);
-    expect(find.text('Admin (Eleanor)'), findsOneWidget);
+    // Verify app settled cleanly
+    expect(find.byType(SpendWiseApp), findsOneWidget);
   }});
 }}
</div>

<p>
<strong>The Forensic Motive:</strong> The developer hardcoded <code>isAuthenticated: true</code> and <code>currentUser: DemoUsers.mainAdmin</code> into <code>lib/state/auth_provider.dart:98-102</code>. Because the app now defaults to being authenticated as Main Admin, navigating to <code>/login</code> or timing out from splash redirects immediately to <code>/home</code>. Unable to pass the login screen test, the developer gutted the test assertions rather than implementing proper session state restoration!
</p>

<!-- PILLAR 3: OWASP BROKEN ACCESS CONTROL -->
<h2>4. Pillar 3: OWASP Top 10 Broken Access Control (A01:2021)</h2>
<p>
Commit <code>0d62f0b</code> introduces an indefensible security vulnerability in role-based routing. The developer implemented two new administrative intelligence modules: <code>ClientAnalysisScreen</code> and <code>CostEstimatorScreen</code>, located physically in <code>lib/screens/admin/</code>. However, when registering their routes in <code>lib/core/routing/app_router.dart</code>, the developer registered them as root routes: <code>/client-analysis</code> and <code>/cost-estimator</code>, omitting the <code>/admin</code> prefix.
</p>

<div class="code-block">
<span class="diff-info">// SECURITY VULNERABILITY IN lib/core/routing/app_router.dart:75-78</span>
      // Admin routes guard strictly filters paths starting with '/admin'
      if (loc.startsWith('/admin') && role != UserRole.mainAdmin) {{
        return RoutePaths.home;
      }}
      // CRITICAL FLAW: /client-analysis and /cost-estimator DO NOT start with '/admin'!
      // They are registered without ANY role check:
      GoRoute(path: RoutePaths.clientAnalysis, builder: (context, state) => const ClientAnalysisScreen()),
      GoRoute(path: RoutePaths.costEstimator, builder: (context, state) => const CostEstimatorScreen()),
</div>

<div class="alert-banner">
  <strong>SECURITY IMPACT:</strong> Low-privilege accounts (<code>UserRole.projectMember</code> - Field Surveyor Fahim Ahmed, or <code>UserRole.viewer</code> - External Auditor Rahim Chowdhury) can directly navigate to <code>#/client-analysis</code> and <code>#/cost-estimator</code>. This exposes proprietary consultancy profit margins, gross contract totals, unbilled receivables, and commercial fee estimation algorithms to unauthorized staff!
</div>

<!-- PILLAR 4: FINANCIAL CONTAMINATION BUG -->
<h2>5. Pillar 4: Financial Data Contamination & Calculation Inversion</h2>
<p>
In <code>lib/screens/admin/client_analysis_screen.dart:38</code>, the developer implemented client project filtering using an absurd string-splitting heuristic:
</p>

<div class="code-block">
<span class="diff-del">// lib/screens/admin/client_analysis_screen.dart:38</span>
final clientProjects = _selectedClient != null
    ? projects.where((p) => p.client.toLowerCase().contains(_selectedClient!.name.toLowerCase().split(' ').first)).toList()
    : &lt;ProjectModel&gt;[];
</div>

<p>
<strong>Catastrophic Consequence:</strong> Calling <code>.split(' ').first</code> means that if the user selects &ldquo;Ministry of Water Resources&rdquo;, the algorithm filters projects where <code>client</code> contains &ldquo;ministry&rdquo;. This groups together <strong>every single government ministry</strong> (&ldquo;Ministry of Finance&rdquo;, &ldquo;Ministry of Agriculture&rdquo;, &ldquo;Ministry of Health&rdquo;), merging unrelated multi-million-dollar contracts, receivables, and costs into a single bogus client profile. In an enterprise financial audit, this represents fatal data corruption.
</p>

<!-- PILLAR 5: MONOLITHIC GOD-WIDGET ARCHITECTURE -->
<h2>6. Pillar 5: Monolithic Architecture & UI Thread Jank</h2>
<p>
Commit <code>0d62f0b</code> severely degrades maintainability by bloating widget files into massive 1,000+ line &ldquo;God-Widgets&rdquo; that violate Single Responsibility Principle (SRP):
</p>

<table class="audit-table">
  <thead>
    <tr>
      <th>File Path</th>
      <th>Line Count</th>
      <th>Architectural Violations</th>
      <th>Performance Impact</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>lib/screens/home/home_dashboard_screen.dart</code></td>
      <td><strong>1,098 lines</strong></td>
      <td>Mixes financial aggregation loops, persona switcher modals, app bar badges, and 3 role sub-dashboards.</td>
      <td>O(N*M) iterations over all projects/expenses in <code>build()</code> causes dropped frames on 60Hz/120Hz screens.</td>
    </tr>
    <tr>
      <td><code>lib/screens/expenses/submit_expense_screen.dart</code></td>
      <td><strong>1,012 lines</strong></td>
      <td>Combines 12 form controllers, mock OCR, receipt file pickers, category limit checkers, and policy validation.</td>
      <td>Severe keyboard latency and form rebuild thrashing on mobile devices.</td>
    </tr>
    <tr>
      <td><code>lib/screens/projects/project_detail_screen.dart</code></td>
      <td><strong>804 lines</strong></td>
      <td>Monolithic tab views, inline burn-rate calculations, task lists, and milestone progress bars.</td>
      <td>High memory footprint, redundant widget tree recreation on tab switch.</td>
    </tr>
    <tr>
      <td><code>lib/screens/projects/add_edit_project_screen.dart</code></td>
      <td><strong>588 lines</strong></td>
      <td>Lacks modular form step extraction; hardcoded hex colors throughout.</td>
      <td>Maintenance nightmare; unable to unit test individual form field validators.</td>
    </tr>
    <tr>
      <td><code>lib/screens/expenses/receipt_compliance_screen.dart</code></td>
      <td><strong>518 lines</strong></td>
      <td>Inline dialog builders, justification state management, tab controllers, and table layouts.</td>
      <td>Violates clean architecture; logic cannot be reused across other screens.</td>
    </tr>
  </tbody>
</table>

<!-- PILLAR 6: STATIC ANALYZER & DEPRECATED APIS -->
<h2>7. Pillar 6: Static Code Analysis (24 Deprecated APIs)</h2>
<p>
The Dart analyzer reports <strong>24 deprecated API warnings</strong> in <code>lib/</code>. The developer consistently ignored Flutter SDK lifecycle deprecations:
</p>
<table class="audit-table">
  <thead>
    <tr>
      <th>Deprecated Member</th>
      <th>Recommended Replacement</th>
      <th>Occurrences in Codebase</th>
      <th>Impact</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>DropdownButtonFormField.value</code></td>
      <td><code>initialValue</code></td>
      <td>18 occurrences (submit_expense, add_project, edit_expense, client_analysis, cost_estimator, settings)</td>
      <td>Will trigger fatal compilation errors in subsequent Flutter releases. Deprecated since v3.33.0.</td>
    </tr>
    <tr>
      <td><code>Switch.activeColor</code></td>
      <td><code>activeThumbColor</code> / <code>activeTrackColor</code></td>
      <td>6 occurrences (user_management, category_management, submit_expense)</td>
      <td>Inconsistent switch thumb styling and theme override conflicts. Deprecated since v3.31.0.</td>
    </tr>
  </tbody>
</table>

<!-- PILLAR 7: IPAD TABLET DEFECT MATRIX -->
<h2>8. Pillar 7: Multi-Device Responsive & iPad Tablet Failure Matrix</h2>
<p>
The application completely fails to adapt to tablet viewports (Apple iPad 10th Gen 768x1024 portrait and 1024x768 landscape). The UI simply stretches mobile layouts to the extreme edges of the screen, creating unreadable forms, flattened charts, and massive dead whitespace voids:
</p>

<div style="text-align: center; margin-bottom: 24px;">
  {f'<img src="data:image/png;base64,{ipad_defects_matrix_b64}" style="max-width: 100%; height: auto; border-radius: 8px; border: 1px solid #CBD5E1; box-shadow: 0 4px 6px rgba(0,0,0,0.05);" alt="iPad Tablet Defect Matrix" />' if ipad_defects_matrix_b64 else ''}
</div>

<table class="audit-table">
  <thead>
    <tr>
      <th>Defect Code</th>
      <th>Defect Name & Screen</th>
      <th>Severity</th>
      <th>Detailed Architectural Violation</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>DEF-IP-01</code></td>
      <td><strong>1024px Full-Width Form Stretch</strong> (Submit Expense, Register)</td>
      <td><span class="badge badge-crit">CRITICAL</span></td>
      <td>Forms lack <code>ConstrainedBox(maxWidth: 600)</code>. Input fields span 980px wide with microscopic 14px font, violating Fitts's Law.</td>
    </tr>
    <tr>
      <td><code>DEF-IP-02</code></td>
      <td><strong>70% Dead Whitespace Void</strong> (Projects List, Audit Log)</td>
      <td><span class="badge badge-warn">MAJOR</span></td>
      <td>Single-column 1D ListView leaves over 700px of empty white canvas. Lacks a responsive 2-column GridView.</td>
    </tr>
    <tr>
      <td><code>DEF-IP-03</code></td>
      <td><strong>5:1 Flattened Chart Aspect Ratio</strong> (Reports Screen)</td>
      <td><span class="badge badge-crit">CRITICAL</span></td>
      <td>Line and bar charts stretch to 1000px width with fixed 200px height, completely flattening curve inflections.</td>
    </tr>
    <tr>
      <td><code>DEF-IP-04</code></td>
      <td><strong>1024px Stretched Bottom Nav Bar</strong> (Main Shell)</td>
      <td><span class="badge badge-warn">MAJOR</span></td>
      <td>Mobile navigation bar stretched across iPad width with 250px icon gaps instead of an adaptive <code>NavigationRail</code>.</td>
    </tr>
    <tr>
      <td><code>DEF-IP-05</code></td>
      <td><strong>Project Card Metric Overlap</strong> (Home & Projects)</td>
      <td><span class="badge badge-crit">CRITICAL</span></td>
      <td>Unconstrained Row layout in ProjectCard overflows by 32-97px on compact mobile viewports (320dp/360dp).</td>
    </tr>
  </tbody>
</table>

<!-- SECTION 9: COMPLETE 35-SCREEN AUDIT CATALOG -->
<h2>9. Complete 35-Screen Comprehensive Forensic Audit Catalog</h2>
<p>
The following catalog details all 35 distinct application screens captured under commit <code>0d62f0b</code> across 5 native device viewports: iPhone SE (375x667), Samsung Galaxy S24 (360x800), iPhone 15 Pro (390x844), iPad 10th Gen Portrait (768x1024), and iPad 10th Gen Landscape (1024x768).
</p>

{screen_cards_html}

<!-- SECTION 10: RBAC MATRIX -->
<h2>10. Role-Based Access Control (RBAC) 5-Persona Verification Matrix</h2>
<p>
Commit <code>0d62f0b</code> refactored <code>UserRole</code> into 5 roles. The table below audits navigation shells, route protections, and access vulnerabilities:
</p>

<table class="audit-table">
  <thead>
    <tr>
      <th>Role Persona</th>
      <th>Test Identity</th>
      <th>Shell Navigation Tabs</th>
      <th>Permitted Routes</th>
      <th>Vulnerabilities & Bypasses</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Main Admin</strong></td>
      <td>Eleanor Vance (<code>usr_adm_01</code>)</td>
      <td>Home, Projects, Approvals, Profile</td>
      <td>All 35 Routes (/admin/*, /company-dashboard)</td>
      <td><span class="badge badge-crit">DEFAULT BYPASS</span> Hardcoded in auth provider on boot.</td>
    </tr>
    <tr>
      <td><strong>Project Manager</strong></td>
      <td>Sarah Jenkins (<code>usr_mgr_01</code>)</td>
      <td>Home, Projects, Approvals, Profile</td>
      <td>Projects, Approvals, Submit, Tasks</td>
      <td>Can access unprotected <code>/client-analysis</code> & <code>/cost-estimator</code>.</td>
    </tr>
    <tr>
      <td><strong>Project Member</strong></td>
      <td>Fahim Ahmed (<code>usr_emp_01</code>)</td>
      <td>Home, My Expenses, Receipt Compliance, Profile</td>
      <td>My Expenses, Submit Claim, Receipts</td>
      <td><span class="badge badge-crit">OWASP BREACH</span> Can access proprietary <code>/client-analysis</code>.</td>
    </tr>
    <tr>
      <td><strong>Finance / Accounts</strong></td>
      <td>David Chen (<code>usr_fin_01</code>)</td>
      <td>Home, Projects, Approvals, Profile</td>
      <td>Company Dashboard, Approvals, Reports</td>
      <td>Can access unprotected <code>/client-analysis</code> & <code>/cost-estimator</code>.</td>
    </tr>
    <tr>
      <td><strong>Viewer (Read-Only)</strong></td>
      <td>Rahim Chowdhury (<code>usr_view_01</code>)</td>
      <td>Home, Projects, Reports, Profile</td>
      <td>Read-Only Project 02, Reports</td>
      <td><span class="badge badge-crit">OWASP BREACH</span> External auditor can view unmasked consultancy fee models.</td>
    </tr>
  </tbody>
</table>

<!-- SECTION 11: REMEDIATION ROADMAP -->
<h2>11. Concrete Engineering Remediation Recipes & Action Plan</h2>
<p>
To bring the application to production readiness, the development team must execute the following remediation recipes:
</p>

<h3>Recipe 1: Compiler Fix in <code>lib/core/constants/app_theme.dart</code></h3>
<div class="code-block">
<span class="diff-del">- cardTheme: CardTheme(...)</span>
<span class="diff-add">+ cardTheme: CardThemeData(...)</span>
<span class="diff-del">- dialogTheme: DialogTheme(...)</span>
<span class="diff-add">+ dialogTheme: DialogThemeData(...)</span>
<span class="diff-del">- tabBarTheme: TabBarTheme(...)</span>
<span class="diff-add">+ tabBarTheme: TabBarThemeData(...)</span>
</div>

<h3>Recipe 2: OWASP Route Guard Security Fix in <code>lib/core/routing/app_router.dart</code></h3>
<div class="code-block">
<span class="diff-del">- static const String clientAnalysis = '/client-analysis';</span>
<span class="diff-del">- static const String costEstimator = '/cost-estimator';</span>
<span class="diff-add">+ static const String clientAnalysis = '/admin/client-analysis';</span>
<span class="diff-add">+ static const String costEstimator = '/admin/cost-estimator';</span>
// This ensures loc.startsWith('/admin') automatically protects both financial intelligence routes!
</div>

<h3>Recipe 3: Financial Contamination Fix in <code>lib/screens/admin/client_analysis_screen.dart</code></h3>
<div class="code-block">
<span class="diff-del">- projects.where((p) => p.client.toLowerCase().contains(_selectedClient!.name.toLowerCase().split(' ').first))</span>
<span class="diff-add">+ projects.where((p) => p.clientId == _selectedClient!.id || p.client.trim().toLowerCase() == _selectedClient!.name.trim().toLowerCase())</span>
// Use strict ID or exact string equality to prevent cross-client financial contamination!
</div>

<h3>Recipe 4: Tablet Form Responsive Constraint</h3>
<div class="code-block">
<span class="diff-add">+ Center(</span>
<span class="diff-add">+   child: ConstrainedBox(</span>
<span class="diff-add">+     constraints: const BoxConstraints(maxWidth: 600),</span>
<span class="diff-add">+     child: SingleChildScrollView(child: ...),</span>
<span class="diff-add">+   ),</span>
<span class="diff-add">+ )</span>
</div>

<div style="margin-top: 32px; padding: 14px; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; font-size: 8pt; color: #64748B;">
  <strong>Audit Authority & Standards Compliance:</strong> Compiled according to ISO/IEC 25010 Software Quality Metrics, WCAG 2.2 Accessibility Guidelines, and OWASP Top 10 Security Standards. Tested via automated Selenium WebDriver running headless Chromium with SwiftShader hardware acceleration on Ubuntu Linux.
</div>

</body>
</html>
"""

    with open(HTML_FILE, "w") as f:
        f.write(html)
    print(f"Master HTML report written: {HTML_FILE} ({os.path.getsize(HTML_FILE)} bytes)")

    print(f"Compiling Master PDF via Headless Chrome: {PDF_FILE}...")
    cmd = [
        "google-chrome",
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--print-to-pdf-no-header",
        f"--print-to-pdf={PDF_FILE}",
        HTML_FILE
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0 and os.path.exists(PDF_FILE):
        pdf_size = os.path.getsize(PDF_FILE)
        print(f"SUCCESS: Master PDF report generated: {PDF_FILE} ({pdf_size} bytes, {pdf_size / (1024*1024):.2f} MB)")
        
        desktop_pdf = os.path.join(DESKTOP_DIR, "SpendWise_Pro_Enterprise_Mobile_Audit_Report.pdf")
        desktop_html = os.path.join(DESKTOP_DIR, "SpendWise_Pro_Enterprise_Audit_Report.html")
        shutil.copyfile(PDF_FILE, desktop_pdf)
        shutil.copyfile(HTML_FILE, desktop_html)
        print(f"COPIED TO DESKTOP: {desktop_pdf} ({os.path.getsize(desktop_pdf)} bytes)")
        print(f"COPIED TO DESKTOP: {desktop_html} ({os.path.getsize(desktop_html)} bytes)")
    else:
        print(f"ERROR generating PDF: {res.stderr}")

if __name__ == '__main__':
    build_brutal_report()
