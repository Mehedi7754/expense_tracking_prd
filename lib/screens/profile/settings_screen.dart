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
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Preferences & Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preferred Currency Section (PRD Section 4.2)
              Text('Currency & Regional Formats', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.currency_exchange_rounded,
                            size: 20,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text('Preferred Display Currency', style: AppTextStyles.labelMedium),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'All personal expense claims and summaries will format with this currency.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: settings.preferredCurrency,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        items: AppConstants.supportedCurrencies.map((curr) {
                          final symbol = AppConstants.currencySymbols[curr] ?? '';
                          return DropdownMenuItem<String>(
                            value: curr,
                            child: Text('$curr ($symbol)'),
                          );
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
              ),

              const SizedBox(height: 24),

              // Appearance (PRD Section 4.2: Light or dark theme)
              Text('Interface Theme', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: SwitchListTile(
                  secondary: Icon(
                    settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                  ),
                  title: Text('Dark Theme Mode', style: AppTextStyles.labelMedium),
                  subtitle: Text(
                    'Executive midnight obsidian theme (PRD Section 4.2)',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                  ),
                  value: settings.isDarkMode,
                  activeColor: isDark ? AppColors.darkPrimary : AppColors.emerald,
                  onChanged: (isDarkTheme) {
                    ref.read(settingsProvider.notifier).toggleTheme(isDarkTheme);
                    NotificationBanner.showSuccess(
                      context,
                      isDarkTheme ? 'Dark Theme activated.' : 'Light Theme activated.',
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Notification Preferences (PRD Section 4.2)
              Text('Alert Notifications', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        Icons.notifications_active_outlined,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                      title: Text('Claim Approvals & Rejections', style: AppTextStyles.labelMedium),
                      subtitle: Text(
                        'Receive immediate notifications on decision updates',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                      ),
                      value: settings.notificationsEnabled,
                      activeColor: isDark ? AppColors.darkPrimary : AppColors.emerald,
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).toggleNotifications(val);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
                      title: Text('Budget Threshold Alerts', style: AppTextStyles.labelMedium),
                      subtitle: Text(
                        'Flag projects consuming >80% allocated funds',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                      ),
                      value: settings.budgetAlertsEnabled,
                      activeColor: isDark ? AppColors.darkPrimary : AppColors.emerald,
                      onChanged: (val) {
                        ref.read(settingsProvider.notifier).toggleBudgetAlerts(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Test Role Persona Switcher (Allows full PRD testing)
              Text('Role Persona (Live Evaluation Mode)', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Persona: ${user?.name ?? ''} (${user?.role.displayName ?? ''})',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Switch personas to observe dynamic bottom navigation and role-based permissions immediately.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: UserRole.values.map((r) {
                        final isSel = user?.role == r;
                        return ChoiceChip(
                          label: Text(r.displayName),
                          selected: isSel,
                          onSelected: (selected) {
                            if (selected) {
                              ref.read(authProvider.notifier).switchRole(r);
                              NotificationBanner.showSuccess(context, 'Switched to ${r.displayName} persona.');
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
