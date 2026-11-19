import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_env.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/app_back_button.dart';
import '../../models/user_model.dart';
import '../../state/user_management_provider.dart';

class MonthlyAttendanceScreen extends ConsumerStatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  ConsumerState<MonthlyAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState
    extends ConsumerState<MonthlyAttendanceScreen> {
  late DateTime _month;
  bool _loading = true;
  String? _error;
  String _employeeQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(userManagementProvider.notifier).fetchUsers();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Employees could not be loaded. Please try again.';
        });
      }
    }
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final users =
        ref
            .watch(userManagementProvider)
            .where((user) => user.isActive && user.isApproved)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final query = _employeeQuery.trim().toLowerCase();
    final matches =
        users
            .where(
              (user) =>
                  query.isEmpty ||
                  user.name.toLowerCase().contains(query) ||
                  user.email.toLowerCase().contains(query) ||
                  user.department.toLowerCase().contains(query),
            )
            .toList();

    return Scaffold(
      backgroundColor:
          dark ? AppColors.darkBackground : const Color(0xFFF5F7FB),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(
          'Monthly attendance',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor:
            dark ? AppColors.darkBackground : const Color(0xFFF5F7FB),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _monthSelector(dark),
            const SizedBox(height: 18),
            Text(
              'EMPLOYEES (${users.length})',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white54 : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose an employee to view their monthly attendance and daily check-in details.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: dark ? Colors.white54 : const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _employeeQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by name, email, or department',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _employeeQuery.isEmpty
                        ? null
                        : IconButton(
                          onPressed: () => setState(() => _employeeQuery = ''),
                          icon: const Icon(Icons.close_rounded),
                        ),
                filled: true,
                fillColor: dark ? AppColors.darkSurface : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color:
                        dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color:
                        dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_error != null)
              _MessageCard(
                message: _error!,
                actionLabel: 'Retry',
                onAction: _load,
                dark: dark,
              )
            else if (_loading && users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (users.isEmpty)
              _MessageCard(message: 'No active employees found.', dark: dark)
            else if (matches.isEmpty)
              _MessageCard(
                message: 'No employees match “$_employeeQuery”.',
                dark: dark,
              )
            else
              ...matches.map(
                (user) => _EmployeeRow(
                  user: user,
                  dark: dark,
                  onTap:
                      () => context.push(
                        RoutePaths.employeeMonthlyAttendance(user.id),
                        extra: _month,
                      ),
                ),
              ),
            if (_loading && users.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _monthSelector(bool dark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: dark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () => _moveMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _month,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (date != null)
                setState(() => _month = DateTime(date.year, date.month));
            },
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : const Color(0xFF101828),
                  ),
                ),
                Text(
                  'SELECT MONTH',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white54 : const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () => _moveMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _EmployeeRow extends StatelessWidget {
  final UserModel user;
  final bool dark;
  final VoidCallback onTap;
  const _EmployeeRow({
    required this.user,
    required this.dark,
    required this.onTap,
  });

  String _avatarUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = AppEnv.apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  @override
  Widget build(BuildContext context) {
    final name = user.name.trim();
    final photo = user.avatarUrl?.trim() ?? '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: dark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEEF0FF),
                backgroundImage:
                    photo.isEmpty ? null : NetworkImage(_avatarUrl(photo)),
                onBackgroundImageError: photo.isEmpty ? null : (_, __) {},
                child:
                    photo.isEmpty
                        ? Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF5B5BD6),
                            fontWeight: FontWeight.w800,
                          ),
                        )
                        : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Employee' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : const Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        user.department,
                        user.email,
                      ].where((item) => item.trim().isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: dark ? Colors.white54 : const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: dark ? Colors.white54 : const Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dark;
  const _MessageCard({
    required this.message,
    required this.dark,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: dark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
      ),
    ),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white70 : const Color(0xFF667085),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
