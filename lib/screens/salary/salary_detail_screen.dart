import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/salary_model.dart';
import '../../state/salary_provider.dart';

class SalaryDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const SalaryDetailScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<SalaryDetailScreen> createState() => _SalaryDetailScreenState();
}

class _SalaryDetailScreenState extends ConsumerState<SalaryDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salaryProvider.notifier).setSelectedUser(widget.userId);
    });
  }

  void _showAddAdjustmentDialog() {
    final parentContext = context;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String type = 'bonus';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Payroll Adjustment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Adjustment Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'bonus', child: Text('Bonus / Performance Addition (+)')),
                  DropdownMenuItem(value: 'addition', child: Text('Special Allowance (+)')),
                  DropdownMenuItem(value: 'penalty', child: Text('Policy Penalty (-)')),
                  DropdownMenuItem(value: 'deduction', child: Text('Manual Deduction (-)')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => type = val);
                },
              ),
              const SizedBox(height: 12),
              const Text('Amount (BDT)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '৳ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Audit Reason / Justification', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'e.g. Overtime reimbursement or policy exception',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: 2,
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
                final amt = double.tryParse(amountController.text.trim());
                if (amt == null || amt <= 0) return;
                Navigator.pop(ctx);

                final success = await ref.read(salaryProvider.notifier).addAdjustment(
                      userId: widget.userId,
                      type: type,
                      amount: amt,
                      reason: reasonController.text.trim().isEmpty ? 'Manual adjustment' : reasonController.text.trim(),
                    );
                if (parentContext.mounted) {
                  if (success) {
                    NotificationBanner.showSuccess(parentContext, 'Adjustment recorded and applied to final salary');
                  } else {
                    NotificationBanner.showError(parentContext, 'Failed to save adjustment');
                  }
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveCalculation() async {
    final success = await ref.read(salaryProvider.notifier).saveCalculation(
          widget.userId,
          notes: 'Confirmed and locked for audit',
        );
    if (mounted) {
      if (success) {
        NotificationBanner.showSuccess(context, 'Salary calculation confirmed and locked for payroll audit');
      } else {
        NotificationBanner.showError(context, 'Failed to lock calculation');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final salaryState = ref.watch(salaryProvider);
    final calc = salaryState.currentCalculation;

    final monthName = DateFormat('MMMM yyyy').format(DateTime(salaryState.selectedYear, salaryState.selectedMonth));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          calc != null ? '${calc.userName} • Salary' : 'Salary Calculation',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            tooltip: 'Add Adjustment',
            onPressed: _showAddAdjustmentDialog,
          ),
          IconButton(
            icon: const Icon(Icons.lock_clock_rounded),
            tooltip: 'Confirm & Lock Calculation',
            onPressed: _handleSaveCalculation,
          ),
        ],
      ),
      body: salaryState.isLoading && calc == null
          ? const Center(child: CircularProgressIndicator())
          : calc == null
              ? const Center(child: Text('Unable to load employee calculation'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. SUMMARY HERO CARD
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 16 : 4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        calc.userName,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${calc.department} • ${calc.designation}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        monthName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (calc.isConfirmed ? const Color(0xFF10B981) : const Color(0xFF4F46E5)).withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    calc.isConfirmed ? 'Audited' : 'Live Calc',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: calc.isConfirmed ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // Calculation Formula Grid
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: _buildMetricCol('Monthly Base', CurrencyFormatter.format(calc.monthlyBaseSalary), isDark)),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 2),
                                  child: Text('÷', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ),
                                Expanded(child: _buildMetricCol('Payable Days', '${calc.configuredPayableWorkingDays}d', isDark)),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 2),
                                  child: Text('=', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ),
                                Expanded(child: _buildMetricCol('Daily Rate', CurrencyFormatter.format(calc.dailySalaryRate), isDark, color: const Color(0xFF4F46E5))),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Attendance Summary Pills
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black.withAlpha(25) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildAttendancePill('Present', '${calc.totalPresentEquivalent}d', const Color(0xFF10B981)),
                                  _buildAttendancePill('Absent/Unpaid', '${calc.totalAbsentEquivalent}d', const Color(0xFFEF4444)),
                                  _buildAttendancePill('Holidays', '${calc.holidayDays}d', const Color(0xFF0284C7)),
                                  _buildAttendancePill('Weekends', '${calc.weekendDays}d', const Color(0xFF64748B)),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Final Net Payable Calculation Result
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Absence Deductions', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(
                                        '-${CurrencyFormatter.format(calc.totalAbsenceDeductions)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (calc.totalAdditions > 0 || calc.totalPenalties > 0)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const Text('Adjustments', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(
                                          '+${CurrencyFormatter.format(calc.totalAdditions - calc.totalPenalties)}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Final Payable', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(
                                        CurrencyFormatter.format(calc.finalPayableSalary),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981), letterSpacing: -0.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 2. DAY-BY-DAY ATTENDANCE CALENDAR TABLE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Daily Attendance & Policy Log',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${calc.calendarDaysInMonth} Days in Month',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      ...calc.dailyBreakdown.map((day) => _buildDayBreakdownRow(day, isDark)),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricCol(String label, String value, bool isDark, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendancePill(String title, String count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(count, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildDayBreakdownRow(DailyBreakdownItemModel day, bool isDark) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (day.status) {
      case 'present':
        badgeColor = const Color(0xFF10B981);
        badgeText = 'Present (Full)';
        badgeIcon = Icons.check_circle_rounded;
        break;
      case 'half_day':
        badgeColor = const Color(0xFFF59E0B);
        badgeText = 'Half Day (0.5d)';
        badgeIcon = Icons.timelapse_rounded;
        break;
      case 'paid_leave':
        badgeColor = const Color(0xFF0284C7);
        badgeText = 'Paid Leave';
        badgeIcon = Icons.event_available_rounded;
        break;
      case 'unpaid_leave':
        badgeColor = const Color(0xFFEF4444);
        badgeText = 'Unpaid Leave';
        badgeIcon = Icons.event_busy_rounded;
        break;
      case 'holiday':
        badgeColor = const Color(0xFF8B5CF6);
        badgeText = 'Official Holiday';
        badgeIcon = Icons.beach_access_rounded;
        break;
      case 'weekend':
        badgeColor = const Color(0xFF64748B);
        badgeText = 'Weekend';
        badgeIcon = Icons.weekend_rounded;
        break;
      case 'confirmed_absent':
        badgeColor = const Color(0xFFEF4444);
        badgeText = 'Absent (-1d)';
        badgeIcon = Icons.cancel_rounded;
        break;
      case 'missing_record':
        badgeColor = const Color(0xFFEAB308);
        badgeText = 'Missing Record';
        badgeIcon = Icons.help_outline_rounded;
        break;
      default:
        badgeColor = const Color(0xFF94A3B8);
        badgeText = 'Upcoming';
        badgeIcon = Icons.schedule_rounded;
    }

    final dateParts = day.date.split('-');
    final dayNum = dateParts.length == 3 ? dateParts[2] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
        ),
      ),
      child: Row(
        children: [
          // Day number box
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayNum,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                Text(
                  day.dayOfWeek.substring(0, 3).toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Session punch times or holiday name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.holidayName ?? (day.notes.isNotEmpty ? day.notes : day.status),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (day.morningAttended || day.afternoonAttended)
                  Text(
                    'Morning: ${day.morningAttended ? "Checked in" : "None"} • Afternoon: ${day.afternoonAttended ? "Checked in" : "None"}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  )
                else
                  Text(
                    day.isWeekend ? 'Non-working day' : (day.isHoliday ? 'Official Paid Holiday' : 'No punches recorded'),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 11, color: badgeColor),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
