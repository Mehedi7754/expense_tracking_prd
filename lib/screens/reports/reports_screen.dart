import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/minimal_area_chart.dart';
import '../../core/widgets/notification_banner.dart';
import '../../state/expense_provider.dart';
import '../../state/export_service.dart';
import '../../state/project_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final projects = ref.watch(projectProvider);
    final expenses = ref.watch(expenseProvider);

    final totalPortfolioValue = projects.fold<double>(0.0, (sum, p) => sum + p.grossProjectValue);
    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final receiptedCount = expenses.where((e) => e.hasReceipt).length;
    final complianceRatio = expenses.isNotEmpty ? (receiptedCount / expenses.length) * 100 : 100.0;

    // Category breakdown
    final Map<String, double> categoryTotals = {};
    for (final e in expenses) {
      categoryTotals[e.categoryName] = (categoryTotals[e.categoryName] ?? 0.0) + e.amount;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Financial Reports',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30, top: 4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Minimal Hero Financial Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E1B4B).withAlpha(90),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Expenditure vs Portfolio',
                    style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.format(totalSpent, compact: true),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text('Total Incurred', style: TextStyle(fontSize: 11, color: Colors.white60)),
                        ],
                      ),
                      Container(width: 1, height: 36, color: Colors.white24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.format(totalPortfolioValue, compact: true),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text('Total Contract Value', style: TextStyle(fontSize: 11, color: Colors.white60)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Overall Receipt Compliance',
                          style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${complianceRatio.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: complianceRatio >= 50 ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Curved Area Graph
            const MinimalAreaChart(
              title: 'Expenditure Trends',
            ),

            const SizedBox(height: 12),

            // Category Breakdown Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Spending by Category',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
            ),

            const SizedBox(height: 8),

            ...categoryTotals.entries.map((entry) {
              final ratio = totalSpent > 0 ? (entry.value / totalSpent) : 0.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          CurrencyFormatter.format(entry.value),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 4,
                        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 18),

            // Export Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Export Reports (CSV)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildExportPill(
                    label: 'Export Projects Portfolio',
                    icon: Icons.business_center_outlined,
                    onTap: () {
                      final csv = ExportService.exportProjectsToCsv(projects, expenses);
                      NotificationBanner.showSuccess(context, 'Projects exported (${csv.length} bytes)');
                    },
                    isDark: isDark,
                  ),
                  _buildExportPill(
                    label: 'Export Expenses & Receipts',
                    icon: Icons.receipt_long_outlined,
                    onTap: () {
                      final csv = ExportService.exportExpensesToCsv(expenses);
                      NotificationBanner.showSuccess(context, 'Expenses exported (${csv.length} bytes)');
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildExportPill({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.download_rounded, size: 14, color: Color(0xFF4F46E5)),
          ],
        ),
      ),
    );
  }
}
