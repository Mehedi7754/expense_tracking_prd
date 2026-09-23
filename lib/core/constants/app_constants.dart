class AppConstants {
  AppConstants._();

  static const String appName = 'PFIS';
  static const String appFullName = 'Project Financial Intelligence System';
  static const String appTagline = 'Project Cost & Profitability Management';

  // Receipt compliance thresholds (PRD Section 11, 12)
  static const double receiptWarningThreshold = 0.30; // 30%
  static const double receiptRedFlagThreshold = 0.50; // 50%
  static const double receiptCriticalThreshold = 0.75; // 75%
  static const double receiptRequiredThreshold = 50.0; // ৳50 threshold for requiring receipt

  // Default Office Benefit rate (PRD Section 9)
  static const double defaultOfficeBenefitRate = 0.30; // 30%

  // Company approved food allowance per person/day (PRD Section 6)
  static const double defaultDailyFoodAllowance = 800.0; // ৳800 per person

  // Supported currencies
  static const List<String> supportedCurrencies = [
    'BDT',
    'USD',
    'EUR',
    'GBP',
  ];

  static const Map<String, String> currencySymbols = {
    'BDT': '৳',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
  };
}
