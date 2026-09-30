import os
import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'
os.makedirs(OUTPUT_DIR, exist_ok=True)

DEVICES = [
    {"id": "iphone_se", "name": "iPhone SE", "width": 375, "height": 667, "desc": "Compact (16:9)"},
    {"id": "samsung_galaxy", "name": "Samsung Galaxy", "width": 360, "height": 800, "desc": "Tall Android (20:9)"},
    {"id": "iphone_15_pro_max", "name": "iPhone 15 Pro Max", "width": 430, "height": 932, "desc": "Flagship (19.5:9)"},
    {"id": "ipad_10th_gen", "name": "iPad 10th Gen", "width": 1024, "height": 768, "desc": "Tablet Landscape (4:3)"},
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

def run_captures():
    opts = Options()
    opts.add_argument('--headless=new')
    opts.add_argument('--no-sandbox')
    opts.add_argument('--enable-unsafe-swiftshader')
    
    driver = webdriver.Chrome(options=opts)
    
    # Warmup
    driver.get('http://localhost:8085/#/home')
    time.sleep(3)
    
    for dev in DEVICES:
        dev_id = dev["id"]
        w, h = dev["width"], dev["height"]
        print(f"\n==========================================")
        print(f"CAPTURING 35 SCREENS FOR: {dev['name']} ({w}x{h} - {dev['desc']})")
        print(f"==========================================")
        driver.set_window_size(w, h)
        time.sleep(1.0)
        
        for idx, s in enumerate(SCREENS):
            sc_id = s["id"]
            out_file = f"{OUTPUT_DIR}/device4_{dev_id}_{sc_id}.png"
            
            driver.get(f"http://localhost:8085/#{s['route']}")
            time.sleep(0.7)
            driver.save_screenshot(out_file)
            print(f"  [{idx+1}/35] Captured {dev['name']}: {s['name']} ({os.path.getsize(out_file)} bytes)")
            
    driver.quit()
    print("\nAll 140 4-device screenshots captured successfully!")

if __name__ == '__main__':
    run_captures()
