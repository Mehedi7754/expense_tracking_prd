import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final bool isOffline;
  final VoidCallback onRetry;

  const ErrorStateWidget({
    super.key,
    this.title = 'Unable to Load Data',
    this.message = 'Something went wrong while connecting to the server. Please check your connection and try again.',
    this.isOffline = false,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.crimsonLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.crimsonBorder, width: 1),
              ),
              child: Icon(
                isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                size: 28,
                color: AppColors.crimson,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isOffline ? 'No Internet Connection' : title,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isOffline
                  ? 'Your device appears to be offline. Please connect to Wi-Fi or mobile data to access the latest financial records.'
                  : message,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
