import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
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
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (isEditing) {
      final existing = ref.read(userManagementProvider).firstWhere((u) => u.id == widget.userId);
      final updated = existing.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        department: _deptController.text.trim(),
        role: _selectedRole,
      );
      ref.read(userManagementProvider.notifier).updateUser(updated);
      NotificationBanner.showSuccess(context, 'User profile updated.');
    } else {
      ref.read(userManagementProvider.notifier).addUser(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            role: _selectedRole,
            department: _deptController.text.trim(),
          );
      NotificationBanner.showSuccess(context, 'Invitation dispatched and user account created.');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(isEditing ? 'Edit User Account' : 'Invite / Add New User'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
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
                  items: UserRole.values.map((r) {
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
                        : Text(isEditing ? 'Save Account Changes' : 'Create User Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
