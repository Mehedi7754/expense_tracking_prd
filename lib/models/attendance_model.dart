import 'package:intl/intl.dart';

class AttendanceRecordModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String department;
  final String designation;
  final String avatarUrl;
  final String date;
  final String sessionType; // 'morning' | 'afternoon'
  final DateTime loginTime;
  final double? latitude;
  final double? longitude;
  final String addressText;
  final String deviceInfo;
  final String status;
  final String notes;
  final DateTime createdAt;

  const AttendanceRecordModel({
    required this.id,
    required this.userId,
    this.userName = '',
    this.userEmail = '',
    this.department = '',
    this.designation = '',
    this.avatarUrl = '',
    required this.date,
    required this.sessionType,
    required this.loginTime,
    this.latitude,
    this.longitude,
    this.addressText = '',
    this.deviceInfo = '',
    this.status = 'present',
    this.notes = '',
    required this.createdAt,
  });

  bool get isMorning => sessionType.toLowerCase() == 'morning';
  bool get isAfternoon => sessionType.toLowerCase() == 'afternoon';
  bool get hasValidLocation => latitude != null && longitude != null;

  String get formattedTime => DateFormat('hh:mm a').format(loginTime.toLocal());
  String get formattedDate => DateFormat('EEE, MMM d, yyyy').format(DateTime.tryParse(date) ?? loginTime);

  String get formattedCoordinates {
    if (latitude == null || longitude == null) return 'No GPS Coordinates';
    final lat = '${latitude!.abs().toStringAsFixed(4)}° ${latitude! >= 0 ? "N" : "S"}';
    final lng = '${longitude!.abs().toStringAsFixed(4)}° ${longitude! >= 0 ? "E" : "W"}';
    return '$lat, $lng';
  }

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedLogin;
    try {
      parsedLogin = DateTime.parse(json['loginTime'] ?? json['login_time'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedLogin = DateTime.now();
    }

    DateTime parsedCreated;
    try {
      parsedCreated = DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    double? parseCoord(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    return AttendanceRecordModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? json['user_name'] ?? json['full_name'] ?? '',
      userEmail: json['userEmail']?.toString() ?? json['user_email'] ?? json['email'] ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url'] ?? '',
      date: json['date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      sessionType: json['sessionType']?.toString() ?? json['session_type'] ?? 'morning',
      loginTime: parsedLogin,
      latitude: parseCoord(json['latitude']),
      longitude: parseCoord(json['longitude']),
      addressText: json['addressText']?.toString() ?? json['address_text'] ?? '',
      deviceInfo: json['deviceInfo']?.toString() ?? json['device_info'] ?? '',
      status: json['status']?.toString() ?? 'present',
      notes: json['notes']?.toString() ?? '',
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'department': department,
      'designation': designation,
      'avatarUrl': avatarUrl,
      'date': date,
      'sessionType': sessionType,
      'loginTime': loginTime.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'addressText': addressText,
      'deviceInfo': deviceInfo,
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecordModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class EmployeeDailyAttendance {
  final String userId;
  final String userName;
  final String userEmail;
  final String department;
  final String designation;
  final String role;
  final String avatarUrl;
  final String date;
  final String status; // 'present' | 'half_day' | 'missing' | 'confirmed_absent'
  final AttendanceRecordModel? morning;
  final AttendanceRecordModel? afternoon;

  const EmployeeDailyAttendance({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.department,
    required this.designation,
    required this.role,
    this.avatarUrl = '',
    required this.date,
    required this.status,
    this.morning,
    this.afternoon,
  });

  bool get isPresent => status == 'present';
  bool get isHalfDay => status == 'half_day';
  bool get isMissing => status == 'missing';
  bool get isConfirmedAbsent => status == 'confirmed_absent';

  factory EmployeeDailyAttendance.fromJson(Map<String, dynamic> json) {
    return EmployeeDailyAttendance(
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? json['user_name'] ?? json['full_name'] ?? '',
      userEmail: json['userEmail']?.toString() ?? json['user_email'] ?? json['email'] ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url'] ?? '',
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'missing',
      morning: json['morning'] != null ? AttendanceRecordModel.fromJson(json['morning']) : null,
      afternoon: json['afternoon'] != null ? AttendanceRecordModel.fromJson(json['afternoon']) : null,
    );
  }
}

class DailyAttendanceOverview {
  final String date;
  final int totalEmployees;
  final int presentCount;
  final int halfDayCount;
  final int missingCount;
  final List<EmployeeDailyAttendance> employees;

  const DailyAttendanceOverview({
    required this.date,
    required this.totalEmployees,
    required this.presentCount,
    required this.halfDayCount,
    required this.missingCount,
    required this.employees,
  });

  factory DailyAttendanceOverview.fromJson(Map<String, dynamic> json) {
    final list = json['employees'] as List<dynamic>? ?? [];
    return DailyAttendanceOverview(
      date: json['date']?.toString() ?? '',
      totalEmployees: json['totalEmployees'] as int? ?? 0,
      presentCount: json['presentCount'] as int? ?? 0,
      halfDayCount: json['halfDayCount'] as int? ?? 0,
      missingCount: json['missingCount'] as int? ?? 0,
      employees: list.map((e) => EmployeeDailyAttendance.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AttendanceSummaryModel {
  final String userId;
  final int month;
  final int year;
  final int totalRecords;
  final int fullPresentDays;
  final int halfDays;
  final double totalPresentEquivalent;

  const AttendanceSummaryModel({
    required this.userId,
    required this.month,
    required this.year,
    required this.totalRecords,
    required this.fullPresentDays,
    required this.halfDays,
    required this.totalPresentEquivalent,
  });

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) {
    double parseDbl(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return AttendanceSummaryModel(
      userId: json['userId']?.toString() ?? '',
      month: json['month'] as int? ?? 1,
      year: json['year'] as int? ?? 2026,
      totalRecords: json['totalRecords'] as int? ?? 0,
      fullPresentDays: json['fullPresentDays'] as int? ?? 0,
      halfDays: json['halfDays'] as int? ?? 0,
      totalPresentEquivalent: parseDbl(json['totalPresentEquivalent']),
    );
  }
}
