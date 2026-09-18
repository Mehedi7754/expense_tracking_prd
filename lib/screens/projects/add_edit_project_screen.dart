import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/project_model.dart';
import '../../state/project_provider.dart';
import '../../state/user_management_provider.dart';

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
  final _budgetController = TextEditingController();
  final _revenueController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));
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
    _budgetController.text = project.budget.toStringAsFixed(0);
    _revenueController.text = project.expectedRevenue.toStringAsFixed(0);
    _startDate = project.startDate;
    _endDate = project.endDate;
    _selectedTeamMemberIds.addAll(project.teamMemberIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _clientController.dispose();
    _budgetController.dispose();
    _revenueController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeamMemberIds.isEmpty) {
      NotificationBanner.showError(context, 'Please assign at least one team member');
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;
    final expectedRev = double.tryParse(_revenueController.text.trim()) ?? 0.0;

    if (isEditing) {
      final existing = ref.read(projectProvider).firstWhere((p) => p.id == widget.projectId);
      final updated = existing.copyWith(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        client: _clientController.text.trim(),
        budget: budget,
        expectedRevenue: expectedRev,
        startDate: _startDate,
        endDate: _endDate,
        teamMemberIds: _selectedTeamMemberIds.toList(),
      );
      ref.read(projectProvider.notifier).updateProject(updated);
      NotificationBanner.showSuccess(context, 'Project updated successfully.');
    } else {
      ref.read(projectProvider.notifier).addProject(
            name: _nameController.text.trim(),
            description: _descController.text.trim(),
            client: _clientController.text.trim(),
            budget: budget,
            expectedRevenue: expectedRev,
            startDate: _startDate,
            endDate: _endDate,
            teamMemberIds: _selectedTeamMemberIds.toList(),
          );
      NotificationBanner.showSuccess(context, 'New project initialized.');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allUsers = ref.watch(userManagementProvider);

    if (isEditing) {
      final allProjects = ref.watch(projectProvider);
      final match = allProjects.where((p) => p.id == widget.projectId);
      if (match.isNotEmpty) {
        _initProject(match.first);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Project' : 'Create New Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Project Name *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Project name is required' : null,
                ),
                const SizedBox(height: 18),

                // Client Name
                TextFormField(
                  controller: _clientController,
                  decoration: const InputDecoration(labelText: 'Client Organization *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Client name is required' : null,
                ),
                const SizedBox(height: 18),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Project Scope / Description *',
                    alignLabelWithHint: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 18),

                // Budget & Expected Revenue
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Allocated Budget (\$)*',
                          prefixText: '\$ ',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Budget required';
                          if (double.tryParse(val.trim()) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _revenueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Expected Revenue (\$)*',
                          prefixText: '\$ ',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Revenue required';
                          if (double.tryParse(val.trim()) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Date Range Picker
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start & End Dates *',
                      suffixIcon: Icon(Icons.date_range_rounded),
                    ),
                    child: Text(
                      '${DateFormatter.formatShort(_startDate)} — ${DateFormatter.formatShort(_endDate)}',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.getTextPrimary(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Multi-select Team Member Assignment (PRD Section 4.4)
                Text('Assign Team Members *', style: AppTextStyles.labelMedium),
                const SizedBox(height: 4),
                Text(
                  'Select all team members eligible to submit expenses against this project.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allUsers.map((u) {
                    final isSelected = _selectedTeamMemberIds.contains(u.id);
                    return FilterChip(
                      label: Text('${u.name} (${u.department})'),
                      selected: isSelected,
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

                // Save Action
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
                        : Text(isEditing ? 'Save Changes' : 'Initialize Project'),
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
