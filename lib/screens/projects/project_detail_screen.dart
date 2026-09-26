import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/project_cost_card.dart';
import '../../core/widgets/receipt_compliance_badge.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 4 Tabs: Financial Overview, Budget vs Actual, Expenses & Receipts, Revenue & Closing
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showUpdateRemainingCostDialog(BuildContext context, ProjectModel project) {
    final controller = TextEditingController(text: project.estimatedRemainingCost.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Estimated Remaining Cost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter projected future expenses needed to complete this project. This updates the Financial Forecast.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated Remaining Cost (৳)',
                prefixText: '৳ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim()) ?? 0.0;
              ref.read(projectProvider.notifier).updateEstimatedRemainingCost(project.id, val);
              Navigator.pop(ctx);
              NotificationBanner.showSuccess(context, 'Financial forecast updated');
            },
            child: const Text('Update Forecast'),
          ),
        ],
      ),
    );
  }

  void _showCloseProjectDialog(
    BuildContext context,
    ProjectModel project,
    List<ExpenseModel> expenses,
  ) {
    final directCost = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final officeBenefit = directCost * project.officeBenefitRate;
    final totalCost = directCost + officeBenefit;
    final totalRevenue = project.amountReceived;
    final profit = project.grossProjectValue - totalCost;
    final profitMargin = project.grossProjectValue > 0 ? (profit / project.grossProjectValue) * 100 : 0.0;
    final receivable = project.amountReceivable;

    final unreceiptedAmount = expenses.where((e) => !e.hasReceipt).fold<double>(0.0, (sum, e) => sum + e.amount);
    final receiptCompliance = directCost > 0 ? (((directCost - unreceiptedAmount) / directCost) * 100) : 100.0;
    final budgetVariance = project.budget > 0 ? (((totalCost - project.budget) / project.budget) * 100) : 0.0;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.archive_rounded, color: AppColors.getPrimary(context)),
              const SizedBox(width: 8),
              const Text('Close Project & Generate Summary'),
            ],
          ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Closing this project will archive it into Historical Cost Intelligence benchmarks for future project estimation.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
              ),
              const Divider(height: 20),
              _buildSummaryRow('Contract Value:', CurrencyFormatter.format(project.grossProjectValue)),
              _buildSummaryRow('Total Revenue Received:', CurrencyFormatter.format(totalRevenue)),
              _buildSummaryRow('Direct Expenditure:', CurrencyFormatter.format(directCost)),
              _buildSummaryRow('Office Benefit (30%):', CurrencyFormatter.format(officeBenefit)),
              _buildSummaryRow('Net Project Cost:', CurrencyFormatter.format(totalCost)),
              _buildSummaryRow('Project Profit:', CurrencyFormatter.format(profit), isBold: true),
              _buildSummaryRow('Profit Margin:', '${profitMargin.toStringAsFixed(1)}%', isBold: true),
              _buildSummaryRow('Outstanding Receivable:', CurrencyFormatter.format(receivable)),
              _buildSummaryRow('Receipt Compliance:', '${receiptCompliance.toStringAsFixed(1)}%'),
              _buildSummaryRow('Budget Variance:', '${budgetVariance.toStringAsFixed(1)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getPrimary(context),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final summary = ProjectFinancialSummary(
                contractValue: project.grossProjectValue,
                taxInfo: project.taxStatus.displayName,
                totalRevenue: totalRevenue,
                directExpenditure: directCost,
                officeBenefit: officeBenefit,
                netProjectCost: totalCost,
                profit: profit,
                profitMargin: profitMargin,
                totalReceivable: receivable,
                receiptComplianceRate: receiptCompliance,
                teamMembersCount: project.teamMemberIds.length,
                budgetVariance: budgetVariance,
                closedAt: DateTime.now(),
              );

              ref.read(projectProvider.notifier).closeProject(projectId: project.id, summary: summary);
              Navigator.pop(ctx);
              NotificationBanner.showSuccess(context, 'Project closed & archived to historical intelligence');
            },
            child: const Text('Confirm Close'),
          ),
        ],
      );
    },
  );
}

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);
    final user = ref.watch(authProvider).currentUser;
    final role = user?.role ?? UserRole.projectMember;

    final projectList = allProjects.where((p) => p.id == widget.projectId).toList();
    if (projectList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Record')),
        body: const Center(child: Text('Project not found.')),
      );
    }

    final project = projectList.first;
    final projectExpenses = allExpenses.where((e) => e.projectId == project.id).toList();

    final canEdit = role.canCreateProject;
    final canClose = role == UserRole.mainAdmin || role == UserRole.finance;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.projectId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.getPrimary(context))),
            Text(project.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Project Setup',
              onPressed: () => context.push('/projects/edit/${project.id}'),
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Financial Overview'),
            Tab(text: 'Budget vs Actual'),
            Tab(text: 'Expenses & Receipts'),
            Tab(text: 'Revenue & Closing'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, project, projectExpenses),
              _buildBudgetVsActualTab(context, project, projectExpenses),
              _buildExpensesTab(context, project, projectExpenses),
              _buildRevenueAndClosingTab(context, project, projectExpenses, canClose),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TAB 1: FINANCIAL OVERVIEW & FORECAST ====================
  Widget _buildOverviewTab(BuildContext context, ProjectModel project, List<ExpenseModel> expenses) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final directCost = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final officeBenefit = directCost * project.officeBenefitRate;
    final costIncurred = directCost + officeBenefit;
    final expectedRemaining = project.estimatedRemainingCost;
    final projectedFinalCost = costIncurred + expectedRemaining;
    final projectedProfit = project.grossProjectValue - projectedFinalCost;
    final projectedMargin = project.grossProjectValue > 0
        ? (projectedProfit / project.grossProjectValue) * 100
        : 0.0;

    final unreceiptedAmount = expenses.where((e) => !e.hasReceipt).fold<double>(0.0, (sum, e) => sum + e.amount);
    final unreceiptedRatio = directCost > 0 ? (unreceiptedAmount / directCost) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PRD Section 30 "Project Cost Card"
          ProjectCostCard(project: project, projectExpenses: expenses),

          const SizedBox(height: 12),

          // Minimalist Financial Forecast Card (SaaS Clean Style)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.analytics_outlined, color: Color(0xFF4F46E5), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Financial Forecast',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF4F46E5)),
                      tooltip: 'Edit Remaining Cost',
                      onPressed: () => _showUpdateRemainingCostDialog(context, project),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildForecastItem('Contract Value', CurrencyFormatter.format(project.grossProjectValue), isDark ? Colors.white : const Color(0xFF0F172A), isDark: isDark),
                Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9), height: 18),
                _buildForecastItem('Cost Incurred (inc. 30% OB)', CurrencyFormatter.format(costIncurred), const Color(0xFFD97706), isDark: isDark),
                Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9), height: 18),
                _buildForecastItem(
                  'Estimated Remaining Cost',
                  CurrencyFormatter.format(expectedRemaining),
                  const Color(0xFF2563EB),
                  isDark: isDark,
                  isEditable: true,
                  onEdit: () => _showUpdateRemainingCostDialog(context, project),
                ),
                Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9), height: 18),
                _buildForecastItem('Projected Final Cost', CurrencyFormatter.format(projectedFinalCost), isDark ? Colors.white : const Color(0xFF0F172A), isDark: isDark),
                const SizedBox(height: 14),

                // Clean Highlight Pill for Projected Profit & Margin
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: projectedProfit >= 0
                        ? (isDark ? const Color(0xFF064E3B).withAlpha(40) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0xFF7F1D1D).withAlpha(40) : const Color(0xFFFEF2F2)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: projectedProfit >= 0
                          ? (isDark ? const Color(0xFF059669).withAlpha(60) : const Color(0xFFA7F3D0))
                          : (isDark ? const Color(0xFFDC2626).withAlpha(60) : const Color(0xFFFECACA)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Projected Profit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: projectedProfit >= 0
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                                  : (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(projectedProfit),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: projectedProfit >= 0
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                                  : (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C)),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: projectedProfit >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${projectedMargin.toStringAsFixed(1)}% Margin',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Receipt Compliance Dual Indicator Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ReceiptComplianceBadge(
              unreceiptedAmount: unreceiptedAmount,
              unreceiptedRatio: unreceiptedRatio,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastItem(String label, String value, Color valueColor, {bool isDark = false, bool isBold = false, bool isEditable = false, VoidCallback? onEdit}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isEditable) ...[
              const SizedBox(width: 4),
              InkWell(onTap: onEdit, child: const Icon(Icons.edit, size: 13, color: Color(0xFF2563EB))),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ==================== TAB 2: BUDGET VS ACTUAL (PRD Section 14) ====================
  Widget _buildBudgetVsActualTab(BuildContext context, ProjectModel project, List<ExpenseModel> expenses) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = [
      {'name': 'Equipment', 'key': 'equipment', 'icon': Icons.precision_manufacturing_rounded},
      {'name': 'Transportation', 'key': 'transportation', 'icon': Icons.directions_car_rounded},
      {'name': 'Food', 'key': 'food', 'icon': Icons.restaurant_rounded},
      {'name': 'Accommodation', 'key': 'accommodation', 'icon': Icons.hotel_rounded},
      {'name': 'Office Cost', 'key': 'officecost', 'icon': Icons.business_rounded},
    ];

    double totalBudget = 0.0;
    double totalActual = 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Category Variance Analysis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Compares allocated budget versus actual costs incurred by category.', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.darkTextSecondary)),
        const SizedBox(height: 16),

        ...categories.map((cat) {
          final key = cat['key'] as String;
          final name = cat['name'] as String;
          final icon = cat['icon'] as IconData;

          final budget = project.categoryBudgets[key] ?? 0.0;
          final actual = expenses
              .where((e) => e.categoryName.toLowerCase().contains(name.toLowerCase().split(' ').first))
              .fold<double>(0.0, (sum, e) => sum + e.amount);

          final remaining = budget - actual;
          final variance = budget > 0 ? ((actual - budget) / budget) * 100 : 0.0;

          totalBudget += budget;
          totalActual += actual;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (actual > budget ? AppColors.error : AppColors.success).withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        actual > budget ? 'OVER' : 'ON TRACK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: actual > budget ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSubMetric('Budget', CurrencyFormatter.format(budget)),
                    _buildSubMetric('Actual', CurrencyFormatter.format(actual)),
                    _buildSubMetric('Remaining', CurrencyFormatter.format(remaining)),
                    _buildSubMetric('Variance', '${variance.toStringAsFixed(1)}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: budget > 0 ? (actual / budget).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(actual > budget ? AppColors.error : AppColors.primary),
                ),
              ],
            ),
          );
        }),

        // Office Benefit Row (PRD Section 9: 30%)
        Builder(builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final obColor = AppColors.getPrimary(context);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: obColor.withValues(alpha: isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: obColor.withValues(alpha: isDark ? 0.3 : 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.corporate_fare_rounded, size: 18, color: obColor),
                    const SizedBox(width: 8),
                    Text(
                      'Office Benefit (${(project.officeBenefitRate * 100).toInt()}%)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: obColor),
                    ),
                    const Spacer(),
                    Text('AUTO-CALCULATED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: obColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSubMetric('Budgeted OB', CurrencyFormatter.format(totalBudget * project.officeBenefitRate)),
                    _buildSubMetric('Actual OB', CurrencyFormatter.format(totalActual * project.officeBenefitRate)),
                    _buildSubMetric('Remaining', CurrencyFormatter.format((totalBudget - totalActual) * project.officeBenefitRate)),
                    _buildSubMetric('Rate', '${(project.officeBenefitRate * 100).toInt()}%'),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ==================== TAB 3: EXPENSES & RECEIPTS ====================
  Widget _buildExpensesTab(BuildContext context, ProjectModel project, List<ExpenseModel> expenses) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (expenses.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long_rounded,
        title: 'No Expenses Recorded',
        message: 'No expenses have been submitted for this project yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length,
      itemBuilder: (ctx, i) {
        final exp = expenses[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(exp.categoryName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    CurrencyFormatter.format(exp.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF4F46E5)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'By ${exp.employeeName} • ${DateFormatter.formatShort(exp.date)}',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(exp.note, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (exp.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exp.hasReceipt ? 'Receipt' : 'No Receipt',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: exp.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        if (!exp.hasReceipt)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exp.justificationStatus.displayName,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+30% OB: ৳${exp.officeBenefitAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== TAB 4: REVENUE & CLOSING (PRD Section 23) ====================
  Widget _buildRevenueAndClosingTab(
    BuildContext context,
    ProjectModel project,
    List<ExpenseModel> expenses,
    bool canClose,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Revenue Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Revenue & Invoicing Settlement', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Divider(height: 20),
              _buildSummaryRow('Gross Contract Value:', CurrencyFormatter.format(project.grossProjectValue)),
              _buildSummaryRow('Advance Received:', CurrencyFormatter.format(project.advanceReceived)),
              _buildSummaryRow('Total Received to Date:', CurrencyFormatter.format(project.amountReceived)),
              _buildSummaryRow('Outstanding Receivable:', CurrencyFormatter.format(project.amountReceivable), isBold: true),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // PRD Section 23 Project Closing Action
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: project.isClosed ? Colors.grey.withAlpha(20) : AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: project.isClosed ? Colors.grey : AppColors.primary.withAlpha(60),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    project.isClosed ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                    color: project.isClosed ? AppColors.success : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    project.isClosed ? 'Project Closed & Archived' : 'Project Closing (PRD Section 23)',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                project.isClosed
                    ? 'This project was formally closed. All financial records are preserved in historical benchmarks.'
                    : 'When all deliverables and final invoices are concluded, close the project to generate a comprehensive Financial Summary.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (!project.isClosed && canClose)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.archive_rounded),
                    label: const Text('Close Project & Generate Summary', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () => _showCloseProjectDialog(context, project, expenses),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
