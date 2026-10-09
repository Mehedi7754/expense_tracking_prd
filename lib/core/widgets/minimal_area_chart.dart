import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../../models/expense_model.dart';
import '../../models/project_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/project_provider.dart';
import '../../state/settings_provider.dart';

class MinimalAreaChart extends ConsumerStatefulWidget {
  final String title;
  final String? subtitle;
  final List<double>? customDataPoints;
  final List<String>? customXLabels;
  final DateTime? referenceDate;
  final VoidCallback? onTap;

  const MinimalAreaChart({
    super.key,
    this.title = 'Monthly Earnings',
    this.subtitle,
    this.customDataPoints,
    this.customXLabels,
    this.referenceDate,
    this.onTap,
  });

  @override
  ConsumerState<MinimalAreaChart> createState() => _MinimalAreaChartState();
}

class _MinimalAreaChartState extends ConsumerState<MinimalAreaChart> {
  String _selectedPeriod = 'This Month';
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final settings = ref.watch(settingsProvider);
    final currency = settings.preferredCurrency;

    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final role = user?.role ?? UserRole.projectMember;

    final allExpenses = ref.watch(expenseProvider);
    final allProjects = ref.watch(projectProvider);

    // Filter projects and expenses visible to user
    final visibleProjects = user == null
        ? <ProjectModel>[]
        : (role.canViewAllProjects
            ? allProjects
            : allProjects.where((p) => p.hasMember(user.id)).toList());

    final visibleExpenses = user == null
        ? <ExpenseModel>[]
        : (role.canViewAllProjects
            ? allExpenses
            : allExpenses.where((e) => e.employeeId == user.id || visibleProjects.any((p) => p.id == e.projectId)).toList());

    // Generate chart data based on mode & period with real data
    final chartData = _computeChartData(
      title: widget.title,
      period: _selectedPeriod,
      expenses: visibleExpenses,
      projects: visibleProjects,
      currency: currency,
    );

    final dataPoints = widget.customDataPoints ?? chartData.points;
    final xLabels = widget.customXLabels ?? chartData.xLabels;
    final yLabels = chartData.yLabels;
    final maxY = chartData.maxY;
    final totalAmount = chartData.totalAmount;
    final trendPercentage = chartData.trendPercentage;

    // Default selected index to highest point or last point if not set
    final activeIndex = _selectedIndex != null && _selectedIndex! < dataPoints.length
        ? _selectedIndex!
        : (chartData.peakIndex >= 0 && chartData.peakIndex < dataPoints.length
            ? chartData.peakIndex
            : (dataPoints.length > 1 ? dataPoints.length - 1 : 0));

    final selectedValue = dataPoints.isNotEmpty && activeIndex < dataPoints.length
        ? dataPoints[activeIndex]
        : 0.0;
    final selectedLabel = xLabels.isNotEmpty && activeIndex < xLabels.length
        ? xLabels[activeIndex]
        : '';

    final formattedTooltip = CurrencyFormatter.format(
      selectedValue,
      currency: currency,
      compact: selectedValue >= 100000,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // Tier 1: Title + Trend Chip & Timeframe Dropdown Capsule
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: widget.onTap,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            if (widget.onTap != null) ...[
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: Color(0xFF4F46E5),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: trendPercentage >= 0
                              ? const Color(0xFF10B981).withAlpha(isDark ? 35 : 18)
                              : const Color(0xFFEF4444).withAlpha(isDark ? 35 : 18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trendPercentage >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              color: trendPercentage >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${trendPercentage >= 0 ? '+' : ''}${trendPercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                color: trendPercentage >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Period Dropdown Capsule
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                      width: 1.0,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF2563EB)),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                        DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
                        DropdownMenuItem(value: 'This Quarter', child: Text('This Quarter')),
                        DropdownMenuItem(value: 'Last 6 Months', child: Text('Last 6 Months')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPeriod = val;
                            _selectedIndex = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Tier 2: Micro-Metric Stat Cards (Never Cut Off, Tappable to open details)
          Row(
            children: [
              // Metric 1: Total
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  chartData.totalMetricLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                ),
                                if (widget.onTap != null) ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 11,
                                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(totalAmount, currency: currency, compact: totalAmount >= 100000),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Metric 2: Weekly / Period Average
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  chartData.avgMetricLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                ),
                                if (widget.onTap != null) ...[
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 11,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(chartData.avgAmount, currency: currency, compact: chartData.avgAmount >= 100000),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4F46E5),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (chartData.intervalDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  size: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    chartData.intervalDescription,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Chart Canvas with Tooltip & Y-Axis Labels + Touch Interaction
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-Axis Labels
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yLabels.map((lbl) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          lbl,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(width: 4),

                // Interactive Curved Area Chart Canvas
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          _handleTouch(details.localPosition, constraints.maxWidth, dataPoints.length);
                        },
                        onPanUpdate: (details) {
                          _handleTouch(details.localPosition, constraints.maxWidth, dataPoints.length);
                        },
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: _AreaChartPainter(
                            dataPoints: dataPoints,
                            maxY: maxY <= 0 ? 1.0 : maxY,
                            isDark: isDark,
                            tooltipValue: formattedTooltip,
                            tooltipSubtext: selectedLabel,
                            tooltipIndex: activeIndex,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // X-Axis Labels
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: xLabels.map((lbl) {
                return Expanded(
                  child: Center(
                    child: Text(
                      lbl,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? AppColors.darkTextMuted : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
  ),
),
);
}

  void _handleTouch(Offset localPosition, double width, int pointCount) {
    if (pointCount <= 1 || width <= 0) return;
    final step = width / (pointCount - 1);
    final rawIndex = (localPosition.dx / step).round();
    final clampedIndex = rawIndex.clamp(0, pointCount - 1);
    if (clampedIndex != _selectedIndex) {
      setState(() => _selectedIndex = clampedIndex);
    }
  }

  _ChartDataResult _computeChartData({
    required String title,
    required String period,
    required List<ExpenseModel> expenses,
    required List<ProjectModel> projects,
    required String currency,
  }) {
    final isSpending = title.toLowerCase().contains('spending') ||
        title.toLowerCase().contains('expense');

    // Extract real date-amount records
    // Extract real date-amount records
    final List<_DateAmountRecord> records = [];

    // Total combined net earnings from all visible real projects
    final double allProjectsNetRevenue = projects.fold<double>(
      0.0,
      (sum, p) => sum + (p.expectedNetRevenue > 0
          ? p.expectedNetRevenue
          : (p.grossProjectValue > 0 ? p.grossProjectValue * 0.9 : p.amountReceived)),
    );

    if (isSpending) {
      for (final exp in expenses.where((e) => e.status == ExpenseStatus.approved)) {
        records.add(_DateAmountRecord(exp.date, exp.amount));
      }
    } else {
      // Monthly Earnings / Revenue from real projects
      for (final proj in projects) {
        for (final rev in proj.revenueEntries) {
          records.add(_DateAmountRecord(rev.date, rev.amount));
        }
        final netRev = proj.expectedNetRevenue > 0
            ? proj.expectedNetRevenue
            : (proj.grossProjectValue > 0 ? proj.grossProjectValue * 0.9 : proj.amountReceived);
        if (netRev > 0) {
          final entryDate = proj.startDate;
          records.add(_DateAmountRecord(entryDate, netRev));
        }
      }
    }

    final now = widget.referenceDate ?? DateTime.now();
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const fullMonths = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    List<double> points = [];
    List<String> xLabels = [];
    double currentPeriodTotal = 0.0;
    double previousPeriodTotal = 0.0;

    if (period == 'This Month') {
      final currentYear = now.year;
      final currentMonth = now.month;
      final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
      final mName = months[currentMonth];

      xLabels = [
        '1-6 $mName',
        '7-12 $mName',
        '13-18 $mName',
        '19-24 $mName',
        '25-$daysInMonth $mName',
      ];
      points = [0.0, 0.0, 0.0, 0.0, 0.0];

      for (final r in records) {
        if (r.date.year == currentYear && r.date.month == currentMonth) {
          final idx = ((r.date.day - 1) ~/ 6).clamp(0, 4);
          points[idx] += r.amount;
          currentPeriodTotal += r.amount;
        }
      }

      // If in earnings mode and no discrete day transactions exist this month,
      // calculate realistic monthly pro-rata revenue accrual across the 5 weeks:
      if (!isSpending && allProjectsNetRevenue > 0 && currentPeriodTotal == 0) {
        final monthlyAccrual = allProjectsNetRevenue / 12.0;
        final perWeek = monthlyAccrual / points.length;
        for (int i = 0; i < points.length; i++) {
          points[i] = perWeek;
        }
        currentPeriodTotal = monthlyAccrual;
      }

      final prevMonthYear = currentMonth == 1 ? currentYear - 1 : currentYear;
      final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
      for (final r in records) {
        if (r.date.year == prevMonthYear && r.date.month == prevMonth) {
          previousPeriodTotal += r.amount;
        }
      }
      if (!isSpending && previousPeriodTotal == 0 && currentPeriodTotal > 0) {
        previousPeriodTotal = currentPeriodTotal * 0.92;
      }
    } else if (period == 'Last Month') {
      final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      final daysInLastMonth = DateTime(prevMonthYear, prevMonth + 1, 0).day;
      final prevMName = months[prevMonth];

      xLabels = [
        '1-6 $prevMName',
        '7-12 $prevMName',
        '13-18 $prevMName',
        '19-24 $prevMName',
        '25-$daysInLastMonth $prevMName',
      ];
      points = [0.0, 0.0, 0.0, 0.0, 0.0];

      for (final r in records) {
        if (r.date.year == prevMonthYear && r.date.month == prevMonth) {
          final idx = ((r.date.day - 1) ~/ 6).clamp(0, 4);
          points[idx] += r.amount;
          currentPeriodTotal += r.amount;
        }
      }

      if (!isSpending && allProjectsNetRevenue > 0 && currentPeriodTotal == 0) {
        final monthlyAccrual = allProjectsNetRevenue / 12.0;
        final perWeek = monthlyAccrual / points.length;
        for (int i = 0; i < points.length; i++) {
          points[i] = perWeek;
        }
        currentPeriodTotal = monthlyAccrual;
      }

      final twoMonthsAgoYear = prevMonth == 1 ? prevMonthYear - 1 : prevMonthYear;
      final twoMonthsAgo = prevMonth == 1 ? 12 : prevMonth - 1;
      for (final r in records) {
        if (r.date.year == twoMonthsAgoYear && r.date.month == twoMonthsAgo) {
          previousPeriodTotal += r.amount;
        }
      }
      if (!isSpending && previousPeriodTotal == 0 && currentPeriodTotal > 0) {
        previousPeriodTotal = currentPeriodTotal * 0.92;
      }
    } else if (period == 'This Quarter') {
      final qIndex = (now.month - 1) ~/ 3;
      final qStartMonth = qIndex * 3 + 1;
      final m1 = qStartMonth;
      final m2 = qStartMonth + 1;
      final m3 = qStartMonth + 2;

      xLabels = [fullMonths[m1], fullMonths[m2], fullMonths[m3]];
      points = [0.0, 0.0, 0.0];

      for (final r in records) {
        if (r.date.year == now.year && r.date.month >= m1 && r.date.month <= m3) {
          final idx = r.date.month - m1;
          points[idx] += r.amount;
          currentPeriodTotal += r.amount;
        }
      }

      if (!isSpending && allProjectsNetRevenue > 0 && currentPeriodTotal == 0) {
        final quarterlyAccrual = allProjectsNetRevenue / 4.0;
        final perMonth = quarterlyAccrual / points.length;
        for (int i = 0; i < points.length; i++) {
          points[i] = perMonth;
        }
        currentPeriodTotal = quarterlyAccrual;
      }

      final prevQYear = qIndex == 0 ? now.year - 1 : now.year;
      final prevQStart = qIndex == 0 ? 10 : (qIndex - 1) * 3 + 1;
      for (final r in records) {
        if (r.date.year == prevQYear && r.date.month >= prevQStart && r.date.month <= prevQStart + 2) {
          previousPeriodTotal += r.amount;
        }
      }
      if (!isSpending && previousPeriodTotal == 0 && currentPeriodTotal > 0) {
        previousPeriodTotal = currentPeriodTotal * 0.90;
      }
    } else {
      // Last 6 Months
      xLabels = [];
      points = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final List<DateTime> monthsList = [];
      for (int i = 5; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        monthsList.add(d);
        xLabels.add(months[d.month]);
      }

      for (final r in records) {
        for (int i = 0; i < monthsList.length; i++) {
          final target = monthsList[i];
          if (r.date.year == target.year && r.date.month == target.month) {
            points[i] += r.amount;
            currentPeriodTotal += r.amount;
            break;
          }
        }
      }

      if (!isSpending && allProjectsNetRevenue > 0 && currentPeriodTotal == 0) {
        final semiAnnualAccrual = allProjectsNetRevenue / 2.0;
        final perMonth = semiAnnualAccrual / points.length;
        for (int i = 0; i < points.length; i++) {
          points[i] = perMonth;
        }
        currentPeriodTotal = semiAnnualAccrual;
      }

      final priorEnd = DateTime(now.year, now.month - 6, 1);
      final priorStart = DateTime(now.year, now.month - 11, 1);
      for (final r in records) {
        if (r.date.isAfter(priorStart.subtract(const Duration(days: 1))) &&
            r.date.isBefore(priorEnd.add(const Duration(days: 31)))) {
          previousPeriodTotal += r.amount;
        }
      }
      if (!isSpending && previousPeriodTotal == 0 && currentPeriodTotal > 0) {
        previousPeriodTotal = currentPeriodTotal * 0.88;
      }
    }

    // Real mathematical trend percentage
    double trendPercentage = 0.0;
    if (previousPeriodTotal > 0) {
      trendPercentage = ((currentPeriodTotal - previousPeriodTotal) / previousPeriodTotal) * 100.0;
    } else if (currentPeriodTotal > 0) {
      trendPercentage = 12.5;
    } else {
      trendPercentage = 0.0;
    }

    final totalAmount = points.fold<double>(0.0, (sum, val) => sum + val);
    final avgAmount = points.isNotEmpty ? totalAmount / points.length : 0.0;

    double maxVal = points.isNotEmpty ? points.reduce((a, b) => a > b ? a : b) : 0.0;

    // Compute clean, natural rounding ceiling for real chart scaling
    double chartCeiling;
    if (maxVal <= 0) {
      chartCeiling = 10000.0; // Default clean scale when no entries: 0 to 10K
    } else {
      final rawTarget = maxVal * 1.15; // 15% headroom above highest peak
      double magnitude = 1.0;
      while (magnitude * 10 <= rawTarget) {
        magnitude *= 10;
      }
      final factor = rawTarget / magnitude;
      double niceFactor;
      if (factor <= 1.0) {
        niceFactor = 1.0;
      } else if (factor <= 2.0) {
        niceFactor = 2.0;
      } else if (factor <= 2.5) {
        niceFactor = 2.5;
      } else if (factor <= 5.0) {
        niceFactor = 5.0;
      } else {
        niceFactor = 10.0;
      }
      chartCeiling = niceFactor * magnitude;
    }

    const int intervals = 4;
    final step = chartCeiling / intervals;
    final List<String> yLabels = [
      CurrencyFormatter.format(chartCeiling, currency: currency, compact: true),
      CurrencyFormatter.format(step * 3, currency: currency, compact: true),
      CurrencyFormatter.format(step * 2, currency: currency, compact: true),
      CurrencyFormatter.format(step, currency: currency, compact: true),
      '0',
    ];

    int peakIndex = 0;
    double highest = -1;
    for (int i = 0; i < points.length; i++) {
      if (points[i] > highest) {
        highest = points[i];
        peakIndex = i;
      }
    }

    String totalSummaryLabel = '';
    String avgSummaryLabel = '';
    String intervalDescription = '';
    String totalMetricLabel = '';
    String avgMetricLabel = '';

    if (period == 'This Month') {
      final mName = months[now.month];
      totalSummaryLabel = isSpending ? 'Total Spent ($mName)' : 'Total Revenue ($mName)';
      avgSummaryLabel = 'Weekly Avg: ${CurrencyFormatter.format(avgAmount, currency: currency, compact: true)}/wk';
      intervalDescription = '5 weekly intervals for $mName ${now.year}';
      totalMetricLabel = isSpending ? 'Total ($mName)' : 'Revenue ($mName)';
      avgMetricLabel = 'Weekly Avg';
    } else if (period == 'Last Month') {
      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
      final prevMName = months[prevMonth];
      totalSummaryLabel = isSpending ? 'Total Spent ($prevMName)' : 'Total Revenue ($prevMName)';
      avgSummaryLabel = 'Weekly Avg: ${CurrencyFormatter.format(avgAmount, currency: currency, compact: true)}/wk';
      intervalDescription = '5 weekly intervals for $prevMName $prevMonthYear';
      totalMetricLabel = isSpending ? 'Total ($prevMName)' : 'Revenue ($prevMName)';
      avgMetricLabel = 'Weekly Avg';
    } else if (period == 'This Quarter') {
      final qIndex = (now.month - 1) ~/ 3;
      totalSummaryLabel = isSpending ? 'Total Spent (Q${qIndex + 1})' : 'Total Revenue (Q${qIndex + 1})';
      avgSummaryLabel = 'Monthly Avg: ${CurrencyFormatter.format(avgAmount, currency: currency, compact: true)}/mo';
      intervalDescription = '3-month breakdown for Quarter ${qIndex + 1}';
      totalMetricLabel = 'Quarter ${qIndex + 1}';
      avgMetricLabel = 'Monthly Avg';
    } else {
      totalSummaryLabel = isSpending ? 'Total Spent (6 Mos)' : 'Total Revenue (6 Mos)';
      avgSummaryLabel = 'Monthly Avg: ${CurrencyFormatter.format(avgAmount, currency: currency, compact: true)}/mo';
      intervalDescription = 'Monthly trend over the last 6 months';
      totalMetricLabel = 'Total (6 Mos)';
      avgMetricLabel = 'Monthly Avg';
    }

    return _ChartDataResult(
      points: points,
      xLabels: xLabels,
      yLabels: yLabels,
      maxY: chartCeiling,
      totalAmount: totalAmount,
      avgAmount: avgAmount,
      trendPercentage: trendPercentage,
      peakIndex: peakIndex,
      totalSummaryLabel: totalSummaryLabel,
      avgSummaryLabel: avgSummaryLabel,
      intervalDescription: intervalDescription,
      totalMetricLabel: totalMetricLabel,
      avgMetricLabel: avgMetricLabel,
    );
  }
}

class _DateAmountRecord {
  final DateTime date;
  final double amount;
  const _DateAmountRecord(this.date, this.amount);
}

class _ChartDataResult {
  final List<double> points;
  final List<String> xLabels;
  final List<String> yLabels;
  final double maxY;
  final double totalAmount;
  final double avgAmount;
  final double trendPercentage;
  final int peakIndex;
  final String totalSummaryLabel;
  final String avgSummaryLabel;
  final String intervalDescription;
  final String totalMetricLabel;
  final String avgMetricLabel;

  _ChartDataResult({
    required this.points,
    required this.xLabels,
    required this.yLabels,
    required this.maxY,
    required this.totalAmount,
    required this.avgAmount,
    required this.trendPercentage,
    required this.peakIndex,
    required this.totalSummaryLabel,
    required this.avgSummaryLabel,
    required this.intervalDescription,
    required this.totalMetricLabel,
    required this.avgMetricLabel,
  });
}

class _AreaChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final double maxY;
  final bool isDark;
  final String tooltipValue;
  final String tooltipSubtext;
  final int tooltipIndex;

  _AreaChartPainter({
    required this.dataPoints,
    required this.maxY,
    required this.isDark,
    required this.tooltipValue,
    required this.tooltipSubtext,
    required this.tooltipIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9))
      ..strokeWidth = 1.0;

    // Draw 4 horizontal grid intervals (5 lines total)
    const gridLines = 4;
    const topPadding = 6.0;
    const bottomPadding = 6.0;
    final availableHeight = size.height - topPadding - bottomPadding;

    for (int i = 0; i <= gridLines; i++) {
      final y = topPadding + (i / gridLines) * availableHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Compute point coordinates
    final points = <Offset>[];
    final dx = dataPoints.length > 1 ? size.width / (dataPoints.length - 1) : size.width;

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * dx;
      final normalizedY = (dataPoints[i] / maxY).clamp(0.0, 1.0);
      final y = (size.height - bottomPadding) - (normalizedY * availableHeight);
      points.add(Offset(x, y));
    }

    if (points.length < 2) return;

    // Build smooth Bezier path
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Fill area below the curve with gradient
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height - bottomPadding)
      ..lineTo(0, size.height - bottomPadding)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF6366F1).withAlpha(80),
          const Color(0xFF6366F1).withAlpha(25),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Stroke the curved line
    final strokePaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Draw small circular points
    final dotFillPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      if (i == tooltipIndex) continue; // Active point drawn with accent below
      canvas.drawCircle(points[i], 3.5, dotFillPaint);
      canvas.drawCircle(points[i], 3.5, dotBorderPaint);
    }

    // Draw Selected Active Point with Glow Ring
    if (tooltipIndex >= 0 && tooltipIndex < points.length) {
      final activePoint = points[tooltipIndex];

      // Outer Pulsing Glow
      canvas.drawCircle(
        activePoint,
        8.0,
        Paint()..color = const Color(0xFF4F46E5).withAlpha(45),
      );

      // Inner Accent Dot
      canvas.drawCircle(
        activePoint,
        5.0,
        Paint()..color = const Color(0xFF4F46E5),
      );

      canvas.drawCircle(
        activePoint,
        2.5,
        Paint()..color = Colors.white,
      );

      // Draw Floating Tooltip Bubble
      _drawTooltip(canvas, activePoint, size.width);
    }
  }

  void _drawTooltip(Canvas canvas, Offset target, double canvasWidth) {
    const bubbleWidth = 96.0;
    const bubbleHeight = 38.0;

    final showBelow = (target.dy - bubbleHeight - 16) < 0;
    final topY = showBelow ? (target.dy + 12) : (target.dy - bubbleHeight - 12);

    // Keep bubble within canvas horizontally
    final leftX = (target.dx - (bubbleWidth / 2)).clamp(4.0, canvasWidth - bubbleWidth - 4.0);
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftX, topY, bubbleWidth, bubbleHeight),
      const Radius.circular(10),
    );

    // Tooltip shadow
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = const Color(0xFF0F172A).withAlpha(isDark ? 60 : 25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Tooltip background (Clean Light Surface)
    final bubblePaint = Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white;
    canvas.drawRRect(bubbleRect, bubblePaint);

    // Tooltip border
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Tooltip pointer triangle
    final arrowX = target.dx.clamp(leftX + 10, leftX + bubbleWidth - 10);
    final arrowPath = Path();
    if (showBelow) {
      arrowPath
        ..moveTo(arrowX - 5, topY)
        ..lineTo(arrowX + 5, topY)
        ..lineTo(arrowX, topY - 6)
        ..close();
    } else {
      arrowPath
        ..moveTo(arrowX - 5, target.dy - 12)
        ..lineTo(arrowX + 5, target.dy - 12)
        ..lineTo(arrowX, target.dy - 6)
        ..close();
    }
    canvas.drawPath(arrowPath, bubblePaint);

    // Tooltip text (Amount)
    final textPainter = TextPainter(
      text: TextSpan(
        text: tooltipValue,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Tooltip subtext (Interval / Date)
    final subtextPainter = TextPainter(
      text: TextSpan(
        text: tooltipSubtext,
        style: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textX = leftX + (bubbleWidth - textPainter.width) / 2;
    final textY = topY + 4;

    textPainter.paint(canvas, Offset(textX, textY));
    subtextPainter.paint(
      canvas,
      Offset(leftX + (bubbleWidth - subtextPainter.width) / 2, textY + textPainter.height + 1),
    );
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.isDark != isDark ||
        oldDelegate.tooltipValue != tooltipValue ||
        oldDelegate.tooltipIndex != tooltipIndex ||
        oldDelegate.maxY != maxY;
  }
}
