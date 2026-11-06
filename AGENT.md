# GW Project - Agent Guidelines & Build Standards

## 1. Android Release Build & Universal Compatibility
- **Always Keep Production Compatibility**: Maintain `minSdk = 24`, `targetSdk = 34`, and compile with compatible dependencies.
- **Signing Scheme**: Multi-scheme signing enabled (`enableV1Signing = true`, `enableV2Signing = true`, `enableV3Signing = true`).
- **Always Verify**: Verify every build with `/home/alvee/Android/Sdk/build-tools/35.0.0/apksigner verify --verbose` before releasing.
- **Versioning**: Increment `version` in `pubspec.yaml` and `AppConstants` (`appVersion` and `buildNumber`).
- **Database Release Record**: Update PostgreSQL `app_releases` table with `is_latest = TRUE`, matching version, build number, size in bytes, and download URL.

## 2. Project-Level Roles & Permissions Matrix
- Keep system roles (`mainAdmin`, `admin`, `manager`, `projectMember`) intact for high-level routing.
- Granular permissions live in `project_members` per project with custom role titles and 10 capability flags:
  1. `can_approve_expenses` (Crucial: delegates claim review & notifications to project lead/auditor)
  2. `can_view_budget`
  3. `can_record_revenue`
  4. `can_view_expenses`
  5. `can_create_expenses`
  6. `can_manage_tasks`
  7. `can_update_progress`
  8. `can_manage_team`
  9. `can_edit_project`
  10. `can_view_attendance`
