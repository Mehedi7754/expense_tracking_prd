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
import '../../models/client_model.dart';
import '../../models/project_model.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/user_management_provider.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';

class AddEditProjectScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const AddEditProjectScreen({
    super.key,
    this.projectId,
  });

  @override
  ConsumerState<AddEditProjectScreen> createState() => _AddEditProjectScreenState();
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

  ClientType _clientType = ClientType.government;
  AssignmentType _assignmentType = AssignmentType.directConsultancy;
  ProjectStatus _status = ProjectStatus.ongoing;
  TaxStatus _taxStatus = TaxStatus.included;
  double _taxRate = 0.10; // 10%
  double _officeBenefitRate = 0.30; // 30% default

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 180));
  final Set<String> _selectedTeamMemberIds = {};
  final _memberSearchController = TextEditingController();
  String _memberSearchQuery = '';
  String? _imageUrl;
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
    _officeBenefitRate = project.officeBenefitRate;
    _imageUrl = project.imageUrl;

    _grossValueController.text = project.grossProjectValue.toStringAsFixed(0);
    _advanceReceivedController.text = project.advanceReceived.toStringAsFixed(0);
    _amountReceivedController.text = project.amountReceived.toStringAsFixed(0);

    _equipBudgetController.text = (project.categoryBudgets['equipment'] ?? 0).toStringAsFixed(0);
    _transportBudgetController.text = (project.categoryBudgets['transportation'] ?? 0).toStringAsFixed(0);
    _foodBudgetController.text = (project.categoryBudgets['food'] ?? 0).toStringAsFixed(0);
    _accommBudgetController.text = (project.categoryBudgets['accommodation'] ?? 0).toStringAsFixed(0);
    _officeBudgetController.text = (project.categoryBudgets['officecost'] ?? 0).toStringAsFixed(0);

    _startDate = project.startDate;
    _endDate = project.endDate;
    _selectedTeamMemberIds.addAll(project.teamMemberIds);
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
      return gross * (1 - _taxRate);
    }
    return gross;
  }

  double get _calculatedDirectBudget {
    final eq = double.tryParse(_equipBudgetController.text.trim()) ?? 0.0;
    final tr = double.tryParse(_transportBudgetController.text.trim()) ?? 0.0;
    final fd = double.tryParse(_foodBudgetController.text.trim()) ?? 0.0;
    final ac = double.tryParse(_accommBudgetController.text.trim()) ?? 0.0;
    final of = double.tryParse(_officeBudgetController.text.trim()) ?? 0.0;
    return eq + tr + fd + ac + of;
  }

  double get _calculatedOfficeBenefit {
    return _calculatedDirectBudget * _officeBenefitRate;
  }

  double get _calculatedTotalBudget {
    return _calculatedDirectBudget + _calculatedOfficeBenefit;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeamMemberIds.isEmpty) {
      NotificationBanner.showError(context, 'Please assign at least one team member');
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final gross = double.tryParse(_grossValueController.text.trim()) ?? 0.0;
    final advance = double.tryParse(_advanceReceivedController.text.trim()) ?? 0.0;
    final received = double.tryParse(_amountReceivedController.text.trim()) ?? 0.0;

    final categoryBudgets = {
      'equipment': double.tryParse(_equipBudgetController.text.trim()) ?? 0.0,
      'transportation': double.tryParse(_transportBudgetController.text.trim()) ?? 0.0,
      'food': double.tryParse(_foodBudgetController.text.trim()) ?? 0.0,
      'accommodation': double.tryParse(_accommBudgetController.text.trim()) ?? 0.0,
      'officecost': double.tryParse(_officeBudgetController.text.trim()) ?? 0.0,
      'officebenefit': _calculatedOfficeBenefit,
    };

    final totalBudget = _calculatedTotalBudget;

    if (isEditing) {
      final existing = ref.read(projectProvider).firstWhere((p) => p.id == widget.projectId);
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
        imageUrl: _imageUrl,
      );
      await ref.read(projectProvider.notifier).updateProject(updated);
      if (mounted) {
        NotificationBanner.showSuccess(context, 'Project updated successfully');
      }
    } else {
      final currentUser = ref.read(authProvider).currentUser;
      final members = {
        ..._selectedTeamMemberIds,
        if (currentUser != null && currentUser.id.isNotEmpty) currentUser.id,
      }.toList();

      final created = await ref.read(projectProvider.notifier).addProject(
            name: _nameController.text.trim(),
            description: _descController.text.trim(),
            client: _clientController.text.trim(),
            clientType: _clientType,
            assignmentType: _assignmentType,
            grossProjectValue: gross,
            taxStatus: _taxStatus,
            taxRate: _taxRate,
            advanceReceived: advance,
            amountReceived: received,
            budget: totalBudget,
            categoryBudgets: categoryBudgets,
            estimatedRemainingCost: totalBudget * 0.4,
            officeBenefitRate: _officeBenefitRate,
            startDate: _startDate,
            endDate: _endDate,
            teamMemberIds: members,
            createdById: currentUser?.id,
            imageUrl: _imageUrl,
          );
      if (mounted) {
        final isUploadedToServer = !created.id.startsWith('proj_');
        if (isUploadedToServer) {
          NotificationBanner.showSuccess(context, 'Project created and uploaded to backend server!');
        } else {
          NotificationBanner.showWarning(context, 'Saved locally (Server unreachable: Check internet / phone settings).');
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
        borderSide: const BorderSide(
          color: Color(0xFF4F46E5),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isEditing) {
      final existing = ref.watch(projectProvider).where((p) => p.id == widget.projectId).toList();
      if (existing.isNotEmpty) _initProject(existing.first);
    } else if (!_initialized) {
      _initialized = true;
      final current = ref.read(authProvider).currentUser;
      if (current != null) _selectedTeamMemberIds.add(current.id);
      final settings = ref.read(settingsProvider);
      _officeBenefitRate = settings.defaultOfficeBenefitRate;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit Project' : 'New Project',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
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
                  iconBg: isDark ? const Color(0xFF312E81).withAlpha(40) : const Color(0xFFEEF2FF),
                  title: 'Project Overview',
                  subtitle: 'Basic specifications, client info and requirements',
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDeco(
                        label: 'Project Name *',
                        hint: 'Enter official project title',
                        isDark: isDark,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter project name' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _clientController,
                      decoration: _inputDeco(
                        label: 'Client Name *',
                        hint: 'Enter client or organization name',
                        isDark: isDark,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter client name' : null,
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
                      value: _assignmentType,
                      isExpanded: true,
                      decoration: _inputDeco(label: 'Assignment Type', isDark: isDark),
                      items: AssignmentType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName, overflow: TextOverflow.ellipsis, maxLines: 1),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _assignmentType = v!;
                          if (_assignmentType == AssignmentType.government) _officeBenefitRate = 0.30;
                          if (_assignmentType == AssignmentType.private) _officeBenefitRate = 0.25;
                          if (_assignmentType == AssignmentType.subConsultancy) _officeBenefitRate = 0.20;
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
                          suffixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF4F46E5)),
                          isDark: isDark,
                        ),
                        child: Text(
                          '${DateFormatter.formatShort(_startDate)} — ${DateFormatter.formatShort(_endDate)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scope / Requirements
                    TextFormField(
                      controller: _descController,
                      decoration: _inputDeco(
                        label: 'Project Requirements & Scope of Work *',
                        hint: 'Client deliverables, technical requirements and methodology',
                        isDark: isDark,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ==================== CARD 2: CONTRACT & FINANCIALS ====================
                _buildCardContainer(
                  isDark: isDark,
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBg: isDark ? const Color(0xFF064E3B).withAlpha(40) : const Color(0xFFECFDF5),
                  title: 'Contract & Tax Setup',
                  subtitle: 'Contract value, IT-VAT treatment and revenue projection',
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
                      validator: (v) => (v == null || double.tryParse(v.trim()) == null) ? 'Enter valid amount' : null,
                    ),
                    const SizedBox(height: 12),

                    // Tax Status & Tax Rate in responsive layout
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _buildTaxStatusDropdown(isDark),
                              const SizedBox(height: 12),
                              _buildTaxRateInput(isDark),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 3, child: _buildTaxStatusDropdown(isDark)),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _buildTaxRateInput(isDark)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Expected Net Revenue Preview Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFC7D2FE),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Expected Net Revenue:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4338CA),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.format(_calculatedNetRevenue),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4F46E5),
                            ),
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
                  iconBg: isDark ? const Color(0xFF78350F).withAlpha(40) : const Color(0xFFFFFBEB),
                  title: 'Budget Allocation',
                  subtitle: 'Category expenditure & 30% automatic office benefit',
                  children: [
                    _buildCompactBudgetRow('Equipment', Icons.construction_rounded, _equipBudgetController, isDark),
                    const SizedBox(height: 8),
                    _buildCompactBudgetRow('Transportation', Icons.directions_car_rounded, _transportBudgetController, isDark),
                    const SizedBox(height: 8),
                    _buildCompactBudgetRow('Food & Meals', Icons.restaurant_rounded, _foodBudgetController, isDark),
                    const SizedBox(height: 8),
                    _buildCompactBudgetRow('Accommodation', Icons.hotel_rounded, _accommBudgetController, isDark),
                    const SizedBox(height: 8),
                    _buildCompactBudgetRow('Office Cost', Icons.work_outline_rounded, _officeBudgetController, isDark),
                    const SizedBox(height: 14),

                    // Office Benefit (30%) Calculation Summary Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(_calculatedDirectBudget),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Office Benefit (${(_officeBenefitRate * 100).toInt()}%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(_calculatedOfficeBenefit),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total Project Budget',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(_calculatedTotalBudget),
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
                  iconBg: isDark ? const Color(0xFF4C1D95).withAlpha(40) : const Color(0xFFF5F3FF),
                  title: 'Team Access',
                  subtitle: 'Search & assign members permitted to view & submit costs',
                  children: [
                    Builder(
                      builder: (context) {
                        final allUsers = ref.watch(userManagementProvider);
                        final curUser = ref.watch(authProvider).currentUser;

                        // Ensure current user is in user lookup pool if available
                        final Map<String, UserModel> userMap = {};
                        for (final u in allUsers) {
                          userMap[u.id] = u;
                          if (u.email.isNotEmpty) userMap[u.email.toLowerCase()] = u;
                        }
                        if (curUser != null) {
                          userMap[curUser.id] = curUser;
                          if (curUser.email.isNotEmpty) userMap[curUser.email.toLowerCase()] = curUser;
                        }

                        final selectedUsers = _selectedTeamMemberIds.map((id) {
                          return userMap[id] ?? UserModel(
                            id: id,
                            name: id.contains('@') ? id.split('@').first : id,
                            email: id.contains('@') ? id : '',
                            role: UserRole.projectMember,
                            department: 'Operations',
                          );
                        }).toList();

                        // Filter candidates based on search
                        final query = _memberSearchQuery.trim().toLowerCase();
                        final candidatePool = userMap.values.toSet().toList();
                        final filteredCandidates = query.isEmpty
                            ? candidatePool
                            : candidatePool.where((u) {
                                return u.name.toLowerCase().contains(query) ||
                                    u.email.toLowerCase().contains(query) ||
                                    u.department.toLowerCase().contains(query);
                              }).toList();

                        final isQueryEmail = query.contains('@') && query.contains('.');
                        final hasExactEmailMatch = candidatePool.any((u) => u.email.toLowerCase() == query);

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
                                  ref.read(userManagementProvider.notifier).searchUsers(val.trim());
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Search member by name or Gmail...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                                ),
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                suffixIcon: _memberSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _memberSearchController.clear();
                                          setState(() => _memberSearchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
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
                              ),
                            ),

                            // 2. Direct Add by Email Option if unlisted
                            if (_memberSearchQuery.isNotEmpty && !hasExactEmailMatch) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withAlpha(isDark ? 30 : 15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF4F46E5).withAlpha(80)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isQueryEmail ? 'Assign member with Gmail:' : 'Search or invite by email:',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                                          ),
                                          Text(
                                            _memberSearchQuery,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final added = await ref.read(userManagementProvider.notifier).findOrAddMemberByEmail(
                                              _memberSearchQuery,
                                            );
                                        if (added != null && mounted) {
                                          setState(() {
                                            _selectedTeamMemberIds.add(added.id);
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
                                        backgroundColor: const Color(0xFF4F46E5),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text('Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedTeamMemberIds.clear();
                                        if (curUser != null) _selectedTeamMemberIds.add(curUser.id);
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Reset', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedUsers.map((u) {
                                  final isCurrentUser = curUser != null && curUser.id == u.id;
                                  return Chip(
                                    avatar: CircleAvatar(
                                      radius: 11,
                                      backgroundColor: const Color(0xFF4F46E5),
                                      child: Text(
                                        u.name.isNotEmpty ? u.name.substring(0, 1).toUpperCase() : 'U',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ),
                                    label: Text(
                                      '${u.name.isNotEmpty ? u.name : u.email}${isCurrentUser ? ' (You)' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    deleteIcon: isCurrentUser ? null : const Icon(Icons.close_rounded, size: 16),
                                    onDeleted: isCurrentUser
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedTeamMemberIds.remove(u.id);
                                            });
                                          },
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFC7D2FE),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 4. Available Candidates Selector List
                            Text(
                              _memberSearchQuery.isEmpty ? 'Available Members' : 'Search Results (${filteredCandidates.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (filteredCandidates.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    'No registered members match "$_memberSearchQuery".\nUse "Assign member by email" above to assign them.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredCandidates.length > 8 ? 8 : filteredCandidates.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final u = filteredCandidates[index];
                                  final isAssigned = _selectedTeamMemberIds.contains(u.id);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isAssigned
                                          ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isAssigned
                                            ? const Color(0xFF4F46E5)
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: isAssigned ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                                          child: Text(
                                            u.name.isNotEmpty ? u.name.substring(0, 1).toUpperCase() : 'U',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      u.name.isNotEmpty ? u.name : u.email,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      u.role.displayName.split(' ').first,
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (u.email.isNotEmpty)
                                                Text(
                                                  u.email,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(
                                            isAssigned ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                            color: isAssigned ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                            size: 24,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (isAssigned) {
                                                _selectedTeamMemberIds.remove(u.id);
                                              } else {
                                                _selectedTeamMemberIds.add(u.id);
                                              }
                                            });
                                          },
                                        ),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      isEditing ? 'Save Changes' : 'Create Project',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
        boxShadow: isDark
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
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
          Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildClientTypeDropdown(bool isDark) {
    return DropdownButtonFormField<ClientType>(
      value: _clientType,
      isExpanded: true,
      decoration: _inputDeco(label: 'Client Type', isDark: isDark),
      items: ClientType.values.map((t) {
        return DropdownMenuItem(
          value: t,
          child: Text(t.displayName, overflow: TextOverflow.ellipsis, maxLines: 1),
        );
      }).toList(),
      onChanged: (v) => setState(() => _clientType = v!),
    );
  }

  Widget _buildStatusDropdown(bool isDark) {
    return DropdownButtonFormField<ProjectStatus>(
      value: _status,
      isExpanded: true,
      decoration: _inputDeco(label: 'Status', isDark: isDark),
      items: ProjectStatus.values.map((s) {
        return DropdownMenuItem(
          value: s,
          child: Text(s.displayName, overflow: TextOverflow.ellipsis, maxLines: 1),
        );
      }).toList(),
      onChanged: (v) => setState(() => _status = v!),
    );
  }

  Widget _buildTaxStatusDropdown(bool isDark) {
    return DropdownButtonFormField<TaxStatus>(
      value: _taxStatus,
      isExpanded: true,
      decoration: _inputDeco(label: 'IT-VAT Treatment', isDark: isDark),
      items: TaxStatus.values.map((t) {
        return DropdownMenuItem(
          value: t,
          child: Text(t.displayName, overflow: TextOverflow.ellipsis, maxLines: 1),
        );
      }).toList(),
      onChanged: (v) => setState(() => _taxStatus = v!),
    );
  }

  Widget _buildTaxRateInput(bool isDark) {
    return TextFormField(
      initialValue: '${(_taxRate * 100).toInt()}%',
      decoration: _inputDeco(label: 'Tax Rate (%)', isDark: isDark),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final val = double.tryParse(v.replaceAll('%', '').trim());
        if (val != null) setState(() => _taxRate = val / 100);
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
          Icon(icon, size: 16, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
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
                prefixStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
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
        boxShadow: isDark
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
                  color: isDark ? const Color(0xFF312E81).withAlpha(40) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Project Cover Image',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add a project banner for visual identification',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (_imageUrl != null && _imageUrl!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                  tooltip: 'Remove project image',
                  onPressed: () {
                    setState(() => _imageUrl = null);
                    NotificationBanner.showInfo(context, 'Project image removed');
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 14),
                        label: const Text('Change Image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withAlpha(100) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
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
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Camera or Gallery • JPG, PNG supported',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 15),
                      label: const Text('Select Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
            Icon(Icons.business_center_rounded, size: 36, color: Colors.white70),
            SizedBox(height: 6),
            Text(
              'Project Cover Image',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
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
        final base64Uri = await AppImageHelper.fileToBase64DataUri(File(picked.path));
        setState(() => _imageUrl = base64Uri);
        if (mounted) {
          NotificationBanner.showSuccess(context, 'Project image selected and prepared for upload');
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
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a cover photo or banner for this project',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
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
                child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF4F46E5)),
              ),
              title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Capture project site or blueprint', style: TextStyle(fontSize: 11)),
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
                child: const Icon(Icons.photo_library_outlined, color: Color(0xFF0284C7)),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Select photo from local device', style: TextStyle(fontSize: 11)),
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
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                ),
                title: const Text(
                  'Remove Cover Image',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFEF4444)),
                ),
                subtitle: const Text('Revert back to project initial banner', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _imageUrl = null);
                  NotificationBanner.showInfo(context, 'Cover image removed');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

