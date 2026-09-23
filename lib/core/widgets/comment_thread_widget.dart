import 'package:flutter/material.dart';
import '../../models/comment_model.dart';
import '../../models/user_role.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../utils/date_formatter.dart';
import 'role_badge.dart';

class CommentThreadWidget extends StatefulWidget {
  final List<CommentModel> comments;
  final ValueChanged<String> onAddComment;
  final bool isReadOnly;

  const CommentThreadWidget({
    super.key,
    required this.comments,
    required this.onAddComment,
    this.isReadOnly = false,
  });

  @override
  State<CommentThreadWidget> createState() => _CommentThreadWidgetState();
}

class _CommentThreadWidgetState extends State<CommentThreadWidget> {
  final TextEditingController _controller = TextEditingController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onAddComment(text);
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(context), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Clarification Thread', style: AppTextStyles.titleSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.comments.length}',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.comments.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Text(
                'No messages yet. Ask a question or provide context here.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final c = widget.comments[index];
                final isReviewer = c.authorRole != UserRole.projectMember;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isReviewer
                        ? (isDark ? AppColors.indigo.withValues(alpha: 0.2) : AppColors.indigoLight.withValues(alpha: 0.3))
                        : (isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceSubtle),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isReviewer
                          ? (isDark ? AppColors.indigo.withValues(alpha: 0.4) : AppColors.indigoBorder.withValues(alpha: 0.5))
                          : AppColors.getBorder(context),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(c.authorName, style: AppTextStyles.labelMedium),
                              const SizedBox(width: 6),
                              RoleBadge(role: c.authorRole, compact: true),
                            ],
                          ),
                          Text(
                            DateFormatter.formatRelative(c.timestamp),
                            style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(c.text, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                );
              },
            ),
          if (!widget.isReadOnly) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Ask for clarification or reply...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.primary),
                        onPressed: _submit,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
