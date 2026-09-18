import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final String preferredCurrency;
  final bool isDarkMode;
  final bool notificationsEnabled;
  final bool budgetAlertsEnabled;
  final String companyName;
  final String baseCurrency;
  final String? companyLogoUrl;

  const SettingsState({
    this.preferredCurrency = 'USD',
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.budgetAlertsEnabled = true,
    this.companyName = 'Apex Global Enterprises Inc.',
    this.baseCurrency = 'USD',
    this.companyLogoUrl,
  });

  SettingsState copyWith({
    String? preferredCurrency,
    bool? isDarkMode,
    bool? notificationsEnabled,
    bool? budgetAlertsEnabled,
    String? companyName,
    String? baseCurrency,
    String? companyLogoUrl,
  }) {
    return SettingsState(
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      companyName: companyName ?? this.companyName,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setCurrency(String currency) {
    state = state.copyWith(preferredCurrency: currency);
  }

  void toggleTheme(bool isDark) {
    state = state.copyWith(isDarkMode: isDark);
  }

  void toggleNotifications(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
  }

  void toggleBudgetAlerts(bool enabled) {
    state = state.copyWith(budgetAlertsEnabled: enabled);
  }

  void updateCompanyProfile({
    required String name,
    required String baseCurrency,
    String? logoUrl,
  }) {
    state = state.copyWith(
      companyName: name,
      baseCurrency: baseCurrency,
      companyLogoUrl: logoUrl,
    );
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
