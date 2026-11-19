# Geospatial Works (GW Project) — Comprehensive AI Agent Manual

> **Purpose**: This document provides end-to-end instructions, operational rules, infrastructure details, deployment commands, and architectural context for any AI coding agent operating across the Geospatial Works ecosystem.

---

## 1. System Architecture & Repositories

The project consists of three interconnected systems:

| Component | Repository Directory | Remote Git URL | Active Working Branch | Tech Stack |
| :--- | :--- | :--- | :--- | :--- |
| **Mobile App (Flutter)** | `/home/alvee/Desktop/gw project app/repo` | `https://github.com/Mehedi7754/expense_tracking_prd.git` | `codex/project-field-geofence-20261103` | Flutter 3.29+, Dart 3.7+, Riverpod, GoRouter |
| **Backend API (NestJS)** | `/home/alvee/Desktop/gw project app/repo/backend` | (same repo as mobile app) | `codex/project-field-geofence-20261103` | NestJS 11+, Fastify 5.12+, TypeScript, PostgreSQL (`pg`) |
| **Web Dashboard** | `/home/alvee/Desktop/gw project app/frontend-repo` | `https://github.com/Alvee0033/geospatialworks.git` | `codex/project-image-upload-20261103` | Next.js 16 (App Router), React 19, Tailwind CSS, Turbopack |
| **Admin Web (Legacy/Alt)** | `/home/alvee/Desktop/gw project app/admin-web` | — | `master` | Next.js App Router |

---

## 2. Production Infrastructure & Deployment

### 2.1 Live Environments & Endpoints
- **Live Backend API Base**: `https://ihhxbfmr3be3hilklfuvhwyg.203.96.190.78.sslip.io/api/v1`
- **Live Health Check**: `https://ihhxbfmr3be3hilklfuvhwyg.203.96.190.78.sslip.io/api/v1/health`
- **Live Web Dashboard**: Managed via Coolify frontend container
- **Coolify Console Host**: `http://203.96.190.78:8000`
- **Coolify CLI Context**: `fahad`

### 2.2 Coolify Deployment Commands
Every agent deploying code must use the Coolify CLI with `--context fahad`:

```bash
# 1. Deploy Backend (UUID: ihhxbfmr3be3hilklfuvhwyg)
coolify deploy uuid ihhxbfmr3be3hilklfuvhwyg --context fahad

# 2. Deploy Web Frontend (UUID: mtoam6j7bojzuo6lhsakwfp8)
coolify deploy uuid mtoam6j7bojzuo6lhsakwfp8 --context fahad

# 3. Check Deployment Progress & Status
coolify deploy get <deployment_uuid> --context fahad
```

> **Crucial Rule**: Always commit and push code to the designated remote Git branch **before** triggering a Coolify deployment. Coolify builds directly from the remote repository.

---

## 3. Database Architecture (PostgreSQL)

- **Host**: `203.96.190.78`
- **Port**: `5437`
- **Database Name**: `spendwise_db`
- **Username**: `spendwise`
- **Password**: `63e1d28f749885ae9246ce9c1d9f5e804d33d5be5898f490f2389fd7f87c8eb1`
- **Direct CLI Access**:
  ```bash
  PGPASSWORD=63e1d28f749885ae9246ce9c1d9f5e804d33d5be5898f490f2389fd7f87c8eb1 psql -h 203.96.190.78 -p 5437 -U spendwise -d spendwise_db
  ```

### Key Tables & Critical Columns
1. **`users`**:
   - `role`: `main_admin`, `admin`, `project_manager`, `finance_manager`, `finance`, `project_member`.
2. **`projects`**:
   - `daily_food_allowance`: Project-specific override for meal allowances (e.g., 1200 BDT). Overrides system company default (800 BDT).
   - `latitude`, `longitude`, `geofence_radius`: Dynamic project field site geofencing coordinates.
3. **`project_members`**:
   - Granular capability flags per member per project: `can_approve_expenses`, `can_view_budget`, `can_record_revenue`, `can_view_expenses`, `can_create_expenses`, `can_manage_tasks`, `can_update_progress`, `can_manage_team`, `can_edit_project`, `can_view_attendance`.
4. **`expenses`**:
   - `note`: Text notes/description.
   - `receipt_photo_urls`: PostgreSQL native array `text[]` storing multiple image URLs.
   - `receipt_photos`: Structured JSON `jsonb` array of receipt metadata.
   - `full_day_meal`: Boolean flag for full-day field meal allowance claims.
   - `status`: `draft`, `pending`, `approved`, `rejected`.
5. **`attendance_records`**:
   - `is_present`, `is_late`, `is_early_departure`, `geofence_status`, `punch_type`, `location_pin`.
6. **`leave_records`**:
   - `leave_type`: `casual`, `sick`, `emergency`, `unpaid`, `maternity`, `paid`.
   - `status`: `pending`, `approved`, `rejected`.
   - `is_approved`: Boolean.
   - `approved_by`: UUID reference to approver.
7. **`app_releases`**:
   - Holds APK release metadata: `version_name`, `build_number`, `download_url`, `file_path`, `file_size_bytes`, `is_latest`.

---

## 4. Mobile Release Protocols (Android APK)

When releasing mobile app updates, agents **must adhere to these universal compatibility rules**:

1. **Target SDK & Minimum SDK**:
   - `minSdk = 24` (Android 7.0+)
   - `targetSdk = 34` (Android 14+)
   - `compileSdk = 35`
2. **Multi-Scheme Signing Scheme (Mandatory)**:
   - Keystore: Located in `repo/android/app/key.jks`
   - All schemes enabled: `enableV1Signing = true`, `enableV2Signing = true`, `enableV3Signing = true`.
3. **Verification Before Release**:
   - Run verification using the Android SDK build-tools `apksigner`:
     ```bash
     /home/alvee/Android/Sdk/build-tools/34.0.0/apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
     ```
   - Must confirm `Verified using v2 scheme: true` and `Verified using v3 scheme: true`.
4. **Publishing Workflow**:
   - Increment `version` in `repo/pubspec.yaml` (e.g., `1.0.39+2039`).
   - Run `flutter build apk --release`.
   - Copy to:
     - `repo/GW-Project-vX.Y.Z.apk`
     - `repo/backend/uploads/apps/geospatial-works-vX.Y.Z.apk`
     - `repo/backend/uploads/apps/geospatial-works.apk`
   - Register in PostgreSQL `app_releases` table with `is_latest = TRUE` (set previous latest to `FALSE`).
   - Commit, push, and redeploy Coolify backend so static downloads (`/api/v1/app-releases/download-latest`) immediately serve the new APK.

---

## 5. Backend Operational Patterns & Gotchas

### 5.1 Fastify JSON Body Parsing (Critical)
The backend runs on Fastify (`@nestjs/platform-fastify`).
- **Gotcha**: Fastify strictly throws `FST_ERR_CTP_INVALID_JSON_BODY` (HTTP 400: `Body cannot be empty when content-type is set to 'application/json'`) if an HTTP POST/PUT/PATCH includes `Content-Type: application/json` but has an empty 0-byte body.
- **Rule**:
  1. `main.ts` must maintain the custom body parser intercepting empty JSON bodies and returning `{}`.
  2. Frontend & Flutter `ApiClient` must never send `Content-Type: application/json` on requests where `body` is null or empty.
  3. Action endpoints without parameters (like `/approve` or `/reject` or `/logout`) should accept `{}` or omit the Content-Type header.

### 5.2 Geofencing Fallback Logic
- **Rule**: Geofence coordinates are **never hardcoded**.
- The server reads dynamic settings from `attendance_timing_settings` table (`officeLatitude`, `officeLongitude`, `geofenceRadiusMeters`).
- Individual projects store site coordinates in `projects.latitude`, `projects.longitude`, and `projects.geofence_radius`.
- Banani HQ centroid coordinates (`23.7925, 90.4078`) serve strictly as a fallback when coordinates are null/0 to prevent defaulting to `[0, 0]` (Gulf of Guinea).

### 5.3 Notification Deduplication
- **Rule**: Attendance check-in/out and leave events must never pop duplicate banners.
- Push notification dispatches attach deterministic tags (`payloadData.tag = attendance_${actor}_${date}`).
- Frontends (Web & Mobile) maintain a sliding 60-second content fingerprint cache (`title + body`) to prevent race conditions between SSE real-time streams and fallback polling intervals.

### 5.4 Expense Anti-Fraud & Edit Safeguards
- **Rule**: Once an expense claim is in `approved` state (or any state other than `pending`/`draft`), it cannot be edited or deleted by any user (including project members). Must return `403 Forbidden`.
- **Rule**: Users cannot approve their own expense claims (returns `403 Forbidden: Anti-fraud rule: You cannot approve your own expense report`).

---

## 6. Testing, Subagent Orchestration & Cleanliness Rules

When testing features or delegating work to autonomous subagents:

1. **Tag All Test Artifacts**:
   - Any test user, project, expense, leave, attendance, or notification created must use identifiable prefixes:
     - Emails: `%ralph%`, `%val%`, `test_*@gw.com`
     - Reasons / Titles / Notes: `VAL_%`, `RALPH_%`, `TEMP_%`
2. **100% Database Purge Mandate**:
   - Immediately after test completion, all test records must be deleted from:
     - `leave_records`
     - `expense_comments`
     - `expenses`
     - `attendance_records`
     - `notifications`
     - `project_members`
     - `projects`
     - `user_fcm_tokens`
     - `users`
   - Always run an audit verification query (`SELECT count(*)`) to verify **0 residual test rows** remain.
3. **Clean Working Tree**:
   - Delete all temporary test runners or scratch scripts from `backend/scripts/` or `repo/` before completing tasks.
