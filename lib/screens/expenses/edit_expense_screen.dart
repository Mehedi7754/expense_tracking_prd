import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
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
import '../../state/settings_provider.dart';
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
  late TextEditingController _customTaxController;
  late TextEditingController _noteController;

  ProjectModel? _selectedProject;
  TaskModel? _selectedTask;
  CategoryModel? _selectedCategory;
  String _selectedCurrency = 'USD';
  DateTime _selectedDate = DateTime.now();
  String? _receiptImagePath;
  bool _isSaving = false;
  bool _initialized = false;

  double _selectedTaxRate = 0.0;
  bool _isCustomTax = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _customTaxController = TextEditingController();
    _noteController = TextEditingController();
  }

  void _initFields(ExpenseModel expense, List<ProjectModel> projects, List<CategoryModel> categories, List<TaskModel> tasks) {
    if (_initialized) return;
    _initialized = true;

    final initialTotal = expense.amount;
    _amountController.text = initialTotal.toStringAsFixed(initialTotal.truncateToDouble() == initialTotal ? 0 : 2);
    _noteController.text = expense.note;
    _selectedCurrency = expense.currency;
    _selectedDate = expense.date;
    _receiptImagePath = expense.receiptPhotoUrl;

    _selectedTaxRate = expense.taxRate;
    final defaultRates = [0.0, 5.0, 7.5, 10.0, 15.0];
    if (expense.taxRate > 0 && !defaultRates.contains(expense.taxRate)) {
      _isCustomTax = true;
      _customTaxController.text = expense.taxRate.toStringAsFixed(1);
    }

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
    _customTaxController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _enteredAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  double get _taxRate {
    if (_isCustomTax) {
      return double.tryParse(_customTaxController.text.trim()) ?? 0.0;
    }
    return _selectedTaxRate;
  }

  double get _taxAmount => _taxRate > 0 ? (_enteredAmount * (_taxRate / 100.0)) : 0.0;

  double get _netCost => _taxRate > 0 ? (_enteredAmount - _taxAmount) : _enteredAmount;

  double get _baseCost => _netCost;

  double get _currentAmount => _netCost;
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
          amount: _netCost,
          baseCost: _baseCost,
          taxRate: _taxRate,
          taxAmount: _taxAmount,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
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
                    DropdownButtonFormField<String?>(
                      value: _selectedTask?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Linked Task (Optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None (General Project Expense)'),
                        ),
                        ...projectTasks.map((t) => DropdownMenuItem<String?>(
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
                          labelText: 'Total Cost *',
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
                const SizedBox(height: 14),

                // Tax Rate Selection Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.percent_rounded, size: 16, color: AppColors.getPrimary(context)),
                              const SizedBox(width: 6),
                              Text(
                                'Tax / VAT Rate',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (_taxRate > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${CurrencyFormatter.format(_taxAmount)} Tax',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...ref.watch(settingsProvider).availableTaxRates.map((rate) {
                            final isSelected = !_isCustomTax && _selectedTaxRate == rate;
                            return ChoiceChip(
                              label: Text(rate == 0.0 ? '0% (No Tax)' : '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}%'),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  _isCustomTax = false;
                                  _selectedTaxRate = rate;
                                });
                              },
                              selectedColor: AppColors.getPrimary(context),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                              ),
                              backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.getPrimary(context)
                                      : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                                ),
                              ),
                            );
                          }),
                          ChoiceChip(
                            label: const Text('Custom %'),
                            selected: _isCustomTax,
                            onSelected: (val) {
                              setState(() {
                                _isCustomTax = true;
                              });
                            },
                            selectedColor: AppColors.getPrimary(context),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isCustomTax ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
                            ),
                            backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: _isCustomTax
                                    ? AppColors.getPrimary(context)
                                    : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isCustomTax) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _customTaxController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Custom Tax Percentage (%)',
                            hintText: 'e.g. 8.5',
                            suffixText: '%',
                            isDense: true,
                            filled: true,
                            fillColor: isDark ? AppColors.darkBackground : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Cost Breakdown Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cost Breakdown',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (_taxRate > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_taxRate.toStringAsFixed(_taxRate.truncateToDouble() == _taxRate ? 0 : 1)}% Tax Applied',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Invoice Amount:', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                          Text(CurrencyFormatter.format(_enteredAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tax Rate:', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                          Text('${_taxRate.toStringAsFixed(_taxRate.truncateToDouble() == _taxRate ? 0 : 1)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tax / VAT Amount:', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B))),
                          Text('+ ${CurrencyFormatter.format(_taxAmount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _taxAmount > 0 ? const Color(0xFF0284C7) : null)),
                        ],
                      ),
                      Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9), height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Expense Added to Project:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                            CurrencyFormatter.format(_netCost),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ],
                  ),
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
    ),
  );
  }
}
