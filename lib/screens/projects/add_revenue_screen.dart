import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';

class AddRevenueScreen extends ConsumerStatefulWidget {
  final String projectId;

  const AddRevenueScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<AddRevenueScreen> createState() => _AddRevenueScreenState();
}

class _AddRevenueScreenState extends ConsumerState<AddRevenueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _revenueDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _revenueDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _revenueDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    ref.read(projectProvider.notifier).addRevenue(
          projectId: widget.projectId,
          amount: amount,
          date: _revenueDate,
          note: _noteController.text.trim(),
          createdBy: user.name,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      NotificationBanner.showSuccess(context, 'Project revenue recorded successfully.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectProvider);
    final user = ref.watch(authProvider).currentUser;
    final role = user?.role ?? UserRole.projectMember;

    // Permissions check: Finance and Admin only (PRD Section 4.4)
    if (role != UserRole.finance && role != UserRole.mainAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Revenue')),
        body: const Center(child: Text('Only Finance and Administrators can record revenue.')),
      );
    }

    final match = projects.where((p) => p.id == widget.projectId);
    final projectName = match.isNotEmpty ? match.first.name : 'Selected Project';

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Record Project Revenue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pre-filled Project Field (PRD Section 4.4)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Associated Project (Locked)',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                  ),
                  child: Text(
                    projectName,
                    style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 18),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTextStyles.currencyLarge.copyWith(
                    fontSize: 22,
                    color: (Theme.of(context).brightness == Brightness.dark)
                        ? AppColors.emeraldAccent
                        : AppColors.emeraldDark,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Revenue Amount (\$)*',
                    prefixText: '\$ ',
                    hintText: '0.00',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter amount';
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Date Picker (PRD Section 4.4)
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Received Date *',
                      suffixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    child: Text(
                      DateFormatter.formatWithDay(_revenueDate),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.getTextPrimary(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Note / Source description (PRD Section 4.4)
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Source & Description *',
                    hintText: 'e.g. Milestone 2 deliverable payment from client...',
                    alignLabelWithHint: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Note required' : null,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Record Revenue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
