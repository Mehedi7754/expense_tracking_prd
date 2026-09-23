import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';

class ReceiptComplianceBadge extends StatelessWidget {
  final double unreceiptedAmount;
  final double unreceiptedRatio; // e.g. 60.0 for 60%
  final bool isCompact;

  const ReceiptComplianceBadge({
    super.key,
    required this.unreceiptedAmount,
    required this.unreceiptedRatio,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    String symbol;

    if (unreceiptedRatio >= 75.0) {
      statusColor = const Color(0xFF991B1B); // Dark Red
      statusText = 'CRITICAL RISK';
      symbol = '🔴';
    } else if (unreceiptedRatio >= 50.0) {
      statusColor = AppColors.error;
      statusText = 'HIGH RISK';
      symbol = '🔴';
    } else if (unreceiptedRatio >= 30.0) {
      statusColor = AppColors.warning;
      statusText = 'WARNING';
      symbol = '🟡';
    } else {
      statusColor = AppColors.success;
      statusText = 'COMPLIANT';
      symbol = '🟢';
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: statusColor.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(symbol, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
            Text(
              '${unreceiptedRatio.toStringAsFixed(0)}% No-Receipt',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(60), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              unreceiptedRatio >= 50.0
                  ? Icons.receipt_long_rounded
                  : Icons.verified_user_rounded,
              size: 20,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$symbol $statusText',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${unreceiptedRatio.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Unreceipted Expenditure: ${CurrencyFormatter.format(unreceiptedAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor.withAlpha(220),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
