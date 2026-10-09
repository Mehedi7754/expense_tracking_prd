import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/salary_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/salary_provider.dart';

class MySalaryScreen extends ConsumerStatefulWidget {
  const MySalaryScreen({super.key});

  @override
  ConsumerState<MySalaryScreen> createState() => _MySalaryScreenState();
}

class _MySalaryScreenState extends ConsumerState<MySalaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).currentUser;
      if (user != null && user.role != UserRole.mainAdmin) {
        ref.read(salaryProvider.notifier).setSelectedUser(user.id);
      }
    });
  }

  void _changeMonth(int monthDelta) {
    final state = ref.read(salaryProvider);
    var m = state.selectedMonth + monthDelta;
    var y = state.selectedYear;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    ref.read(salaryProvider.notifier).setSelectedPeriod(m, y);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = ref.watch(authProvider).currentUser;
    if (currentUser?.role == UserRole.mainAdmin) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
        appBar: AppBar(
          title: const Text('Salary Statement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded, size: 48, color: Color(0xFF6366F1)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Super Admin Exemption',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Salary statements and deduction records are strictly designed for employees and staff members. Executive leadership is exempt from payroll calculation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final salaryState = ref.watch(salaryProvider);
    final calc = salaryState.currentCalculation;
    final monthName = DateFormat('MMMM yyyy').format(DateTime(salaryState.selectedYear, salaryState.selectedMonth));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('My Monthly Salary Statement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: salaryState.isLoading && calc == null
          ? const Center(child: CircularProgressIndicator())
          : calc == null
              ? const Center(child: Text('Unable to load salary statement'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.chevron_left_rounded, size: 22),
                              onPressed: () => _changeMonth(-1),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  monthName,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.chevron_right_rounded, size: 22),
                              onPressed: () => _changeMonth(1),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Final Payable Card (Hero)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF064E3B), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669).withAlpha(40),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Final Net Payable Salary',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(calc.finalPayableSalary),
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: _buildWhiteStat('Base Salary', CurrencyFormatter.format(calc.monthlyBaseSalary))),
                                Expanded(child: _buildWhiteStat('Daily Rate', CurrencyFormatter.format(calc.dailySalaryRate))),
                                Expanded(child: _buildWhiteStat('Deductions', '-${CurrencyFormatter.format(calc.totalAbsenceDeductions)}')),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Attendance Summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Attendance & Working Days Audit',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _buildPill('Scheduled', '${calc.scheduledWorkingDays}d', const Color(0xFF4F46E5))),
                                Expanded(child: _buildPill('Present', '${calc.totalPresentEquivalent}d', const Color(0xFF10B981))),
                                Expanded(child: _buildPill('Absences', '${calc.totalAbsentEquivalent}d', const Color(0xFFEF4444))),
                                Expanded(child: _buildPill('Holidays', '${calc.holidayDays}d', const Color(0xFF0284C7))),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Day by day
                      const Text(
                        'Day-by-Day Attendance Record',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 8),

                      ...calc.dailyBreakdown.map((day) => _buildDayTile(day, isDark)),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWhiteStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  Widget _buildDayTile(DailyBreakdownItemModel day, bool isDark) {
    Color badgeColor;
    String badgeText;

    switch (day.status) {
      case 'present':
        badgeColor = const Color(0xFF10B981);
        badgeText = 'Present (Full)';
        break;
      case 'half_day':
        badgeColor = const Color(0xFFF59E0B);
        badgeText = 'Half Day';
        break;
      case 'paid_leave':
        badgeColor = const Color(0xFF0284C7);
        badgeText = 'Paid Leave';
        break;
      case 'holiday':
        badgeColor = const Color(0xFF8B5CF6);
        badgeText = 'Holiday';
        break;
      case 'weekend':
        badgeColor = const Color(0xFF64748B);
        badgeText = 'Weekend';
        break;
      case 'confirmed_absent':
        badgeColor = const Color(0xFFEF4444);
        badgeText = 'Absent (-1d)';
        break;
      case 'missing_record':
        badgeColor = const Color(0xFFEAB308);
        badgeText = 'Missing Record';
        break;
      default:
        badgeColor = const Color(0xFF94A3B8);
        badgeText = 'Upcoming';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
        ),
      ),
      child: Row(
        children: [
          Text(
            day.date,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            day.dayOfWeek.substring(0, 3),
            style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
