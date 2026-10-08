import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class NotificationBanner {
  NotificationBanner._();

  /// Sanitizes any notification message so URLs, IPs, ports, and internal details
  /// are never displayed on screen.
  static String sanitizeMessage(String rawMessage) {
    if (rawMessage.isEmpty) return rawMessage;
    var msg = rawMessage;

    // Remove raw Exception prefixes
    msg = msg.replaceAll(RegExp(r'^(Exception|ApiException|ClientException|SocketException|HttpException):\s*', caseSensitive: false), '');

    // Strip http/https URLs
    msg = msg.replaceAll(RegExp(r'https?://[^\s/$.?#].[^\s]*', caseSensitive: false), 'server');

    // Strip IP addresses with optional port
    msg = msg.replaceAll(RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?\b'), 'server');

    // Strip domain names/hostnames if any
    msg = msg.replaceAll(RegExp(r'[\w.-]*sslip\.io[^\s]*', caseSensitive: false), 'server');

    // Convert raw network/socket error text into clean user-friendly phrasing
    final lower = msg.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('network error') ||
        lower.contains('connection error') ||
        lower.contains('network connection failed') ||
        lower.contains('connection reset') ||
        lower.contains('broken pipe')) {
      return 'Unable to connect to server. Please check your internet connection.';
    }

    return msg.trim();
  }

  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.emeraldAccent,
      bgColor: AppColors.primary,
      textColor: AppColors.textWhite,
    );
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.crimson,
      bgColor: AppColors.surface,
      borderColor: AppColors.crimsonBorder,
      textColor: AppColors.crimsonDark,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.amber,
      bgColor: AppColors.surface,
      borderColor: AppColors.amberBorder,
      textColor: AppColors.amberDark,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.brandPrimary,
      bgColor: AppColors.surface,
      borderColor: AppColors.indigoBorder,
      textColor: AppColors.indigoDark,
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
  }) {
    final cleanMessage = sanitizeMessage(message);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: borderColor != null
              ? BorderSide(color: borderColor, width: 1.2)
              : BorderSide.none,
        ),
        content: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cleanMessage,
                style: AppTextStyles.labelMedium.copyWith(color: textColor),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
