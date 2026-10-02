import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/attendance_model.dart';
import '../../state/attendance_provider.dart';
import '../../state/auth_provider.dart';
import 'widgets/attendance_map_view.dart';

class MyAttendanceScreen extends ConsumerStatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  ConsumerState<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends ConsumerState<MyAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).currentUser;
      final effectiveId = user?.id ?? 'a0000000-0000-0000-0000-000000000003';
      ref.read(attendanceProvider.notifier).fetchAttendanceRecords(userId: effectiveId, force: true);
    });
  }

  Future<void> _handleManualCheckIn([String? session]) async {
    final success = await ref.read(attendanceProvider.notifier).checkIn(explicitSession: session);
    if (mounted) {
      if (success) {
        NotificationBanner.showSuccess(context, 'Attendance & GPS coordinates recorded successfully!');
      } else {
        final err = ref.read(attendanceProvider).errorMessage ?? 'Check-in failed';
        NotificationBanner.showWarning(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final attendanceState = ref.watch(attendanceProvider);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final effectiveUserId = user?.id ?? 'a0000000-0000-0000-0000-000000000003';
    final myRecords = attendanceState.records.where((r) => r.userId == effectiveUserId).toList();

    AttendanceRecordModel? todayMorning;
    AttendanceRecordModel? todayAfternoon;

    for (final r in myRecords) {
      if (r.date == todayStr) {
        if (r.isMorning) todayMorning = r;
        if (r.isAfternoon) todayAfternoon = r;
      }
    }

    final currentHour = DateTime.now().hour;
    final isMorningTime = currentHour < 13;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('My Attendance & Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TODAY'S ATTENDANCE STATUS CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withAlpha(40),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
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
                            const Text(
                              "Today's Check-In Status",
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isMorningTime ? 'Morning Slot' : 'Afternoon Slot',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Session 1: Morning Check-in
                  _buildSessionPill(
                    title: 'Morning Session',
                    record: todayMorning,
                    onCheckIn: () => _handleManualCheckIn('morning'),
                    isSubmitting: attendanceState.isSubmitting,
                    icon: Icons.wb_sunny_rounded,
                  ),

                  const SizedBox(height: 12),

                  // Session 2: Afternoon Check-in
                  _buildSessionPill(
                    title: 'Afternoon Session',
                    record: todayAfternoon,
                    onCheckIn: () => _handleManualCheckIn('afternoon'),
                    isSubmitting: attendanceState.isSubmitting,
                    icon: Icons.nights_stay_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. TODAY'S GPS MAP
            if (myRecords.where((r) => r.latitude != null).isNotEmpty) ...[
              const Text(
                'My Logged Locations Today',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                width: double.infinity,
                child: AttendanceMapView(
                  records: myRecords.where((r) => r.date == todayStr).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 3. ATTENDANCE HISTORY LIST
            const Text(
              'Attendance History',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
            ),
            const SizedBox(height: 8),

            if (myRecords.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('No attendance history found yet', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              )
            else
              ...myRecords.map((r) => _buildHistoryRow(r, isDark)),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionPill({
    required String title,
    required AttendanceRecordModel? record,
    required VoidCallback onCheckIn,
    required bool isSubmitting,
    required IconData icon,
  }) {
    final hasLogged = record != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                Text(
                  hasLogged ? 'Logged at ${record.formattedTime}' : 'Not logged yet',
                  style: TextStyle(
                    color: Colors.white.withAlpha(190),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (hasLogged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Present', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              onPressed: isSubmitting ? null : onCheckIn,
              child: isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Punch In', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(AttendanceRecordModel r, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (r.isMorning ? const Color(0xFF4F46E5) : const Color(0xFF10B981)).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              r.isMorning ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              color: r.isMorning ? const Color(0xFF4F46E5) : const Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.formattedDate} • ${r.sessionType.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Text(
                  r.formattedCoordinates,
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
                r.formattedTime,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Present',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
