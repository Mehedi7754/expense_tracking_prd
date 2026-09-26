import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/minimal_area_chart.dart';
import '../../core/widgets/project_cost_card.dart';
import '../../core/widgets/receipt_compliance_badge.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/notification_provider.dart';
import '../../state/project_provider.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  String _activeFilter = 'all'; // all, profitable, approaching, overbudget

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final role = user?.role ?? UserRole.projectMember;

    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);

    final visibleProjects = user == null
        ? <ProjectModel>[]
        : (role.canViewAllProjects
            ? allProjects
            : allProjects.where((p) => p.teamMemberIds.contains(user.id)).toList());
    final visibleProjectIds = visibleProjects.map((p) => p.id).toSet();
    final visibleExpenses = user == null
        ? <ExpenseModel>[]
        : (role.canViewAllProjects
            ? allExpenses
            : allExpenses.where((e) => e.employeeId == user.id || visibleProjectIds.contains(e.projectId)).toList());

    final notifications = ref.watch(notificationProvider);
    final unreadNotifsCount = notifications.where((n) {
      if (user == null) return false;
      return (n.userId == user.id || n.userId.isEmpty) && !n.isRead;
    }).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            // User Avatar with Initials
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PFIS Financials',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Expense & Budget Tracking',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Professional Cohesive Persona Switcher Pill
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => _showPersonaSwitcherModal(context, ref, user),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      role.displayName.split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Notification Bell
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: isDark ? Colors.white : const Color(0xFF4338CA),
                  size: 22,
                ),
                if (unreadNotifsCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push(RoutePaths.notifications),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await Future.delayed(const Duration(milliseconds: 300)),
        color: const Color(0xFF4F46E5),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Body according to Role
                  if (role == UserRole.projectMember)
                    _buildMemberDashboard(context, ref, user!, visibleProjects, visibleExpenses)
                  else if (role == UserRole.viewer)
                    _buildViewerDashboard(context, ref, user!, visibleProjects, visibleExpenses)
                  else
                    _buildCompanyDashboard(context, ref, allProjects, allExpenses),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 1. COMPANY-LEVEL DASHBOARD (Admin & Finance & Manager) ====================
  Widget _buildCompanyDashboard(
    BuildContext context,
    WidgetRef ref,
    List<ProjectModel> projects,
    List<ExpenseModel> expenses,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Financial calculations - Optimized O(N+M) single pass direct cost map
    final activeProjects = projects.where((p) => p.status == ProjectStatus.ongoing).toList();
    final totalContractValue = projects.fold<double>(0.0, (sum, p) => sum + p.grossProjectValue);

    final Map<String, double> directCostByProjectId = {};
    for (final e in expenses) {
      directCostByProjectId[e.projectId] = (directCostByProjectId[e.projectId] ?? 0.0) + e.amount;
    }

    double totalCostIncurred = 0.0;
    for (final p in projects) {
      final directCost = directCostByProjectId[p.id] ?? 0.0;
      final officeBenefit = directCost * p.officeBenefitRate;
      totalCostIncurred += (directCost + officeBenefit);
    }

    final totalExpectedAdditionalCost = projects.fold<double>(0.0, (sum, p) => sum + p.estimatedRemainingCost);
    final projectedFinalCost = totalCostIncurred + totalExpectedAdditionalCost;
    final projectedRevenue = projects.fold<double>(0.0, (sum, p) => sum + p.expectedNetRevenue);
    final projectedProfit = totalContractValue - projectedFinalCost;
    final projectedProfitMargin = totalContractValue > 0 ? (projectedProfit / totalContractValue) * 100 : 0.0;

    // Filter projects using O(1) direct cost lookup
    final profitableProjects = projects.where((p) {
      final direct = directCostByProjectId[p.id] ?? 0.0;
      final cost = direct * (1 + p.officeBenefitRate) + p.estimatedRemainingCost;
      final profit = p.grossProjectValue - cost;
      return p.grossProjectValue > 0 && (profit / p.grossProjectValue) >= 0.30;
    }).toList();

    final approachingProjects = projects.where((p) {
      final direct = directCostByProjectId[p.id] ?? 0.0;
      final cost = direct * (1 + p.officeBenefitRate);
      return p.budget > 0 && cost >= (p.budget * 0.80) && cost <= p.budget;
    }).toList();

    final overBudgetProjects = projects.where((p) {
      final direct = directCostByProjectId[p.id] ?? 0.0;
      final cost = direct * (1 + p.officeBenefitRate);
      return p.budget > 0 && cost > p.budget;
    }).toList();

    List<ProjectModel> filteredProjects = projects;
    if (_activeFilter == 'profitable') filteredProjects = profitableProjects;
    if (_activeFilter == 'approaching') filteredProjects = approachingProjects;
    if (_activeFilter == 'overbudget') filteredProjects = overBudgetProjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Financial Card (Inspired by Image 2 & 1)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF2E1065)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top label + Profit trend pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Portfolio Value',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: Color(0xFF4ADE80), size: 13),
                        const SizedBox(width: 3),
                        Text(
                          '${projectedProfitMargin.toStringAsFixed(1)}% Margin',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Huge Bold Balance Number
              Text(
                CurrencyFormatter.format(totalContractValue, compact: true),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 18),

              // 3 Translucent Frosted Glass Mini-Pills (Image 2 style)
              Row(
                children: [
                  _buildFrostedMiniStat(
                    icon: Icons.payments_outlined,
                    label: 'Incurred',
                    value: CurrencyFormatter.format(totalCostIncurred, compact: true),
                  ),
                  const SizedBox(width: 8),
                  _buildFrostedMiniStat(
                    icon: Icons.receipt_long_outlined,
                    label: 'Net Revenue',
                    value: CurrencyFormatter.format(projectedRevenue, compact: true),
                  ),
                  const SizedBox(width: 8),
                  _buildFrostedMiniStat(
                    icon: Icons.business_center_outlined,
                    label: 'Active',
                    value: '${activeProjects.length} Projects',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Curved Area Graph (Image 2 style)
        const MinimalAreaChart(
          title: 'Monthly Earnings',
        ),

        const SizedBox(height: 8),

        // Filter Tabs (Image 2 & 3 style)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterPill(
                label: 'All (${projects.length})',
                isSelected: _activeFilter == 'all',
                onTap: () => setState(() => _activeFilter = 'all'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: 'Profitable (${profitableProjects.length})',
                isSelected: _activeFilter == 'profitable',
                onTap: () => setState(() => _activeFilter = 'profitable'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: 'Approaching (${approachingProjects.length})',
                isSelected: _activeFilter == 'approaching',
                onTap: () => setState(() => _activeFilter = 'approaching'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: 'Over Budget (${overBudgetProjects.length})',
                isSelected: _activeFilter == 'overbudget',
                onTap: () => setState(() => _activeFilter = 'overbudget'),
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Section Title & "View All"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Project Portfolios',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => context.push(RoutePaths.projectsList),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Minimal Project Cost Cards List
        if (filteredProjects.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No projects match this filter.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        else
          ...filteredProjects.map((p) {
            final pExp = expenses.where((e) => e.projectId == p.id).toList();
            return ProjectCostCard(
              project: p,
              projectExpenses: pExp,
              onTap: () => context.push(RoutePaths.projectDetail(p.id)),
            );
          }),
      ],
    );
  }

  // ==================== 2. MEMBER DASHBOARD VIEW (Fahim - Field Staff) ====================
  Widget _buildMemberDashboard(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    List<ProjectModel> assignedProjects,
    List<ExpenseModel> userExpenses,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final metrics = ref.read(expenseProvider.notifier).getReceiptMetrics(memberId: user.id);
    final unreceiptedAmount = metrics['unreceiptedAmount'] ?? 0.0;
    final unreceiptedRatio = metrics['unreceiptedRatio'] ?? 0.0;
    final isHighRisk = unreceiptedRatio >= 50.0;

    final totalSpent = userExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal Hero Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF2E1065)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Total Submitted Claims',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                CurrencyFormatter.format(totalSpent),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildFrostedMiniStat(
                    icon: Icons.receipt_rounded,
                    label: 'Unreceipted',
                    value: '${unreceiptedRatio.toStringAsFixed(0)}%',
                  ),
                  const SizedBox(width: 8),
                  _buildFrostedMiniStat(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Receipted',
                    value: '${(100 - unreceiptedRatio).toStringAsFixed(0)}%',
                  ),
                  const SizedBox(width: 8),
                  _buildFrostedMiniStat(
                    icon: Icons.folder_outlined,
                    label: 'Projects',
                    value: '${assignedProjects.length} Assigned',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Curved Area Graph (Image 2 style)
        const MinimalAreaChart(
          title: 'Monthly Spending',
        ),

        // Receipt Compliance Alert (if > 50%)
        if (isHighRisk)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF7F1D1D).withAlpha(40) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt Compliance Alert (>50%)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '৳${CurrencyFormatter.format(unreceiptedAmount, compact: true)} lacks receipts. Please submit justification.',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(RoutePaths.receiptCompliance),
                  child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Dual Indicator Summary Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ReceiptComplianceBadge(
            unreceiptedAmount: unreceiptedAmount,
            unreceiptedRatio: unreceiptedRatio,
          ),
        ),

        const SizedBox(height: 18),

        // Assigned Projects Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Assigned Projects (${assignedProjects.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        if (assignedProjects.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No projects currently assigned to your profile.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        else
          ...assignedProjects.map((p) {
            final pExp = userExpenses.where((e) => e.projectId == p.id).toList();
            return ProjectCostCard(
              project: p,
              projectExpenses: pExp,
              onTap: () => context.push(RoutePaths.projectDetail(p.id)),
            );
          }),

        const SizedBox(height: 16),

        // Recent Expense Claims
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Expenses',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => context.push(RoutePaths.myExpenses),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        ...userExpenses.take(4).map((e) => _buildMinimalExpenseRow(context, e, isDark)),
      ],
    );
  }

  // ==================== 3. VIEWER DASHBOARD VIEW (Read-Only) ====================
  Widget _buildViewerDashboard(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    List<ProjectModel> assignedProjects,
    List<ExpenseModel> visibleExpenses,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Viewer Mode: Read-only access to permitted audit data.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Permitted Projects (${assignedProjects.length})',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ...assignedProjects.map((p) {
          final pExp = visibleExpenses.where((e) => e.projectId == p.id).toList();
          return ProjectCostCard(
            project: p,
            projectExpenses: pExp,
            onTap: () => context.push(RoutePaths.projectDetail(p.id)),
          );
        }),
      ],
    );
  }

  // Helper: Frosted Mini Stat Inside Hero Card
  Widget _buildFrostedMiniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Filter Pill
  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withAlpha(40),
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
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // Helper: Minimal Expense Row (Image 3 style)
  Widget _buildMinimalExpenseRow(BuildContext context, ExpenseModel expense, bool isDark) {
    Color iconColor;
    Color iconBg;
    IconData icon;

    switch (expense.categoryId.toLowerCase()) {
      case 'food':
        iconColor = const Color(0xFFF59E0B);
        iconBg = const Color(0xFFFFFBEB);
        icon = Icons.restaurant_rounded;
        break;
      case 'transportation':
        iconColor = const Color(0xFF0D9488);
        iconBg = const Color(0xFFF0FDFA);
        icon = Icons.directions_car_rounded;
        break;
      case 'equipment':
        iconColor = const Color(0xFF4F46E5);
        iconBg = const Color(0xFFEEF2FF);
        icon = Icons.construction_rounded;
        break;
      case 'accommodation':
        iconColor = const Color(0xFF8B5CF6);
        iconBg = const Color(0xFFF5F3FF);
        icon = Icons.hotel_rounded;
        break;
      default:
        iconColor = const Color(0xFF0284C7);
        iconBg = const Color(0xFFF0F9FF);
        icon = Icons.receipt_rounded;
        break;
    }

    if (isDark) {
      iconBg = iconColor.withAlpha(25);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.categoryName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  expense.note.isEmpty ? 'Project expenditure' : expense.note,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(expense.amount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: expense.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    expense.hasReceipt ? 'Receipt' : 'No Receipt',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: expense.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Persona Switcher Bottom Sheet Modal
  void _showPersonaSwitcherModal(BuildContext context, WidgetRef ref, UserModel? currentUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(60),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Switch Test Persona',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select any PRD role to preview role-specific dashboards & permissions.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...DemoUsers.all.map((u) {
                    final isSelected = currentUser?.id == u.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            _getUserInitials(u.name),
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        u.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        u.role.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? const Color(0xFF4F46E5) : Colors.grey,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5))
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(authProvider.notifier).switchRole(u.role);
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getUserInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}
