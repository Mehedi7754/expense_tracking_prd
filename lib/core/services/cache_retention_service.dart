import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheRetentionService {
  CacheRetentionService._();

  static const String _retentionDaysKey = 'spendwise_doc_retention_days';
  static const int defaultRetentionDays = 30;

  static const List<int> retentionOptions = [7, 14, 30, -1];

  /// Returns label for retention option
  static String getRetentionLabel(int days) {
    switch (days) {
      case 7:
        return '7 Days';
      case 14:
        return '14 Days';
      case 30:
        return '30 Days (Recommended)';
      case -1:
        return 'Never (Manual Only)';
      default:
        return '$days Days';
    }
  }

  /// Gets the currently configured retention period in days (-1 = never)
  static Future<int> getRetentionDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_retentionDaysKey) ?? defaultRetentionDays;
    } catch (e) {
      developer.log('Error reading retention days: $e', name: 'CacheRetentionService');
      return defaultRetentionDays;
    }
  }

  /// Sets the retention period in days
  static Future<void> setRetentionDays(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_retentionDaysKey, days);
      developer.log('Set document retention policy to: $days days', name: 'CacheRetentionService');
    } catch (e) {
      developer.log('Error saving retention days: $e', name: 'CacheRetentionService');
    }
  }

  /// Calculates total bytes of files stored in temporary / cache directories
  static Future<int> getCacheSizeBytes() async {
    int totalBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entities = tempDir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            try {
              totalBytes += await entity.length();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      developer.log('Error calculating cache size: $e', name: 'CacheRetentionService');
    }
    return totalBytes;
  }

  /// Returns human-readable formatted string of current cache size (e.g. 1.8 MB)
  static Future<String> getFormattedCacheSize() async {
    final bytes = await getCacheSizeBytes();
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Scans temporary directory and deletes documents / cached files older than the retention threshold
  /// Returns the number of files deleted.
  static Future<int> cleanupExpiredFiles() async {
    final retentionDays = await getRetentionDays();
    if (retentionDays <= 0) {
      developer.log('Retention set to manual only. Skipping cleanup.', name: 'CacheRetentionService');
      return 0;
    }

    int deletedCount = 0;
    int freedBytes = 0;
    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));

    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return 0;

      final entities = tempDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            final lastModified = await entity.lastModified();
            if (lastModified.isBefore(cutoffDate)) {
              final size = await entity.length();
              await entity.delete();
              deletedCount++;
              freedBytes += size;
            }
          } catch (e) {
            // Ignore in-use file deletion errors
          }
        }
      }

      developer.log(
        'Auto-cleanup completed: $deletedCount expired files removed (${(freedBytes / 1024).toStringAsFixed(1)} KB freed)',
        name: 'CacheRetentionService',
      );
    } catch (e) {
      developer.log('Error during cache cleanup: $e', name: 'CacheRetentionService');
    }

    return deletedCount;
  }

  /// Immediately deletes all cached files in the temporary directory
  /// Returns the number of files deleted.
  static Future<int> clearAllCache() async {
    int deletedCount = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return 0;

      final entities = tempDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (_) {}
        }
      }
      developer.log('Manual cache purge: $deletedCount files removed', name: 'CacheRetentionService');
    } catch (e) {
      developer.log('Error clearing cache: $e', name: 'CacheRetentionService');
    }
    return deletedCount;
  }
}
