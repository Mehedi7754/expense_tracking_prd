import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/project_cost_card.dart';
import '../../core/widgets/project_progress_badge.dart';
import '../../core/widgets/receipt_compliance_badge.dart';
import '../../core/widgets/update_progress_dialog.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/user_role.dart';
import '../../core/routing/route_paths.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/user_management_provider.dart';
import '../../repositories/file_upload_repository.dart';

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
    final validExpenses = expenses.where((e) => e.status != ExpenseStatus.rejected);
    final directCost = validExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final officeBenefit = directCost * project.officeBenefitRate;
    final totalCost = directCost + officeBenefit;
    final totalRevenue = project.amountReceived;
    final profit = project.grossProjectValue - totalCost;
    final profitMargin = project.grossProjectValue > 0 ? (profit / project.grossProjectValue) * 100 : 0.0;
    final receivable = project.amountReceivable;

    final unreceiptedAmount = validExpenses.where((e) => !e.hasReceipt).fold<double>(0.0, (sum, e) => sum + e.amount);
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
    final canUpdateProgress = role.canUpdateProjectProgress;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              project.projectId,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.getPrimary(context),
              ),
            ),
            Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Upload Project Image',
              onPressed: () => _showImageSourcePicker(context, project),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Assign Project Members',
              onPressed: () => _showAssignMembersModal(context, project),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Project Setup',
              onPressed: () => context.push('/projects/edit/${project.id}'),
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
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
              _buildOverviewTab(context, project, projectExpenses, canUpdateProgress, canEdit),
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
  Widget _buildOverviewTab(
    BuildContext context,
    ProjectModel project,
    List<ExpenseModel> expenses,
    bool canUpdateProgress,
    bool canEdit,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final validExpenses = expenses.where((e) => e.status != ExpenseStatus.rejected);
    final directCost = validExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final totalTaxIncurred = validExpenses.fold<double>(0.0, (sum, e) => sum + e.taxAmount);
    final costIncurred = directCost;
    final expectedRemaining = project.estimatedRemainingCost;
    final projectedFinalCost = costIncurred + expectedRemaining;
    final projectedProfit = project.grossProjectValue - projectedFinalCost;
    final projectedMargin = project.grossProjectValue > 0
        ? (projectedProfit / project.grossProjectValue) * 100
        : 0.0;

    final unreceiptedAmount = validExpenses.where((e) => !e.hasReceipt).fold<double>(0.0, (sum, e) => sum + e.amount);
    final unreceiptedRatio = directCost > 0 ? (unreceiptedAmount / directCost) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Cover Image or Upload Prompt for Admin & PM
          if (project.imageUrl != null && project.imageUrl!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: isDark ? [] : AppColors.cardShadow,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _buildProjectBannerImage(project.imageUrl!),
                  ),
                  if (canEdit)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: InkWell(
                        onTap: () => _showImageSourcePicker(context, project),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text(
                                'Change Image',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ] else if (canEdit) ...[
            InkWell(
              onTap: () => _showImageSourcePicker(context, project),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.getPrimary(context).withAlpha(80),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.getPrimary(context).withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.getPrimary(context),
                          size: 19,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload Project Cover Image',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add site photos or blueprints (Super Admin & Project Manager)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // PRD Section 30 "Project Cost Card"
          ProjectCostCard(project: project, projectExpenses: expenses),

          const SizedBox(height: 12),

          // Project Progress Tracking Card (Admin & Manager interactive controls)
          _buildProgressTrackingCard(context, project, canUpdateProgress),

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
                    Expanded(
                      child: Row(
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
                          Expanded(
                            child: Text(
                              'Financial Forecast',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
                _buildForecastItem('Cost Incurred', CurrencyFormatter.format(costIncurred), const Color(0xFFD97706), isDark: isDark),
                if (totalTaxIncurred > 0) ...[
                  Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9), height: 18),
                  _buildForecastItem('Total Tax Incurred', CurrencyFormatter.format(totalTaxIncurred), const Color(0xFF6366F1), isDark: isDark),
                ],
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
                      Expanded(
                        child: Column(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
          const SizedBox(height: 14),

          // Project Team Members Section
          _buildProjectMembersCard(context, project, canEdit),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildForecastItem(String label, String value, Color valueColor, {bool isDark = false, bool isBold = false, bool isEditable = false, VoidCallback? onEdit}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isEditable) ...[
                const SizedBox(width: 4),
                InkWell(onTap: onEdit, child: const Icon(Icons.edit, size: 13, color: Color(0xFF2563EB))),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
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

  // ==================== PROJECT PROGRESS TRACKING CARD ====================
  Widget _buildProgressTrackingCard(
    BuildContext context,
    ProjectModel project,
    bool canUpdateProgress,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = project.progressPercentage.clamp(0.0, 100.0);

    Color progressColor;
    if (pct <= 25.0) {
      progressColor = const Color(0xFFEF4444); // Red: 0 to 25%
    } else if (pct < 75.0) {
      progressColor = const Color(0xFFF59E0B); // Amber/Orange: 26 to 74%
    } else if (pct < 100.0) {
      progressColor = const Color(0xFF3B82F6); // Blue: 75 to 99%
    } else {
      progressColor = const Color(0xFF10B981); // Emerald Green: 100%
    }

    return Container(
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: progressColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.speed_rounded, color: progressColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Project Progress',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (canUpdateProgress)
                InkWell(
                  onTap: () => UpdateProgressDialog.show(context, project),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4F46E5).withAlpha(50)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 14, color: Color(0xFF4F46E5)),
                        SizedBox(width: 4),
                        Text(
                          'Update',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Percentage & Status Indicator Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: progressColor,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ProjectProgressBadge.fromProject(project),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),

          // Audit record
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  project.progressUpdatedAt != null
                      ? 'Last updated on ${DateFormatter.formatDateTime(project.progressUpdatedAt!)}'
                      : 'Progress not yet updated (initial state 0%)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== PROJECT TEAM MEMBERS CARD ====================
  Widget _buildProjectMembersCard(BuildContext context, ProjectModel project, bool canEdit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allUsers = ref.watch(userManagementProvider);
    final teamMembers = allUsers.where((u) => project.teamMemberIds.contains(u.id)).toList();

    return Container(
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
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Members',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${teamMembers.length} assigned member${teamMembers.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (canEdit) ...[
                IconButton(
                  tooltip: 'Assign Members',
                  icon: Icon(Icons.person_add_alt_1_rounded, size: 20, color: AppColors.getPrimary(context)),
                  onPressed: () => _showAssignMembersModal(context, project),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                tooltip: 'View Team',
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF8B5CF6)),
                onPressed: () => context.push(RoutePaths.projectTeam(project.id)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Team Member Chips / Avatars
          if (teamMembers.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No team members assigned yet. Admin and Project Manager can assign members to work on this project.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getPrimary(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                    label: const Text('Assign Project Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _showAssignMembersModal(context, project),
                  ),
                ],
              ],
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: teamMembers.map((member) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFF8B5CF6),
                          child: Text(
                            member.name.isNotEmpty ? member.name[0] : 'U',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(
                            member.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            member.role.displayName.split(' ').first,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
                          ),
                        ),
                        if (canEdit) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () async {
                              await ref.read(projectProvider.notifier).unassignMemberFromProject(project.id, member.id);
                              await ref.read(userManagementProvider.notifier).unassignUserFromProject(member.id, project.id);
                              if (context.mounted) {
                                NotificationBanner.showInfo(context, '${member.name} unassigned from ${project.name}');
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
            ),
            if (canEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.getPrimary(context),
                  side: BorderSide(color: AppColors.getPrimary(context).withAlpha(60)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                label: const Text('Manage & Assign Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () => _showAssignMembersModal(context, project),
              ),
            ],
          ],
        ],
      ),
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
              .where((e) =>
                  e.status != ExpenseStatus.rejected &&
                  e.categoryName.toLowerCase().contains(name.toLowerCase().split(' ').first))
              .fold<double>(0.0, (sum, e) => sum + e.amount);

          final remaining = budget - actual;
          final variance = budget > 0 ? ((actual - budget) / budget) * 100 : 0.0;

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
                  if (exp.hasTax) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Inc. ${exp.taxRate.toStringAsFixed(exp.taxRate.truncateToDouble() == exp.taxRate ? 0 : 1)}% Tax',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                    ),
                  ],
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

  Widget _buildProjectBannerImage(String path) {
    return AppImageHelper.buildImage(
      path: path,
      placeholder: () => Container(
        color: const Color(0xFF312E81),
        child: const Center(
          child: Icon(Icons.business_center_rounded, size: 40, color: Colors.white70),
        ),
      ),
    );
  }

  // ==================== REQUIREMENT 1: PROJECT IMAGE UPLOAD ====================
  Future<void> _pickAndApplyImage(BuildContext context, ProjectModel project, ImageSource source) async {
    try {
      final picker = ImagePicker();
      // Compression: downscale to max 1280x800 and quality 75 for optimal memory & network performance
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (picked != null) {
        final base64Uri = await AppImageHelper.fileToBase64DataUri(File(picked.path));
        // Apply immediately to state for zero-lag UI feedback
        final updatedWithUri = project.copyWith(imageUrl: base64Uri);
        await ref.read(projectProvider.notifier).updateProject(updatedWithUri);

        // Upload through file upload pipeline if online
        try {
          final uploadResult = await ref.read(fileUploadRepositoryProvider).upload(
            filePathOrDataUri: picked.path,
            category: UploadCategory.projects,
            entityId: project.id,
          );
          if (uploadResult.url.isNotEmpty && uploadResult.url != base64Uri) {
            final updatedWithUrl = project.copyWith(imageUrl: uploadResult.url);
            await ref.read(projectProvider.notifier).updateProject(updatedWithUrl);
          }
        } catch (_) {
          // If file endpoint was unreachable, the compressed base64 URI is already persisted to the project in DB
        }

        if (context.mounted) {
          NotificationBanner.showSuccess(context, 'Project cover image updated successfully');
        }
      }
    } catch (e) {
      if (context.mounted) {
        NotificationBanner.showError(context, 'Failed to upload project image: $e');
      }
    }
  }

  void _showImageSourcePicker(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Project Image',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a cover photo or banner for ${project.name}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF4F46E5)),
              ),
              title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Capture site or blueprints directly', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndApplyImage(context, project, ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_outlined, color: Color(0xFF0EA5E9)),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Select photo from local device library', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndApplyImage(context, project, ImageSource.gallery);
              },
            ),
            if (project.imageUrl != null && project.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
                title: const Text('Remove Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.red)),
                subtitle: const Text('Clear current project banner', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final updated = project.copyWith(clearImageUrl: true);
                  await ref.read(projectProvider.notifier).updateProject(updated);
                  if (context.mounted) {
                    NotificationBanner.showInfo(context, 'Project image removed');
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== REQUIREMENT 2: ASSIGN PROJECT MEMBERS ====================
  void _showAssignMembersModal(BuildContext context, ProjectModel project) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (modalCtx, ref, _) {
            return StatefulBuilder(
              builder: (modalContext, setModalState) {
                final allUsers = ref.watch(userManagementProvider);
                final currentProjects = ref.watch(projectProvider);
                final liveProject = currentProjects.firstWhere(
                  (p) => p.id == project.id,
                  orElse: () => project,
                );
                final assignedIds = liveProject.teamMemberIds.toSet();

            final filteredUsers = allUsers.where((u) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return u.name.toLowerCase().contains(q) ||
                  u.email.toLowerCase().contains(q) ||
                  u.department.toLowerCase().contains(q) ||
                  (u.designation?.toLowerCase().contains(q) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assign Project Members',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${assignedIds.length} members assigned to ${liveProject.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Search Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() => searchQuery = val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search members by name, email, department...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Member list
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              'No registered members found.',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (itemCtx, i) {
                              final u = filteredUsers[i];
                              final isAssigned = assignedIds.contains(u.id);

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isAssigned
                                      ? AppColors.getPrimary(context)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  child: Text(
                                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isAssigned ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        u.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: u.isApproved
                                            ? const Color(0xFF10B981).withAlpha(20)
                                            : const Color(0xFFF59E0B).withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        u.isApproved ? 'Approved' : 'Pending',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: u.isApproved ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${u.department} • ${u.role.displayName}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      u.email,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!u.isApproved) ...[
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        onPressed: () async {
                                          await ref.read(userManagementProvider.notifier).approveUser(u.id);
                                          setModalState(() {});
                                          if (context.mounted) {
                                            NotificationBanner.showSuccess(context, '${u.name} approved');
                                          }
                                        },
                                        child: const Text('Approve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Switch.adaptive(
                                      value: isAssigned,
                                      activeColor: AppColors.getPrimary(context),
                                      onChanged: (val) async {
                                        if (val) {
                                          await ref.read(projectProvider.notifier).assignMemberToProject(liveProject.id, u.id);
                                          await ref.read(userManagementProvider.notifier).assignUserToProject(u.id, liveProject.id);
                                          setModalState(() {});
                                          if (context.mounted) {
                                            NotificationBanner.showSuccess(
                                              context,
                                              '${u.name} assigned to ${liveProject.name}. They can now work on this project.',
                                            );
                                          }
                                        } else {
                                          await ref.read(projectProvider.notifier).unassignMemberFromProject(liveProject.id, u.id);
                                          await ref.read(userManagementProvider.notifier).unassignUserFromProject(u.id, liveProject.id);
                                          setModalState(() {});
                                          if (context.mounted) {
                                            NotificationBanner.showInfo(
                                              context,
                                              '${u.name} unassigned from ${liveProject.name}',
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  },
);
}
}
