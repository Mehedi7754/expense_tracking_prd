import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/location_pin_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../models/client_model.dart';
import '../../models/project_model.dart';
import '../../repositories/file_upload_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';
import '../../state/attendance_settings_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/user_management_provider.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';

class AddEditProjectScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const AddEditProjectScreen({super.key, this.projectId});

  @override
  ConsumerState<AddEditProjectScreen> createState() =>
      _AddEditProjectScreenState();
}

class _AddEditProjectScreenState extends ConsumerState<AddEditProjectScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _clientController = TextEditingController();
  final _grossValueController = TextEditingController();
  final _advanceReceivedController = TextEditingController();
  final _amountReceivedController = TextEditingController();

  // Category Budgets
  final _equipBudgetController = TextEditingController();
  final _transportBudgetController = TextEditingController();
  final _foodBudgetController = TextEditingController();
  final _accommBudgetController = TextEditingController();
  final _officeBudgetController = TextEditingController();
  final Map<String, TextEditingController> _customCategoryControllers = {};

  ClientType _clientType = ClientType.government;
  AssignmentType _assignmentType = AssignmentType.directConsultancy;
  ProjectStatus _status = ProjectStatus.ongoing;
  TaxStatus _taxStatus = TaxStatus.included;
  double _taxRate = 0.10; // 10% VAT
  double _incomeTaxRate = 0.05; // 5% Income Tax (IT)
  double _officeBenefitRate = 0.30; // 30% default

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 180));
  final Set<String> _selectedTeamMemberIds = {};
  final Map<String, ProjectMember> _memberAssignments = {};
  final _memberSearchController = TextEditingController();
  String _memberSearchQuery = '';
  String? _imageUrl;
  double? _siteLatitude;
  double? _siteLongitude;
  double? _siteRadiusMeters;
  bool _clearSiteLocation = false;
  bool _initialized = false;
  bool _isSaving = false;

  bool get isEditing => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userManagementProvider.notifier).fetchUsers();
      if (!isEditing) {
        final currentUser = ref.read(authProvider).currentUser;
        if (currentUser != null && mounted) {
          setState(() {
            _selectedTeamMemberIds.add(currentUser.id);
            _memberAssignments[currentUser.id] = ProjectMember(
              userId: currentUser.id,
              roleInProject: 'Owner',
              fullName: currentUser.name,
              email: currentUser.email,
              permissions: const ProjectPermissions(
                canViewBudget: true,
                canRecordRevenue: true,
                canViewExpenses: true,
                canCreateExpenses: true,
                canApproveExpenses: true,
                canManageTasks: true,
                canUpdateProgress: true,
                canManageTeam: true,
                canEditProject: true,
                canViewAttendance: true,
              ),
            );
          });
        }
      }
    });
  }

  void _initProject(ProjectModel project) {
    if (_initialized) return;
    _initialized = true;

    _nameController.text = project.name;
    _descController.text = project.description;
    _clientController.text = project.client;
    _clientType = project.clientType;
    _assignmentType = project.assignmentType;
    _status = project.status;
    _taxStatus = project.taxStatus;
    _taxRate = project.taxRate;
    _incomeTaxRate = project.incomeTaxRate;
    _officeBenefitRate = project.officeBenefitRate;
    _imageUrl = project.imageUrl;
    _siteLatitude = project.siteLatitude;
    _siteLongitude = project.siteLongitude;
    _siteRadiusMeters = project.siteRadiusMeters;

    _grossValueController.text = project.grossProjectValue.toStringAsFixed(0);
    _advanceReceivedController.text = project.advanceReceived.toStringAsFixed(
      0,
    );
    _amountReceivedController.text = project.amountReceived.toStringAsFixed(0);

    _equipBudgetController.text = (project.categoryBudgets['equipment'] ?? 0)
        .toStringAsFixed(0);
    _transportBudgetController.text =
        (project.categoryBudgets['transportation'] ?? 0).toStringAsFixed(0);
    _foodBudgetController.text = (project.categoryBudgets['food'] ?? 0)
        .toStringAsFixed(0);
    _accommBudgetController.text =
        (project.categoryBudgets['accommodation'] ?? 0).toStringAsFixed(0);
    _officeBudgetController.text = (project.categoryBudgets['officecost'] ?? 0)
        .toStringAsFixed(0);

    // Load any custom categories
    final standardKeys = {
      'equipment',
      'transportation',
      'food',
      'accommodation',
      'officecost',
      'officebenefit',
    };
    project.categoryBudgets.forEach((key, val) {
      if (!standardKeys.contains(key.toLowerCase()) &&
          !key.startsWith('_meta_')) {
        final ctrl = TextEditingController(text: val.toStringAsFixed(0));
        ctrl.addListener(() => setState(() {}));
        _customCategoryControllers[key] = ctrl;
      }
    });

    _startDate = project.startDate;
    _endDate = project.endDate;
    _selectedTeamMemberIds.addAll(project.teamMemberIds);
    for (final m in project.members) {
      _memberAssignments[m.userId] = m;
    }
  }

  @override
  void dispose() {
    _memberSearchController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _clientController.dispose();
    _grossValueController.dispose();
    _advanceReceivedController.dispose();
    _amountReceivedController.dispose();
    _equipBudgetController.dispose();
    _transportBudgetController.dispose();
    _foodBudgetController.dispose();
    _accommBudgetController.dispose();
    _officeBudgetController.dispose();
    for (final c in _customCategoryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  double get _calculatedNetRevenue {
    final gross = double.tryParse(_grossValueController.text.trim()) ?? 0.0;
    if (_taxStatus == TaxStatus.included) {
      final totalDeductionRate = (_taxRate + _incomeTaxRate).clamp(0.0, 1.0);
      return gross * (1 - totalDeductionRate);
    }
    return gross;
  }

  double get _calculatedDirectBudget {
    final eq = double.tryParse(_equipBudgetController.text.trim()) ?? 0.0;
    final tr = double.tryParse(_transportBudgetController.text.trim()) ?? 0.0;
    final fd = double.tryParse(_foodBudgetController.text.trim()) ?? 0.0;
    final ac = double.tryParse(_accommBudgetController.text.trim()) ?? 0.0;
    final of = double.tryParse(_officeBudgetController.text.trim()) ?? 0.0;
    double custom = 0.0;
    for (final c in _customCategoryControllers.values) {
      custom += double.tryParse(c.text.trim()) ?? 0.0;
    }
    return eq + tr + fd + ac + of + custom;
  }

  double get _calculatedOfficeBenefit {
    final gross = double.tryParse(_grossValueController.text.trim()) ?? 0.0;
    return gross * _officeBenefitRate;
  }

  double get _calculatedTotalBudget {
    return _calculatedDirectBudget + _calculatedOfficeBenefit;
  }

  double get _calculatedExpectedRevenue {
    return _calculatedNetRevenue - _calculatedTotalBudget;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeamMemberIds.isEmpty) {
      NotificationBanner.showError(
        context,
        'Please assign at least one team member',
      );
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final rawGross = double.tryParse(_grossValueController.text.trim()) ?? 0.0;
    final gross = rawGross < 0 ? 0.0 : rawGross;
    final rawAdvance =
        double.tryParse(_advanceReceivedController.text.trim()) ?? 0.0;
    final advance = rawAdvance < 0 ? 0.0 : rawAdvance;
    final rawReceived =
        double.tryParse(_amountReceivedController.text.trim()) ?? 0.0;
    final received = rawReceived < 0 ? 0.0 : rawReceived;

    double safeBudget(String text) {
      final v = double.tryParse(text.trim()) ?? 0.0;
      return v < 0 ? 0.0 : v;
    }

    final categoryBudgets = <String, double>{
      'equipment': safeBudget(_equipBudgetController.text),
      'transportation': safeBudget(_transportBudgetController.text),
      'food': safeBudget(_foodBudgetController.text),
      'accommodation': safeBudget(_accommBudgetController.text),
      'officecost': safeBudget(_officeBudgetController.text),
      'officebenefit':
          _calculatedOfficeBenefit < 0 ? 0.0 : _calculatedOfficeBenefit,
    };
    for (final entry in _customCategoryControllers.entries) {
      categoryBudgets[entry.key] = safeBudget(entry.value.text);
    }

    final totalBudget =
        _calculatedTotalBudget < 0 ? 0.0 : _calculatedTotalBudget;

    final assignedMemberList = _selectedTeamMemberIds.map((id) {
      return _memberAssignments[id] ??
          ProjectMember(
            userId: id,
            roleInProject: 'Site Engineer',
            permissions: const ProjectPermissions(
              canViewBudget: false,
              canRecordRevenue: false,
              canViewExpenses: true,
              canCreateExpenses: true,
              canApproveExpenses: false,
              canManageTasks: true,
              canUpdateProgress: true,
              canManageTeam: false,
              canEditProject: false,
              canViewAttendance: true,
            ),
          );
    }).toList();

    if (isEditing) {
      final existing = ref
          .read(projectProvider)
          .firstWhere((p) => p.id == widget.projectId);
      final updated = existing.copyWith(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        client: _clientController.text.trim(),
        clientType: _clientType,
        assignmentType: _assignmentType,
        status: _status,
        grossProjectValue: gross,
        taxStatus: _taxStatus,
        taxRate: _taxRate,
        incomeTaxRate: _incomeTaxRate,
        expectedNetRevenue: _calculatedNetRevenue,
        advanceReceived: advance,
        amountReceived: received,
        amountReceivable: (gross - received).clamp(0.0, double.infinity),
        budget: totalBudget,
        categoryBudgets: categoryBudgets,
        officeBenefitRate: _officeBenefitRate,
        startDate: _startDate,
        endDate: _endDate,
        teamMemberIds: _selectedTeamMemberIds.toList(),
        members: assignedMemberList,
        imageUrl: _imageUrl,
        siteLatitude: _siteLatitude,
        siteLongitude: _siteLongitude,
        siteRadiusMeters: _siteRadiusMeters,
        clearSiteLocation: _clearSiteLocation,
      );
      await ref.read(projectProvider.notifier).updateProject(updated);
      if (mounted) {
        NotificationBanner.showSuccess(context, 'Project updated successfully');
      }
    } else {
      final currentUser = ref.read(authProvider).currentUser;
      final members =
          {
            ..._selectedTeamMemberIds,
            if (currentUser != null && currentUser.id.isNotEmpty)
              currentUser.id,
          }.toList();

      final created = await ref
          .read(projectProvider.notifier)
          .addProject(
            name: _nameController.text.trim(),
            description: _descController.text.trim(),
            client: _clientController.text.trim(),
            clientType: _clientType,
            assignmentType: _assignmentType,
            grossProjectValue: gross,
            taxStatus: _taxStatus,
            taxRate: _taxRate,
            incomeTaxRate: _incomeTaxRate,
            advanceReceived: advance,
            amountReceived: received,
            budget: totalBudget,
            categoryBudgets: categoryBudgets,
            estimatedRemainingCost: totalBudget * 0.4,
            officeBenefitRate: _officeBenefitRate,
            startDate: _startDate,
            endDate: _endDate,
            teamMemberIds: members,
            members: assignedMemberList,
            createdById: currentUser?.id,
            imageUrl: _imageUrl,
            siteLatitude: _siteLatitude,
            siteLongitude: _siteLongitude,
            siteRadiusMeters: _siteRadiusMeters,
          );
      if (mounted) {
        final isUploadedToServer = !created.id.startsWith('proj_');
        if (isUploadedToServer) {
          NotificationBanner.showSuccess(
            context,
            'Project created and uploaded to backend server!',
          );
        } else {
          NotificationBanner.showWarning(
            context,
            'Saved locally (Server unreachable: Check internet / phone settings).',
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      context.pop();
    }
  }

  InputDecoration _inputDeco({
    required String label,
    String? hint,
    String? prefixText,
    Widget? suffixIcon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isEditing) {
      final existing =
          ref
              .watch(projectProvider)
              .where((p) => p.id == widget.projectId)
              .toList();
      if (existing.isNotEmpty) _initProject(existing.first);
    } else if (!_initialized) {
      _initialized = true;
      final current = ref.read(authProvider).currentUser;
      if (current != null) _selectedTeamMemberIds.add(current.id);
      final settings = ref.read(settingsProvider);
      _officeBenefitRate = settings.defaultOfficeBenefitRate;
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit Project' : 'New Project',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ==================== PROJECT COVER IMAGE UPLOAD ====================
                _buildProjectImageSection(isDark),
                const SizedBox(height: 16),

                // ==================== CARD 1: PROJECT OVERVIEW ====================
                _buildCardContainer(
                  isDark: isDark,
                  icon: Icons.business_center_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  iconBg:
                      isDark
                          ? const Color(0xFF312E81).withAlpha(40)
                          : const Color(0xFFEEF2FF),
                  title: 'Project Overview',
                  subtitle:
                      'Basic specifications, client info and requirements',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDeco(
                        label: 'Project Name *',
                        hint: 'Enter official project title',
                        isDark: isDark,
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter project name'
                                  : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _clientController,
                      decoration: _inputDeco(
                        label: 'Client Name *',
                        hint: 'Enter client or organization name',
                        isDark: isDark,
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Please enter client name'
                                  : null,
                    ),
                    const SizedBox(height: 12),

                    // Client Type & Project Status in responsive row
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _buildClientTypeDropdown(isDark),
                              const SizedBox(height: 12),
                              _buildStatusDropdown(isDark),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: _buildClientTypeDropdown(isDark)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatusDropdown(isDark)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Assignment Type (Full width to avoid text truncation/overflow)
                    DropdownButtonFormField<AssignmentType>(
                      initialValue: _assignmentType,
                      isExpanded: true,
                      decoration: _inputDeco(
                        label: 'Assignment Type',
                        isDark: isDark,
                      ),
                      items:
                          AssignmentType.values.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.displayName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _assignmentType = v!;
                          if (_assignmentType == AssignmentType.government)
                            _officeBenefitRate = 0.30;
                          if (_assignmentType == AssignmentType.private)
                            _officeBenefitRate = 0.25;
                          if (_assignmentType == AssignmentType.subConsultancy)
                            _officeBenefitRate = 0.20;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Timeline Range Tile (Full Width, Tappable)
                    InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _inputDeco(
                          label: 'Timeline Range',
                          suffixIcon: const Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: Color(0xFF4F46E5),
                          ),
                          isDark: isDark,
                        ),
                        child: Text(
                          '${DateFormatter.formatDayMonthYear(_startDate)} — ${DateFormatter.formatDayMonthYear(_endDate)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scope / Requirements
                    TextFormField(
                      controller: _descController,
                      decoration: _inputDeco(
                        label: 'Project Requirements & Scope of Work *',
                        hint:
                            'Client deliverables, technical requirements and methodology',
                        isDark: isDark,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _buildCardContainer(
                  isDark: isDark,
                  icon: Icons.location_on_outlined,
                  iconColor: const Color(0xFF4F46E5),
                  iconBg: const Color(0xFFEEF2FF),
                  title: 'Project site',
                  subtitle: 'Pin the site used for on-field attendance',
                  children: [
                    Text(
                      _siteLatitude == null || _siteLongitude == null
                          ? 'No site location selected'
                          : '${_siteLatitude!.toStringAsFixed(6)}, ${_siteLongitude!.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final defaultRadius = ref
                                    .read(attendanceSettingsProvider)
                                    .value
                                    ?.geofenceRadiusMeters ??
                                200.0;
                            final result = await LocationPinPicker.showWithRadius(
                              context,
                              initialLocation: LatLng(
                                _siteLatitude ?? 23.8103,
                                _siteLongitude ?? 90.4125,
                              ),
                              title: 'Pin project site',
                              radiusMeters: _siteRadiusMeters ?? defaultRadius,
                            );
                            if (result != null && mounted) {
                              setState(() {
                                _siteLatitude = result.location.latitude;
                                _siteLongitude = result.location.longitude;
                                if (result.radiusMeters != null) {
                                  _siteRadiusMeters = result.radiusMeters;
                                }
                                _clearSiteLocation = false;
                              });
                            }
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: Text(
                            _siteLatitude == null
                                ? 'Select on map'
                                : 'Change pin on map',
                          ),
                        ),
                        if (_siteLatitude != null)
                          TextButton(
                            onPressed:
                                () => setState(() {
                                  _siteLatitude = null;
                                  _siteLongitude = null;
                                  _clearSiteLocation = true;
                                }),
                            child: const Text('Remove pin'),
                          ),
                      ],
                    ),
                    if (_siteLatitude != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Custom Site Radius',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (_siteRadiusMeters ?? 200) >= 1000
                                        ? '${((_siteRadiusMeters ?? 200) / 1000).toStringAsFixed((_siteRadiusMeters ?? 200) % 1000 == 0 ? 0 : 1)} km (${(_siteRadiusMeters ?? 200).toInt()} m)'
                                        : '${(_siteRadiusMeters ?? 200).toInt()} m',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Allowed circular geofence boundary around this project site (adjustable up to 1,000 km).',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                            Slider(
                              value: (_siteRadiusMeters ?? 200.0).clamp(50.0, 1000000.0),
                              min: 50,
                              max: 1000000,
                              label: (_siteRadiusMeters ?? 200) >= 1000
                                  ? '${((_siteRadiusMeters ?? 200) / 1000).toStringAsFixed(1)} km'
                                  : '${(_siteRadiusMeters ?? 200).toInt()} m',
                              onChanged: (val) {
                                setState(() {
                                  _siteRadiusMeters = val;
                                });
                              },
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [100, 500, 1000, 5000, 25000, 100000, 500000, 1000000].map((preset) {
                                  final currentVal = _siteRadiusMeters ?? 200.0;
                                  final isSelected = (currentVal - preset).abs() < 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(
                                        preset >= 1000 ? '${preset ~/ 1000} km' : '$preset m',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected: (_) {
                                        setState(() {
                                          _siteRadiusMeters = preset.toDouble();
                                        });
                                      },
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // ==================== CARD 2: CONTRACT & FINANCIALS ====================
                _buildCardContainer(
                  isDark: isDark,
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBg:
                      isDark
                          ? const Color(0xFF064E3B).withAlpha(40)
                          : const Color(0xFFECFDF5),
                  title: 'Contract & Tax Setup',
                  subtitle:
                      'Contract value, IT-VAT treatment and revenue projection',
                  children: [
                    TextFormField(
                      controller: _grossValueController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco(
                        label: 'Gross Contract Value (৳) *',
                        prefixText: '৳ ',
                        hint: 'e.g. 2500000',
                        isDark: isDark,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Enter contract value';
                        final val = double.tryParse(v.trim());
                        if (val == null) return 'Enter valid amount';
                        if (val <= 0)
                          return 'Contract value must be greater than zero';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Tax Status & Tax Rates in responsive layout
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isNarrow = constraints.maxWidth < 460;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _buildTaxStatusDropdown(isDark),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildTaxRateInput(isDark)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildIncomeTaxRateInput(isDark),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildTaxStatusDropdown(isDark),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildTaxRateInput(isDark),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _buildIncomeTaxRateInput(isDark),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Keep contract value and expected revenue distinct.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF0FDF9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildFinancialPreviewRow(
                            'Project Value Excl. IT-VAT',
                            _calculatedNetRevenue,
                            isDark,
                            emphasized: true,
                          ),
                          const SizedBox(height: 6),
                          _buildFinancialPreviewRow(
                            'Direct Operational Budget',
                            _calculatedDirectBudget,
                            isDark,
                          ),
                          const SizedBox(height: 6),
                          _buildFinancialPreviewRow(
                            'Office Benefit (${(_officeBenefitRate * 100).toInt()}% of Gross Contract)',
                            _calculatedOfficeBenefit,
                            isDark,
                          ),
                          const Divider(height: 16),
                          _buildFinancialPreviewRow(
                            'Expected Revenue',
                            _calculatedExpectedRevenue,
                            isDark,
                            emphasized: true,
                            valueColor:
                                _calculatedExpectedRevenue < 0
                                    ? const Color(0xFFBE123C)
                                    : const Color(0xFF047857),
                          ),
                          const SizedBox(height: 6),
                          _buildFinancialPreviewRow(
                            'Total Project Budget',
                            _calculatedTotalBudget,
                            isDark,
                            emphasized: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Advance and Received
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        if (isNarrow) {
                          return Column(
                            children: [
                              TextFormField(
                                controller: _advanceReceivedController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco(
                                  label: 'Advance Received (৳)',
                                  prefixText: '৳ ',
                                  isDark: isDark,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return null;
                                  final val = double.tryParse(v.trim());
                                  if (val == null) return 'Enter valid amount';
                                  if (val < 0) return 'Cannot be negative';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _amountReceivedController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco(
                                  label: 'Amount Received to Date (৳)',
                                  prefixText: '৳ ',
                                  isDark: isDark,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return null;
                                  final val = double.tryParse(v.trim());
                                  if (val == null) return 'Enter valid amount';
                                  if (val < 0) return 'Cannot be negative';
                                  return null;
                                },
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _advanceReceivedController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco(
                                  label: 'Advance Received (৳)',
                                  prefixText: '৳ ',
                                  isDark: isDark,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return null;
                                  final val = double.tryParse(v.trim());
                                  if (val == null) return 'Enter valid amount';
                                  if (val < 0) return 'Cannot be negative';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _amountReceivedController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco(
                                  label: 'Amount Received (৳)',
                                  prefixText: '৳ ',
                                  isDark: isDark,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return null;
                                  final val = double.tryParse(v.trim());
                                  if (val == null) return 'Enter valid amount';
                                  if (val < 0) return 'Cannot be negative';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ==================== CARD 3: BUDGET ALLOCATION ====================
                _buildCardContainer(
                  isDark: isDark,
                  icon: Icons.pie_chart_outline_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg:
                      isDark
                          ? const Color(0xFF78350F).withAlpha(40)
                          : const Color(0xFFFFFBEB),
                  title: 'Budget Allocation',
                  subtitle: 'Category expenditure & automatic markup margin',
                  children: [
                    _buildCompactBudgetRow(
                      'Equipment',
                      Icons.construction_rounded,
                      _equipBudgetController,
                      isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildCompactBudgetRow(
                      'Transportation',
                      Icons.directions_car_rounded,
                      _transportBudgetController,
                      isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildCompactBudgetRow(
                      'Food & Meals',
                      Icons.restaurant_rounded,
                      _foodBudgetController,
                      isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildCompactBudgetRow(
                      'Accommodation',
                      Icons.hotel_rounded,
                      _accommBudgetController,
                      isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildCompactBudgetRow(
                      'Office and Administration',
                      Icons.work_outline_rounded,
                      _officeBudgetController,
                      isDark,
                    ),
                    const SizedBox(height: 8),

                    // Custom Categories List
                    if (_customCategoryControllers.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 13,
                            color: AppColors.getPrimary(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ADDITIONAL OFFICE AND ADMINISTRATION LINES',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.getPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._customCategoryControllers.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildCustomBudgetRow(
                            entry.key,
                            entry.value,
                            isDark,
                            onDelete: () {
                              setState(() {
                                final ctrl = _customCategoryControllers.remove(
                                  entry.key,
                                );
                                ctrl?.dispose();
                              });
                            },
                          ),
                        );
                      }),
                    ],

                    // + Add Category Button
                    InkWell(
                      onTap: _showAddCategoryDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFD97706,
                          ).withAlpha(isDark ? 25 : 12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD97706).withAlpha(60),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Add Category',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Markup Margin Calculation Summary Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Direct Budget Subtotal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDark
                                            ? AppColors.darkTextSecondary
                                            : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(
                                  _calculatedDirectBudget,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Office Benefit (${(_officeBenefitRate * 100).toInt()}% of Gross Contract)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDark
                                            ? AppColors.darkTextSecondary
                                            : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(
                                  _calculatedOfficeBenefit,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total Project Budget',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(
                                  _calculatedTotalBudget,
                                ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ==================== CARD 4: TEAM ASSIGNMENT ====================
                _buildCardContainer(
                  isDark: isDark,
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBg:
                      isDark
                          ? const Color(0xFF4C1D95).withAlpha(40)
                          : const Color(0xFFF5F3FF),
                  title: 'Team Access',
                  subtitle:
                      'Search & assign members permitted to view & submit costs',
                  children: [
                    Builder(
                      builder: (context) {
                        final allUsers = ref.watch(userManagementProvider);
                        final curUser = ref.watch(authProvider).currentUser;

                        // Ensure current user is in user lookup pool if available
                        final Map<String, UserModel> userMap = {};
                        for (final u in allUsers) {
                          userMap[u.id] = u;
                          if (u.email.isNotEmpty)
                            userMap[u.email.toLowerCase()] = u;
                        }
                        if (curUser != null) {
                          userMap[curUser.id] = curUser;
                          if (curUser.email.isNotEmpty)
                            userMap[curUser.email.toLowerCase()] = curUser;
                        }

                        final selectedUsers =
                            _selectedTeamMemberIds.map((id) {
                              return userMap[id] ??
                                  UserModel(
                                    id: id,
                                    name:
                                        id.contains('@')
                                            ? id.split('@').first
                                            : id,
                                    email: id.contains('@') ? id : '',
                                    role: UserRole.projectMember,
                                    department: 'Operations',
                                  );
                            }).toList();

                        // Filter candidates based on search
                        final query = _memberSearchQuery.trim().toLowerCase();
                        final candidatePool = userMap.values.toSet().toList();
                        final filteredCandidates =
                            query.isEmpty
                                ? candidatePool
                                : candidatePool.where((u) {
                                  return u.name.toLowerCase().contains(query) ||
                                      u.email.toLowerCase().contains(query) ||
                                      u.department.toLowerCase().contains(
                                        query,
                                      );
                                }).toList();

                        final isQueryEmail =
                            query.contains('@') && query.contains('.');
                        final hasExactEmailMatch = candidatePool.any(
                          (u) => u.email.toLowerCase() == query,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Search Bar
                            TextFormField(
                              controller: _memberSearchController,
                              style: const TextStyle(fontSize: 14),
                              onChanged: (val) {
                                setState(() {
                                  _memberSearchQuery = val;
                                });
                                if (val.trim().length >= 2) {
                                  ref
                                      .read(userManagementProvider.notifier)
                                      .searchUsers(val.trim());
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Search member by name or Gmail...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF94A3B8),
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                                suffixIcon:
                                    _memberSearchQuery.isNotEmpty
                                        ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _memberSearchController.clear();
                                            setState(
                                              () => _memberSearchQuery = '',
                                            );
                                          },
                                        )
                                        : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor:
                                    isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color:
                                        isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color:
                                        isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF4F46E5),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            // 2. Direct Add by Email Option if unlisted
                            if (_memberSearchQuery.isNotEmpty &&
                                !hasExactEmailMatch) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4F46E5,
                                  ).withAlpha(isDark ? 30 : 15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF4F46E5,
                                    ).withAlpha(80),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      color: Color(0xFF4F46E5),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isQueryEmail
                                                ? 'Assign member with Gmail:'
                                                : 'Search or invite by email:',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            _memberSearchQuery,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final added = await ref
                                            .read(
                                              userManagementProvider.notifier,
                                            )
                                            .findOrAddMemberByEmail(
                                              _memberSearchQuery,
                                            );
                                        if (added != null && mounted) {
                                          setState(() {
                                            _selectedTeamMemberIds.add(
                                              added.id,
                                            );
                                            _memberSearchController.clear();
                                            _memberSearchQuery = '';
                                          });
                                          NotificationBanner.showSuccess(
                                            this.context,
                                            'Added and assigned ${added.name.isNotEmpty ? added.name : added.email} to project',
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4F46E5,
                                        ),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Assign',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 3. Assigned Members Chips
                            if (selectedUsers.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Text(
                                    'Assigned Team (${selectedUsers.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isDark
                                              ? AppColors.darkTextSecondary
                                              : const Color(0xFF475569),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedTeamMemberIds.clear();
                                        if (curUser != null)
                                          _selectedTeamMemberIds.add(
                                            curUser.id,
                                          );
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    selectedUsers.map((u) {
                                      final isCurrentUser =
                                          curUser != null && curUser.id == u.id;
                                      return Chip(
                                        avatar: CircleAvatar(
                                          radius: 11,
                                          backgroundColor: const Color(
                                            0xFF4F46E5,
                                          ),
                                          child: Text(
                                            u.name.isNotEmpty
                                                ? u.name
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        label: Text(
                                          '${u.name.isNotEmpty ? u.name : u.email}${isCurrentUser ? ' (You)' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        deleteIcon:
                                            isCurrentUser
                                                ? null
                                                : const Icon(
                                                  Icons.close_rounded,
                                                  size: 16,
                                                ),
                                        onDeleted:
                                            isCurrentUser
                                                ? null
                                                : () {
                                                  setState(() {
                                                    _selectedTeamMemberIds
                                                        .remove(u.id);
                                                  });
                                                },
                                        backgroundColor:
                                            isDark
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFFEEF2FF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          side: BorderSide(
                                            color:
                                                isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFC7D2FE),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 4. Available Candidates Selector List
                            Text(
                              _memberSearchQuery.isEmpty
                                  ? 'Available Members'
                                  : 'Search Results (${filteredCandidates.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (filteredCandidates.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: Text(
                                    'No registered members match "$_memberSearchQuery".\nUse "Assign member by email" above to assign them.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isDark
                                              ? AppColors.darkTextSecondary
                                              : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount:
                                    filteredCandidates.length > 8
                                        ? 8
                                        : filteredCandidates.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final u = filteredCandidates[index];
                                  final isAssigned = _selectedTeamMemberIds
                                      .contains(u.id);
                                  final assignedMember = _memberAssignments[u.id];
                                  final roleTitle = assignedMember?.roleInProject.isNotEmpty == true
                                      ? assignedMember!.roleInProject
                                      : 'Site Engineer';
                                  final canApprove = assignedMember?.permissions.canApproveExpenses ?? false;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isAssigned
                                              ? (isDark
                                                  ? const Color(0xFF1E293B)
                                                  : const Color(0xFFEEF2FF))
                                              : (isDark
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color:
                                            isAssigned
                                                ? const Color(0xFF4F46E5)
                                                : (isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor:
                                                  isAssigned
                                                      ? const Color(0xFF4F46E5)
                                                      : const Color(0xFF94A3B8),
                                              child: Text(
                                                u.name.isNotEmpty
                                                    ? u.name
                                                        .substring(0, 1)
                                                        .toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          u.name.isNotEmpty
                                                              ? u.name
                                                              : u.email,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                isDark
                                                                    ? Colors.white
                                                                    : const Color(
                                                                      0xFF1E293B,
                                                                    ),
                                                          ),
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              (isDark
                                                                  ? Colors
                                                                      .grey
                                                                      .shade800
                                                                  : Colors
                                                                      .grey
                                                                      .shade200),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          u.role.displayName
                                                              .split(' ')
                                                              .first,
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (u.email.isNotEmpty)
                                                    Text(
                                                      u.email,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            isDark
                                                                ? AppColors
                                                                    .darkTextSecondary
                                                                : const Color(
                                                                  0xFF64748B,
                                                                ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(
                                                isAssigned
                                                    ? Icons.check_circle_rounded
                                                    : Icons
                                                        .add_circle_outline_rounded,
                                                color:
                                                    isAssigned
                                                        ? const Color(0xFF10B981)
                                                        : const Color(0xFF4F46E5),
                                                size: 24,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  if (isAssigned) {
                                                    _selectedTeamMemberIds.remove(
                                                      u.id,
                                                    );
                                                  } else {
                                                    _selectedTeamMemberIds.add(
                                                      u.id,
                                                    );
                                                    if (!_memberAssignments.containsKey(u.id)) {
                                                      _memberAssignments[u.id] = ProjectMember(
                                                        userId: u.id,
                                                        roleInProject: 'Site Engineer',
                                                        fullName: u.name,
                                                        email: u.email,
                                                        permissions: const ProjectPermissions(
                                                          canViewBudget: false,
                                                          canRecordRevenue: false,
                                                          canViewExpenses: true,
                                                          canCreateExpenses: true,
                                                          canApproveExpenses: false,
                                                          canManageTasks: true,
                                                          canUpdateProgress: true,
                                                          canManageTeam: false,
                                                          canEditProject: false,
                                                          canViewAttendance: true,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        if (isAssigned) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.only(top: 8),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                top: BorderSide(
                                                  color: isDark
                                                      ? const Color(0xFF334155)
                                                      : const Color(0xFFE0E7FF),
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: SingleChildScrollView(
                                                    scrollDirection: Axis.horizontal,
                                                    child: Row(
                                                      children: [
                                                        InkWell(
                                                  onTap: () => _showMemberRoleBottomSheet(context, u),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF4F46E5).withAlpha(20),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: const Color(0xFF4F46E5).withAlpha(50),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          roleTitle,
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: Color(0xFF4F46E5),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        const Icon(
                                                          Icons.tune_rounded,
                                                          size: 12,
                                                          color: Color(0xFF4F46E5),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (canApprove) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF10B981).withAlpha(20),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: const Color(0xFF10B981).withAlpha(60),
                                                      ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.verified_user_rounded,
                                                          size: 11,
                                                          color: Color(0xFF10B981),
                                                        ),
                                                        SizedBox(width: 3),
                                                        Text(
                                                          'Approver',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w700,
                                                            color: Color(0xFF10B981),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () => _showMemberRoleBottomSheet(context, u),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.shield_outlined,
                                                        size: 13,
                                                        color: Color(0xFF4F46E5),
                                                      ),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'Edit Access',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF4F46E5),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==================== REUSABLE ACTION BUTTON ====================
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      isEditing ? 'Save Changes' : 'Create Project',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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

  // ==================== SUB-WIDGET HELPERS ====================

  Widget _buildFinancialPreviewRow(
    String label,
    double value,
    bool isDark, {
    bool emphasized = false,
    Color? valueColor,
  }) {
    final mutedColor =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 12 : 11,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              color:
                  emphasized
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : mutedColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(
            fontSize: emphasized ? 12 : 11,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            color:
                valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            height: 1,
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildClientTypeDropdown(bool isDark) {
    return DropdownButtonFormField<ClientType>(
      initialValue: _clientType,
      isExpanded: true,
      decoration: _inputDeco(label: 'Client Type', isDark: isDark),
      items:
          ClientType.values.map((t) {
            return DropdownMenuItem(
              value: t,
              child: Text(
                t.displayName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
      onChanged: (v) => setState(() => _clientType = v!),
    );
  }

  Widget _buildStatusDropdown(bool isDark) {
    return DropdownButtonFormField<ProjectStatus>(
      initialValue: _status,
      isExpanded: true,
      decoration: _inputDeco(label: 'Status', isDark: isDark),
      items:
          ProjectStatus.values.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text(
                s.displayName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
      onChanged: (v) => setState(() => _status = v!),
    );
  }

  Widget _buildTaxStatusDropdown(bool isDark) {
    return DropdownButtonFormField<TaxStatus>(
      initialValue: _taxStatus,
      isExpanded: true,
      decoration: _inputDeco(label: 'IT-VAT Treatment', isDark: isDark),
      items:
          TaxStatus.values.map((t) {
            return DropdownMenuItem(
              value: t,
              child: Text(
                t.displayName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
      onChanged: (v) => setState(() => _taxStatus = v!),
    );
  }

  Widget _buildTaxRateInput(bool isDark) {
    return TextFormField(
      initialValue: '${(_taxRate * 100).toInt()}%',
      decoration: _inputDeco(label: 'VAT Rate (%)', isDark: isDark),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final val = double.tryParse(v.replaceAll('%', '').trim());
        if (val != null) setState(() => _taxRate = val / 100);
      },
    );
  }

  Widget _buildIncomeTaxRateInput(bool isDark) {
    return TextFormField(
      initialValue: '${(_incomeTaxRate * 100).toInt()}%',
      decoration: _inputDeco(label: 'IT Rate (%)', isDark: isDark),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final val = double.tryParse(v.replaceAll('%', '').trim());
        if (val != null) setState(() => _incomeTaxRate = val / 100);
      },
    );
  }

  Widget _buildCompactBudgetRow(
    String label,
    IconData icon,
    TextEditingController controller,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color:
                isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                prefixText: '৳ ',
                prefixStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomBudgetRow(
    String label,
    TextEditingController controller,
    bool isDark, {
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.category_rounded,
            size: 16,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                prefixText: '৳ ',
                prefixStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final suggestions = [
      'Consultancy',
      'Labor & Staff',
      'Permits & Licenses',
      'Subcontractor',
      'Site Logistics',
      'Utilities & Power',
      'Contingency',
    ];

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_circle_rounded,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Add Budget Category',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Suggestions:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            suggestions.map((sug) {
                              final isSelected =
                                  nameController.text.trim().toLowerCase() ==
                                  sug.toLowerCase();
                              return ChoiceChip(
                                label: Text(
                                  sug,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : (isDark
                                                ? const Color(0xFFCBD5E1)
                                                : const Color(0xFF334155)),
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFFD97706),
                                backgroundColor:
                                    isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                visualDensity: VisualDensity.compact,
                                showCheckmark: false,
                                onSelected: (val) {
                                  setDialogState(() {
                                    nameController.text = val ? sug : '';
                                  });
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        autofocus: false,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g. Survey Equipment, Consultant Fee',
                          filled: true,
                          fillColor:
                              isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Allocated Budget (৳)',
                          hintText: '0',
                          prefixText: '৳ ',
                          filled: true,
                          fillColor:
                              isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color:
                            isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;

                      final standardNames = {
                        'equipment',
                        'transportation',
                        'food',
                        'accommodation',
                        'officecost',
                        'officebenefit',
                      };
                      if (standardNames.contains(name.toLowerCase()) ||
                          _customCategoryControllers.keys.any(
                            (k) => k.toLowerCase() == name.toLowerCase(),
                          )) {
                        NotificationBanner.showError(
                          context,
                          'Category "$name" already exists',
                        );
                        return;
                      }

                      final amt = amountController.text.trim();
                      setState(() {
                        final ctrl = TextEditingController(
                          text: amt.isEmpty ? '0' : amt,
                        );
                        ctrl.addListener(() => setState(() {}));
                        _customCategoryControllers[name] = ctrl;
                      });
                      Navigator.pop(ctx);
                      NotificationBanner.showSuccess(
                        context,
                        'Added category "$name"',
                      );
                    },
                    child: const Text(
                      'Add Category',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildProjectImageSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow:
            isDark
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF312E81).withAlpha(40)
                          : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Project Cover Image',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add a project banner for visual identification',
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (_imageUrl != null && _imageUrl!.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Color(0xFFEF4444),
                  ),
                  tooltip: 'Remove project image',
                  onPressed: () {
                    setState(() => _imageUrl = null);
                    NotificationBanner.showInfo(
                      context,
                      'Project image removed',
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImagePreview(_imageUrl!),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withAlpha(160),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 14),
                        label: const Text(
                          'Change Image',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _showImageSourcePicker,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            InkWell(
              onTap: _showImageSourcePicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF0F172A).withAlpha(100)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        size: 24,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Upload Project Image',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Camera or Gallery • JPG, PNG supported',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 15),
                      label: const Text(
                        'Select Image',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _showImageSourcePicker,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreview(String path) {
    return AppImageHelper.buildImage(
      path: path,
      placeholder: () => _buildFallbackBanner(),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      color: const Color(0xFF312E81),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business_center_rounded,
              size: 36,
              color: Colors.white70,
            ),
            SizedBox(height: 6),
            Text(
              'Project Cover Image',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProjectImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final base64Uri = await AppImageHelper.fileToBase64DataUri(
          File(picked.path),
        );
        setState(() => _imageUrl = base64Uri);
        try {
          final uploadResult = await ref
              .read(fileUploadRepositoryProvider)
              .upload(
                filePathOrDataUri: picked.path,
                category: UploadCategory.projects,
                entityId: widget.projectId,
              );
          if (mounted) {
            setState(() => _imageUrl = uploadResult.url);
            NotificationBanner.showSuccess(
              context,
              'Project image uploaded successfully',
            );
          }
        } catch (_) {
          if (mounted) {
            NotificationBanner.showInfo(
              context,
              'Project image selected (offline ready)',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationBanner.showError(context, 'Could not access image: $e');
      }
    }
  }

  void _showImageSourcePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Upload Project Image',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a cover photo or banner for this project',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  title: const Text(
                    'Take Photo with Camera',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Capture project site or blueprint',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickProjectImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Select photo from local device',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickProjectImage(ImageSource.gallery);
                  },
                ),
                if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    title: const Text(
                      'Remove Cover Image',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    subtitle: const Text(
                      'Revert back to project initial banner',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _imageUrl = null);
                      NotificationBanner.showInfo(
                        context,
                        'Cover image removed',
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
    );
  }

  void _showMemberRoleBottomSheet(BuildContext context, UserModel u) {
    final existingMember = _memberAssignments[u.id];
    final roleController = TextEditingController(
      text: existingMember?.roleInProject.isNotEmpty == true
          ? existingMember!.roleInProject
          : 'Site Engineer',
    );
    final perms = existingMember?.permissions ??
        const ProjectPermissions(
          canViewBudget: false,
          canRecordRevenue: false,
          canViewExpenses: true,
          canCreateExpenses: true,
          canApproveExpenses: false,
          canManageTasks: true,
          canUpdateProgress: true,
          canManageTeam: false,
          canEditProject: false,
          canViewAttendance: true,
        );

    bool canViewBudget = perms.canViewBudget;
    bool canRecordRevenue = perms.canRecordRevenue;
    bool canViewExpenses = perms.canViewExpenses;
    bool canCreateExpenses = perms.canCreateExpenses;
    bool canApproveExpenses = perms.canApproveExpenses;
    bool canManageTasks = perms.canManageTasks;
    bool canUpdateProgress = perms.canUpdateProgress;
    bool canManageTeam = perms.canManageTeam;
    bool canEditProject = perms.canEditProject;
    bool canViewAttendance = perms.canViewAttendance;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            void applyPreset(String roleName, ProjectPermissions p) {
              setSheetState(() {
                roleController.text = roleName;
                canViewBudget = p.canViewBudget;
                canRecordRevenue = p.canRecordRevenue;
                canViewExpenses = p.canViewExpenses;
                canCreateExpenses = p.canCreateExpenses;
                canApproveExpenses = p.canApproveExpenses;
                canManageTasks = p.canManageTasks;
                canUpdateProgress = p.canUpdateProgress;
                canManageTeam = p.canManageTeam;
                canEditProject = p.canEditProject;
                canViewAttendance = p.canViewAttendance;
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Role & Access: ${u.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Set custom role title & 10 granular permissions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      children: [
                        const Text(
                          'Project Role Title',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: roleController,
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Site Lead, Field Auditor, Site Engineer',
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              size: 18,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor:
                                isDark
                                    ? AppColors.darkBackground
                                    : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Quick Role Presets',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildRolePresetChip(
                              'Site Lead',
                              () => applyPreset(
                                'Site Lead',
                                const ProjectPermissions(
                                  canViewBudget: true,
                                  canRecordRevenue: true,
                                  canViewExpenses: true,
                                  canCreateExpenses: true,
                                  canApproveExpenses: true,
                                  canManageTasks: true,
                                  canUpdateProgress: true,
                                  canManageTeam: true,
                                  canEditProject: true,
                                  canViewAttendance: true,
                                ),
                              ),
                              isSelected:
                                  roleController.text.trim().toLowerCase() ==
                                  'site lead',
                              isDark: isDark,
                            ),
                            _buildRolePresetChip(
                              'Field Auditor',
                              () => applyPreset(
                                'Field Auditor',
                                const ProjectPermissions(
                                  canViewBudget: true,
                                  canRecordRevenue: false,
                                  canViewExpenses: true,
                                  canCreateExpenses: false,
                                  canApproveExpenses: true,
                                  canManageTasks: false,
                                  canUpdateProgress: false,
                                  canManageTeam: false,
                                  canEditProject: false,
                                  canViewAttendance: true,
                                ),
                              ),
                              isSelected:
                                  roleController.text.trim().toLowerCase() ==
                                  'field auditor',
                              isDark: isDark,
                            ),
                            _buildRolePresetChip(
                              'Site Engineer',
                              () => applyPreset(
                                'Site Engineer',
                                const ProjectPermissions(
                                  canViewBudget: false,
                                  canRecordRevenue: false,
                                  canViewExpenses: true,
                                  canCreateExpenses: true,
                                  canApproveExpenses: false,
                                  canManageTasks: true,
                                  canUpdateProgress: true,
                                  canManageTeam: false,
                                  canEditProject: false,
                                  canViewAttendance: true,
                                ),
                              ),
                              isSelected:
                                  roleController.text.trim().toLowerCase() ==
                                  'site engineer',
                              isDark: isDark,
                            ),
                            _buildRolePresetChip(
                              'Field Crew',
                              () => applyPreset(
                                'Field Crew',
                                const ProjectPermissions(
                                  canViewBudget: false,
                                  canRecordRevenue: false,
                                  canViewExpenses: true,
                                  canCreateExpenses: true,
                                  canApproveExpenses: false,
                                  canManageTasks: false,
                                  canUpdateProgress: false,
                                  canManageTeam: false,
                                  canEditProject: false,
                                  canViewAttendance: true,
                                ),
                              ),
                              isSelected:
                                  roleController.text.trim().toLowerCase() ==
                                  'field crew',
                              isDark: isDark,
                            ),
                            _buildRolePresetChip(
                              'Observer',
                              () => applyPreset(
                                'Observer',
                                const ProjectPermissions(
                                  canViewBudget: true,
                                  canRecordRevenue: false,
                                  canViewExpenses: true,
                                  canCreateExpenses: false,
                                  canApproveExpenses: false,
                                  canManageTasks: false,
                                  canUpdateProgress: false,
                                  canManageTeam: false,
                                  canEditProject: false,
                                  canViewAttendance: true,
                                ),
                              ),
                              isSelected:
                                  roleController.text.trim().toLowerCase() ==
                                  'observer',
                              isDark: isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Row(
                          children: [
                            Text(
                              'Granular Permissions Matrix',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '(10 Controls)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Highlighted: Expense Approval
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color:
                                canApproveExpenses
                                    ? const Color(0xFF10B981).withAlpha(20)
                                    : (isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  canApproveExpenses
                                      ? const Color(0xFF10B981)
                                      : (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0)),
                              width: canApproveExpenses ? 1.5 : 1.0,
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            title: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user_rounded,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Approve Expense Claims',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'AUTHORITY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: const Text(
                              'Can review and approve/reject claims submitted for this project.',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: canApproveExpenses,
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged:
                                (val) => setSheetState(
                                  () => canApproveExpenses = val,
                                ),
                          ),
                        ),

                        _buildPermSwitchTile(
                          'View Budget & Revenue',
                          'Access project budget overview and revenue numbers',
                          canViewBudget,
                          (v) => setSheetState(() => canViewBudget = v),
                          isDark,
                        ),
                        _buildPermSwitchTile(
                          'Record Revenue',
                          'Add revenue entries and client milestone billing',
                          canRecordRevenue,
                          (v) => setSheetState(() => canRecordRevenue = v),
                          isDark,
                        ),
                        _buildPermSwitchTile(
                          'View Expenses',
                          'Browse project expenses submitted by all members',
                          canViewExpenses,
                          (v) => setSheetState(() => canViewExpenses = v),
                          isDark,
                        ),
                        _buildPermSwitchTile(
                          'Create Expenses',
                          'Submit expense claims against this project',
                          canCreateExpenses,
                          (v) => setSheetState(() => canCreateExpenses = v),
                          isDark,
                        ),
                        _buildPermSwitchTile(
                          'Manage Tasks',
                          'Create, assign, edit, and close project tasks',
                          canManageTasks,
                          (v) => setSheetState(() => canManageTasks = v),
                          isDark,
                        ),
                        _buildPermSwitchTile(
                          'Update Progress',
                          'Update percentage completion and post site notes',
                          canUpdateProgress,
                          (v) => setSheetState(() => canUpdateProgress = v),
                          isDark,
                        ),
                        _buildPermSwitchTile(
                          'Manage Team',
                          'Add/remove members and adjust project-level roles',
                          canManageTeam,
                          (v) => setSheetState(() => canManageTeam = v),
                          isDark,
                        ),
                        _buildPermSwitchTile(
                          'Edit Project Details',
                          'Edit project information, site coordinates, and timeline',
                          canEditProject,
                          (v) => setSheetState(() => canEditProject = v),
                          isDark,
                        ),
                        _buildPermSwitchTile(
                          'View Attendance',
                          'View member geofence check-ins and attendance logs',
                          canViewAttendance,
                          (v) => setSheetState(() => canViewAttendance = v),
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'Apply Project Access',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () {
                          final updatedPerms = ProjectPermissions(
                            canViewBudget: canViewBudget,
                            canRecordRevenue: canRecordRevenue,
                            canViewExpenses: canViewExpenses,
                            canCreateExpenses: canCreateExpenses,
                            canApproveExpenses: canApproveExpenses,
                            canManageTasks: canManageTasks,
                            canUpdateProgress: canUpdateProgress,
                            canManageTeam: canManageTeam,
                            canEditProject: canEditProject,
                            canViewAttendance: canViewAttendance,
                          );

                          setState(() {
                            _selectedTeamMemberIds.add(u.id);
                            _memberAssignments[u.id] = ProjectMember(
                              userId: u.id,
                              roleInProject:
                                  roleController.text.trim().isNotEmpty
                                      ? roleController.text.trim()
                                      : 'Site Engineer',
                              permissions: updatedPerms,
                              fullName: u.name,
                              email: u.email,
                            );
                          });

                          Navigator.pop(modalCtx);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRolePresetChip(
    String label,
    VoidCallback onTap, {
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF4F46E5).withAlpha(25)
                  : (isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color:
                isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildPermSwitchTile(
    String title,
    String desc,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        subtitle: Text(
          desc,
          style: TextStyle(
            fontSize: 10,
            color:
                isDark
                    ? AppColors.darkTextSecondary
                    : const Color(0xFF64748B),
          ),
        ),
        value: value,
        activeThumbColor: const Color(0xFF4F46E5),
        onChanged: onChanged,
      ),
    );
  }
}
