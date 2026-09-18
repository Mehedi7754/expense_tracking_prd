import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {String currency = 'USD', bool compact = false}) {
    final symbol = AppConstants.currencySymbols[currency] ?? '\$';
    if (compact && (amount.abs() >= 1000000 || amount.abs() >= 1000)) {
      final compactFormat = NumberFormat.compact();
      return '$symbol${compactFormat.format(amount)}';
    }
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '$symbol${formatter.format(amount)}';
  }

  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}
