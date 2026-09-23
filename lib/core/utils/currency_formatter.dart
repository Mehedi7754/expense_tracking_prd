import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(
    double amount, {
    String currency = 'BDT',
    bool compact = false,
    bool includeDecimals = false,
  }) {
    final symbol = AppConstants.currencySymbols[currency] ?? '৳';

    if (compact) {
      final absAmount = amount.abs();
      final sign = amount < 0 ? '-' : '';

      if (absAmount >= 10000000) {
        // Crores
        final crValue = absAmount / 10000000;
        return '$sign$symbol${crValue.toStringAsFixed(crValue.truncateToDouble() == crValue ? 0 : 2)}Cr';
      } else if (absAmount >= 100000) {
        // Lakhs
        final lValue = absAmount / 100000;
        return '$sign$symbol${lValue.toStringAsFixed(lValue.truncateToDouble() == lValue ? 0 : 1)}L';
      } else if (absAmount >= 1000) {
        // Thousands
        final kValue = absAmount / 1000;
        return '$sign$symbol${kValue.toStringAsFixed(kValue.truncateToDouble() == kValue ? 0 : 1)}K';
      }
      return '$sign$symbol${absAmount.toStringAsFixed(0)}';
    }

    final pattern = includeDecimals ? '#,##,##0.00' : '#,##,##0';
    try {
      final formatter = NumberFormat(pattern, 'en_IN');
      return '$symbol${formatter.format(amount)}';
    } catch (_) {
      final formatter = NumberFormat(includeDecimals ? '#,##0.00' : '#,##0', 'en_US');
      return '$symbol${formatter.format(amount)}';
    }
  }

  static String formatPercentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }
}
