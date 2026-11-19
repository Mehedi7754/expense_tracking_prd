import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/comment_thread_widget.dart';
import '../../models/comment_model.dart';
import '../../models/leave_model.dart';
import '../../state/auth_provider.dart';
import '../../state/leave_provider.dart';
import '../../repositories/leave_repository.dart';
import 'leave_applicant_avatar.dart';

class LeaveDetailScreen extends ConsumerStatefulWidget {
  final String leaveId;

  const LeaveDetailScreen({super.key, required this.leaveId});

  @override
  ConsumerState<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends ConsumerState<LeaveDetailScreen> {
  LeaveRecordModel? _leave;
  List<CommentModel> _comments = const [];
  bool _commentsLoading = true;
  bool _loading = true;
  String? _error;
  String? _commentsError;
  List<LeaveRecordModel> _history = const [];
  bool _historyLoading = true;
  String? _historyError;
  late DateTime _historyMonth;
  bool _showAllHistory = false;

  DateTime _historyMonthOrNow() {
    final date = _leave == null ? null : DateTime.tryParse(_leave!.startDate);
    return DateTime(
      (date ?? DateTime.now()).year,
      (date ?? DateTime.now()).month,
    );
  }

  @override
  void initState() {
    super.initState();
    _historyMonth = DateTime(DateTime.now().year, DateTime.now().month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final leaveState = ref.read(leaveProvider);
      var leave =
          leaveState.leaves
              .where((item) => item.id == widget.leaveId)
              .firstOrNull;
      if (leave == null) {
        final user = ref.read(authProvider).currentUser;
        if (user == null) throw Exception('Your session has expired.');
        leave = await ref
            .read(leaveRepositoryProvider)
            .getLeaveById(widget.leaveId);
      }
      if (!mounted) return;
      setState(() {
        _leave = leave;
        _loading = false;
        _commentsLoading = true;
        _commentsError = null;
        _historyMonth = _historyMonthOrNow();
        _historyLoading = true;
        _historyError = null;
      });
      // History is loaded independently so a history error never hides the request.
      _loadHistory(leave.userId);
      // Keep the leave visible even if its separate discussion request fails.
      try {
        final comments = await ref
            .read(leaveRepositoryProvider)
            .getComments(widget.leaveId);
        if (!mounted) return;
        setState(() {
          _comments = comments;
          _commentsLoading = false;
          _commentsError = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _commentsLoading = false;
          _commentsError = _messageFor(error);
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageFor(error);
      });
    }
  }

  Future<void> _addComment(String text) async {
    final leave = _leave;
    final user = ref.read(authProvider).currentUser;
    if (leave == null || user == null) return;
    final local = CommentModel(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      expenseId: leave.id,
      authorId: user.id,
      authorName: user.name,
      authorRole: user.role,
      text: text,
      timestamp: DateTime.now(),
    );
    setState(() => _comments = [..._comments, local]);
    try {
      final saved = await ref
          .read(leaveRepositoryProvider)
          .addComment(leave.id, text);
      if (!mounted) return;
      setState(
        () =>
            _comments = [
              for (final comment in _comments)
                if (comment.id == local.id) saved else comment,
            ],
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _comments = _comments.where((c) => c.id != local.id).toList(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message could not be sent. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leave = _leave;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F7FB),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(
          'Leave details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF5F7FB),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    _detailCard(leave!, isDark),
                    const SizedBox(height: 14),
                    _historyCard(leave, isDark),
                    const SizedBox(height: 14),
                    if (_commentsError != null)
                      _ClarificationLoadError(
                        message: _commentsError!,
                        onRetry: _loadComments,
                      ),
                    CommentThreadWidget(
                      comments: _comments,
                      isLoading: _commentsLoading,
                      onAddComment: _addComment,
                    ),
                  ],
                ),
              ),
    );
  }

  Future<void> _loadComments() async {
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final comments = await ref
          .read(leaveRepositoryProvider)
          .getComments(widget.leaveId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _commentsLoading = false;
        _commentsError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _commentsLoading = false;
          _commentsError = _messageFor(error);
        });
      }
    }
  }

  Future<void> _loadHistory(String userId) async {
    try {
      final records = await ref
          .read(leaveRepositoryProvider)
          .getLeaves(userId: userId);
      if (!mounted || _leave?.userId != userId) return;
      setState(() {
        _history =
            records
                .where(
                  (record) =>
                      record.userId == userId && record.id != widget.leaveId,
                )
                .toList();
        _historyLoading = false;
        _historyError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyLoading = false;
        _historyError = 'Past leave records could not be loaded.';
      });
    }
  }

  int _daysInMonth(LeaveRecordModel record) {
    final start = DateTime.tryParse(record.startDate);
    final end = DateTime.tryParse(record.endDate);
    if (start == null || end == null) return 0;
    final first = DateTime(_historyMonth.year, _historyMonth.month);
    final last = DateTime(_historyMonth.year, _historyMonth.month + 1, 0);
    final overlapStart = start.isAfter(first) ? start : first;
    final overlapEnd = end.isBefore(last) ? end : last;
    return overlapEnd.isBefore(overlapStart)
        ? 0
        : overlapEnd.difference(overlapStart).inDays + 1;
  }

  Widget _historyCard(LeaveRecordModel leave, bool dark) {
    final records =
        _history.where((record) => _daysInMonth(record) > 0).toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final approvedDays = records
        .where((record) => record.isApproved && !record.isRejected)
        .fold<int>(0, (sum, record) => sum + _daysInMonth(record));
    return Card(
      color: dark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Past Leave Records',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : const Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${leave.userName.isEmpty ? 'This employee' : leave.userName}’s other leave requests',
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM yyyy').format(_historyMonth),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous month',
                  onPressed:
                      () => setState(() {
                        _historyMonth = DateTime(
                          _historyMonth.year,
                          _historyMonth.month - 1,
                        );
                        _showAllHistory = false;
                      }),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed:
                      () => setState(() {
                        _historyMonth = DateTime(
                          _historyMonth.year,
                          _historyMonth.month + 1,
                        );
                        _showAllHistory = false;
                      }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_historyError != null)
              TextButton.icon(
                onPressed: () => _loadHistory(leave.userId),
                icon: const Icon(Icons.refresh),
                label: Text(_historyError!),
              )
            else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _historyMetric(
                      'Requests',
                      '${records.length}',
                      dark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _historyMetric(
                      'Approved days',
                      '$approvedDays',
                      dark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No other leave records in this month.'),
                ),
              for (final record
                  in (_showAllHistory ? records : records.take(3)))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.event_note_rounded,
                    color: Color(0xFF5B6FDB),
                  ),
                  title: Text(
                    record.typeDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${record.startDate.substring(0, 10)} – ${record.endDate.substring(0, 10)} · ${record.statusText}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/leaves/${record.id}'),
                ),
              if (records.length > 3)
                TextButton(
                  onPressed:
                      () => setState(() => _showAllHistory = !_showAllHistory),
                  child: Text(
                    _showAllHistory
                        ? 'Show less'
                        : 'View all ${records.length} records',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyMetric(String label, String value, bool dark) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: dark ? AppColors.darkBackground : const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  String _messageFor(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty
        ? 'Could not load the clarification thread. Check your connection and retry.'
        : message;
  }

  Widget _detailCard(LeaveRecordModel leave, bool dark) {
    final ink = dark ? Colors.white : const Color(0xFF101828);
    final statusColor =
        leave.isApproved
            ? const Color(0xFF10B981)
            : leave.isRejected
            ? const Color(0xFFEF4444)
            : const Color(0xFFD97706);
    DateTime? parseDate(String value) => DateTime.tryParse(value);
    String displayDate(String value) {
      final date = parseDate(value);
      return date == null ? value : DateFormat('EEE, d MMM yyyy').format(date);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LeaveApplicantAvatar(
                name: leave.userName,
                imageUrl: leave.userAvatarUrl,
                radius: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.userName.isEmpty ? 'Employee' : leave.userName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    if (leave.userEmail.isNotEmpty)
                      Text(
                        leave.userEmail,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              dark ? Colors.white60 : const Color(0xFF667085),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  leave.statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            leave.typeDisplayName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 14),
          _detailLine(
            Icons.calendar_month_rounded,
            'From',
            displayDate(leave.startDate),
            dark,
            ink,
          ),
          const SizedBox(height: 10),
          _detailLine(
            Icons.event_available_rounded,
            'Through',
            displayDate(leave.endDate),
            dark,
            ink,
          ),
          const SizedBox(height: 10),
          _detailLine(
            Icons.timelapse_rounded,
            'Duration',
            '${leave.totalDays} ${leave.totalDays == 1 ? 'day' : 'days'}',
            dark,
            ink,
          ),
          if (leave.reason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Reason',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              leave.reason,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: dark ? Colors.white70 : const Color(0xFF475467),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailLine(
    IconData icon,
    String label,
    String value,
    bool dark,
    Color ink,
  ) => Row(
    children: [
      Icon(icon, size: 17, color: const Color(0xFF5B6FDB)),
      const SizedBox(width: 9),
      SizedBox(
        width: 62,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: dark ? Colors.white54 : const Color(0xFF667085),
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ),
    ],
  );
}

class _ClarificationLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ClarificationLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry messages'),
          ),
        ],
      ),
    ),
  );
}
