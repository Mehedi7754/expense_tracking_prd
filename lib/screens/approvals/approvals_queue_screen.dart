import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/approve_reject_dialog.dart';
import '../../core/widgets/custom_search_bar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/expense_model.dart';
import '../../models/user_model.dart';
import '../../state/expense_provider.dart';
import '../../state/user_management_provider.dart';
import '../../core/widgets/app_avatar.dart';

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

  Future<void> _handleBatchApprove() async {
    if (_selectedExpenseIds.isEmpty) return;
    final count = _selectedExpenseIds.length;
    final confirm = await ApproveRejectDialog.showConfirmApprovalDialog(
      context,
      title: 'Batch Approve Claims',
      message: 'Approve all $count selected claims at once?',
    );

    if (confirm && mounted) {
      await ref.read(expenseProvider.notifier).batchApprove(_selectedExpenseIds.toList());
      if (mounted) {
        NotificationBanner.showSuccess(context, 'Successfully batch approved $count claims.');
        setState(() {
          _selectedExpenseIds.clear();
          _isBatchMode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allExpenses = ref.watch(expenseProvider);
    final allUsers = ref.watch(userManagementProvider);
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
        title: Text(
          'Approvals (${pendingExpenses.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
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
          // Single Unified Search Bar with Integrated Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: CustomSearchBar(
              hintText: 'Search claimant, project...',
              initialValue: _searchQuery,
              onChanged: (q) => setState(() => _searchQuery = q),
              trailing: _buildFilterButton(pendingExpenses.length, isDark),
            ),
          ),

          const SizedBox(height: 4),

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
                      return _buildApprovalCard(context, exp, isDark, allUsers);
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildApprovalCard(BuildContext context, ExpenseModel exp, bool isDark, List<UserModel> allUsers) {
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
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
              : () => context.push('/expenses/${exp.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
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
                // Left profile avatar with category badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(
                      imageUrl: (exp.employeeAvatar != null && exp.employeeAvatar!.isNotEmpty)
                          ? exp.employeeAvatar
                          : allUsers.where((u) => u.id == exp.employeeId || u.name.toLowerCase() == exp.employeeName.toLowerCase()).firstOrNull?.avatarUrl,
                      name: exp.employeeName,
                      size: 48,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 10, color: iconColor),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Middle column: Claimant Name, Project & Relative Time, and Receipt Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exp.employeeName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exp.projectName} • ${DateFormatter.formatRelative(exp.date)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: exp.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              exp.hasReceipt ? 'Receipt Verified' : 'No Receipt',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: exp.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Right side: Amount and Approve Button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyFormatter.format(exp.amount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (!_isBatchMode) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleApprove(exp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                          label: const Text('Approve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(int totalCount, bool isDark) {
    final isFiltered = _activeFilter != 'all';
    final currentLabel = _filterApprovalLabel(_activeFilter);

    return PopupMenuButton<String>(
      initialValue: _activeFilter,
      tooltip: 'Filter Pending Approvals',
      onSelected: (val) => setState(() => _activeFilter = val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isFiltered
              ? const Color(0xFF4F46E5).withAlpha(isDark ? 50 : 25)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: isFiltered
              ? Border.all(color: const Color(0xFF4F46E5).withAlpha(80), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: isFiltered ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 4),
            Text(
              isFiltered ? currentLabel : 'Filter',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isFiltered ? FontWeight.w700 : FontWeight.w600,
                color: isFiltered ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isFiltered ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        _buildPopupItem('all', 'All Pending ($totalCount)', _activeFilter == 'all', isDark),
        _buildPopupItem('highAmount', 'High Amount (>৳10k)', _activeFilter == 'highAmount', isDark),
        _buildPopupItem('noReceipt', 'No Receipt', _activeFilter == 'noReceipt', isDark),
        _buildPopupItem('hasReceipt', 'With Receipt', _activeFilter == 'hasReceipt', isDark),
      ],
    );
  }

  String _filterApprovalLabel(String filter) {
    switch (filter) {
      case 'highAmount':
        return '>৳10k';
      case 'noReceipt':
        return 'No Rcpt';
      case 'hasReceipt':
        return 'Rcpt';
      default:
        return 'All';
    }
  }

  PopupMenuItem<String> _buildPopupItem(String value, String title, bool isSelected, bool isDark) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}
