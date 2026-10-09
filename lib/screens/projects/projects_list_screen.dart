import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/custom_search_bar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/project_cost_card.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  String _searchQuery = '';
  String _selectedType = 'all'; // all, directConsultancy, subConsultancy, government, private
  String _selectedStatusFilter = 'all'; // all, active, closed, suspended

  void _showDeleteConfirmationDialog(BuildContext context, ProjectModel project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Project', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${project.name}" (${project.projectId})?\n\nThis will permanently remove all budget allocations, team assignments, and revenue records.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(projectProvider.notifier).deleteProject(project.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Project "${project.name}" deleted successfully'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = ref.watch(authProvider).currentUser;
    final role = user?.role;
    final canCreateProject = role?.canCreateProject ?? false;
    final canDeleteProject = role?.canCreateProject ?? false;

    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);

    final permittedProjects = user == null
        ? <ProjectModel>[]
        : (role?.canViewAllProjects == true
            ? allProjects
            : allProjects.where((p) => p.hasMember(user.id)).toList());

    final filteredProjects = permittedProjects.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = p.name.toLowerCase().contains(q) ||
            p.client.toLowerCase().contains(q) ||
            p.projectId.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_selectedType != 'all') {
        if (p.assignmentType.name != _selectedType) return false;
      }
      if (_selectedStatusFilter == 'active') {
        if (p.isClosed || p.status == ProjectStatus.completed) return false;
      } else if (_selectedStatusFilter == 'closed') {
        if (!p.isClosed && p.status != ProjectStatus.completed) return false;
      } else if (_selectedStatusFilter == 'suspended') {
        if (p.status != ProjectStatus.suspended) return false;
      }
      return true;
    }).toList();

    final activeProjects = filteredProjects.where((p) => !p.isClosed && p.status != ProjectStatus.completed).toList();
    final closedProjects = filteredProjects.where((p) => p.isClosed || p.status == ProjectStatus.completed).toList();

    // Portfolio KPI aggregation
    double totalPortfolioValue = 0;
    double totalCostIncurred = 0;
    for (final p in permittedProjects) {
      totalPortfolioValue += p.grossProjectValue;
      final pExp = allExpenses.where((e) => e.projectId == p.id && e.status == ExpenseStatus.approved);
      final direct = pExp.fold<double>(0.0, (s, e) => s + e.amount);
      totalCostIncurred += (direct + (direct * p.officeBenefitRate));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          role?.canViewAllProjects == true
              ? 'Projects Portfolio (${permittedProjects.length})'
              : 'My Projects (${permittedProjects.length})',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF475569),
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () {
              ref.read(settingsProvider.notifier).toggleTheme(!isDark);
            },
          ),
          if (canCreateProject)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded, size: 22),
                tooltip: 'New Project',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5).withAlpha(isDark ? 50 : 25),
                  foregroundColor: const Color(0xFF4F46E5),
                ),
                onPressed: () => context.push(RoutePaths.addProject),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Search & Filter header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: CustomSearchBar(
                  hintText: 'Search project, ID, client...',
                  initialValue: _searchQuery,
                  onChanged: (q) => setState(() => _searchQuery = q),
                  trailing: _buildFilterButton(isDark),
                ),
              ),

              // Status Filter Pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildStatusChip('all', 'All (${permittedProjects.length})', isDark),
                      const SizedBox(width: 8),
                      _buildStatusChip('active', 'Active (${permittedProjects.where((p) => !p.isClosed && p.status != ProjectStatus.completed).length})', isDark),
                      const SizedBox(width: 8),
                      _buildStatusChip('closed', 'Completed (${permittedProjects.where((p) => p.isClosed || p.status == ProjectStatus.completed).length})', isDark),
                      const SizedBox(width: 8),
                      _buildStatusChip('suspended', 'Suspended (${permittedProjects.where((p) => p.status == ProjectStatus.suspended).length})', isDark),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Projects Stream View
              Expanded(
                child: filteredProjects.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => ref.read(projectProvider.notifier).fetchProjects(force: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 400,
                              child: EmptyStateWidget(
                                icon: Icons.folder_open_rounded,
                                title: 'No Projects Found',
                                message: _searchQuery.isNotEmpty
                                    ? 'No projects matching your search criteria.'
                                    : 'No projects available in this category.',
                                actionLabel: canCreateProject ? 'Create New Project' : null,
                                onAction: canCreateProject ? () => context.push(RoutePaths.addProject) : null,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Builder(
                        builder: (ctx) {
                          final isTablet = MediaQuery.sizeOf(ctx).width >= 768;
                          return RefreshIndicator(
                            onRefresh: () => ref.read(projectProvider.notifier).fetchProjects(force: true),
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // Executive Hero Header Banner (KPI cards & charts)
                                if (role?.canViewAllProjects == true || role?.name == 'projectManager')
                                  SliverToBoxAdapter(
                                    child: _buildExecutivePortfolioHeader(
                                      context,
                                      filteredProjects,
                                      allExpenses,
                                      totalPortfolioValue,
                                      totalCostIncurred,
                                      isDark,
                                    ),
                                  ),

                                // Section: Active Projects
                                if (_selectedStatusFilter == 'all' && closedProjects.isNotEmpty && activeProjects.isNotEmpty) ...[
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF4F46E5).withAlpha(20),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF4F46E5), size: 14),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Active Projects (${activeProjects.length})',
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, letterSpacing: -0.2),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'In Progress',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _buildProjectSliverList(activeProjects, allExpenses, isTablet, canDeleteProject, role?.canViewAllProjects == true || role?.name == 'projectManager'),

                                  // Section: Closed Projects
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withAlpha(20),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Completed & Archived (${closedProjects.length})',
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, letterSpacing: -0.2),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'Archived',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _buildProjectSliverList(closedProjects, allExpenses, isTablet, canDeleteProject, role?.canViewAllProjects == true || role?.name == 'projectManager'),
                                ] else ...[
                                  _buildProjectSliverList(filteredProjects, allExpenses, isTablet, canDeleteProject, role?.canViewAllProjects == true || role?.name == 'projectManager'),
                                ],

                                // Bottom safe margin above bottom dock
                                const SliverPadding(padding: EdgeInsets.only(bottom: 160)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String key, String label, bool isDark) {
    final isSelected = _selectedStatusFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A)).withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectSliverList(
    List<ProjectModel> projectsList,
    List<ExpenseModel> allExpenses,
    bool isTablet,
    bool canDelete,
    bool showFinancials,
  ) {
    final Map<String, List<ExpenseModel>> expensesByProject = {};
    for (final expense in allExpenses) {
      expensesByProject.putIfAbsent(expense.projectId, () => []).add(expense);
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 0, vertical: 4),
      sliver: isTablet
          ? SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 130,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final proj = projectsList[i];
                  final pExp = expensesByProject[proj.id] ?? [];
                  return ProjectCostCard(
                    project: proj,
                    projectExpenses: pExp,
                    margin: EdgeInsets.zero,
                    showFinancials: showFinancials,
                    onTap: () => context.push(RoutePaths.projectDetail(proj.id)),
                    onDelete: canDelete ? () => _showDeleteConfirmationDialog(context, proj) : null,
                  );
                },
                childCount: projectsList.length,
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final proj = projectsList[i];
                  final pExp = expensesByProject[proj.id] ?? [];
                  return ProjectCostCard(
                    project: proj,
                    projectExpenses: pExp,
                    showFinancials: showFinancials,
                    onTap: () => context.push(RoutePaths.projectDetail(proj.id)),
                    onDelete: canDelete ? () => _showDeleteConfirmationDialog(context, proj) : null,
                  );
                },
                childCount: projectsList.length,
              ),
            ),
    );
  }

  // ==================== EXECUTIVE PORTFOLIO HERO BANNER ====================
  Widget _buildExecutivePortfolioHeader(
    BuildContext context,
    List<ProjectModel> projects,
    List<ExpenseModel> allExpenses,
    double totalPortfolioValue,
    double totalCostIncurred,
    bool isDark,
  ) {
    if (projects.isEmpty) return const SizedBox.shrink();

    // Map top projects by expenditure
    final Map<String, double> projectCosts = {};
    for (final p in projects) {
      final pExp = allExpenses.where((e) => e.projectId == p.id && e.status == ExpenseStatus.approved);
      final direct = pExp.fold<double>(0.0, (sum, e) => sum + e.amount);
      final total = direct * (1 + p.officeBenefitRate);
      if (total > 0) {
        projectCosts[p.name] = total;
      }
    }

    final double totalSpent = projectCosts.values.fold<double>(0.0, (s, v) => s + v);
    final bool useContractValue = totalSpent <= 0;
    final Map<String, double> displayMap = useContractValue
        ? {for (final p in projects) p.name: p.grossProjectValue}
        : projectCosts;
    final double displayTotal = useContractValue
        ? projects.fold<double>(0.0, (s, p) => s + p.grossProjectValue)
        : totalSpent;

    const palette = [
      Color(0xFF4F46E5), // Indigo
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFF0284C7), // Sky Blue
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
    ];

    final entries = displayMap.entries.toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(isDark ? 10 : 8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bento Stat Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(
                bottom: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL PORTFOLIO VALUE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        CurrencyFormatter.format(totalPortfolioValue, compact: true),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 32, width: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL COST INCURRED',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        CurrencyFormatter.format(totalCostIncurred, compact: true),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Donut Chart & Project Allocation
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Donut Chart
                SizedBox(
                  height: 100,
                  width: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 32,
                          sections: List.generate(entries.length, (i) {
                            final e = entries[i];
                            final color = palette[i % palette.length];
                            return PieChartSectionData(
                              color: color,
                              value: e.value,
                              title: '',
                              radius: 12,
                            );
                          }),
                        ),
                      ),
                      Text(
                        '${projects.length}\nProjects',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Allocation Breakdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        useContractValue ? 'Portfolio Allocation by Value' : 'Expenditure by Project',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ...entries.take(3).map((e) {
                        final idx = entries.indexOf(e);
                        final color = palette[idx % palette.length];
                        final pct = displayTotal > 0 ? (e.value / displayTotal * 100) : 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            children: [
                              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(bool isDark) {
    final isFiltered = _selectedType != 'all';
    final currentLabel = _filterTypeLabel(_selectedType);

    return PopupMenuButton<String>(
      initialValue: _selectedType,
      tooltip: 'Filter by Assignment Type',
      onSelected: (val) => setState(() => _selectedType = val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isFiltered
              ? const Color(0xFF4F46E5).withAlpha(isDark ? 50 : 25)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: isFiltered
              ? Border.all(color: const Color(0xFF4F46E5).withAlpha(80), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: isFiltered ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 4),
            Text(
              isFiltered ? currentLabel : 'Type',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isFiltered ? FontWeight.w800 : FontWeight.w600,
                color: isFiltered ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isFiltered ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        _buildPopupItem('all', 'All Projects', _selectedType == 'all', isDark),
        _buildPopupItem('directConsultancy', 'Direct Consultancy', _selectedType == 'directConsultancy', isDark),
        _buildPopupItem('subConsultancy', 'Sub-consultancy', _selectedType == 'subConsultancy', isDark),
        _buildPopupItem('government', 'Government', _selectedType == 'government', isDark),
        _buildPopupItem('private', 'Private', _selectedType == 'private', isDark),
      ],
    );
  }

  String _filterTypeLabel(String type) {
    switch (type) {
      case 'directConsultancy':
        return 'Direct';
      case 'subConsultancy':
        return 'Sub-consult';
      case 'government':
        return 'Govt';
      case 'private':
        return 'Private';
      default:
        return 'All';
    }
  }

  PopupMenuItem<String> _buildPopupItem(String value, String title, bool isSelected, bool isDark) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}
