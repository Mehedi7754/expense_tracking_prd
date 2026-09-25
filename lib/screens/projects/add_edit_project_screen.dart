import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/client_model.dart';
import '../../models/project_model.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';

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
  bool _initialized = false;
  bool _isSaving = false;

  bool get isEditing => widget.projectId != null;

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

  double get _calculatedTotalBudget {
    final eq = double.tryParse(_equipBudgetController.text.trim()) ?? 0.0;
    final tr = double.tryParse(_transportBudgetController.text.trim()) ?? 0.0;
    final fd = double.tryParse(_foodBudgetController.text.trim()) ?? 0.0;
    final ac = double.tryParse(_accommBudgetController.text.trim()) ?? 0.0;
    final of = double.tryParse(_officeBudgetController.text.trim()) ?? 0.0;
    final direct = eq + tr + fd + ac + of;
    final ob = direct * _officeBenefitRate;
    return direct + ob;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeamMemberIds.isEmpty) {
      NotificationBanner.showError(context, 'Please assign at least one team member');
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 400));
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
      'officebenefit': (double.tryParse(_equipBudgetController.text.trim()) ?? 0.0) +
          (double.tryParse(_transportBudgetController.text.trim()) ?? 0.0) +
          (double.tryParse(_foodBudgetController.text.trim()) ?? 0.0) +
          (double.tryParse(_accommBudgetController.text.trim()) ?? 0.0) +
          (double.tryParse(_officeBudgetController.text.trim()) ?? 0.0) * _officeBenefitRate,
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
      );
      ref.read(projectProvider.notifier).updateProject(updated);
      NotificationBanner.showSuccess(context, 'Project updated successfully');
    } else {
      ref.read(projectProvider.notifier).addProject(
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
            estimatedRemainingCost: totalBudget * 0.4, // Initial forecast estimate
            officeBenefitRate: _officeBenefitRate,
            startDate: _startDate,
            endDate: _endDate,
            teamMemberIds: _selectedTeamMemberIds.toList(),
          );
      NotificationBanner.showSuccess(context, 'Project created with auto-generated ID');
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isEditing) {
      final existing = ref.watch(projectProvider).where((p) => p.id == widget.projectId).toList();
      if (existing.isNotEmpty) _initProject(existing.first);
    } else if (!_initialized) {
      _initialized = true;
      // Default assign current user
      final current = ref.read(authProvider).currentUser;
      if (current != null) _selectedTeamMemberIds.add(current.id);
      // Default office benefit from settings
      final settings = ref.read(settingsProvider);
      _officeBenefitRate = settings.defaultOfficeBenefitRate;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Project' : 'Create Project (PFIS)'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
          children: [
            // Section 1: Basic Information
            _buildSectionHeader(context, '1. Basic Information', Icons.info_outline_rounded),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name *',
                hintText: 'e.g. Enterprise Cloud ERP Platform',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter project name' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _clientController,
              decoration: const InputDecoration(
                labelText: 'Client Name *',
                hintText: 'e.g. Apex Technologies Inc.',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter client name' : null,
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ClientType>(
                    value: _clientType,
                    decoration: const InputDecoration(labelText: 'Client Type'),
                    items: ClientType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.displayName));
                    }).toList(),
                    onChanged: (v) => setState(() => _clientType = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AssignmentType>(
                    value: _assignmentType,
                    decoration: const InputDecoration(labelText: 'Assignment Type'),
                    items: AssignmentType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.displayName));
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _assignmentType = v!;
                        // Adjust default office benefit by assignment type
                        if (_assignmentType == AssignmentType.government) _officeBenefitRate = 0.30;
                        if (_assignmentType == AssignmentType.private) _officeBenefitRate = 0.25;
                        if (_assignmentType == AssignmentType.subConsultancy) _officeBenefitRate = 0.20;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ProjectStatus>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Project Status'),
                    items: ProjectStatus.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.displayName));
                    }).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDateRange,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Timeline Range',
                        suffixIcon: Icon(Icons.calendar_month_rounded, size: 18),
                      ),
                      child: Text(
                        '${DateFormatter.formatShort(_startDate)} - ${DateFormatter.formatShort(_endDate)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description / Scope of Work',
                hintText: 'Brief summary of project objectives, methodology, and deliverables',
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Section 2: Financial Information (PRD Section 4)
            _buildSectionHeader(context, '2. Financial Setup & Tax Rules', Icons.account_balance_wallet_outlined),
            const SizedBox(height: 12),

            TextFormField(
              controller: _grossValueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Gross Project / Contract Value (৳) *',
                prefixText: '৳ ',
                hintText: 'e.g. 2500000',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || double.tryParse(v.trim()) == null) ? 'Enter valid amount' : null,
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TaxStatus>(
                    value: _taxStatus,
                    decoration: const InputDecoration(labelText: 'IT-VAT / Tax Status'),
                    items: TaxStatus.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.displayName));
                    }).toList(),
                    onChanged: (v) => setState(() => _taxStatus = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: '${(_taxRate * 100).toInt()}%',
                    decoration: const InputDecoration(labelText: 'Tax Rate (%)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = double.tryParse(v.replaceAll('%', '').trim());
                      if (val != null) setState(() => _taxRate = val / 100);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Calculated Net Revenue Preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Expected Net Revenue:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    '৳ ${_calculatedNetRevenue.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _advanceReceivedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Advance Received (৳)',
                      prefixText: '৳ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _amountReceivedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount Received (৳)',
                      prefixText: '৳ ',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Section 3: Project Cost Categories & Estimated Budget (PRD Section 5 & 14)
            _buildSectionHeader(context, '3. Category Budgets & 30% Office Benefit', Icons.pie_chart_outline_rounded),
            const SizedBox(height: 8),
            Text(
              'Define budgeted expenditure per category. Office Benefit is calculated automatically.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: 12),

            _buildCategoryBudgetRow('Equipment Budget', _equipBudgetController),
            const SizedBox(height: 10),
            _buildCategoryBudgetRow('Transportation Budget', _transportBudgetController),
            const SizedBox(height: 10),
            _buildCategoryBudgetRow('Food Budget', _foodBudgetController),
            const SizedBox(height: 10),
            _buildCategoryBudgetRow('Accommodation Budget', _accommBudgetController),
            const SizedBox(height: 10),
            _buildCategoryBudgetRow('Office Cost Budget', _officeBudgetController),
            const SizedBox(height: 12),

            // Office Benefit Configuration & Preview (PRD Section 9)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Office Benefit (${(_officeBenefitRate * 100).toInt()}%):',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        'Auto-calculated',
                        style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Budget with Office Benefit:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(
                        '৳ ${_calculatedTotalBudget.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 4: Team Member Assignment (PRD Section 1)
            _buildSectionHeader(context, '4. Assign Team Members', Icons.group_outlined),
            const SizedBox(height: 8),
            Text(
              'Enforced Rule: Only assigned members can view and enter costs for this project.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DemoUsers.all.map((u) {
                final isSelected = _selectedTeamMemberIds.contains(u.id);
                return FilterChip(
                  label: Text('${u.name} (${u.role.displayName})'),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withAlpha(40),
                  checkmarkColor: AppColors.primary,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTeamMemberIds.add(u.id);
                      } else {
                        _selectedTeamMemberIds.remove(u.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  isEditing ? 'Save Changes' : 'Create Project',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildCategoryBudgetRow(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '$label (৳)',
        prefixText: '৳ ',
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
