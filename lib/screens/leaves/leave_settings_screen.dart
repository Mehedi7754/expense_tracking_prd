import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../repositories/leave_repository.dart';
import '../../state/leave_provider.dart';
import '../../state/user_management_provider.dart';

const leaveTypes = [
  'casual',
  'sick',
  'emergency',
  'paid',
  'unpaid',
  'maternity',
];

Color _leaveTypeColor(String type) => switch (type) {
  'casual' => const Color(0xFF2563EB),
  'sick' => const Color(0xFF059669),
  'emergency' => const Color(0xFFD97706),
  'paid' => const Color(0xFF7C3AED),
  'unpaid' => const Color(0xFF475569),
  'maternity' => const Color(0xFFDB2777),
  _ => const Color(0xFF4F46E5),
};

class LeaveSettingsScreen extends ConsumerStatefulWidget {
  const LeaveSettingsScreen({super.key});

  @override
  ConsumerState<LeaveSettingsScreen> createState() =>
      _LeaveSettingsScreenState();
}

class _LeaveSettingsScreenState extends ConsumerState<LeaveSettingsScreen> {
  int _year = DateTime.now().year;
  String _search = '';
  String _type = 'all';
  String? _selectedUserId;
  String? _expandedUserId;
  List<LeaveAllowance> _allowances = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(userManagementProvider.notifier).fetchUsers();
      await ref.read(leaveProvider.notifier).fetchLeaves(force: true);
      final allowances = await ref
          .read(leaveRepositoryProvider)
          .getAllowances(year: _year);
      if (!mounted) return;
      setState(() {
        _allowances = allowances;
        _loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Leave settings could not be loaded.';
        });
    }
  }

  int _usedDays(String userId, String type) {
    final first = DateTime(_year);
    final last = DateTime(_year, 12, 31);
    return ref
        .read(leaveProvider)
        .leaves
        .where(
          (leave) =>
              leave.userId == userId &&
              leave.leaveType.toLowerCase() == type &&
              leave.isApproved &&
              !leave.isRejected,
        )
        .fold(0, (sum, leave) {
          final start = DateTime.tryParse(leave.startDate);
          final end = DateTime.tryParse(leave.endDate);
          if (start == null || end == null) return sum;
          final from = start.isBefore(first) ? first : start;
          final to = end.isAfter(last) ? last : end;
          return sum + (to.isBefore(from) ? 0 : to.difference(from).inDays + 1);
        });
  }

  Future<void> _edit(UserModel user, String type) async {
    final current =
        _allowances
            .where((item) => item.userId == user.id && item.leaveType == type)
            .firstOrNull;
    final controller = TextEditingController(
      text: current?.allowedDays.toString() ?? '',
    );
    final days = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '${user.name} · ${type[0].toUpperCase()}${type.substring(1)}',
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Allowed days in $_year',
                helperText: 'Enter 0 to allow no days.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(controller.text.trim());
                  if (value == null || value < 0 || value > 366) return;
                  Navigator.pop(context, value);
                },
                child: const Text('Save allowance'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (days == null || !mounted) return;
    try {
      final saved = await ref
          .read(leaveRepositoryProvider)
          .setAllowance(
            userId: user.id,
            year: _year,
            leaveType: type,
            allowedDays: days,
          );
      if (!mounted) return;
      setState(() {
        _allowances = [
          ..._allowances.where(
            (item) => item.userId != user.id || item.leaveType != type,
          ),
          saved,
        ];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Leave allowance saved.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save allowance. Please try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final users =
        ref
            .watch(userManagementProvider)
            .where((user) => user.isActive)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final filtered =
        users
            .where(
              (user) =>
                  (_selectedUserId == null || user.id == _selectedUserId) &&
                  (user.name.toLowerCase().contains(_search.toLowerCase()) ||
                      user.department.toLowerCase().contains(
                        _search.toLowerCase(),
                      )),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Settings')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Employee leave allowances',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set allowed days per employee, leave type, and calendar year.',
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search employee or department',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() => _year--);
                    _load();
                  },
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous year',
                ),
                Text(
                  '$_year',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _year++);
                    _load();
                  },
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next year',
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _type,
                  items:
                      ['all', ...leaveTypes]
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type == 'all' ? 'All types' : type),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _type = value ?? 'all'),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _selectedUserId ?? '',
              decoration: const InputDecoration(
                labelText: 'Employee',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All employees')),
                ...users.map(
                  (user) =>
                      DropdownMenuItem(value: user.id, child: Text(user.name)),
                ),
              ],
              onChanged:
                  (value) => setState(
                    () => _selectedUserId = value == '' ? null : value,
                  ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(_error!),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No employees match these filters.'),
              )
            else
              for (final user in filtered)
                Builder(
                  builder: (context) {
                    final expanded = _expandedUserId == user.id;
                    final configured =
                        _allowances
                            .where((item) => item.userId == user.id)
                            .length;
                    final used = leaveTypes.fold<int>(
                      0,
                      (sum, type) => sum + _usedDays(user.id, type),
                    );
                    return Card(
                      margin: const EdgeInsets.only(top: 10),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          InkWell(
                            onTap:
                                () => setState(
                                  () =>
                                      _expandedUserId =
                                          expanded ? null : user.id,
                                ),
                  child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 21,
                                    child: Text(
                                      user.name.isEmpty
                                          ? '?'
                                          : user.name[0].toUpperCase(),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                                          '${user.department} · $configured/${leaveTypes.length} allowances · $used days used',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                        ),
                                  AnimatedRotation(
                                    turns: expanded ? .5 : 0,
                                    duration: const Duration(milliseconds: 180),
                                    child: const Icon(
                                      Icons.expand_more_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child:
                                expanded
                                    ? Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        0,
                                        14,
                                        10,
                                      ),
                                      child: Column(
                                        children: [
                        for (final type in leaveTypes.where(
                                            (type) =>
                                                _type == 'all' || _type == type,
                        ))
                          Builder(
                            builder: (context) {
                              final allowance =
                                  _allowances
                                      .where(
                                        (item) =>
                                                              item.userId ==
                                                                  user.id &&
                                                              item.leaveType ==
                                                                  type,
                                      )
                                      .firstOrNull;
                                                final used = _usedDays(
                                                  user.id,
                                                  type,
                                                );
                              final color = _leaveTypeColor(type);
                              final allowed = allowance?.allowedDays;
                              final remaining = allowed == null
                                  ? null
                                  : (allowed - used).clamp(0, allowed);
                              return Card(
                                margin: const EdgeInsets.only(top: 8),
                                elevation: 0,
                                color: color.withValues(alpha: .07),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: color.withValues(alpha: .22)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
                                        child: Icon(Icons.event_available_rounded, color: color, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(type[0].toUpperCase() + type.substring(1), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                                            const SizedBox(height: 2),
                                            Text(allowed == null ? '$used days used · Not configured' : '$used used · $remaining remaining of $allowed', style: Theme.of(context).textTheme.bodySmall),
                                            if (allowed != null && allowed > 0) ...[
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: LinearProgressIndicator(value: (used / allowed).clamp(0, 1).toDouble(), minHeight: 4, color: color, backgroundColor: color.withValues(alpha: .14)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton.icon(
                                        onPressed: () => _edit(user, type),
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        label: const Text('Edit'),
                                        style: TextButton.styleFrom(foregroundColor: color),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                                    )
                                    : const SizedBox(width: double.infinity),
                  ),
                        ],
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}
