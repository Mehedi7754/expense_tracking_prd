import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';

class SubmitExpenseScreen extends ConsumerStatefulWidget {
  const SubmitExpenseScreen({super.key});

  @override
  ConsumerState<SubmitExpenseScreen> createState() => _SubmitExpenseScreenState();
}

class _SubmitExpenseScreenState extends ConsumerState<SubmitExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  ProjectModel? _selectedProject;
  String _selectedCategory = 'transportation'; // equipment, transportation, food, accommodation, office, other
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool _hasReceipt = true; // PRD Section 10: Receipt available Yes/No
  String? _receiptFileName;
  String? _receiptPath;
  bool _isSubmitting = false;

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

  @override
  void dispose() {
    _amountController.dispose();
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

  double get _currentAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  // PRD Section 9: 30% automatic office benefit calculation
  double get _officeBenefitAmount {
    final rate = _selectedProject?.officeBenefitRate ?? AppConstants.defaultOfficeBenefitRate;
    return _currentAmount * rate;
  }

  // PRD Section 6: Food allowance check
  bool get _exceedsFoodAllowance {
    if (_selectedCategory != 'food') return false;
    final people = int.tryParse(_foodPeopleCountController.text.trim()) ?? 1;
    final settings = ref.read(settingsProvider);
    final limit = settings.dailyFoodAllowance * (people > 0 ? people : 1);
    return _currentAmount > limit;
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _receiptPath = image.path;
          _receiptFileName = image.name.isNotEmpty ? image.name : image.path.split(RegExp(r'[/\\]')).last;
        });
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

  Future<void> _pickDocumentOrMedia() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickMedia();
      if (file != null) {
        setState(() {
          _receiptPath = file.path;
          _receiptFileName = file.name.isNotEmpty ? file.name : file.path.split(RegExp(r'[/\\]')).last;
        });
        if (mounted) {
          NotificationBanner.showSuccess(context, 'Receipt file attached: $_receiptFileName');
        }
      }
    } catch (_) {
      try {
        final picker = ImagePicker();
        final XFile? file = await picker.pickImage(source: ImageSource.gallery);
        if (file != null) {
          setState(() {
            _receiptPath = file.path;
            _receiptFileName = file.name.isNotEmpty ? file.name : file.path.split(RegExp(r'[/\\]')).last;
          });
          if (mounted) {
            NotificationBanner.showSuccess(context, 'Receipt file attached: $_receiptFileName');
          }
        }
      } catch (err) {
        if (mounted) {
          NotificationBanner.showError(context, 'Could not open file manager: $err');
        }
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProject == null) {
      NotificationBanner.showError(context, 'Please select an assigned project');
      return;
    }

    if (_currentAmount <= 0) {
      NotificationBanner.showError(context, 'Please enter a valid expense amount');
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final user = ref.read(authProvider).currentUser!;

    // Category specific details
    EquipmentDetails? equipDetails;
    TransportationDetails? transDetails;
    FoodDetails? foodDetails;
    AccommodationDetails? accommDetails;
    OfficeCostDetails? officeDetails;

    if (_selectedCategory == 'equipment') {
      equipDetails = EquipmentDetails(
        equipmentType: _equipTypeController.text.trim(),
        isRental: _isRental,
        quantity: int.tryParse(_equipQtyController.text.trim()) ?? 1,
        rentalAmount: double.tryParse(_rentalAmountController.text.trim()) ?? 0.0,
        rentalPeriod: _rentalPeriodController.text.trim(),
      );
    } else if (_selectedCategory == 'transportation') {
      transDetails = TransportationDetails(
        transportationType: _transportType,
        fromLocation: _fromController.text.trim(),
        toLocation: _toController.text.trim(),
        vehicle: _vehicleController.text.trim(),
        distanceKm: double.tryParse(_distanceController.text.trim()),
        fuelCost: double.tryParse(_fuelCostController.text.trim()),
        otherTransportCost: double.tryParse(_otherTransportCostController.text.trim()),
      );
    } else if (_selectedCategory == 'food') {
      foodDetails = FoodDetails(
        location: _foodLocationController.text.trim(),
        attendees: _foodAttendeesController.text.trim(),
        numberOfPeople: int.tryParse(_foodPeopleCountController.text.trim()) ?? 1,
        mealType: _mealType,
        exceedsFoodAllowance: _exceedsFoodAllowance,
      );
    } else if (_selectedCategory == 'accommodation') {
      accommDetails = AccommodationDetails(
        hotelName: _hotelNameController.text.trim(),
        location: _hotelLocationController.text.trim(),
        guests: _hotelGuestsController.text.trim(),
        numberOfNights: int.tryParse(_hotelNightsController.text.trim()) ?? 1,
        ratePerNight: double.tryParse(_hotelRateController.text.trim()) ?? 0.0,
      );
    } else if (_selectedCategory == 'office') {
      officeDetails = OfficeCostDetails(subCategory: _officeSubCategory);
    }

    ref.read(expenseProvider.notifier).submitExpense(
          employeeId: user.id,
          employeeName: user.name,
          projectId: _selectedProject!.id,
          projectName: _selectedProject!.name,
          amount: _currentAmount,
          officeBenefitRate: _selectedProject!.officeBenefitRate,
          currency: 'BDT',
          categoryId: 'cat_$_selectedCategory',
          categoryName: _getCategoryDisplayName(_selectedCategory),
          categoryIcon: _getCategoryIconName(_selectedCategory),
          note: _noteController.text.trim(),
          date: _selectedDate,
          hasReceipt: _hasReceipt,
          receiptPhotoUrl: _receiptPath ?? _receiptFileName,
          equipmentDetails: equipDetails,
          transportationDetails: transDetails,
          foodDetails: foodDetails,
          accommodationDetails: accommDetails,
          officeCostDetails: officeDetails,
        );

    NotificationBanner.showSuccess(
      context,
      _hasReceipt ? 'Expense submitted successfully' : 'Expense submitted (Flagged: No Receipt)',
    );
    context.pop();
  }

  String _getCategoryDisplayName(String cat) {
    switch (cat) {
      case 'equipment':
        return 'Equipment';
      case 'transportation':
        return 'Transportation';
      case 'food':
        return 'Food';
      case 'accommodation':
        return 'Accommodation';
      case 'office':
        return 'Office Cost';
      default:
        return 'Other';
    }
  }

  String _getCategoryIconName(String cat) {
    switch (cat) {
      case 'equipment':
        return 'hardware';
      case 'transportation':
        return 'transport';
      case 'food':
        return 'meal';
      case 'accommodation':
        return 'hotel';
      case 'office':
        return 'office';
      default:
        return 'other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = ref.watch(authProvider).currentUser;
    // Watch projectProvider for state reactivity across updates
    ref.watch(projectProvider);
    // PRD Section 1: Member should only see assigned projects in dropdown
    final assignedProjects = ref.read(projectProvider.notifier).getProjectsForUser(user);

    if (_selectedProject == null && assignedProjects.isNotEmpty) {
      _selectedProject = assignedProjects.first;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Add Expense (PFIS)', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // Project Selector (PRD Section 1: Assigned projects only)
                DropdownButtonFormField<ProjectModel>(
              isExpanded: true,
              value: _selectedProject,
              decoration: InputDecoration(
                labelText: 'Select Assigned Project *',
                prefixIcon: Icon(Icons.folder_shared_rounded, color: AppColors.getPrimary(context)),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.getPrimary(context), width: 1.8),
                ),
              ),
              items: assignedProjects.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(
                    '${p.projectId} - ${p.name}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              onChanged: (p) => setState(() => _selectedProject = p),
              validator: (v) => v == null ? 'Please select a project' : null,
            ),
            const SizedBox(height: 16),

            // Category Selector Chips (PRD Section 5 & 17)
            Text('Expense Category *', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('transportation', 'Transportation', Icons.directions_car_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildCategoryChip('food', 'Food', Icons.restaurant_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildCategoryChip('accommodation', 'Accommodation', Icons.hotel_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildCategoryChip('equipment', 'Equipment', Icons.precision_manufacturing_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildCategoryChip('office', 'Office Cost', Icons.business_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildCategoryChip('other', 'Other', Icons.category_rounded, isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Category Form (PRD Section 5)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                  if (_selectedCategory == 'equipment') _buildEquipmentForm(),
                  if (_selectedCategory == 'transportation') _buildTransportationForm(),
                  if (_selectedCategory == 'food') _buildFoodForm(),
                  if (_selectedCategory == 'accommodation') _buildAccommodationForm(),
                  if (_selectedCategory == 'office') _buildOfficeForm(),
                  if (_selectedCategory == 'other') _buildOtherForm(),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Amount, Date & Note
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Direct Expense Amount (৳) *',
                prefixText: '৳ ',
                prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.getPrimary(context)),
                hintText: 'e.g. 4500',
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.getPrimary(context), width: 2),
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter amount';
                if (double.tryParse(v.trim()) == null) return 'Enter valid number';
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
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Amount exceeds standard daily company food allowance (৳${ref.read(settingsProvider).dailyFoodAllowance.toInt()}/person). Management review may be required.',
                        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Expense Date',
                        suffixIcon: Icon(Icons.calendar_month_rounded, size: 18),
                      ),
                      child: Text(
                        DateFormatter.formatShort(_selectedDate),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Purpose / Description *',
                hintText: 'Describe business purpose, field location, attendees...',
              ),
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter purpose' : null,
            ),

            const SizedBox(height: 20),

            // Office Benefit Auto-Calculation (Clean Minimal SaaS Style)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Office Benefit (${((_selectedProject?.officeBenefitRate ?? 0.30) * 100).toInt()}%):',
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        CurrencyFormatter.format(_officeBenefitAmount),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9), height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Project Cost:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(
                        CurrencyFormatter.format(_currentAmount + _officeBenefitAmount),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5)),
                      ),
                    ],
                  ),
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
                  color: _hasReceipt
                      ? (isDark ? const Color(0xFF059669).withAlpha(60) : const Color(0xFFA7F3D0))
                      : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
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
                          color: (_hasReceipt ? const Color(0xFF10B981) : const Color(0xFF94A3B8)).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _hasReceipt ? Icons.receipt_long_rounded : Icons.receipt_outlined,
                          color: _hasReceipt ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasReceipt ? 'Receipt Available' : 'No Receipt Available',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _hasReceipt ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                            ),
                            Text(
                              _hasReceipt
                                  ? 'Receipt attached to verify claim'
                                  : 'Requires non-receipt justification',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
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
                      'Attach Receipt:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickReceipt(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: BorderSide(color: const Color(0xFF10B981).withAlpha(100)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _pickReceipt(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Gallery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: BorderSide(color: const Color(0xFF4F46E5).withAlpha(100)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickDocumentOrMedia,
                          icon: const Icon(Icons.folder_open_outlined, size: 16),
                          label: const Text('File Manager', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: BorderSide(color: const Color(0xFF0284C7).withAlpha(100)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    if (_receiptFileName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _receiptFileName!.endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                              size: 20,
                              color: _receiptFileName!.endsWith('.pdf') ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _receiptFileName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: Colors.grey,
                              onPressed: () => setState(() {
                                _receiptFileName = null;
                                _receiptPath = null;
                              }),
                            ),
                          ],
                        ),
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
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: const Text('Submit Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
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

  Widget _buildCategoryChip(String id, String label, IconData icon, bool isDark) {
    final isSelected = _selectedCategory == id;
    final primaryColor = isDark ? AppColors.brandPrimaryDark : AppColors.brandPrimary;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : const Color(0xFF334155)),
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
          decoration: const InputDecoration(labelText: 'Equipment Type *', hintText: 'e.g. GPS Device, Soil Tester, Drone'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                title: Text(_isRental ? 'Rental' : 'Purchase', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _isRental,
                onChanged: (v) => setState(() => _isRental = v),
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _equipQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
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
                  decoration: const InputDecoration(labelText: 'Rental Rate (৳)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _rentalPeriodController,
                  decoration: const InputDecoration(labelText: 'Period', hintText: 'e.g. 7 Days'),
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
          decoration: const InputDecoration(labelText: 'Transportation Type'),
          items: TransportationType.values.map((t) {
            return DropdownMenuItem(value: t, child: Text(t.displayName, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (v) => setState(() => _transportType = v!),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fromController,
                decoration: const InputDecoration(labelText: 'From Location', hintText: 'e.g. Dhaka'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _toController,
                decoration: const InputDecoration(labelText: 'To Location', hintText: 'e.g. Sylhet'),
              ),
            ),
          ],
        ),
        // For Private Vehicle (PRD Section 5: distance, fuel cost, cost per km)
        if (_transportType == TransportationType.privateCar) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _vehicleController,
            decoration: const InputDecoration(labelText: 'Vehicle Model / Reg Number', hintText: 'e.g. Toyota HiAce (Dhaka Metro-Ch-12-3456)'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _distanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Distance (KM)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _fuelCostController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fuel Cost (৳)'),
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
                decoration: const InputDecoration(labelText: 'Meal Location', hintText: 'e.g. Sunamganj Field Camp'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _foodPeopleCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of People'),
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
                decoration: const InputDecoration(labelText: 'Meal Type'),
                items: ['Breakfast', 'Lunch', 'Dinner', 'Refreshments / Tea'].map((m) {
                  return DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setState(() => _mealType = v!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _foodAttendeesController,
                decoration: const InputDecoration(labelText: 'Attendees', hintText: 'Names of staff'),
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
                decoration: const InputDecoration(labelText: 'Hotel / Accommodation', hintText: 'e.g. Hotel Noorjahan'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _hotelLocationController,
                decoration: const InputDecoration(labelText: 'Location', hintText: 'e.g. Sylhet Sadar'),
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
                decoration: const InputDecoration(labelText: 'Nights'),
                onChanged: (_) => _calcAccommodationTotal(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _hotelRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rate / Night (৳)'),
                onChanged: (_) => _calcAccommodationTotal(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _hotelGuestsController,
          decoration: const InputDecoration(labelText: 'Person / Guests', hintText: 'Names of accommodated members'),
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
      decoration: const InputDecoration(labelText: 'Office Cost Category'),
      items: [
        'Printing',
        'Photocopy',
        'Stationery',
        'Internet',
        'Communication',
        'Meeting expenses',
        'Temporary office',
        'Other',
      ].map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) => setState(() => _officeSubCategory = v!),
    );
  }

  Widget _buildOtherForm() {
    return const Text(
      'Enter general expense information below. Provide detailed description in the purpose field.',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
}
