import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/custom_filter_panel.dart';
import '../../core/widgets/custom_search_bar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/expense_list_row.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../models/expense_model.dart';
import '../../state/auth_provider.dart';
import '../../state/category_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';

class MyExpensesScreen extends ConsumerStatefulWidget {
  const MyExpensesScreen({super.key});

  @override
  ConsumerState<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends ConsumerState<MyExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  FilterCriteria _filterCriteria = const FilterCriteria();
  bool _isLoading = false;

  final List<String> _tabLabels = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isLoading = false);
  }

  void _openFilterPanel(List<dynamic> allProjects, List<dynamic> allCategories) {
    final projectsList = allProjects
        .map((p) => {'id': p.id as String, 'name': p.name as String})
        .toList();

    final categoriesList = allCategories
        .map((c) => {'id': c.id as String, 'name': c.name as String})
        .toList();

    CustomFilterPanel.show(
      context,
      initialCriteria: _filterCriteria,
      projects: projectsList,
      categories: categoriesList,
      showStatusFilter: false, // Status is handled by tab bar
      onApply: (newCriteria) {
        setState(() => _filterCriteria = newCriteria);
      },
    );
  }

  List<ExpenseModel> _filterExpenses(
    List<ExpenseModel> expenses,
    String currentUserId,
    int tabIndex,
  ) {
    return expenses.where((e) {
      // Must be submitted by current employee
      if (e.employeeId != currentUserId) return false;

      // Filter by Tab Status
      if (tabIndex == 1 && e.status != ExpenseStatus.pending) return false;
      if (tabIndex == 2 && e.status != ExpenseStatus.approved) return false;
      if (tabIndex == 3 && e.status != ExpenseStatus.rejected) return false;

      // Filter by Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesProject = e.projectName.toLowerCase().contains(query);
        final matchesCategory = e.categoryName.toLowerCase().contains(query);
        final matchesNote = e.note.toLowerCase().contains(query);
        final matchesAmount = e.amount.toString().contains(query);
        if (!matchesProject && !matchesCategory && !matchesNote && !matchesAmount) {
          return false;
        }
      }

      // Filter by Project Filter
      if (_filterCriteria.projectId != null && e.projectId != _filterCriteria.projectId) {
        return false;
      }

      // Filter by Category Filter
      if (_filterCriteria.categoryId != null && e.categoryId != _filterCriteria.categoryId) {
        return false;
      }

      // Filter by Date Range
      if (_filterCriteria.dateRange != null) {
        if (e.date.isBefore(_filterCriteria.dateRange!.start) ||
            e.date.isAfter(_filterCriteria.dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    final allExpenses = ref.watch(expenseProvider);
    final allProjects = ref.watch(projectProvider);
    final allCategories = ref.watch(categoryProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myExpenses = allExpenses.where((e) => e.employeeId == user.id).toList();
    final pendingCount = myExpenses.where((e) => e.status == ExpenseStatus.pending).length;
    final approvedCount = myExpenses.where((e) => e.status == ExpenseStatus.approved).length;
    final rejectedCount = myExpenses.where((e) => e.status == ExpenseStatus.rejected).length;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: const Text('My Expenses'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filterCriteria.isActive,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter Expenses',
            onPressed: () => _openFilterPanel(allProjects, allCategories),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.getBorder(context), width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'All (${myExpenses.length})'),
                Tab(text: 'Pending ($pendingCount)'),
                Tab(text: 'Approved ($approvedCount)'),
                Tab(text: 'Rejected ($rejectedCount)'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'my_expenses_fab',
        onPressed: () => context.push(RoutePaths.submitExpense),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 2,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Search & Filter Status Bar
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomSearchBar(
                        hintText: 'Search my expenses...',
                        initialValue: _searchQuery,
                        onChanged: (q) => setState(() => _searchQuery = q),
                      ),
                    ),
                    if (_filterCriteria.isActive) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.close_rounded, size: 14),
                        label: const Text('Clear'),
                        onPressed: () => setState(() => _filterCriteria = const FilterCriteria()),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(4, (index) {
                final filtered = _filterExpenses(allExpenses, user.id, index);

                if (_isLoading) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      ExpenseRowSkeleton(),
                      ExpenseRowSkeleton(),
                      ExpenseRowSkeleton(),
                    ],
                  );
                }

                if (filtered.isEmpty) {
                  final tabName = _tabLabels[index];
                  return EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'No $tabName Expenses Found',
                    message: _searchQuery.isNotEmpty || _filterCriteria.isActive
                        ? 'No expenses matched your search or filter filters.'
                        : index == 0
                            ? 'You have not submitted any expenses yet.'
                            : 'No expenses with $tabName status.',
                    actionLabel: index == 0 ? 'Submit Expense' : null,
                    onAction: index == 0 ? () => context.push(RoutePaths.submitExpense) : null,
                  );
                }

                final isTablet = MediaQuery.sizeOf(context).width >= 768;

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppColors.primary,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: isTablet
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 4,
                                mainAxisExtent: 84,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final exp = filtered[i];
                                return ExpenseListRow(
                                  expense: exp,
                                  onTap: () => context.push('/expenses/${exp.id}'),
                                );
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final exp = filtered[i];
                                return ExpenseListRow(
                                  expense: exp,
                                  onTap: () => context.push('/expenses/${exp.id}'),
                                );
                              },
                            ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
