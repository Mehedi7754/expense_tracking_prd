import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
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
    final canUpdateStatus = user != null && const {
      UserRole.mainAdmin,
      UserRole.projectManager,
      UserRole.projectMember,
    }.contains(user.role);
    final filtered =
        tasks.where((task) {
            if (_filter != 'all' && task.status.name != _filter) return false;
            final query = _search.trim().toLowerCase();
            if (query.isEmpty) return true;
            return task.title.toLowerCase().contains(query) ||
                task.description.toLowerCase().contains(query) ||
                task.assigneeName.toLowerCase().contains(query) ||
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
        title: Text(
          user?.role == UserRole.projectMember ? 'My Tasks' : 'Tasks',
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          if (isManager)
            IconButton(
              onPressed: () => context.push(RoutePaths.addTask),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Assign task',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search tasks',
                isDense: true,
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
              ...filtered.map((task) => _taskCard(context, task, projects, canUpdateStatus)),
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

  Widget _filterChip(String value, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  Widget _taskCard(BuildContext context, TaskModel task, List projects, bool canUpdateStatus) {
    final matchingProjects = projects.where(
      (item) => item.id == task.projectId,
    );
    final project = matchingProjects.isEmpty ? null : matchingProjects.first;
    final statusColor =
        task.status == TaskStatus.completed
            ? Colors.green
            : task.status == TaskStatus.todo
            ? Colors.orange
            : Colors.blue;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap:
            () => context.push(
              RoutePaths.taskDetail.replaceFirst(':id', task.id),
            ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (canUpdateStatus) PopupMenuButton<TaskStatus>(
                    tooltip: 'Update status',
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.getTextMuted(context),
                    ),
                    onSelected: (status) async {
                      try {
                        await ref
                            .read(taskProvider.notifier)
                            .updateTaskStatus(task.id, status);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Task status could not be saved. Please retry.',
                              ),
                            ),
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
              Text(
                project?.name ?? 'Project',
                style: TextStyle(
                  color: AppColors.getTextMuted(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
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
                  const Spacer(),
                  Text(
                    'Due ${task.dueDate.month}/${task.dueDate.day}/${task.dueDate.year}',
                    style: TextStyle(
                      color: AppColors.getTextMuted(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (task.assigneeNames.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  task.assigneeNames.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.getTextMuted(context),
                    fontSize: 12,
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
