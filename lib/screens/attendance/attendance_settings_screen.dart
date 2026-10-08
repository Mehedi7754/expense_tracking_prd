import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../state/attendance_settings_provider.dart';
import '../../state/user_management_provider.dart';

class AttendanceSettingsScreen extends ConsumerStatefulWidget {
  const AttendanceSettingsScreen({super.key});

  @override
  ConsumerState<AttendanceSettingsScreen> createState() =>
      _AttendanceSettingsScreenState();
}

class _AttendanceSettingsScreenState
    extends ConsumerState<AttendanceSettingsScreen> {
  late String _deductionType;
  late bool _isDeductionEnabled;
  late double _fullDayDeductionAmount;
  late double _halfDayDeductionAmount;

  final TextEditingController _fullDayCtrl = TextEditingController();
  final TextEditingController _halfDayCtrl = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final settingsAsync = ref.read(attendanceSettingsProvider);
      final s = settingsAsync.value ?? const AttendanceSettingsState();
      _deductionType = s.deductionType;
      _isDeductionEnabled = s.isDeductionEnabled;
      _fullDayDeductionAmount = s.fullDayDeductionAmount;
      _halfDayDeductionAmount = s.halfDayDeductionAmount;
      _fullDayCtrl.text = _fullDayDeductionAmount.toStringAsFixed(1);
      _halfDayCtrl.text = _halfDayDeductionAmount.toStringAsFixed(1);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _fullDayCtrl.dispose();
    _halfDayCtrl.dispose();
    super.dispose();
  }

  String _hourLabel(int h) {
    final period = h < 12 ? 'AM' : 'PM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:00 $period';
  }

  String _dayShort(int dayIndex) {
    switch (dayIndex) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Future<void> _saveDeductions() async {
    setState(() => _saving = true);
    final fullVal = double.tryParse(_fullDayCtrl.text) ?? _fullDayDeductionAmount;
    final halfVal = double.tryParse(_halfDayCtrl.text) ?? _halfDayDeductionAmount;

    final currentSettings = ref.read(attendanceSettingsProvider).value ?? const AttendanceSettingsState();
    final updated = currentSettings.copyWith(
      deductionType: _deductionType,
      isDeductionEnabled: _isDeductionEnabled,
      fullDayDeductionAmount: fullVal,
      halfDayDeductionAmount: halfVal,
    );

    await ref.read(attendanceSettingsProvider.notifier).updateSettings(updated);
    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salary Deduction & Payroll Rules Saved!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showShiftDialog({AttendanceShift? existingShift}) {
    final isEditing = existingShift != null;
    final nameCtrl = TextEditingController(text: existingShift?.name ?? 'New Shift');
    int startH = existingShift?.morningStartHour ?? 9;
    int cutoffH = existingShift?.morningEndHour ?? 13;
    int endH = existingShift?.afternoonEndHour ?? 18;
    List<int> weekendDays = List<int>.from(existingShift?.weekendDays ?? [5, 6]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Shift Schedule' : 'Create New Shift',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      if (isEditing && !existingShift.isDefault)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete Shift',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteShift(existingShift);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Shift Name Input
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Shift Name',
                      hintText: 'e.g. Morning Shift / Remote Shift',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withAlpha(50)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Shift Timing & Session Split',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  // Timing Pickers: From Time & To Time
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4F46E5).withAlpha(40)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('From (Start)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: startH,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  items: List.generate(12, (i) => i + 5).map((h) {
                                    return DropdownMenuItem<int>(
                                      value: h,
                                      child: Text(_hourLabel(h)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDlgState(() {
                                        startH = val;
                                        if (cutoffH <= startH) cutoffH = startH + 4;
                                        if (endH <= cutoffH) endH = cutoffH + 4;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withAlpha(40)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('To (End)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: endH,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  items: List.generate(14, (i) => i + 11).map((h) {
                                    return DropdownMenuItem<int>(
                                      value: h,
                                      child: Text(_hourLabel(h)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDlgState(() {
                                        endH = val;
                                        if (cutoffH >= endH) cutoffH = endH - 2;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Session Cutoff Point
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6366F1).withAlpha(30)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Session Cutoff Time', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              Text('Separates Morning & Afternoon punch', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: cutoffH,
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6366F1), fontSize: 14),
                            items: List.generate(10, (i) => i + 9).map((h) {
                              return DropdownMenuItem<int>(
                                value: h,
                                child: Text(_hourLabel(h)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() => cutoffH = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Weekend / Off-Days for this Shift
                  const Text(
                    'Shift Weekly Off-Days',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(7, (idx) {
                      final dayIdx = idx + 1;
                      final isSelected = weekendDays.contains(dayIdx);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(_dayShort(dayIdx)),
                        selectedColor: const Color(0xFF4F46E5),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (val) {
                          setDlgState(() {
                            if (val) {
                              if (!weekendDays.contains(dayIdx)) weekendDays.add(dayIdx);
                            } else {
                              weekendDays.remove(dayIdx);
                            }
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;

                            final shift = AttendanceShift(
                              id: isEditing ? existingShift.id : 'shift_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              morningStartHour: startH,
                              morningEndHour: cutoffH,
                              afternoonStartHour: cutoffH,
                              afternoonEndHour: endH,
                              weekendDays: weekendDays.isEmpty ? const [5, 6] : weekendDays,
                              isDefault: isEditing ? existingShift.isDefault : false,
                            );

                            ref.read(attendanceSettingsProvider.notifier).addOrUpdateShift(shift);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isEditing ? 'Save Changes' : 'Create Shift', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteShift(AttendanceShift shift) {
    if (shift.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the default shift!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${shift.name}"?'),
        content: const Text(
          'Deleting this shift will automatically reassign all affected employees to the Default Shift.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(attendanceSettingsProvider.notifier).deleteShift(shift.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Shift "${shift.name}" deleted and users reassigned.'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsAsync = ref.watch(attendanceSettingsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'Shift & Attendance Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
        data: (settings) {
          final users = ref.watch(userManagementProvider);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Shift & Schedule Management',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Each shift controls its own From / Cutoff / To hours and specific weekly off-days, assigned individually to employees.',
                        style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // SECTION 1: Configured Shifts
                _buildCardContainer(
                  isDark: isDark,
                  title: '1. Configured Shifts (${settings.shifts.length})',
                  subtitle: 'Manage working hours, session cutoff times, and weekly rest days per shift.',
                  child: Column(
                    children: [
                      ...settings.shifts.map((shift) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: shift.isDefault
                                  ? const Color(0xFF4F46E5).withAlpha(80)
                                  : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                              width: shift.isDefault ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    shift.isDefault ? Icons.star_rounded : Icons.schedule_rounded,
                                    color: const Color(0xFF4F46E5),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      shift.name,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                  ),
                                  if (shift.isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withAlpha(30),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Default Shift', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _showShiftDialog(existingShift: shift),
                                    tooltip: 'Edit Shift',
                                  ),
                                  if (!shift.isDefault)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      onPressed: () => _confirmDeleteShift(shift),
                                      tooltip: 'Delete Shift',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _sessionChip(
                                      '☀️ Morning',
                                      '${_hourLabel(shift.morningStartHour)} – ${_hourLabel(shift.morningEndHour)}',
                                      const Color(0xFF4F46E5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _sessionChip(
                                      '🌙 Afternoon',
                                      '${_hourLabel(shift.morningEndHour)} – ${_hourLabel(shift.afternoonEndHour)}',
                                      const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Off-Days: ${shift.weekendDays.isEmpty ? 'None' : shift.weekendDays.map((d) => _dayShort(d)).join(', ')}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showShiftDialog(),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Add Custom Shift', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // SECTION 2: Employee Shift Assignments
                _buildCardContainer(
                  isDark: isDark,
                  title: '2. Employee Shift Assignment',
                  subtitle: 'Assign specific shifts to team members. Each employee follows their assigned shift schedule.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (users.isEmpty)
                        const Text('No employees found to assign.', style: TextStyle(fontSize: 12, color: Colors.grey))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => const Divider(height: 12),
                          itemBuilder: (ctx, idx) {
                            final user = users[idx];
                            final assignedShiftId = settings.userShifts[user.id] ?? 'shift_default';
                            final currentShift = settings.getShiftForUser(user.id);

                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF4F46E5).withAlpha(30),
                                  child: Text(
                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text(
                                        '${user.role.displayName} • Off: ${currentShift.weekendDays.map((d) => _dayShort(d)).join('/')}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: settings.shifts.any((s) => s.id == assignedShiftId) ? assignedShiftId : 'shift_default',
                                      isDense: true,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      items: settings.shifts.map((s) {
                                        return DropdownMenuItem<String>(
                                          value: s.id,
                                          child: Text(s.name),
                                        );
                                      }).toList(),
                                      onChanged: (newShiftId) {
                                        if (newShiftId != null) {
                                          ref.read(attendanceSettingsProvider.notifier).assignUserShift(user.id, newShiftId);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // SECTION 3: Salary Deduction Options
                _buildCardContainer(
                  isDark: isDark,
                  title: '3. Salary Deduction Rules',
                  subtitle: 'Configure automatic payroll cuts for missed sign-outs and unexcused absences.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Master Deduction Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: _isDeductionEnabled
                              ? (isDark ? const Color(0xFF064E3B).withAlpha(40) : const Color(0xFFF0FDF4))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isDeductionEnabled
                                ? const Color(0xFF10B981).withAlpha(80)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          title: Text(
                            'Enable Salary Deductions',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            _isDeductionEnabled
                                ? 'Active: Missed morning or evening sign-outs will apply salary deductions.'
                                : 'Turned OFF: No salary deductions will be applied for attendance misses.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                          value: _isDeductionEnabled,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (val) => setState(() => _isDeductionEnabled = val),
                        ),
                      ),

                      if (!_isDeductionEnabled) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3B82F6).withAlpha(40)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Color(0xFF3B82F6), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Salary deductions are turned OFF. Employees will receive 100% of their base salary regardless of attendance punch records.',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Deduction Calculation Mode',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _deductionType = 'rate_based'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _deductionType == 'rate_based'
                                        ? const Color(0xFF4F46E5).withAlpha(isDark ? 50 : 20)
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _deductionType == 'rate_based'
                                          ? const Color(0xFF4F46E5)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      width: _deductionType == 'rate_based' ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _deductionType == 'rate_based' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                            size: 16,
                                            color: _deductionType == 'rate_based' ? const Color(0xFF4F46E5) : Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('Rate-Based', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Daily salary multiplier (e.g. 0.5 = 50% cut)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _deductionType = 'fixed_amount'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _deductionType == 'fixed_amount'
                                        ? const Color(0xFF4F46E5).withAlpha(isDark ? 50 : 20)
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _deductionType == 'fixed_amount'
                                          ? const Color(0xFF4F46E5)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      width: _deductionType == 'fixed_amount' ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _deductionType == 'fixed_amount' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                            size: 16,
                                            color: _deductionType == 'fixed_amount' ? const Color(0xFF4F46E5) : Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('Fixed Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fixed BDT amount (e.g. ৳500 per miss)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Inputs for Half Day & Full Day
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _deductionType == 'rate_based' ? 'Half Day / Missed Sign-out' : 'Half Day Deduction',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _deductionType == 'rate_based' ? 'Default 0.5 (50% day pay)' : 'Fixed ৳ cut per miss',
                                    style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _halfDayCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: _deductionType == 'rate_based' ? '0.5' : '500',
                                      prefixText: _deductionType == 'rate_based' ? '' : '৳ ',
                                      suffixText: _deductionType == 'rate_based' ? ' days' : '',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _deductionType == 'rate_based' ? 'Full Day Absence' : 'Full Day Deduction',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _deductionType == 'rate_based' ? 'Default 1.0 (100% day pay)' : 'Fixed ৳ cut for absent',
                                    style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _fullDayCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: _deductionType == 'rate_based' ? '1.0' : '1000',
                                      prefixText: _deductionType == 'rate_based' ? '' : '৳ ',
                                      suffixText: _deductionType == 'rate_based' ? ' days' : '',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Save Payroll Rules Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saving ? null : _saveDeductions,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Save Payroll Deduction Rules',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _sessionChip(String label, String time, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: color)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(time, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
