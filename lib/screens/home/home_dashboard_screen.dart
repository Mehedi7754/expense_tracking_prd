import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/expense_list_row.dart';
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
            // App Logo in Header
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4338CA), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
            child: Tooltip(
              message: 'Switch PRD Persona',
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
        // Hero Financial Card (Minimal Gradient, Clickable -> Projects Portfolio)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4338CA), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _showPortfolioFinancialDetailsModal(
                context: context,
                isDark: isDark,
                projects: projects,
                expenses: expenses,
                totalContractValue: totalContractValue,
                totalCostIncurred: totalCostIncurred,
                projectedRevenue: projectedRevenue,
                projectedProfitMargin: projectedProfitMargin,
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top label + Profit trend pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Total Portfolio Value',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 5),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 11),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
            ),
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
              Expanded(
                child: Text(
                  'Project Portfolios',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        // Personal Hero Card (Minimal Gradient, Clickable -> Assigned Projects)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4338CA), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                final assignedGross = assignedProjects.fold<double>(0.0, (sum, p) => sum + p.grossProjectValue);
                final margin = assignedGross > 0 ? ((assignedGross - totalSpent) / assignedGross) * 100 : 0.0;
                _showPortfolioFinancialDetailsModal(
                  context: context,
                  isDark: isDark,
                  projects: assignedProjects,
                  expenses: userExpenses,
                  totalContractValue: assignedGross,
                  totalCostIncurred: totalSpent,
                  projectedRevenue: assignedProjects.fold<double>(0.0, (sum, p) => sum + p.expectedNetRevenue),
                  projectedProfitMargin: margin,
                  memberUser: user,
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'My Total Submitted Claims',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 11),
                      ],
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
            ),
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
            children: [
              Expanded(
                child: Text(
                  'My Assigned Projects (${assignedProjects.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
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
              Expanded(
                child: Text(
                  'Recent Expenses',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
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
                  ...DemoUsers.all.where((u) => u.role != UserRole.viewer).map((u) {
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

  // Portfolio Financial Details Modal Bottom Sheet
  void _showPortfolioFinancialDetailsModal({
    required BuildContext context,
    required bool isDark,
    required List<ProjectModel> projects,
    required List<ExpenseModel> expenses,
    required double totalContractValue,
    required double totalCostIncurred,
    required double projectedRevenue,
    required double projectedProfitMargin,
    UserModel? memberUser,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return _PortfolioFinancialDetailsSheet(
          isDark: isDark,
          projects: projects,
          expenses: expenses,
          totalContractValue: totalContractValue,
          totalCostIncurred: totalCostIncurred,
          projectedRevenue: projectedRevenue,
          projectedProfitMargin: projectedProfitMargin,
          memberUser: memberUser,
        );
      },
    );
  }
}

// ==============================================================================
// 3. PORTFOLIO FINANCIAL & PERSONNEL BREAKDOWN BOTTOM SHEET
// ==============================================================================

class _PortfolioFinancialDetailsSheet extends StatefulWidget {
  final bool isDark;
  final List<ProjectModel> projects;
  final List<ExpenseModel> expenses;
  final double totalContractValue;
  final double totalCostIncurred;
  final double projectedRevenue;
  final double projectedProfitMargin;
  final UserModel? memberUser;

  const _PortfolioFinancialDetailsSheet({
    required this.isDark,
    required this.projects,
    required this.expenses,
    required this.totalContractValue,
    required this.totalCostIncurred,
    required this.projectedRevenue,
    required this.projectedProfitMargin,
    this.memberUser,
  });

  @override
  State<_PortfolioFinancialDetailsSheet> createState() => _PortfolioFinancialDetailsSheetState();
}

class _PortfolioFinancialDetailsSheetState extends State<_PortfolioFinancialDetailsSheet> {
  int _selectedTabIndex = 0; // 0: By Person, 1: By Category, 2: By Project, 3: All Records
  final Set<String> _expandedPersonNames = {};
  final Set<String> _expandedCategoryNames = {};
  final Set<String> _expandedProjectIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'equipment':
      case 'hardware':
        return Icons.hardware_rounded;
      case 'transportation':
      case 'transport':
      case 'travel':
        return Icons.directions_car_rounded;
      case 'food':
      case 'meal':
        return Icons.restaurant_rounded;
      case 'accommodation':
      case 'hotel':
        return Icons.hotel_rounded;
      case 'office cost':
      case 'office':
        return Icons.business_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _getUserInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final totalDirectSpent = widget.expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final totalUnreceipted = widget.expenses
        .where((e) => !e.hasReceipt)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
    final overallUnreceiptedRatio = totalDirectSpent > 0 ? (totalUnreceipted / totalDirectSpent) * 100 : 0.0;

    // Group expenses by Person
    final Map<String, List<ExpenseModel>> groupedByPerson = {};
    for (final e in widget.expenses) {
      groupedByPerson.putIfAbsent(e.employeeName, () => []).add(e);
    }

    final List<_PersonCostSummary> personSummaries = [];
    for (final entry in groupedByPerson.entries) {
      final pExpenses = entry.value;
      final name = entry.key;
      final pId = pExpenses.first.employeeId;
      final totalAmt = pExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      final unreceipted = pExpenses.where((e) => !e.hasReceipt).toList();
      final unreceiptedAmt = unreceipted.fold<double>(0.0, (sum, e) => sum + e.amount);

      final Map<String, double> catMap = {};
      for (final e in pExpenses) {
        catMap[e.categoryName] = (catMap[e.categoryName] ?? 0.0) + e.amount;
      }

      final Set<String> projNames = pExpenses.map((e) => e.projectName).toSet();

      UserModel? demoUser;
      for (final u in DemoUsers.all) {
        if (u.id == pId || u.name.toLowerCase() == name.toLowerCase()) {
          demoUser = u;
          break;
        }
      }
      final designation = demoUser?.designation ?? (demoUser?.role.displayName ?? 'Team Member');

      personSummaries.add(_PersonCostSummary(
        personId: pId,
        personName: name,
        designation: designation,
        totalAmount: totalAmt,
        unreceiptedAmount: unreceiptedAmt,
        totalCount: pExpenses.length,
        unreceiptedCount: unreceipted.length,
        categoryAmounts: catMap,
        projectNames: projNames,
        expenses: pExpenses,
      ));
    }
    personSummaries.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // Group expenses by Category
    final Map<String, List<ExpenseModel>> groupedByCat = {};
    for (final e in widget.expenses) {
      groupedByCat.putIfAbsent(e.categoryName, () => []).add(e);
    }

    final List<_CategoryCostSummary> categorySummaries = [];
    for (final entry in groupedByCat.entries) {
      final catExpenses = entry.value;
      final totalAmt = catExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
      final Map<String, double> pAmounts = {};
      for (final e in catExpenses) {
        pAmounts[e.employeeName] = (pAmounts[e.employeeName] ?? 0.0) + e.amount;
      }

      categorySummaries.add(_CategoryCostSummary(
        categoryName: entry.key,
        totalAmount: totalAmt,
        count: catExpenses.length,
        personAmounts: pAmounts,
        expenses: catExpenses,
      ));
    }
    categorySummaries.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // Group expenses by Project
    final List<_ProjectCostSummary> projectSummaries = [];
    for (final p in widget.projects) {
      final pExp = widget.expenses.where((e) => e.projectId == p.id).toList();
      final totalIncurred = pExp.fold<double>(0.0, (sum, e) => sum + e.amount);
      final Map<String, double> pAmounts = {};
      for (final e in pExp) {
        pAmounts[e.employeeName] = (pAmounts[e.employeeName] ?? 0.0) + e.amount;
      }
      projectSummaries.add(_ProjectCostSummary(
        project: p,
        totalIncurred: totalIncurred,
        personAmounts: pAmounts,
        expenseCount: pExp.length,
        expenses: pExp,
      ));
    }
    projectSummaries.sort((a, b) => b.totalIncurred.compareTo(a.totalIncurred));

    // Filtered all expenses for search
    final query = _searchController.text.trim().toLowerCase();
    final filteredExpenses = widget.expenses.where((e) {
      if (query.isEmpty) return true;
      return e.employeeName.toLowerCase().contains(query) ||
          e.categoryName.toLowerCase().contains(query) ||
          e.projectName.toLowerCase().contains(query) ||
          e.note.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.memberUser != null
                              ? 'My Expense Breakdown'
                              : 'Financial Details & Cost Audit',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.memberUser != null
                              ? 'Personal cost usage & submitted claims'
                              : 'Person-wise spending, categories & project audit',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4 Mini KPI cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMiniKpi(
                      label: 'Total Spent',
                      value: CurrencyFormatter.format(totalDirectSpent, compact: true),
                      color: const Color(0xFF4F46E5),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniKpi(
                      label: 'Portfolio',
                      value: CurrencyFormatter.format(widget.totalContractValue, compact: true),
                      color: const Color(0xFF0284C7),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniKpi(
                      label: 'Claimants',
                      value: '${personSummaries.length}',
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniKpi(
                      label: 'No Receipt',
                      value: '${overallUnreceiptedRatio.toStringAsFixed(0)}%',
                      color: overallUnreceiptedRatio > 50 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Segmented Tabs Pill Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTabPill(
                    label: widget.memberUser != null
                        ? '👤 My Breakdown (${personSummaries.length})'
                        : '👥 By Person (${personSummaries.length})',
                    index: 0,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildTabPill(
                    label: '🏷️ Categories (${categorySummaries.length})',
                    index: 1,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildTabPill(
                    label: '📁 Projects (${widget.projects.length})',
                    index: 2,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildTabPill(
                    label: '🧾 All Records (${widget.expenses.length})',
                    index: 3,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // Tab Content
            Expanded(
              child: _buildActiveTabContent(
                totalDirectSpent: totalDirectSpent,
                personSummaries: personSummaries,
                categorySummaries: categorySummaries,
                projectSummaries: projectSummaries,
                filteredExpenses: filteredExpenses,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniKpi({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent({
    required double totalDirectSpent,
    required List<_PersonCostSummary> personSummaries,
    required List<_CategoryCostSummary> categorySummaries,
    required List<_ProjectCostSummary> projectSummaries,
    required List<ExpenseModel> filteredExpenses,
    required bool isDark,
  }) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildPersonTab(
          totalDirectSpent: totalDirectSpent,
          personSummaries: personSummaries,
          isDark: isDark,
        );
      case 1:
        return _buildCategoriesTab(
          totalDirectSpent: totalDirectSpent,
          categorySummaries: categorySummaries,
          isDark: isDark,
        );
      case 2:
        return _buildProjectsTab(
          projectSummaries: projectSummaries,
          isDark: isDark,
        );
      case 3:
      default:
        return _buildRecordsTab(
          filteredExpenses: filteredExpenses,
          isDark: isDark,
        );
    }
  }

  // 1. By Person Tab: Which person which cost use
  Widget _buildPersonTab({
    required double totalDirectSpent,
    required List<_PersonCostSummary> personSummaries,
    required bool isDark,
  }) {
    if (personSummaries.isEmpty) {
      return Center(
        child: Text(
          'No person-wise spending records found.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: personSummaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final person = personSummaries[i];
        final isExpanded = _expandedPersonNames.contains(person.personName);
        final shareRatio = totalDirectSpent > 0 ? (person.totalAmount / totalDirectSpent) : 0.0;

        return InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedPersonNames.remove(person.personName);
              } else {
                _expandedPersonNames.add(person.personName);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded
                    ? const Color(0xFF4F46E5).withAlpha(120)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isExpanded ? 1.5 : 1,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal container header row (Always visible)
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _getUserInitials(person.personName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.personName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            person.designation,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(person.totalAmount),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4F46E5),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(shareRatio * 100).toStringAsFixed(1)}% of total',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isExpanded ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),

                // Expanded Section: Only visible when clicked!
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Share Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: shareRatio.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Compliance status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: person.unreceiptedRatio > 50
                          ? (isDark ? const Color(0xFF7F1D1D).withAlpha(40) : const Color(0xFFFEF2F2))
                          : (isDark ? const Color(0xFF064E3B).withAlpha(40) : const Color(0xFFECFDF5)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: person.unreceiptedRatio > 50
                            ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
                            : (isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          person.unreceiptedRatio > 50
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: person.unreceiptedRatio > 50 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            person.unreceiptedAmount > 0
                                ? '${CurrencyFormatter.format(person.unreceiptedAmount)} without receipt (${person.unreceiptedRatio.toStringAsFixed(0)}% of claims)'
                                : '100% Receipts Attached & Verified',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: person.unreceiptedRatio > 50
                                  ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                                  : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Which cost used chips
                  Text(
                    'Cost Usage Breakdown:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: person.categoryAmounts.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getCategoryIcon(entry.key), size: 12, color: const Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${entry.key}: ',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(entry.value),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  // Projects Assigned / Incurred
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: person.projectNames.map((proj) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business_center_outlined, size: 11, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: Text(
                                proj,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4F46E5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Itemized Expenses
                  Text(
                    'Itemized Expenses (${person.expenses.length}):',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...person.expenses.map((e) {
                    return InkWell(
                      onTap: () => context.push(RoutePaths.expenseDetail(e.id)),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getCategoryIcon(e.categoryName),
                              size: 16,
                              color: const Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.note.isNotEmpty ? e.note : e.categoryName,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormatter.formatShort(e.date)} • ${e.hasReceipt ? "🟢 Receipt" : "🔴 No Receipt"}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              CurrencyFormatter.format(e.amount),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. Categories Tab: Minimal container with dropdown expansion
  Widget _buildCategoriesTab({
    required double totalDirectSpent,
    required List<_CategoryCostSummary> categorySummaries,
    required bool isDark,
  }) {
    if (categorySummaries.isEmpty) {
      return Center(
        child: Text(
          'No category records found.',
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categorySummaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final cat = categorySummaries[i];
        final isExpanded = _expandedCategoryNames.contains(cat.categoryName);
        final shareRatio = totalDirectSpent > 0 ? (cat.totalAmount / totalDirectSpent) : 0.0;

        return InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedCategoryNames.remove(cat.categoryName);
              } else {
                _expandedCategoryNames.add(cat.categoryName);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded
                    ? const Color(0xFF4F46E5).withAlpha(120)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isExpanded ? 1.5 : 1,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal Header (Always visible)
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(_getCategoryIcon(cat.categoryName), size: 20, color: const Color(0xFF4F46E5)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.categoryName,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${cat.count} claim${cat.count == 1 ? "" : "s"} • ${cat.personAmounts.length} claimant${cat.personAmounts.length == 1 ? "" : "s"}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(cat.totalAmount),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4F46E5),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(shareRatio * 100).toStringAsFixed(1)}% of spend',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isExpanded ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),

                // Expanded Section
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Share Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: shareRatio.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Claimants in this category
                  Text(
                    'Claimants in this category:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: cat.personAmounts.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${entry.key}: ',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(entry.value),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Itemized category expenses
                  Text(
                    'Itemized Expenses (${cat.expenses.length}):',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...cat.expenses.map((e) {
                    return InkWell(
                      onTap: () => context.push(RoutePaths.expenseDetail(e.id)),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getCategoryIcon(e.categoryName),
                              size: 16,
                              color: const Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.note.isNotEmpty ? e.note : e.projectName,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${e.employeeName} • ${DateFormatter.formatShort(e.date)} • ${e.hasReceipt ? "🟢 Receipt" : "🔴 No Receipt"}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              CurrencyFormatter.format(e.amount),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. Projects Tab: Minimal container with dropdown expansion
  Widget _buildProjectsTab({
    required List<_ProjectCostSummary> projectSummaries,
    required bool isDark,
  }) {
    if (projectSummaries.isEmpty) {
      return Center(
        child: Text(
          'No project records found.',
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: projectSummaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final pSummary = projectSummaries[i];
        final p = pSummary.project;
        final isExpanded = _expandedProjectIds.contains(p.id);
        final pMargin = p.grossProjectValue > 0
            ? ((p.grossProjectValue - pSummary.totalIncurred) / p.grossProjectValue) * 100
            : 0.0;
        final budgetRatio = p.budget > 0 ? (pSummary.totalIncurred / p.budget) : 0.0;

        return InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedProjectIds.remove(p.id);
              } else {
                _expandedProjectIds.add(p.id);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isExpanded
                    ? const Color(0xFF4F46E5).withAlpha(120)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isExpanded ? 1.5 : 1,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal Header (Always visible)
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.folder_special_rounded, size: 20, color: Color(0xFF4F46E5)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Client: ${p.client}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(pSummary.totalIncurred),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4F46E5),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: pMargin >= 0
                                ? (isDark ? const Color(0xFF064E3B).withAlpha(40) : const Color(0xFFECFDF5))
                                : (isDark ? const Color(0xFF7F1D1D).withAlpha(40) : const Color(0xFFFEF2F2)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pMargin.toStringAsFixed(0)}% Margin',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: pMargin >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isExpanded ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),

                // Expanded Section
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Budget Utilization Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: budgetRatio.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation(
                        budgetRatio > 1.0
                            ? const Color(0xFFEF4444)
                            : (budgetRatio > 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF4F46E5)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Financial Key Metrics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Incurred: ${CurrencyFormatter.format(pSummary.totalIncurred)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Budget: ${CurrencyFormatter.format(p.budget, compact: true)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (pSummary.personAmounts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Personnel Spenders:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: pSummary.personAmounts.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${entry.key}: ${CurrencyFormatter.format(entry.value)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Itemized Project Expenses
                  Text(
                    'Project Expenses (${pSummary.expenses.length}):',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...pSummary.expenses.map((e) {
                    return InkWell(
                      onTap: () => context.push(RoutePaths.expenseDetail(e.id)),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getCategoryIcon(e.categoryName),
                              size: 16,
                              color: const Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.note.isNotEmpty ? e.note : e.categoryName,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${e.employeeName} • ${DateFormatter.formatShort(e.date)} • ${e.hasReceipt ? "🟢 Receipt" : "🔴 No Receipt"}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              CurrencyFormatter.format(e.amount),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // Button to navigate to project details
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(RoutePaths.projectDetail(p.id)),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Open Project Overview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. All Records Tab
  Widget _buildRecordsTab({
    required List<ExpenseModel> filteredExpenses,
    required bool isDark,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by person, category, note...',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredExpenses.isEmpty
              ? Center(
                  child: Text(
                    'No expense records found matching query.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: filteredExpenses.length,
                  itemBuilder: (ctx, i) {
                    final e = filteredExpenses[i];
                    return ExpenseListRow(
                      expense: e,
                      showEmployeeName: true,
                      onTap: () => context.push(RoutePaths.expenseDetail(e.id)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PersonCostSummary {
  final String personId;
  final String personName;
  final String designation;
  final double totalAmount;
  final double unreceiptedAmount;
  final int totalCount;
  final int unreceiptedCount;
  final Map<String, double> categoryAmounts;
  final Set<String> projectNames;
  final List<ExpenseModel> expenses;

  _PersonCostSummary({
    required this.personId,
    required this.personName,
    required this.designation,
    required this.totalAmount,
    required this.unreceiptedAmount,
    required this.totalCount,
    required this.unreceiptedCount,
    required this.categoryAmounts,
    required this.projectNames,
    required this.expenses,
  });

  double get unreceiptedRatio => totalAmount > 0 ? (unreceiptedAmount / totalAmount) * 100 : 0.0;
}

class _CategoryCostSummary {
  final String categoryName;
  final double totalAmount;
  final int count;
  final Map<String, double> personAmounts;
  final List<ExpenseModel> expenses;

  _CategoryCostSummary({
    required this.categoryName,
    required this.totalAmount,
    required this.count,
    required this.personAmounts,
    required this.expenses,
  });
}

class _ProjectCostSummary {
  final ProjectModel project;
  final double totalIncurred;
  final Map<String, double> personAmounts;
  final int expenseCount;
  final List<ExpenseModel> expenses;

  _ProjectCostSummary({
    required this.project,
    required this.totalIncurred,
    required this.personAmounts,
    required this.expenseCount,
    required this.expenses,
  });
}
