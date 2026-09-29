import os
import time
from PIL import Image, ImageDraw, ImageFont
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'
os.makedirs(OUTPUT_DIR, exist_ok=True)

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

opts = Options()
opts.add_argument('--headless=new')
opts.add_argument('--no-sandbox')
opts.add_argument('--enable-unsafe-swiftshader')

driver = webdriver.Chrome(options=opts)

# Warmup
driver.get('http://localhost:8085/#/home')
time.sleep(3)

print("Capturing 35 screens on Mobile (390x844)...")
driver.set_window_size(390, 844)
for s in SCREENS:
    driver.get(f"http://localhost:8085/#{s['route']}")
    time.sleep(0.8)
    driver.save_screenshot(f"{OUTPUT_DIR}/recapture_mobile_{s['id']}.png")
    print(f"  Captured Mobile: {s['id']}")

print("\nCapturing 35 screens on iPad 10th (1024x768)...")
driver.set_window_size(1024, 768)
for s in SCREENS:
    driver.get(f"http://localhost:8085/#{s['route']}")
    time.sleep(0.8)
    driver.save_screenshot(f"{OUTPUT_DIR}/recapture_ipad_{s['id']}.png")
    print(f"  Captured iPad: {s['id']}")

driver.quit()
print("\nAll 70 targeted captures complete!")
