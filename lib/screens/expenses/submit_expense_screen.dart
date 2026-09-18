import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/category_dropdown.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/project_dropdown.dart';
import '../../core/widgets/receipt_uploader.dart';
import '../../models/category_model.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../state/auth_provider.dart';
import '../../state/category_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/task_provider.dart';

class SubmitExpenseScreen extends ConsumerStatefulWidget {
  const SubmitExpenseScreen({super.key});

  @override
  ConsumerState<SubmitExpenseScreen> createState() => _SubmitExpenseScreenState();
}

class _SubmitExpenseScreenState extends ConsumerState<SubmitExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  ProjectModel? _selectedProject;
  TaskModel? _selectedTask;
  CategoryModel? _selectedCategory;
  String _selectedCurrency = 'USD';
  DateTime _selectedDate = DateTime.now();
  String? _receiptImagePath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _selectedCurrency = settings.preferredCurrency;
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProject == null) {
      NotificationBanner.showError(context, 'Please select an assigned project');
      return;
    }

    if (_selectedCategory == null) {
      NotificationBanner.showError(context, 'Please select an expense category');
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final user = ref.read(authProvider).currentUser!;

    ref.read(expenseProvider.notifier).submitExpense(
          employeeId: user.id,
          employeeName: user.name,
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
      setState(() => _isSubmitting = false);
      NotificationBanner.showSuccess(
        context,
        'Expense claim submitted successfully for review.',
      );
      // Returns employee to My Expenses screen as required by PRD Section 4.3
      context.go(RoutePaths.myExpenses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    final allProjects = ref.watch(projectProvider);
    final allCategories = ref.watch(categoryProvider);
    final allTasks = ref.watch(taskProvider);

    // Limit to projects employee is assigned to (PRD Section 4.3)
    final assignedProjects = allProjects.where((p) {
      if (user == null) return false;
      return p.teamMemberIds.contains(user.id);
    }).toList();

    // Filter tasks for the selected project
    final projectTasks = _selectedProject != null
        ? allTasks.where((t) => t.projectId == _selectedProject!.id).toList()
        : <TaskModel>[];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Submit New Expense'),
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
                // Assigned Project Dropdown
                ProjectDropdown(
                  projects: assignedProjects,
                  selectedProjectId: _selectedProject?.id,
                  onChanged: (proj) {
                    setState(() {
                      _selectedProject = proj;
                      _selectedTask = null; // Reset task when project changes
                    });
                  },
                ),
                const SizedBox(height: 18),

                // Optional Task Dropdown
                if (_selectedProject != null && projectTasks.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedTask?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Linked Task (Optional)',
                      hintText: 'Select task or leave unlinked',
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

                // Amount & Currency selector
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Currency Dropdown
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
                    // Amount Field
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: AppTextStyles.currencyLarge.copyWith(fontSize: 20),
                        decoration: const InputDecoration(
                          labelText: 'Amount *',
                          hintText: '0.00',
                          prefixText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter claim amount';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Category Dropdown (Active categories only)
                CategoryDropdown(
                  categories: allCategories,
                  selectedCategoryId: _selectedCategory?.id,
                  onChanged: (cat) => setState(() => _selectedCategory = cat),
                ),
                const SizedBox(height: 18),

                // Date Picker (defaults to today)
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

                // Required Note / Description
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Business Purpose / Note *',
                    hintText: 'Explain the reason for this expense and business justification...',
                    alignLabelWithHint: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide an explanatory note';
                    }
                    if (val.trim().length < 5) {
                      return 'Explanation is too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Receipt Photo Uploader
                Text('Receipt Attachment', style: AppTextStyles.labelMedium),
                const SizedBox(height: 8),
                ReceiptUploader(
                  imagePath: _receiptImagePath,
                  onImageChanged: (path) => setState(() => _receiptImagePath = path),
                ),

                // PRD Warning: Policy warning if amount > $50 and no receipt attached
                if (_exceedsThresholdWithoutReceipt) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.amberDark.withValues(alpha: 0.2) : AppColors.amberLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.amber.withValues(alpha: 0.4) : AppColors.amberBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipt Required for Claims Over \$${AppConstants.receiptRequiredThreshold.toStringAsFixed(0)}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFFDE68A) : AppColors.amberDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Company policy mandates attaching a photo or digital receipt for expenses above \$${AppConstants.receiptRequiredThreshold.toStringAsFixed(0)}. Submitting without a receipt may lead to rejection.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? const Color(0xFFFDE68A).withValues(alpha: 0.85) : AppColors.amberDark,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Submit Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Submit Expense Claim'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
