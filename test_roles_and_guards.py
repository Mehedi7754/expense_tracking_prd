from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
import time
import os
import json

OUTPUT_DIR = '/home/alvee/.gemini/antigravity/brain/0a439ff8-c4a7-43bd-b5dc-a2f587aeeffe/screenshots'

opts = Options()
opts.add_argument('--headless=new')
opts.add_argument('--no-sandbox')
opts.add_argument('--enable-unsafe-swiftshader')
opts.add_argument('--window-size=390,844')

driver = webdriver.Chrome(options=opts)
driver.get('http://localhost:8085/#/home')
time.sleep(3)

print("Testing direct navigation to sensitive routes as default user:")
test_routes = [
    {"route": "/admin/users", "label": "Admin Users Directory", "expected": "Admin Only (Blocked for Non-Admin)"},
    {"route": "/admin/categories", "label": "Admin Categories", "expected": "Admin Only (Blocked for Non-Admin)"},
    {"route": "/company-dashboard", "label": "Company Financial Dashboard", "expected": "Finance/Admin Only"},
    {"route": "/projects/new", "label": "Add Project Form", "expected": "Admin/Manager/Finance Only"},
    {"route": "/client-analysis", "label": "Client Profitability Analysis", "expected": "CRITICAL: OWASP A01 Vulnerability (UNPROTECTED!)"},
    {"route": "/cost-estimator", "label": "Project Cost Estimator", "expected": "CRITICAL: OWASP A01 Vulnerability (UNPROTECTED!)"},
    {"route": "/receipt-compliance", "label": "Receipt Compliance Audit", "expected": "All Roles"}
]

rbac_findings = []
for tr in test_routes:
    driver.get(f"http://localhost:8085/#{tr['route']}")
    time.sleep(1.0)
    current_url = driver.current_url
    sc_name = tr['route'].replace('/', '_').replace('-', '_')
    out_p = f"{OUTPUT_DIR}/rbac_test{sc_name}.png"
    driver.save_screenshot(out_p)
    
    blocked = '#/home' in current_url and tr['route'] != '/home'
    rbac_findings.append({
        "route": tr['route'],
        "label": tr['label'],
        "expected": tr['expected'],
        "current_url": current_url,
        "blocked": blocked,
        "screenshot": out_p
    })
    print(f"Route: {tr['route']} -> URL: {current_url} | Blocked: {blocked}")

with open(f"{OUTPUT_DIR}/rbac_audit_results.json", "w") as f:
    json.dump(rbac_findings, f, indent=2)

print("RBAC audit finished!")
driver.quit()
