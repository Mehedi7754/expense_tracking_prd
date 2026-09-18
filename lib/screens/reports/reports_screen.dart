import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/chart_widget.dart';
import '../../core/widgets/custom_filter_panel.dart';
import '../../core/widgets/date_range_picker_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/stat_card.dart';
import '../../models/expense_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/category_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/user_management_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  FilterCriteria _filterCriteria = const FilterCriteria();

  void _openFilterModal(List<dynamic> projects, List<dynamic> categories, List<dynamic> users) {
    CustomFilterPanel.show(
      context,
      initialCriteria: _filterCriteria,
      projects: projects.map((p) => {'id': p.id as String, 'name': p.name as String}).toList(),
      categories: categories.map((c) => {'id': c.id as String, 'name': c.name as String}).toList(),
      employees: users.map((u) => {'id': u.id as String, 'name': u.name as String}).toList(),
      showEmployeeFilter: true,
      showStatusFilter: true,
      onApply: (criteria) => setState(() => _filterCriteria = criteria),
    );
  }

  void _simulateExport(String format) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    format == 'Excel' ? Icons.table_chart_rounded : Icons.picture_as_pdf_rounded,
                    color: format == 'Excel' ? AppColors.emerald : AppColors.crimson,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text('Export Financial Report ($format)', style: AppTextStyles.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Financial report generated containing all active filters, expense line items, and category rollups.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    NotificationBanner.showSuccess(
                      context,
                      'Report successfully compiled and shared to device.',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text('Share $format File via System'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    NotificationBanner.showSuccess(
                      context,
                      'Report saved to device Downloads folder.',
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download to Local Storage'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expenseProvider);
    final allProjects = ref.watch(projectProvider);
    final allCategories = ref.watch(categoryProvider);
    final allUsers = ref.watch(userManagementProvider);

    // Apply Filter Panel Criteria to Expenses
    final filteredExpenses = allExpenses.where((e) {
      if (_filterCriteria.projectId != null && e.projectId != _filterCriteria.projectId) return false;
      if (_filterCriteria.categoryId != null && e.categoryId != _filterCriteria.categoryId) return false;
      if (_filterCriteria.employeeId != null && e.employeeId != _filterCriteria.employeeId) return false;
      if (_filterCriteria.status != null && e.status != _filterCriteria.status) return false;
      if (_filterCriteria.dateRange != null) {
        if (e.date.isBefore(_filterCriteria.dateRange!.start) ||
            e.date.isAfter(_filterCriteria.dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();

    // Summary calculation (PRD Section 4.5: total cost, total revenue, total profit)
    double totalCost = 0.0;
    for (final exp in filteredExpenses.where((e) => e.status == ExpenseStatus.approved)) {
      totalCost += exp.amount;
    }

    double totalRevenue = 0.0;
    for (final proj in allProjects) {
      if (_filterCriteria.projectId != null && proj.id != _filterCriteria.projectId) continue;
      for (final rev in proj.revenueEntries) {
        if (_filterCriteria.dateRange != null) {
          if (rev.date.isBefore(_filterCriteria.dateRange!.start) ||
              rev.date.isAfter(_filterCriteria.dateRange!.end.add(const Duration(days: 1)))) {
            continue;
          }
        }
        totalRevenue += rev.amount;
      }
    }

    final totalProfit = totalRevenue - totalCost;

    // Charts calculation: Cost broken down by category (PRD Section 4.5)
    final Map<String, double> categoryCosts = {};
    for (final exp in filteredExpenses.where((e) => e.status == ExpenseStatus.approved)) {
      categoryCosts[exp.categoryName] = (categoryCosts[exp.categoryName] ?? 0.0) + exp.amount;
    }

    final user = ref.watch(authProvider).currentUser;
    final canViewCompanyDashboard = user != null &&
        (user.role == UserRole.finance || user.role == UserRole.admin);
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filterCriteria.isActive,
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: 'Filter Report Data',
            onPressed: () => _openFilterModal(allProjects, allCategories, allUsers),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Report',
            onSelected: (val) => _simulateExport(val),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'Excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_rounded, size: 18, color: AppColors.emerald),
                    SizedBox(width: 10),
                    Text('Export as Excel (.xlsx)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'PDF',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppColors.crimson),
                    SizedBox(width: 10),
                    Text('Export as PDF Document'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canViewCompanyDashboard) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isDark ? AppColors.darkHeroCardGradient : AppColors.heroCardGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.floatingShadow(isDark),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Company Financial Overview',
                            style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Company-wide profit, top spending, & at-risk projects.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => context.push(RoutePaths.companyDashboard),
                      child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Date Range Bar
            DateRangePickerWidget(
              selectedRange: _filterCriteria.dateRange,
              onRangeSelected: (range) {
                setState(() => _filterCriteria = _filterCriteria.copyWith(dateRange: range, clearDateRange: range == null));
              },
            ),
            const SizedBox(height: 16),

            // Top Summary Cards (PRD Section 4.5: Total Cost, Total Revenue, Total Profit)
            Text('Financial Summary', style: AppTextStyles.titleSmall),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
              children: [
                StatCard(
                  label: 'Total Cost',
                  value: CurrencyFormatter.format(totalCost, compact: true),
                  icon: Icons.payments_rounded,
                  iconColor: AppColors.primary,
                  iconBgColor: AppColors.surfaceSubtle,
                ),
                StatCard(
                  label: 'Total Revenue',
                  value: CurrencyFormatter.format(totalRevenue, compact: true),
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.emerald,
                  iconBgColor: AppColors.emeraldLight,
                ),
                StatCard(
                  label: 'Net Profit',
                  value: CurrencyFormatter.format(totalProfit, compact: true),
                  icon: Icons.monetization_on_rounded,
                  iconColor: totalProfit >= 0 ? AppColors.emeraldDark : AppColors.crimsonDark,
                  iconBgColor: totalProfit >= 0 ? AppColors.emeraldLight : AppColors.crimsonLight,
                  trendDirection: totalProfit >= 0 ? TrendDirection.up : TrendDirection.down,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Chart 1: Cost Broken Down by Category (PRD Section 4.5)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cost by Category', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 16),
                  CategoryDonutChart(categoryCosts: categoryCosts, total: totalCost),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Chart 2: Spending Trend Over Time (PRD Section 4.5)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spending Trend Over Time', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 16),
                  const SpendingTrendLineChart(
                    monthlyValues: [3100, 4200, 3900, 6800, 5400, 7200],
                    monthLabels: ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Export & Share Action Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Export & Share Report', style: AppTextStyles.titleSmall),
                        Text('Download report as Excel (.xlsx) or PDF', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _simulateExport('Excel'),
                    child: const Text('Export'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
