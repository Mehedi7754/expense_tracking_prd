import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

    // 1. Base64 Data URI
    if (trimmed.startsWith('data:image/') || trimmed.startsWith('data:')) {
      try {
        final commaIdx = trimmed.indexOf(',');
        final b64 = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => placeholder(),
        );
      } catch (_) {
        return placeholder();
      }
    }

    // 2. HTTP/HTTPS Network URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    // 3. Local File
    if (!kIsWeb) {
      try {
        final file = File(trimmed);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => placeholder(),
          );
        }
      } catch (_) {}
    }

    return placeholder();
  }
}
