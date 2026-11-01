import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracking_prd/models/attendance_model.dart';
import 'package:expense_tracking_prd/models/user_model.dart';
import 'package:expense_tracking_prd/repositories/attendance_repository.dart';
import 'package:expense_tracking_prd/state/attendance_provider.dart';

class MockAttendanceRepository extends Fake implements AttendanceRepository {
  List<AttendanceRecordModel> recordsToReturn = [];
  int getRecordsCallCount = 0;
  int getDailyOverviewCallCount = 0;

  @override
  Future<List<AttendanceRecordModel>> getAttendanceRecords({
    String? userId,
    String? date,
    String? sessionType,
    int? month,
    int? year,
  }) async {
    getRecordsCallCount++;
    return recordsToReturn;
  }

  @override
  Future<DailyAttendanceOverview> getDailyOverview([String? date, List<UserModel>? explicitUsers]) async {
    getDailyOverviewCallCount++;
    return DailyAttendanceOverview(
      date: date ?? '2026-10-10',
      totalEmployees: explicitUsers?.length ?? 1,
      presentCount: 1,
      halfDayCount: 0,
      missingCount: 0,
      employees: const [],
    );
  }
}

void main() {
  group('Employee Attendance Auto-Fetch & Decoupled Caching Tests', () {
    test('AttendanceNotifier allows concurrent or back-to-back overview and records fetches without aborting', () async {
      final mockRepo = MockAttendanceRepository();
      mockRepo.recordsToReturn = [
        AttendanceRecordModel(
          id: 'rec-1',
          userId: 'emp-123',
          userName: 'Employee One',
          date: '2026-10-10',
          sessionType: 'morning',
          loginTime: DateTime.parse('2026-10-10T09:00:00Z'),
          createdAt: DateTime.parse('2026-10-10T09:00:00Z'),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          attendanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(attendanceProvider.notifier);

      // Trigger both concurrently / back-to-back
      final future1 = notifier.fetchDailyOverview(force: true);
      final future2 = notifier.fetchAttendanceRecords(userId: 'emp-123', force: true);

      await Future.wait([future1, future2]);

      expect(mockRepo.getDailyOverviewCallCount, equals(1));
      expect(mockRepo.getRecordsCallCount, equals(1));

      final state = container.read(attendanceProvider);
      expect(state.records.length, equals(1));
      expect(state.records.first.id, equals('rec-1'));
    });

    test('AttendanceNotifier invalidateCache clears timestamps and allows forced re-fetch', () async {
      final mockRepo = MockAttendanceRepository();
      mockRepo.recordsToReturn = [
        AttendanceRecordModel(
          id: 'rec-1',
          userId: 'emp-123',
          userName: 'Employee One',
          date: '2026-10-10',
          sessionType: 'morning',
          loginTime: DateTime.parse('2026-10-10T09:00:00Z'),
          createdAt: DateTime.parse('2026-10-10T09:00:00Z'),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          attendanceRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(attendanceProvider.notifier);

      await notifier.fetchAttendanceRecords(userId: 'emp-123', force: true);
      expect(mockRepo.getRecordsCallCount, equals(1));

      // Second call without force within TTL uses cache
      await notifier.fetchAttendanceRecords(userId: 'emp-123');
      expect(mockRepo.getRecordsCallCount, equals(1));

      // After invalidateCache, fetch proceeds
      notifier.invalidateCache();
      await notifier.fetchAttendanceRecords(userId: 'emp-123');
      expect(mockRepo.getRecordsCallCount, equals(2));
    });
  });
}
