class LeaveRecordModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String startDate;
  final String endDate;
  final String leaveType; // 'paid', 'unpaid', 'sick', 'casual', 'maternity', 'emergency'
  final String reason;
  final bool isApproved;

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
  });

  bool get isPaid => leaveType.toLowerCase() != 'unpaid';

  factory LeaveRecordModel.fromJson(Map<String, dynamic> json) {
    return LeaveRecordModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? json['user_name'] ?? json['full_name'] ?? '',
      userEmail: json['userEmail']?.toString() ?? json['user_email'] ?? json['email'] ?? '',
      startDate: json['startDate']?.toString() ?? json['start_date']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? json['end_date']?.toString() ?? '',
      leaveType: json['leaveType']?.toString() ?? json['leave_type'] ?? 'paid',
      reason: json['reason']?.toString() ?? '',
      isApproved: json['isApproved'] as bool? ?? json['is_approved'] as bool? ?? true,
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
    };
  }
}
