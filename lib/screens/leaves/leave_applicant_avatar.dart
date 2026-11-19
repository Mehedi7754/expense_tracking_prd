import 'package:flutter/material.dart';

import '../../core/config/app_env.dart';

class LeaveApplicantAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;

  const LeaveApplicantAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    this.radius = 22,
  });

  String _resolve(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = AppEnv.apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final path = imageUrl?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDBEAFE),
      backgroundImage: path.isEmpty ? null : NetworkImage(_resolve(path)),
      onBackgroundImageError: path.isEmpty ? null : (_, __) {},
      child:
          path.isEmpty
              ? Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w800,
                ),
              )
              : null,
    );
  }
}
