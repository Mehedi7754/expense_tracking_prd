import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/project_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/project_provider.dart';
import '../../core/widgets/notification_banner.dart';
import '../../core/widgets/empty_state_widget.dart';

class ProjectNotesHistoryScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectNotesHistoryScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectNotesHistoryScreen> createState() => _ProjectNotesHistoryScreenState();
}

class _ProjectNotesHistoryScreenState extends ConsumerState<ProjectNotesHistoryScreen> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showAddNoteBottomSheet(BuildContext context, ProjectModel project) {
    _noteController.clear();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(authProvider).currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.note_add_rounded, color: Color(0xFF4F46E5), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Add Progress Note',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Post an activity update, work report, or status comment for ${project.name}. Visible to all team members.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type progress update or site note here...',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? AppColors.darkTextSecondary.withAlpha(120) : const Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isSubmitting ? 'Posting...' : 'Post Note',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              final text = _noteController.text.trim();
                              if (text.isEmpty) {
                                NotificationBanner.showWarning(context, 'Please enter a note before posting.');
                                return;
                              }
                              setModalState(() => _isSubmitting = true);
                              setState(() => _isSubmitting = true);

                              final authorRole = currentUser?.role.displayName ?? 'Team Member';
                              final authorId = currentUser?.id ?? 'usr_current';
                              final authorName = currentUser?.name ?? 'Member';

                              await ref.read(projectProvider.notifier).addProgressNote(
                                    projectId: project.id,
                                    note: text,
                                    authorId: authorId,
                                    authorName: authorName,
                                    authorRole: authorRole,
                                  );

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                NotificationBanner.showSuccess(context, 'Note added to project history.');
                              }
                              if (mounted) {
                                setState(() => _isSubmitting = false);
                              }
                            },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allProjects = ref.watch(projectProvider);
    final matches = allProjects.where((p) => p.id == widget.projectId).toList();

    if (matches.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: const Text('Progress Notes History'),
        ),
        body: const Center(
          child: Text('Project not found.'),
        ),
      );
    }

    final project = matches.first;
    final notes = project.progressNotes;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Progress & Notes History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${project.projectId} • ${project.name}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add Note',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: () => _showAddNoteBottomSheet(context, project),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNoteBottomSheet(context, project),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded, size: 20),
        label: const Text(
          'Add Note',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      body: notes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: EmptyStateWidget(
                  icon: Icons.speaker_notes_off_outlined,
                  title: 'No Notes Recorded Yet',
                  message: 'Updates and notes logged during progress changes will appear here for all employees.',
                  actionLabel: 'Add First Note',
                  onAction: () => _showAddNoteBottomSheet(context, project),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return _buildNoteCard(context, note, isDark);
              },
            ),
    );
  }

  Widget _buildNoteCard(BuildContext context, ProjectProgressNote note, bool isDark) {
    Color pctBadgeColor;
    if (note.progressPercentage <= 25.0) {
      pctBadgeColor = const Color(0xFFEF4444);
    } else if (note.progressPercentage < 75.0) {
      pctBadgeColor = const Color(0xFFF59E0B);
    } else if (note.progressPercentage < 100.0) {
      pctBadgeColor = const Color(0xFF3B82F6);
    } else {
      pctBadgeColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4F46E5).withAlpha(20),
                child: Text(
                  note.authorName.isNotEmpty ? note.authorName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            note.authorName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withAlpha(15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            note.authorRole,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.formatDateTime(note.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pctBadgeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pctBadgeColor.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed_rounded, size: 12, color: pctBadgeColor),
                    const SizedBox(width: 4),
                    Text(
                      '${note.progressPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: pctBadgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withAlpha(60) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder.withAlpha(60) : const Color(0xFFF1F5F9),
              ),
            ),
            child: Text(
              note.note,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
