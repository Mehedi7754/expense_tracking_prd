import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/category_dropdown.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/project_dropdown.dart';
import '../../core/widgets/receipt_uploader.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../state/category_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/task_provider.dart';

class EditExpenseScreen extends ConsumerStatefulWidget {
  final String expenseId;

  const EditExpenseScreen({
    super.key,
    required this.expenseId,
  });

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  ProjectModel? _selectedProject;
  TaskModel? _selectedTask;
  CategoryModel? _selectedCategory;
  String _selectedCurrency = 'USD';
  DateTime _selectedDate = DateTime.now();
  String? _receiptImagePath;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
  }

  void _initFields(ExpenseModel expense, List<ProjectModel> projects, List<CategoryModel> categories, List<TaskModel> tasks) {
    if (_initialized) return;
    _initialized = true;

    _amountController.text = expense.amount.toStringAsFixed(2);
    _noteController.text = expense.note;
    _selectedCurrency = expense.currency;
    _selectedDate = expense.date;
    _receiptImagePath = expense.receiptPhotoUrl;

    try {
      _selectedProject = projects.firstWhere((p) => p.id == expense.projectId);
    } catch (_) {}

    try {
      _selectedCategory = categories.firstWhere((c) => c.id == expense.categoryId);
    } catch (_) {}

    if (expense.taskId != null) {
      try {
        _selectedTask = tasks.firstWhere((t) => t.id == expense.taskId);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _currentAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;
  bool get _exceedsThresholdWithoutReceipt =>
      _currentAmount > AppConstants.receiptRequiredThreshold &&
      (_receiptImagePath == null || _receiptImagePath!.isEmpty);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProject == null || _selectedCategory == null) {
      NotificationBanner.showError(context, 'Please ensure all required fields are chosen');
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));

    ref.read(expenseProvider.notifier).editExpense(
          id: widget.expenseId,
          projectId: _selectedProject!.id,
          projectName: _selectedProject!.name,
          taskId: _selectedTask?.id,
          taskTitle: _selectedTask?.title,
          amount: _currentAmount,
          currency: _selectedCurrency,
          categoryId: _selectedCategory!.id,
          categoryName: _selectedCategory!.name,
          categoryIcon: _selectedCategory!.iconName,
          note: _noteController.text.trim(),
          date: _selectedDate,
          receiptPhotoUrl: _receiptImagePath,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      NotificationBanner.showSuccess(context, 'Expense claim updated successfully.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expenseProvider);
    final allProjects = ref.watch(projectProvider);
    final allCategories = ref.watch(categoryProvider);
    final allTasks = ref.watch(taskProvider);

    final expenseList = allExpenses.where((e) => e.id == widget.expenseId);
    if (expenseList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Expense')),
        body: const Center(child: Text('Expense record not found.')),
      );
    }

    final expense = expenseList.first;

    // Security check: PRD mandates only Pending expenses can be edited
    if (expense.status != ExpenseStatus.pending) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Expense')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock_rounded, size: 48, color: AppColors.amber),
                const SizedBox(height: 16),
                Text('Expense Cannot Be Edited', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Only pending expenses can be edited. This claim is already ${expense.status.displayName.toLowerCase()}.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(onPressed: () => context.pop(), child: const Text('Return to Details')),
              ],
            ),
          ),
        ),
      );
    }

    _initFields(expense, allProjects, allCategories, allTasks);

    final projectTasks = _selectedProject != null
        ? allTasks.where((t) => t.projectId == _selectedProject!.id).toList()
        : <TaskModel>[];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Edit Pending Expense'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProjectDropdown(
                  projects: allProjects,
                  selectedProjectId: _selectedProject?.id,
                  onChanged: (proj) {
                    setState(() {
                      _selectedProject = proj;
                      _selectedTask = null;
                    });
                  },
                ),
                const SizedBox(height: 18),

                if (_selectedProject != null && projectTasks.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedTask?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Linked Task (Optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None (General Project Expense)'),
                      ),
                      ...projectTasks.map((t) => DropdownMenuItem<String>(
                            value: t.id,
                            child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (taskId) {
                      setState(() {
                        if (taskId == null) {
                          _selectedTask = null;
                        } else {
                          _selectedTask = projectTasks.firstWhere((t) => t.id == taskId);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                ],

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 105,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: const InputDecoration(labelText: 'Currency'),
                        items: AppConstants.supportedCurrencies.map((curr) {
                          return DropdownMenuItem<String>(
                            value: curr,
                            child: Text(
                              curr,
                              style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCurrency = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: AppTextStyles.currencyLarge.copyWith(fontSize: 20),
                        decoration: const InputDecoration(
                          labelText: 'Amount *',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter amount';
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) return 'Enter valid amount';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                CategoryDropdown(
                  categories: allCategories,
                  selectedCategoryId: _selectedCategory?.id,
                  onChanged: (cat) => setState(() => _selectedCategory = cat),
                ),
                const SizedBox(height: 18),

                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expense Date *',
                      suffixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                    ),
                    child: Text(
                      DateFormatter.formatWithDay(_selectedDate),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.getTextPrimary(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Business Purpose / Note *',
                    alignLabelWithHint: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Note required';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Text('Receipt Attachment', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                ReceiptUploader(
                  imagePath: _receiptImagePath,
                  onImageChanged: (path) => setState(() => _receiptImagePath = path),
                ),

                if (_exceedsThresholdWithoutReceipt) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.amberDark.withValues(alpha: 0.2) : AppColors.amberLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.amber.withValues(alpha: 0.4) : AppColors.amberBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Warning: Claims over \$${AppConstants.receiptRequiredThreshold.toStringAsFixed(0)} require a receipt under company policy.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? const Color(0xFFFDE68A) : AppColors.amberDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes'),
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
