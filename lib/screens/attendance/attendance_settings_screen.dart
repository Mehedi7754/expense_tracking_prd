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
  late int _gracePeriodMinutes;

  final TextEditingController _fullDayCtrl = TextEditingController();
  final TextEditingController _halfDayCtrl = TextEditingController();
  final TextEditingController _gracePeriodCtrl = TextEditingController();
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
      _gracePeriodMinutes = s.gracePeriodMinutes;
      _fullDayCtrl.text = _fullDayDeductionAmount.toStringAsFixed(1);
      _halfDayCtrl.text = _halfDayDeductionAmount.toStringAsFixed(1);
      _gracePeriodCtrl.text = _gracePeriodMinutes.toString();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _fullDayCtrl.dispose();
    _halfDayCtrl.dispose();
    _gracePeriodCtrl.dispose();
    super.dispose();
  }

  String _hourLabel(int h) {
    final cleanH = ((h % 24) + 24) % 24;
    final period = cleanH < 12 ? 'AM' : 'PM';
    final displayH = cleanH == 0 ? 12 : (cleanH > 12 ? cleanH - 12 : cleanH);
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
    final graceVal = int.tryParse(_gracePeriodCtrl.text) ?? _gracePeriodMinutes;

    final currentSettings = ref.read(attendanceSettingsProvider).value ?? const AttendanceSettingsState();
    final updated = currentSettings.copyWith(
      deductionType: _deductionType,
      isDeductionEnabled: _isDeductionEnabled,
      fullDayDeductionAmount: fullVal,
      halfDayDeductionAmount: halfVal,
      gracePeriodMinutes: graceVal,
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
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
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
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Shift Schedule' : 'Create Custom Shift',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (isEditing && !existingShift.isDefault)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Shift Title',
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      hintText: 'e.g. Early Morning / Remote Shift',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Shift Working Hours',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Timing Pickers: From Time & To Time
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Shift Start (From)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                              const SizedBox(height: 2),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: startH,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  items: List.generate(24, (h) => h).map((h) {
                                    return DropdownMenuItem<int>(
                                      value: h,
                                      child: Text(_hourLabel(h)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDlgState(() {
                                        startH = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Shift End (To)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                              const SizedBox(height: 2),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: endH,
                                  isExpanded: true,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  items: List.generate(24, (h) => h).map((h) {
                                    return DropdownMenuItem<int>(
                                      value: h,
                                      child: Text(_hourLabel(h)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDlgState(() {
                                        endH = val;
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Session Cutoff Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Splits Morning & Afternoon punch sessions',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: cutoffH,
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), fontSize: 14),
                            items: List.generate(24, (h) => h).map((h) {
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
                  const SizedBox(height: 20),

                  // Weekend / Off-Days for this Shift
                  Text(
                    'Shift Weekly Off-Days',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (idx) {
                      final dayIdx = idx + 1;
                      final isSelected = weekendDays.contains(dayIdx);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(_dayShort(dayIdx)),
                        selectedColor: const Color(0xFF4F46E5),
                        checkmarkColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
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
                  const SizedBox(height: 26),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
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
                              weekendDays: weekendDays,
                              isDefault: isEditing ? existingShift.isDefault : false,
                            );

                            ref.read(attendanceSettingsProvider.notifier).addOrUpdateShift(shift);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(isEditing ? 'Save Changes' : 'Create Shift', style: const TextStyle(fontWeight: FontWeight.w800)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${shift.name}"?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text(
          'Deleting this shift will automatically reassign all affected employees to the Default Shift.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            child: const Text('Delete Shift', style: TextStyle(fontWeight: FontWeight.w800)),
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
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Shift & Attendance Settings',
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildStickySaveButton(isDark),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading settings: $e')),
        data: (settings) {
          final users = ref.watch(userManagementProvider);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                          : [const Color(0xFFEEF2FF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.4 : 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF4F46E5), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Shift & Schedule Management',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Each shift controls its own From / Cutoff / To hours and specific weekly off-days, assigned individually to employees.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          fontSize: 12,
                          height: 1.4,
                        ),
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
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: shift.isDefault
                                  ? const Color(0xFF4F46E5).withValues(alpha: 0.5)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: shift.isDefault ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.black : const Color(0xFF64748B)).withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Shift Header: Name + Badge on Left, Action buttons on Right
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      shift.isDefault ? Icons.auto_awesome_rounded : Icons.schedule_rounded,
                                      color: const Color(0xFF4F46E5),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          shift.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.5,
                                            letterSpacing: -0.2,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (shift.isDefault)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Default',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        onPressed: () => _showShiftDialog(existingShift: shift),
                                        tooltip: 'Edit Shift',
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: const EdgeInsets.all(6),
                                      ),
                                      if (!shift.isDefault)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                          onPressed: () => _confirmDeleteShift(shift),
                                          tooltip: 'Delete Shift',
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          padding: const EdgeInsets.all(6),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Timing summary banner
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Timing: ${_hourLabel(shift.morningStartHour)} → ${_hourLabel(shift.afternoonEndHour)} • Midday Cutoff: ${_hourLabel(shift.morningEndHour)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (ctx, constraints) {
                                  final isCompact = constraints.maxWidth < 360;
                                  final morning = _sessionChip(
                                    '☀️ Morning Slot',
                                    '${_hourLabel(shift.morningStartHour)} – ${_hourLabel(shift.morningEndHour)}',
                                    const Color(0xFF4F46E5),
                                    isDark: isDark,
                                  );
                                  final afternoon = _sessionChip(
                                    '🌙 Afternoon Slot',
                                    '${_hourLabel(shift.morningEndHour)} – ${_hourLabel(shift.afternoonEndHour)}',
                                    const Color(0xFF10B981),
                                    isDark: isDark,
                                  );

                                  if (isCompact) {
                                    return Column(
                                      children: [
                                        morning,
                                        const SizedBox(height: 8),
                                        afternoon,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: morning),
                                      const SizedBox(width: 8),
                                      Expanded(child: afternoon),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.beach_access_rounded,
                                    size: 13,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Off-Days:',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: shift.weekendDays.isEmpty
                                        ? Text(
                                            'None',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                            ),
                                          )
                                        : Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: shift.weekendDays.map((d) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF334155)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  _dayShort(d),
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showShiftDialog(),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                          label: const Text('Add Custom Shift', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // SECTION 2: Salary Deduction Options (Moved to Section 2)
                _buildCardContainer(
                  isDark: isDark,
                  title: '2. Salary Deduction Rules',
                  subtitle: 'Configure automatic payroll cuts for missed sign-outs and unexcused absences.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Master Deduction Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: _isDeductionEnabled
                              ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFF0FDF4))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isDeductionEnabled
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          title: Text(
                            'Enable Salary Deductions',
                            style: TextStyle(
                              fontSize: 13.5,
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
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Color(0xFF3B82F6), size: 18),
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
                        Text(
                          'Deduction Calculation Mode',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
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
                                        ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.35 : 0.12)
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
                                            size: 15,
                                            color: _deductionType == 'rate_based' ? const Color(0xFF4F46E5) : Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('Rate-Based', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Daily multiplier (e.g. 0.5 = 50% cut)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                                        ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.35 : 0.12)
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
                                            size: 15,
                                            color: _deductionType == 'fixed_amount' ? const Color(0xFF4F46E5) : Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('Fixed Amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fixed BDT amount (e.g. ৳500)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _deductionType == 'rate_based' ? 'Default 0.5 (50% day pay)' : 'Fixed ৳ cut per miss',
                                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _halfDayCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _deductionType == 'rate_based' ? '0.5' : '500',
                                      prefixText: _deductionType == 'rate_based' ? '' : '৳ ',
                                      suffixText: _deductionType == 'rate_based' ? ' days' : '',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      ),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _deductionType == 'rate_based' ? 'Default 1.0 (100% day pay)' : 'Fixed ৳ cut for absent',
                                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _fullDayCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _deductionType == 'rate_based' ? '1.0' : '1000',
                                      prefixText: _deductionType == 'rate_based' ? '' : '৳ ',
                                      suffixText: _deductionType == 'rate_based' ? ' days' : '',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      ),
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        
                        // Grace Period Input
                        Text(
                          'Late Check-in Grace Period',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Minutes allowed after shift start before marked as LATE (Default: 15)',
                          style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: TextField(
                            controller: _gracePeriodCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: '15',
                              suffixText: ' minutes',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // SECTION 3: Employee Shift Assignments (Moved to Section 3)
                _buildCardContainer(
                  isDark: isDark,
                  title: '3. Employee Shift Assignment',
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
                          separatorBuilder: (_, __) => const Divider(height: 14),
                          itemBuilder: (ctx, idx) {
                            final user = users[idx];
                            final assignedShiftId = settings.userShifts[user.id] ?? 'shift_default';
                            final currentShift = settings.getShiftForUser(user.id);

                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
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
                                      Text(
                                        user.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        '${user.role.displayName} • Off: ${currentShift.weekendDays.map((d) => _dayShort(d)).join('/')}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: settings.shifts.any((s) => s.id == assignedShiftId) ? assignedShiftId : 'shift_default',
                                      isDense: true,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              letterSpacing: -0.2,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _sessionChip(String label, String time, Color color, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: color),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickySaveButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveDeductions,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle_rounded, size: 20),
        label: Text(
          _saving ? 'Saving...' : 'Save Settings',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
