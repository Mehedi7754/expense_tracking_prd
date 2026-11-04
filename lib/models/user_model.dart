import 'user_role.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String department;
  final String? designation;
  final String? phone;
  final String? avatarUrl;
  final double? homeLatitude;
  final double? homeLongitude;
  final bool isActive;
  final bool isApproved;
  final List<String> assignedProjectIds;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.designation,
    this.phone,
    this.avatarUrl,
    this.homeLatitude,
    this.homeLongitude,
    this.isActive = true,
    this.isApproved = true,
    this.assignedProjectIds = const [],
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? department,
    String? designation,
    String? phone,
    String? avatarUrl,
    double? homeLatitude,
    double? homeLongitude,
    bool clearAvatarUrl = false,
    bool? isActive,
    bool? isApproved,
    List<String>? assignedProjectIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      homeLatitude: homeLatitude ?? this.homeLatitude,
      homeLongitude: homeLongitude ?? this.homeLongitude,
      isActive: isActive ?? this.isActive,
      isApproved: isApproved ?? this.isApproved,
      assignedProjectIds: assignedProjectIds ?? this.assignedProjectIds,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> parseProjectIds(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    }

    final roleStr = json['role']?.toString() ?? 'project_member';

    return UserModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: UserRole.fromString(roleStr),
      department: (json['department'] ?? 'Operations').toString(),
      designation: json['designation']?.toString(),
      phone: json['phone']?.toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
      homeLatitude: _asDouble(json['home_latitude'] ?? json['homeLatitude']),
      homeLongitude: _asDouble(json['home_longitude'] ?? json['homeLongitude']),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      isApproved: json['is_approved'] ?? json['isApproved'] ?? (json['is_active'] ?? json['isActive'] ?? true),
      assignedProjectIds: parseProjectIds(
        json['assigned_project_ids'] ?? json['assignedProjectIds'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'department': department,
      if (designation != null) 'designation': designation,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) ...{
        'avatar_url': avatarUrl,
        'avatarUrl': avatarUrl,
      },
      if (homeLatitude != null) 'home_latitude': homeLatitude,
      if (homeLongitude != null) 'home_longitude': homeLongitude,
      'is_active': isActive,
      'is_approved': isApproved,
      'assigned_project_ids': assignedProjectIds,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          (id.isNotEmpty ? id == other.id : email == other.email);

  @override
  int get hashCode => id.isNotEmpty ? id.hashCode : email.hashCode;
}

double? _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
