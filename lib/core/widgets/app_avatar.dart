import 'package:flutter/material.dart';
import '../utils/image_utils.dart';

/// A versatile, production-ready Avatar widget that supports:
/// - Base64 Data URIs (e.g. from ImagePicker)
/// - Local file paths
/// - Relative URLs (e.g. `/uploads/...`)
/// - Network HTTP/HTTPS URLs
/// - Graceful initials fallback with stylish deterministic gradients
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final Border? border;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final TextStyle? textStyle;
  final VoidCallback? onTap;
  final Widget? badge;
  final Alignment badgeAlignment;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.border,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 1.5,
    this.backgroundColor,
    this.gradientColors,
    this.textStyle,
    this.onTap,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
  });

  /// Factory for a radius-based avatar (similar to CircleAvatar)
  factory AppAvatar.radius({
    Key? key,
    String? imageUrl,
    String? name,
    double radius = 20,
    Border? border,
    bool showBorder = false,
    Color? borderColor,
    double borderWidth = 1.5,
    Color? backgroundColor,
    List<Color>? gradientColors,
    TextStyle? textStyle,
    VoidCallback? onTap,
    Widget? badge,
    Alignment badgeAlignment = Alignment.bottomRight,
  }) {
    return AppAvatar(
      key: key,
      imageUrl: imageUrl,
      name: name,
      size: radius * 2,
      border: border,
      showBorder: showBorder,
      borderColor: borderColor,
      borderWidth: borderWidth,
      backgroundColor: backgroundColor,
      gradientColors: gradientColors,
      textStyle: textStyle,
      onTap: onTap,
      badge: badge,
      badgeAlignment: badgeAlignment,
    );
  }

  /// Extracts up to 2 initials from a full name.
  static String getInitials(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) return 'U';
    final trimmed = rawName.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final second = parts[1].isNotEmpty ? parts[1][0] : '';
      final combined = '$first$second'.toUpperCase();
      if (combined.isNotEmpty) return combined;
    }
    if (trimmed.isNotEmpty) {
      return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'U';
  }

  /// Deterministic gradient palette based on user name.
  static List<Color> getGradientForName(String? rawName) {
    final palettes = <List<Color>>[
      [const Color(0xFF4F46E5), const Color(0xFF7C3AED)], // Indigo - Purple
      [const Color(0xFF2563EB), const Color(0xFF06B6D4)], // Blue - Cyan
      [const Color(0xFF059669), const Color(0xFF10B981)], // Emerald
      [const Color(0xFFD97706), const Color(0xFFF59E0B)], // Amber
      [const Color(0xFFDC2626), const Color(0xFFF43F5E)], // Rose
      [const Color(0xFF7C3AED), const Color(0xFFEC4899)], // Violet - Pink
      [const Color(0xFF0D9488), const Color(0xFF14B8A6)], // Teal
      [const Color(0xFF4338CA), const Color(0xFF3B82F6)], // Royal Blue
    ];

    if (rawName == null || rawName.isEmpty) return palettes[0];
    final hash = rawName.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return palettes[hash % palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = getInitials(name);
    final colors = gradientColors ?? getGradientForName(name);

    final effectiveBorder = border ??
        (showBorder
            ? Border.all(
                color: borderColor ?? const Color(0xFF4F46E5),
                width: borderWidth,
              )
            : null);

    Widget avatarContent;

    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      avatarContent = AppImageHelper.buildImage(
        path: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: () => _buildInitialsFallback(initials, colors),
      );
    } else {
      avatarContent = _buildInitialsFallback(initials, colors);
    }

    Widget avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: effectiveBorder,
        color: backgroundColor ?? Colors.transparent,
      ),
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: avatarContent,
        ),
      ),
    );

    if (badge != null) {
      avatarCircle = Stack(
        clipBehavior: Clip.none,
        alignment: badgeAlignment,
        children: [
          avatarCircle,
          Positioned(
            child: badge!,
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatarCircle,
      );
    }

    return avatarCircle;
  }

  Widget _buildInitialsFallback(String initials, List<Color> colors) {
    final fontSize = (size * 0.40).clamp(9.0, 32.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: textStyle ??
              TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: fontSize,
                letterSpacing: initials.length > 1 ? -0.5 : 0,
              ),
        ),
      ),
    );
  }
}
