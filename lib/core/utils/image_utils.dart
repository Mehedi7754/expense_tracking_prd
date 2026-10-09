import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/app_env.dart';

class AppImageHelper {
  /// Converts an image file or bytes to a base64 Data URI string.
  static Future<String> fileToBase64DataUri(File file) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  /// Converts byte array to a base64 Data URI string.
  static String bytesToBase64DataUri(Uint8List bytes, {String mime = 'image/jpeg'}) {
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  /// Builds a widget from an image path/URI (HTTP URL, Data URI base64, or local File).
  static Widget buildImage({
    required String? path,
    required Widget Function() placeholder,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    if (path == null || path.trim().isEmpty) return placeholder();
    final trimmed = path.trim();

    // 1. Base64 Data URI or Raw Base64
    if (trimmed.startsWith('data:image/') || trimmed.startsWith('data:')) {
      try {
        final commaIdx = trimmed.indexOf(',');
        final b64 = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        final bytes = base64Decode(b64);
        if (bytes.isEmpty || bytes.lengthInBytes < 12) return placeholder();
        return Image.memory(
          key: ValueKey('b64_${trimmed.hashCode}'),
          bytes,
          fit: fit,
          width: width,
          height: height,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder(),
        );
      } catch (_) {
        return placeholder();
      }
    } else if (trimmed.length > 60 && !trimmed.contains(' ') && !trimmed.contains('/') && !trimmed.contains(':') ||
               (trimmed.length > 60 && (trimmed.startsWith('iVBOR') || trimmed.startsWith('/9j/') || trimmed.startsWith('UklGR') || trimmed.startsWith('R0lGOD')))) {
      try {
        final bytes = base64Decode(trimmed);
        if (bytes.isNotEmpty && bytes.lengthInBytes >= 12) {
          return Image.memory(
            key: ValueKey('raw_b64_${trimmed.hashCode}'),
            bytes,
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder(),
          );
        }
      } catch (_) {}
    }

    // 2. HTTP/HTTPS Network URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        key: ValueKey(trimmed),
        trimmed,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    // 3. Relative Backend Uploads Path (e.g., /uploads/... or uploads/...)
    if (trimmed.startsWith('/uploads/') || trimmed.startsWith('uploads/') || (trimmed.startsWith('/') && !trimmed.contains('/data/user/'))) {
      final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      final resolved = AppEnv.resolveUrl(normalized);
      if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
        return Image.network(
          key: ValueKey(resolved),
          resolved,
          fit: fit,
          width: width,
          height: height,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder(),
        );
      }
    }

    // 4. Local File
    if (!kIsWeb) {
      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          return Image.file(
            key: ValueKey(file.path),
            file,
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder(),
          );
        }
      } catch (_) {}
    }

    return placeholder();
  }
}
