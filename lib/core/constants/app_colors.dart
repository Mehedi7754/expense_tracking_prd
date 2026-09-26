import 'package:flutter/material.dart';

/// Bespoke financial color palette supporting both Light and Dark themes.
/// Crafted specifically for modern financial elegance — no generic templates.
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ==================== LIGHT THEME COLORS ====================
  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8F9FA); // Warm porcelain canvas
  static const Color surface = Color(0xFFFFFFFF); // Pure white elevated cards
  static const Color surfaceSubtle = Color(0xFFF3F4F6); // Soft gray for inputs/badges
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB); // Hairline geometric border
  static const Color borderSubtle = Color(0xFFF1F3F5); // Extremely subtle divider
  static const Color borderFocused = Color(0xFF0F172A); // Midnight charcoal focus ring

  // Text & Typography
  static const Color textPrimary = Color(0xFF111827); // Deep obsidian text
  static const Color textSecondary = Color(0xFF4B5563); // Cool graphite secondary
  static const Color textMuted = Color(0xFF9CA3AF); // Muted caption gray
  static const Color textWhite = Color(0xFFFFFFFF);

  // Brand / Slate Anchors
  static const Color primary = Color(0xFF0F172A); // Midnight Slate (Authority)
  static const Color primaryLight = Color(0xFF1E293B);
  static const Color primarySubtle = Color(0xFFE2E8F0);

  // Modern Minimal Fintech Gradients (Reference Style)
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentFabGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Convenient Aliases
  static const Color lightBackground = background;
  static const Color lightSurface = surface;
  static const Color lightBorder = border;
  static const Color lightTextPrimary = textPrimary;
  static const Color lightTextSecondary = textSecondary;
  static const Color lightTextMuted = textMuted;
  static const Color error = crimson;
  static const Color warning = amber;
  static const Color success = emeraldAccent;

  // ==================== DARK THEME COLORS ====================
  static const Color darkBackground = Color(0xFF0A0F1D); // Deepest obsidian night
  static const Color darkSurface = Color(0xFF121A2C); // Rich elevated navy-slate card
  static const Color darkSurfaceSubtle = Color(0xFF1A243B); // Dark badge / input fill
  static const Color darkSurfaceElevated = Color(0xFF222F4C); // Popups and floating docks
  static const Color darkBorder = Color(0xFF1E2B45); // Subtle dark geometric divider
  static const Color darkBorderSubtle = Color(0xFF162035);
  static const Color darkBorderFocused = Color(0xFF38BDF8); // Vibrant cyan focus ring

  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Crisp diamond white
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Cool silver slate
  static const Color darkTextMuted = Color(0xFF64748B); // Muted slate gray

  static const Color darkPrimary = Color(0xFF38BDF8); // Bright electric cyan accent
  static const Color darkPrimaryLight = Color(0xFF0284C7);
  static const Color darkPrimarySubtle = Color(0xFF1E293B);

  // ==================== FINANCIAL ACCENTS ====================
  // Emerald / Growth / Approved / Profit
  static const Color emerald = Color(0xFF0F766E); // Deep refined teal-emerald
  static const Color emeraldAccent = Color(0xFF10B981); // Vibrant spring emerald
  static const Color emeraldLight = Color(0xFFECFDF5); // Mint background pill
  static const Color emeraldBorder = Color(0xFFA7F3D0); // Mint border
  static const Color emeraldDark = Color(0xFF064E3B);
  static const Color darkEmeraldLight = Color(0xFF064E3B); // Dark pill fill
  static const Color darkEmeraldBorder = Color(0xFF0F766E);

  // Status Accents: Pending / Amber / Budget Warning
  static const Color amber = Color(0xFFD97706); // Warm ochre
  static const Color amberAccent = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFFFBEB); // Warm vanilla pill
  static const Color amberBorder = Color(0xFFFDE68A);
  static const Color amberDark = Color(0xFF78350F);
  static const Color darkAmberLight = Color(0xFF451A03);
  static const Color darkAmberBorder = Color(0xFF92400E);

  // Status Accents: Rejected / Crimson / At-Risk Project
  static const Color crimson = Color(0xFFE11D48); // Crisp rose-crimson
  static const Color crimsonAccent = Color(0xFFF43F5E);
  static const Color crimsonLight = Color(0xFFFFF1F2); // Soft rose pill
  static const Color crimsonBorder = Color(0xFFFECDD3);
  static const Color crimsonDark = Color(0xFF881337);
  static const Color darkCrimsonLight = Color(0xFF4C0519);
  static const Color darkCrimsonBorder = Color(0xFF9F1239);

  // Status Accents: Indigo / Tasks / Administrator
  static const Color indigo = Color(0xFF4F46E5); // Royal slate
  static const Color indigoAccent = Color(0xFF6366F1);
  static const Color indigoLight = Color(0xFFEEF2FF);
  static const Color indigoBorder = Color(0xFFC7D2FE);
  static const Color indigoDark = Color(0xFF312E81);
  static const Color darkIndigoLight = Color(0xFF1E1B4B);
  static const Color darkIndigoBorder = Color(0xFF3730A3);

  // Neutral Badges & Chips
  static const Color chipBackground = Color(0xFFF3F4F6);
  static const Color chipBorder = Color(0xFFE5E7EB);

  // ==================== PREMIUM GRADIENTS ====================
  static const LinearGradient heroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
    ],
  );

  static const LinearGradient darkHeroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D9488),
      Color(0xFF10B981),
    ],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD97706),
      Color(0xFFF59E0B),
    ],
  );

  static const LinearGradient crimsonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE11D48),
      Color(0xFFFB7185),
    ],
  );

  static const LinearGradient indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4F46E5),
      Color(0xFF6366F1),
    ],
  );

  // Floating dock gradient
  static LinearGradient dockGradient(bool isDark) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF1A243B).withValues(alpha: 0.95),
                const Color(0xFF121A2C).withValues(alpha: 0.98),
              ]
            : [
                Colors.white.withValues(alpha: 0.95),
                const Color(0xFFF8F9FA).withValues(alpha: 0.98),
              ],
      );

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color getBackground(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color getSurface(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color getSurfaceSubtle(BuildContext context) =>
      isDark(context) ? darkSurfaceSubtle : surfaceSubtle;

  static Color getBorder(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color getTextPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color getTextSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color getTextMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  // Consistent Brand Primary Accent (Modern Royal Indigo)
  static const Color brandPrimary = Color(0xFF4F46E5);
  static const Color brandPrimaryDark = Color(0xFF818CF8);

  static Color getPrimary(BuildContext context) =>
      isDark(context) ? brandPrimaryDark : brandPrimary;

  // Subtle Shadow
  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: Color(0x08000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> darkCardShadow([Color? glowColor]) => [
        BoxShadow(
          color: glowColor?.withValues(alpha: 0.12) ?? const Color(0x28000000),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> floatingShadow([bool isDark = false]) => [
        BoxShadow(
          color: isDark ? const Color(0x40000000) : const Color(0x14000000),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
