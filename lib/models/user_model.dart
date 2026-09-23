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
  final bool isActive;
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
    this.isActive = true,
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
    bool? isActive,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      assignedProjectIds: assignedProjectIds ?? this.assignedProjectIds,
    );
  }
}
