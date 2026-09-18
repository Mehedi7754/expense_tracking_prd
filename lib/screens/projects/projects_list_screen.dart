import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/custom_search_bar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/project_card.dart';
import '../../models/expense_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  String _searchQuery = '';
  bool _isLoading = false;

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);
    final user = ref.watch(authProvider).currentUser;
    final role = user?.role ?? UserRole.employee;

    // Creation button visible only to Managers and Administrators (PRD Section 4.4)
    final canCreateProject = role == UserRole.manager || role == UserRole.admin;

    final filteredProjects = allProjects.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) || p.client.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('Projects Portfolio'),
        actions: [
          if (canCreateProject)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Create New Project',
              onPressed: () => context.push(RoutePaths.addProject),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: canCreateProject
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RoutePaths.addProject),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textWhite,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Project'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CustomSearchBar(
              hintText: 'Search projects by name or client...',
              initialValue: _searchQuery,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),
          Expanded(
            child: _isLoading
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      ProjectCardSkeleton(),
                      ProjectCardSkeleton(),
                    ],
                  )
                : filteredProjects.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.folder_open_rounded,
                        title: 'No Projects Found',
                        message: _searchQuery.isNotEmpty
                            ? 'No projects matched your search query.'
                            : 'No active projects available in portfolio.',
                        actionLabel: canCreateProject ? 'Create Project' : null,
                        onAction: canCreateProject ? () => context.push(RoutePaths.addProject) : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filteredProjects.length,
                          itemBuilder: (ctx, i) {
                            final proj = filteredProjects[i];

                            // Calculate spent: sum of approved expenses for this project
                            double spent = 0.0;
                            for (final e in allExpenses.where((exp) => exp.projectId == proj.id && exp.status == ExpenseStatus.approved)) {
                              spent += e.amount;
                            }

                            // Calculate revenue: sum of revenue entries
                            double revenue = 0.0;
                            for (final r in proj.revenueEntries) {
                              revenue += r.amount;
                            }

                            return ProjectCard(
                              project: proj,
                              spent: spent,
                              revenue: revenue,
                              onTap: () => context.push('/projects/${proj.id}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
