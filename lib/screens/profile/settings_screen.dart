import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authProvider).currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = user?.role == UserRole.mainAdmin || user?.role == UserRole.finance;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('PFIS Settings & Rules'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Currency
            Text('Currency & Regional Formats', style: AppTextStyles.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.currency_exchange_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text('Preferred Display Currency', style: AppTextStyles.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Default currency is Bangladeshi Taka (৳). Formats in Lakhs (L) and Crores (Cr).',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: settings.preferredCurrency,
                    items: AppConstants.supportedCurrencies.map((curr) {
                      final symbol = AppConstants.currencySymbols[curr] ?? '';
                      return DropdownMenuItem<String>(value: curr, child: Text('$curr ($symbol)'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(settingsProvider.notifier).setCurrency(val);
                        NotificationBanner.showSuccess(context, 'Preferred currency set to $val.');
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // PRD Section 9: Configurable Office Benefit (30%)
            if (isAdmin) ...[
              Text('Office Benefit Configuration (PRD Section 9)', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fixed percentage applied automatically to Direct Project Costs without manual entry.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Office Benefit Rate:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${(settings.defaultOfficeBenefitRate * 100).toInt()}%',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('By Assignment Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    _buildRateRow('Direct Consultancy', '30%'),
                    _buildRateRow('Government', '30%'),
                    _buildRateRow('Private', '25%'),
                    _buildRateRow('Sub-consultancy', '20%'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // PRD Section 11 & 12: Configurable Receipt Compliance Thresholds
              Text('Receipt Compliance Thresholds (PRD Section 11 & 12)', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dual indicator thresholds governing automated compliance flags and justification triggers.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    _buildThresholdItem('🟢 Normal Threshold', 'Below 30%', AppColors.success),
                    const Divider(height: 16),
                    _buildThresholdItem('🟡 Warning Threshold', '30% – 50%', AppColors.warning),
                    const Divider(height: 16),
                    _buildThresholdItem('🔴 Red Flag / High Risk Threshold', 'Above 50% (Justification Required)', AppColors.error),
                    const Divider(height: 16),
                    _buildThresholdItem('🔴 Critical Risk Threshold', 'Above 75%', const Color(0xFF991B1B)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // PRD Section 6: Food Allowance Limit
              Text('Daily Food Allowance Limit (PRD Section 6)', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Per Person Daily Limit:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Flags unusually high claims automatically', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Text('৳ ${settings.dailyFoodAllowance.toInt()}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Appearance Theme
            Text('Interface Theme', style: AppTextStyles.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Dark Mode', style: AppTextStyles.labelMedium),
                subtitle: Text('Switch between light executive and dark OLED themes.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                value: settings.isDarkMode,
                onChanged: (val) => ref.read(settingsProvider.notifier).toggleTheme(val),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateRow(String type, String rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(type, style: const TextStyle(fontSize: 12)),
          Text(rate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildThresholdItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
