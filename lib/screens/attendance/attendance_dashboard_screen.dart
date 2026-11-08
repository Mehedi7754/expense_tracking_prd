import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/attendance_model.dart';
import '../../models/user_role.dart';
import '../../state/attendance_provider.dart';
import '../../repositories/attendance_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/attendance_settings_provider.dart';
import '../../state/user_management_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'my_attendance_screen.dart';
import 'widgets/attendance_map_view.dart';
import 'widgets/member_geo_location_modal.dart';

class AttendanceDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  ConsumerState<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState
    extends ConsumerState<AttendanceDashboardScreen> {
  bool _showMap = false;
  String _statusFilter = 'all'; // all, present, half_day, missing
  String _locationFilter =
      'all'; // all, office, home, home_office, field, unrecorded

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userManagementProvider.notifier).fetchUsers();
      ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
      ref.read(attendanceProvider.notifier).fetchAttendanceRecords(force: true);
    });
  }

  void _changeDate(int dayDelta) {
    final state = ref.read(attendanceProvider);
    final current = DateTime.tryParse(state.selectedDate) ?? DateTime.now();
    final newDate = current.add(Duration(days: dayDelta));
    final str = DateFormat('yyyy-MM-dd').format(newDate);
    ref.read(attendanceProvider.notifier).setSelectedDate(str);
  }

  Future<void> _pickDate() async {
    final state = ref.read(attendanceProvider);
    final current = DateTime.tryParse(state.selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final str = DateFormat('yyyy-MM-dd').format(picked);
      ref.read(attendanceProvider.notifier).setSelectedDate(str);
    }
  }

  void _showOverrideAttendanceModal() {
    final allUsers = ref.read(userManagementProvider);
    final selectedUserIds = <String>{};
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    String status = 'present';
    String workMode = 'office';
    bool skipWeekends = true;
    bool skipHolidays = true;
    String searchFilter = '';
    final notesCtrl = TextEditingController(text: 'Admin attendance adjustment');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final filteredUsers = allUsers.where((u) {
            if (searchFilter.isEmpty) return true;
            final query = searchFilter.toLowerCase();
            return u.name.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query) ||
                u.department.toLowerCase().contains(query);
          }).toList();

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 20,
              left: 20,
              right: 20,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Override Attendance',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Date range override with off-day & holiday protection',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Employee multi-select section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target Employees (${selectedUserIds.length}/${allUsers.length})',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedUserIds.clear();
                                selectedUserIds.addAll(allUsers.map((u) => u.id));
                              });
                            },
                            child: const Text('All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                          ),
                          const SizedBox(width: 8),
                          Text('|', style: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setModalState(() => selectedUserIds.clear()),
                            child: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (val) => setModalState(() => searchFilter = val),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search employee by name, email, department...',
                      hintStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filteredUsers.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      itemBuilder: (ctx, idx) {
                        final u = filteredUsers[idx];
                        final isSelected = selectedUserIds.contains(u.id);
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                selectedUserIds.remove(u.id);
                              } else {
                                selectedUserIds.add(u.id);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: isSelected,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          selectedUserIds.add(u.id);
                                        } else {
                                          selectedUserIds.remove(u.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: isDark ? Colors.white : Colors.black87)),
                                      Text('${u.department} • ${u.email}', style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white54 : Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date range pickers
                  Text('Date Range', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: startDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) {
                              setModalState(() {
                                startDate = d;
                                if (endDate.isBefore(startDate)) endDate = startDate;
                              });
                            }
                          },
                          icon: const Icon(Icons.date_range, size: 14),
                          label: Text('From: ${DateFormat('yyyy-MM-dd').format(startDate)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setModalState(() => endDate = d);
                          },
                          icon: const Icon(Icons.date_range, size: 14),
                          label: Text('To: ${DateFormat('yyyy-MM-dd').format(endDate)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Status and WorkMode dropdowns
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Override Status', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: status,
                                  isExpanded: true,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: 'present', child: Text('Present (Standard)')),
                                    DropdownMenuItem(value: 'late', child: Text('Late Check-In')),
                                    DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                                    DropdownMenuItem(value: 'confirmed_absent', child: Text('Absent (Confirmed)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => status = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Work Mode', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: workMode,
                                  isExpanded: true,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: 'office', child: Text('Office HQ')),
                                    DropdownMenuItem(value: 'field', child: Text('Field Work')),
                                    DropdownMenuItem(value: 'home_office', child: Text('Home Office')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => workMode = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Smart Exclusions Toggles
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Intelligent Exclusion Rules', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: skipWeekends,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) => setModalState(() => skipWeekends = val ?? true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Skip Shift Off-Days & Weekends', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: skipHolidays,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) => setModalState(() => skipHolidays = val ?? true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Skip Public & Company Holidays', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Audit Note / Justification',
                      labelStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting || selectedUserIds.isEmpty
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final repo = ref.read(attendanceRepositoryProvider);
                                    final res = await repo.overrideAttendance(
                                      userIds: selectedUserIds.toList(),
                                      startDate: DateFormat('yyyy-MM-dd').format(startDate),
                                      endDate: DateFormat('yyyy-MM-dd').format(endDate),
                                      status: status,
                                      workMode: workMode,
                                      skipWeekends: skipWeekends,
                                      skipHolidays: skipHolidays,
                                      notes: notesCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
                                    ref.read(attendanceProvider.notifier).fetchAttendanceRecords(force: true);
                                    if (mounted) {
                                      NotificationBanner.showSuccess(
                                        context,
                                        res?['message']?.toString() ?? 'Attendance override applied successfully',
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      NotificationBanner.showError(context, 'Override failed: $e');
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Apply Override', style: TextStyle(fontWeight: FontWeight.w800)),
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

  void _showWorkLocationAssignmentModal() {
    final allUsers = ref.read(userManagementProvider);
    final selectedUserIds = <String>{};
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    String assignedLocation = 'office';
    String searchFilter = '';
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final filteredUsers = allUsers.where((u) {
            if (searchFilter.isEmpty) return true;
            final query = searchFilter.toLowerCase();
            return u.name.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query) ||
                u.department.toLowerCase().contains(query);
          }).toList();

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 20,
              left: 20,
              right: 20,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0D9488), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Work Location Assignment',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Assign Office (Default), Home, or Field by date range',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Employee multi-select section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Personnel (${selectedUserIds.length}/${allUsers.length})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedUserIds.addAll(allUsers.map((u) => u.id));
                              });
                            },
                            child: const Text('Select All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D9488))),
                          ),
                          const SizedBox(width: 8),
                          const Text('|', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedUserIds.clear();
                              });
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Search box
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setModalState(() => searchFilter = val),
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Search by employee name or role...',
                              hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Scrollable checklist
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (ctx, idx) {
                        final u = filteredUsers[idx];
                        final isSel = selectedUserIds.contains(u.id);
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              if (isSel) {
                                selectedUserIds.remove(u.id);
                              } else {
                                selectedUserIds.add(u.id);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            color: isSel ? const Color(0xFF0D9488).withValues(alpha: 0.08) : Colors.transparent,
                            child: Row(
                              children: [
                                Icon(
                                  isSel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: isSel ? const Color(0xFF0D9488) : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.name,
                                        style: TextStyle(
                                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: 12,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${u.department} • ${u.role.name}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Calendar Date Range picker
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Date Range',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      startDate = DateTime.now();
                                      endDate = DateTime.now();
                                    });
                                  },
                                  child: const Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0D9488))),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      final t = DateTime.now().add(const Duration(days: 1));
                                      startDate = t;
                                      endDate = t;
                                    });
                                  },
                                  child: const Text('Tomorrow', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0D9488))),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      startDate = DateTime.now();
                                      endDate = DateTime.now().add(const Duration(days: 6));
                                    });
                                  },
                                  child: const Text('Next 7D', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0D9488))),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: startDate,
                                    firstDate: DateTime(2023),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      startDate = picked;
                                      if (endDate.isBefore(startDate)) endDate = startDate;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.withAlpha(80)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0D9488)),
                                      const SizedBox(width: 6),
                                      Text(DateFormat('dd MMM yyyy').format(startDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: endDate,
                                    firstDate: startDate,
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setModalState(() => endDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.withAlpha(80)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF0D9488)),
                                      const SizedBox(width: 6),
                                      Text(DateFormat('dd MMM yyyy').format(endDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Work Location Selection Cards
                  const Text('Assigned Work Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      {
                        'key': 'office',
                        'label': 'Office HQ',
                        'icon': Icons.business_rounded,
                        'desc': 'Default Geofence',
                      },
                      {
                        'key': 'home',
                        'label': 'Home',
                        'icon': Icons.home_rounded,
                        'desc': 'Remote / WFH',
                      },
                      {
                        'key': 'field',
                        'label': 'Field / Site',
                        'icon': Icons.engineering_rounded,
                        'desc': 'Client / Site',
                      },
                    ].map((item) {
                      final isSel = assignedLocation == item['key'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => assignedLocation = item['key'] as String),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? const Color(0xFF0D9488) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(item['icon'] as IconData, size: 20, color: isSel ? const Color(0xFF0D9488) : Colors.grey),
                                const SizedBox(height: 4),
                                Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    color: isSel ? const Color(0xFF0D9488) : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                Text(
                                  item['desc'] as String,
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Assignment Notes / Reason (Optional)',
                      hintText: 'e.g. Approved work from home / Site duty',
                      labelStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting || selectedUserIds.isEmpty
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final repo = ref.read(attendanceRepositoryProvider);
                                    final res = await repo.assignWorkLocations(
                                      userIds: selectedUserIds.toList(),
                                      startDate: DateFormat('yyyy-MM-dd').format(startDate),
                                      endDate: DateFormat('yyyy-MM-dd').format(endDate),
                                      workLocation: assignedLocation,
                                      notes: notesCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
                                    ref.read(attendanceProvider.notifier).fetchAttendanceRecords(force: true);
                                    if (mounted) {
                                      NotificationBanner.showSuccess(
                                        context,
                                        res?['message']?.toString() ?? 'Work location assigned successfully',
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      NotificationBanner.showError(context, 'Assignment failed: $e');
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save Assignment', style: TextStyle(fontWeight: FontWeight.w800)),
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

  void _showManualCheckInModal({String? preselectedUserId, String? preselectedDate}) {
    final allUsers = ref.read(userManagementProvider);
    final settingsAsync = ref.read(attendanceSettingsProvider);
    final officeSettings = settingsAsync.value;
    final officeLat = officeSettings?.officeLatitude ?? 23.8103;
    final officeLng = officeSettings?.officeLongitude ?? 90.4125;

    String? selectedUserId = preselectedUserId;
    DateTime checkInDate = preselectedDate != null
        ? (DateTime.tryParse(preselectedDate) ?? DateTime.now())
        : DateTime.now();
    String sessionType = 'morning';
    String workMode = 'office';
    String status = 'present';
    double latitude = officeLat;
    double longitude = officeLng;
    final addressCtrl = TextEditingController(text: officeSettings?.officeAddress ?? 'Head Office, Dhaka');
    final notesCtrl = TextEditingController(text: 'Admin manual attendance check-in');
    bool isSubmitting = false;
    bool isLocating = false;
    String userSearchFilter = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final filteredUsers = allUsers.where((u) {
            if (userSearchFilter.isEmpty) return true;
            final q = userSearchFilter.toLowerCase();
            return u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.department.toLowerCase().contains(q);
          }).toList();

          final selectedUser = allUsers.where((u) => u.id == selectedUserId).firstOrNull;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 20,
              left: 20,
              right: 20,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.90,
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.how_to_reg_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Manual Check-in',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Log official arrival or field check-in on behalf of staff',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Employee Picker
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target Employee ${selectedUser != null ? '(${selectedUser.name})' : '(None Selected)'}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                      if (selectedUserId != null)
                        GestureDetector(
                          onTap: () => setModalState(() => selectedUserId = null),
                          child: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (selectedUserId == null) ...[
                    // Search box
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setModalState(() => userSearchFilter = val),
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'Search employee by name, email or role...',
                                hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (ctx, idx) {
                          final u = filteredUsers[idx];
                          return InkWell(
                            onTap: () => setModalState(() => selectedUserId = u.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  AppAvatar(name: u.name, imageUrl: u.avatarUrl, size: 28),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                        Text('${u.department} • ${u.email}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF4F46E5)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(name: selectedUser!.name, imageUrl: selectedUser.avatarUrl, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selectedUser.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                Text('${selectedUser.department} • ${selectedUser.email}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Selected', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Date and Session Picker
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: checkInDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setModalState(() => checkInDate = d);
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: Text(DateFormat('yyyy-MM-dd').format(checkInDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: sessionType,
                              isExpanded: true,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                              items: const [
                                DropdownMenuItem(value: 'morning', child: Text('Morning Session')),
                                DropdownMenuItem(value: 'afternoon', child: Text('Afternoon Session')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => sessionType = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Work Mode & Status
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Work Mode', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: workMode,
                                  isExpanded: true,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: 'office', child: Text('Office HQ')),
                                    DropdownMenuItem(value: 'home_office', child: Text('Home Office')),
                                    DropdownMenuItem(value: 'field', child: Text('Field Site')),
                                    DropdownMenuItem(value: 'home', child: Text('Home / WFH')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => workMode = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: status,
                                  isExpanded: true,
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: 'present', child: Text('Present (Standard)')),
                                    DropdownMenuItem(value: 'late', child: Text('Late Check-In')),
                                    DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setModalState(() => status = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location and Pin Options
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Coordinates & Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      latitude = officeLat;
                                      longitude = officeLng;
                                      addressCtrl.text = officeSettings?.officeAddress ?? 'Head Office, Dhaka';
                                    });
                                  },
                                  child: const Text('Use Office Pin', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                ),
                                const SizedBox(width: 8),
                                const Text('|', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: isLocating
                                      ? null
                                      : () async {
                                          setModalState(() => isLocating = true);
                                          try {
                                            final pos = await Geolocator.getCurrentPosition(
                                              desiredAccuracy: LocationAccuracy.high,
                                            );
                                            setModalState(() {
                                              latitude = pos.latitude;
                                              longitude = pos.longitude;
                                              addressCtrl.text = 'Current GPS Position (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
                                            });
                                          } catch (_) {}
                                          setModalState(() => isLocating = false);
                                        },
                                  child: Text(isLocating ? 'Locating...' : 'Get GPS', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: addressCtrl,
                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Address or landmark name',
                            hintStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.withAlpha(50))),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coords: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Notes / Audit Justification (Optional)',
                      labelStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting || selectedUserId == null
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final repo = ref.read(attendanceRepositoryProvider);
                                    await repo.checkIn(
                                      userId: selectedUserId,
                                      date: DateFormat('yyyy-MM-dd').format(checkInDate),
                                      status: status,
                                      latitude: latitude,
                                      longitude: longitude,
                                      addressText: addressCtrl.text.trim(),
                                      sessionType: sessionType,
                                      workMode: workMode,
                                      notes: notesCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
                                    ref.read(attendanceProvider.notifier).fetchAttendanceRecords(force: true);
                                    if (mounted) {
                                      NotificationBanner.showSuccess(
                                        context,
                                        'Manual attendance check-in recorded successfully.',
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      NotificationBanner.showError(context, 'Check-in failed: $e');
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit Check-in', style: TextStyle(fontWeight: FontWeight.w800)),
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

  void _showRecordDetailsModal(AttendanceRecordModel record) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    AppAvatar(
                      imageUrl:
                          (record.avatarUrl.isNotEmpty)
                              ? record.avatarUrl
                              : (ref
                                      .read(userManagementProvider)
                                      .where((u) => u.id == record.userId)
                                      .firstOrNull
                                      ?.avatarUrl ??
                                  ''),
                      name: record.userName,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${record.department} • ${record.designation}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (record.isMorning
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF10B981))
                            .withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        record.isMorning
                            ? 'Morning Session'
                            : 'Afternoon Session',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color:
                              record.isMorning
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Work Mode & Geofence Origin Banner
                () {
                  Color bannerBg;
                  Color bannerBorder;
                  Color bannerFg;
                  IconData bannerIcon;
                  String modeTitle;
                  String modeSubtitle;

                  if (record.isFieldDuty) {
                    bannerBg =
                        isDark
                            ? const Color(0xFF312E81).withAlpha(100)
                            : const Color(0xFFEEF2FF);
                    bannerBorder =
                        isDark
                            ? const Color(0xFF4338CA)
                            : const Color(0xFFC7D2FE);
                    bannerFg =
                        isDark
                            ? const Color(0xFFA5B4FC)
                            : const Color(0xFF4F46E5);
                    bannerIcon = Icons.directions_car_rounded;
                    modeTitle = 'On Field Duty Attendance';
                    final site = record.fieldSite;
                    final client = record.fieldClient;
                    modeSubtitle =
                        'Site: ${site ?? "Site Not Specified"}${client != null ? " • Client: $client" : ""}';
                  } else if (record.isHomeOffice) {
                    bannerBg =
                        isDark
                            ? const Color(0xFF4C1D95).withAlpha(100)
                            : const Color(0xFFF3E8FF);
                    bannerBorder =
                        isDark
                            ? const Color(0xFF6B21A8)
                            : const Color(0xFFE9D5FF);
                    bannerFg =
                        isDark
                            ? const Color(0xFFD8B4FE)
                            : const Color(0xFF7E22CE);
                    bannerIcon = Icons.home_work_rounded;
                    modeTitle = 'Home Office Attendance';
                    modeSubtitle =
                        'Logged remotely from approved residential/home workstation';
                  } else {
                    // Office check-in
                    final distText = record.geofenceDistanceText;
                    if (record.isInsideGeofence) {
                      bannerBg =
                          isDark
                              ? const Color(0xFF064E3B).withAlpha(100)
                              : const Color(0xFFECFDF5);
                      bannerBorder =
                          isDark
                              ? const Color(0xFF047857)
                              : const Color(0xFFA7F3D0);
                      bannerFg =
                          isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF059669);
                      bannerIcon = Icons.verified_rounded;
                      modeTitle = 'Office Attendance • Verified In-Range';
                      modeSubtitle =
                          'Device GPS within allowed perimeter${distText != null ? " (Distance: $distText)" : ""}';
                    } else if (record.isOutsideGeofence) {
                      bannerBg =
                          isDark
                              ? const Color(0xFF7F1D1D).withAlpha(100)
                              : const Color(0xFFFEF2F2);
                      bannerBorder =
                          isDark
                              ? const Color(0xFF991B1B)
                              : const Color(0xFFFECACA);
                      bannerFg =
                          isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFDC2626);
                      bannerIcon = Icons.warning_amber_rounded;
                      modeTitle = 'Office Attendance • Outside Geofence';
                      modeSubtitle =
                          'Device logged outside allowed office boundary${distText != null ? " ($distText away)" : ""}';
                    } else {
                      bannerBg =
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC);
                      bannerBorder =
                          isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0);
                      bannerFg =
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569);
                      bannerIcon = Icons.business_rounded;
                      modeTitle = 'Office Headquarters Attendance';
                      modeSubtitle = 'Office workstation session';
                    }
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bannerBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bannerBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(bannerIcon, size: 24, color: bannerFg),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                modeTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: bannerFg,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                modeSubtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF475569),
                                ),
                              ),
                              if (record.earlyDepartureReason != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Early Departure: ${record.earlyDepartureReason}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }(),
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: Icons.access_time_rounded,
                  title: 'Login Timestamp',
                  value: '${record.formattedDate} at ${record.formattedTime}',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  icon: Icons.location_on_outlined,
                  title: 'GPS Coordinates',
                  value: record.formattedCoordinates,
                  isDark: isDark,
                ),
                if (record.addressText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.map_outlined,
                    title: 'Address / Location',
                    value: record.addressText,
                    isDark: isDark,
                  ),
                ],
                if (record.deviceInfo.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.smartphone_rounded,
                    title: 'Device & Hardware',
                    value: record.deviceInfo,
                    isDark: isDark,
                  ),
                ],
                if (record.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.notes_rounded,
                    title: 'Status Notes',
                    value: record.notes,
                    isDark: isDark,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Close Details',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = ref.watch(authProvider).currentUser;
    // Project Member perspective: only see their own attendance & geo-location
    if (currentUser != null && !currentUser.role.canManageAttendanceAndSalary) {
      return const MyAttendanceScreen();
    }

    final attendanceState = ref.watch(attendanceProvider);
    final allUsers = ref.watch(userManagementProvider);
    final overview = attendanceState.dailyOverview;
    final records = attendanceState.records;

    final avatarMap = <String, String>{};
    for (final u in allUsers) {
      if (u.avatarUrl != null && u.avatarUrl!.isNotEmpty) {
        avatarMap[u.id] = u.avatarUrl!;
      }
    }

    List<EmployeeDailyAttendance> rawEmployees = overview?.employees ?? [];
    if (rawEmployees.isEmpty && allUsers.isNotEmpty) {
      rawEmployees =
          allUsers
              .where((u) => u.isActive && u.role.requiresAttendanceCheckIn)
              .map((u) {
                final userRecords =
                    records.where((r) => r.userId == u.id).toList();
                final hasMorning = userRecords.any((r) => r.isMorning);
                final hasAfternoon = userRecords.any((r) => !r.isMorning);
                String status = 'missing';
                if (hasMorning && hasAfternoon) {
                  status = 'present';
                } else if (hasMorning || hasAfternoon) {
                  status = 'half_day';
                }
                return EmployeeDailyAttendance(
                  userId: u.id,
                  userName: u.name,
                  userEmail: u.email,
                  department: u.department,
                  designation: u.designation ?? u.role.displayName,
                  avatarUrl: u.avatarUrl ?? '',
                  role: u.role.displayName,
                  date: attendanceState.selectedDate,
                  status: status,
                  morning: userRecords.where((r) => r.isMorning).firstOrNull,
                  afternoon: userRecords.where((r) => !r.isMorning).firstOrNull,
                );
              })
              .toList();
    }
    final employees = rawEmployees;

    final totalStaff = employees.length;
    final presentCount = employees.where((e) => e.status == 'present').length;
    final halfDayCount = employees.where((e) => e.status == 'half_day').length;
    final missingCount =
        employees
            .where(
              (e) => e.status == 'missing' || e.status == 'confirmed_absent',
            )
            .length;

    final filteredEmployees =
        employees.where((e) {
          final matchesStatus =
              _statusFilter == 'present'
                  ? e.status == 'present'
                  : _statusFilter == 'half_day'
                  ? e.status == 'half_day'
                  : _statusFilter == 'missing'
                  ? e.status == 'missing' || e.status == 'confirmed_absent'
                  : true;
          if (!matchesStatus) return false;
          if (_locationFilter == 'all') return true;
          final records =
              [e.morning, e.afternoon].whereType<AttendanceRecordModel>();
          if (_locationFilter == 'unrecorded') return records.isEmpty;
          return records.any((record) {
            switch (_locationFilter) {
              case 'office':
                return !record.isFieldDuty &&
                    !record.isHome &&
                    !record.isHomeOffice;
              case 'home':
                return record.isHome;
              case 'home_office':
                return record.isHomeOffice;
              case 'field':
                return record.isFieldDuty;
              default:
                return true;
            }
          });
        }).toList();

    DateTime parsedDate =
        DateTime.tryParse(attendanceState.selectedDate) ?? DateTime.now();
    final formattedDateTitle = DateFormat(
      'EEE, MMM d, yyyy',
    ).format(parsedDate);
    final settingsState = ref.watch(attendanceSettingsProvider);
    final currentSettings = settingsState.value;
    final weekendDays =
        currentSettings?.weekendDays ?? [DateTime.friday, DateTime.saturday];
    final isWeekend = weekendDays.contains(parsedDate.weekday);
    final isHoliday =
        employees.isNotEmpty && employees.every((e) => e.status == 'holiday');

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(
          'Attendance',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (currentUser?.role == UserRole.mainAdmin ||
              currentUser?.role == UserRole.projectManager ||
              currentUser?.role == UserRole.finance) ...[
            IconButton(
              icon: const Icon(Icons.how_to_reg_rounded),
              tooltip: 'Record Manual Check-in',
              onPressed: () => _showManualCheckInModal(),
            ),
            IconButton(
              icon: const Icon(Icons.add_location_alt_rounded),
              tooltip: 'Work Location Assignment Settings',
              onPressed: _showWorkLocationAssignmentModal,
            ),
            IconButton(
              icon: const Icon(Icons.edit_calendar_rounded),
              tooltip: 'Override Attendance (Date Range)',
              onPressed: _showOverrideAttendanceModal,
            ),
          ],
          if (currentUser?.role == UserRole.mainAdmin)
            IconButton(
              icon: const Icon(Icons.access_time_rounded),
              tooltip: 'Office Timing Settings',
              onPressed: () => context.push(RoutePaths.attendanceSettings),
            ),
          IconButton(
            icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
            tooltip: _showMap ? 'Hide Map' : 'Show Map',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Attendance',
            onPressed: () {
              ref.read(userManagementProvider.notifier).fetchUsers();
              ref
                  .read(attendanceProvider.notifier)
                  .fetchDailyOverview(force: true);
              ref
                  .read(attendanceProvider.notifier)
                  .fetchAttendanceRecords(force: true);
              ref.read(attendanceProvider.notifier).syncOfflineCheckIns();
              NotificationBanner.showInfo(
                context,
                'Attendance records refreshed',
              );
            },
          ),
        ],
      ),
      body:
          attendanceState.isLoading && overview == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Office Timing Configuration Banner (Super Admin)
                    if (currentUser?.role == UserRole.mainAdmin) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              () => context.push(RoutePaths.attendanceSettings),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppColors.darkBorder
                                        : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(
                                    isDark ? 20 : 6,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4F46E5,
                                    ).withValues(alpha: isDark ? 0.25 : 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: Color(0xFF4F46E5),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Shift & Timing Rules',
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Configure schedules, off-days & payroll',
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? AppColors.darkTextSecondary
                                                  : const Color(0xFF64748B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Manage',
                                        style: TextStyle(
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 10,
                                        color:
                                            isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    // 1. DATE NAVIGATOR BAR
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFF1F5F9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 16 : 4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _changeDate(-1),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 15,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        formattedDateTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _changeDate(1),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    if (isWeekend) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark
                                    ? const Color(0xFF3B82F6).withAlpha(80)
                                    : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.beach_access_rounded,
                              size: 18,
                              color:
                                  isDark
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Weekend Non-Working Day (Friday & Saturday) — Staff are excused and no salary cuts apply.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isHoliday) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF2E1065).withAlpha(50)
                                  : const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark
                                    ? const Color(0xFF8B5CF6).withAlpha(80)
                                    : const Color(0xFFDDD6FE),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.celebration_rounded,
                              size: 18,
                              color:
                                  isDark
                                      ? const Color(0xFFA78BFA)
                                      : const Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Official Company Holiday — Non-working day with zero absence deductions.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFFC4B5FD)
                                          : const Color(0xFF6D28D9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 2. KPI METRICS CARDS
                    Row(
                      children: [
                        _buildMetricCard(
                          title: 'Total',
                          value: '$totalStaff',
                          color: const Color(0xFF64748B),
                          icon: Icons.people_outline_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildMetricCard(
                          title: 'Present',
                          value: '$presentCount',
                          color: const Color(0xFF10B981),
                          icon: Icons.check_circle_outline_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildMetricCard(
                          title: 'Half Day',
                          value: '$halfDayCount',
                          color: const Color(0xFFF59E0B),
                          icon: Icons.timelapse_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 6),
                        _buildMetricCard(
                          title: 'Absent',
                          value: '$missingCount',
                          color: const Color(0xFFEF4444),
                          icon: Icons.error_outline_rounded,
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. INTERACTIVE MAP SECTION
                    () {
                      final combinedMapRecords = <AttendanceRecordModel>[
                        ...records,
                      ];
                      if (overview?.employees != null) {
                        for (final emp in overview!.employees) {
                          if (emp.morning != null &&
                              !combinedMapRecords.any(
                                (r) => r.id == emp.morning!.id,
                              )) {
                            combinedMapRecords.add(emp.morning!);
                          }
                          if (emp.afternoon != null &&
                              !combinedMapRecords.any(
                                (r) => r.id == emp.afternoon!.id,
                              )) {
                            combinedMapRecords.add(emp.afternoon!);
                          }
                        }
                      }
                      final gpsRecords =
                          combinedMapRecords
                              .where(
                                (r) =>
                                    r.latitude != null && r.longitude != null,
                              )
                              .toList();

                      if (!_showMap && gpsRecords.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Live Geo-Location Pins',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                '${gpsRecords.length} Verified Locations',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? AppColors.darkTextSecondary
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 240,
                            width: double.infinity,
                            child: AttendanceMapView(
                              records: gpsRecords,
                              onMarkerTap: _showRecordDetailsModal,
                              officeLocation:
                                  (currentSettings != null &&
                                          currentSettings.officeLatitude != 0)
                                      ? LatLng(
                                        currentSettings.officeLatitude,
                                        currentSettings.officeLongitude,
                                      )
                                      : null,
                              officeRadiusMeters:
                                  currentSettings?.geofenceRadiusMeters,
                              officeName: currentSettings?.officeName,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }(),

                    // 4. STATUS CHIPS FILTER

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All (${employees.length})', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Full Day ($presentCount)',
                            'present',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Half Day ($halfDayCount)',
                            'half_day',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Missing / Absent ($missingCount)',
                            'missing',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildLocationFilterChip(
                            'All locations',
                            'all',
                            employees.length,
                          ),
                          _buildLocationFilterChip(
                            'Office',
                            'office',
                            _locationCount(employees, 'office'),
                          ),
                          _buildLocationFilterChip(
                            'Home',
                            'home',
                            _locationCount(employees, 'home'),
                          ),
                          _buildLocationFilterChip(
                            'Home office',
                            'home_office',
                            _locationCount(employees, 'home_office'),
                          ),
                          _buildLocationFilterChip(
                            'Field',
                            'field',
                            _locationCount(employees, 'field'),
                          ),
                          _buildLocationFilterChip(
                            'Not recorded',
                            'unrecorded',
                            _locationCount(employees, 'unrecorded'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 5. EMPLOYEE ATTENDANCE RECORDS LIST
                    if (filteredEmployees.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              size: 48,
                              color:
                                  isDark
                                      ? Colors.white30
                                      : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No attendance records matching filter',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filteredEmployees.map(
                        (emp) => _buildEmployeeAttendanceCard(
                          emp,
                          isDark,
                          avatarMap,
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 10 : 3),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 12, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      selected: isSelected,
      selectedColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color:
            isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : null,
      ),
      onSelected: (_) => setState(() => _statusFilter = value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  int _locationCount(List<EmployeeDailyAttendance> employees, String filter) =>
      employees.where((employee) {
        final records =
            [
              employee.morning,
              employee.afternoon,
            ].whereType<AttendanceRecordModel>();
        if (filter == 'unrecorded') return records.isEmpty;
        return records.any((record) {
          switch (filter) {
            case 'office':
              return !record.isFieldDuty &&
                  !record.isHome &&
                  !record.isHomeOffice;
            case 'home':
              return record.isHome;
            case 'home_office':
              return record.isHomeOffice;
            case 'field':
              return record.isFieldDuty;
            default:
              return true;
          }
        });
      }).length;

  Widget _buildLocationFilterChip(String label, String value, int count) {
    final selected = _locationFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('$label ($count)', style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => setState(() => _locationFilter = value),
        selectedColor:
            isDark ? const Color(0xFF155E75) : const Color(0xFFE0F2FE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmployeeAttendanceCard(
    EmployeeDailyAttendance emp,
    bool isDark, [
    Map<String, String>? avatarMap,
  ]) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    final currentUser = ref.watch(authProvider).currentUser;
    final settingsState = ref.watch(attendanceSettingsProvider);
    final currentSettings = settingsState.value;
    final userShift = currentSettings?.getShiftForUser(emp.userId);
    final weekendDays =
        userShift?.weekendDays ?? currentSettings?.weekendDays ?? const [];

    final dateStr = ref.watch(attendanceProvider).selectedDate;
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final isWeekendForDate = weekendDays.contains(parsedDate.weekday);

    String effectiveStatus = emp.status;
    if (!isWeekendForDate && effectiveStatus == 'weekend') {
      effectiveStatus = 'missing';
    } else if (isWeekendForDate &&
        (effectiveStatus == 'missing' || effectiveStatus.isEmpty)) {
      effectiveStatus = 'weekend';
    }

    if (effectiveStatus == 'present') {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Present';
      statusIcon = Icons.check_circle_rounded;
    } else if (effectiveStatus == 'half_day') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Half Day';
      statusIcon = Icons.timelapse_rounded;
    } else if (effectiveStatus == 'confirmed_absent') {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Absent';
      statusIcon = Icons.cancel_rounded;
    } else if (effectiveStatus == 'weekend') {
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'Weekend';
      statusIcon = Icons.beach_access_rounded;
    } else if (effectiveStatus == 'holiday') {
      statusColor = const Color(0xFF8B5CF6);
      statusLabel = 'Holiday';
      statusIcon = Icons.celebration_rounded;
    } else {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'Not Logged';
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    final effectiveAvatar =
        emp.avatarUrl.isNotEmpty
            ? emp.avatarUrl
            : (avatarMap?[emp.userId] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 8 : 2),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap:
              () => MemberGeoLocationModal.show(
                context,
                emp,
                ref.read(attendanceProvider).selectedDate,
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      imageUrl: effectiveAvatar,
                      name: emp.userName,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${emp.department} • ${emp.designation.isEmpty ? emp.role : emp.designation}',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (currentUser?.role == UserRole.mainAdmin ||
                        currentUser?.role == UserRole.projectManager ||
                        currentUser?.role == UserRole.finance) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF4F46E5)),
                        tooltip: 'Record check-in for ${emp.userName}',
                        onPressed: () => _showManualCheckInModal(
                          preselectedUserId: emp.userId,
                          preselectedDate: ref.read(attendanceProvider).selectedDate,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? Colors.white30 : const Color(0xFFCBD5E1),
                    ),
                  ],
                ),
                ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (emp.morning != null)
                        _buildLocationBadge(
                          emp.morning!,
                          true,
                          isDark,
                          currentSettings,
                        ),
                      if (emp.afternoon != null)
                        _buildLocationBadge(
                          emp.afternoon!,
                          false,
                          isDark,
                          currentSettings,
                        ),
                      if (emp.morning?.earlyDepartureReason != null)
                        _buildEarlyLeaveBadge(
                          emp.morning!.earlyDepartureReason!,
                          isDark,
                        ),
                      if (emp.afternoon?.earlyDepartureReason != null &&
                          emp.afternoon?.earlyDepartureReason !=
                              emp.morning?.earlyDepartureReason)
                        _buildEarlyLeaveBadge(
                          emp.afternoon!.earlyDepartureReason!,
                          isDark,
                        ),
                      if (!emp.hasLocationRecords)
                        _buildUnrecordedLocationBadge(isDark),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBadge(
    AttendanceRecordModel record,
    bool isMorning,
    bool isDark,
    AttendanceSettingsState? settings,
  ) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData icon;
    String text;

    final sessionTag = isMorning ? 'AM' : 'PM';

    if (record.isFieldDuty) {
      bgColor =
          isDark
              ? const Color(0xFF312E81).withAlpha(100)
              : const Color(0xFFEEF2FF);
      textColor = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA);
      borderColor =
          isDark
              ? const Color(0xFF4338CA).withAlpha(120)
              : const Color(0xFFC7D2FE);
      icon = Icons.directions_car_rounded;
      final site = record.fieldSite;
      text =
          '$sessionTag: Field${site != null && site.isNotEmpty ? ' • $site' : ''}';
    } else if (record.isHomeOffice) {
      bgColor =
          isDark
              ? const Color(0xFF4C1D95).withAlpha(100)
              : const Color(0xFFF3E8FF);
      textColor = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6B21A8);
      borderColor =
          isDark
              ? const Color(0xFF6B21A8).withAlpha(120)
              : const Color(0xFFE9D5FF);
      icon = Icons.home_work_rounded;
      text = '$sessionTag: Home Office';
    } else if (record.isHome) {
      bgColor =
          isDark
              ? const Color(0xFF78350F).withAlpha(90)
              : const Color(0xFFFFF7ED);
      textColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412);
      borderColor =
          isDark
              ? const Color(0xFF9A3412).withAlpha(120)
              : const Color(0xFFFED7AA);
      icon = Icons.home_rounded;
      text = '$sessionTag: Home';
    } else {
      // Office Mode
      double? distMeters;
      if (settings != null &&
          settings.officeLatitude != 0 &&
          record.latitude != null &&
          record.longitude != null) {
        distMeters = Geolocator.distanceBetween(
          record.latitude!,
          record.longitude!,
          settings.officeLatitude,
          settings.officeLongitude,
        );
      }

      final allowedRadius = settings?.geofenceRadiusMeters ?? 200.0;
      final isInside =
          record.isInsideGeofence ||
          (distMeters != null && distMeters <= allowedRadius);
      final isOutside =
          record.isOutsideGeofence ||
          (distMeters != null && distMeters > allowedRadius);
      final distText =
          record.geofenceDistanceText ??
          (distMeters != null
              ? (distMeters >= 1000
                  ? '${(distMeters / 1000).toStringAsFixed(1)}km'
                  : '${distMeters.toStringAsFixed(0)}m')
              : null);

      if (isOutside) {
        bgColor =
            isDark
                ? const Color(0xFF7F1D1D).withAlpha(90)
                : const Color(0xFFFEF2F2);
        textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
        borderColor =
            isDark
                ? const Color(0xFF991B1B).withAlpha(120)
                : const Color(0xFFFECACA);
        icon = Icons.warning_amber_rounded;
        text =
            '$sessionTag: Office Outside${distText != null ? ' ($distText)' : ''}';
      } else if (isInside) {
        bgColor =
            isDark
                ? const Color(0xFF064E3B).withAlpha(90)
                : const Color(0xFFECFDF5);
        textColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
        borderColor =
            isDark
                ? const Color(0xFF047857).withAlpha(120)
                : const Color(0xFFA7F3D0);
        icon = Icons.verified_rounded;
        text =
            '$sessionTag: Office In-Range${distText != null ? ' ($distText)' : ''}';
      } else {
        bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        borderColor =
            isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        icon = Icons.business_rounded;
        text = '$sessionTag: Office';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnrecordedLocationBadge(bool isDark) {
    final color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            'No check-in location',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarlyLeaveBadge(String reason, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF78350F).withAlpha(90)
                : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              isDark
                  ? const Color(0xFF92400E).withAlpha(120)
                  : const Color(0xFFFDE68A),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_run_rounded,
            size: 11,
            color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Early Leave: $reason',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
