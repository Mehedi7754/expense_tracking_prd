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

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  String _searchQuery = '';
  String _selectedType = 'all'; // all, directConsultancy, subConsultancy, government, private

  @override
  void initState() {
    super.initState();
    // TTL cache in ProjectNotifier prevents redundant calls on tab switches.
    // Auth flow already triggers initial fetch.
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = ref.watch(authProvider).currentUser;
    final role = user?.role;
    final canCreateProject = role?.canCreateProject ?? false;

    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);

    // Reactive permitted projects selector based on watched allProjects
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
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          role?.canViewAllProjects == true
              ? 'Projects (${permittedProjects.length})'
              : 'My Projects (${permittedProjects.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Single Unified Search Bar with Integrated Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: CustomSearchBar(
                  hintText: 'Search project, ID, client...',
                  initialValue: _searchQuery,
                  onChanged: (q) => setState(() => _searchQuery = q),
                  trailing: _buildFilterButton(isDark),
                ),
              ),

              const SizedBox(height: 4),

              // Project Cards List with Permanent Pie Chart at Top
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
                                actionLabel: canCreateProject ? 'Create Project' : null,
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
                                SliverToBoxAdapter(
                                  child: _buildProjectPieChartCard(
                                    context,
                                    filteredProjects,
                                    allExpenses,
                                    isDark,
                                  ),
                                ),
                              SliverPadding(
                                padding: EdgeInsets.only(
                                  bottom: 24,
                                  top: 4,
                                  left: isTablet ? 16 : 0,
                                  right: isTablet ? 16 : 0,
                                ),
                                sliver: isTablet
                                    ? SliverGrid(
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          mainAxisExtent: 122,
                                        ),
                                        delegate: SliverChildBuilderDelegate(
                                          (ctx, i) {
                                            final proj = filteredProjects[i];
                                            final pExp = allExpenses.where((e) => e.projectId == proj.id).toList();
                                            return ProjectCostCard(
                                              project: proj,
                                              projectExpenses: pExp,
                                              margin: EdgeInsets.zero,
                                              onTap: () => context.push(RoutePaths.projectDetail(proj.id)),
                                            );
                                          },
                                          childCount: filteredProjects.length,
                                        ),
                                      )
                                    : SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (ctx, i) {
                                            final proj = filteredProjects[i];
                                            final pExp = allExpenses.where((e) => e.projectId == proj.id).toList();
                                            return ProjectCostCard(
                                              project: proj,
                                              projectExpenses: pExp,
                                              onTap: () => context.push(RoutePaths.projectDetail(proj.id)),
                                            );
                                          },
                                          childCount: filteredProjects.length,
                                        ),
                                      ),
                              ),
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

  // ==================== PERMANENT PIE CHART CARD ====================
  Widget _buildProjectPieChartCard(
    BuildContext context,
    List<ProjectModel> projects,
    List<ExpenseModel> allExpenses,
    bool isDark,
  ) {
    if (projects.isEmpty) return const SizedBox.shrink();

    // Calculate incurred cost per project
    final Map<String, double> projectCosts = {};
    for (final p in projects) {
      final pExp = allExpenses.where((e) => e.projectId == p.id);
      final direct = pExp.fold<double>(0.0, (sum, e) => sum + e.amount);
      final total = direct * (1 + p.officeBenefitRate);
      if (total > 0) {
        projectCosts[p.name] = total;
      }
    }

    final totalSpent = projectCosts.values.fold<double>(0.0, (s, v) => s + v);

    // If no expenses incurred yet across filtered projects, fallback to gross project values
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Total Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.pie_chart_outline_rounded,
                        color: Color(0xFF4F46E5),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        useContractValue ? 'Portfolio Allocation' : 'Cost Breakdown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  useContractValue
                      ? '${CurrencyFormatter.format(displayTotal, compact: true)} Value'
                      : '${CurrencyFormatter.format(displayTotal, compact: true)} Incurred',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Donut Chart with Center Total
          SizedBox(
            height: 175,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 52,
                    sections: List.generate(entries.length, (i) {
                      final e = entries[i];
                      final color = palette[i % palette.length];
                      return PieChartSectionData(
                        color: color,
                        value: e.value,
                        title: '',
                        radius: 22,
                      );
                    }),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      useContractValue ? 'Total Value' : 'Total Spent',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(displayTotal, compact: true),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Legend Chips
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(entries.length, (i) {
              final e = entries[i];
              final color = palette[i % palette.length];
              final double pct = displayTotal > 0 ? (e.value / displayTotal * 100) : 0;
              final projectName = e.key;

              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$projectName (${pct.toStringAsFixed(0)}%)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
              isFiltered ? currentLabel : 'Filter',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isFiltered ? FontWeight.w700 : FontWeight.w600,
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
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
