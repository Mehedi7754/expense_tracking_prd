import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import 'leave_applicant_avatar.dart';
import '../../core/widgets/app_back_button.dart';
import '../../models/leave_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/leave_provider.dart';
import '../../state/user_management_provider.dart';
import '../../repositories/leave_repository.dart';

class LeaveManagementScreen extends ConsumerStatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  ConsumerState<LeaveManagementScreen> createState() =>
      _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends ConsumerState<LeaveManagementScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _showAllRecords = false;
  String? _selectedEmployeeId;
  List<LeaveAllowance> _allowances = const [];
  bool _allowancesLoading = true;
  String? _allowancesError;

  Future<void> _loadAllowances() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;
    setState(() {
      _allowancesLoading = true;
      _allowancesError = null;
    });
    try {
      final records = await ref
          .read(leaveRepositoryProvider)
          .getAllowances(
            year: _selectedMonth.year,
            userId: user.role.canApproveMembers ? null : user.id,
          );
      if (mounted)
        setState(() {
          _allowances = records;
          _allowancesLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _allowancesLoading = false;
          _allowancesError = 'Allowances could not be loaded.';
        });
    }
  }

  int _usedInYear(List<LeaveRecordModel> leaves, String userId, String type) {
    final first = DateTime(_selectedMonth.year);
    final last = DateTime(_selectedMonth.year, 12, 31);
    return leaves
        .where(
          (leave) =>
              leave.userId == userId &&
              leave.leaveType.toLowerCase() == type &&
              leave.isApproved &&
              !leave.isRejected,
        )
        .fold<int>(0, (sum, leave) {
          final start = DateTime.tryParse(leave.startDate);
          final end = DateTime.tryParse(leave.endDate);
          if (start == null || end == null) return sum;
          final from = start.isBefore(first) ? first : start;
          final to = end.isAfter(last) ? last : end;
          return sum + (to.isBefore(from) ? 0 : to.difference(from).inDays + 1);
        });
  }

  int? _allowed(String userId, String type) =>
      _allowances
          .where((item) => item.userId == userId && item.leaveType == type)
          .firstOrNull
          ?.allowedDays;

  void _moveMonth(int offset) {
    final previousYear = _selectedMonth.year;
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
      _showAllRecords = false;
    });
    if (_selectedMonth.year != previousYear) _loadAllowances();
  }

  int _daysInMonth(LeaveRecordModel leave) {
    final start = DateTime.tryParse(leave.startDate);
    final end = DateTime.tryParse(leave.endDate);
    if (start == null || end == null || end.isBefore(start)) return 0;
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final first = start.isBefore(_selectedMonth) ? _selectedMonth : start;
    final last = end.isAfter(monthEnd) ? monthEnd : end;
    return last.isBefore(first) ? 0 : last.difference(first).inDays + 1;
  }

  String get _monthLabel {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaveProvider.notifier).fetchLeaves(force: true);
      _loadAllowances();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final leaveState = ref.watch(leaveProvider);
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final users =
        ref
            .watch(userManagementProvider)
            .where((employee) => employee.isActive)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final balanceEmployeeId =
        user?.role.canApproveMembers == true ? _selectedEmployeeId : user?.id;
    final balanceEmployeeName =
        balanceEmployeeId == null
            ? null
            : users
                    .where((employee) => employee.id == balanceEmployeeId)
                    .firstOrNull
                    ?.name ??
                leaveState.leaves
                    .where((leave) => leave.userId == balanceEmployeeId)
                    .firstOrNull
                    ?.userName ??
                user?.name;
    final canApplyLeave = user != null && user.role != UserRole.mainAdmin;

    final employeeLeaves =
        leaveState.leaves
            .where(
              (leave) =>
                  _selectedEmployeeId == null ||
                  leave.userId == _selectedEmployeeId,
            )
            .toList();
    final monthlyLeaves =
        employeeLeaves.where((leave) => _daysInMonth(leave) > 0).toList();
    final filtered =
        monthlyLeaves
            .where(
              (leave) => switch (leaveState.activeFilter) {
                'approved' => leave.isApproved,
                'pending' => leave.isPending,
                'rejected' => leave.isRejected,
                _ => true,
              },
            )
            .toList();
    final displayed = _showAllRecords ? filtered : filtered.take(4).toList();
    final approvedDays = monthlyLeaves
        .where((leave) => leave.isApproved)
        .fold<int>(0, (sum, leave) => sum + _daysInMonth(leave));
    final requestedDays = monthlyLeaves.fold<int>(
      0,
      (sum, leave) => sum + _daysInMonth(leave),
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          'Leave Management',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          if (user?.role == UserRole.mainAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Leave allowance settings',
              onPressed: () async {
                await context.push(RoutePaths.leaveSettings);
                if (mounted) _loadAllowances();
              },
            ),
          if (canApplyLeave)
            IconButton(
              icon: const Icon(
                CupertinoIcons.plus_circle_fill,
                color: Color(0xFF2563EB),
              ),
              tooltip: 'Apply for Leave',
              onPressed: () => context.push(RoutePaths.applyLeave),
            ),
        ],
      ),
      floatingActionButton:
          canApplyLeave
              ? FloatingActionButton.extended(
                onPressed: () => context.push(RoutePaths.applyLeave),
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                icon: const Icon(CupertinoIcons.plus, size: 18),
                label: const Text(
                  'Apply Leave',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              )
              : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(leaveProvider.notifier).fetchLeaves(force: true);
          await _loadAllowances();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Annual balances belong to one employee, never the whole team.
              if (user?.role.canApproveMembers == true) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Employee balance',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Select employee'),
                    ),
                    ...users.map(
                      (employee) => DropdownMenuItem(
                        value: employee.id,
                        child: Text(employee.name),
                      ),
                    ),
                  ],
                  onChanged:
                      (value) => setState(() {
                        _selectedEmployeeId = value == '' ? null : value;
                        _showAllRecords = false;
                      }),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                balanceEmployeeName == null
                    ? 'EMPLOYEE LEAVE BALANCE'
                    : '${balanceEmployeeName.toUpperCase()} · ${_selectedMonth.year} BALANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color:
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Approved days used in the calendar year. Allowances are set per employee in Leave Settings.',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),

              if (balanceEmployeeId == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Select an employee to see their allowed, used, and remaining leave days.',
                    ),
                  ),
                )
              else if (_allowancesLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_allowancesError != null)
                  TextButton.icon(
                    onPressed: _loadAllowances,
                    icon: const Icon(Icons.refresh),
                    label: Text(_allowancesError!),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceCard(
                        title: 'Casual Leave',
                        usedDays: _usedInYear(
                          leaveState.leaves,
                          balanceEmployeeId,
                          'casual',
                        ),
                        totalAllowance: _allowed(balanceEmployeeId, 'casual'),
                        color: const Color(0xFF2563EB),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBalanceCard(
                        title: 'Medical / Sick',
                        usedDays: _usedInYear(
                          leaveState.leaves,
                          balanceEmployeeId,
                          'sick',
                        ),
                        totalAllowance: _allowed(balanceEmployeeId, 'sick'),
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceCard(
                        title: 'Emergency',
                        usedDays: _usedInYear(
                          leaveState.leaves,
                          balanceEmployeeId,
                          'emergency',
                        ),
                        totalAllowance: _allowed(
                          balanceEmployeeId,
                          'emergency',
                        ),
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBalanceCard(
                        title: 'Unpaid Leave',
                        usedDays: _usedInYear(
                          leaveState.leaves,
                          balanceEmployeeId,
                          'unpaid',
                        ),
                        totalAllowance: _allowed(balanceEmployeeId, 'unpaid'),
                        color: const Color(0xFF8B5CF6),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceCard(
                        title: 'Paid Leave',
                        usedDays: _usedInYear(
                          leaveState.leaves,
                          balanceEmployeeId,
                          'paid',
                        ),
                        totalAllowance: _allowed(balanceEmployeeId, 'paid'),
                        color: const Color(0xFF0EA5E9),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBalanceCard(
                        title: 'Maternity',
                        usedDays: _usedInYear(
                          leaveState.leaves,
                          balanceEmployeeId,
                          'maternity',
                        ),
                        totalAllowance: _allowed(
                          balanceEmployeeId,
                          'maternity',
                        ),
                        color: const Color(0xFFEC4899),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              Text(
                'Past Leave Records',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Leave history and clarification messages',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _moveMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                  ),
                  Text(
                    _monthLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _moveMonth(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildBalanceCard(
                      title: 'Requests',
                      usedDays: monthlyLeaves.length,
                      totalAllowance: null,
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                      unit: 'requests',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBalanceCard(
                      title: 'Requested days',
                      usedDays: requestedDays,
                      totalAllowance: null,
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBalanceCard(
                      title: 'Approved days',
                      usedDays: approvedDays,
                      totalAllowance: null,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (leaveState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                      title: const Text(
                        'Could not load leave records',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed:
                            () => ref
                                .read(leaveProvider.notifier)
                                .fetchLeaves(force: true),
                        child: const Text('Retry'),
                      ),
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'all',
                      'All (${monthlyLeaves.length})',
                      leaveState.activeFilter,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'approved',
                      'Approved (${monthlyLeaves.where((l) => l.isApproved).length})',
                      leaveState.activeFilter,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'pending',
                      'Pending (${monthlyLeaves.where((l) => l.isPending).length})',
                      leaveState.activeFilter,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'rejected',
                      'Declined (${monthlyLeaves.where((l) => l.isRejected).length})',
                      leaveState.activeFilter,
                      isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. LEAVE REQUESTS LIST
              if (leaveState.isLoading && leaveState.leaves.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.calendar,
                          size: 28,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No leave records found',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leaveState.activeFilter == 'all'
                            ? 'You have not submitted any leave applications yet.'
                            : 'No leave applications match the selected status.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (canApplyLeave) const SizedBox(height: 16),
                      if (canApplyLeave)
                        ElevatedButton.icon(
                          onPressed: () => context.push(RoutePaths.applyLeave),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(CupertinoIcons.plus, size: 14),
                          label: const Text(
                            'Apply for Leave',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                ...displayed.map(
                  (leave) => _buildLeaveCard(
                    leave,
                    isDark,
                    user?.role.canApproveMembers == true,
                  ),
                ),
              if (filtered.length > 4)
                Center(
                  child: TextButton.icon(
                    onPressed:
                        () =>
                            setState(() => _showAllRecords = !_showAllRecords),
                    icon: Icon(
                      _showAllRecords ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      _showAllRecords
                          ? 'Show less'
                          : 'View all ${filtered.length} records',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String id,
    String label,
    String activeId,
    bool isDark,
  ) {
    final isSelected = id == activeId;
    return InkWell(
      onTap: () => ref.read(leaveProvider.notifier).setFilter(id),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color:
                isSelected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required int usedDays,
    required int? totalAllowance,
    required Color color,
    required bool isDark,
    String unit = 'days',
  }) {
    final remaining = totalAllowance == null ? null : totalAllowance - usedDays;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$usedDays',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (totalAllowance != null) ...[
                Text(
                  ' / $totalAllowance days',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
              ] else ...[
                Text(
                  ' $unit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
          if (remaining != null) ...[
            const SizedBox(height: 2),
            Text(
              '$remaining days remaining',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
          if (totalAllowance == null)
            const Text(
              'Allowance not set',
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRecordModel leave, bool isDark, bool canApprove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(RoutePaths.leaveDetail(leave.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    LeaveApplicantAvatar(
                      name: leave.userName,
                      imageUrl: leave.userAvatarUrl,
                      radius: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leave.userName.isEmpty
                                ? 'Employee'
                                : leave.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                          if (leave.userEmail.isNotEmpty)
                            Text(
                              leave.userEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.calendar,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    leave.typeDisplayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      leave.isApproved
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : leave.isRejected
                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      leave.isApproved
                          ? CupertinoIcons.checkmark_seal_fill
                          : leave.isRejected
                          ? CupertinoIcons.xmark_circle_fill
                          : CupertinoIcons.clock_fill,
                      size: 11,
                      color:
                          leave.isApproved
                              ? const Color(0xFF10B981)
                              : leave.isRejected
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      leave.statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color:
                            leave.isApproved
                                ? const Color(0xFF10B981)
                                : leave.isRejected
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                CupertinoIcons.time,
                size: 12,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                '${leave.startDate} → ${leave.endDate}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${leave.totalDays} ${leave.totalDays == 1 ? "Day" : "Days"}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                leave.reason,
                style: TextStyle(
                  fontSize: 11,
                  color:
                      isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                ),
              ),
            ),
          ],
          if (canApprove && leave.isPending) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final ok = await ref
                        .read(leaveProvider.notifier)
                        .decideLeave(leave.id, approved: false);
                    if (mounted && !ok) _showLeaveError();
                  },
                  icon: const Icon(CupertinoIcons.xmark, size: 14),
                  label: const Text('Decline'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await ref
                        .read(leaveProvider.notifier)
                        .decideLeave(leave.id, approved: true);
                    if (mounted && !ok) _showLeaveError();
                  },
                  icon: const Icon(CupertinoIcons.checkmark, size: 14),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showLeaveError() {
    final message =
        ref.read(leaveProvider).errorMessage ??
        'Could not update leave request.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
