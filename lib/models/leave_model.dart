class LeaveRecordModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String startDate;
  final String endDate;
  final String
  leaveType; // 'paid', 'unpaid', 'sick', 'casual', 'maternity', 'emergency'
  final String reason;
  final bool isApproved;
  final String status;

  const LeaveRecordModel({
    required this.id,
    required this.userId,
    this.userName = '',
    this.userEmail = '',
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    this.reason = '',
    this.isApproved = true,
  this.status = '',
  });

  bool get isPending => status.isEmpty ? !isApproved : status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';

  bool get isPaid => leaveType.toLowerCase() != 'unpaid';

  int get totalDays {
    try {
      final s = DateTime.parse(startDate);
      final e = DateTime.parse(endDate);
      final diff = e.difference(s).inDays;
      return diff >= 0 ? diff + 1 : 1;
    } catch (_) {
      return 1;
    }
  }

  String get typeDisplayName {
    switch (leaveType.toLowerCase()) {
      case 'casual':
        return 'Casual Leave';
      case 'sick':
        return 'Medical / Sick Leave';
      case 'emergency':
        return 'Emergency Leave';
      case 'maternity':
        return 'Maternity / Paternity Leave';
      case 'unpaid':
        return 'Unpaid Leave';
      case 'paid':
      default:
        return 'Paid Leave';
    }
  }

  String get statusText => switch (status.toLowerCase()) {
    'rejected' => 'Declined',
    'pending' => 'Pending approval',
    'approved' => 'Approved',
    _ => isApproved ? 'Approved' : 'Pending approval',
  };

  factory LeaveRecordModel.fromJson(Map<String, dynamic> json) {
    return LeaveRecordModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userName:
          json['userName']?.toString() ??
          json['user_name'] ??
          json['full_name'] ??
          '',
      userEmail:
          json['userEmail']?.toString() ??
          json['user_email'] ??
          json['email'] ??
          '',
      startDate:
          json['startDate']?.toString() ?? json['start_date']?.toString() ?? '',
      endDate:
          json['endDate']?.toString() ?? json['end_date']?.toString() ?? '',
      leaveType: json['leaveType']?.toString() ?? json['leave_type'] ?? 'paid',
      reason: json['reason']?.toString() ?? '',
      isApproved:
          json['isApproved'] as bool? ?? json['is_approved'] as bool? ?? true,
      status:
          json['status']?.toString() ??
          ((json['isApproved'] as bool? ?? json['is_approved'] as bool? ?? true)
              ? 'approved'
              : 'pending'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'startDate': startDate,
      'endDate': endDate,
      'leaveType': leaveType,
      'reason': reason,
      'isApproved': isApproved,
      'status': status.isEmpty ? (isApproved ? 'approved' : 'pending') : status,
    };
  }
}
