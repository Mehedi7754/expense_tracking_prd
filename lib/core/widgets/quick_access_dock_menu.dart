import 'package:flutter/material.dart';

import '../../models/user_role.dart';

/// Role-aware drawer overlay opened from the Menu item in the bottom dock.
class QuickAccessDockMenu extends StatelessWidget {
  const QuickAccessDockMenu({
    super.key,
    required this.role,
    required this.expanded,
    required this.onClose,
    required this.onNavigate,
  });

  final UserRole role;
  final bool expanded;
  final VoidCallback onClose;
  final ValueChanged<String> onNavigate;

  List<_QuickDestination> get _destinations {
    if (role == UserRole.projectMember) {
      return const [
        _QuickDestination('My Tasks', '/tasks', Icons.task_alt_rounded),
        _QuickDestination('My Pay', '/salary/my', Icons.payments_outlined),
        _QuickDestination(
          'My Attendance',
          '/attendance/my',
          Icons.how_to_reg_outlined,
        ),
        _QuickDestination(
          'Request Leave',
          '/leaves/apply',
          Icons.event_available_outlined,
        ),
        _QuickDestination(
          'My Expenses',
          '/expenses/my',
          Icons.receipt_long_outlined,
        ),
        _QuickDestination(
          'Messages',
          '/chat',
          Icons.chat_bubble_outline_rounded,
        ),
      ];
    }
    if (role == UserRole.viewer) {
      return const [
        _QuickDestination('Projects', '/projects', Icons.folder_open_outlined),
        _QuickDestination('Reports', '/reports', Icons.analytics_outlined),
        _QuickDestination(
          'Messages',
          '/chat',
          Icons.chat_bubble_outline_rounded,
        ),
      ];
    }

    final destinations = <_QuickDestination>[
      const _QuickDestination('Tasks', '/tasks', Icons.task_alt_rounded),
    ];
    if (role.canCreateProject) {
      destinations.add(
        const _QuickDestination(
          'Assign task',
          '/tasks/new',
          Icons.person_add_alt_1_rounded,
        ),
      );
    }
    destinations.addAll(const [
      _QuickDestination('Payroll', '/salary', Icons.payments_outlined),
      _QuickDestination('Reports', '/reports', Icons.analytics_outlined),
      _QuickDestination('Attendance', '/attendance', Icons.how_to_reg_outlined),
      _QuickDestination('Leave', '/leaves', Icons.event_available_outlined),
      _QuickDestination('Messages', '/chat', Icons.chat_bubble_outline_rounded),
    ]);
    return destinations;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final width = (screen.width - 24).clamp(220.0, 400.0);
    final maxHeight = (screen.height * 0.48).clamp(220.0, 390.0);
    const dockBlue = Color(0xFF2563EB);

    return IgnorePointer(
      ignoring: !expanded,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              color: Colors.black.withValues(alpha: expanded ? 0.12 : 0),
            ),
          ),
          Positioned(
            right: 16,
            // Keep the panel attached to the dock edge so it reads as an
            // expansion of the Menu button, especially on narrow screens.
            bottom: bottom + 60,
            child: ExcludeSemantics(
              excluding: !expanded,
              child: ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.bottomRight,
                  widthFactor: 1,
                  heightFactor: expanded ? 1 : 0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: AnimatedScale(
                    scale: expanded ? 1 : 0.97,
                    alignment: Alignment.bottomRight,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: Material(
                      color: theme.colorScheme.surface,
                      elevation: 16,
                      shadowColor: const Color(0x26334155),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(19),
                        topRight: Radius.circular(19),
                        bottomLeft: Radius.circular(19),
                        bottomRight: Radius.circular(13),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        width: width.toDouble(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxHeight.toDouble(),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(13, 7, 7, 7),
                                decoration: const BoxDecoration(
                                  color: dockBlue,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.grid_view_rounded,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 9),
                                    const Expanded(
                                      child: Text(
                                        'More',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Close menu',
                                      onPressed: onClose,
                                      visualDensity: VisualDensity.compact,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 32,
                                            height: 32,
                                          ),
                                      color: Colors.white,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 5,
                                  ),
                                  itemCount: _destinations.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 1),
                                  itemBuilder:
                                      (context, index) => _destinationTile(
                                        context,
                                        _destinations[index],
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationTile(BuildContext context, _QuickDestination destination) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          onClose();
          onNavigate(destination.path);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  destination.icon,
                  size: 16,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  destination.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.65,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickDestination {
  const _QuickDestination(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
}
