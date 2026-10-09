import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/salary_model.dart';
import '../../state/auth_provider.dart';
import '../../state/salary_provider.dart';
import 'holidays_management_screen.dart';
import 'my_salary_screen.dart';

class SalaryDashboardScreen extends ConsumerStatefulWidget {
  const SalaryDashboardScreen({super.key});

  @override
  ConsumerState<SalaryDashboardScreen> createState() => _SalaryDashboardScreenState();
}

class _SalaryDashboardScreenState extends ConsumerState<SalaryDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salaryProvider.notifier).fetchOrgSalaryReport(force: true);
      ref.read(salaryProvider.notifier).fetchHolidays();
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

  void _showEditSalaryDialog(SalaryCalculationModel emp) {
    final salaryController = TextEditingController(text: emp.monthlyBaseSalary.toStringAsFixed(0));
    final daysController = TextEditingController(text: emp.configuredPayableWorkingDays.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Base Salary • ${emp.userName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Predefined Monthly Salary (BDT)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: salaryController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '৳ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Standard Payable Working Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newSalary = double.tryParse(salaryController.text.trim()) ?? emp.monthlyBaseSalary;
              final newDays = int.tryParse(daysController.text.trim()) ?? emp.configuredPayableWorkingDays;
              Navigator.pop(ctx);

              final success = await ref.read(salaryProvider.notifier).setEmployeeSalary(
                    emp.userId,
                    newSalary,
                    standardWorkingDays: newDays,
                  );
              if (mounted) {
                if (success) {
                  NotificationBanner.showSuccess(context, 'Base salary profile updated');
                } else {
                  NotificationBanner.showError(context, 'Failed to update salary');
                }
              }
            },
            child: const Text('Save Salary'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = ref.watch(authProvider).currentUser;
    if (currentUser != null && !currentUser.role.canManageAttendanceAndSalary) {
      return const MySalaryScreen();
    }

    final salaryState = ref.watch(salaryProvider);
    final report = salaryState.orgReport;

    final monthName = DateFormat('MMMM yyyy').format(DateTime(salaryState.selectedYear, salaryState.selectedMonth));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Salary & Attendance Deductions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.beach_access_rounded),
            tooltip: 'Holidays & Non-Working Days',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HolidaysManagementScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recalculate All',
            onPressed: () {
              ref.read(salaryProvider.notifier).fetchOrgSalaryReport(force: true);
              NotificationBanner.showInfo(context, 'Salary calculations refreshed');
            },
          ),
        ],
      ),
      body: salaryState.isLoading && report == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. MONTH SELECTOR
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 16 : 4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.chevron_left_rounded, size: 22),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _changeMonth(-1),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  monthName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.chevron_right_rounded, size: 22),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. KPI SUMMARY CARDS
                  Row(
                    children: [
                      _buildMetricCard(
                        title: 'Total Payroll',
                        value: CurrencyFormatter.format(report?.totalBaseSalary ?? 0),
                        color: const Color(0xFF4F46E5),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _buildMetricCard(
                        title: 'Deductions',
                        value: CurrencyFormatter.format(report?.totalDeductions ?? 0),
                        color: const Color(0xFFEF4444),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _buildMetricCard(
                        title: 'Net Payable',
                        value: CurrencyFormatter.format(report?.totalPayable ?? 0),
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 4. EMPLOYEE SALARY LIST HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: const Text(
                          'Employee Payroll Breakdown',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${report?.totalEmployees ?? 0} Staff Members',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 5. EMPLOYEE SALARY CARDS
                  () {
                    final emps = (report?.employees ?? []).where((emp) {
                      return emp.department.toLowerCase() != 'executive' &&
                          !emp.designation.toLowerCase().contains('super admin') &&
                          !emp.userName.toLowerCase().contains('super admin');
                    }).toList();

                    if (emps.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text('No employee records found for this period', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      );
                    }

                    return Column(
                      children: emps.map((emp) => _buildEmployeeSalaryCard(emp, isDark)).toList(),
                    );
                  }(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 16 : 4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeSalaryCard(SalaryCalculationModel emp, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/salary/${emp.userId}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 16 : 4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, Department & Actions
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4F46E5),
                child: Text(
                  emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.userName,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      '${emp.department} • ${emp.designation}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                tooltip: 'Edit Base Salary',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showEditSalaryDialog(emp),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                tooltip: 'Detailed Audit Breakdown',
                visualDensity: VisualDensity.compact,
                onPressed: () => context.push('/salary/${emp.userId}'),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Minimal Salary Summary Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Salary',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(emp.monthlyBaseSalary),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (emp.totalAbsenceDeductions > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Deductions',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '-${CurrencyFormatter.format(emp.totalAbsenceDeductions)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Net Payable',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(emp.finalPayableSalary),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
      ),
    );
  }
}
