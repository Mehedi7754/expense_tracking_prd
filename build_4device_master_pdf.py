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
DOWNLOADS_DIR = '/home/alvee/Downloads'

def get_base64_image(file_path):
    if not os.path.exists(file_path):
        return ""
    with open(file_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

from generate_brutal_postpush_report import SCREENS_DATA

def build_pdf_report():
    print("Compiling Comprehensive 4-Device Enterprise Audit Dossier with ALL 35 Screens Across 4 Viewports...")

    ipad_defects_matrix_b64 = get_base64_image(f"{SCREENSHOTS_DIR}/matrix_postpush_ipad_defects.png")

    screen_sections_html = ""
    for s in SCREENS_DATA:
        sc_id = s["id"]
        marked_img_path = f"{SCREENSHOTS_DIR}/marked_4device_screen_{sc_id}.png"
        if not os.path.exists(marked_img_path):
            marked_img_path = f"{SCREENSHOTS_DIR}/marked_screen_{sc_id}.png"
            
        marked_b64 = get_base64_image(marked_img_path)

        defects_rows = ""
        for d in s["defects"]:
            badge_class = "badge-pass" if d["type"] == "PASS" else ("badge-crit" if d["type"] in ["CRITICAL", "SECURITY", "ARCH", "DEFECT", "OVERFLOW"] else "badge-warn")
            defects_rows += f"""
            <tr style="border-bottom: 1px solid #F1F5F9;">
              <td style="padding: 6px 10px; width: 190px;"><span class="badge {badge_class}">{d['badge']}</span></td>
              <td style="padding: 6px 10px; color: #1E293B; font-size: 8.5pt; font-weight: 500;">{d['detail']}</td>
            </tr>
            """

        screen_sections_html += f"""
        <div class="screen-page-block">
          <!-- Screen Header -->
          <div style="background: #0F172A; color: #FFFFFF; padding: 10px 16px; border-radius: 8px 8px 0 0; display: flex; justify-content: space-between; align-items: center;">
            <div>
              <span style="background: #3B82F6; color: #FFFFFF; font-weight: 800; font-size: 8pt; padding: 3px 8px; border-radius: 4px; margin-right: 8px;">SCREEN #{s['num']}</span>
              <strong style="font-size: 11pt; color: #FFFFFF;">{s['name']}</strong>
              <span style="font-family: monospace; font-size: 8pt; color: #94A3B8; margin-left: 10px;">#{s['route']}</span>
            </div>
            <div>
              <span class="badge" style="background: {s['status_color']}; color: #FFFFFF; font-weight: 800; font-size: 7.5pt; padding: 3px 8px;">{s['status']}</span>
              <span style="background: rgba(255,255,255,0.15); color: #FFFFFF; font-weight: 800; font-size: 7.5pt; padding: 3px 8px; border-radius: 4px; margin-left: 6px;">Score: {s['score']}</span>
            </div>
          </div>

          <!-- Metadata Strip -->
          <div style="padding: 6px 14px; background: #F8FAFC; border: 1px solid #E2E8F0; border-top: none; font-size: 8pt; color: #475569; display: grid; grid-template-columns: 1fr 1.3fr 2fr; gap: 8px;">
            <div><strong>Module:</strong> {s['category']}</div>
            <div><strong>Intended Persona:</strong> {s['persona']}</div>
            <div><strong>Heuristics:</strong> {s['heuristics']}</div>
          </div>

          <!-- Description -->
          <div style="padding: 6px 14px; font-size: 8pt; color: #334155; line-height: 1.4; background: #FFFFFF; border: 1px solid #E2E8F0; border-top: none;">
            {s['desc']}
          </div>

          <!-- 4-Device Visual Comparison Card -->
          <div style="padding: 8px; background: #0F172A; text-align: center; border: 1px solid #334155; border-top: none;">
            {f'<img src="data:image/png;base64,{marked_b64}" style="width: 100%; max-height: 480px; object-fit: contain; border-radius: 6px;" alt="{s["name"]} 4-Device Marked Visual" />' if marked_b64 else '<div style="color: #94A3B8; padding: 40px;">[Visual Missing]</div>'}
          </div>

          <!-- Findings Table -->
          <div style="border: 1px solid #E2E8F0; border-top: none; border-radius: 0 0 8px 8px; overflow: hidden; background: #FFFFFF;">
            <div style="background: #F8FAFC; padding: 6px 12px; font-size: 8pt; font-weight: 800; color: #0F172A; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #E2E8F0;">Forensic Findings & Technical Violations across 4 Device Viewports:</div>
            <table style="width: 100%; border-collapse: collapse;">
              <tbody>
                {defects_rows}
              </tbody>
            </table>
          </div>
        </div>
        """

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SpendWise Pro (PFIS Financials) — 4-Device Enterprise Forensic Mobile & Tablet Quality Audit</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&display=swap');

  @page {{
    size: A4 portrait;
    margin: 10mm 10mm 10mm 10mm;
    @bottom-right {{
      content: "Page " counter(page);
      font-family: 'Plus Jakarta Sans', sans-serif;
      font-size: 8pt;
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
    font-size: 8.5pt;
    line-height: 1.45;
  }}

  .page-break {{
    page-break-after: always;
    break-after: page;
  }}

  .screen-page-block {{
    page-break-after: always;
    break-after: page;
    margin-bottom: 0;
  }}

  h1, h2, h3, h4 {{
    color: #0F172A;
    font-weight: 800;
    margin-top: 0;
    letter-spacing: -0.4px;
  }}

  h1 {{ font-size: 20pt; line-height: 1.2; }}
  h2 {{ font-size: 12pt; border-bottom: 2px solid #0F172A; padding-bottom: 4px; margin-top: 18px; margin-bottom: 10px; page-break-after: avoid; }}
  h3 {{ font-size: 10pt; color: #1E293B; margin-top: 12px; margin-bottom: 5px; page-break-after: avoid; }}

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
    padding: 24px 20px;
    border-radius: 10px;
    margin-bottom: 18px;
    border: 1px solid #334155;
  }}

  .kpi-grid {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    margin-bottom: 16px;
  }}

  .kpi-card {{
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 6px;
    padding: 8px 10px;
    text-align: center;
  }}

  .kpi-val {{
    font-size: 16pt;
    font-weight: 800;
    line-height: 1.1;
    margin-bottom: 2px;
  }}

  .kpi-lbl {{
    font-size: 6.5pt;
    font-weight: 700;
    text-transform: uppercase;
    color: #64748B;
    letter-spacing: 0.5px;
  }}

  table.audit-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 8pt;
    margin-bottom: 16px;
    background: #FFFFFF;
  }}

  table.audit-table th {{
    background: #0F172A;
    color: #FFFFFF;
    text-align: left;
    padding: 6px 8px;
    font-weight: 700;
    font-size: 7.5pt;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }}

  table.audit-table td {{
    padding: 6px 8px;
    border-bottom: 1px solid #E2E8F0;
    vertical-align: top;
  }}

  table.audit-table tr:nth-child(even) td {{
    background: #F8FAFC;
  }}

  .code-block {{
    background: #0F172A;
    color: #F8FAFC;
    padding: 8px 12px;
    border-radius: 6px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 7.2pt;
    line-height: 1.4;
    overflow-x: auto;
    margin-bottom: 12px;
    border: 1px solid #334155;
  }}

  .diff-del {{ color: #F87171; background: rgba(239, 68, 68, 0.15); display: block; }}
  .diff-add {{ color: #4ADE80; background: rgba(34, 197, 94, 0.15); display: block; }}
  .diff-info {{ color: #94A3B8; font-style: italic; }}

  .alert-banner {{
    border-left: 4px solid #EF4444;
    background: #FEF2F2;
    padding: 10px 14px;
    border-radius: 0 6px 6px 0;
    margin-bottom: 14px;
  }}
</style>
</head>
<body>

  <!-- PAGE 1: COVER & EXECUTIVE SUMMARY -->
  <div class="hero">
    <div style="display: flex; justify-content: space-between; align-items: flex-start;">
      <div>
        <span class="badge" style="background: #EF4444; color: #FFFFFF; margin-bottom: 8px;">P0 PRODUCTION CRITICAL AUDIT</span>
        <h1 style="color: #FFFFFF; margin-bottom: 4px;">SpendWise Pro (PFIS Financials)</h1>
        <p style="color: #94A3B8; font-size: 9pt; margin: 0;">Comprehensive 4-Device Forensic Mobile & Tablet Quality Audit Dossier</p>
      </div>
      <div style="text-align: right; font-family: monospace; font-size: 7.5pt; color: #94A3B8;">
        <div>COMMIT: <strong style="color: #F8FAFC;">0d62f0b</strong> ("new")</div>
        <div>AUTHOR: Mehedi Hasan</div>
        <div>DATE: Sep 25, 2026</div>
        <div>DEVICE COUNT: 4 Active Viewports</div>
      </div>
    </div>
  </div>

  <div class="kpi-grid">
    <div class="kpi-card">
      <div class="kpi-val" style="color: #EF4444;">P0 CRASH</div>
      <div class="kpi-lbl">Production Build Status</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #3B82F6;">35 Screens</div>
      <div class="kpi-lbl">Full Viewport Audit</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #8B5CF6;">4 Devices</div>
      <div class="kpi-lbl">SE / S24 / 15PM / iPad</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #DC2626;">OWASP A01</div>
      <div class="kpi-lbl">Broken Access Control</div>
    </div>
  </div>

  <h2>1. Executive Summary & Audit Mandate</h2>
  <p>
    This forensic audit report evaluates commit <code>0d62f0b3b90f7f7d943286b8a04131f501848e8f</code> across <strong>4 distinct hardware device profiles</strong>:
    <strong>iPhone SE</strong> (375x667, 16:9), <strong>Samsung Galaxy</strong> (360x800, 20:9), <strong>iPhone 15 Pro Max</strong> (430x932, 19.5:9), and <strong>iPad 10th Gen</strong> (1024x768, 4:3).
    A fatal compilation defect in <code>lib/core/constants/app_theme.dart</code> completely broke the release build pipeline. Furthermore, automated test coverage was gutted ("p-hacked") to conceal a hardcoded authentication bypass, while newly introduced modules suffer from OWASP Top 10 access control breaches, cross-client financial calculation contamination, and extreme 1024px tablet blowout anti-patterns.
  </p>

  <div class="alert-banner">
    <strong style="color: #991B1B; font-size: 8.5pt;">VERDICT: REJECT RELEASE CANDIDATE (CRITICAL RISK)</strong><br>
    <span style="color: #7F1D1D; font-size: 8pt;">
      Branch <code>main</code> at commit <code>0d62f0b</code> cannot compile for production release. The app hardcodes administrative privileges on boot, exposes proprietary margin data without authorization guards, and renders with severe layout distortion across multi-device viewports.
    </span>
  </div>

  <h2>2. 4-Device Hardware Profile Comparison Matrix</h2>
  <table class="audit-table">
    <thead>
      <tr>
        <th>Device Profile</th>
        <th>Viewport (px)</th>
        <th>Aspect Ratio</th>
        <th>Form Factor Category</th>
        <th>Primary Failure Modes & Violations</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>iPhone SE</strong></td>
        <td><code>375 x 667</code></td>
        <td>16:9 Compact</td>
        <td>Compact iOS Handheld</td>
        <td>Horizontal flex overflow (54px on login persona row), touch targets &lt; 48dp (20dp forgot password, 22dp trash icons).</td>
      </tr>
      <tr>
        <td><strong>Samsung Galaxy</strong></td>
        <td><code>360 x 800</code></td>
        <td>20:9 Tall</td>
        <td>Standard Android Viewport</td>
        <td>Narrow column clipping, floating action button overlap with list cards, memory leaks in modal text controllers.</td>
      </tr>
      <tr>
        <td><strong>iPhone 15 Pro Max</strong></td>
        <td><code>430 x 932</code></td>
        <td>19.5:9 Flagship</td>
        <td>Large Premium Handheld</td>
        <td>Unguarded admin routes directly accessible, unconstrained margins, bottom navigation thumb-reach ergonomics.</td>
      </tr>
      <tr>
        <td><strong>iPad 10th Gen</strong></td>
        <td><code>1024 x 768</code></td>
        <td>4:3 Landscape</td>
        <td>Enterprise Tablet Viewport</td>
        <td>1024px unconstrained form fields (980px wide), 70% dead whitespace voids in 1D ListViews, 5:1 squashed trend charts, stretched bottom bar.</td>
      </tr>
    </tbody>
  </table>

  <div class="page-break"></div>

  <!-- PAGE 2: FORENSIC INVESTIGATION & CODE VIOLATIONS -->
  <h2>3. Pillar 1: Fatal Production Compiler Blocker</h2>
  <p>
    The developer attempted to update component themes in <code>lib/core/constants/app_theme.dart</code>. Instead of instantiating <code>ThemeData</code> classes, they instantiated <strong>Widget classes</strong>, triggering fatal type mismatches:
  </p>
  <div class="code-block">
<span class="diff-del">- cardTheme: const CardTheme(elevation: 0, margin: EdgeInsets.zero),</span>
<span class="diff-add">+ cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),</span>
<span class="diff-del">- dialogTheme: const DialogTheme(shape: RoundedRectangleBorder(...)),</span>
<span class="diff-add">+ dialogTheme: const DialogThemeData(shape: RoundedRectangleBorder(...)),</span>
<span class="diff-del">- tabBarTheme: const TabBarTheme(indicatorSize: TabBarIndicatorSize.tab),</span>
<span class="diff-add">+ tabBarTheme: const TabBarThemeData(indicatorSize: TabBarIndicatorSize.tab),</span>
<span class="diff-info">// Triggered across 6 distinct blocks in both light and dark theme definitions</span>
  </div>

  <h2>4. Pillar 2: Test Demolition ("P-Hacking") & Hardcoded Auth Bypass</h2>
  <p>
    In <code>test/splash_login_flow_test.dart</code>, the developer deleted all 8 functional assertions validating forms, inputs, and persona pills. The test was replaced with a hollow <code>find.byType(SpendWiseApp)</code> assertion, accompanied by hardcoded root authorization in <code>lib/state/auth_provider.dart:98-102</code>:
  </p>
  <div class="code-block">
<span class="diff-info">// lib/state/auth_provider.dart:98-102 (Boot initialization backdoor)</span>
_isAuthenticated = true;
_currentUser = DemoUsers.mainAdmin; // FORCED ROOT ON BOOT
  </div>

  <h2>5. Pillar 3: OWASP Top 10 Broken Access Control (A01:2021)</h2>
  <p>
    In <code>lib/core/routing/app_router.dart</code>, the developer registered new administrative modules without the <code>/admin</code> prefix:
  </p>
  <div class="code-block">
<span class="diff-del">- static const String clientAnalysis = '/client-analysis';</span>
<span class="diff-add">+ static const String clientAnalysis = '/admin/client-analysis';</span>
<span class="diff-del">- static const String costEstimator = '/cost-estimator';</span>
<span class="diff-add">+ static const String costEstimator = '/admin/cost-estimator';</span>
<span class="diff-info">// Route guard checks: if (loc.startsWith('/admin') && role != UserRole.mainAdmin) return RoutePaths.home;</span>
  </div>
  <p>
    Because the routes omit <code>/admin</code>, external auditors (<code>viewer</code>) and field workers (<code>projectMember</code>) can navigate directly to inspect corporate margins.
  </p>

  <h2>6. Pillar 4: Financial Calculation Contamination Bug</h2>
  <p>
    In <code>lib/screens/admin/client_analysis_screen.dart:38</code>, client matching uses substring matching on the first word:
  </p>
  <div class="code-block">
<span class="diff-del">projects.where((p) => p.client.toLowerCase().contains(_selectedClient!.name.toLowerCase().split(' ').first))</span>
<span class="diff-add">projects.where((p) => p.clientId == _selectedClient!.id || p.client.trim().toLowerCase() == _selectedClient!.name.trim().toLowerCase())</span>
  </div>
  <p>
    Splitting on space and taking the first token causes "Ministry of Water Resources" to match "Ministry of Finance", "Ministry of Health", and "Ministry of Education", corrupting portfolio aggregations.
  </p>

  <h2>7. Pillar 5: Transient Memory Leak Pathology</h2>
  <p>
    In <code>receipt_compliance_screen.dart</code>, <code>category_management_screen.dart</code>, and <code>profile_screen.dart</code>, modal dialogs instantiate <code>TextEditingController</code> instances within closures and never invoke <code>dispose()</code>, leaving detached event listeners active in the engine heap.
  </p>

  <h2>8. Pillar 6: Static Analysis Deprecations (24 Warnings)</h2>
  <p>
    <code>flutter analyze</code> reports 24 deprecations: 18x <code>DropdownButtonFormField.value</code> (must be <code>initialValue</code>) and 6x <code>Switch.activeColor</code> (must be <code>activeThumbColor</code>/<code>activeTrackColor</code>).
  </p>

  <div class="page-break"></div>

  <!-- PAGE 3: IPAD DEFECT MATRIX -->
  <h2>9. Multi-Device Responsive & Tablet Failure Matrix</h2>
  <p>
    The application completely fails to adapt to tablet viewports (iPad 10th Gen 1024x768 landscape) and compact handhelds (iPhone SE 375x667):
  </p>
  <div style="text-align: center; margin-top: 10px;">
    {f'<img src="data:image/png;base64,{ipad_defects_matrix_b64}" style="max-width: 100%; height: auto; border-radius: 6px; border: 1px solid #CBD5E1;" alt="iPad Tablet Defect Matrix" />' if ipad_defects_matrix_b64 else ''}
  </div>

  <div class="page-break"></div>

  <!-- SECTION: 35 SCREENS WITH 4-DEVICE ANNOTATED CARDS -->
  <div style="background: #0F172A; color: #FFFFFF; padding: 14px 18px; border-radius: 8px; margin-bottom: 20px;">
    <h2 style="color: #FFFFFF; border-bottom: none; margin: 0 0 6px 0;">SECTION 10: COMPLETE 35-SCREEN 4-DEVICE AUDIT CATALOG</h2>
    <p style="color: #94A3B8; margin: 0; font-size: 8.5pt;">
      Exhaustive screen-by-screen visual inspection displaying side-by-side comparison across <strong>iPhone SE</strong> (375x667), <strong>Samsung Galaxy</strong> (360x800), <strong>iPhone 15 Pro Max</strong> (430x932), and <strong>iPad 10th Gen</strong> (1024x768) with direct visual defect markings (red bounding boxes, glowing callouts, and technical tickets).
    </p>
  </div>

  {screen_sections_html}

  <div class="page-break"></div>

  <!-- FINAL PAGE: RBAC & REMEDIATION RECIPES -->
  <h2>11. Role-Based Access Control (RBAC) 5-Persona Verification Matrix</h2>
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
        <td>All 35 Routes (<code>/admin/*</code>, <code>/company-dashboard</code>)</td>
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

  <h2>12. Concrete Engineering Remediation Recipes & Action Plan</h2>
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
<span class="diff-info">// Automatically protected by loc.startsWith('/admin')!</span>
  </div>

  <h3>Recipe 3: Financial Integrity Fix in <code>lib/screens/admin/client_analysis_screen.dart</code></h3>
  <div class="code-block">
<span class="diff-del">- projects.where((p) => p.client.toLowerCase().contains(_selectedClient!.name.toLowerCase().split(' ').first))</span>
<span class="diff-add">+ projects.where((p) => p.clientId == _selectedClient!.id || p.client.trim().toLowerCase() == _selectedClient!.name.trim().toLowerCase())</span>
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
        "--run-all-compositor-stages-before-draw",
        "--virtual-time-budget=12000",
        "--print-to-pdf-no-header",
        f"--print-to-pdf={PDF_FILE}",
        f"file://{HTML_FILE}"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0 and os.path.exists(PDF_FILE):
        pdf_size = os.path.getsize(PDF_FILE)
        print(f"SUCCESS: Master PDF report generated: {PDF_FILE} ({pdf_size} bytes, {pdf_size / (1024*1024):.2f} MB)")
        
        # Mirror to Desktop
        d_files = [
            "SpendWise_Pro_Enterprise_Mobile_Audit_Report.pdf",
            "SpendWise_Pro_Audit_Report.pdf",
            "AUDIT_REPORT_ALL_35_SCREENS_MARKED.pdf",
            "REPORT.pdf",
            "SpendWise_Audit_Report_NEW.pdf"
        ]
        for df in d_files:
            target = os.path.join(DESKTOP_DIR, df)
            shutil.copyfile(PDF_FILE, target)
            print(f"COPIED TO DESKTOP: {target}")

        shutil.copyfile(HTML_FILE, os.path.join(DESKTOP_DIR, "SpendWise_Pro_Enterprise_Audit_Report.html"))

        # Mirror to Downloads
        os.makedirs(DOWNLOADS_DIR, exist_ok=True)
        shutil.copyfile(PDF_FILE, os.path.join(DOWNLOADS_DIR, "SpendWise_Pro_Enterprise_Mobile_Audit_Report.pdf"))
        shutil.copyfile(PDF_FILE, os.path.join(DOWNLOADS_DIR, "SpendWise_Audit_Report.pdf"))
        shutil.copyfile(PDF_FILE, os.path.join(DOWNLOADS_DIR, "REPORT.pdf"))

        # Mirror to Home
        shutil.copyfile(PDF_FILE, "/home/alvee/SpendWise_Audit_Report.pdf")
        shutil.copyfile(PDF_FILE, "/home/alvee/Documents/antigravity/agitated-hopper/SpendWise_Pro_Enterprise_Mobile_Audit_Report.pdf")

    else:
        print(f"ERROR generating PDF: {res.stderr}")

if __name__ == '__main__':
    build_pdf_report()
