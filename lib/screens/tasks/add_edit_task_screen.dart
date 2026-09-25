import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/task_model.dart';
import '../../state/project_provider.dart';
import '../../state/task_provider.dart';
import '../../state/user_management_provider.dart';

class AddEditTaskScreen extends ConsumerStatefulWidget {
  final String? taskId;
  final String? projectId;

  const AddEditTaskScreen({
    super.key,
    this.taskId,
    this.projectId,
  });

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetLineController = TextEditingController();

  String? _selectedProjectId;
  String? _selectedAssigneeId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  bool _initialized = false;
  bool _isSaving = false;

  bool get isEditing => widget.taskId != null;

  void _initFields(TaskModel task) {
    if (_initialized) return;
    _initialized = true;

    _titleController.text = task.title;
    _descController.text = task.description;
    _budgetLineController.text = task.budgetLine ?? '';
    _selectedProjectId = task.projectId;
    _selectedAssigneeId = task.assigneeId;
    _dueDate = task.dueDate;
  }

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.projectId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetLineController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProjectId == null) {
      NotificationBanner.showError(context, 'Please select a project');
      return;
    }

    if (_selectedAssigneeId == null) {
      NotificationBanner.showError(context, 'Please select an assignee');
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final users = ref.read(userManagementProvider);
    final assignee = users.firstWhere((u) => u.id == _selectedAssigneeId);

    if (isEditing) {
      final existing = ref.read(taskProvider).firstWhere((t) => t.id == widget.taskId);
      final updated = existing.copyWith(
        projectId: _selectedProjectId!,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        assigneeId: assignee.id,
        assigneeName: assignee.name,
        dueDate: _dueDate,
        budgetLine: _budgetLineController.text.trim().isNotEmpty
            ? _budgetLineController.text.trim()
            : null,
      );
      ref.read(taskProvider.notifier).updateTask(updated);
      NotificationBanner.showSuccess(context, 'Task updated.');
    } else {
      ref.read(taskProvider.notifier).addTask(
            projectId: _selectedProjectId!,
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            assigneeId: assignee.id,
            assigneeName: assignee.name,
            dueDate: _dueDate,
            budgetLine: _budgetLineController.text.trim().isNotEmpty
                ? _budgetLineController.text.trim()
                : null,
          );
      NotificationBanner.showSuccess(context, 'Task added to project.');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allProjects = ref.watch(projectProvider);
    final allUsers = ref.watch(userManagementProvider);

    if (isEditing) {
      final allTasks = ref.watch(taskProvider);
      final match = allTasks.where((t) => t.id == widget.taskId);
      if (match.isNotEmpty) {
        _initFields(match.first);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'Add Project Task'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedProjectId,
                  decoration: const InputDecoration(labelText: 'Associated Project *'),
                  items: allProjects.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedProjectId = val),
                  validator: (val) => val == null ? 'Project required' : null,
                ),
                const SizedBox(height: 18),

                // Task Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Task Title *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Title required' : null,
                ),
                const SizedBox(height: 18),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Task Scope / Description *',
                    alignLabelWithHint: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Description required' : null,
                ),
                const SizedBox(height: 18),

                // Assignee Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedAssigneeId,
                  decoration: const InputDecoration(labelText: 'Assignee *'),
                  items: allUsers.map((u) {
                    return DropdownMenuItem<String>(
                      value: u.id,
                      child: Text('${u.name} (${u.department})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAssigneeId = val),
                  validator: (val) => val == null ? 'Assignee required' : null,
                ),
                const SizedBox(height: 18),

                // Due Date
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date *',
                      suffixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    child: Text(
                      DateFormatter.formatWithDay(_dueDate),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.getTextPrimary(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Optional Link to Specific Budget Line (PRD Section 4.4)
                TextFormField(
                  controller: _budgetLineController,
                  decoration: const InputDecoration(
                    labelText: 'Budget Line Item (Optional)',
                    hintText: 'e.g. Frontend Engineering, Travel, QA testing...',
                  ),
                ),
                const SizedBox(height: 32),

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
                        : Text(isEditing ? 'Save Task Changes' : 'Create Task'),
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
