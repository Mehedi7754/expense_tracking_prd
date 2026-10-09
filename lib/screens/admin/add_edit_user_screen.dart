import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/user_management_provider.dart';

class AddEditUserScreen extends ConsumerStatefulWidget {
  final String? userId;

  const AddEditUserScreen({
    super.key,
    this.userId,
  });

  @override
  ConsumerState<AddEditUserScreen> createState() => _AddEditUserScreenState();
}

class _AddEditUserScreenState extends ConsumerState<AddEditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _deptController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  UserRole _selectedRole = UserRole.projectMember;
  bool _initialized = false;
  bool _isSaving = false;

  bool get isEditing => widget.userId != null;

  void _initUser(UserModel user) {
    if (_initialized) return;
    _initialized = true;

    _nameController.text = user.name;
    _emailController.text = user.email;
    _deptController.text = user.department;
    _selectedRole = user.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _deptController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final passwordText = _passwordController.text.trim();

    if (isEditing) {
      final existing = ref.read(userManagementProvider).firstWhere((u) => u.id == widget.userId);
      final updated = existing.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        department: _deptController.text.trim(),
        role: _selectedRole,
      );
      await ref.read(userManagementProvider.notifier).updateUser(
            updated,
            password: passwordText.isNotEmpty ? passwordText : null,
          );
      if (mounted) {
        NotificationBanner.showSuccess(context, 'User profile updated.');
      }
    } else {
      await ref.read(userManagementProvider.notifier).addUser(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            role: _selectedRole,
            department: _deptController.text.trim(),
            password: passwordText.isNotEmpty ? passwordText : null,
          );
      if (mounted) {
        NotificationBanner.showSuccess(context, 'Employee account created successfully.');
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).currentUser;
    final isSuperAdmin = currentUser?.role == UserRole.mainAdmin;
    final allowedRoles = isSuperAdmin
        ? [UserRole.mainAdmin, UserRole.projectManager, UserRole.projectMember]
        : [UserRole.projectManager, UserRole.projectMember];

    if (!allowedRoles.contains(_selectedRole)) {
      _selectedRole = allowedRoles.last;
    }

    if (isEditing) {
      final allUsers = ref.watch(userManagementProvider);
      final match = allUsers.where((u) => u.id == widget.userId);
      if (match.isNotEmpty) {
        _initUser(match.first);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Employee Account' : 'Add Employee'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 18),

                // Corporate Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Work Email Address *'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Email required';
                    if (!val.contains('@')) return 'Enter a valid corporate email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: isEditing ? 'New Password (leave blank to keep current)' : 'Password *',
                    hintText: isEditing ? 'Enter new password if changing' : 'Enter login password for employee',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (!isEditing && (val == null || val.trim().isEmpty)) {
                      return 'Password is required for new employees';
                    }
                    if (val != null && val.trim().isNotEmpty && val.trim().length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Department
                TextFormField(
                  controller: _deptController,
                  decoration: const InputDecoration(
                    labelText: 'Department / Organization Unit *',
                    hintText: 'e.g. Engineering, Sales, Product, Marketing',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Department required' : null,
                ),
                const SizedBox(height: 18),

                // Role Dropdown
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'App Role & Permission Tier *'),
                  items: allowedRoles.map((r) {
                    return DropdownMenuItem<UserRole>(
                      value: r,
                      child: Text(r.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Save Account Changes' : 'Create Employee Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
