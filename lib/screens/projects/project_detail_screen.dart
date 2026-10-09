import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/project_progress_badge.dart';
import '../../core/widgets/receipt_compliance_badge.dart';
import '../../core/widgets/update_progress_dialog.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/user_role.dart';
import '../../core/routing/route_paths.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/user_management_provider.dart';
import '../../state/chat_provider.dart';
import '../../repositories/file_upload_repository.dart';
import '../../repositories/chat_repository.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {

  void _showUpdateBudgetDialog(BuildContext context, ProjectModel project) {
    final contractController = TextEditingController(text: project.grossProjectValue.toStringAsFixed(0));
    final taxRateController = TextEditingController(text: project.taxRate.toStringAsFixed(1));
    final officeBenefitController = TextEditingController(text: (project.officeBenefitRate * 100.0).toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setState) {
            final gross = double.tryParse(contractController.text.trim()) ?? 0.0;
            final taxPct = double.tryParse(taxRateController.text.trim()) ?? 0.0;
            final taxAmount = gross * (taxPct / 100.0);
            final netAfterTax = gross - taxAmount;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Update Project Budget',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set contract value, tax rate, and project profit margin.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: contractController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Total Contract Value (Gross ৳)',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: taxRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Tax Rate (%)',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: officeBenefitController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Margin/Markup (%)',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // LIVE AFTER-TAX CALCULATION BREAKDOWN
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A).withAlpha(80) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Gross Contract:',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(gross),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Tax (${taxPct.toStringAsFixed(1)}%):',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '- ${CurrencyFormatter.format(taxAmount)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'After-Tax Value:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(netAfterTax),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final newGross = double.tryParse(contractController.text.trim()) ?? project.grossProjectValue;
                    final newTax = double.tryParse(taxRateController.text.trim()) ?? project.taxRate;
                    final newBenefit = (double.tryParse(officeBenefitController.text.trim()) ?? (project.officeBenefitRate * 100)) / 100.0;
                    final newNet = newTax > 0 ? newGross * (1.0 - (newTax / 100.0)) : newGross;

                    final updated = project.copyWith(
                      grossProjectValue: newGross,
                      taxRate: newTax,
                      expectedNetRevenue: newNet,
                      officeBenefitRate: newBenefit,
                      budget: newGross,
                    );
                    ref.read(projectProvider.notifier).updateProject(updated);
                    Navigator.pop(ctx);
                    NotificationBanner.showSuccess(context, 'Project budget updated successfully');
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUpdateRemainingCostDialog(BuildContext context, ProjectModel project) {
    final controller = TextEditingController(text: project.estimatedRemainingCost.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Needed to Finish',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter additional money needed to finish this project. This immediately updates your profit forecast.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Needed to Finish (৳)',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.trim()) ?? 0.0;
              ref.read(projectProvider.notifier).updateEstimatedRemainingCost(project.id, val);
              Navigator.pop(ctx);
              NotificationBanner.showSuccess(context, 'Profit forecast updated');
            },
            child: const Text('Save'),
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
    final validExpenses = expenses.where((e) => e.status == ExpenseStatus.approved);
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

  void _showDeleteProjectDialog(BuildContext context, ProjectModel project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Project',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${project.name}" (${project.projectId})?\n\nThis will permanently purge all budget records, team assignments, and revenue settlements. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(projectProvider.notifier).deleteProject(project.id);
              if (context.mounted) {
                context.pop();
                NotificationBanner.showInfo(context, 'Project "${project.name}" deleted successfully');
              }
            },
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddRevenueDialog(BuildContext context, ProjectModel project) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Record Project Revenue'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Revenue Amount (৳)',
                    prefixText: '৳ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Note / Invoice Ref',
                    hintText: 'e.g. Milestone 1 Invoice #104',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment Date',
                      suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(DateFormatter.formatShort(selectedDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amount <= 0) {
                  NotificationBanner.showError(context, 'Please enter a valid positive amount');
                  return;
                }
                final user = ref.read(authProvider).currentUser;
                await ref.read(projectProvider.notifier).addRevenue(
                  projectId: project.id,
                  amount: amount,
                  date: selectedDate,
                  note: noteController.text.trim(),
                  createdBy: user?.name ?? 'Admin',
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  NotificationBanner.showSuccess(context, 'Revenue entry recorded successfully');
                }
              },
              child: const Text('Save Revenue'),
            ),
          ],
        ),
      ),
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
    List<ExpenseModel> projectExpenses = allExpenses.where((e) => e.projectId == project.id).toList();

    final canEdit = role.canCreateProject;
    final canClose = role == UserRole.mainAdmin || role == UserRole.finance;
    final canUpdateProgress = role.canUpdateProjectProgress;
    final canViewFinancials = role == UserRole.mainAdmin || role == UserRole.finance || role == UserRole.projectManager;

    if (!canViewFinancials) {
      projectExpenses = projectExpenses.where((e) => e.employeeId == user?.id).toList();
    }

    final List<Widget> tabs = [];
    final List<Widget> tabViews = [];

    if (canViewFinancials) {
      tabs.add(const Tab(text: 'Financial Overview'));
      tabViews.add(_buildOverviewTab(context, project, projectExpenses, canUpdateProgress, canEdit));
      
      tabs.add(const Tab(text: 'Budget vs Actual'));
      tabViews.add(_buildBudgetVsActualTab(context, project, projectExpenses));
    }

    tabs.add(const Tab(text: 'Expenses & Receipts'));
    tabViews.add(_buildExpensesTab(context, project, projectExpenses));

    if (canViewFinancials) {
      tabs.add(const Tab(text: 'Revenue & Closing'));
      tabViews.add(_buildRevenueAndClosingTab(context, project, projectExpenses, canClose));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
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
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF475569),
              ),
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: () {
                ref.read(settingsProvider.notifier).toggleTheme(!isDark);
              },
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Color(0xFF2563EB)),
              tooltip: 'Project Team Chat',
              onPressed: () async {
                try {
                  final repo = ref.read(chatRepositoryProvider);
                  final channelId = await repo.getOrCreateProjectChannel(project.id);
                  if (context.mounted && channelId.isNotEmpty) {
                    ref.read(chatChannelsProvider.notifier).fetchChannels(silent: true);
                    context.push(RoutePaths.chatThread(channelId));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to open project chat: $e')),
                    );
                  }
                }
              },
            ),
            if (canEdit)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Project Options',
                onSelected: (val) {
                  switch (val) {
                    case 'edit':
                      context.push(RoutePaths.editProject(project.id));
                      break;
                    case 'members':
                      _showAssignMembersModal(context, project);
                      break;
                    case 'image':
                      _showImageSourcePicker(context, project);
                      break;
                    case 'delete':
                      _showDeleteProjectDialog(context, project);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text('Edit Project'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'members',
                    child: Row(
                      children: [
                        Icon(Icons.person_add_alt_1_outlined, size: 18, color: Color(0xFF4F46E5)),
                        SizedBox(width: 8),
                        Text('Assign Members'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'image',
                    child: Row(
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 18, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Text('Change Image'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Delete Project', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: tabs,
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: TabBarView(
              children: tabViews,
            ),
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

    final validExpenses = expenses.where((e) => e.status == ExpenseStatus.approved);
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
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. UNIFIED HERO PROGRESS & COVER CARD (At the very top)
          _buildUnifiedHeroProgressCard(context, project, canUpdateProgress, canEdit),
          const SizedBox(height: 6),

          // 2. EXECUTIVE FINANCIAL OVERVIEW COCKPIT (Directly beneath Hero)
          _buildFinancialCockpitCard(
            context: context,
            project: project,
            costIncurred: costIncurred,
            expectedRemaining: expectedRemaining,
            projectedFinalCost: projectedFinalCost,
            projectedProfit: projectedProfit,
            projectedMargin: projectedMargin,
            totalTaxIncurred: totalTaxIncurred,
            expenseCount: validExpenses.length,
            isDark: isDark,
          ),
          const SizedBox(height: 6),

          // 4. Project Scope & Contract Profile Panel (Bento Style)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.08 : 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.getPrimary(context).withAlpha(18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.business_center_rounded, color: AppColors.getPrimary(context), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Project Scope & Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Official contract parameters & assignment details',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Grid stats for Client and Contract
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CLIENT / SPONSOR',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  project.client.isNotEmpty ? project.client : 'Direct Assignment',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 32, color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CONTRACT TYPE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  project.assignmentType.displayName,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4F46E5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _buildForecastItem('Tax & VAT Provision', project.taxStatus.displayName.replaceAll('IT-VAT: ', 'Tax '), const Color(0xFF0D9488), isDark: isDark),
                Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9), height: 16),
                _buildForecastItem(
                  'Project Lifespan',
                  '${DateFormatter.formatShort(project.startDate)} → ${DateFormatter.formatShort(project.endDate)}',
                  isDark ? Colors.white70 : const Color(0xFF334155),
                  isDark: isDark,
                ),
                if (project.description.isNotEmpty) ...[
                  Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9), height: 16),
                  Text(
                    'Scope Summary:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.description,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 5. Receipt Compliance Dual Indicator Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ReceiptComplianceBadge(
              unreceiptedAmount: unreceiptedAmount,
              unreceiptedRatio: unreceiptedRatio,
            ),
          ),
          const SizedBox(height: 14),

          // 6. Project Team Members Section
          _buildProjectMembersCard(context, project, canEdit),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== FINANCIAL COCKPIT (BENTO MASTERPIECE) ====================
  Widget _buildFinancialCockpitCard({
    required BuildContext context,
    required ProjectModel project,
    required double costIncurred,
    required double expectedRemaining,
    required double projectedFinalCost,
    required double projectedProfit,
    required double projectedMargin,
    required double totalTaxIncurred,
    required int expenseCount,
    required bool isDark,
  }) {
    final grossContract = project.grossProjectValue;
    final taxRate = project.taxRate;
    final expectedNet = project.expectedNetRevenue > 0
        ? project.expectedNetRevenue
        : (taxRate > 0 ? grossContract * (1.0 - (taxRate / 100.0)) : grossContract);
    final afterTaxProfit = expectedNet - projectedFinalCost;
    final afterTaxMargin = expectedNet > 0 ? (afterTaxProfit / expectedNet) * 100.0 : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Quick Actions (Never truncated)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;

              final budgetButton = InkWell(
                onTap: () => _showUpdateBudgetDialog(context, project),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4F46E5).withAlpha(50)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 13, color: Color(0xFF4F46E5)),
                      SizedBox(width: 4),
                      Text(
                        'Budget',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final neededButton = InkWell(
                onTap: () => _showUpdateRemainingCostDialog(context, project),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2563EB).withAlpha(50)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Needed',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withAlpha(18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: Color(0xFF4F46E5), size: 19),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Financial Overview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Budget & profit forecast',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        budgetButton,
                        const SizedBox(width: 8),
                        neededButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Color(0xFF4F46E5), size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial Overview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Budget & profit forecast',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  budgetButton,
                  const SizedBox(width: 6),
                  neededButton,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 2x2 Bento Metric Tiles
          Row(
            children: [
              // Tile 1: Total Budget
              Expanded(
                child: _buildBentoMetricTile(
                  title: 'TOTAL BUDGET',
                  value: CurrencyFormatter.format(project.grossProjectValue),
                  subtitle: 'Agreed Contract',
                  icon: Icons.account_balance_wallet_outlined,
                  valueColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  iconColor: const Color(0xFF4F46E5),
                  bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderColor: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(width: 10),
              // Tile 2: TOTAL SPENT
              Expanded(
                child: _buildBentoMetricTile(
                  title: 'TOTAL SPENT',
                  value: CurrencyFormatter.format(costIncurred),
                  subtitle: '$expenseCount recorded',
                  icon: Icons.receipt_long_outlined,
                  valueColor: const Color(0xFFD97706),
                  iconColor: const Color(0xFFD97706),
                  bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                  borderColor: isDark ? const Color(0xFFF59E0B).withAlpha(40) : const Color(0xFFFDE68A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Tile 3: Needed to Finish
              Expanded(
                child: InkWell(
                  onTap: () => _showUpdateRemainingCostDialog(context, project),
                  borderRadius: BorderRadius.circular(14),
                  child: _buildBentoMetricTile(
                    title: 'NEEDED TO FINISH',
                    value: CurrencyFormatter.format(expectedRemaining),
                    subtitle: 'Tap to update ✎',
                    icon: Icons.edit_note_rounded,
                    valueColor: const Color(0xFF2563EB),
                    iconColor: const Color(0xFF2563EB),
                    bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderColor: isDark ? const Color(0xFF3B82F6).withAlpha(50) : const Color(0xFFBFDBFE),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Tile 4: After-Tax Profit KPI
              Expanded(
                child: _buildBentoMetricTile(
                  title: 'AFTER-TAX PROFIT',
                  value: CurrencyFormatter.format(afterTaxProfit),
                  subtitle: '${afterTaxMargin.toStringAsFixed(1)}% Net Margin',
                  icon: afterTaxProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  valueColor: afterTaxProfit >= 0
                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                      : (isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C)),
                  iconColor: afterTaxProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  bgColor: afterTaxProfit >= 0
                      ? (isDark ? const Color(0xFF064E3B).withAlpha(40) : const Color(0xFFECFDF5))
                      : (isDark ? const Color(0xFF7F1D1D).withAlpha(40) : const Color(0xFFFEF2F2)),
                  borderColor: afterTaxProfit >= 0
                      ? (isDark ? const Color(0xFF059669).withAlpha(60) : const Color(0xFFA7F3D0))
                      : (isDark ? const Color(0xFFDC2626).withAlpha(60) : const Color(0xFFFECACA)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bottom summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withAlpha(60) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Expected Total Cost:',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.format(projectedFinalCost),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Pre-Tax Profit & Net Revenue Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withAlpha(40) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Pre-Tax Profit: ${CurrencyFormatter.format(projectedProfit)} (${projectedMargin.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tax: ${taxRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          if (totalTaxIncurred > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withAlpha(40) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Tax Incurred on Expenses:',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.format(totalTaxIncurred),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBentoMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color valueColor,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: iconColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: valueColor.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 15 : 13,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== UNIFIED HERO PROGRESS & COVER CARD ====================
  Widget _buildUnifiedHeroProgressCard(
    BuildContext context,
    ProjectModel project,
    bool canUpdateProgress,
    bool canEdit,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = project.progressPercentage.clamp(0.0, 100.0);
    final hasImage = project.imageUrl != null && project.imageUrl!.isNotEmpty;
    final notesCount = project.progressNotes.length;

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(isDark ? 30 : 12),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Section: Image Banner or Compact Header
            if (hasImage)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildProjectBannerImage(project.imageUrl!),
                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withAlpha(60),
                              Colors.transparent,
                              Colors.black.withAlpha(160),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Change image button for managers/admins
                    if (canEdit)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: InkWell(
                          onTap: () => _showImageSourcePicker(context, project),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(160),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_outlined, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Change',
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
                    // Bottom title badge on image
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 10,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(180),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              project.projectId,
                              style: const TextStyle(
                                color: Color(0xFF60A5FA),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              project.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (canEdit)
              InkWell(
                onTap: () => _showImageSourcePicker(context, project),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withAlpha(80) : const Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 16, color: AppColors.getPrimary(context)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Add Project Cover Image',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Section: Progress metrics, Bar, and Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 360;
                      final actionsRow = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Notes History Button (Visible to all employees)
                          InkWell(
                            onTap: () => context.push(RoutePaths.projectNotes(project.id)),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withAlpha(16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF0D9488).withAlpha(50)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.comment_outlined, size: 12, color: Color(0xFF0D9488)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Notes ($notesCount)',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0D9488),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (canUpdateProgress) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => UpdateProgressDialog.show(context, project),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withAlpha(16),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF4F46E5).withAlpha(50)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tune_rounded, size: 12, color: Color(0xFF4F46E5)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Update',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: progressColor.withAlpha(22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.speed_rounded, color: progressColor, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overall Progress',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        '${pct.toStringAsFixed(0)}% Completed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: progressColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            actionsRow,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: progressColor.withAlpha(22),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.speed_rounded, color: progressColor, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overall Progress',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${pct.toStringAsFixed(0)}% Completed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: progressColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          actionsRow,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

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
                  const SizedBox(height: 10),

                  // Audit record + stage badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                project.progressUpdatedAt != null
                                    ? 'Updated ${DateFormatter.formatShort(project.progressUpdatedAt!)}'
                                    : 'Initial state 0%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ProjectProgressBadge.fromProject(project),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
                        AppAvatar(
                          imageUrl: member.avatarUrl,
                          name: member.name,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          member.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
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
    final defaultCategories = [
      {'name': 'Equipment', 'key': 'equipment', 'icon': Icons.precision_manufacturing_rounded},
      {'name': 'Transportation', 'key': 'transportation', 'icon': Icons.directions_car_rounded},
      {'name': 'Food', 'key': 'food', 'icon': Icons.restaurant_rounded},
      {'name': 'Accommodation', 'key': 'accommodation', 'icon': Icons.hotel_rounded},
      {'name': 'Office Cost', 'key': 'officecost', 'icon': Icons.business_rounded},
    ];

    final customCategories = <Map<String, dynamic>>[];
    final standardKeys = {'equipment', 'transportation', 'food', 'accommodation', 'officecost', 'officebenefit'};
    project.categoryBudgets.forEach((k, v) {
      if (!standardKeys.contains(k.toLowerCase()) && !k.startsWith('_meta_')) {
        customCategories.add({
          'name': k,
          'key': k,
          'icon': Icons.category_rounded,
        });
      }
    });

    final categories = [...defaultCategories, ...customCategories];

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
                  e.status == ExpenseStatus.approved &&
                  e.categoryName.toLowerCase().contains(name.toLowerCase().split(' ').first))
              .fold<double>(0.0, (sum, e) => sum + e.amount);

          final remainingOrOverrun = (budget - actual).abs();
          final variance = budget > 0 ? ((actual - budget) / budget) * 100 : (actual > 0 ? 100.0 : 0.0);

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
                    _buildSubMetric(actual > budget ? 'Overrun' : 'Remaining', CurrencyFormatter.format(remainingOrOverrun)),
                    _buildSubMetric('Variance', '${variance.toStringAsFixed(1)}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: budget > 0 ? (actual / budget).clamp(0.0, 1.0) : (actual > 0 ? 1.0 : 0.0),
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

    final allUsers = ref.watch(userManagementProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length,
      itemBuilder: (ctx, i) {
        final exp = expenses[i];
        final submitterAvatar = (exp.employeeAvatar != null && exp.employeeAvatar!.isNotEmpty)
            ? exp.employeeAvatar
            : allUsers.where((u) => u.id == exp.employeeId || u.name.toLowerCase() == exp.employeeName.toLowerCase()).firstOrNull?.avatarUrl;

        return InkWell(
          onTap: () => context.push(RoutePaths.expenseDetail(exp.id)),
          borderRadius: BorderRadius.circular(14),
          child: Container(
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
                  children: [
                    AppAvatar(
                      imageUrl: submitterAvatar,
                      name: exp.employeeName,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exp.employeeName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${exp.categoryName} • ${DateFormatter.formatShort(exp.date)}',
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(exp.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
                if (exp.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(exp.note, style: const TextStyle(fontSize: 13)),
                ],
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
                        StatusChip.fromExpenseStatus(exp.status),
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
              if (exp.status == ExpenseStatus.rejected) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_rounded, size: 14, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Rejected: ${exp.rejectionReason != null && exp.rejectionReason!.isNotEmpty ? exp.rejectionReason : "No reason provided"}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Revenue & Invoicing Settlement',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Revenue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _showAddRevenueDialog(context, project),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildSummaryRow('Gross Contract Value:', CurrencyFormatter.format(project.grossProjectValue)),
              _buildSummaryRow('Advance Received:', CurrencyFormatter.format(project.advanceReceived)),
              _buildSummaryRow('Total Received to Date:', CurrencyFormatter.format(project.amountReceived)),
              _buildSummaryRow('Outstanding Receivable:', CurrencyFormatter.format(project.amountReceivable), isBold: true),
              
              if (project.revenueEntries.isNotEmpty) ...[
                const Divider(height: 20),
                Text(
                  'Recorded Payments (${project.revenueEntries.length}):',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...project.revenueEntries.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${DateFormatter.formatShort(r.date)} ${r.note.isNotEmpty ? '• ${r.note}' : ''}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(r.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                )),
              ],
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

        const SizedBox(height: 20),

        // Danger Zone: Delete Project Option
        if (canClose)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Danger Zone: Delete Project',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Deleting this project will permanently remove all budget allocations, team assignments, and revenue records.',
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Delete Project', style: TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () => _showDeleteProjectDialog(context, project),
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
                                leading: AppAvatar(
                                  imageUrl: u.avatarUrl,
                                  name: u.name,
                                  size: 40,
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
                                    ),
                                    Text(
                                      u.email,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                                      ),
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
                                      activeThumbColor: AppColors.getPrimary(context),
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
