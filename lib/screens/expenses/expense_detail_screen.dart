import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/approve_reject_dialog.dart';
import '../../core/widgets/comment_thread_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/receipt_uploader.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/expense_model.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/user_management_provider.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({
    super.key,
    required this.expenseId,
  });

  static (Color, Color, IconData) _getCategoryTheme(String categoryId, bool isDark) {
    Color iconColor;
    Color iconBg;
    IconData icon;

    switch (categoryId.toLowerCase()) {
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
    return (iconColor, iconBg, icon);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExpenses = ref.watch(expenseProvider);
    final user = ref.watch(authProvider).currentUser;

    final expenseList = allExpenses.where((e) => e.id == expenseId);
    if (expenseList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Detail')),
        body: const Center(child: Text('Expense record not found.')),
      );
    }

    final expense = expenseList.first;
    final isEmployeeOwner = user?.id == expense.employeeId;
    final isReviewer = user != null && user.role.canApproveExpenses;

    final isPending = expense.status == ExpenseStatus.pending;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allUsers = ref.watch(userManagementProvider);
    final submitterAvatar = (expense.employeeAvatar != null && expense.employeeAvatar!.isNotEmpty)
        ? expense.employeeAvatar
        : allUsers.where((u) => u.id == expense.employeeId || u.name.toLowerCase() == expense.employeeName.toLowerCase()).firstOrNull?.avatarUrl;

    final (catColor, catBg, catIcon) = _getCategoryTheme(expense.categoryId, isDark);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Expense Detail',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: StatusChip.fromExpenseStatus(expense.status)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. MAIN FINANCIAL SUMMARY CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Category Icon squircle + Category Name + Date
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: catBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(catIcon, color: catColor, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense.categoryName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  expense.projectName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Large bold claim amount
                      Text(
                        'Total Direct Cost',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(expense.amount, currency: expense.currency),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),

                      if (expense.hasTax) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Tax Calculation Breakdown',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withAlpha(25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${expense.taxRate.toStringAsFixed(expense.taxRate.truncateToDouble() == expense.taxRate ? 0 : 1)}% Tax',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Base Cost:', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                                  Text(CurrencyFormatter.format(expense.baseCost, currency: expense.currency), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Tax Rate:', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                                  Text('${expense.taxRate.toStringAsFixed(expense.taxRate.truncateToDouble() == expense.taxRate ? 0 : 1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Tax Amount:', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                                  Text('+ ${CurrencyFormatter.format(expense.taxAmount, currency: expense.currency)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                                ],
                              ),
                              Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text('Total Cost:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(CurrencyFormatter.format(expense.totalCost, currency: expense.currency), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 16),

                      // Metadata Rows
                      _DetailRow(
                        label: 'Submitted By',
                        value: expense.employeeName,
                        avatarUrl: submitterAvatar,
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: 'Expense Date',
                        value: DateFormatter.formatWithDay(expense.date),
                        icon: Icons.calendar_today_rounded,
                        isDark: isDark,
                      ),
                      if (expense.taskTitle != null) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Assigned Task',
                          value: expense.taskTitle!,
                          icon: Icons.task_alt_rounded,
                          isDark: isDark,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_outlined,
                            size: 16,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Receipt Status',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: expense.hasReceipt
                                  ? (isDark ? const Color(0xFF064E3B).withAlpha(40) : const Color(0xFFECFDF5))
                                  : (isDark ? const Color(0xFF7F1D1D).withAlpha(40) : const Color(0xFFFEF2F2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  expense.hasReceipt ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  size: 13,
                                  color: expense.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  expense.hasReceipt ? 'Verified Receipt' : 'No Receipt (Justified)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: expense.hasReceipt ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. REJECTION REASON BANNER (If rejected)
                if (expense.status == ExpenseStatus.rejected && expense.rejectionReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF7F1D1D).withAlpha(30) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFFDC2626).withAlpha(50) : const Color(0xFFFECACA),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Reason for Rejection',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          expense.rejectionReason!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 3. CATEGORY SPECIFIC BREAKDOWN CARD
                if (_hasCategoryBreakdown(expense)) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(catIcon, size: 18, color: catColor),
                            const SizedBox(width: 8),
                            Text(
                              '${expense.categoryName} Details',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), height: 1),
                        const SizedBox(height: 14),
                        ..._buildCategoryDetails(expense, isDark),
                      ],
                    ),
                  ),
                ],

                // 4. BUSINESS PURPOSE & NOTES
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business Purpose & Description',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        expense.note.trim().isEmpty ? 'No additional notes provided.' : expense.note,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. RECEIPT DOCUMENTATION
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt Documentation',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ReceiptUploader(
                        imagePath: expense.receiptPhotoUrl,
                        isReadOnly: true,
                        onImageChanged: (_) {},
                      ),
                    ],
                  ),
                ),

                // 6. COMMENT & CLARIFICATION THREAD
                const SizedBox(height: 16),
                CommentThreadWidget(
                  comments: expense.comments,
                  isReadOnly: false,
                  onAddComment: (text) {
                    if (user != null) {
                      ref.read(expenseProvider.notifier).addComment(
                            expenseId: expense.id,
                            text: text,
                            authorId: user.id,
                            authorName: user.name,
                            authorRole: user.role,
                          );
                      NotificationBanner.showSuccess(context, 'Comment posted to thread.');
                    }
                  },
                ),

                const SizedBox(height: 24),

                // 7. ACTION BUTTONS: REUSABLE & CONSISTENT
                // Employee Actions: Withdraw & Edit (when pending)
                if (isEmployeeOwner && isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            label: const Text(
                              'Withdraw Claim',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Withdraw Expense Claim?'),
                                  content: const Text('Are you sure you want to withdraw this pending expense claim?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Withdraw'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                ref.read(expenseProvider.notifier).withdrawExpense(expense.id);
                                NotificationBanner.showSuccess(context, 'Expense claim withdrawn.');
                                context.pop();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                            label: const Text(
                              'Edit Expense',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => context.push('/expenses/${expense.id}/edit'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Reviewer Actions: Reject & Approve (when pending)
                if (isReviewer && isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 18),
                            label: const Text(
                              'Reject',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final reason = await ApproveRejectDialog.showRejectDialog(
                                context,
                                title: 'Reject Expense Claim',
                                subtitle: 'Provide an explanatory reason for ${expense.employeeName}.',
                              );
                              if (reason != null && context.mounted) {
                                ref.read(expenseProvider.notifier).rejectExpense(expense.id, reason);
                                NotificationBanner.showWarning(context, 'Expense claim rejected.');
                                context.pop();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                            label: const Text(
                              'Approve Claim',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final confirm = await ApproveRejectDialog.showConfirmApprovalDialog(
                                context,
                                title: 'Approve Expense Claim',
                                message:
                                    'Approve ${CurrencyFormatter.format(expense.amount)} for ${expense.projectName}?',
                              );
                              if (confirm && context.mounted) {
                                ref.read(expenseProvider.notifier).approveExpense(expense.id);
                                NotificationBanner.showSuccess(context, 'Expense approved successfully.');
                                context.pop();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasCategoryBreakdown(ExpenseModel exp) {
    return exp.foodDetails != null ||
        exp.transportationDetails != null ||
        exp.accommodationDetails != null ||
        exp.equipmentDetails != null ||
        exp.officeCostDetails != null;
  }

  List<Widget> _buildCategoryDetails(ExpenseModel exp, bool isDark) {
    final list = <Widget>[];

    if (exp.foodDetails != null) {
      final f = exp.foodDetails!;
      list.add(_DetailRow(label: 'Meal Type', value: f.mealType, icon: Icons.fastfood_outlined, isDark: isDark));
      list.add(const SizedBox(height: 8));
      list.add(_DetailRow(label: 'Location / Restaurant', value: f.location, icon: Icons.place_outlined, isDark: isDark));
      list.add(const SizedBox(height: 8));
      list.add(_DetailRow(label: 'Number of People', value: '${f.numberOfPeople} Person(s)', icon: Icons.people_outline, isDark: isDark));
      if (f.attendees.isNotEmpty) {
        list.add(const SizedBox(height: 8));
        list.add(_DetailRow(label: 'Attendees', value: f.attendees, icon: Icons.badge_outlined, isDark: isDark));
      }
    } else if (exp.transportationDetails != null) {
      final t = exp.transportationDetails!;
      list.add(_DetailRow(label: 'Vehicle / Mode', value: t.transportationType.displayName, icon: Icons.directions_car_outlined, isDark: isDark));
      list.add(const SizedBox(height: 8));
      list.add(_DetailRow(label: 'Route', value: '${t.fromLocation} → ${t.toLocation}', icon: Icons.route_outlined, isDark: isDark));
      if (t.distanceKm != null && t.distanceKm! > 0) {
        list.add(const SizedBox(height: 8));
        list.add(_DetailRow(label: 'Distance', value: '${t.distanceKm} km', icon: Icons.straighten_outlined, isDark: isDark));
      }
      if (t.fuelCost != null && t.fuelCost! > 0) {
        list.add(const SizedBox(height: 8));
        list.add(_DetailRow(label: 'Fuel / CNG Cost', value: CurrencyFormatter.format(t.fuelCost!), icon: Icons.local_gas_station_outlined, isDark: isDark));
      }
    } else if (exp.accommodationDetails != null) {
      final a = exp.accommodationDetails!;
      list.add(_DetailRow(label: 'Hotel / Accommodation', value: a.hotelName, icon: Icons.hotel_outlined, isDark: isDark));
      list.add(const SizedBox(height: 8));
      list.add(_DetailRow(label: 'Location', value: a.location, icon: Icons.location_on_outlined, isDark: isDark));
      list.add(const SizedBox(height: 8));
      list.add(_DetailRow(label: 'Nights Stayed', value: '${a.numberOfNights} Night(s)', icon: Icons.night_shelter_outlined, isDark: isDark));
      list.add(const SizedBox(height: 8));
      list.add(_DetailRow(label: 'Rate per Night', value: CurrencyFormatter.format(a.ratePerNight), icon: Icons.payments_outlined, isDark: isDark));
    } else if (exp.equipmentDetails != null) {
      final eq = exp.equipmentDetails!;
      list.add(_DetailRow(label: 'Equipment Type', value: eq.equipmentType, icon: Icons.hardware_outlined, isDark: isDark));
      list.add(const SizedBox(height: 8));
      list.add(_DetailRow(label: 'Type', value: eq.isRental ? 'Rental' : 'Purchase', icon: Icons.info_outline, isDark: isDark));
      list.add(const SizedBox(height: 8));
      list.add(_DetailRow(label: 'Quantity', value: '${eq.quantity}', icon: Icons.format_list_numbered_rounded, isDark: isDark));
      if (eq.rentalPeriod.isNotEmpty) {
        list.add(const SizedBox(height: 8));
        list.add(_DetailRow(label: 'Rental Period', value: eq.rentalPeriod, icon: Icons.timelapse_rounded, isDark: isDark));
      }
    } else if (exp.officeCostDetails != null) {
      final o = exp.officeCostDetails!;
      list.add(_DetailRow(label: 'Expense Sub-Type', value: o.subCategory, icon: Icons.work_outline, isDark: isDark));
    }

    return list;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final String? avatarUrl;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (avatarUrl != null || label == 'Submitted By') ...[
                AppAvatar(
                  imageUrl: avatarUrl,
                  name: value,
                  size: 26,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
