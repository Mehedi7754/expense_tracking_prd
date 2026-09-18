import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/approve_reject_dialog.dart';
import '../../core/widgets/comment_thread_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/receipt_uploader.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/expense_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({
    super.key,
    required this.expenseId,
  });

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
    final isReviewer = user != null &&
        (user.role == UserRole.manager ||
            user.role == UserRole.finance ||
            user.role == UserRole.admin);

    final isPending = expense.status == ExpenseStatus.pending;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Expense Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: StatusChip.fromExpenseStatus(expense.status)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Financial Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Claim Amount', style: AppTextStyles.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(expense.amount, currency: expense.currency),
                      style: AppTextStyles.currencyLarge.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Project',
                      value: expense.projectName,
                      icon: Icons.folder_outlined,
                    ),
                    if (expense.taskTitle != null) ...[
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: 'Task',
                        value: expense.taskTitle!,
                        icon: Icons.task_alt_rounded,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _DetailRow(
                      label: 'Category',
                      value: expense.categoryName,
                      icon: Icons.category_outlined,
                    ),
                    const SizedBox(height: 10),
                    _DetailRow(
                      label: 'Submitted By',
                      value: expense.employeeName,
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    _DetailRow(
                      label: 'Expense Date',
                      value: DateFormatter.formatWithDay(expense.date),
                      icon: Icons.calendar_today_rounded,
                    ),
                  ],
                ),
              ),

              // Rejection Reason Banner (if rejected)
              if (expense.status == ExpenseStatus.rejected && expense.rejectionReason != null) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.crimsonDark.withValues(alpha: 0.25) : AppColors.crimsonLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.crimson.withValues(alpha: 0.4) : AppColors.crimsonBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cancel_rounded, color: AppColors.crimson, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Reason for Rejection',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: isDark ? const Color(0xFFFCA5A5) : AppColors.crimsonDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        expense.rejectionReason!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? const Color(0xFFFECACA) : AppColors.crimsonDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Business Purpose / Note Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Business Purpose & Notes', style: AppTextStyles.titleSmall),
                    const SizedBox(height: 10),
                    Text(expense.note, style: AppTextStyles.bodyLarge),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Receipt Attachment View
              Text('Receipt Documentation', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              ReceiptUploader(
                imagePath: expense.receiptPhotoUrl,
                isReadOnly: true,
                onImageChanged: (_) {},
              ),

              const SizedBox(height: 20),

              // Interactive Clarification Comment Thread
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

              const SizedBox(height: 28),

              // ACTION BUTTONS: Employee View vs Reviewer View
              // 1. Employee Actions: Edit and Withdraw (Available ONLY while Pending)
              if (isEmployeeOwner && isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.crimson, size: 18),
                        label: Text(
                          'Withdraw',
                          style: AppTextStyles.labelLarge.copyWith(color: AppColors.crimson),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.crimsonBorder),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Withdraw Expense Claim?'),
                              content: const Text('Are you sure you want to withdraw this pending expense claim?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Expense'),
                        onPressed: () => context.push('/expenses/${expense.id}/edit'),
                      ),
                    ),
                  ],
                ),
              ],

              // 2. Reviewer Actions: Approve and Reject with Reason Prompt
              if (isReviewer && isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, color: AppColors.crimson, size: 18),
                        label: Text('Reject', style: AppTextStyles.labelLarge.copyWith(color: AppColors.crimson)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.crimsonBorder, width: 1.2),
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve Claim'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
                        onPressed: () async {
                          final confirm = await ApproveRejectDialog.showConfirmApprovalDialog(
                            context,
                            title: 'Approve Expense Claim',
                            message: 'Approve ${CurrencyFormatter.format(expense.amount)} for ${expense.projectName}?',
                          );
                          if (confirm && context.mounted) {
                            ref.read(expenseProvider.notifier).approveExpense(expense.id);
                            NotificationBanner.showSuccess(context, 'Expense approved successfully.');
                            context.pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.getTextMuted(context)),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.labelMedium.copyWith(color: AppColors.getTextSecondary(context))),
        const Spacer(),
        Text(value, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
