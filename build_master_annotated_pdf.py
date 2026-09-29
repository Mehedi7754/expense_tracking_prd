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
        return base64.b64encode(f.read()).decode("utf-8")

from generate_brutal_postpush_report import SCREENS_DATA

def build_pdf_report():
    print("Compiling Comprehensive 42-Page Enterprise Audit Dossier with ALL 35 Marked Screens...")

    ipad_defects_matrix_b64 = get_base64_image(f"{SCREENSHOTS_DIR}/matrix_postpush_ipad_defects.png")

    screen_sections_html = ""
    for s in SCREENS_DATA:
        sc_id = s["id"]
        marked_img_path = f"{SCREENSHOTS_DIR}/marked_screen_{sc_id}.png"
        marked_b64 = get_base64_image(marked_img_path)

        defects_rows = ""
        for d in s["defects"]:
            badge_class = "badge-pass" if d["type"] == "PASS" else ("badge-crit" if d["type"] in ["CRITICAL", "SECURITY", "ARCH", "DEFECT", "OVERFLOW"] else "badge-warn")
            defects_rows += f"""
            <tr style="border-bottom: 1px solid #F1F5F9;">
              <td style="padding: 6px 10px; width: 180px;"><span class="badge {badge_class}">{d['badge']}</span></td>
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

          <!-- Marked Visual Image -->
          <div style="padding: 8px; background: #F1F5F9; text-align: center; border: 1px solid #CBD5E1; border-top: none;">
            {f'<img src="data:image/png;base64,{marked_b64}" style="width: 100%; max-height: 520px; object-fit: contain; border-radius: 6px; border: 1px solid #CBD5E1;" alt="{s["name"]} Marked Visual" />' if marked_b64 else '<div style="color: #94A3B8; padding: 40px;">[Visual Missing]</div>'}
          </div>

          <!-- Findings Table -->
          <div style="border: 1px solid #E2E8F0; border-top: none; border-radius: 0 0 8px 8px; overflow: hidden; background: #FFFFFF;">
            <div style="background: #F8FAFC; padding: 6px 12px; font-size: 8pt; font-weight: 800; color: #0F172A; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #E2E8F0;">Forensic Findings & Technical Violations:</div>
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
<title>SpendWise Pro (PFIS Financials) — Enterprise Forensic Mobile & Tablet Quality Audit</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&display=swap');

  @page {{
    size: A4 portrait;
    margin: 12mm 12mm 12mm 12mm;
    @bottom-right {{
      content: "Page " counter(page);
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

  h1 {{ font-size: 22pt; line-height: 1.2; }}
  h2 {{ font-size: 13pt; border-bottom: 2px solid #0F172A; padding-bottom: 5px; margin-top: 22px; margin-bottom: 12px; page-break-after: avoid; }}
  h3 {{ font-size: 10.5pt; color: #1E293B; margin-top: 14px; margin-bottom: 6px; page-break-after: avoid; }}

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
    border-radius: 12px;
    margin-bottom: 22px;
    border: 1px solid #334155;
  }}

  .kpi-grid {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 10px;
    margin-bottom: 20px;
  }}

  .kpi-card {{
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 8px;
    padding: 10px 12px;
    text-align: center;
  }}

  .kpi-val {{
    font-size: 18pt;
    font-weight: 800;
    line-height: 1.1;
    margin-bottom: 3px;
  }}

  .kpi-lbl {{
    font-size: 7pt;
    font-weight: 700;
    text-transform: uppercase;
    color: #64748B;
    letter-spacing: 0.5px;
  }}

  table.audit-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 8pt;
    margin-bottom: 18px;
    background: #FFFFFF;
  }}

  table.audit-table th {{
    background: #0F172A;
    color: #FFFFFF;
    text-align: left;
    padding: 7px 9px;
    font-weight: 700;
    font-size: 7.5pt;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }}

  table.audit-table td {{
    padding: 7px 9px;
    border-bottom: 1px solid #E2E8F0;
    vertical-align: top;
  }}

  table.audit-table tr:nth-child(even) td {{
    background: #F8FAFC;
  }}

  .code-block {{
    background: #0F172A;
    color: #F8FAFC;
    padding: 10px 14px;
    border-radius: 8px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 7.5pt;
    line-height: 1.45;
    overflow-x: auto;
    margin-bottom: 14px;
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
    line-height: 1.5;
  }}
</style>
</head>
<body>

<!-- PAGE 1: COVER & EXECUTIVE AUTOPSY -->
<div>
  <div class="hero">
    <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 14px;">
      <div>
        <span class="badge" style="background: #EF4444; color: #FFFFFF; font-weight: 800; font-size: 8pt; padding: 4px 10px;">FATAL PRODUCTION BLOCKER</span>
        <span class="badge" style="background: #3B82F6; color: #FFFFFF; font-weight: 700; font-size: 8pt; padding: 4px 10px; margin-left: 6px;">GIT COMMIT: 0d62f0b</span>
      </div>
      <div style="text-align: right; font-size: 8pt; color: #94A3B8; font-family: monospace;">
        AUDIT DATE: SEPTEMBER 2026<br>
        FLUTTER 3.38.9 • DART 3.10.8
      </div>
    </div>

    <h1 style="color: #FFFFFF; margin-bottom: 6px;">ENTERPRISE FORENSIC CODE QUALITY & MOBILE/TABLET AUDIT</h1>
    <div style="font-size: 10.5pt; color: #94A3B8; max-width: 900px; line-height: 1.4; margin-bottom: 18px;">
      Exhaustive Forensic Autopsy on Commit <code>0d62f0b</code> (&ldquo;new&rdquo; by Mehedi Hasan). Evaluated across ALL 35 Visible Screens with Direct Red Defect Markings, 5 Native Device Viewports, OWASP Top 10 Security Benchmarks, and ISO/IEC 25010 Architecture Standards.
    </div>

    <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; border-top: 1px solid #334155; padding-top: 14px;">
      <div>
        <div style="color: #94A3B8; font-size: 7pt; font-weight: 700; text-transform: uppercase;">Overall Quality Score</div>
        <div style="font-size: 20pt; font-weight: 800; color: #EF4444;">0.0 <span style="font-size: 10pt; color: #94A3B8;">/ 10.0</span></div>
        <div style="color: #F87171; font-size: 7pt; font-weight: 700;">BUILD REJECTED</div>
      </div>
      <div>
        <div style="color: #94A3B8; font-size: 7pt; font-weight: 700; text-transform: uppercase;">Production Web Build</div>
        <div style="font-size: 20pt; font-weight: 800; color: #EF4444;">FAIL</div>
        <div style="color: #F87171; font-size: 7pt; font-weight: 700;">Exit Code 1 (Dart2JS)</div>
      </div>
      <div>
        <div style="color: #94A3B8; font-size: 7pt; font-weight: 700; text-transform: uppercase;">Scope Churn</div>
        <div style="font-size: 20pt; font-weight: 800; color: #F59E0B;">+8,951 / -3,151</div>
        <div style="color: #FCD34D; font-size: 7pt; font-weight: 700;">50 Files Modified</div>
      </div>
      <div>
        <div style="color: #94A3B8; font-size: 7pt; font-weight: 700; text-transform: uppercase;">Total Marked Defects</div>
        <div style="font-size: 20pt; font-weight: 800; color: #EF4444;">84</div>
        <div style="color: #F87171; font-size: 7pt; font-weight: 700;">Across All 35 Screens</div>
      </div>
    </div>
  </div>

  <h2>1. Executive Forensic Summary & Critical Verdict</h2>
  <div class="alert-banner">
    <strong>AUDITOR'S UNCOMPROMISING VERDICT: IMMEDIATE REJECTION.</strong> Commit <code>0d62f0b</code> is completely unfit for production release. The developer pushed 12,102 lines of unreviewed code directly to <code>main</code> under a single-word message (&ldquo;new&rdquo;). The codebase <strong>fails compilation completely</strong> on Flutter Web, breaks all existing regression tests, actively deletes core authentication assertions (&ldquo;p-hacking&rdquo;), exposes proprietary consultancy financial margins via OWASP Broken Access Control (A01:2021), and introduces severe data corruption bugs in client analytics.
  </div>

  <div class="kpi-grid">
    <div class="kpi-card">
      <div class="kpi-val" style="color: #EF4444;">6</div>
      <div class="kpi-lbl">Fatal Compiler Errors</div>
      <div style="font-size: 7pt; color: #64748B; margin-top: 2px;">CardTheme/DialogTheme Mismatches</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #EF4444;">24</div>
      <div class="kpi-lbl">Test Suite Failures</div>
      <div style="font-size: 7pt; color: #64748B; margin-top: 2px;">Enum Renaming Without Migration</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #EF4444;">2</div>
      <div class="kpi-lbl">OWASP A01 Breaches</div>
      <div style="font-size: 7pt; color: #64748B; margin-top: 2px;">Unguarded Client Analysis & Estimator</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-val" style="color: #F59E0B;">24</div>
      <div class="kpi-lbl">Deprecated API Calls</div>
      <div style="font-size: 7pt; color: #64748B; margin-top: 2px;">Dropdown 'value' & Switch 'activeColor'</div>
    </div>
  </div>
</div>
<div class="page-break"></div>

<!-- PAGE 2: PILLAR 1 & PILLAR 2 -->
<div>
  <h2>2. Pillar 1: Fatal Compilation Blocker (P0 — Code Does Not Build)</h2>
  <p>
  The pushed commit <strong>cannot compile for web release</strong>. Running <code>flutter build web --release</code> terminates abnormally with exit code 1. The developer assigned Flutter widget classes (<code>CardTheme</code>, <code>DialogTheme</code>, <code>TabBarTheme</code>) to parameters expecting theme data objects (<code>CardThemeData?</code>, <code>DialogThemeData?</code>, <code>TabBarThemeData?</code>) in <code>lib/core/constants/app_theme.dart</code>.
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

  <h2>3. Pillar 2: Test Suite Demolition & &ldquo;P-Hacking&rdquo; Forensics</h2>
  <p>
  Rather than fixing authentication state flow, the developer deleted all eight rigorous assertions verifying the Login screen, welcome text, buttons, and demo persona switchers in <code>test/splash_login_flow_test.dart</code>, replacing them with a hollow smoke test:
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
  <strong>Forensic Motive:</strong> In <code>lib/state/auth_provider.dart:98-102</code>, the developer hardcoded <code>isAuthenticated: true</code> and <code>currentUser: DemoUsers.mainAdmin</code> on startup. The app bypasses the login screen entirely. When the existing tests failed, the developer deleted the assertions rather than building proper authentication session handling!
  </p>
</div>
<div class="page-break"></div>

<!-- PAGE 3: PILLAR 3, 4, 5 -->
<div>
  <h2>4. Pillar 3: OWASP Top 10 Broken Access Control (A01:2021)</h2>
  <p>
  The developer implemented two new administrative tools: <code>ClientAnalysisScreen</code> and <code>CostEstimatorScreen</code> in <code>lib/screens/admin/</code>, but registered their routes as <code>/client-analysis</code> and <code>/cost-estimator</code> in <code>lib/core/routing/app_router.dart</code> without the <code>/admin</code> prefix.
  </p>

  <div class="code-block">
<span class="diff-info">// SECURITY VULNERABILITY IN lib/core/routing/app_router.dart</span>
      // Admin guard only protects routes starting with '/admin'
      if (loc.startsWith('/admin') && role != UserRole.mainAdmin) {{
        return RoutePaths.home;
      }}
      // CRITICAL FLAW: /client-analysis and /cost-estimator DO NOT start with '/admin'!
      GoRoute(path: RoutePaths.clientAnalysis, builder: (context, state) => const ClientAnalysisScreen()),
      GoRoute(path: RoutePaths.costEstimator, builder: (context, state) => const CostEstimatorScreen()),
  </div>

  <h2>5. Pillar 4: Financial Data Contamination & Calculation Inversion</h2>
  <p>
  In <code>lib/screens/admin/client_analysis_screen.dart:38</code>:
  </p>
  <div class="code-block">
<span class="diff-del">// DANGEROUS STRING PARSING IN FINANCIAL INTELLIGENCE</span>
final clientProjects = _selectedClient != null
    ? projects.where((p) => p.client.toLowerCase().contains(_selectedClient!.name.toLowerCase().split(' ').first)).toList()
    : &lt;ProjectModel&gt;[];
  </div>
  <p>
  Calling <code>.split(' ').first</code> means that selecting &ldquo;Ministry of Water Resources&rdquo; filters by the substring &ldquo;ministry&rdquo;. This groups together <strong>all government ministries</strong> (&ldquo;Ministry of Finance&rdquo;, &ldquo;Ministry of Agriculture&rdquo;, &ldquo;Ministry of Health&rdquo;), cross-contaminating multi-million-dollar receivables, costs, and profit margins into a single corrupt aggregate.
  </p>

  <h2>6. Pillar 5: Monolithic Architecture & UI Thread Jank</h2>
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
        <td>God-widget mixing math loops, persona modals, app bar badges, 3 role dashboards.</td>
        <td>O(N*M) iterations over all projects/expenses in <code>build()</code> drops frames.</td>
      </tr>
      <tr>
        <td><code>lib/screens/expenses/submit_expense_screen.dart</code></td>
        <td><strong>1,012 lines</strong></td>
        <td>12 form controllers, mock OCR, file pickers, category limit checkers.</td>
        <td>Severe keyboard latency and form rebuild thrashing on mobile devices.</td>
      </tr>
      <tr>
        <td><code>lib/screens/projects/project_detail_screen.dart</code></td>
        <td><strong>804 lines</strong></td>
        <td>Monolithic tab views, inline burn-rate calculations, task lists.</td>
        <td>High memory footprint, redundant widget tree recreation on tab switch.</td>
      </tr>
    </tbody>
  </table>
</div>
<div class="page-break"></div>

<!-- PAGE 4: PILLAR 6 & PILLAR 7 -->
<div>
  <h2>7. Pillar 6: Static Code Analysis (24 Deprecated APIs)</h2>
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
        <td>18 occurrences across 6 screens</td>
        <td>Will trigger fatal compilation errors in subsequent Flutter releases. Deprecated since v3.33.0.</td>
      </tr>
      <tr>
        <td><code>Switch.activeColor</code></td>
        <td><code>activeThumbColor</code> / <code>activeTrackColor</code></td>
        <td>6 occurrences across 3 screens</td>
        <td>Inconsistent switch thumb styling and theme override conflicts. Deprecated since v3.31.0.</td>
      </tr>
    </tbody>
  </table>

  <h2>8. Pillar 7: Multi-Device Responsive & iPad Tablet Failure Matrix</h2>
  <p>
  The application completely fails to adapt to tablet viewports (Apple iPad 10th Gen 768x1024 portrait and 1024x768 landscape). The UI simply stretches mobile layouts to the extreme edges of the screen, creating unreadable forms, flattened charts, and massive dead whitespace voids:
  </p>

  <div style="text-align: center; margin-bottom: 14px;">
    {f'<img src="data:image/png;base64,{ipad_defects_matrix_b64}" style="max-width: 100%; height: auto; border-radius: 6px; border: 1px solid #CBD5E1;" alt="iPad Tablet Defect Matrix" />' if ipad_defects_matrix_b64 else ''}
  </div>
</div>
<div class="page-break"></div>

<!-- SECTION 9: 35 SCREENS (EACH WITH ITS OWN PAGE!) -->
<div>
  <div style="background: #0F172A; color: #FFFFFF; padding: 14px 18px; border-radius: 8px; margin-bottom: 20px;">
    <h2 style="color: #FFFFFF; border: none; margin: 0; padding: 0;">SECTION 9: COMPLETE 35-SCREEN FORENSIC AUDIT CATALOG</h2>
    <div style="font-size: 9pt; color: #94A3B8; margin-top: 4px;">
      Exhaustive screen-by-screen visual inspection displaying side-by-side Mobile (iPhone 15 Pro) and Tablet (iPad 10th Gen Landscape) captures with direct visual defect markings (red bounding boxes, glowing callouts, and technical tickets).
    </div>
  </div>
</div>

{screen_sections_html}

<!-- SECTION 10 & 11 -->
<div>
  <h2>10. Role-Based Access Control (RBAC) 5-Persona Verification Matrix</h2>
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

  <h2>11. Concrete Engineering Remediation Recipes & Action Plan</h2>
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
// Automatically protected by loc.startsWith('/admin')!
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

  <div style="margin-top: 24px; padding: 12px; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; font-size: 7.5pt; color: #64748B;">
    <strong>Audit Standards:</strong> ISO/IEC 25010 Software Quality Metrics, WCAG 2.2 Accessibility Guidelines, and OWASP Top 10 Security Standards. Tested via automated Selenium WebDriver running headless Chromium with SwiftShader hardware acceleration on Ubuntu Linux.
  </div>
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
        "--virtual-time-budget=10000",
        "--print-to-pdf-no-header",
        f"--print-to-pdf={PDF_FILE}",
        f"file://{HTML_FILE}"
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
    build_pdf_report()
