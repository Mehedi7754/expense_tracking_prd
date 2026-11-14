import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/app_back_button.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';
import '../../state/task_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _filter = 'all';
  String _projectFilter = 'all';
  String _priorityFilter = 'all';
  String _dateFilter = 'all'; // 'all', 'today', 'this_week', 'overdue', 'custom'
  DateTime? _selectedCustomDate;
  String _search = '';
  bool _loading = false;
  String? _error;

  Future<void> _refresh() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(taskProvider.notifier)
          .fetchTasks(
            assigneeId: user.role == UserRole.projectMember ? user.id : null,
          );
    } catch (_) {
      _error = 'Could not load tasks. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProvider);
    final projects = ref.watch(projectProvider);
    final user = ref.watch(authProvider).currentUser;
    final isManager = user?.role.canCreateProject ?? false;
    final filtered =
        tasks.where((task) {
            if (_filter != 'all' && task.status.name != _filter) return false;
            if (_projectFilter != 'all' && task.projectId != _projectFilter)
              return false;
            if (_priorityFilter != 'all' &&
                task.priority.toLowerCase() != _priorityFilter)
              return false;
            if (_dateFilter != 'all') {
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
              final taskDate = task.dueDate;
              if (_dateFilter == 'today') {
                if (taskDate.isBefore(todayStart) || taskDate.isAfter(todayEnd)) {
                  return false;
                }
              } else if (_dateFilter == 'this_week') {
                final startOfWeek = todayStart.subtract(Duration(days: now.weekday % 7));
                final endOfWeek = startOfWeek.add(const Duration(days: 7, seconds: -1));
                if (taskDate.isBefore(startOfWeek) || taskDate.isAfter(endOfWeek)) {
                  return false;
                }
              } else if (_dateFilter == 'overdue') {
                if (task.status == TaskStatus.completed || !taskDate.isBefore(todayStart)) {
                  return false;
                }
              } else if (_dateFilter == 'custom' && _selectedCustomDate != null) {
                final customStart = DateTime(_selectedCustomDate!.year, _selectedCustomDate!.month, _selectedCustomDate!.day);
                final customEnd = DateTime(_selectedCustomDate!.year, _selectedCustomDate!.month, _selectedCustomDate!.day, 23, 59, 59);
                if (taskDate.isBefore(customStart) || taskDate.isAfter(customEnd)) {
                  return false;
                }
              }
            }
            final query = _search.trim().toLowerCase();
            if (query.isEmpty) return true;
            return task.title.toLowerCase().contains(query) ||
                task.description.toLowerCase().contains(query) ||
                task.assigneeName.toLowerCase().contains(query) ||
                task.assigneeNames.any(
                  (name) => name.toLowerCase().contains(query),
                ) ||
                projects.any(
                  (project) =>
                      project.id == task.projectId &&
                      project.name.toLowerCase().contains(query),
                );
          }).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          user?.role == UserRole.projectMember ? 'My Tasks' : 'Tasks',
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    context,
                    'To do',
                    tasks.where((t) => t.status == TaskStatus.todo).length,
                    AppColors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    context,
                    'In progress',
                    tasks
                        .where((t) => t.status == TaskStatus.inProgress)
                        .length,
                    AppColors.indigo,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard(
                    context,
                    'Done',
                    tasks.where((t) => t.status == TaskStatus.completed).length,
                    AppColors.emerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search tasks',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', 'All'),
                  _filterChip('todo', 'To do'),
                  _filterChip('inProgress', 'In progress'),
                  _filterChip('completed', 'Completed'),
                ],
              ),
            ),
            if (projects.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _projectFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.folder_open_rounded),
                  labelText: 'Project',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All projects'),
                  ),
                  ...projects.map(
                    (project) => DropdownMenuItem(
                      value: project.id,
                      child: Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged:
                    (value) => setState(() => _projectFilter = value ?? 'all'),
              ),
            ],
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _priorityChip('all', 'Any priority'),
                  _priorityChip('important', 'Important'),
                  _priorityChip('high', 'High'),
                  _priorityChip('medium', 'Medium'),
                  _priorityChip('low', 'Low'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _dateChip('all', 'Any date', Icons.calendar_today_rounded),
                  _dateChip('today', 'Due today', Icons.today_rounded),
                  _dateChip('this_week', 'This week', Icons.date_range_rounded),
                  _dateChip('overdue', 'Overdue', Icons.warning_amber_rounded),
                  _customDateChip(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_loading && tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 54),
                child: Column(
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      size: 36,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _search.isNotEmpty || _filter != 'all'
                          ? 'No matching tasks'
                          : 'No tasks assigned yet',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (isManager) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => context.push(RoutePaths.addTask),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Assign a task'),
                      ),
                    ],
                  ],
                ),
              )
            else
              ...filtered.map(
                (task) => _taskCard(
                  context,
                  task,
                  projects,
                  isManager ||
                      (user != null &&
                          user.role == UserRole.projectMember &&
                          task.isAssignedTo(user.id)),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton:
          isManager
              ? FloatingActionButton.extended(
                onPressed: () => context.push(RoutePaths.addTask),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Assign task'),
              )
              : null,
    );
  }

  Widget _summaryCard(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.getTextMuted(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.indigo,
        backgroundColor: AppColors.getSurface(context),
        side: BorderSide(
          color: selected ? AppColors.indigo : AppColors.getBorder(context),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.getTextSecondary(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _priorityChip(String value, String label) {
    final selected = _priorityFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.indigoLight,
        backgroundColor: AppColors.getSurface(context),
        side: BorderSide(
          color:
              selected ? AppColors.indigoBorder : AppColors.getBorder(context),
        ),
        labelStyle: TextStyle(
          color:
              selected ? AppColors.indigo : AppColors.getTextSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _priorityFilter = value),
      ),
    );
  }

  Widget _dateChip(String value, String label, IconData icon) {
    final selected = _dateFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 14,
          color: selected ? Colors.white : (value == 'overdue' ? AppColors.crimson : AppColors.getTextSecondary(context)),
        ),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: value == 'overdue' ? AppColors.crimson : AppColors.indigo,
        backgroundColor: AppColors.getSurface(context),
        side: BorderSide(
          color: selected
              ? (value == 'overdue' ? AppColors.crimson : AppColors.indigo)
              : AppColors.getBorder(context),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : (value == 'overdue' ? AppColors.crimson : AppColors.getTextSecondary(context)),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() {
          _dateFilter = value;
          if (value != 'custom') _selectedCustomDate = null;
        }),
      ),
    );
  }

  Widget _customDateChip() {
    final isCustom = _dateFilter == 'custom';
    final label = _selectedCustomDate != null
        ? DateFormatter.formatShort(_selectedCustomDate!)
        : 'Pick date';
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ActionChip(
        avatar: Icon(
          Icons.event_available_rounded,
          size: 14,
          color: isCustom ? Colors.white : AppColors.getTextSecondary(context),
        ),
        label: Text(label),
        backgroundColor: isCustom ? AppColors.indigo : AppColors.getSurface(context),
        side: BorderSide(
          color: isCustom ? AppColors.indigo : AppColors.getBorder(context),
        ),
        labelStyle: TextStyle(
          color: isCustom ? Colors.white : AppColors.getTextSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedCustomDate ?? now,
            firstDate: now.subtract(const Duration(days: 365)),
            lastDate: now.add(const Duration(days: 730)),
          );
          if (picked != null) {
            setState(() {
              _dateFilter = 'custom';
              _selectedCustomDate = picked;
            });
          }
        },
      ),
    );
  }

  Widget _taskCard(
    BuildContext context,
    TaskModel task,
    List projects,
    bool canUpdateStatus,
  ) {
    final matchingProjects = projects.where(
      (item) => item.id == task.projectId,
    );
    final project = matchingProjects.isEmpty ? null : matchingProjects.first;
    final statusColor =
        task.status == TaskStatus.completed
            ? AppColors.emerald
            : task.status == TaskStatus.todo
            ? AppColors.amber
            : AppColors.indigo;
    final priorityColor = switch (task.priority.toLowerCase()) {
      'high' || 'urgent' => AppColors.crimson,
      'low' => AppColors.emerald,
      _ => AppColors.amber,
    };
    final overdue =
        task.status != TaskStatus.completed &&
        task.dueDate.isBefore(DateTime.now());
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: AppColors.getBorder(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap:
            () => context.push(
              RoutePaths.taskDetail.replaceFirst(':id', task.id),
            ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 9, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 30,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (canUpdateStatus)
                    PopupMenuButton<TaskStatus>(
                      tooltip: 'Update status',
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.getTextMuted(context),
                      ),
                      onSelected: (status) async {
                        if (status == task.status) return;
                        try {
                          await ref
                              .read(taskProvider.notifier)
                              .updateTaskStatus(task.id, status);
                          if (context.mounted) {
                            NotificationBanner.showSuccess(
                              context,
                              'Task updated to ${status.displayName}.',
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            NotificationBanner.showError(
                              context,
                              'Task status could not be saved. Please retry.',
                            );
                          }
                        }
                      },
                      itemBuilder:
                          (_) =>
                              TaskStatus.values
                                  .map(
                                    (status) => PopupMenuItem(
                                      value: status,
                                      child: Text(status.displayName),
                                    ),
                                  )
                                  .toList(),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  task.description.trim().isEmpty
                      ? (project?.name ?? 'Project')
                      : task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.getTextMuted(context),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.priority.isEmpty
                          ? 'Medium'
                          : task.priority[0].toUpperCase() +
                              task.priority.substring(1),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    overdue
                        ? 'Overdue · ${DateFormatter.formatShort(task.dueDate)}'
                        : 'Due ${DateFormatter.formatShort(task.dueDate)}',
                    style: TextStyle(
                      color:
                          overdue
                              ? AppColors.crimson
                              : AppColors.getTextMuted(context),
                      fontSize: 10.5,
                      fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (task.assigneeNames.isNotEmpty) ...[
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      ...task.assigneeNames
                          .take(3)
                          .map(
                            (name) => Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: AppColors.indigoLight,
                                child: Text(
                                  name.trim().isEmpty
                                      ? '?'
                                      : name.trim()[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.indigo,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      Expanded(
                        child: Text(
                          task.assigneeNames.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.getTextMuted(context),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (project != null)
                        Text(
                          project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.getTextMuted(context),
                            fontSize: 10,
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
    );
  }
}
