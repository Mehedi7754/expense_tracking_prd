import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/expense_list_row.dart';
import '../../core/widgets/project_card.dart';
import '../../core/widgets/role_badge.dart';
import '../../core/widgets/stat_card.dart';
import '../../models/expense_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/user_management_provider.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final role = user?.role ?? UserRole.employee;

    final expenses = ref.watch(expenseProvider);
    final projects = ref.watch(projectProvider);
    final users = ref.watch(userManagementProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user?.name.split(' ').first ?? 'User'}',
                  style: AppTextStyles.titleMedium,
                ),
                Text(
                  user?.department ?? 'Enterprise Staff',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.getTextMuted(context)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: RoleBadge(role: role),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (role == UserRole.employee)
                _buildEmployeeView(context, ref, user!.id, expenses)
              else if (role == UserRole.manager || role == UserRole.finance)
                _buildManagerFinanceView(context, ref, role, expenses, projects)
              else
                _buildAdminView(context, ref, expenses, projects, users),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 1. EMPLOYEE DASHBOARD VIEW ====================
  Widget _buildEmployeeView(
    BuildContext context,
    WidgetRef ref,
    String userId,
    List<ExpenseModel> allExpenses,
  ) {
    final isDark = AppColors.isDark(context);
    final myExpenses = allExpenses.where((e) => e.employeeId == userId).toList();

    double totalSubmitted = 0.0;
    double totalApproved = 0.0;
    double totalPending = 0.0;
    double totalRejected = 0.0;

    for (final exp in myExpenses) {
      totalSubmitted += exp.amount;
      if (exp.status == ExpenseStatus.approved) totalApproved += exp.amount;
      if (exp.status == ExpenseStatus.pending) totalPending += exp.amount;
      if (exp.status == ExpenseStatus.rejected) totalRejected += exp.amount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary Call to Action Shortcut
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.darkHeroCardGradient : AppColors.heroCardGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.floatingShadow(isDark),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to claim an expense?',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.textWhite),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attach receipts and select an assigned project.',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => context.push(RoutePaths.submitExpense),
                icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                label: Text(
                  'Add Expense',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4 Stat Cards: Submitted, Approved, Pending, Rejected
        Text('My Expense Overview', style: AppTextStyles.titleSmall),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.10,
          children: [
            StatCard(
              label: 'Total Submitted',
              value: CurrencyFormatter.format(totalSubmitted, compact: true),
              icon: Icons.receipt_long_rounded,
              iconBgColor: AppColors.surfaceSubtle,
              iconColor: AppColors.primary,
              trendText: '${myExpenses.length} claims',
            ),
            StatCard(
              label: 'Approved',
              value: CurrencyFormatter.format(totalApproved, compact: true),
              icon: Icons.check_circle_rounded,
              iconBgColor: AppColors.emeraldLight,
              iconColor: AppColors.emerald,
              trendDirection: TrendDirection.up,
              trendText: 'Paid/Ready',
            ),
            StatCard(
              label: 'Pending Review',
              value: CurrencyFormatter.format(totalPending, compact: true),
              icon: Icons.hourglass_top_rounded,
              iconBgColor: AppColors.amberLight,
              iconColor: AppColors.amber,
              trendDirection: TrendDirection.neutral,
              trendText: 'In Queue',
            ),
            StatCard(
              label: 'Rejected',
              value: CurrencyFormatter.format(totalRejected, compact: true),
              icon: Icons.cancel_rounded,
              iconBgColor: AppColors.crimsonLight,
              iconColor: AppColors.crimson,
              trendDirection: TrendDirection.down,
              trendText: 'Action needed',
            ),
          ],
        ),

        const SizedBox(height: 24),
        // Recent Activity Feed
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity', style: AppTextStyles.titleSmall),
            TextButton(
              onPressed: () => context.go(RoutePaths.myExpenses),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (myExpenses.isEmpty)
          EmptyStateWidget(
            icon: Icons.receipt_long_outlined,
            title: 'No expenses yet',
            message: 'Tap the button above to record your first business expense.',
            actionLabel: 'Submit Expense',
            onAction: () => context.push(RoutePaths.submitExpense),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: myExpenses.take(5).length,
            itemBuilder: (ctx, index) {
              final exp = myExpenses[index];
              return ExpenseListRow(
                expense: exp,
                onTap: () => context.push('/expenses/${exp.id}'),
              );
            },
          ),
      ],
    );
  }

  // ==================== 2. MANAGER & FINANCE DASHBOARD VIEW ====================
  Widget _buildManagerFinanceView(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
    List<ExpenseModel> allExpenses,
    List<dynamic> allProjects,
  ) {
    final pendingExpenses = allExpenses.where((e) => e.status == ExpenseStatus.pending).toList();

    double totalCompanySpent = 0.0;
    for (final e in allExpenses.where((exp) => exp.status == ExpenseStatus.approved)) {
      totalCompanySpent += e.amount;
    }

    // Projects at risk (>80% budget used)
    final atRiskProjects = allProjects.where((p) {
      double spent = 0.0;
      for (final e in allExpenses.where((exp) => exp.projectId == p.id && exp.status == ExpenseStatus.approved)) {
        spent += e.amount;
      }
      return p.budget > 0 && (spent / p.budget) >= 0.80;
    }).toList();

    final isDark = AppColors.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (role == UserRole.finance || role == UserRole.admin) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.darkHeroCardGradient : AppColors.heroCardGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.floatingShadow(isDark),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_graph_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Financial Dashboard',
                        style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Totals, profit margins, & high-spend projects',
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => context.push(RoutePaths.companyDashboard),
                  child: const Text('Explore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
        Text(
          role == UserRole.finance ? 'Finance Operations' : 'Management Overview',
          style: AppTextStyles.titleSmall,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.10,
          children: [
            StatCard(
              label: 'Pending Approvals',
              value: '${pendingExpenses.length}',
              icon: Icons.fact_check_rounded,
              iconBgColor: AppColors.amberLight,
              iconColor: AppColors.amber,
              trendText: 'Needs review',
              trendDirection: TrendDirection.down,
              onTap: () => context.go(RoutePaths.approvalsQueue),
            ),
            StatCard(
              label: 'Projects At Risk',
              value: '${atRiskProjects.length}',
              icon: Icons.warning_amber_rounded,
              iconBgColor: AppColors.crimsonLight,
              iconColor: AppColors.crimson,
              trendText: '>80% budget',
              trendDirection: TrendDirection.down,
            ),
            StatCard(
              label: 'Total Active Spend',
              value: CurrencyFormatter.format(totalCompanySpent, compact: true),
              icon: Icons.payments_rounded,
              iconBgColor: AppColors.emeraldLight,
              iconColor: AppColors.emerald,
              trendText: 'Approved YTD',
              trendDirection: TrendDirection.up,
            ),
            StatCard(
              label: 'Active Projects',
              value: '${allProjects.length}',
              icon: Icons.folder_open_rounded,
              iconBgColor: AppColors.surfaceSubtle,
              iconColor: AppColors.primary,
              trendText: 'Monitoring',
              onTap: () => context.go(RoutePaths.projects),
            ),
          ],
        ),

        const SizedBox(height: 24),
        // Urgent Approvals Queue shortcut
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Awaiting Decision', style: AppTextStyles.titleSmall),
            TextButton(
              onPressed: () => context.go(RoutePaths.approvalsQueue),
              child: const Text('Open Queue'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (pendingExpenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AppColors.emerald, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All caught up! No claims currently awaiting review.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingExpenses.take(3).length,
            itemBuilder: (ctx, index) {
              final exp = pendingExpenses[index];
              return ExpenseListRow(
                expense: exp,
                showEmployeeName: true,
                onTap: () => context.push('/approvals'),
              );
            },
          ),

        const SizedBox(height: 24),
        // Projects At Risk List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Projects at Budget Risk (>80%)', style: AppTextStyles.titleSmall),
            TextButton(
              onPressed: () => context.go(RoutePaths.projects),
              child: const Text('All Projects'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (atRiskProjects.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.emerald, size: 20),
                const SizedBox(width: 10),
                Text('All project budgets are currently healthy.', style: AppTextStyles.bodySmall),
              ],
            ),
          )
        else
          ...atRiskProjects.map((proj) {
            double spent = 0.0;
            for (final e in allExpenses.where((exp) => exp.projectId == proj.id && exp.status == ExpenseStatus.approved)) {
              spent += e.amount;
            }
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
          }),
      ],
    );
  }

  // ==================== 3. ADMINISTRATOR DASHBOARD VIEW ====================
  Widget _buildAdminView(
    BuildContext context,
    WidgetRef ref,
    List<ExpenseModel> allExpenses,
    List<dynamic> allProjects,
    List<dynamic> allUsers,
  ) {
    final activeUsersCount = allUsers.where((u) => u.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Governance snapshot cards
        Text('Executive & Governance Control', style: AppTextStyles.titleSmall),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.10,
          children: [
            StatCard(
              label: 'Active Users',
              value: '$activeUsersCount',
              icon: Icons.people_alt_rounded,
              iconBgColor: AppColors.indigoLight,
              iconColor: AppColors.indigo,
              trendText: '${allUsers.length} total accounts',
              onTap: () => context.push(RoutePaths.userManagement),
            ),
            StatCard(
              label: 'Active Projects',
              value: '${allProjects.length}',
              icon: Icons.business_rounded,
              iconBgColor: AppColors.emeraldLight,
              iconColor: AppColors.emerald,
              trendText: 'Enterprise portfolio',
              onTap: () => context.go(RoutePaths.projects),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Quick Governance Access Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QuickActionBtn(
                icon: Icons.person_add_outlined,
                label: 'Add User',
                onTap: () => context.push(RoutePaths.addUser),
              ),
              _QuickActionBtn(
                icon: Icons.category_outlined,
                label: 'Categories',
                onTap: () => context.push(RoutePaths.categoryManagement),
              ),
              _QuickActionBtn(
                icon: Icons.history_edu_rounded,
                label: 'Audit Log',
                onTap: () => context.push(RoutePaths.auditLog),
              ),
              _QuickActionBtn(
                icon: Icons.tune_rounded,
                label: 'Setup',
                onTap: () => context.push(RoutePaths.companySetup),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Also includes Manager/Finance monitoring metrics
        _buildManagerFinanceView(context, ref, UserRole.admin, allExpenses, allProjects),
      ],
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
