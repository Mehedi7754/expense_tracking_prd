import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/user_management_provider.dart';

class PortfolioValueDetailScreen extends ConsumerStatefulWidget {
  const PortfolioValueDetailScreen({super.key});

  @override
  ConsumerState<PortfolioValueDetailScreen> createState() => _PortfolioValueDetailScreenState();
}

class _PortfolioValueDetailScreenState extends ConsumerState<PortfolioValueDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedPersonNames = {};
  final Set<String> _expandedCategoryNames = {};
  final Set<String> _expandedProjectIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final role = user?.role ?? UserRole.projectMember;

    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);
    final allUsers = ref.watch(userManagementProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.preferredCurrency;

    // Filter projects & expenses according to PRD permissions
    final visibleProjects = user == null
        ? <ProjectModel>[]
        : (role.canViewAllProjects
            ? allProjects
            : allProjects.where((p) => p.hasMember(user.id)).toList());

    final approvedExpenses = allExpenses.where((e) => e.status == ExpenseStatus.approved).toList();
    final visibleExpenses = user == null
        ? <ExpenseModel>[]
        : (role.canViewAllProjects
            ? approvedExpenses
            : approvedExpenses
                .where((e) =>
                    e.employeeId == user.id ||
                    visibleProjects.any((p) => p.id == e.projectId))
                .toList());

    final totalContractValue = visibleProjects.fold<double>(
      0.0,
      (sum, p) => sum + (p.grossProjectValue > 0 ? p.grossProjectValue : p.budget),
    );
    final totalCostIncurred = visibleExpenses.fold<double>(0.0, (sum, e) => sum + (e.amount + e.taxAmount));
    final remainingBalance = totalContractValue - totalCostIncurred;
    final spentRatio = totalContractValue > 0
        ? (totalCostIncurred / totalContractValue) * 100
        : 0.0;

    final totalUnreceipted = visibleExpenses
        .where((e) => !e.hasReceipt)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
    final overallUnreceiptedRatio = totalCostIncurred > 0
        ? (totalUnreceipted / totalCostIncurred) * 100
        : 0.0;

    final currentUser = ref.watch(authProvider).currentUser;
    if (currentUser?.role == UserRole.projectMember) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Access Restricted'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(RoutePaths.home),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Company-wide portfolio financials are restricted to executive and finance management.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Total Portfolio Financials',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Executive Hero Financial Banner
                    _buildExecutiveHeroBanner(
                      isDark: isDark,
                      currency: currency,
                      totalContractValue: totalContractValue,
                      totalCostIncurred: totalCostIncurred,
                      remainingBalance: remainingBalance,
                      spentRatio: spentRatio,
                      projectsCount: visibleProjects.length,
                    ),

                    const SizedBox(height: 12),

                    // 2. Unreceipted Risk Banner (if applicable)
                    if (totalUnreceipted > 0)
                      _buildUnreceiptedAlert(
                        isDark: isDark,
                        currency: currency,
                        totalUnreceipted: totalUnreceipted,
                        ratio: overallUnreceiptedRatio,
                      ),

                    const SizedBox(height: 12),

                    // 3. Search Bar
                    _buildSearchBar(isDark: isDark),

                    const SizedBox(height: 14),

                    // 4. Tab Bar Capsule
                    _buildTabBar(isDark: isDark),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: By Team Member
            _buildPersonnelTab(
              isDark: isDark,
              currency: currency,
              expenses: visibleExpenses,
              allUsers: allUsers,
            ),

            // Tab 2: By Category
            _buildCategoryTab(
              isDark: isDark,
              currency: currency,
              expenses: visibleExpenses,
              totalCostIncurred: totalCostIncurred,
            ),

            // Tab 3: By Project
            _buildProjectTab(
              isDark: isDark,
              currency: currency,
              projects: visibleProjects,
              expenses: visibleExpenses,
            ),

            // Tab 4: All Transactions
            _buildAllRecordsTab(
              isDark: isDark,
              currency: currency,
              expenses: visibleExpenses,
              allUsers: allUsers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveHeroBanner({
    required bool isDark,
    required String currency,
    required double totalContractValue,
    required double totalCostIncurred,
    required double remainingBalance,
    required double spentRatio,
    required int projectsCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withAlpha(isDark ? 80 : 50),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'PORTFOLIO VALUE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (spentRatio <= 80
                          ? const Color(0xFF10B981)
                          : (spentRatio <= 100 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)))
                      .withAlpha(45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (spentRatio <= 80
                            ? const Color(0xFF34D399)
                            : (spentRatio <= 100 ? const Color(0xFFFBBF24) : const Color(0xFFF87171)))
                        .withAlpha(80),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      spentRatio <= 100 ? Icons.pie_chart_outline_rounded : Icons.warning_amber_rounded,
                      color: spentRatio <= 80
                          ? const Color(0xFF4ADE80)
                          : (spentRatio <= 100 ? const Color(0xFFFBBF24) : const Color(0xFFF87171)),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${spentRatio.toStringAsFixed(1)}% Used',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: spentRatio <= 80
                            ? const Color(0xFF4ADE80)
                            : (spentRatio <= 100 ? const Color(0xFFFBBF24) : const Color(0xFFF87171)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(totalContractValue, currency: currency),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 18),
          // 3 Frosted Mini Stats (No text cutoffs)
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildHeroStatItem(
                    icon: Icons.payments_outlined,
                    label: 'Spent',
                    value: CurrencyFormatter.format(totalCostIncurred, currency: currency, compact: true),
                    iconColor: const Color(0xFFF87171),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHeroStatItem(
                    icon: Icons.savings_outlined,
                    label: 'Remaining',
                    value: CurrencyFormatter.format(remainingBalance, currency: currency, compact: true),
                    iconColor: const Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHeroStatItem(
                    icon: Icons.folder_special_outlined,
                    label: 'Active',
                    value: '$projectsCount Active',
                    iconColor: const Color(0xFF60A5FA),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(25), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreceiptedAlert({
    required bool isDark,
    required String currency,
    required double totalUnreceipted,
    required double ratio,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03).withAlpha(80) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFB45309).withAlpha(80) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unreceipted Claims Notice',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyFormatter.format(totalUnreceipted, currency: currency)} (${ratio.toStringAsFixed(1)}% of expenses) requires paper or digital verification.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search members, categories, or projects...',
          hintStyle: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
          prefixIcon: Icon(CupertinoIcons.search, size: 17, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTabBar({required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF312E81) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        labelColor: isDark ? Colors.white : const Color(0xFF4F46E5),
        unselectedLabelColor: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Members'),
          Tab(text: 'Category'),
          Tab(text: 'Projects'),
          Tab(text: 'Claims'),
        ],
      ),
    );
  }

  // ==================== TAB 1: BY TEAM MEMBER ====================
  Widget _buildPersonnelTab({
    required bool isDark,
    required String currency,
    required List<ExpenseModel> expenses,
    required List<UserModel> allUsers,
  }) {
    final Map<String, List<ExpenseModel>> groupedByPerson = {};
    for (final e in expenses) {
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

      UserModel? matchedUser;
      for (final u in allUsers) {
        if (u.id == pId || u.name.toLowerCase() == name.toLowerCase()) {
          matchedUser = u;
          break;
        }
      }
      final designation = matchedUser?.designation ?? (matchedUser?.role.displayName ?? 'Team Member');
      final avatarUrl = matchedUser?.avatarUrl ?? pExpenses.first.employeeAvatar;

      personSummaries.add(_PersonCostSummary(
        personId: pId,
        personName: name,
        designation: designation,
        avatarUrl: avatarUrl,
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

    final filtered = _searchQuery.isEmpty
        ? personSummaries
        : personSummaries
            .where((p) =>
                p.personName.toLowerCase().contains(_searchQuery) ||
                p.designation.toLowerCase().contains(_searchQuery) ||
                p.projectNames.any((pn) => pn.toLowerCase().contains(_searchQuery)))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyList(isDark, 'No matching team members found');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final p = filtered[i];
        final isExpanded = _expandedPersonNames.contains(p.personName);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 15 : 5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedPersonNames.remove(p.personName);
                    } else {
                      _expandedPersonNames.add(p.personName);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: p.avatarUrl,
                        name: p.personName,
                        size: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.personName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: -0.2),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.designation,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.totalCount} claims • ${p.projectNames.length} projects',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(p.totalAmount, currency: currency),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          if (p.unreceiptedAmount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${p.unreceiptedRatio.toStringAsFixed(0)}% Unreceipted',
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Claim Breakdown
              if (isExpanded) ...[
                Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category Breakdown',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: p.categoryAmounts.entries.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${c.key}: ${CurrencyFormatter.format(c.value, currency: currency, compact: true)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      ...p.expenses.take(5).map((e) {
                        return InkWell(
                          onTap: () => context.push('/expenses/${e.id}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(e.categoryName), size: 14, color: const Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.note.isEmpty ? e.categoryName : e.note,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(e.amount, currency: currency),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (p.expenses.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+ ${p.expenses.length - 5} more claims',
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==================== TAB 2: BY CATEGORY ====================
  Widget _buildCategoryTab({
    required bool isDark,
    required String currency,
    required List<ExpenseModel> expenses,
    required double totalCostIncurred,
  }) {
    final Map<String, List<ExpenseModel>> groupedByCat = {};
    for (final e in expenses) {
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

    final filtered = _searchQuery.isEmpty
        ? categorySummaries
        : categorySummaries
            .where((c) => c.categoryName.toLowerCase().contains(_searchQuery))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyList(isDark, 'No categories matching search');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final c = filtered[i];
        final percentOfTotal = totalCostIncurred > 0 ? (c.totalAmount / totalCostIncurred) * 100 : 0.0;
        final isExpanded = _expandedCategoryNames.contains(c.categoryName);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 15 : 5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCategoryNames.remove(c.categoryName);
                    } else {
                      _expandedCategoryNames.add(c.categoryName);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withAlpha(isDark ? 35 : 15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_getCategoryIcon(c.categoryName), color: const Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.categoryName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${c.count} claims • ${percentOfTotal.toStringAsFixed(1)}% of total cost',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(c.totalAmount, currency: currency),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Claimants for this category',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      ...c.personAmounts.entries.map((p) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(CurrencyFormatter.format(p.value, currency: currency), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==================== TAB 3: BY PROJECT ====================
  Widget _buildProjectTab({
    required bool isDark,
    required String currency,
    required List<ProjectModel> projects,
    required List<ExpenseModel> expenses,
  }) {
    final List<_ProjectCostSummary> projectSummaries = [];
    for (final p in projects) {
      final pExp = expenses.where((e) => e.projectId == p.id).toList();
      final totalIncurred = pExp.fold<double>(0.0, (sum, e) => sum + (e.amount + e.taxAmount));
      final Map<String, double> pAmounts = {};
      for (final e in pExp) {
        pAmounts[e.employeeName] = (pAmounts[e.employeeName] ?? 0.0) + (e.amount + e.taxAmount);
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

    final filtered = _searchQuery.isEmpty
        ? projectSummaries
        : projectSummaries
            .where((p) =>
                p.project.name.toLowerCase().contains(_searchQuery) ||
                p.project.projectId.toLowerCase().contains(_searchQuery))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyList(isDark, 'No projects matching search');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final p = filtered[i];
        final budget = p.project.grossProjectValue > 0 ? p.project.grossProjectValue : p.project.budget;
        final incurred = p.totalIncurred;
        final remaining = budget - incurred;
        final burnRate = budget > 0 ? (incurred / budget) : 0.0;
        final isExpanded = _expandedProjectIds.contains(p.project.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 15 : 5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedProjectIds.remove(p.project.id);
                    } else {
                      _expandedProjectIds.add(p.project.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.project.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${p.project.projectId} • ${p.expenseCount} claims',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(incurred, currency: currency),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                              Text(
                                'Budget: ${CurrencyFormatter.format(budget, currency: currency, compact: true)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                'Remaining: ${CurrencyFormatter.format(remaining, currency: currency, compact: true)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: remaining >= 0
                                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (burnRate.clamp(0.0, 1.0)),
                          minHeight: 5,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            burnRate > 1.0
                                ? const Color(0xFFEF4444)
                                : burnRate > 0.85
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Team Contributors',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      ...p.personAmounts.entries.map((c) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(CurrencyFormatter.format(c.value, currency: currency), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => context.push(RoutePaths.projectDetail(p.project.id)),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: const Text('Open Project Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==================== TAB 4: ALL TRANSACTIONS ====================
  Widget _buildAllRecordsTab({
    required bool isDark,
    required String currency,
    required List<ExpenseModel> expenses,
    required List<UserModel> allUsers,
  }) {
    final filtered = _searchQuery.isEmpty
        ? expenses
        : expenses
            .where((e) =>
                e.employeeName.toLowerCase().contains(_searchQuery) ||
                e.projectName.toLowerCase().contains(_searchQuery) ||
                e.categoryName.toLowerCase().contains(_searchQuery) ||
                e.note.toLowerCase().contains(_searchQuery))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyList(isDark, 'No claims matching query');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final e = filtered[i];
        final avatar = (e.employeeAvatar != null && e.employeeAvatar!.isNotEmpty)
            ? e.employeeAvatar
            : allUsers.where((u) => u.id == e.employeeId || u.name.toLowerCase() == e.employeeName.toLowerCase()).firstOrNull?.avatarUrl;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => context.push('/expenses/${e.id}'),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    AppAvatar(
                      imageUrl: avatar,
                      name: e.employeeName,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.employeeName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${e.categoryName} • ${e.projectName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                DateFormatter.formatShort(e.date),
                                style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(width: 8),
                              StatusChip.fromExpenseStatus(e.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(e.amount, currency: currency),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: e.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              e.hasReceipt ? 'Receipt' : 'No Receipt',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: e.hasReceipt ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyList(bool isDark, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCostSummary {
  final String personId;
  final String personName;
  final String designation;
  final String? avatarUrl;
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
    this.avatarUrl,
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
