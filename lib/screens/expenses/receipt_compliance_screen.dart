import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/receipt_compliance_badge.dart';
import '../../models/expense_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';

class ReceiptComplianceScreen extends ConsumerStatefulWidget {
  const ReceiptComplianceScreen({super.key});

  @override
  ConsumerState<ReceiptComplianceScreen> createState() => _ReceiptComplianceScreenState();
}

class _ReceiptComplianceScreenState extends ConsumerState<ReceiptComplianceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSubmitJustificationDialog(BuildContext context, ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (ctx) => _SubmitJustificationDialog(expense: expense),
    );
  }

  void _showAdminReviewDialog(BuildContext context, ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (ctx) => _AdminReviewDialog(expense: expense),
    );
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    final role = user?.role ?? UserRole.projectMember;
    final allExpenses = ref.watch(expenseProvider);

    final isAdminOrFinance = role.canApproveJustifications;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Receipt Compliance & Justifications', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: isAdminOrFinance
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Members Review Queue'),
                  Tab(text: 'Pending Justifications'),
                ],
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: isAdminOrFinance
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAdminMembersQueue(context),
                    _buildAdminPendingJustifications(context, allExpenses),
                  ],
                )
              : _buildMemberComplianceView(context, user!, allExpenses),
        ),
      ),
    );
  }

  // ==================== MEMBER COMPLIANCE VIEW ====================
  Widget _buildMemberComplianceView(BuildContext context, dynamic user, List<ExpenseModel> expenses) {
    final myExpenses = expenses.where((e) => e.employeeId == user.id).toList();
    final unreceipted = myExpenses.where((e) => !e.hasReceipt).toList();

    final metrics = ref.read(expenseProvider.notifier).getReceiptMetrics(memberId: user.id);
    final unreceiptedAmount = metrics['unreceiptedAmount'] ?? 0.0;
    final unreceiptedRatio = metrics['unreceiptedRatio'] ?? 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Dual Indicator Badge
        ReceiptComplianceBadge(
          unreceiptedAmount: unreceiptedAmount,
          unreceiptedRatio: unreceiptedRatio,
        ),
        const SizedBox(height: 16),

        Text(
          'My Expenses Without Receipts (${unreceipted.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Provide justifications for unreceipted expenditure to resolve compliance flags.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        if (unreceipted.isEmpty)
          const EmptyStateWidget(
            icon: Icons.verified_user_rounded,
            title: '100% Compliant',
            message: 'All your expenses have valid receipts attached. Great job!',
          )
        else
          ...unreceipted.map((e) {
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.categoryName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text(
                        CurrencyFormatter.format(e.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${e.projectName} • ${e.note}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (e.justificationStatus == JustificationStatus.approved
                                  ? AppColors.success
                                  : Colors.orange)
                              .withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          e.justificationStatus.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: e.justificationStatus == JustificationStatus.approved
                                ? AppColors.success
                                : Colors.orange,
                          ),
                        ),
                      ),
                      if (e.justificationStatus == JustificationStatus.required ||
                          e.justificationStatus == JustificationStatus.clarificationRequested)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.rate_review_rounded, size: 14),
                          label: const Text('Submit Justification', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          onPressed: () => _showSubmitJustificationDialog(context, e),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==================== ADMIN: MEMBERS REQUIRING JUSTIFICATION (PRD Section 11) ====================
  Widget _buildAdminMembersQueue(BuildContext context) {
    final summaries = ref.read(expenseProvider.notifier).getMembersRequiringJustification();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Members Requiring Justification',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Members whose unreceipted expense ratio exceeds the 50% red-flag threshold.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Member', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('Project', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('No Receipt', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('%', style: TextStyle(fontWeight: FontWeight.w800))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w800))),
              ],
              rows: summaries.map((s) {
                return DataRow(
                  cells: [
                    DataCell(Text(s.memberName, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(s.projectName, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(CurrencyFormatter.format(s.totalClaimed, compact: true))),
                    DataCell(Text(CurrencyFormatter.format(s.unreceiptedAmount, compact: true))),
                    DataCell(
                      Text(
                        '${s.unreceiptedRatio.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: s.isExceedingThreshold ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (s.isExceedingThreshold ? AppColors.error : AppColors.success).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.isExceedingThreshold ? '🔴 Review' : '🟢 Compliant',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: s.isExceedingThreshold ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== ADMIN: PENDING JUSTIFICATIONS QUEUE (PRD Section 13) ====================
  Widget _buildAdminPendingJustifications(BuildContext context, List<ExpenseModel> expenses) {
    final pending = expenses
        .where((e) =>
            e.justificationStatus == JustificationStatus.submitted ||
            e.justificationStatus == JustificationStatus.clarificationRequested)
        .toList();

    if (pending.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline_rounded,
        title: 'All Caught Up!',
        message: 'No pending expense justifications awaiting administrator review.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (ctx, i) {
        final exp = pending[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${exp.employeeName} — ${exp.projectName}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    CurrencyFormatter.format(exp.amount),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Reason: ${exp.justificationReason ?? "Unstated"}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.orange)),
              const SizedBox(height: 4),
              Text('Comment: ${exp.justificationComment ?? "None"}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _showAdminReviewDialog(context, exp),
                    child: const Text('Review Justification'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubmitJustificationDialog extends ConsumerStatefulWidget {
  final ExpenseModel expense;

  const _SubmitJustificationDialog({required this.expense});

  @override
  ConsumerState<_SubmitJustificationDialog> createState() => _SubmitJustificationDialogState();
}

class _SubmitJustificationDialogState extends ConsumerState<_SubmitJustificationDialog> {
  late final TextEditingController _commentController;
  String _selectedReason = 'Rural / Local vendor does not provide printed receipts';
  String? _attachmentName;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.assignment_turned_in_rounded, color: AppColors.getPrimary(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Submit Justification: ${expense.categoryName}'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense: ${CurrencyFormatter.format(expense.amount)} • ${expense.projectName}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason for No Receipt *'),
              items: [
                'Rural / Local vendor does not provide printed receipts',
                'Local transport operator (CNG / Boat / Rickshaw)',
                'Village / Field market purchase without vouchers',
                'Emergency repair or field operational necessity',
                'Other exceptional field circumstances',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedReason = v);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Explanation / Comment *',
                hintText: 'Detail why a receipt was unobtainable...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                  ),
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: const Text('Supporting Document/Photo'),
                  onPressed: () {
                    setState(() => _attachmentName = 'supporting_proof_${DateTime.now().millisecondsSinceEpoch}.jpg');
                  },
                ),
              ],
            ),
            if (_attachmentName != null) ...[
              const SizedBox(height: 4),
              Text(_attachmentName!, style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: () {
            if (_commentController.text.trim().isEmpty) {
              NotificationBanner.showError(context, 'Please enter an explanation');
              return;
            }
            ref.read(expenseProvider.notifier).submitJustification(
                  expenseId: expense.id,
                  reason: _selectedReason,
                  comment: _commentController.text.trim(),
                  attachmentUrl: _attachmentName,
                );
            Navigator.pop(context);
            NotificationBanner.showSuccess(context, 'Justification submitted for admin review');
          },
          child: const Text('Submit Justification'),
        ),
      ],
    );
  }
}

class _AdminReviewDialog extends ConsumerStatefulWidget {
  final ExpenseModel expense;

  const _AdminReviewDialog({required this.expense});

  @override
  ConsumerState<_AdminReviewDialog> createState() => _AdminReviewDialogState();
}

class _AdminReviewDialogState extends ConsumerState<_AdminReviewDialog> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.rate_review_rounded, color: AppColors.getPrimary(context)),
          const SizedBox(width: 8),
          const Text('Review Justification'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${expense.employeeName} — ${expense.projectName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Amount: ${CurrencyFormatter.format(expense.amount)} (${expense.categoryName})', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.getPrimary(context))),
            const Divider(height: 18),
            const Text('Reason:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(expense.justificationReason ?? 'No reason provided', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Comment:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(expense.justificationComment ?? 'No comment provided', style: const TextStyle(fontSize: 13)),
            if (expense.justificationAttachmentUrl != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attachment_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(expense.justificationAttachmentUrl!, style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Admin Review Note (Optional)',
                hintText: 'Approval note or reason for rejection...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () {
            ref.read(expenseProvider.notifier).rejectJustification(
                  expenseId: expense.id,
                  reviewerName: ref.read(authProvider).currentUser?.name ?? 'Admin',
                  reason: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : 'Rejected by admin.',
                );
            Navigator.pop(context);
            NotificationBanner.showSuccess(context, 'Justification rejected');
          },
          child: const Text('Reject'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.orange),
          onPressed: () {
            ref.read(expenseProvider.notifier).requestClarification(
                  expenseId: expense.id,
                  reviewerName: ref.read(authProvider).currentUser?.name ?? 'Admin',
                  note: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : 'Clarification requested.',
                );
            Navigator.pop(context);
            NotificationBanner.showSuccess(context, 'Clarification requested from member');
          },
          child: const Text('Clarification'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
          onPressed: () {
            ref.read(expenseProvider.notifier).approveJustification(
                  expenseId: expense.id,
                  reviewerName: ref.read(authProvider).currentUser?.name ?? 'Admin',
                  reviewComment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
                );
            Navigator.pop(context);
            NotificationBanner.showSuccess(context, 'Justification approved');
          },
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
