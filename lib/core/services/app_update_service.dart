import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../network/api_endpoints.dart';

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();
  static bool _hasCheckedThisSession = false;

  Future<void> checkForUpdate(BuildContext context, {bool force = false}) async {
    if (_hasCheckedThisSession && !force) return;
    _hasCheckedThisSession = true;

    try {
      final url = Uri.parse(ApiEndpoints.resolve('/app-releases/latest'));
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data == null || data is! Map<String, dynamic>) return;

      final latestBuildNumber = int.tryParse(data['buildNumber']?.toString() ?? '') ?? 0;
      final latestVersionName = (data['versionName']?.toString() ?? '').replaceAll('v', '').trim();
      final currentVersion = AppConstants.appVersion.replaceAll('v', '').trim();

      final isNewerBuild = latestBuildNumber > AppConstants.buildNumber;
      final isNewerVersion = latestVersionName.isNotEmpty &&
          latestVersionName != currentVersion &&
          _compareVersions(latestVersionName, currentVersion) > 0;

      if ((isNewerBuild || isNewerVersion) && context.mounted) {
        showUpdateDialog(context, data);
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for update: $e');
    }
  }

  int _compareVersions(String v1, String v2) {
    final p1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final p2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (int i = 0; i < maxLen; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 > n2) return 1;
      if (n1 < n2) return -1;
    }
    return 0;
  }

  void showUpdateDialog(BuildContext context, Map<String, dynamic> releaseInfo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final versionName = releaseInfo['versionName'] ?? 'Latest';
    final notes = releaseInfo['releaseNotes']?.toString() ?? 'A new version is available with bug fixes and improvements.';
    final rawUrl = releaseInfo['downloadUrl']?.toString() ?? '';
    final downloadUrl = rawUrl.startsWith('http') ? rawUrl : ApiEndpoints.resolve('/app-releases/download-latest');
    final sizeBytes = int.tryParse(releaseInfo['fileSizeBytes']?.toString() ?? '') ?? 0;
    final sizeMb = sizeBytes > 0 ? ' (${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB)' : '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF10B981)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Update Available $sizeMb', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                ),
              ),
              const SizedBox(height: 8),
              Text('GW Project $versionName', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text('Current Version: v${AppConstants.appVersion}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(maxHeight: 130),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("WHAT'S NEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text(notes, style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final uri = Uri.parse(downloadUrl);
                  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                    await launchUrl(uri, mode: LaunchMode.platformDefault);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Download & Install Update', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
