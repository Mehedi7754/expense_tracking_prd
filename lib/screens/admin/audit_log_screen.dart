import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/custom_search_bar.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/role_badge.dart';
import '../../state/audit_log_provider.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const AuditLogScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(auditLogProvider);

    final filteredLogs = logs.where((l) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return l.userName.toLowerCase().contains(q) ||
            l.action.toLowerCase().contains(q) ||
            l.details.toLowerCase().contains(q) ||
            l.entityType.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('System Audit Trail'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CustomSearchBar(
              hintText: 'Search audit records by actor, action, or details...',
              initialValue: _searchQuery,
              onChanged: (q) => setState(() => _searchQuery = q),
            ),
          ),
          Expanded(
            child: filteredLogs.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.search_off_rounded,
                    title: 'No Matching Logs',
                    message: 'No system audit logs matched your query.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    itemCount: filteredLogs.length,
                    itemBuilder: (ctx, i) {
                      final log = filteredLogs[i];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(log.userName, style: AppTextStyles.labelMedium),
                                    const SizedBox(width: 8),
                                    RoleBadge(role: log.userRole, compact: true),
                                  ],
                                ),
                                Text(
                                  DateFormatter.formatRelative(log.timestamp),
                                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${log.action} • ${log.entityType}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              log.details,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
