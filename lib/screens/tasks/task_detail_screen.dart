import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/expense_list_row.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/task_provider.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTasks = ref.watch(taskProvider);
    final allExpenses = ref.watch(expenseProvider);

    final match = allTasks.where((t) => t.id == widget.taskId);
    if (match.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Detail')),
        body: const Center(child: Text('Task not found')),
      );
    }

    final task = match.first;
    final isCompleted = task.status == TaskStatus.completed;
    final role = ref.watch(authProvider).currentUser?.role;
    final canManage = role == UserRole.mainAdmin || role == UserRole.projectManager;
    final canUpdateStatus = canManage || role == UserRole.projectMember;

    // Expenses linked to this task (PRD Section 4.4)
    final linkedExpenses = allExpenses.where((e) => e.taskId == task.id).toList();
    double totalTaskExpenses = 0.0;
    for (final e in linkedExpenses) {
      totalTaskExpenses += e.amount;
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Task Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canManage)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Task',
            onPressed: () => context.push('/tasks/new?taskId=${task.id}&projectId=${task.projectId}'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.getBorder(context)),
                  boxShadow: isDark ? [] : AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isCompleted)
                          StatusChip.completed()
                        else
                          const StatusChip(
                            label: 'In Progress',
                            backgroundColor: AppColors.indigoLight,
                            textColor: AppColors.indigoDark,
                            borderColor: AppColors.indigoBorder,
                            dotColor: AppColors.indigo,
                          ),
                        Text(
                          'Due ${DateFormatter.formatShort(task.dueDate)}',
                          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(task.title, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 10),
                    Text(task.description, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text('Assignee:', style: AppTextStyles.bodySmall),
                        const SizedBox(width: 6),
                        Text(task.assigneeName, style: AppTextStyles.labelMedium),
                      ],
                    ),
                    if (task.budgetLine != null && task.budgetLine!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Text('Budget Line:', style: AppTextStyles.bodySmall),
                          const SizedBox(width: 6),
                          Text(task.budgetLine!, style: AppTextStyles.labelMedium),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Mark Complete Toggle Button (PRD Section 4.4)
          if (canUpdateStatus) SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(
                    isCompleted ? Icons.restart_alt_rounded : Icons.check_circle_outline_rounded,
                    color: isCompleted ? AppColors.textSecondary : AppColors.emerald,
                  ),
                  label: Text(isCompleted ? 'Mark as In Progress' : 'Mark Task Complete'),
                  onPressed: _updating ? null : () async {
                    setState(() => _updating = true);
                    try {
                      await ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
                      if (!context.mounted) return;
                      NotificationBanner.showSuccess(context, isCompleted ? 'Task reopened.' : 'Task marked complete!');
                    } catch (_) {
                      if (!context.mounted) return;
                      NotificationBanner.showError(context, 'Task status could not be saved. Please retry.');
                    } finally {
                      if (mounted) setState(() => _updating = false);
                    }
                  },
                ),
              ),

              const SizedBox(height: 28),

              // Linked Expenses List (PRD Section 4.4)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Linked Expenses', style: AppTextStyles.titleSmall),
                  Text(
                    'Total: ${CurrencyFormatter.format(totalTaskExpenses)}',
                    style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (linkedExpenses.isEmpty)
                const EmptyStateWidget(
                  icon: Icons.receipt_long_outlined,
                  title: 'No Expenses Linked',
                  message: 'No expenses have been tagged with this task yet.',
                )
              else
                ...linkedExpenses.map((e) => ExpenseListRow(
                      expense: e,
                      onTap: () => context.push('/expenses/${e.id}'),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
