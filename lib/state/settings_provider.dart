import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final String preferredCurrency;
  final bool isDarkMode;
  final bool notificationsEnabled;
  final bool budgetAlertsEnabled;
  final String companyName;
  final String baseCurrency;
  final String? companyLogoUrl;

  // Office Benefit (PRD Section 9)
  final double defaultOfficeBenefitRate; // e.g. 0.30 = 30%
  final Map<String, double> officeBenefitByAssignmentType;

  // Receipt Monitoring Thresholds (PRD Section 11, 12)
  final double receiptWarningThreshold; // 0.30 = 30%
  final double receiptRedFlagThreshold; // 0.50 = 50%
  final double receiptCriticalThreshold; // 0.75 = 75%

  // Food Allowance (PRD Section 6)
  final double dailyFoodAllowance; // ৳800.0

  // Profitability Thresholds (PRD Section 16)
  final double targetProfitMargin; // 35.0%
  final double watchProfitMargin; // 20.0%
  final double riskProfitMargin; // 10.0%

  const SettingsState({
    this.preferredCurrency = 'BDT',
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.budgetAlertsEnabled = true,
    this.companyName = 'PFIS Consultancy & Survey Ltd.',
    this.baseCurrency = 'BDT',
    this.companyLogoUrl,
    this.defaultOfficeBenefitRate = 0.30,
    this.officeBenefitByAssignmentType = const {
      'directConsultancy': 0.30,
      'government': 0.30,
      'private': 0.25,
      'subConsultancy': 0.20,
    },
    this.receiptWarningThreshold = 0.30,
    this.receiptRedFlagThreshold = 0.50,
    this.receiptCriticalThreshold = 0.75,
    this.dailyFoodAllowance = 800.0,
    this.targetProfitMargin = 35.0,
    this.watchProfitMargin = 20.0,
    this.riskProfitMargin = 10.0,
  });

  SettingsState copyWith({
    String? preferredCurrency,
    bool? isDarkMode,
    bool? notificationsEnabled,
    bool? budgetAlertsEnabled,
    String? companyName,
    String? baseCurrency,
    String? companyLogoUrl,
    double? defaultOfficeBenefitRate,
    Map<String, double>? officeBenefitByAssignmentType,
    double? receiptWarningThreshold,
    double? receiptRedFlagThreshold,
    double? receiptCriticalThreshold,
    double? dailyFoodAllowance,
    double? targetProfitMargin,
    double? watchProfitMargin,
    double? riskProfitMargin,
  }) {
    return SettingsState(
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      companyName: companyName ?? this.companyName,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      defaultOfficeBenefitRate: defaultOfficeBenefitRate ?? this.defaultOfficeBenefitRate,
      officeBenefitByAssignmentType: officeBenefitByAssignmentType ?? this.officeBenefitByAssignmentType,
      receiptWarningThreshold: receiptWarningThreshold ?? this.receiptWarningThreshold,
      receiptRedFlagThreshold: receiptRedFlagThreshold ?? this.receiptRedFlagThreshold,
      receiptCriticalThreshold: receiptCriticalThreshold ?? this.receiptCriticalThreshold,
      dailyFoodAllowance: dailyFoodAllowance ?? this.dailyFoodAllowance,
      targetProfitMargin: targetProfitMargin ?? this.targetProfitMargin,
      watchProfitMargin: watchProfitMargin ?? this.watchProfitMargin,
      riskProfitMargin: riskProfitMargin ?? this.riskProfitMargin,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setCurrency(String currency) {
    state = state.copyWith(preferredCurrency: currency, baseCurrency: currency);
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
      preferredCurrency: baseCurrency,
      companyLogoUrl: logoUrl,
    );
  }

  void updateOfficeBenefitSettings({
    required double defaultRate,
    required Map<String, double> byType,
  }) {
    state = state.copyWith(
      defaultOfficeBenefitRate: defaultRate,
      officeBenefitByAssignmentType: byType,
    );
  }

  void updateReceiptThresholds({
    required double warning,
    required double redFlag,
    required double critical,
  }) {
    state = state.copyWith(
      receiptWarningThreshold: warning,
      receiptRedFlagThreshold: redFlag,
      receiptCriticalThreshold: critical,
    );
  }

  void updateFoodAllowance(double allowance) {
    state = state.copyWith(dailyFoodAllowance: allowance);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
