import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/approve_reject_dialog.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/expense_model.dart';
import '../../state/expense_provider.dart';

class ApprovalsQueueScreen extends ConsumerStatefulWidget {
  const ApprovalsQueueScreen({super.key});

  @override
  ConsumerState<ApprovalsQueueScreen> createState() => _ApprovalsQueueScreenState();
}

class _ApprovalsQueueScreenState extends ConsumerState<ApprovalsQueueScreen> {
  String _activeFilter = 'all'; // all, highAmount, noReceipt, hasReceipt
  String _searchQuery = '';
  bool _isBatchMode = false;
  final Set<String> _selectedExpenseIds = {};

  Future<void> _handleApprove(ExpenseModel expense) async {
    final confirm = await ApproveRejectDialog.showConfirmApprovalDialog(
      context,
      title: 'Approve Claim',
      message: 'Approve ${CurrencyFormatter.format(expense.amount)} claim by ${expense.employeeName}?',
    );

    if (confirm && mounted) {
      ref.read(expenseProvider.notifier).approveExpense(expense.id);
      NotificationBanner.showSuccess(context, 'Claim approved for ${expense.employeeName}.');
    }
  }

  Future<void> _handleReject(ExpenseModel expense) async {
    final reason = await ApproveRejectDialog.showRejectDialog(
      context,
      title: 'Reject Claim',
      subtitle: 'Provide a reason for ${expense.employeeName}.',
    );

    if (reason != null && mounted) {
      ref.read(expenseProvider.notifier).rejectExpense(expense.id, reason);
      NotificationBanner.showWarning(context, 'Claim rejected.');
    }
  }

  Future<void> _handleBatchApprove() async {
    if (_selectedExpenseIds.isEmpty) return;
    final count = _selectedExpenseIds.length;
    final confirm = await ApproveRejectDialog.showConfirmApprovalDialog(
      context,
      title: 'Batch Approve Claims',
      message: 'Approve all $count selected claims at once?',
    );

    if (confirm && mounted) {
      for (final id in _selectedExpenseIds) {
        ref.read(expenseProvider.notifier).approveExpense(id);
      }
      NotificationBanner.showSuccess(context, 'Successfully batch approved $count claims.');
      setState(() {
        _selectedExpenseIds.clear();
        _isBatchMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allExpenses = ref.watch(expenseProvider);
    final pendingExpenses = allExpenses.where((e) => e.status == ExpenseStatus.pending).toList();

    // Filter logic
    final filtered = pendingExpenses.where((e) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = e.employeeName.toLowerCase().contains(q) ||
            e.projectName.toLowerCase().contains(q) ||
            e.categoryName.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_activeFilter == 'highAmount' && e.amount < 10000) return false;
      if (_activeFilter == 'noReceipt' && e.hasReceipt) return false;
      if (_activeFilter == 'hasReceipt' && !e.hasReceipt) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Text(
              'Approvals (${pendingExpenses.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
            if (pendingExpenses.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${pendingExpenses.length} Pending',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (pendingExpenses.isNotEmpty)
            TextButton.icon(
              icon: Icon(_isBatchMode ? Icons.close_rounded : Icons.checklist_rounded, size: 18),
              label: Text(_isBatchMode ? 'Cancel' : 'Batch Approve'),
              onPressed: () {
                setState(() {
                  _isBatchMode = !_isBatchMode;
                  _selectedExpenseIds.clear();
                });
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _isBatchMode
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: filtered.isNotEmpty && _selectedExpenseIds.length == filtered.length,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedExpenseIds.addAll(filtered.map((e) => e.id));
                          } else {
                            _selectedExpenseIds.clear();
                          }
                        });
                      },
                    ),
                    Text(
                      '${_selectedExpenseIds.length} of ${filtered.length} Selected',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _selectedExpenseIds.isEmpty ? null : _handleBatchApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: Text('Approve (${_selectedExpenseIds.length})'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (q) => setState(() => _searchQuery = q),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search claimant, project...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterPill('All (${pendingExpenses.length})', 'all', isDark),
                const SizedBox(width: 6),
                _buildFilterPill('High Amount (>৳10k)', 'highAmount', isDark),
                const SizedBox(width: 6),
                _buildFilterPill('No Receipt', 'noReceipt', isDark),
                const SizedBox(width: 6),
                _buildFilterPill('With Receipt', 'hasReceipt', isDark),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Minimalist Approval Cards List
          Expanded(
            child: filtered.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.done_all_rounded,
                    title: 'All Caught Up!',
                    message: pendingExpenses.isEmpty
                        ? 'There are no pending expense claims requiring your approval.'
                        : 'No pending claims match your search/filter.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24, top: 4),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final exp = filtered[i];
                      return _buildApprovalCard(context, exp, isDark);
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildApprovalCard(BuildContext context, ExpenseModel exp, bool isDark) {
    Color iconColor;
    Color iconBg;
    IconData icon;

    switch (exp.categoryId.toLowerCase()) {
      case 'food':
        iconColor = const Color(0xFFF59E0B);
        iconBg = const Color(0xFFFFFBEB);
        icon = Icons.restaurant_rounded;
        break;
      case 'transportation':
        iconColor = const Color(0xFF0D9488);
        iconBg = const Color(0xFFF0FDFA);
        icon = Icons.directions_car_rounded;
        break;
      case 'equipment':
        iconColor = const Color(0xFF4F46E5);
        iconBg = const Color(0xFFEEF2FF);
        icon = Icons.construction_rounded;
        break;
      case 'accommodation':
        iconColor = const Color(0xFF8B5CF6);
        iconBg = const Color(0xFFF5F3FF);
        icon = Icons.hotel_rounded;
        break;
      default:
        iconColor = const Color(0xFF0284C7);
        iconBg = const Color(0xFFF0F9FF);
        icon = Icons.receipt_rounded;
        break;
    }

    if (isDark) {
      iconBg = iconColor.withAlpha(25);
    }

    final isSelected = _selectedExpenseIds.contains(exp.id);

    return InkWell(
      onTap: _isBatchMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedExpenseIds.remove(exp.id);
                } else {
                  _selectedExpenseIds.add(exp.id);
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : (isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9)),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 25 : 8),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Squircle icon + Employee & Project + Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_isBatchMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedExpenseIds.add(exp.id);
                        } else {
                          _selectedExpenseIds.remove(exp.id);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Icon(icon, color: iconColor, size: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${exp.projectName} • ${DateFormatter.formatRelative(exp.date)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(exp.amount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: exp.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          exp.hasReceipt ? 'Receipt' : 'No Receipt',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: exp.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            if (exp.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                exp.note,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (!_isBatchMode) ...[
              const SizedBox(height: 14),
              // Action Buttons: Approve & Reject grouped closely on wide devices
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 500;
                  final rejectBtn = SizedBox(
                    height: 38,
                    width: isWide ? 120 : null,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleReject(exp),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  );

                  final approveBtn = SizedBox(
                    height: 38,
                    width: isWide ? 130 : null,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleApprove(exp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  );

                  return isWide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            rejectBtn,
                            const SizedBox(width: 10),
                            approveBtn,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: rejectBtn),
                            const SizedBox(width: 10),
                            Expanded(child: approveBtn),
                          ],
                        );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String value, bool isDark) {
    final isSelected = _activeFilter == value;

    return InkWell(
      onTap: () => setState(() => _activeFilter = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}
