import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';

class DetailedFinancialRecord {
  final String id;
  final String title;
  final String projectName;
  final String category;
  final double amount;
  final DateTime date;
  final bool isRevenue;
  final String status;
  final String? submitterOrClient;
  final String? expenseId;

  DetailedFinancialRecord({
    required this.id,
    required this.title,
    required this.projectName,
    required this.category,
    required this.amount,
    required this.date,
    required this.isRevenue,
    required this.status,
    this.submitterOrClient,
    this.expenseId,
  });
}

class MonthlyEarningsDetailScreen extends ConsumerStatefulWidget {
  const MonthlyEarningsDetailScreen({super.key});

  @override
  ConsumerState<MonthlyEarningsDetailScreen> createState() => _MonthlyEarningsDetailScreenState();
}

class _MonthlyEarningsDetailScreenState extends ConsumerState<MonthlyEarningsDetailScreen> {
  String _selectedPeriod = 'This Month';
  String _recordTypeFilter = 'all'; // 'all', 'revenue', 'expense'
  String _searchQuery = '';
  int? _selectedDayIndex;
  DateTime? _selectedSingleDate;
  DateTimeRange? _customDateRange;

  final TextEditingController _searchController = TextEditingController();

  Future<void> _pickCalendarDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSingleDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Specific Day for Cashflow Breakdown',
    );
    if (picked != null) {
      setState(() {
        _selectedSingleDate = picked;
        _selectedPeriod = 'Custom Date';
        _selectedDayIndex = null;
      });
    }
  }

  Future<void> _pickCalendarDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Date Range for Financial Analysis',
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedSingleDate = null;
        _selectedPeriod = 'Custom Range';
        _selectedDayIndex = null;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final settings = ref.watch(settingsProvider);
    final currency = settings.preferredCurrency;

    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final role = user?.role ?? UserRole.projectMember;

    final allProjects = ref.watch(projectProvider);
    final allExpenses = ref.watch(expenseProvider);

    final visibleProjects = user == null
        ? <ProjectModel>[]
        : (role.canViewAllProjects
            ? allProjects
            : allProjects.where((p) => p.hasMember(user.id)).toList());
    final visibleProjectIds = visibleProjects.map((p) => p.id).toSet();

    final visibleExpenses = user == null
        ? <ExpenseModel>[]
        : (role.canViewAllProjects
            ? allExpenses
            : allExpenses.where((e) => e.employeeId == user.id || visibleProjectIds.contains(e.projectId)).toList());

    final projectMap = {for (var p in visibleProjects) p.id: p};

    // Calculate Date Range Bounds
    final now = DateTime.now();
    DateTime rangeStart;
    DateTime rangeEnd = now;

    if (_selectedSingleDate != null) {
      rangeStart = DateTime(_selectedSingleDate!.year, _selectedSingleDate!.month, _selectedSingleDate!.day);
      rangeEnd = DateTime(_selectedSingleDate!.year, _selectedSingleDate!.month, _selectedSingleDate!.day, 23, 59, 59);
    } else if (_customDateRange != null) {
      rangeStart = _customDateRange!.start;
      rangeEnd = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
    } else if (_selectedPeriod == 'Last Month') {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      rangeStart = prevMonth;
      rangeEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else if (_selectedPeriod == 'This Quarter') {
      final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
      rangeStart = DateTime(now.year, quarterStartMonth, 1);
    } else if (_selectedPeriod == 'This Year') {
      rangeStart = DateTime(now.year, 1, 1);
    } else {
      // Default: This Month
      rangeStart = DateTime(now.year, now.month, 1);
    }

    // Build Financial Records Pool (Revenues + Incurred Expenses)
    final List<DetailedFinancialRecord> rawRecords = [];

    // 1. Project Revenues / Income (Using expected net revenue as total value after tax)
    for (final project in visibleProjects) {
      if (project.expectedNetRevenue > 0) {
        final revDate = project.startDate;
        if (revDate.isAfter(rangeStart.subtract(const Duration(seconds: 1))) &&
            revDate.isBefore(rangeEnd.add(const Duration(days: 1)))) {
          rawRecords.add(DetailedFinancialRecord(
            id: 'proj_net_rev_${project.id}',
            title: 'Net Project Value (After Tax)',
            projectName: project.name,
            category: 'Project Revenue',
            amount: project.expectedNetRevenue,
            date: revDate,
            isRevenue: true,
            status: 'Active',
            submitterOrClient: project.client,
          ));
        }
      }
    }

    // 2. Expenses Incurred
    for (final exp in visibleExpenses) {
      final expDate = exp.date;
      if (expDate.isAfter(rangeStart.subtract(const Duration(seconds: 1))) &&
          expDate.isBefore(rangeEnd.add(const Duration(days: 1)))) {
        final project = projectMap[exp.projectId];
        rawRecords.add(DetailedFinancialRecord(
          id: exp.id,
          title: exp.note.isNotEmpty ? exp.note : exp.categoryName,
          projectName: exp.projectName.isNotEmpty ? exp.projectName : (project?.name ?? 'General Expense'),
          category: exp.categoryName,
          amount: exp.amount,
          date: expDate,
          isRevenue: false,
          status: exp.status.displayName,
          submitterOrClient: exp.employeeName,
          expenseId: exp.id,
        ));
      }
    }

    // Sort Records Chronologically (Newest first)
    rawRecords.sort((a, b) => b.date.compareTo(a.date));

    // Calculate Summary Stats for selected date range
    final totalIncome = rawRecords.where((r) => r.isRevenue).fold<double>(0.0, (sum, r) => sum + r.amount);
    final totalExpense = rawRecords.where((r) => !r.isRevenue).fold<double>(0.0, (sum, r) => sum + r.amount);
    final netMargin = totalIncome - totalExpense;
    final marginPercentage = totalIncome > 0 ? (netMargin / totalIncome) * 100 : 0.0;

    // Filter Records by Type & Search Query
    final filteredRecords = rawRecords.where((r) {
      if (_recordTypeFilter == 'revenue' && !r.isRevenue) return false;
      if (_recordTypeFilter == 'expense' && r.isRevenue) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = r.title.toLowerCase().contains(q);
        final matchesProject = r.projectName.toLowerCase().contains(q);
        final matchesCategory = r.category.toLowerCase().contains(q);
        final matchesPerson = r.submitterOrClient?.toLowerCase().contains(q) ?? false;
        if (!matchesTitle && !matchesProject && !matchesCategory && !matchesPerson) return false;
      }
      return true;
    }).toList();

    // Generate Day-by-Day Aggregation for Timeline Chart
    final daysInPeriod = rangeEnd.difference(rangeStart).inDays + 1;
    final chartDaysCount = daysInPeriod > 31 ? 30 : (daysInPeriod <= 0 ? 1 : daysInPeriod);

    final List<DateTime> dayDates = List.generate(
      chartDaysCount,
      (i) => rangeStart.add(Duration(days: i)),
    );

    final Map<int, double> dailyIncomeMap = {};
    final Map<int, double> dailyExpenseMap = {};

    for (final record in rawRecords) {
      final dayDiff = record.date.difference(rangeStart).inDays;
      if (dayDiff >= 0 && dayDiff < chartDaysCount) {
        if (record.isRevenue) {
          dailyIncomeMap[dayDiff] = (dailyIncomeMap[dayDiff] ?? 0.0) + record.amount;
        } else {
          dailyExpenseMap[dayDiff] = (dailyExpenseMap[dayDiff] ?? 0.0) + record.amount;
        }
      }
    }

    double maxDailyVal = 100.0;
    for (int i = 0; i < chartDaysCount; i++) {
      final inc = dailyIncomeMap[i] ?? 0.0;
      final exp = dailyExpenseMap[i] ?? 0.0;
      if (inc > maxDailyVal) maxDailyVal = inc;
      if (exp > maxDailyVal) maxDailyVal = exp;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 18),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Text(
          'Earnings Breakdown',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF4F46E5), size: 22),
            tooltip: 'Filter by Calendar Date',
            onPressed: () => _pickCalendarDate(context),
          ),
          // Period selector dropdown chip
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withAlpha(60)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4F46E5), size: 18),
                isDense: true,
                style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700, fontSize: 12),
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                onChanged: (val) {
                  if (val != null) {
                    if (val == 'Custom Date') {
                      _pickCalendarDate(context);
                    } else if (val == 'Custom Range') {
                      _pickCalendarDateRange(context);
                    } else {
                      setState(() {
                        _selectedPeriod = val;
                        _selectedSingleDate = null;
                        _customDateRange = null;
                        _selectedDayIndex = null;
                      });
                    }
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                  DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
                  DropdownMenuItem(value: 'This Quarter', child: Text('This Quarter')),
                  DropdownMenuItem(value: 'This Year', child: Text('This Year')),
                  DropdownMenuItem(value: 'Custom Date', child: Text('Pick Date 📅')),
                  DropdownMenuItem(value: 'Custom Range', child: Text('Date Range 🗓️')),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32, top: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. High-Level Summary Metrics Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return isMobile
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricCard(
                                        title: 'Total Revenues',
                                        amount: totalIncome,
                                        currency: currency,
                                        icon: Icons.south_west_rounded,
                                        color: const Color(0xFF10B981),
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildMetricCard(
                                        title: 'Incurred Costs',
                                        amount: totalExpense,
                                        currency: currency,
                                        icon: Icons.north_east_rounded,
                                        color: const Color(0xFFEF4444),
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildMetricCard(
                                  title: 'Net Cash Margin',
                                  amount: netMargin,
                                  currency: currency,
                                  subtitle: '${marginPercentage >= 0 ? '+' : ''}${marginPercentage.toStringAsFixed(1)}% margin',
                                  icon: Icons.account_balance_wallet_outlined,
                                  color: const Color(0xFF4F46E5),
                                  isDark: isDark,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Total Revenues',
                                    amount: totalIncome,
                                    currency: currency,
                                    icon: Icons.south_west_rounded,
                                    color: const Color(0xFF10B981),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Incurred Costs',
                                    amount: totalExpense,
                                    currency: currency,
                                    icon: Icons.north_east_rounded,
                                    color: const Color(0xFFEF4444),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Net Margin',
                                    amount: netMargin,
                                    currency: currency,
                                    subtitle: '${marginPercentage >= 0 ? '+' : ''}${marginPercentage.toStringAsFixed(1)}% ratio',
                                    icon: Icons.account_balance_wallet_outlined,
                                    color: const Color(0xFF4F46E5),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                ),

                if (_selectedSingleDate != null || _customDateRange != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(isDark ? 30 : 15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6366F1).withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available_rounded, color: Color(0xFF4F46E5), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _selectedSingleDate != null
                                  ? 'Active Date: ${DateFormatter.formatShort(_selectedSingleDate!)}'
                                  : 'Active Range: ${DateFormatter.formatShort(_customDateRange!.start)} - ${DateFormatter.formatShort(_customDateRange!.end)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedSingleDate = null;
                              _customDateRange = null;
                              _selectedPeriod = 'This Month';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.close_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Reset',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // 2. Day-by-Day Income vs Expense Timeline Chart
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 30 : 6),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Day-by-Day Cashflow Timeline',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormatter.formatShort(rangeStart)} - ${DateFormatter.formatShort(rangeEnd)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Legend
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLegendDot('Income', const Color(0xFF10B981), isDark),
                              const SizedBox(width: 8),
                              _buildLegendDot('Expense', const Color(0xFFEF4444), isDark),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Chart Bar Graphics Container
                      SizedBox(
                        height: 140,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final barWidth = (constraints.maxWidth / chartDaysCount) - 4;
                            final clampedBarWidth = barWidth.clamp(4.0, 24.0);

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(chartDaysCount, (idx) {
                                  final dayDate = dayDates[idx];
                                  final inc = dailyIncomeMap[idx] ?? 0.0;
                                  final exp = dailyExpenseMap[idx] ?? 0.0;

                                  final incHeight = maxDailyVal > 0 ? (inc / maxDailyVal) * 110 : 0.0;
                                  final expHeight = maxDailyVal > 0 ? (exp / maxDailyVal) * 110 : 0.0;

                                  final isSelected = _selectedDayIndex == idx;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedDayIndex = _selectedDayIndex == idx ? null : idx;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: isSelected
                                          ? BoxDecoration(
                                              color: const Color(0xFF6366F1).withAlpha(20),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF6366F1), width: 1),
                                            )
                                          : null,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              // Income Bar
                                              Container(
                                                width: clampedBarWidth / 2,
                                                height: incHeight.clamp(4.0, 110.0),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF10B981),
                                                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                                ),
                                              ),
                                              const SizedBox(width: 1),
                                              // Expense Bar
                                              Container(
                                                width: clampedBarWidth / 2,
                                                height: expHeight.clamp(4.0, 110.0),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFEF4444),
                                                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${dayDate.day}',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                                              color: isSelected
                                                  ? const Color(0xFF4F46E5)
                                                  : (isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Search & Segment Filters Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Search field
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Search transactions by project, title, category...',
                          hintStyle: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8)),
                          prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8), size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Segment Filter Pills
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    label: 'All Records (${rawRecords.length})',
                                    isSelected: _recordTypeFilter == 'all',
                                    onTap: () => setState(() => _recordTypeFilter = 'all'),
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    label: 'Revenues Only (${rawRecords.where((r) => r.isRevenue).length})',
                                    isSelected: _recordTypeFilter == 'revenue',
                                    onTap: () => setState(() => _recordTypeFilter = 'revenue'),
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    label: 'Expenses Only (${rawRecords.where((r) => !r.isRevenue).length})',
                                    isSelected: _recordTypeFilter == 'expense',
                                    onTap: () => setState(() => _recordTypeFilter = 'expense'),
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Itemized Transaction Record List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Itemized Records (${filteredRecords.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Sorted by Date',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                if (filteredRecords.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 42, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFCBD5E1)),
                        const SizedBox(height: 10),
                        Text(
                          'No financial records found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try changing the period filter or search term.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredRecords.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final record = filteredRecords[idx];
                      return _buildRecordRow(context, record, currency, isDark);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required String currency,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(isDark ? 40 : 20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(amount, currency: currency, compact: amount >= 100000),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordRow(
    BuildContext context,
    DetailedFinancialRecord record,
    String currency,
    bool isDark,
  ) {
    final isRev = record.isRevenue;
    final color = isRev ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: () {
        if (record.expenseId != null) {
          context.push(RoutePaths.expenseDetail(record.expenseId!));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 15 : 4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 35 : 15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isRev ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        record.projectName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      if (record.submitterOrClient != null) ...[
                        const Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Expanded(
                          child: Text(
                            record.submitterOrClient!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Amount & Status Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isRev ? '+' : '-'}${CurrencyFormatter.format(record.amount, currency: currency)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    DateFormatter.formatShort(record.date),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
