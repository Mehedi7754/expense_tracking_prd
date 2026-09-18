class AppConstants {
  AppConstants._();

  static const String appName = 'SpendWise Pro';
  static const String appTagline = 'Enterprise Expense & Finance Management';

  // Receipt requirement threshold in base currency
  static const double receiptRequiredThreshold = 50.0;

  // Project budget alert threshold (80% used)
  static const double budgetAlertThreshold = 0.80;

  // Supported currencies
  static const List<String> supportedCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'CAD',
    'AUD',
    'JPY',
  ];

  static const Map<String, String> currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'CAD': 'CA\$',
    'AUD': 'AU\$',
    'JPY': '¥',
  };
}
