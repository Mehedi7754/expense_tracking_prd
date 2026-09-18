import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/chart_widget.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/expense_list_row.dart';
import '../../core/widgets/stat_card.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/task_provider.dart';
import '../../state/user_management_provider.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 5 Tabs as mandated by PRD Section 4.4: Overview, Tasks, Expenses, Revenue, Team
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);
    final allTasks = ref.watch(taskProvider);
    final allUsers = ref.watch(userManagementProvider);
    final user = ref.watch(authProvider).currentUser;
    final role = user?.role ?? UserRole.employee;

    final projectList = allProjects.where((p) => p.id == widget.projectId);
    if (projectList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Detail')),
        body: const Center(child: Text('Project not found.')),
      );
    }

    final project = projectList.first;

    // Financial calculations
    final projectExpenses = allExpenses.where((e) => e.projectId == project.id).toList();
    final approvedExpenses = projectExpenses.where((e) => e.status == ExpenseStatus.approved).toList();

    double spent = 0.0;
    for (final e in approvedExpenses) {
      spent += e.amount;
    }

    double revenue = 0.0;
    for (final r in project.revenueEntries) {
      revenue += r.amount;
    }

    final remaining = project.budget - spent;
    final profit = revenue - spent;
    final profitMargin = revenue > 0 ? (profit / revenue) : 0.0;

    // Permissions (PRD Section 4.4)
    final canAddRevenue = role == UserRole.finance || role == UserRole.admin;
    final canEditProject = role == UserRole.manager || role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          if (canEditProject)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Project Details',
              onPressed: () => context.push('/projects/${project.id}/edit'),
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Expenses'),
            Tab(text: 'Revenue'),
            Tab(text: 'Team'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. OVERVIEW TAB (Header 6 Stat Cards + Charts)
          _buildOverviewTab(project, spent, remaining, revenue, profit, profitMargin, approvedExpenses),

          // 2. TASKS TAB (List of tasks + Add Task button)
          _buildTasksTab(context, project, allTasks),

          // 3. EXPENSES TAB (List of expenses for this project)
          _buildExpensesTab(context, projectExpenses),

          // 4. REVENUE TAB (Revenue entries + Add Revenue button)
          _buildRevenueTab(context, project, canAddRevenue),

          // 5. TEAM TAB (Assigned employees & individual spend)
          _buildTeamTab(context, project, allUsers, approvedExpenses),
        ],
      ),
    );
  }

  // ==================== 1. OVERVIEW TAB ====================
  Widget _buildOverviewTab(
    ProjectModel project,
    double spent,
    double remaining,
    double revenue,
    double profit,
    double profitMargin,
    List<ExpenseModel> approvedExpenses,
  ) {
    // Category Breakdown Calculation
    final Map<String, double> categoryCosts = {};
    for (final e in approvedExpenses) {
      categoryCosts[e.categoryName] = (categoryCosts[e.categoryName] ?? 0.0) + e.amount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PRD Section 4.4: Header showing budget, spent, remaining, revenue, profit, profit margin
          Text('Financial Overview', style: AppTextStyles.titleSmall),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.12,
            children: [
              StatCard(
                label: 'Total Budget',
                value: CurrencyFormatter.format(project.budget, compact: true),
                icon: Icons.account_balance_rounded,
                iconBgColor: AppColors.surfaceSubtle,
              ),
              StatCard(
                label: 'Amount Spent',
                value: CurrencyFormatter.format(spent, compact: true),
                icon: Icons.receipt_rounded,
                iconColor: AppColors.primary,
                trendText: '${CurrencyFormatter.formatPercentage(project.budget > 0 ? spent / project.budget : 0)} used',
              ),
              StatCard(
                label: 'Amount Remaining',
                value: CurrencyFormatter.format(remaining, compact: true),
                icon: Icons.savings_outlined,
                iconColor: remaining < 0 ? AppColors.crimson : AppColors.emerald,
                iconBgColor: remaining < 0 ? AppColors.crimsonLight : AppColors.emeraldLight,
              ),
              StatCard(
                label: 'Total Revenue',
                value: CurrencyFormatter.format(revenue, compact: true),
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.emerald,
                iconBgColor: AppColors.emeraldLight,
              ),
              StatCard(
                label: 'Net Profit',
                value: CurrencyFormatter.format(profit, compact: true),
                icon: Icons.monetization_on_outlined,
                iconColor: profit < 0 ? AppColors.crimson : AppColors.emerald,
                iconBgColor: profit < 0 ? AppColors.crimsonLight : AppColors.emeraldLight,
                trendDirection: profit >= 0 ? TrendDirection.up : TrendDirection.down,
              ),
              StatCard(
                label: 'Profit Margin',
                value: CurrencyFormatter.formatPercentage(profitMargin),
                icon: Icons.pie_chart_outline_rounded,
                iconColor: profitMargin < 0 ? AppColors.crimson : AppColors.emerald,
                iconBgColor: profitMargin < 0 ? AppColors.crimsonLight : AppColors.emeraldLight,
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Chart: Cost by Category (PRD Section 4.4)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(context)),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cost Breakdown by Category', style: AppTextStyles.titleSmall),
                const SizedBox(height: 16),
                CategoryDonutChart(categoryCosts: categoryCosts, total: spent),
              ],
            ),
          ),

          const SizedBox(height: 20),
          // Chart: Spending Trend Over Time (PRD Section 4.4)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(context)),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spending Trend Over Time', style: AppTextStyles.titleSmall),
                const SizedBox(height: 16),
                const SpendingTrendLineChart(
                  monthlyValues: [2400, 3800, 3100, 5200, 4800, 6100],
                  monthLabels: ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==================== 2. TASKS TAB ====================
  Widget _buildTasksTab(BuildContext context, ProjectModel project, List<TaskModel> allTasks) {
    final projectTasks = allTasks.where((t) => t.projectId == project.id).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/new?projectId=${project.id}'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Task'),
      ),
      body: projectTasks.isEmpty
          ? EmptyStateWidget(
              icon: Icons.task_alt_outlined,
              title: 'No Tasks in Project',
              message: 'Break this project down into tasks with assignees and due dates.',
              actionLabel: 'Add First Task',
              onAction: () => context.push('/tasks/new?projectId=${project.id}'),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: projectTasks.length,
              itemBuilder: (ctx, i) {
                final task = projectTasks[i];
                final isDone = task.status == TaskStatus.completed;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.getBorder(context)),
                  ),
                  child: ListTile(
                    leading: IconButton(
                      icon: Icon(
                        isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: isDone ? AppColors.emerald : AppColors.textMuted,
                      ),
                      onPressed: () {
                        ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
                      },
                    ),
                    title: Text(
                      task.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Assigned to: ${task.assigneeName} • Due ${DateFormatter.formatShort(task.dueDate)}',
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () => context.push('/tasks/${task.id}'),
                  ),
                );
              },
            ),
    );
  }

  // ==================== 3. EXPENSES TAB ====================
  Widget _buildExpensesTab(BuildContext context, List<ExpenseModel> projectExpenses) {
    if (projectExpenses.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long_outlined,
        title: 'No Project Expenses',
        message: 'No expense claims have been charged to this project yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projectExpenses.length,
      itemBuilder: (ctx, i) {
        final exp = projectExpenses[i];
        return ExpenseListRow(
          expense: exp,
          showEmployeeName: true,
          onTap: () => context.push('/expenses/${exp.id}'),
        );
      },
    );
  }

  // ==================== 4. REVENUE TAB ====================
  Widget _buildRevenueTab(BuildContext context, ProjectModel project, bool canAddRevenue) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canAddRevenue
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/projects/${project.id}/revenue/new'),
              backgroundColor: AppColors.emerald,
              foregroundColor: AppColors.textWhite,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Revenue'),
            )
          : null,
      body: project.revenueEntries.isEmpty
          ? EmptyStateWidget(
              icon: Icons.attach_money_rounded,
              title: 'No Revenue Recorded',
              message: 'Record incoming milestone payments and earnings for this project.',
              actionLabel: canAddRevenue ? 'Add Revenue Entry' : null,
              onAction: canAddRevenue ? () => context.push('/projects/${project.id}/revenue/new') : null,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: project.revenueEntries.length,
              itemBuilder: (ctx, i) {
                final rev = project.revenueEntries[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.getBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_downward_rounded, color: AppColors.emerald, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rev.note, style: AppTextStyles.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              'Recorded by ${rev.createdBy} • ${DateFormatter.formatShort(rev.date)}',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${CurrencyFormatter.format(rev.amount)}',
                        style: AppTextStyles.currencySmall.copyWith(
                          color: AppColors.emeraldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ==================== 5. TEAM TAB ====================
  Widget _buildTeamTab(
    BuildContext context,
    ProjectModel project,
    List<dynamic> allUsers,
    List<ExpenseModel> approvedExpenses,
  ) {
    final assignedUsers = allUsers.where((u) => project.teamMemberIds.contains(u.id)).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assignedUsers.length,
      itemBuilder: (ctx, i) {
        final member = assignedUsers[i];

        // Individual spend total for this project (PRD Section 4.4 Project Team Screen)
        double memberSpend = 0.0;
        for (final e in approvedExpenses.where((exp) => exp.employeeId == member.id)) {
          memberSpend += e.amount;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.getBorder(context)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/profile/employee/${member.id}'),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                      child: Text(
                        member.name.isNotEmpty ? member.name[0] : 'U',
                        style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: AppTextStyles.titleSmall),
                          Text('${member.department} • ${member.role.displayName}', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(memberSpend),
                          style: AppTextStyles.currencySmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text('Project spend', style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.getTextMuted(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
