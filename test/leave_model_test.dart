import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/leave_model.dart';

void main() {
  test('parses pending, approved, and declined leave states from API records', () {
    final pending = LeaveRecordModel.fromJson({'id': '1', 'userId': 'u1', 'startDate': '2026-11-01', 'endDate': '2026-11-01', 'leaveType': 'casual', 'isApproved': false, 'status': 'pending'});
    final approved = LeaveRecordModel.fromJson({'id': '2', 'userId': 'u1', 'startDate': '2026-11-01', 'endDate': '2026-11-01', 'leaveType': 'casual', 'isApproved': true, 'status': 'approved'});
    final rejected = LeaveRecordModel.fromJson({'id': '3', 'userId': 'u1', 'startDate': '2026-11-01', 'endDate': '2026-11-01', 'leaveType': 'casual', 'isApproved': false, 'status': 'rejected'});

    expect(pending.isPending, isTrue);
    expect(pending.statusText, 'Pending approval');
    expect(approved.isApproved, isTrue);
    expect(rejected.isRejected, isTrue);
    expect(rejected.statusText, 'Declined');
  });
}
