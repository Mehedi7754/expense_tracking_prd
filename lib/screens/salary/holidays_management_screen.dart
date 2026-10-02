import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/notification_banner.dart';
import '../../state/salary_provider.dart';

class HolidaysManagementScreen extends ConsumerStatefulWidget {
  const HolidaysManagementScreen({super.key});

  @override
  ConsumerState<HolidaysManagementScreen> createState() => _HolidaysManagementScreenState();
}

class _HolidaysManagementScreenState extends ConsumerState<HolidaysManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salaryProvider.notifier).fetchHolidays();
    });
  }

  void _showAddHolidayDialog() {
    DateTime selectedDate = DateTime.now();
    final nameController = TextEditingController();
    bool isRecurring = false;

    final parentContext = context;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Official Holiday', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Holiday Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Independence Day, Eid-ul-Fitr',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withAlpha(80)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('yyyy-MM-dd (EEEE)').format(selectedDate), style: const TextStyle(fontSize: 13)),
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring Annually', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: isRecurring,
                onChanged: (val) {
                  setModalState(() => isRecurring = val ?? false);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                final success = await ref.read(salaryProvider.notifier).addHoliday(dateStr, name, isRecurring: isRecurring);
                if (parentContext.mounted) {
                  if (success) {
                    NotificationBanner.showSuccess(parentContext, 'Holiday added and excluded from work deductions');
                  } else {
                    NotificationBanner.showError(parentContext, 'Failed to add holiday');
                  }
                }
              },
              child: const Text('Add Holiday'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final salaryState = ref.watch(salaryProvider);
    final holidays = salaryState.holidays;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Official Holidays & Leaves', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Holiday', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: _showAddHolidayDialog,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: holidays.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.beach_access_rounded, size: 56, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text('No official holidays configured yet', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                    'Added holidays are automatically excluded from absence deductions',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: holidays.length,
              itemBuilder: (context, index) {
                final h = holidays[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.beach_access_rounded, color: Color(0xFF0284C7), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            Text(
                              '${h.date} ${h.isRecurring ? "• Recurring annually" : ""}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        onPressed: () async {
                          final success = await ref.read(salaryProvider.notifier).deleteHoliday(h.id);
                          if (context.mounted && success) {
                            NotificationBanner.showInfo(context, 'Holiday removed');
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
