import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/notification_banner.dart';
import '../../../models/attendance_model.dart';
import '../../../models/salary_model.dart';
import '../../../state/attendance_provider.dart';
import '../../../state/salary_provider.dart';
import '../../../repositories/salary_repository.dart';
import 'attendance_map_view.dart';

/// Modal bottom sheet displaying an employee's 2-times geo-locations (Morning & Afternoon)
/// on an interactive map, and allowing Project Managers & Admins to configure member salary
/// and review daily attendance-based deductions.
class MemberGeoLocationModal extends ConsumerStatefulWidget {
  final EmployeeDailyAttendance employee;
  final String date;

  const MemberGeoLocationModal({
    super.key,
    required this.employee,
    required this.date,
  });

  static void show(BuildContext context, EmployeeDailyAttendance emp, String date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MemberGeoLocationModal(employee: emp, date: date),
    );
  }

  @override
  ConsumerState<MemberGeoLocationModal> createState() => _MemberGeoLocationModalState();
}

class _MemberGeoLocationModalState extends ConsumerState<MemberGeoLocationModal> {
  late String _currentDate;
  EmployeeSalaryProfile? _salaryProfile;
  bool _isLoadingSalary = true;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
    _loadSalaryProfile();
  }

  Future<void> _loadSalaryProfile() async {
    setState(() => _isLoadingSalary = true);
    final repo = ref.read(salaryRepositoryProvider);
    try {
      final profile = await repo.getEmployeeSalary(widget.employee.userId);
      if (mounted) {
        setState(() {
          _salaryProfile = profile;
          _isLoadingSalary = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSalary = false);
    }
  }

  void _showSetSalaryDialog() {
    final currentBase = _salaryProfile?.monthlySalary ?? 50000.0;
    final currentDays = _salaryProfile?.standardWorkingDays ?? 22;

    final salaryCtrl = TextEditingController(text: currentBase.toStringAsFixed(0));
    final daysCtrl = TextEditingController(text: currentDays.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final inputSalary = double.tryParse(salaryCtrl.text.trim()) ?? currentBase;
          final inputDays = int.tryParse(daysCtrl.text.trim()) ?? currentDays;
          final calcDaily = inputDays > 0 ? (inputSalary / inputDays) : 0.0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.attach_money_rounded, color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Set Salary • ${widget.employee.userName}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Predefined Monthly Salary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: salaryCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '৳ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  const Text('Payable Working Days / Month', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: daysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Real-time calculation formula preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SALARY CALCULATION PREVIEW',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Daily Salary Rate:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(
                              CurrencyFormatter.format(calcDaily),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cut per Absent Day:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                            Text(
                              '- ${CurrencyFormatter.format(calcDaily)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cut per Half Day:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                            Text(
                              '- ${CurrencyFormatter.format(calcDaily * 0.5)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  final newSalary = double.tryParse(salaryCtrl.text.trim()) ?? currentBase;
                  final newDays = int.tryParse(daysCtrl.text.trim()) ?? currentDays;
                  Navigator.pop(ctx);

                  final success = await ref.read(salaryProvider.notifier).setEmployeeSalary(
                        widget.employee.userId,
                        newSalary,
                        standardWorkingDays: newDays,
                      );
                  if (success) {
                    await _loadSalaryProfile();
                    if (mounted) {
                      NotificationBanner.showSuccess(context, 'Salary & daily deduction rate updated for ${widget.employee.userName}');
                    }
                  }
                },
                child: const Text('Save & Apply Rate', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConfirmAbsenceDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Unpaid Absence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No login attendance was verified for ${widget.employee.userName} on $_currentDate.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '1.0 working day will be deducted from monthly salary (${CurrencyFormatter.format(_dailySalaryRate)}).',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Audit Note (Optional):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'e.g. Unscheduled absence without approved leave',
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
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(attendanceProvider.notifier).confirmAbsence(
                    userId: widget.employee.userId,
                    date: _currentDate,
                    notes: noteController.text.trim(),
                  );
              if (mounted) {
                if (success) {
                  NotificationBanner.showSuccess(context, 'Absence confirmed & daily salary deduction applied');
                  Navigator.pop(context);
                } else {
                  NotificationBanner.showError(context, 'Failed to confirm absence');
                }
              }
            },
            child: const Text('Confirm Absence Cut', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  double get _dailySalaryRate {
    final base = _salaryProfile?.monthlySalary ?? 50000.0;
    final days = (_salaryProfile?.standardWorkingDays ?? 22) > 0 ? (_salaryProfile?.standardWorkingDays ?? 22) : 22;
    return base / days;
  }

  double get _todayDeduction {
    final status = widget.employee.status;
    if (status == 'present') return 0.0;
    if (status == 'half_day') return _dailySalaryRate * 0.5;
    return _dailySalaryRate; // absent / missing
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final emp = widget.employee;
    final morning = emp.morning;
    final afternoon = emp.afternoon;

    final validRecords = <AttendanceRecordModel>[
      if (morning != null && morning.latitude != null) morning,
      if (afternoon != null && afternoon.latitude != null) afternoon,
    ];

    double? distanceBetweenPunches;
    if (morning != null && morning.latitude != null && morning.longitude != null &&
        afternoon != null && afternoon.latitude != null && afternoon.longitude != null) {
      final p1 = LatLng(morning.latitude!, morning.longitude!);
      final p2 = LatLng(afternoon.latitude!, afternoon.longitude!);
      const distanceCalc = Distance();
      distanceBetweenPunches = distanceCalc.as(LengthUnit.Meter, p1, p2) / 1000.0; // km
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 1. Sheet Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Member Profile Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF4F46E5),
                  child: Text(
                    emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.userName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${emp.department} • ${emp.designation.isNotEmpty ? emp.designation : emp.role}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // 3. Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and Status Banner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                DateFormat('EEE, MMM d, yyyy').format(DateTime.tryParse(_currentDate) ?? DateTime.now()),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildOverallStatusBadge(emp.status),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // SECTION: 2-TIMES GEO-LOCATION RECORDS
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          '2-Time Daily Geo-Location Records',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Session 1: Morning Geo-Location Card
                  _buildSessionGeoCard(
                    title: 'Morning Check-In',
                    sessionBadge: 'Morning Session',
                    record: morning,
                    color: const Color(0xFF4F46E5),
                    icon: Icons.wb_sunny_rounded,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 10),

                  // Session 2: Afternoon Geo-Location Card
                  _buildSessionGeoCard(
                    title: 'Afternoon Check-In',
                    sessionBadge: 'Afternoon Session',
                    record: afternoon,
                    color: const Color(0xFF10B981),
                    icon: Icons.nights_stay_rounded,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 14),

                  // INTERACTIVE MAP WITH BOTH PINS
                  if (validRecords.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Interactive Map View',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        if (distanceBetweenPunches != null)
                          Text(
                            'Distance: ${distanceBetweenPunches.toStringAsFixed(2)} km',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AttendanceMapView(
                          records: validRecords,
                          initialLat: validRecords.first.latitude!,
                          initialLng: validRecords.first.longitude!,
                          initialZoom: 13.0,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_off_outlined, size: 18, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'No GPS punch logged for this employee on this date.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // SECTION: SALARY & DAILY ATTENDANCE DEDUCTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Salary & Daily Cut',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Set Salary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _showSetSalaryDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Salary Calculation Breakdown Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: _isLoadingSalary
                        ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Monthly Base:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text(
                                    CurrencyFormatter.format(_salaryProfile?.monthlySalary ?? 50000.0),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Daily Rate:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text(
                                    '${CurrencyFormatter.format(_dailySalaryRate)} / day',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Today's Absence Cut:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text(
                                    _todayDeduction > 0 ? '- ${CurrencyFormatter.format(_todayDeduction)}' : '৳0.00 (No Cut)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: _todayDeduction > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),

                  // Absence confirmation button if unlogged
                  if (emp.isMissing) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.gavel_rounded, size: 16),
                        label: const Text('Confirm Unpaid Absence', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showConfirmAbsenceDialog,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (status == 'present') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      label = 'Full Day Present';
      icon = Icons.check_circle_rounded;
    } else if (status == 'half_day') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      label = 'Half Day Present';
      icon = Icons.timelapse_rounded;
    } else if (status == 'confirmed_absent') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'Confirmed Absent';
      icon = Icons.cancel_rounded;
    } else {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFFCA8A04);
      label = 'Missing Record';
      icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  Widget _buildSessionGeoCard({
    required String title,
    required String sessionBadge,
    required AttendanceRecordModel? record,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    final hasRecord = record != null && record.status != 'confirmed_absent';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasRecord ? color.withAlpha(80) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Icon(icon, size: 16, color: hasRecord ? color : Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hasRecord ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasRecord ? color : Colors.grey).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasRecord ? record.formattedTime : 'Not Logged',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasRecord ? color : Colors.grey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (hasRecord) ...[
            // Coordinates Row with Copy button
            Row(
              children: [
                const Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF4F46E5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    record.formattedCoordinates,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: record.formattedCoordinates));
                    NotificationBanner.showInfo(context, 'Coordinates copied to clipboard');
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            if (record.addressText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.apartment_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.addressText,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (record.deviceInfo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.smartphone_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.deviceInfo,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            const Text(
              'No check-in recorded for this session',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }
}
