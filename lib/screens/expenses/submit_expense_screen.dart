import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/expense_model.dart';
import '../../models/category_model.dart';
import '../../models/project_model.dart';
import '../../repositories/file_upload_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/category_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';

class SubmitExpenseScreen extends ConsumerStatefulWidget {
  const SubmitExpenseScreen({super.key});

  @override
  ConsumerState<SubmitExpenseScreen> createState() =>
      _SubmitExpenseScreenState();
}

class _SubmitExpenseScreenState extends ConsumerState<SubmitExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  ProjectModel? _selectedProject;
  bool _isOfficeExpense = false;
  String? _selectedCategory;
  final Map<String, ExpenseCategoryItem> _categoryDrafts = {};
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  late final TextEditingController _dateController = TextEditingController(
    text: DateFormatter.formatDayMonthYear(_selectedDate),
  );

  // VAT calculation state (Segmented VAT)
  double _selectedVatRate = 0.0;
  bool _isCustomVat = false;
  final _customVatController = TextEditingController();

  // Tax calculation state (Segmented Tax / AIT)
  double _selectedTaxRate = 0.0;
  bool _isCustomTax = false;
  final _customTaxController = TextEditingController();

  bool _hasReceipt = true; // PRD Section 10: Receipt available Yes/No
  String? _receiptFileName;
  final List<String> _receiptPaths = [];
  final List<String> _receiptFileNames = [];
  final Map<String, String> _uploadedReceiptUrlsByPath = {};
  bool _isUploadingReceipt = false;
  bool _isSubmitting = false;
  bool _categoriesLoaded = false;
  bool _categoryLoadSucceeded = false;

  // Category A: Equipment
  final _equipTypeController = TextEditingController();
  bool _isRental = false;
  final _equipQtyController = TextEditingController(text: '1');
  final _rentalAmountController = TextEditingController();
  final _rentalPeriodController = TextEditingController();

  // Category B: Transportation
  TransportationType _transportType = TransportationType.local;
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _distanceController = TextEditingController();
  final _fuelCostController = TextEditingController();
  final _otherTransportCostController = TextEditingController();

  // Category C: Food
  final _foodLocationController = TextEditingController();
  final _foodAttendeesController = TextEditingController();
  final _foodPeopleCountController = TextEditingController(text: '1');
  String _mealType = 'Lunch';

  // Category D: Accommodation
  final _hotelNameController = TextEditingController();
  final _hotelLocationController = TextEditingController();
  final _hotelGuestsController = TextEditingController();
  final _hotelNightsController = TextEditingController(text: '1');
  final _hotelRateController = TextEditingController();

  // Category E: Office Cost
  String _officeSubCategory = 'Printing';

  // Category F: Other Custom Category Name
  final _otherCategoryNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServerCategories();
  }

  Future<void> _loadServerCategories({bool force = false}) async {
    final loaded = await ref
        .read(categoryProvider.notifier)
        .fetchCategories(force: force);
    if (!mounted) return;
    final activeCategories = ref
        .read(categoryProvider)
        .where((category) => category.isActive);
    setState(() {
      _categoriesLoaded = true;
      _categoryLoadSucceeded = loaded;
      _selectedCategory ??= activeCategories.firstOrNull?.id;
    });
  }

  @override
  void dispose() {
    _dateController.dispose();
    _otherCategoryNameController.dispose();
    _amountController.dispose();
    _customVatController.dispose();
    _customTaxController.dispose();
    _noteController.dispose();
    _equipTypeController.dispose();
    _equipQtyController.dispose();
    _rentalAmountController.dispose();
    _rentalPeriodController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _vehicleController.dispose();
    _distanceController.dispose();
    _fuelCostController.dispose();
    _otherTransportCostController.dispose();
    _foodLocationController.dispose();
    _foodAttendeesController.dispose();
    _foodPeopleCountController.dispose();
    _hotelNameController.dispose();
    _hotelLocationController.dispose();
    _hotelGuestsController.dispose();
    _hotelNightsController.dispose();
    _hotelRateController.dispose();
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

  // Segmented Cost: Base Invoice Amount + VAT Amount + Tax/AIT Amount = Total Expense Added to Project
  double get _netCost => _enteredAmount + _vatAmount + _taxAmount;

  double get _baseCost => _enteredAmount;

  double get _totalCost => _netCost;

  double get _currentAmount => _netCost;

  double get _submittedTotal => _categoryDrafts.values.fold<double>(
    _currentAmount,
    (total, item) =>
        item.categoryId == _selectedCategory ? total : total + item.amount,
  );

  int get _categoryCount =>
      _categoryDrafts.keys.where((key) => key != _selectedCategory).length +
      (_currentAmount > 0 ? 1 : 0);

  CategoryModel? _categoryById(String? id) {
    if (id == null) return null;
    for (final category in ref.read(categoryProvider)) {
      if (category.id == id) return category;
    }
    return null;
  }

  String _categoryKind(String? id) {
    final category = _categoryById(id);
    final value =
        '${category?.name ?? ''} ${category?.iconName ?? ''}'.toLowerCase();
    if (value.contains('equip') ||
        value.contains('hardware') ||
        value.contains('device'))
      return 'equipment';
    if (value.contains('transport') ||
        value.contains('taxi') ||
        value.contains('travel') ||
        value.contains('flight'))
      return 'transportation';
    if (value.contains('food') ||
        value.contains('meal') ||
        value.contains('dining'))
      return 'food';
    if (value.contains('accommod') ||
        value.contains('lodg') ||
        value.contains('hotel'))
      return 'accommodation';
    if (value.contains('office') || value.contains('suppl')) return 'office';
    return 'other';
  }

  Color _categoryColor(String? id) {
    const palette = [
      Color(0xFF0D9488),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFF4F46E5),
      Color(0xFF0284C7),
      Color(0xFF64748B),
    ];
    return palette[(id?.hashCode ?? 0).abs() % palette.length];
  }

  Map<String, dynamic> _currentCategoryDetails() {
    switch (_categoryKind(_selectedCategory)) {
      case 'equipment':
        return {
          'equipment_type': _equipTypeController.text.trim(),
          'is_rental': _isRental,
          'quantity': int.tryParse(_equipQtyController.text.trim()) ?? 1,
          'rental_amount':
              double.tryParse(_rentalAmountController.text.trim()) ?? 0,
          'rental_period': _rentalPeriodController.text.trim(),
        };
      case 'transportation':
        return {
          'transportation_type': _transportType.name,
          'from_location': _fromController.text.trim(),
          'to_location': _toController.text.trim(),
          'vehicle': _vehicleController.text.trim(),
          'distance_km': double.tryParse(_distanceController.text.trim()),
          'fuel_cost': double.tryParse(_fuelCostController.text.trim()),
          'other_transport_cost': double.tryParse(
            _otherTransportCostController.text.trim(),
          ),
        };
      case 'food':
        return {
          'location': _foodLocationController.text.trim(),
          'attendees': _foodAttendeesController.text.trim(),
          'number_of_people':
              int.tryParse(_foodPeopleCountController.text.trim()) ?? 1,
          'meal_type': _mealType,
          'exceeds_food_allowance': _exceedsFoodAllowance,
        };
      case 'accommodation':
        return {
          'hotel_name': _hotelNameController.text.trim(),
          'location': _hotelLocationController.text.trim(),
          'guests': _hotelGuestsController.text.trim(),
          'number_of_nights':
              int.tryParse(_hotelNightsController.text.trim()) ?? 1,
          'rate_per_night':
              double.tryParse(_hotelRateController.text.trim()) ?? 0,
        };
      case 'office':
        return {'sub_category': _officeSubCategory};
      default:
        return {'additional_details': _otherCategoryNameController.text.trim()};
    }
  }

  void _storeCurrentCategory() {
    final key = _selectedCategory;
    final category = _categoryById(key);
    if (key == null || category == null) return;
    if (_enteredAmount <= 0 && _receiptPaths.isEmpty) {
      _categoryDrafts.remove(key);
      return;
    }
    _categoryDrafts[key] = ExpenseCategoryItem(
      categoryId: category.id,
      categoryName: category.name,
      categoryIcon: category.iconName,
      amount: _netCost,
      baseCost: _baseCost,
      vatRate: _vatRate,
      vatAmount: _vatAmount,
      taxRate: _taxRate,
      taxAmount: _taxAmount,
      details: _currentCategoryDetails(),
      receiptPhotoUrls: List<String>.from(_receiptPaths),
      hasReceipt: _hasReceipt,
    );
  }

  void _clearCategoryFields() {
    for (final controller in [
      _amountController,
      _customVatController,
      _customTaxController,
      _equipTypeController,
      _equipQtyController,
      _rentalAmountController,
      _rentalPeriodController,
      _fromController,
      _toController,
      _vehicleController,
      _distanceController,
      _fuelCostController,
      _otherTransportCostController,
      _foodLocationController,
      _foodAttendeesController,
      _hotelNameController,
      _hotelLocationController,
      _hotelGuestsController,
      _hotelNightsController,
      _hotelRateController,
      _otherCategoryNameController,
    ]) {
      controller.clear();
    }
    _equipQtyController.text = '1';
    _foodPeopleCountController.text = '1';
    _hotelNightsController.text = '1';
    _isRental = false;
    _transportType = TransportationType.local;
    _mealType = 'Lunch';
    _officeSubCategory = 'Printing';
    _selectedVatRate = 0;
    _selectedTaxRate = 0;
    _isCustomVat = false;
    _isCustomTax = false;
    _hasReceipt = true;
    _receiptPaths.clear();
    _receiptFileNames.clear();
    _receiptFileName = null;
  }

  void _restoreCategory(ExpenseCategoryItem? item) {
    _clearCategoryFields();
    if (item == null) return;
    _amountController.text = item.baseCost.toString();
    _selectedVatRate = item.vatRate;
    _selectedTaxRate = item.taxRate;
    _isCustomVat =
        item.vatRate > 0 && ![5.0, 7.5, 10.0, 15.0].contains(item.vatRate);
    _isCustomTax =
        item.taxRate > 0 && ![2.0, 3.0, 5.0, 7.5, 10.0].contains(item.taxRate);
    if (_isCustomVat) _customVatController.text = item.vatRate.toString();
    if (_isCustomTax) _customTaxController.text = item.taxRate.toString();
    final details = item.details;
    _equipTypeController.text = (details['equipment_type'] ?? '').toString();
    _isRental = details['is_rental'] as bool? ?? false;
    _equipQtyController.text = (details['quantity'] ?? 1).toString();
    _rentalAmountController.text = (details['rental_amount'] ?? '').toString();
    _rentalPeriodController.text = (details['rental_period'] ?? '').toString();
    _fromController.text = (details['from_location'] ?? '').toString();
    _toController.text = (details['to_location'] ?? '').toString();
    _transportType = TransportationType.values.firstWhere(
      (value) => value.name == details['transportation_type'],
      orElse: () => TransportationType.local,
    );
    _vehicleController.text = (details['vehicle'] ?? '').toString();
    _distanceController.text = (details['distance_km'] ?? '').toString();
    _fuelCostController.text = (details['fuel_cost'] ?? '').toString();
    _otherTransportCostController.text =
        (details['other_transport_cost'] ?? '').toString();
    _foodLocationController.text = (details['location'] ?? '').toString();
    _foodAttendeesController.text = (details['attendees'] ?? '').toString();
    _foodPeopleCountController.text =
        (details['number_of_people'] ?? 1).toString();
    _mealType = (details['meal_type'] ?? 'Lunch').toString();
    _hotelNameController.text = (details['hotel_name'] ?? '').toString();
    _hotelLocationController.text = (details['location'] ?? '').toString();
    _hotelGuestsController.text = (details['guests'] ?? '').toString();
    _hotelNightsController.text = (details['number_of_nights'] ?? 1).toString();
    _hotelRateController.text = (details['rate_per_night'] ?? '').toString();
    _officeSubCategory = (details['sub_category'] ?? 'Printing').toString();
    _otherCategoryNameController.text =
        (details['additional_details'] ?? details['custom_category_name'] ?? '')
            .toString();
    _hasReceipt = item.hasReceipt;
    _receiptPaths.addAll(item.receiptPhotoUrls);
    _receiptFileNames.addAll(
      item.receiptPhotoUrls.map((path) => path.split(RegExp(r'[/\\]')).last),
    );
    _receiptFileName = _receiptFileNames.firstOrNull;
  }

  void _selectCategory(String category) {
    if (category == _selectedCategory) return;
    _storeCurrentCategory();
    setState(() {
      _selectedCategory = category;
      _restoreCategory(_categoryDrafts[category]);
    });
  }

  // PRD Section 6: Food allowance check
  bool get _exceedsFoodAllowance {
    if (_categoryKind(_selectedCategory) != 'food') return false;
    final people = int.tryParse(_foodPeopleCountController.text.trim()) ?? 1;
    final projectAllowance = _selectedProject?.dailyFoodAllowance;
    final baseAllowance =
        (projectAllowance != null && projectAllowance > 0)
            ? projectAllowance
            : ref.read(settingsProvider).dailyFoodAllowance;
    final limit = baseAllowance * (people > 0 ? people : 1);
    return _totalCost > limit;
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final List<XFile> images = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (images.isNotEmpty) {
          final newPaths = <String>[];
          for (final img in images) {
            final name =
                img.name.isNotEmpty
                    ? img.name
                    : img.path.split(RegExp(r'[/\\]')).last;
            if (!_receiptPaths.contains(img.path)) {
              _receiptPaths.add(img.path);
              _receiptFileNames.add(name);
              newPaths.add(img.path);
            }
          }
          setState(() {
            _receiptFileName = _receiptFileNames.first;
          });
          _uploadBatchReceipts(newPaths);
          if (mounted) {
            NotificationBanner.showSuccess(
              context,
              '${images.length} receipt image(s) selected from Gallery',
            );
          }
          return;
        }
      }

      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        final name =
            image.name.isNotEmpty
                ? image.name
                : image.path.split(RegExp(r'[/\\]')).last;
        setState(() {
          if (!_receiptPaths.contains(image.path)) {
            _receiptPaths.add(image.path);
            _receiptFileNames.add(name);
          }
          _receiptFileName = _receiptFileNames.first;
        });
        _uploadBatchReceipts([image.path]);
        if (mounted) {
          NotificationBanner.showSuccess(
            context,
            source == ImageSource.camera
                ? 'Receipt photo captured from Camera'
                : 'Receipt image selected from Gallery',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationBanner.showError(
          context,
          'Could not access ${source == ImageSource.camera ? "camera" : "gallery"}: $e',
        );
      }
    }
  }

  Future<void> _uploadBatchReceipts(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    setState(() => _isUploadingReceipt = true);
    try {
      final uploadRepo = ref.read(fileUploadRepositoryProvider);
      final results = await uploadRepo.uploadBatch(
        filePathsOrDataUris: filePaths,
        category: UploadCategory.receipts,
      );
      if (mounted) {
        setState(() {
          for (var i = 0; i < results.length; i++) {
            _uploadedReceiptUrlsByPath[filePaths[i]] = results[i].url;
          }
          _isUploadingReceipt = false;
        });
        NotificationBanner.showSuccess(
          context,
          'Receipt(s) uploaded successfully to cloud!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingReceipt = false);
        NotificationBanner.showError(
          context,
          'Receipt upload failed. Please retry before submitting.',
        );
      }
    }
  }

  Future<void> _pickDocumentOrMedia() async {
    try {
      final picker = ImagePicker();
      final List<XFile> files = await picker.pickMultipleMedia();
      if (files.isNotEmpty) {
        final newPaths = <String>[];
        for (final file in files) {
          final name =
              file.name.isNotEmpty
                  ? file.name
                  : file.path.split(RegExp(r'[/\\]')).last;
          if (!_receiptPaths.contains(file.path)) {
            _receiptPaths.add(file.path);
            _receiptFileNames.add(name);
            newPaths.add(file.path);
          }
        }
        setState(() {
          _receiptFileName = _receiptFileNames.first;
        });
        _uploadBatchReceipts(newPaths);
        if (mounted) {
          NotificationBanner.showSuccess(
            context,
            '${files.length} file(s) attached',
          );
        }
        return;
      }
    } catch (_) {
      try {
        final picker = ImagePicker();
        final XFile? file = await picker.pickImage(source: ImageSource.gallery);
        if (file != null) {
          final name =
              file.name.isNotEmpty
                  ? file.name
                  : file.path.split(RegExp(r'[/\\]')).last;
          setState(() {
            if (!_receiptPaths.contains(file.path)) {
              _receiptPaths.add(file.path);
              _receiptFileNames.add(name);
            }
            _receiptFileName = _receiptFileNames.first;
          });
          _uploadBatchReceipts([file.path]);
          if (mounted) {
            NotificationBanner.showSuccess(
              context,
              'Receipt file attached: $name',
            );
          }
        }
      } catch (err) {
        if (mounted) {
          NotificationBanner.showError(
            context,
            'Could not open file manager: $err',
          );
        }
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoryById(_selectedCategory) == null) {
      NotificationBanner.showError(
        context,
        'Select an expense category from the server list.',
      );
      return;
    }

    if (!_isOfficeExpense && _selectedProject == null) {
      NotificationBanner.showError(
        context,
        'Please select an assigned project',
      );
      return;
    }

    if (!_isOfficeExpense &&
        (_selectedProject!.isClosed ||
            _selectedProject!.status == ProjectStatus.completed)) {
      NotificationBanner.showError(
        context,
        'Cannot submit expenses for a closed project',
      );
      return;
    }

    _storeCurrentCategory();
    final drafts =
        _categoryDrafts.values.where((item) => item.amount > 0).toList();
    if (drafts.isEmpty) {
      NotificationBanner.showError(
        context,
        'Enter an amount for at least one expense category.',
      );
      return;
    }
    if (drafts.any(
      (item) => item.hasReceipt && item.receiptPhotoUrls.isEmpty,
    )) {
      NotificationBanner.showError(
        context,
        'Attach a receipt to every category marked as receipt available.',
      );
      return;
    }
    if (drafts.any((item) => !item.hasReceipt) &&
        _noteController.text.trim().isEmpty) {
      NotificationBanner.showError(
        context,
        'A justification is required in the Note field when submitting without a receipt.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final user = ref.read(authProvider).currentUser!;

    try {
      final allPaths =
          drafts
              .where((item) => item.hasReceipt)
              .expand((item) => item.receiptPhotoUrls)
              .toSet()
              .toList();
      final missingPaths =
          allPaths
              .where((path) => !_uploadedReceiptUrlsByPath.containsKey(path))
              .toList();
      if (missingPaths.isNotEmpty) {
        final uploaded = await ref
            .read(fileUploadRepositoryProvider)
            .uploadBatch(
              filePathsOrDataUris: missingPaths,
              category: UploadCategory.receipts,
            );
        for (var i = 0; i < missingPaths.length; i++) {
          _uploadedReceiptUrlsByPath[missingPaths[i]] = uploaded[i].url;
        }
      }
      final categoryItems =
          drafts
              .map(
                (item) => item.copyWith(
                  receiptPhotoUrls:
                      item.hasReceipt
                          ? item.receiptPhotoUrls
                              .map((path) => _uploadedReceiptUrlsByPath[path])
                              .whereType<String>()
                              .toList()
                          : const [],
                ),
              )
              .toList();
      if (categoryItems.any(
        (item) => item.hasReceipt && item.receiptPhotoUrls.isEmpty,
      )) {
        throw StateError(
          'All category receipts must finish uploading before submission',
        );
      }
      final effectiveReceiptUrls =
          categoryItems
              .expand((item) => item.receiptPhotoUrls)
              .toSet()
              .toList();
      final effectiveReceipt =
          effectiveReceiptUrls.isEmpty ? null : effectiveReceiptUrls.first;
      final baseCost = categoryItems.fold<double>(
        0,
        (sum, item) => sum + item.baseCost,
      );
      final vatAmount = categoryItems.fold<double>(
        0,
        (sum, item) => sum + item.vatAmount,
      );
      final taxAmount = categoryItems.fold<double>(
        0,
        (sum, item) => sum + item.taxAmount,
      );
      final totalAmount = categoryItems.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      final vatRate = baseCost > 0 ? vatAmount / baseCost * 100 : 0.0;
      final taxRate = baseCost > 0 ? taxAmount / baseCost * 100 : 0.0;
      final categoryNames =
          categoryItems.map((item) => item.categoryName).toList();
      final primaryCategory = categoryItems.first;

      await ref
          .read(expenseProvider.notifier)
          .submitExpense(
            employeeId: user.id,
            employeeName: user.name,
            projectId: _isOfficeExpense ? '' : _selectedProject!.id,
            projectName:
                _isOfficeExpense
                    ? 'Office / Non-project'
                    : _selectedProject!.name,
            expenseType: _isOfficeExpense ? 'office' : 'project',
            amount: totalAmount,
            baseCost: baseCost,
            vatRate: vatRate,
            vatAmount: vatAmount,
            taxRate: taxRate,
            taxAmount: taxAmount,
            officeBenefitRate: 0.0,
            currency: 'BDT',
            categoryId: primaryCategory.categoryId,
            categoryName: categoryNames.join(' + '),
            categoryIcon: primaryCategory.categoryIcon,
            note: _noteController.text.trim(),
            date: _selectedDate,
            hasReceipt: categoryItems.any((item) => item.hasReceipt),
            receiptPhotoUrl: effectiveReceipt,
            receiptPhotoUrls: effectiveReceiptUrls,
            categoryItems: categoryItems,
          );

      if (mounted) {
        NotificationBanner.showSuccess(
          context,
          'Expense submitted with ${categoryItems.length} ${categoryItems.length == 1 ? 'category' : 'categories'} successfully!',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final errorMsg = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
        NotificationBanner.showError(
          context,
          'Failed to submit expense: $errorMsg',
        );
      }
    }
  }

  String _getCategoryDisplayName(String? id) =>
      _categoryById(id)?.name ?? 'Expense Category';

  IconData _getCategoryIcon(String? id) {
    final icon = _categoryById(id)?.iconName.toLowerCase() ?? '';
    if (icon.contains('transport') || icon.contains('taxi')) {
      return Icons.directions_car_rounded;
    }
    if (icon.contains('food') || icon.contains('meal')) {
      return Icons.restaurant_rounded;
    }
    if (icon.contains('hotel') || icon.contains('lodg')) {
      return Icons.hotel_rounded;
    }
    if (icon.contains('hardware') || icon.contains('equip')) {
      return Icons.precision_manufacturing_rounded;
    }
    if (icon.contains('office')) return Icons.business_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories =
        ref.watch(categoryProvider).where((c) => c.isActive).toList();
    if (!_categoriesLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_categoryLoadSucceeded || categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Submit Expense')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Expense categories could not be loaded from settings.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() => _categoriesLoaded = false);
                    _loadServerCategories(force: true);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final selectedCategoryKind = _categoryKind(_selectedCategory);

    final user = ref.watch(authProvider).currentUser;
    // Watch projectProvider for state reactivity across updates
    ref.watch(projectProvider);
    // PRD Section 1: Member should only see assigned projects in dropdown.
    // Closed or completed projects are excluded from expense claim submission.
    final allAssigned = ref
        .read(projectProvider.notifier)
        .getProjectsForUser(user);
    final assignedProjects =
        allAssigned
            .where((p) => !p.isClosed && p.status != ProjectStatus.completed)
            .toList();

    if (_selectedProject != null &&
        !assignedProjects.contains(_selectedProject)) {
      _selectedProject =
          assignedProjects.isNotEmpty ? assignedProjects.first : null;
    } else if (_selectedProject == null && assignedProjects.isNotEmpty) {
      _selectedProject = assignedProjects.first;
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Add Expense (GW Project)',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'Expense type',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Project expense'),
                      selected: !_isOfficeExpense,
                      onSelected:
                          (_) => setState(() => _isOfficeExpense = false),
                    ),
                    ChoiceChip(
                      label: const Text('Office / non-project'),
                      selected: _isOfficeExpense,
                      onSelected:
                          (_) => setState(() => _isOfficeExpense = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_isOfficeExpense) ...[
                  // Project Selector (PRD Section 1: Assigned projects only)
                  DropdownButtonFormField<ProjectModel>(
                    isExpanded: true,
                    value: _selectedProject,
                    decoration: InputDecoration(
                      labelText: 'Select Assigned Project *',
                      prefixIcon: Icon(
                        Icons.folder_shared_rounded,
                        color: AppColors.getPrimary(context),
                      ),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.getPrimary(context),
                          width: 1.8,
                        ),
                      ),
                    ),
                    items:
                        assignedProjects.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(
                              '${p.projectId} - ${p.name}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (p) => setState(() => _selectedProject = p),
                    validator:
                        (v) => v == null ? 'Please select a project' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Category Selector Chips (PRD Section 5 & 17)
                Text(
                  'Expense Category *',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final category in categories) ...[
                        _buildCategoryChip(category, isDark),
                        if (category != categories.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                if (_categoryDrafts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _categoryDrafts.entries.map((entry) {
                          final color = _categoryColor(entry.key);
                          final isActive = entry.key == _selectedCategory;
                          final amount =
                              isActive ? _currentAmount : entry.value.amount;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: color.withAlpha(100)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: color,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${entry.value.categoryName} · ${CurrencyFormatter.format(amount)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                // Dynamic Category Form (PRD Section 5)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getCategoryDisplayName(_selectedCategory)} Details',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.getPrimary(context),
                        ),
                      ),
                      const Divider(height: 20),
                      if (selectedCategoryKind == 'equipment')
                        _buildEquipmentForm(),
                      if (selectedCategoryKind == 'transportation')
                        _buildTransportationForm(),
                      if (selectedCategoryKind == 'food') _buildFoodForm(),
                      if (selectedCategoryKind == 'accommodation')
                        _buildAccommodationForm(),
                      if (selectedCategoryKind == 'office') _buildOfficeForm(),
                      if (selectedCategoryKind == 'other') _buildOtherForm(),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Amount, Date & Note
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Base Expense Cost (৳) *',
                    prefixText: '৳ ',
                    prefixStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getPrimary(context),
                    ),
                    hintText: 'e.g. 4500 (before tax)',
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.getPrimary(context),
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if ((v == null || v.trim().isEmpty) &&
                        _categoryDrafts.values.any((item) => item.amount > 0)) {
                      return null;
                    }
                    if (v == null || v.trim().isEmpty) return 'Enter amount';
                    final amount = double.tryParse(v.trim());
                    if (amount == null || amount < 0)
                      return 'Enter valid number';
                    return null;
                  },
                ),

                // Food Allowance Alert (PRD Section 6)
                if (_exceedsFoodAllowance)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Amount exceeds standard daily company food allowance (৳${ref.read(settingsProvider).dailyFoodAllowance.toInt()}/person). Management review may be required.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

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
                              onSelected: (val) {
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
                            onSelected: (val) {
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
                            onSelected: (val) {
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

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateController,
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          labelText: 'Expense Date (DD/MM/YYYY) *',
                          hintText: 'e.g. 12/05/2026',
                          prefixIcon: const Icon(
                            Icons.edit_calendar_rounded,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                              color: Color(0xFF2563EB),
                            ),
                            tooltip: 'Choose date from calendar',
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                  _dateController.text =
                                      DateFormatter.formatDayMonthYear(picked);
                                });
                              }
                            },
                          ),
                        ),
                        onChanged: (val) {
                          final trimmed = val.trim();
                          final parts = trimmed.split(RegExp(r'[-/.]'));
                          if (parts.length == 3) {
                            final d = int.tryParse(parts[0]);
                            final m = int.tryParse(parts[1]);
                            final y = int.tryParse(parts[2]);
                            if (d != null &&
                                m != null &&
                                y != null &&
                                y >= 1990 &&
                                y <= 2040 &&
                                m >= 1 &&
                                m <= 12 &&
                                d >= 1 &&
                                d <= 31) {
                              try {
                                final parsed = DateTime(y, m, d);
                                setState(() => _selectedDate = parsed);
                              } catch (_) {}
                            }
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Please enter expense date';
                          final parts = v.trim().split(RegExp(r'[-/.]'));
                          if (parts.length != 3) return 'Format: DD/MM/YYYY';
                          final d = int.tryParse(parts[0]);
                          final m = int.tryParse(parts[1]);
                          final y = int.tryParse(parts[2]);
                          if (d == null ||
                              m == null ||
                              y == null ||
                              y < 1990 ||
                              y > 2040 ||
                              m < 1 ||
                              m > 12 ||
                              d < 1 ||
                              d > 31) {
                            return 'Invalid date value';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText:
                        _hasReceipt
                            ? 'Purpose / Description *'
                            : 'Purpose / Non-Receipt Justification *',
                    hintText:
                        'Describe business purpose, field location, attendees...',
                  ),
                  maxLines: 2,
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Please enter purpose'
                              : null,
                ),

                const SizedBox(height: 20),

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
                            CurrencyFormatter.format(
                              _enteredAmount,
                              includeDecimals: _enteredAmount % 1 != 0,
                            ),
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
                              '+ ${CurrencyFormatter.format(_vatAmount, includeDecimals: _vatAmount % 1 != 0)}',
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
                              '+ ${CurrencyFormatter.format(_taxAmount, includeDecimals: _taxAmount % 1 != 0)}',
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
                          Text(
                            _categoryCount > 1
                                ? 'Current category total:'
                                : 'Total Expense Added to Project:',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(
                              _netCost,
                              includeDecimals:
                                  _netCost % 1 != 0 ||
                                  _vatAmount % 1 != 0 ||
                                  _taxAmount % 1 != 0,
                            ),
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
                      if (_categoryCount > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'All categories total:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(_submittedTotal),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Receipt Management (Clean Modern Card)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          _hasReceipt
                              ? (isDark
                                  ? const Color(0xFF059669).withAlpha(60)
                                  : const Color(0xFFA7F3D0))
                              : (isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: (_hasReceipt
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8))
                                  .withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _hasReceipt
                                  ? Icons.receipt_long_rounded
                                  : Icons.receipt_outlined,
                              color:
                                  _hasReceipt
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF64748B),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasReceipt
                                      ? 'Receipt Available'
                                      : 'No Receipt Available',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        _hasReceipt
                                            ? const Color(0xFF10B981)
                                            : (isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  _hasReceipt
                                      ? 'Receipt attached to verify claim'
                                      : 'Requires non-receipt justification',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        isDark
                                            ? AppColors.darkTextMuted
                                            : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _hasReceipt,
                            activeTrackColor: const Color(0xFF10B981),
                            onChanged: (v) => setState(() => _hasReceipt = v),
                          ),
                        ],
                      ),

                      if (_hasReceipt) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Receipts for ${_getCategoryDisplayName(_selectedCategory)}:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickReceipt(ImageSource.camera),
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'Camera',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF10B981),
                                side: BorderSide(
                                  color: const Color(0xFF10B981).withAlpha(100),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  () => _pickReceipt(ImageSource.gallery),
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'Gallery',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: BorderSide(
                                  color: const Color(0xFF4F46E5).withAlpha(100),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickDocumentOrMedia,
                              icon: const Icon(
                                Icons.folder_open_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'File Manager',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0284C7),
                                side: BorderSide(
                                  color: const Color(0xFF0284C7).withAlpha(100),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_receiptFileNames.isNotEmpty ||
                            _receiptFileName != null) ...[
                          const SizedBox(height: 12),
                          ...List.generate(
                            _receiptFileNames.isNotEmpty
                                ? _receiptFileNames.length
                                : 1,
                            (index) {
                              final name =
                                  _receiptFileNames.isNotEmpty
                                      ? _receiptFileNames[index]
                                      : (_receiptFileName ?? 'Receipt');
                              final isPdf = name.toLowerCase().endsWith('.pdf');
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? AppColors.darkBackground
                                          : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? AppColors.darkBorder
                                            : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isPdf
                                          ? Icons.picture_as_pdf_rounded
                                          : Icons.image_rounded,
                                      size: 20,
                                      color:
                                          isPdf
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF1E293B,
                                                        ),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_isUploadingReceipt) ...[
                                            const SizedBox(width: 8),
                                            const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: Colors.grey,
                                      onPressed:
                                          () => setState(() {
                                            if (_receiptFileNames.isNotEmpty &&
                                                index <
                                                    _receiptFileNames.length) {
                                              _receiptFileNames.removeAt(index);
                                              if (index <
                                                  _receiptPaths.length) {
                                                _uploadedReceiptUrlsByPath
                                                    .remove(
                                                      _receiptPaths[index],
                                                    );
                                                _receiptPaths.removeAt(index);
                                              }
                                              _receiptFileName =
                                                  _receiptFileNames.isNotEmpty
                                                      ? _receiptFileNames.first
                                                      : null;
                                            } else {
                                              _receiptFileName = null;
                                            }
                                            if (_receiptFileNames.isEmpty &&
                                                _receiptFileName == null) {
                                              _hasReceipt = false;
                                            }
                                          }),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // Submit Button (Clean Modern Style, No Glow)
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isSubmitting || _isUploadingReceipt
                            ? null
                            : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon:
                        _isSubmitting
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    label: const Text(
                      'Submit Expense',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(CategoryModel category, bool isDark) {
    final id = category.id;
    final label = category.name;
    final isSelected = _selectedCategory == id;
    final categoryColor = _categoryColor(id);
    final primaryColor =
        isSelected
            ? categoryColor
            : (isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary);
    final saved = _categoryDrafts[id];
    final amount = isSelected ? _currentAmount : saved?.amount;
    return GestureDetector(
      onTap: () => _selectCategory(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? primaryColor
                  : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? primaryColor
                    : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getCategoryIcon(id),
              size: 16,
              color:
                  isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              saved != null && amount != null && amount > 0
                  ? '$label · ${CurrencyFormatter.format(amount)}'
                  : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Category Sub-Forms
  Widget _buildEquipmentForm() {
    return Column(
      children: [
        TextFormField(
          controller: _equipTypeController,
          decoration: InputDecoration(
            labelText: 'Equipment Type *',
            hintText: 'e.g. GPS Device, Soil Tester, Drone',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                title: Text(
                  _isRental ? 'Rental' : 'Purchase',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: _isRental,
                onChanged: (v) => setState(() => _isRental = v),
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _equipQtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantity'),
              ),
            ),
          ],
        ),
        if (_isRental) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _rentalAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Rental Rate (৳)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _rentalPeriodController,
                  decoration: InputDecoration(
                    labelText: 'Period',
                    hintText: 'e.g. 7 Days',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTransportationForm() {
    return Column(
      children: [
        DropdownButtonFormField<TransportationType>(
          value: _transportType,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Transportation Type'),
          items:
              TransportationType.values.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(t.displayName, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
          onChanged: (v) => setState(() => _transportType = v!),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fromController,
                decoration: InputDecoration(
                  labelText: 'From Location',
                  hintText: 'e.g. Dhaka',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _toController,
                decoration: InputDecoration(
                  labelText: 'To Location',
                  hintText: 'e.g. Sylhet',
                ),
              ),
            ),
          ],
        ),
        // For Private Vehicle (PRD Section 5: distance, fuel cost, cost per km)
        if (_transportType == TransportationType.privateCar) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _vehicleController,
            decoration: InputDecoration(
              labelText: 'Vehicle Model / Reg Number',
              hintText: 'e.g. Toyota HiAce (Dhaka Metro-Ch-12-3456)',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _distanceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Distance (KM)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _fuelCostController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Fuel Cost (৳)'),
                  onChanged: (v) {
                    _amountController.text = v;
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFoodForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _foodLocationController,
                decoration: InputDecoration(
                  labelText: 'Meal Location',
                  hintText: 'e.g. Sunamganj Field Camp',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _foodPeopleCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Number of People'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _mealType,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Meal Type'),
                items:
                    [
                      'Breakfast',
                      'Lunch',
                      'Dinner',
                      'Refreshments / Tea',
                      'Full-Day Meal',
                    ].map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(m, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                onChanged: (v) => setState(() => _mealType = v!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _foodAttendeesController,
                decoration: InputDecoration(
                  labelText: 'Attendees',
                  hintText: 'Names of staff',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccommodationForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _hotelNameController,
                decoration: InputDecoration(
                  labelText: 'Hotel / Accommodation',
                  hintText: 'e.g. Hotel Noorjahan',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _hotelLocationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Sylhet Sadar',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _hotelNightsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Nights'),
                onChanged: (_) => _calcAccommodationTotal(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _hotelRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Rate / Night (৳)'),
                onChanged: (_) => _calcAccommodationTotal(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _hotelGuestsController,
          decoration: InputDecoration(
            labelText: 'Person / Guests',
            hintText: 'Names of accommodated members',
          ),
        ),
      ],
    );
  }

  void _calcAccommodationTotal() {
    final nights = int.tryParse(_hotelNightsController.text.trim()) ?? 1;
    final rate = double.tryParse(_hotelRateController.text.trim()) ?? 0.0;
    if (nights > 0 && rate > 0) {
      _amountController.text = (nights * rate).toStringAsFixed(0);
      setState(() {});
    }
  }

  Widget _buildOfficeForm() {
    return DropdownButtonFormField<String>(
      value: _officeSubCategory,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'Office Cost Category'),
      items:
          [
                'Printing',
                'Photocopy',
                'Stationery',
                'Internet',
                'Communication',
                'Meeting expenses',
                'Temporary office',
                'Other',
              ]
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged: (v) => setState(() => _officeSubCategory = v!),
    );
  }

  Widget _buildOtherForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _otherCategoryNameController,
          decoration: InputDecoration(
            labelText: '${_getCategoryDisplayName(_selectedCategory)} Details',
            hintText: 'Add details about this expense category',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Provide specific category details or purpose in the description field below.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
