import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/approve_reject_dialog.dart';
import '../../core/widgets/custom_filter_panel.dart';
import '../../core/widgets/custom_search_bar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/expense_model.dart';
import '../../state/category_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/user_management_provider.dart';

class ApprovalsQueueScreen extends ConsumerStatefulWidget {
  const ApprovalsQueueScreen({super.key});

  @override
  ConsumerState<ApprovalsQueueScreen> createState() => _ApprovalsQueueScreenState();
}

class _ApprovalsQueueScreenState extends ConsumerState<ApprovalsQueueScreen> {
  bool _isMultiSelectMode = false;
  final Set<String> _selectedExpenseIds = {};
  String _searchQuery = '';
  FilterCriteria _filterCriteria = const FilterCriteria();

  void _toggleSelectAll(List<ExpenseModel> pendingList) {
    setState(() {
      if (_selectedExpenseIds.length == pendingList.length) {
        _selectedExpenseIds.clear();
      } else {
        _selectedExpenseIds.clear();
        _selectedExpenseIds.addAll(pendingList.map((e) => e.id));
      }
    });
  }

  void _openFilter(List<dynamic> projects, List<dynamic> categories, List<dynamic> users) {
    CustomFilterPanel.show(
      context,
      initialCriteria: _filterCriteria,
      projects: projects.map((p) => {'id': p.id as String, 'name': p.name as String}).toList(),
      categories: categories.map((c) => {'id': c.id as String, 'name': c.name as String}).toList(),
      employees: users.map((u) => {'id': u.id as String, 'name': u.name as String}).toList(),
      showEmployeeFilter: true,
      showStatusFilter: false, // Queue is exclusively pending
      onApply: (criteria) => setState(() => _filterCriteria = criteria),
    );
  }

  Future<void> _handleInlineApprove(ExpenseModel expense) async {
    final confirm = await ApproveRejectDialog.showConfirmApprovalDialog(
      context,
      title: 'Approve Expense',
      message: 'Approve ${CurrencyFormatter.format(expense.amount)} claim by ${expense.employeeName}?',
    );

    if (confirm && mounted) {
      ref.read(expenseProvider.notifier).approveExpense(expense.id);
      NotificationBanner.showSuccess(context, 'Expense approved for ${expense.employeeName}.');
    }
  }

  Future<void> _handleInlineReject(ExpenseModel expense) async {
    final reason = await ApproveRejectDialog.showRejectDialog(
      context,
      title: 'Reject Expense Claim',
      subtitle: 'Provide a reason for ${expense.employeeName}.',
    );

    if (reason != null && mounted) {
      ref.read(expenseProvider.notifier).rejectExpense(expense.id, reason);
      NotificationBanner.showWarning(context, 'Expense claim rejected.');
    }
  }

  Future<void> _handleBatchApprove() async {
    if (_selectedExpenseIds.isEmpty) return;

    final confirm = await ApproveRejectDialog.showConfirmApprovalDialog(
      context,
      title: 'Batch Approve Claims',
      message: 'Approve ${_selectedExpenseIds.length} selected expenses simultaneously?',
    );

    if (confirm && mounted) {
      ref.read(expenseProvider.notifier).batchApprove(_selectedExpenseIds.toList());
      NotificationBanner.showSuccess(
        context,
        '${_selectedExpenseIds.length} expenses approved simultaneously.',
      );
      setState(() {
        _selectedExpenseIds.clear();
        _isMultiSelectMode = false;
      });
    }
  }

  Future<void> _handleBatchReject() async {
    if (_selectedExpenseIds.isEmpty) return;

    final reason = await ApproveRejectDialog.showRejectDialog(
      context,
      title: 'Batch Reject Claims',
      subtitle: 'Provide a rejection justification for all ${_selectedExpenseIds.length} claims.',
    );

    if (reason != null && mounted) {
      ref.read(expenseProvider.notifier).batchReject(_selectedExpenseIds.toList(), reason);
      NotificationBanner.showWarning(
        context,
        '${_selectedExpenseIds.length} expenses rejected simultaneously.',
      );
      setState(() {
        _selectedExpenseIds.clear();
        _isMultiSelectMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expenseProvider);
    final allProjects = ref.watch(projectProvider);
    final allCategories = ref.watch(categoryProvider);
    final allUsers = ref.watch(userManagementProvider);

    // Filter pending expenses across projects reviewer is assigned to
    final pendingExpenses = allExpenses.where((e) {
      if (e.status != ExpenseStatus.pending) return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = e.employeeName.toLowerCase().contains(q) ||
            e.projectName.toLowerCase().contains(q) ||
            e.categoryName.toLowerCase().contains(q) ||
            e.note.toLowerCase().contains(q) ||
            e.amount.toString().contains(q);
        if (!match) return false;
      }

      // Filter panel filters
      if (_filterCriteria.projectId != null && e.projectId != _filterCriteria.projectId) return false;
      if (_filterCriteria.categoryId != null && e.categoryId != _filterCriteria.categoryId) return false;
      if (_filterCriteria.employeeId != null && e.employeeId != _filterCriteria.employeeId) return false;

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approvals Queue'),
            Text(
              '${pendingExpenses.length} claims waiting for decision',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
            ),
          ],
        ),
        actions: [
          // Toggle Multi-Select Mode
          IconButton(
            icon: Icon(
              _isMultiSelectMode ? Icons.checklist_rtl_rounded : Icons.checklist_rounded,
              color: _isMultiSelectMode ? AppColors.indigo : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            ),
            tooltip: _isMultiSelectMode ? 'Exit Batch Mode' : 'Batch Select Mode',
            onPressed: () {
              setState(() {
                _isMultiSelectMode = !_isMultiSelectMode;
                if (!_isMultiSelectMode) _selectedExpenseIds.clear();
              });
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _filterCriteria.isActive,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter Queue',
            onPressed: () => _openFilter(allProjects, allCategories, allUsers),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CustomSearchBar(
              hintText: 'Search by employee, project, or amount...',
              initialValue: _searchQuery,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),

          // Multi-Select Action Banner
          if (_isMultiSelectMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? AppColors.indigo.withValues(alpha: 0.2) : AppColors.indigoLight,
              child: Row(
                children: [
                  Checkbox(
                    value: pendingExpenses.isNotEmpty &&
                        _selectedExpenseIds.length == pendingExpenses.length,
                    onChanged: (_) => _toggleSelectAll(pendingExpenses),
                  ),
                  Text(
                    '${_selectedExpenseIds.length} Selected',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.indigoDark),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.crimson),
                    label: Text('Reject (${_selectedExpenseIds.length})',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson)),
                    onPressed: _selectedExpenseIds.isEmpty ? null : _handleBatchReject,
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text('Approve (${_selectedExpenseIds.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: _selectedExpenseIds.isEmpty ? null : _handleBatchApprove,
                  ),
                ],
              ),
            ),
          ],

          // Queue List
          Expanded(
            child: pendingExpenses.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.done_all_rounded,
                    title: 'Approvals Queue Clear',
                    message: _searchQuery.isNotEmpty || _filterCriteria.isActive
                        ? 'No pending claims matched your filter criteria.'
                        : 'No pending expense claims currently require your review.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: pendingExpenses.length,
                    itemBuilder: (ctx, i) {
                      final exp = pendingExpenses[i];
                      final isSelected = _selectedExpenseIds.contains(exp.id);

                      return _QueueItemCard(
                        expense: exp,
                        isMultiSelectMode: _isMultiSelectMode,
                        isSelected: isSelected,
                        onToggleSelect: () {
                          setState(() {
                            if (isSelected) {
                              _selectedExpenseIds.remove(exp.id);
                            } else {
                              _selectedExpenseIds.add(exp.id);
                            }
                          });
                        },
                        onTap: () => context.push('/expenses/${exp.id}'),
                        onApprove: () => _handleInlineApprove(exp),
                        onReject: () => _handleInlineReject(exp),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueItemCard extends StatelessWidget {
  final ExpenseModel expense;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _QueueItemCard({
    required this.expense,
    required this.isMultiSelectMode,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? AppColors.indigo.withValues(alpha: 0.25) : AppColors.indigoLight.withValues(alpha: 0.3))
            : AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.indigo : AppColors.getBorder(context),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: InkWell(
        onTap: isMultiSelectMode ? onToggleSelect : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee header & Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMultiSelectMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelect(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Avatar initials
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                    child: Text(
                      expense.employeeName.isNotEmpty ? expense.employeeName[0] : 'U',
                      style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.employeeName,
                          style: AppTextStyles.titleSmall.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${expense.projectName} • ${DateFormatter.formatShort(expense.date)}',
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            CurrencyFormatter.format(expense.amount, currency: expense.currency),
                            style: AppTextStyles.currencySmall.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          expense.categoryName,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            color: AppColors.getTextMuted(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Note preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  expense.note,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextSecondary(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Inline Action Buttons (PRD Section 4.4: quick review directly from list)
              if (!isMultiSelectMode) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.crimson),
                      label: Text('Reject', style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        side: const BorderSide(color: AppColors.crimsonBorder),
                      ),
                      onPressed: onReject,
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: onApprove,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
