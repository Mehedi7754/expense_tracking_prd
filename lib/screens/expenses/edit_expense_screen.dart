import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/category_dropdown.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/project_dropdown.dart';
import '../../core/widgets/receipt_uploader.dart';
import '../../repositories/file_upload_repository.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../state/category_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/task_provider.dart';

class _EditableExpenseCategory {
  _EditableExpenseCategory(
    ExpenseCategoryItem item,
    List<CategoryModel> categories,
  ) : categoryId = item.categoryId,
      categoryName = item.categoryName,
      categoryIcon = item.categoryIcon,
      baseAmountController = TextEditingController(
        text: item.baseCost.toStringAsFixed(
          item.baseCost.truncateToDouble() == item.baseCost ? 0 : 2,
        ),
      ),
      vatRateController = TextEditingController(text: _rateText(item.vatRate)),
      taxRateController = TextEditingController(text: _rateText(item.taxRate)),
      details = Map<String, dynamic>.from(item.details),
      receipts = List<String>.from(item.receiptPhotoUrls),
      hasReceipt = item.hasReceipt {
    category = _findCategory(categories, item.categoryId, item.categoryName);
    for (final entry in details.entries) {
      detailControllers[entry.key] = TextEditingController(
        text: entry.value?.toString() ?? '',
      );
    }
  }

  static String _rateText(double value) =>
      value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);

  static CategoryModel? _findCategory(
    List<CategoryModel> categories,
    String id,
    String name,
  ) {
    for (final category in categories) {
      if (category.id == id ||
          category.name.trim().toLowerCase() == name.trim().toLowerCase()) {
        return category;
      }
    }
    return null;
  }

  String categoryId;
  String categoryName;
  String categoryIcon;
  CategoryModel? category;
  final TextEditingController baseAmountController;
  final TextEditingController vatRateController;
  final TextEditingController taxRateController;
  final Map<String, dynamic> details;
  final Map<String, TextEditingController> detailControllers = {};
  final List<String> receipts;
  bool hasReceipt;

  double get baseAmount =>
      double.tryParse(baseAmountController.text.trim()) ?? 0;
  double get vatRate => double.tryParse(vatRateController.text.trim()) ?? 0;
  double get taxRate => double.tryParse(taxRateController.text.trim()) ?? 0;

  Map<String, dynamic> editedDetails() => {
    for (final entry in details.entries)
      entry.key: _convertDetail(
        entry.value,
        detailControllers[entry.key]?.text ?? '',
      ),
  };

  static dynamic _convertDetail(dynamic original, String value) {
    if (original is bool) return value.trim().toLowerCase() == 'true';
    if (original is int) return int.tryParse(value) ?? value;
    if (original is num) return num.tryParse(value) ?? value;
    return value;
  }

  void dispose() {
    baseAmountController.dispose();
    vatRateController.dispose();
    taxRateController.dispose();
    for (final controller in detailControllers.values) {
      controller.dispose();
    }
  }
}

class EditExpenseScreen extends ConsumerStatefulWidget {
  final String expenseId;

  const EditExpenseScreen({super.key, required this.expenseId});

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _customVatController;
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
  final List<_EditableExpenseCategory> _editableCategories = [];
  bool _isUploadingCategoryReceipt = false;
  bool _editingGroupedClaim = false;

  double _selectedVatRate = 0.0;
  bool _isCustomVat = false;

  double _selectedTaxRate = 0.0;
  bool _isCustomTax = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _customVatController = TextEditingController();
    _customTaxController = TextEditingController();
    _noteController = TextEditingController();
  }

  void _initFields(
    ExpenseModel expense,
    List<ProjectModel> projects,
    List<CategoryModel> categories,
    List<TaskModel> tasks,
  ) {
    if (!_initialized) {
      _initialized = true;
      _editingGroupedClaim = true;

      final initialBase = expense.baseCost;
      _amountController.text = initialBase.toStringAsFixed(
        initialBase.truncateToDouble() == initialBase ? 0 : 2,
      );
      _noteController.text = expense.note;
      _selectedCurrency = expense.currency;
      _selectedDate = expense.date;
      _receiptImagePath = expense.receiptPhotoUrl;

      _selectedVatRate = expense.vatRate;
      final defaultVatRates = [0.0, 5.0, 7.5, 10.0, 15.0];
      if (expense.vatRate > 0 && !defaultVatRates.contains(expense.vatRate)) {
        _isCustomVat = true;
        _customVatController.text = expense.vatRate.toStringAsFixed(1);
      }

      _selectedTaxRate = expense.taxRate;
      final defaultRates = [0.0, 2.0, 3.0, 5.0, 7.5, 10.0];
      if (expense.taxRate > 0 && !defaultRates.contains(expense.taxRate)) {
        _isCustomTax = true;
        _customTaxController.text = expense.taxRate.toStringAsFixed(1);
      }

      final expenseCategoryItems =
          expense.categoryItems.isNotEmpty
              ? expense.categoryItems
              : [
                ExpenseCategoryItem(
                  categoryId: expense.categoryId,
                  categoryName: expense.categoryName,
                  categoryIcon: expense.categoryIcon,
                  amount: expense.amount,
                  baseCost: expense.baseCost,
                  vatRate: expense.vatRate,
                  vatAmount: expense.vatAmount,
                  taxRate: expense.taxRate,
                  taxAmount: expense.taxAmount,
                  details:
                      expense.transportationDetails?.toJson() ??
                      expense.equipmentDetails?.toJson() ??
                      expense.foodDetails?.toJson() ??
                      expense.accommodationDetails?.toJson() ??
                      expense.officeCostDetails?.toJson() ??
                      const {},
                  receiptPhotoUrls:
                      expense.receiptPhotoUrls.isNotEmpty
                          ? expense.receiptPhotoUrls
                          : (expense.receiptPhotoUrl == null
                              ? const []
                              : [expense.receiptPhotoUrl!]),
                  hasReceipt: expense.hasReceipt,
                ),
              ];
      _editableCategories.addAll(
        expenseCategoryItems.map(
          (item) => _EditableExpenseCategory(item, categories),
        ),
      );
    }

    // Project/category providers can finish loading after the expense form's
    // text fields are initialized. Retry resolving selections on each build.
    _selectedProject ??= _firstOrNull(
      projects,
      (p) => p.id == expense.projectId || p.projectId == expense.projectId,
    );

    _selectedCategory ??= _firstOrNull(
      categories,
      (category) =>
          category.id == expense.categoryId ||
          category.name.trim().toLowerCase() ==
              expense.categoryName.trim().toLowerCase(),
    );

    if (_selectedTask == null && expense.taskId != null) {
      _selectedTask = _firstOrNull(tasks, (task) => task.id == expense.taskId);
    }
  }

  T? _firstOrNull<T>(Iterable<T> values, bool Function(T value) matches) {
    for (final value in values) {
      if (matches(value)) return value;
    }
    return null;
  }

  Future<void> _addExpenseCategory(List<CategoryModel> categories) async {
    final available = categories.where(
      (category) =>
          category.isActive &&
          !_editableCategories.any((line) => line.category?.id == category.id),
    );
    if (available.isEmpty) {
      NotificationBanner.showError(
        context,
        'No additional categories are available.',
      );
      return;
    }
    final selected = await showModalBottomSheet<CategoryModel>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Add expense category')),
                ...available.map(
                  (category) => ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(category.name),
                    onTap: () => Navigator.pop(context, category),
                  ),
                ),
              ],
            ),
          ),
    );
    if (selected == null || !mounted) return;
    final item = ExpenseCategoryItem(
      categoryId: selected.id,
      categoryName: selected.name,
      categoryIcon: selected.iconName,
      amount: 0,
      baseCost: 0,
      details: const {},
      receiptPhotoUrls: const [],
      hasReceipt: false,
    );
    setState(
      () => _editableCategories.add(_EditableExpenseCategory(item, categories)),
    );
  }

  Future<void> _addCategoryReceipts(_EditableExpenseCategory line) async {
    try {
      final images = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (images.isEmpty || !mounted) return;
      setState(() => _isUploadingCategoryReceipt = true);
      final uploaded = await ref
          .read(fileUploadRepositoryProvider)
          .uploadBatch(
            filePathsOrDataUris: images.map((image) => image.path).toList(),
            category: UploadCategory.receipts,
            entityId: widget.expenseId,
          );
      if (!mounted) return;
      setState(() {
        line.receipts.addAll(uploaded.map((result) => result.url));
        line.hasReceipt = line.receipts.isNotEmpty;
        _isUploadingCategoryReceipt = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingCategoryReceipt = false);
      NotificationBanner.showError(
        context,
        'Could not upload receipts: $error',
      );
    }
  }

  Widget _buildCategoryEditor(
    _EditableExpenseCategory line,
    int index,
    List<CategoryModel> categories,
    bool isDark,
  ) {
    final activeCategories =
        categories.where((category) => category.isActive).toList();
    final selectedCategory = line.category;
    final availableCategoryIds =
        activeCategories.map((category) => category.id).toSet();
    final dropdownValue =
        selectedCategory != null &&
                availableCategoryIds.contains(selectedCategory.id)
            ? selectedCategory.id
            : null;
    return Container(
      key: ValueKey('expense-category-$index'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: dropdownValue,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category *'),
                  items:
                      activeCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(
                                category.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final category = activeCategories.firstWhere(
                      (item) => item.id == id,
                    );
                    setState(() {
                      line.category = category;
                      line.categoryId = category.id;
                      line.categoryName = category.name;
                      line.categoryIcon = category.iconName;
                    });
                  },
                ),
              ),
              if (_editableCategories.length > 1)
                IconButton(
                  tooltip: 'Remove category',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    setState(
                      () => _editableCategories.removeAt(index).dispose(),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.baseAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Base amount *'),
                  onChanged: (_) => setState(() {}),
                  validator:
                      (value) =>
                          double.tryParse(value?.trim() ?? '') == null ||
                                  (double.tryParse(value!.trim()) ?? 0) <= 0
                              ? 'Enter a valid amount'
                              : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: line.vatRateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'VAT %'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: line.taxRateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Tax %'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          for (final entry in line.detailControllers.entries) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: _formatDetailLabel(entry.key),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove detail',
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed:
                      () => setState(() {
                        line.details.remove(entry.key);
                        line.detailControllers.remove(entry.key)?.dispose();
                      }),
                ),
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  () => setState(() {
                    var index = 1;
                    while (line.details.containsKey(
                      'additional_detail_$index',
                    )) {
                      index++;
                    }
                    final key = 'additional_detail_$index';
                    line.details[key] = '';
                    line.detailControllers[key] = TextEditingController();
                  }),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add detail'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Receipts (${line.receipts.length})',
                  style: AppTextStyles.labelMedium,
                ),
              ),
              TextButton.icon(
                onPressed:
                    _isUploadingCategoryReceipt
                        ? null
                        : () => _addCategoryReceipts(line),
                icon:
                    _isUploadingCategoryReceipt
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add photos'),
              ),
            ],
          ),
          if (line.receipts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final receipt in List<String>.from(line.receipts))
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: _buildReceiptThumbnail(receipt),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap:
                                () => setState(() {
                                  line.receipts.remove(receipt);
                                  line.hasReceipt = line.receipts.isNotEmpty;
                                }),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Category total: ${CurrencyFormatter.format(line.baseAmount * (1 + line.vatRate / 100 + line.taxRate / 100), currency: _selectedCurrency)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDetailLabel(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  Widget _buildReceiptThumbnail(String receipt) {
    if (receipt.startsWith('http://') ||
        receipt.startsWith('https://') ||
        receipt.startsWith('/uploads/') ||
        receipt.startsWith('/api/v1/uploads/')) {
      return Image.network(
        receipt.startsWith('http')
            ? receipt
            : ReceiptUploader.resolveImageUrl(receipt),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }
    if (!kIsWeb && File(receipt).existsSync())
      return Image.file(File(receipt), fit: BoxFit.cover);
    return const Icon(Icons.receipt_long_rounded);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customVatController.dispose();
    _customTaxController.dispose();
    _noteController.dispose();
    for (final category in _editableCategories) {
      category.dispose();
    }
    super.dispose();
  }

  double get _enteredAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  double get _vatRate {
    if (_isCustomVat) {
      return double.tryParse(_customVatController.text.trim()) ?? 0.0;
    }
    return _selectedVatRate;
  }

  double get _vatAmount =>
      _vatRate > 0 ? (_enteredAmount * (_vatRate / 100.0)) : 0.0;

  double get _taxRate {
    if (_isCustomTax) {
      return double.tryParse(_customTaxController.text.trim()) ?? 0.0;
    }
    return _selectedTaxRate;
  }

  double get _taxAmount =>
      _taxRate > 0 ? (_enteredAmount * (_taxRate / 100.0)) : 0.0;

  double get _netCost => _enteredAmount + _vatAmount + _taxAmount;

  double get _baseCost => _enteredAmount;

  double get _currentAmount =>
      _editingGroupedClaim
          ? _editableCategories.fold<double>(
            0,
            (sum, line) =>
                sum +
                line.baseAmount * (1 + line.vatRate / 100 + line.taxRate / 100),
          )
          : _netCost;
  bool get _exceedsThresholdWithoutReceipt =>
      _currentAmount > AppConstants.receiptRequiredThreshold &&
      (_editingGroupedClaim
          ? !_editableCategories.any((line) => line.receipts.isNotEmpty)
          : (_receiptImagePath == null || _receiptImagePath!.isEmpty));

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

    final expense =
        ref
            .read(expenseProvider)
            .where((item) => item.id == widget.expenseId)
            .firstOrNull;

    if (_selectedProject == null) {
      NotificationBanner.showError(
        context,
        'Please select a project before saving',
      );
      return;
    }

    if (_exceedsThresholdWithoutReceipt) {
      NotificationBanner.showError(
        context,
        'Receipt required for expenses above threshold',
      );
      return;
    }

    final hasAnyReceipt =
        _editingGroupedClaim
            ? _editableCategories.any((line) => line.receipts.isNotEmpty)
            : _receiptImagePath != null && _receiptImagePath!.isNotEmpty;
    if (!hasAnyReceipt && _noteController.text.trim().isEmpty) {
      NotificationBanner.showError(
        context,
        'A justification is required in the Note field when saving without a receipt.',
      );
      return;
    }

    final isGroupedClaim = _editingGroupedClaim;
    List<ExpenseCategoryItem>? editedCategoryItems;
    var saveAmount = _netCost;
    var saveBaseCost = _baseCost;
    var saveVatRate = _vatRate;
    var saveVatAmount = _vatAmount;
    var saveTaxRate = _taxRate;
    var saveTaxAmount = _taxAmount;
    var saveCategoryId = _selectedCategory?.id ?? expense?.categoryId ?? '';
    var saveCategoryName =
        _selectedCategory?.name ?? expense?.categoryName ?? 'Expense';
    var saveCategoryIcon =
        _selectedCategory?.iconName ?? expense?.categoryIcon ?? '';
    var saveReceiptUrls = <String>[];
    if (isGroupedClaim) {
      if (_editableCategories.isEmpty ||
          _editableCategories.any((line) => line.category == null)) {
        NotificationBanner.showError(
          context,
          'Choose a category for every expense line.',
        );
        return;
      }
      final categoryIds =
          _editableCategories
              .map((line) => line.category?.id ?? line.categoryId)
              .toSet();
      if (categoryIds.length != _editableCategories.length) {
        NotificationBanner.showError(
          context,
          'Each expense category can only be added once.',
        );
        return;
      }
      editedCategoryItems =
          _editableCategories.map((line) {
            final base = line.baseAmount;
            final vat = base * line.vatRate / 100;
            final tax = base * line.taxRate / 100;
            return ExpenseCategoryItem(
              categoryId: line.category?.id ?? line.categoryId,
              categoryName: line.category?.name ?? line.categoryName,
              categoryIcon: line.category?.iconName ?? line.categoryIcon,
              amount: base + vat + tax,
              baseCost: base,
              vatRate: line.vatRate,
              vatAmount: vat,
              taxRate: line.taxRate,
              taxAmount: tax,
              details: line.editedDetails(),
              receiptPhotoUrls: List<String>.from(line.receipts),
              hasReceipt: line.receipts.isNotEmpty,
            );
          }).toList();
      saveBaseCost = editedCategoryItems.fold(
        0,
        (sum, item) => sum + item.baseCost,
      );
      saveVatAmount = editedCategoryItems.fold(
        0,
        (sum, item) => sum + item.vatAmount,
      );
      saveTaxAmount = editedCategoryItems.fold(
        0,
        (sum, item) => sum + item.taxAmount,
      );
      saveAmount = saveBaseCost + saveVatAmount + saveTaxAmount;
      saveVatRate = saveBaseCost > 0 ? saveVatAmount / saveBaseCost * 100 : 0;
      saveTaxRate = saveBaseCost > 0 ? saveTaxAmount / saveBaseCost * 100 : 0;
      saveCategoryId = editedCategoryItems.first.categoryId;
      saveCategoryName = editedCategoryItems
          .map((item) => item.categoryName)
          .join(' + ');
      saveCategoryIcon = editedCategoryItems.first.categoryIcon;
      saveReceiptUrls =
          editedCategoryItems
              .expand((item) => item.receiptPhotoUrls)
              .toSet()
              .toList();
    }

    setState(() => _isSaving = true);
    try {
      var receiptUrl = _receiptImagePath;
      if (receiptUrl != null &&
          receiptUrl.isNotEmpty &&
          !receiptUrl.startsWith('http://') &&
          !receiptUrl.startsWith('https://') &&
          !receiptUrl.startsWith('/uploads/') &&
          !receiptUrl.startsWith('uploads/')) {
        receiptUrl =
            (await ref
                .read(fileUploadRepositoryProvider)
                .upload(
                  filePathOrDataUri: receiptUrl,
                  category: UploadCategory.receipts,
                  entityId: widget.expenseId,
                )).url;
      }

      final saved = await ref
          .read(expenseProvider.notifier)
          .editExpense(
            id: widget.expenseId,
            projectId: _selectedProject!.id,
            projectName: _selectedProject!.name,
            taskId: _selectedTask?.id,
            taskTitle: _selectedTask?.title,
            amount: saveAmount,
            baseCost: saveBaseCost,
            vatRate: saveVatRate,
            vatAmount: saveVatAmount,
            taxRate: saveTaxRate,
            taxAmount: saveTaxAmount,
            currency: _selectedCurrency,
            categoryId: saveCategoryId,
            categoryName: saveCategoryName,
            categoryIcon: saveCategoryIcon,
            note: _noteController.text.trim(),
            date: _selectedDate,
            receiptPhotoUrl:
                isGroupedClaim
                    ? (saveReceiptUrls.isEmpty ? null : saveReceiptUrls.first)
                    : receiptUrl,
            receiptPhotoUrls:
                isGroupedClaim
                    ? saveReceiptUrls
                    : (receiptUrl == null || receiptUrl.isEmpty
                        ? const []
                        : [
                          receiptUrl,
                          ...?expense?.receiptPhotoUrls.where(
                            (url) => url != receiptUrl && url.isNotEmpty,
                          ),
                        ]),
            categoryItems: editedCategoryItems ?? expense?.categoryItems,
          );

      if (!saved) {
        throw Exception(
          'The expense could not be saved. Check your connection and try again.',
        );
      }
      if (mounted) {
        setState(() => _isSaving = false);
        NotificationBanner.showSuccess(
          context,
          expense?.status == ExpenseStatus.rejected
              ? 'Expense corrected and resubmitted for approval.'
              : 'Expense claim updated successfully.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        NotificationBanner.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expenseProvider);
    final loadedProjects = ref.watch(projectProvider);
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

    final allProjects = List<ProjectModel>.from(loadedProjects);
    final hasSubmittedProject = allProjects.any(
      (project) =>
          project.id == expense.projectId ||
          project.projectId == expense.projectId,
    );
    if (!hasSubmittedProject) {
      final now = DateTime.now();
      allProjects.add(
        ProjectModel(
          id: expense.projectId,
          projectId: expense.projectId,
          name: expense.projectName,
          description: 'Project attached to this expense claim',
          client: '',
          grossProjectValue: 0,
          expectedNetRevenue: 0,
          amountReceivable: 0,
          budget: 0,
          startDate: now,
          endDate: now,
          teamMemberIds: const [],
        ),
      );
    }

    // Security check: PRD & Client feedback: pending and rejected claims can be edited
    if (expense.status != ExpenseStatus.pending &&
        expense.status != ExpenseStatus.rejected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Expense')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 48,
                  color: AppColors.amber,
                ),
                const SizedBox(height: 16),
                Text(
                  'Expense Cannot Be Edited',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Approved expenses cannot be edited. This claim is already ${expense.status.displayName.toLowerCase()}.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Return to Details'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    _initFields(expense, allProjects, allCategories, allTasks);
    for (final line in _editableCategories) {
      line.category ??= _firstOrNull(
        allCategories,
        (category) =>
            category.id == line.categoryId ||
            category.name.trim().toLowerCase() ==
                line.categoryName.trim().toLowerCase(),
      );
    }

    final projectTasks =
        _selectedProject != null
            ? allTasks
                .where((t) => t.projectId == _selectedProject!.id)
                .toList()
            : <TaskModel>[];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMultiCategory = _editableCategories.isNotEmpty;
    final hasMultipleExpenseCategories = _editableCategories.length > 1;

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
                  if (isMultiCategory) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasMultipleExpenseCategories
                                ? 'Expense category lines'
                                : 'Expense category',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF3730A3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._editableCategories.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.category?.name ?? item.categoryName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(
                                      item.baseAmount *
                                          (1 +
                                              item.vatRate / 100 +
                                              item.taxRate / 100),
                                      currency: expense.currency,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${item.receipts.length} receipt${item.receipts.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            hasMultipleExpenseCategories
                                ? 'Edit each category, its amount, details, and receipts.'
                                : 'Edit the category, amount, details, and all receipts.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit category lines and receipts',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _addExpenseCategory(allCategories),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add category'),
                        ),
                      ],
                    ),
                    ..._editableCategories.asMap().entries.map(
                      (entry) => _buildCategoryEditor(
                        entry.value,
                        entry.key,
                        allCategories,
                        isDark,
                      ),
                    ),
                  ],
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
                        ...projectTasks.map(
                          (t) => DropdownMenuItem<String?>(
                            value: t.id,
                            child: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (taskId) {
                        setState(() {
                          if (taskId == null) {
                            _selectedTask = null;
                          } else {
                            _selectedTask = projectTasks.firstWhere(
                              (t) => t.id == taskId,
                            );
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
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                          ),
                          items:
                              AppConstants.supportedCurrencies.map((curr) {
                                return DropdownMenuItem<String>(
                                  value: curr,
                                  child: Text(
                                    curr,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }).toList(),
                          onChanged: (val) {
                            if (val != null)
                              setState(() => _selectedCurrency = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          readOnly: isMultiCategory,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTextStyles.currencyLarge.copyWith(
                            fontSize: 20,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                isMultiCategory
                                    ? 'Grouped Total Cost'
                                    : 'Total Cost *',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Enter amount';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0)
                              return 'Enter valid amount';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tax Rate Selection Card
                  // VAT Rate Selection Card (Segmented VAT)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurface
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16,
                                  color: const Color(0xFF8B5CF6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'VAT (Value Added Tax)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (_vatRate > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+৳${CurrencyFormatter.format(_vatAmount).replaceAll('৳', '').trim()} VAT',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7C3AED),
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
                            ...[0.0, 5.0, 7.5, 10.0, 15.0].map((rate) {
                              final isSelected =
                                  !_isCustomVat && _selectedVatRate == rate;
                              return ChoiceChip(
                                label: Text(
                                  rate == 0.0
                                      ? '0% (No VAT)'
                                      : '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}%',
                                ),
                                selected: isSelected,
                                onSelected:
                                    isMultiCategory
                                        ? null
                                        : (val) {
                                          setState(() {
                                            _isCustomVat = false;
                                            _selectedVatRate = rate;
                                          });
                                        },
                                selectedColor: const Color(0xFF8B5CF6),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : AppColors.textPrimary),
                                ),
                                backgroundColor:
                                    isDark
                                        ? AppColors.darkBackground
                                        : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color:
                                        isSelected
                                            ? const Color(0xFF8B5CF6)
                                            : (isDark
                                                ? AppColors.darkBorder
                                                : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                              );
                            }),
                            ChoiceChip(
                              label: const Text('Custom %'),
                              selected: _isCustomVat,
                              onSelected:
                                  isMultiCategory
                                      ? null
                                      : (val) {
                                        setState(() {
                                          _isCustomVat = true;
                                        });
                                      },
                              selectedColor: const Color(0xFF8B5CF6),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    _isCustomVat
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : AppColors.textPrimary),
                              ),
                              backgroundColor:
                                  isDark
                                      ? AppColors.darkBackground
                                      : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color:
                                      _isCustomVat
                                          ? const Color(0xFF8B5CF6)
                                          : (isDark
                                              ? AppColors.darkBorder
                                              : const Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isCustomVat) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _customVatController,
                            readOnly: isMultiCategory,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Custom VAT Percentage (%)',
                              hintText: 'e.g. 7.5',
                              suffixText: '%',
                              isDense: true,
                              filled: true,
                              fillColor:
                                  isDark
                                      ? AppColors.darkBackground
                                      : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tax / AIT Rate Selection Card (Segmented Tax)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurface
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.percent_rounded,
                                  size: 16,
                                  color: AppColors.getPrimary(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tax / AIT (Advance Income Tax)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (_taxRate > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+৳${CurrencyFormatter.format(_taxAmount).replaceAll('৳', '').trim()} Tax',
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
                            ...[0.0, 2.0, 3.0, 5.0, 7.5, 10.0].map((rate) {
                              final isSelected =
                                  !_isCustomTax && _selectedTaxRate == rate;
                              return ChoiceChip(
                                label: Text(
                                  rate == 0.0
                                      ? '0% (No Tax)'
                                      : '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}%',
                                ),
                                selected: isSelected,
                                onSelected:
                                    isMultiCategory
                                        ? null
                                        : (val) {
                                          setState(() {
                                            _isCustomTax = false;
                                            _selectedTaxRate = rate;
                                          });
                                        },
                                selectedColor: AppColors.getPrimary(context),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : AppColors.textPrimary),
                                ),
                                backgroundColor:
                                    isDark
                                        ? AppColors.darkBackground
                                        : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color:
                                        isSelected
                                            ? AppColors.getPrimary(context)
                                            : (isDark
                                                ? AppColors.darkBorder
                                                : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                              );
                            }),
                            ChoiceChip(
                              label: const Text('Custom %'),
                              selected: _isCustomTax,
                              onSelected:
                                  isMultiCategory
                                      ? null
                                      : (val) {
                                        setState(() {
                                          _isCustomTax = true;
                                        });
                                      },
                              selectedColor: AppColors.getPrimary(context),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    _isCustomTax
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : AppColors.textPrimary),
                              ),
                              backgroundColor:
                                  isDark
                                      ? AppColors.darkBackground
                                      : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color:
                                      _isCustomTax
                                          ? AppColors.getPrimary(context)
                                          : (isDark
                                              ? AppColors.darkBorder
                                              : const Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isCustomTax) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _customTaxController,
                            readOnly: isMultiCategory,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Custom Tax Percentage (%)',
                              hintText: 'e.g. 4.5',
                              suffixText: '%',
                              isDense: true,
                              filled: true,
                              fillColor:
                                  isDark
                                      ? AppColors.darkBackground
                                      : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color:
                                      isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Segmented Cost Breakdown Card (Base + VAT + Tax = Total)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Expenditure Breakdown',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                              ),
                            ),
                            if (_vatRate > 0 || _taxRate > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Tax Segmented',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Base Invoice Cost:',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(_enteredAmount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (_vatRate > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'VAT (${_vatRate.toStringAsFixed(_vatRate.truncateToDouble() == _vatRate ? 0 : 1)}%):',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '+ ${CurrencyFormatter.format(_vatAmount)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_taxRate > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tax / AIT (${_taxRate.toStringAsFixed(_taxRate.truncateToDouble() == _taxRate ? 0 : 1)}%):',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '+ ${CurrencyFormatter.format(_taxAmount)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ],
                        Divider(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFF1F5F9),
                          height: 16,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Expense Added to Project:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(_netCost),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (!isMultiCategory)
                    CategoryDropdown(
                      categories: allCategories,
                      selectedCategoryId: _selectedCategory?.id,
                      onChanged:
                          (cat) => setState(() => _selectedCategory = cat),
                    ),
                  const SizedBox(height: 18),

                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Expense Date *',
                        suffixIcon: Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                        ),
                      ),
                      child: Text(
                        DateFormatter.formatWithDay(_selectedDate),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                        ),
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
                      if (val == null || val.trim().isEmpty)
                        return 'Note required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  Text('Receipt Attachment', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 8),
                  if (!isMultiCategory)
                    ReceiptUploader(
                      imagePath: _receiptImagePath,
                      onImageChanged:
                          (path) => setState(() => _receiptImagePath = path),
                    ),

                  if (_exceedsThresholdWithoutReceipt) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.amberDark.withValues(alpha: 0.2)
                                : AppColors.amberLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.amber.withValues(alpha: 0.4)
                                  : AppColors.amberBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: AppColors.amber,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Warning: Claims over \$${AppConstants.receiptRequiredThreshold.toStringAsFixed(0)} require a receipt under company policy.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color:
                                    isDark
                                        ? const Color(0xFFFDE68A)
                                        : AppColors.amberDark,
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
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  expense.status == ExpenseStatus.rejected
                                      ? 'Resubmit for Approval'
                                      : 'Save Changes',
                                  maxLines: 1,
                                ),
                              ),
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
