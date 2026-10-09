import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/chat_models.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
import '../../repositories/chat_repository.dart';
import '../../state/auth_provider.dart';
import '../../state/chat_provider.dart';
import '../../state/project_provider.dart';
import '../../state/user_management_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  final bool? hasBottomDock;
  const ChatListScreen({super.key, this.hasBottomDock});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _activeTab = 'all'; // 'all', 'direct', 'project'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat.jm().format(dt); // 10:45 AM
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(dt); // Mon, Tue
    }
    return DateFormat.MMMd().format(dt); // Oct 8
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final channelsAsync = ref.watch(chatChannelsProvider);
    final isRootTab = widget.hasBottomDock ?? (!context.canPop());
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final dockOffset = isRootTab ? (72.0 + bottomInset) : 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        automaticallyImplyLeading: !isRootTab,
        leading: isRootTab
            ? null
            : IconButton(
                icon: const Icon(CupertinoIcons.back),
                onPressed: () => context.pop(),
              ),
        title: const Text(
          'Team Messages',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.square_pencil, color: Color(0xFF2563EB)),
            tooltip: 'New Conversation',
            onPressed: () => _openNewChatSheet(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(106),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search chats, people, or projects...',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              // Segmented Tab Filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    _buildTabPill('all', 'All Chats', isDark),
                    const SizedBox(width: 8),
                    _buildTabPill('direct', 'Colleagues', isDark),
                    const SizedBox(width: 8),
                    _buildTabPill('project', 'Project Rooms', isDark),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ],
          ),
        ),
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 8),
              Text('Failed to load conversations: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(chatChannelsProvider.notifier).fetchChannels(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allChannels) {
          // Auto-exclude any direct channel where other user is deleted/missing
          var channels = allChannels.where((c) {
            if (c.isDirect) {
              return c.otherUser != null && c.otherUser!.id.isNotEmpty;
            }
            return true;
          }).toList();

          // Filter by active tab
          if (_activeTab == 'direct') {
            channels = channels.where((c) => c.isDirect).toList();
          } else if (_activeTab == 'project') {
            channels = channels.where((c) => c.isProject).toList();
          }

          // Filter by search query
          if (_searchQuery.isNotEmpty) {
            channels = channels.where((c) {
              final titleMatch = c.title.toLowerCase().contains(_searchQuery);
              final subtitleMatch = c.subtitle.toLowerCase().contains(_searchQuery);
              final codeMatch = c.projectCode?.toLowerCase().contains(_searchQuery) ?? false;
              return titleMatch || subtitleMatch || codeMatch;
            }).toList();
          }

          if (channels.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(chatChannelsProvider.notifier).fetchChannels(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.chat_bubble_2_fill,
                            size: 40,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matching chats found'
                              : (_activeTab == 'project'
                                  ? 'No project channels yet'
                                  : 'No conversations yet'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try searching with another keyword'
                              : 'Start a conversation with colleagues or discuss a project',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _openNewChatSheet(context),
                          icon: const Icon(CupertinoIcons.plus, size: 18),
                          label: const Text('Start New Conversation'),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(chatChannelsProvider.notifier).fetchChannels(),
            child: ListView.separated(
              padding: EdgeInsets.only(
                top: 8,
                bottom: dockOffset + 80,
              ),
              itemCount: channels.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76,
                endIndent: 16,
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (ctx, index) {
                final channel = channels[index];
                return _buildConversationTile(ctx, channel, isDark);
              },
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: dockOffset),
        child: FloatingActionButton(
          heroTag: 'chat_list_new_conversation_fab',
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: () => _openNewChatSheet(context),
          tooltip: 'New Conversation',
          child: const Icon(CupertinoIcons.chat_bubble_text_fill, size: 24),
        ),
      ),
    );
  }

  Widget _buildTabPill(String id, String label, bool isDark) {
    final isSelected = _activeTab == id;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context, ChatChannelModel channel, bool isDark) {
    final hasUnread = channel.unreadCount > 0;

    return InkWell(
      onTap: () {
        context.push(RoutePaths.chatThread(channel.id));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: hasUnread
            ? (isDark
                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                : const Color(0xFFEFF6FF))
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            if (channel.isProject)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: AppImageHelper.buildImage(
                    path: channel.projectImageUrl,
                    fit: BoxFit.cover,
                    placeholder: () => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(CupertinoIcons.folder_badge_person_crop, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ),
              )
            else
              AppAvatar(
                imageUrl: channel.otherUser?.avatarUrl,
                name: channel.otherUser?.fullName ?? 'Colleague',
                size: 48,
                showBorder: true,
                borderColor: const Color(0xFF2563EB),
                borderWidth: 1.5,
              ),
            const SizedBox(width: 14),
            // Middle Content: Title, Snippet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.title,
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (channel.isProject && channel.projectCode != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            channel.projectCode!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    channel.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      color: hasUnread
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right Side: Time and Unread Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(channel.updatedAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    color: hasUnread
                        ? const Color(0xFF2563EB)
                        : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(height: 5),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      channel.unreadCount > 99 ? '99+' : channel.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openNewChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _NewChatBottomSheet(),
    );
  }
}

class _NewChatBottomSheet extends ConsumerStatefulWidget {
  const _NewChatBottomSheet();

  @override
  ConsumerState<_NewChatBottomSheet> createState() => _NewChatBottomSheetState();
}

class _NewChatBottomSheetState extends ConsumerState<_NewChatBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final currentUserId = authState.currentUser?.id ?? '';

    final users = ref.watch(userManagementProvider);
    final projects = ref.watch(projectProvider);

    final filteredUsers = users.where((u) {
      if (u.id == currentUserId) return false;
      if (_query.isEmpty) return true;
      return u.name.toLowerCase().contains(_query) ||
          u.email.toLowerCase().contains(_query) ||
          u.department.toLowerCase().contains(_query);
    }).toList();

    final filteredProjects = projects.where((p) {
      if (_query.isEmpty) return true;
      return p.name.toLowerCase().contains(_query) ||
          p.projectId.toLowerCase().contains(_query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Conversation',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search people or projects...',
                  hintStyle: TextStyle(fontSize: 13),
                  prefixIcon: Icon(CupertinoIcons.search, size: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Colleagues'),
              Tab(text: 'Project Rooms'),
            ],
          ),
          Expanded(
            child: _isCreating
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Colleagues list
                      filteredUsers.isEmpty
                          ? const Center(child: Text('No colleagues found'))
                          : ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (ctx, i) {
                                final user = filteredUsers[i];
                                return ListTile(
                                  leading: AppAvatar(
                                    imageUrl: user.avatarUrl,
                                    name: user.name,
                                    size: 40,
                                  ),
                                  title: Text(
                                    user.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                  ),
                                  subtitle: Text(
                                    '${user.role.displayName}${user.department.isNotEmpty ? ' • ${user.department}' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                  trailing: const Icon(CupertinoIcons.chat_bubble, size: 18, color: Color(0xFF2563EB)),
                                  onTap: () => _startDirectChat(user),
                                );
                              },
                            ),
                      // Projects list
                      filteredProjects.isEmpty
                          ? const Center(child: Text('No projects found'))
                          : ListView.builder(
                              itemCount: filteredProjects.length,
                              itemBuilder: (ctx, i) {
                                final proj = filteredProjects[i];
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: AppImageHelper.buildImage(
                                        path: proj.imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: () => Container(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                          child: const Center(
                                            child: Icon(CupertinoIcons.folder_fill, color: Color(0xFF2563EB), size: 20),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    proj.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                  ),
                                  subtitle: Text(
                                    '${proj.projectId} • ${proj.status.name.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                  trailing: const Icon(CupertinoIcons.arrow_right_circle, size: 20, color: Color(0xFF2563EB)),
                                  onTap: () => _startProjectChat(proj),
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDirectChat(UserModel user) async {
    setState(() => _isCreating = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final channelId = await repo.getOrCreateDirectChannel(user.id);
      if (mounted) {
        Navigator.pop(context); // Close sheet
        if (channelId.isNotEmpty) {
          ref.read(chatChannelsProvider.notifier).fetchChannels(silent: true);
          context.push(RoutePaths.chatThread(channelId));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  Future<void> _startProjectChat(ProjectModel project) async {
    setState(() => _isCreating = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final channelId = await repo.getOrCreateProjectChannel(project.id);
      if (mounted) {
        Navigator.pop(context); // Close sheet
        if (channelId.isNotEmpty) {
          ref.read(chatChannelsProvider.notifier).fetchChannels(silent: true);
          context.push(RoutePaths.chatThread(channelId));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open project room: $e')),
        );
      }
    }
  }
}
