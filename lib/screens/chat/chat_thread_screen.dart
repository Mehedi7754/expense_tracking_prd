import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/chat_models.dart';
import '../../models/project_model.dart';
import '../../repositories/chat_repository.dart';
import '../../state/chat_provider.dart';
import '../../state/project_provider.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String channelId;

  const ChatThreadScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String? _selectedImageBase64;
  ProjectModel? _selectedProject;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1200);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        _selectedImageBase64 = b64;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _openProjectPicker(BuildContext context) {
    final projects = ref.read(projectProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = projects.where((p) {
              if (query.isEmpty) return true;
              return p.name.toLowerCase().contains(query) || p.projectId.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.65,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
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
                  const SizedBox(height: 12),
                  const Text(
                    'Mention / Attach Project',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      onChanged: (val) => setModalState(() => query = val.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Search project by name or code...',
                        hintStyle: TextStyle(fontSize: 13),
                        prefixIcon: Icon(CupertinoIcons.search, size: 16),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (c, idx) {
                        final p = filtered[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(CupertinoIcons.folder_fill, color: Color(0xFF2563EB), size: 18),
                            ),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text('${p.projectId} • ${CurrencyFormatter.format(p.budget)}', style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(CupertinoIcons.plus_circle, color: Color(0xFF2563EB), size: 20),
                          onTap: () {
                            setState(() {
                              _selectedProject = p;
                            });
                            Navigator.pop(ctx);
                          },
                        );
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

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImageBase64 == null && _selectedProject == null) return;

    setState(() => _isSending = true);

    String? uploadedUrl;
    if (_selectedImageBase64 != null) {
      try {
        final repo = ref.read(chatRepositoryProvider);
        uploadedUrl = await repo.uploadPhoto(_selectedImageBase64!);
      } catch (_) {}
    }

    final proj = _selectedProject;
    final projId = proj?.id;
    final projName = proj?.name;
    final projCode = proj?.projectId;

    _textController.clear();
    setState(() {
      _selectedImageBase64 = null;
      _selectedProject = null;
    });

    final notifier = ref.read(chatMessagesProvider(widget.channelId).notifier);
    await notifier.sendMessage(
      content: text,
      imageUrl: uploadedUrl,
      projectId: projId,
      projectName: projName,
      projectCode: projCode,
    );

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final channelsAsync = ref.watch(chatChannelsProvider);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.channelId));

    // Find active channel info
    ChatChannelModel? activeChannel;
    channelsAsync.whenData((channels) {
      try {
        activeChannel = channels.firstWhere((c) => c.id == widget.channelId);
      } catch (_) {}
    });

    final title = activeChannel?.title ?? 'Conversation';
    final isProject = activeChannel?.isProject ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            if (isProject)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: Icon(CupertinoIcons.folder_badge_person_crop, color: Colors.white, size: 20),
                ),
              )
            else
              AppAvatar(
                imageUrl: activeChannel?.otherUser?.avatarUrl,
                name: title,
                size: 38,
                showBorder: true,
                borderColor: const Color(0xFF2563EB),
                borderWidth: 1.5,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isProject
                            ? (activeChannel?.projectCode ?? 'Team Room')
                            : (activeChannel?.otherUser?.role.toUpperCase() ?? 'ACTIVE NOW'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isProject && activeChannel?.projectId != null)
            IconButton(
              icon: const Icon(CupertinoIcons.info_circle, color: Color(0xFF2563EB)),
              tooltip: 'Project Details',
              onPressed: () => context.push(RoutePaths.projectDetail(activeChannel!.projectId!)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Messages thread
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                    const SizedBox(height: 8),
                    Text('Error loading messages: $err'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.read(chatMessagesProvider(widget.channelId).notifier).fetchMessages(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.chat_bubble_2, size: 48, color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          'No messages yet',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hello to start the conversation!',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }

                // Auto-scroll when messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && _scrollController.position.pixels == 0) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, index) {
                    final msg = messages[index];
                    final showDateHeader = index == 0 ||
                        !_isSameDay(messages[index - 1].createdAt, msg.createdAt);

                    return Column(
                      children: [
                        if (showDateHeader) _buildDateHeader(msg.createdAt, isDark),
                        _buildMessageBubble(ctx, msg, isDark, isProject),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Composer
          _buildComposer(isDark),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(DateTime dt, bool isDark) {
    final now = DateTime.now();
    String text;
    if (_isSameDay(dt, now)) {
      text = 'Today';
    } else if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) {
      text = 'Yesterday';
    } else {
      text = DateFormat.yMMMd().format(dt);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessageModel msg, bool isDark, bool isProject) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && isProject) ...[
            AppAvatar(
              imageUrl: msg.senderAvatarUrl,
              name: msg.senderName,
              size: 28,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isProject)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image attachment if present
                        if (msg.hasImage)
                          GestureDetector(
                            onTap: () => _openPhotoViewer(context, msg.imageUrl!),
                            child: Hero(
                              tag: 'chat_img_${msg.id}',
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 260),
                                width: double.infinity,
                                child: AppImageHelper.buildImage(
                                  path: msg.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: () => Container(
                                    height: 180,
                                    color: Colors.black12,
                                    child: const Center(child: CircularProgressIndicator()),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Project reference card if present
                        if (msg.hasProject)
                          _buildEmbeddedProjectCard(context, msg, isMe, isDark),
                        // Text message content
                        if (msg.content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(
                              msg.content,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.35,
                                color: isMe
                                    ? Colors.white
                                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Time & Status
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat.jm().format(msg.createdAt),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          CupertinoIcons.checkmark_alt,
                          size: 13,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedProjectCard(
    BuildContext context,
    ChatMessageModel msg,
    bool isMe,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? Colors.white.withValues(alpha: 0.25)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white24 : const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  msg.projectCode ?? 'PROJECT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isMe ? Colors.white : const Color(0xFF2563EB),
                  ),
                ),
              ),
              const Spacer(),
              if (msg.projectStatus != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    msg.projectStatus!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            msg.projectName ?? 'Referenced Project',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (msg.projectBudget != null) ...[
            const SizedBox(height: 4),
            Text(
              'Budget: ${CurrencyFormatter.format(msg.projectBudget!)}',
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white70 : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (msg.projectId != null) {
                context.push(RoutePaths.projectDetail(msg.projectId!));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isMe ? Colors.white : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'View Project Details →',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isMe ? const Color(0xFF2563EB) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(bool isDark) {
    final hasContent = _textController.text.trim().isNotEmpty ||
        _selectedImageBase64 != null ||
        _selectedProject != null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attachments Preview Strip
            if (_selectedImageBase64 != null || _selectedProject != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (_selectedImageBase64 != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: AppImageHelper.buildImage(
                                path: _selectedImageBase64,
                                fit: BoxFit.cover,
                                placeholder: () => Container(color: Colors.black12),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImageBase64 = null),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_selectedImageBase64 != null && _selectedProject != null)
                      const SizedBox(width: 8),
                    if (_selectedProject != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.folder_fill, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              _selectedProject!.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _selectedProject = null),
                              child: const Icon(Icons.close, size: 14, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            // Input Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach image button
                IconButton(
                  icon: const Icon(CupertinoIcons.photo_camera_solid, color: Color(0xFF2563EB), size: 22),
                  tooltip: 'Attach Photo',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _showImageSourcePicker(context),
                ),
                // Mention project button
                IconButton(
                  icon: const Icon(CupertinoIcons.number_square_fill, color: Color(0xFF4F46E5), size: 22),
                  tooltip: 'Mention Project',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _openProjectPicker(context),
                ),
                const SizedBox(width: 6),
                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _textController,
                      onChanged: (_) => setState(() {}),
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: hasContent ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 20),
                          onPressed: hasContent ? _handleSendMessage : null,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(CupertinoIcons.camera_fill, color: Color(0xFF2563EB)),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.photo_fill_on_rectangle_fill, color: Color(0xFF4F46E5)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPhotoViewer(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: AppImageHelper.buildImage(
                path: imageUrl,
                fit: BoxFit.contain,
                placeholder: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
