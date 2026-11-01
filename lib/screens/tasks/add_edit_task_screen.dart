import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';
import '../../state/task_provider.dart';
import '../../state/user_management_provider.dart';

class AddEditTaskScreen extends ConsumerStatefulWidget {
  final String? taskId;
  final String? projectId;

  const AddEditTaskScreen({super.key, this.taskId, this.projectId});

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetLineController = TextEditingController();
  final _assigneeSearchController = TextEditingController();

  String? _selectedProjectId;
  final Set<String> _selectedAssigneeIds = {};
  String _status = 'todo';
  String _priority = 'medium';
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
    _selectedAssigneeIds
      ..clear()
      ..addAll(
        task.assigneeIds.isNotEmpty ? task.assigneeIds : [task.assigneeId],
      );
    _status = task.status.dbValue;
    _priority = task.priority;
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
    _assigneeSearchController.dispose();
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

    if (_selectedAssigneeIds.isEmpty) {
      NotificationBanner.showError(context, 'Select at least one assignee');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final users = ref.read(userManagementProvider);
      final assignees =
          users.where((u) => _selectedAssigneeIds.contains(u.id)).toList();
      if (assignees.length != _selectedAssigneeIds.length) {
        throw StateError(
          'One or more selected assignees are no longer available.',
        );
      }
      final primary = assignees.first;
      if (isEditing) {
        final existing = ref
            .read(taskProvider)
            .firstWhere((t) => t.id == widget.taskId);
        final updated = existing.copyWith(
          projectId: _selectedProjectId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          assigneeId: primary.id,
          assigneeName: primary.name,
          assigneeIds: assignees.map((u) => u.id).toList(),
          assigneeNames: assignees.map((u) => u.name).toList(),
          dueDate: _dueDate,
          status: TaskStatus.fromString(_status),
          priority: _priority,
          budgetLine:
              _budgetLineController.text.trim().isNotEmpty
                  ? _budgetLineController.text.trim()
                  : null,
        );
        await ref.read(taskProvider.notifier).updateTask(updated);
        if (!mounted) return;
        NotificationBanner.showSuccess(context, 'Task updated.');
      } else {
        await ref
            .read(taskProvider.notifier)
            .addTask(
              projectId: _selectedProjectId!,
              title: _titleController.text.trim(),
              description: _descController.text.trim(),
              assigneeId: primary.id,
              assigneeName: primary.name,
              assigneeIds: assignees.map((u) => u.id).toList(),
              dueDate: _dueDate,
              status: TaskStatus.fromString(_status),
              priority: _priority,
              budgetLine:
                  _budgetLineController.text.trim().isNotEmpty
                      ? _budgetLineController.text.trim()
                      : null,
            );
        if (!mounted) return;
        NotificationBanner.showSuccess(context, 'Task assigned successfully.');
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      NotificationBanner.showError(context, 'Task could not be saved: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).currentUser?.role;
    if (role != UserRole.mainAdmin && role != UserRole.projectManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tasks')),
        body: const Center(child: Text('You do not have permission to manage tasks.')),
      );
    }
    final allProjects = ref.watch(projectProvider);
    final allUsers = ref.watch(userManagementProvider).where((user) => const {
      UserRole.mainAdmin,
      UserRole.projectManager,
      UserRole.projectMember,
    }.contains(user.role)).toList();
    final assigneeQuery = _assigneeSearchController.text.trim().toLowerCase();
    final filteredUsers =
        allUsers.where((u) {
          final value = '${u.name} ${u.email} ${u.department}'.toLowerCase();
          return assigneeQuery.isEmpty || value.contains(assigneeQuery);
        }).toList();

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
                    initialValue: _selectedProjectId,
                    decoration: const InputDecoration(
                      labelText: 'Associated Project *',
                    ),
                    items:
                        allProjects.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged:
                        (val) => setState(() => _selectedProjectId = val),
                    validator: (val) => val == null ? 'Project required' : null,
                  ),
                  const SizedBox(height: 18),

                  // Task Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task Title *',
                    ),
                    validator:
                        (val) =>
                            val == null || val.trim().isEmpty
                                ? 'Title required'
                                : null,
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
                    validator:
                        (val) =>
                            val == null || val.trim().isEmpty
                                ? 'Description required'
                                : null,
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: _assigneeSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search assignees',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedAssigneeIds.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          allUsers
                              .where((u) => _selectedAssigneeIds.contains(u.id))
                              .map(
                                (u) => InputChip(
                                  label: Text(u.name),
                                  onDeleted:
                                      () => setState(
                                        () => _selectedAssigneeIds.remove(u.id),
                                      ),
                                ),
                              )
                              .toList(),
                    ),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.getBorder(context)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        filteredUsers.isEmpty
                            ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('No matching team members'),
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final u = filteredUsers[index];
                                final selected = _selectedAssigneeIds.contains(
                                  u.id,
                                );
                                return CheckboxListTile(
                                  dense: true,
                                  value: selected,
                                  title: Text(
                                    u.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(u.department),
                                  onChanged:
                                      (value) => setState(() {
                                        if (value == true) {
                                          _selectedAssigneeIds.add(u.id);
                                        } else {
                                          _selectedAssigneeIds.remove(u.id);
                                        }
                                      }),
                                );
                              },
                            ),
                  ),
                  const SizedBox(height: 18),

                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'todo', child: Text('To do')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In progress'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged:
                        (value) => setState(() => _status = value ?? 'todo'),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(
                        value: 'important',
                        child: Text('Important'),
                      ),
                    ],
                    onChanged:
                        (value) =>
                            setState(() => _priority = value ?? 'medium'),
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
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Optional Link to Specific Budget Line (PRD Section 4.4)
                  TextFormField(
                    controller: _budgetLineController,
                    decoration: const InputDecoration(
                      labelText: 'Budget Line Item (Optional)',
                      hintText:
                          'e.g. Frontend Engineering, Travel, QA testing...',
                    ),
                  ),
                  const SizedBox(height: 32),

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
                              : Text(
                                isEditing ? 'Save Task Changes' : 'Create Task',
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
