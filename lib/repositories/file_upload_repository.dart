import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/utils/image_utils.dart';

/// Supported upload categories matching backend `/uploads` endpoint.
enum UploadCategory {
  receipts,
  avatars,
  projects;

  String get value => name;
}

/// Result of a successful file upload.
class UploadResult {
  final String url;
  final String filename;
  final int sizeBytes;

  const UploadResult({
    required this.url,
    required this.filename,
    required this.sizeBytes,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      url: (json['url'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Repository for uploading files (images) to the backend.
///
/// Accepts either a local file path or a base64 Data URI string.
/// Returns a [UploadResult] with the server-side URL for storage.
class FileUploadRepository {
  final ApiClient _client;

  FileUploadRepository(this._client);

  /// Uploads a file to the backend.
  ///
  /// [filePathOrDataUri] can be:
  /// - A local file path (e.g., `/data/user/0/image.jpg`)
  /// - A base64 Data URI (e.g., `data:image/jpeg;base64,/9j/4AAQ...`)
  /// - A raw base64 string
  ///
  /// Returns [UploadResult] with the URL to store in the database.
  Future<UploadResult> upload({
    required String filePathOrDataUri,
    required UploadCategory category,
    String? entityId,
  }) async {
    String base64Data;

    if (filePathOrDataUri.startsWith('data:') || _isRawBase64(filePathOrDataUri)) {
      // Already a data URI or raw base64
      base64Data = filePathOrDataUri;
    } else if (!kIsWeb && File(filePathOrDataUri).existsSync()) {
      // Local file path → convert to base64 data URI
      final file = File(filePathOrDataUri);
      base64Data = await AppImageHelper.fileToBase64DataUri(file);
    } else {
      // If it's already a URL, return it as-is (no upload needed)
      if (filePathOrDataUri.startsWith('http://') || filePathOrDataUri.startsWith('https://') || filePathOrDataUri.startsWith('/uploads/')) {
        return UploadResult(
          url: filePathOrDataUri,
          filename: filePathOrDataUri.split('/').last,
          sizeBytes: 0,
        );
      }
      throw ArgumentError('Invalid file path or data URI: $filePathOrDataUri');
    }

    final response = await _client.post(
      '/uploads',
      body: {
        'file': base64Data,
        'category': category.value,
        if (entityId != null) 'entityId': entityId,
      },
    );

    if (response is Map<String, dynamic>) {
      return UploadResult.fromJson(response);
    }

    throw Exception('Unexpected upload response format');
  }

  /// Quick helper to check if a string looks like raw base64.
  bool _isRawBase64(String value) {
    if (value.length < 100) return false;
    return RegExp(r'^[A-Za-z0-9+/]+=*$').hasMatch(value.substring(0, 100));
  }
}

final fileUploadRepositoryProvider = Provider<FileUploadRepository>((ref) {
  return FileUploadRepository(ref.watch(apiClientProvider));
});
