import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import 'curved_dock_bar.dart';

class NavItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badgeCount;

  const NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount = 0,
  });
}

class AppBottomNavBar extends StatelessWidget {
  final UserRole role;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAddTap;
  final int pendingApprovalsCount;
  final int unreadNotificationsCount;
  final int unreadChatCount;

  const AppBottomNavBar({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
    this.onAddTap,
    this.pendingApprovalsCount = 0,
    this.unreadNotificationsCount = 0,
    this.unreadChatCount = 0,
  });

  List<NavItemData> _getAllItems() {
    if (role == UserRole.projectMember) {
      return [
        const NavItemData(
          label: 'Expenses',
          icon: CupertinoIcons.doc_plaintext,
          activeIcon: CupertinoIcons.doc_text_fill,
        ),
        const NavItemData(
          label: 'Attendance',
          icon: CupertinoIcons.clock,
          activeIcon: CupertinoIcons.clock_fill,
        ),
        const NavItemData(
          label: 'Home',
          icon: CupertinoIcons.house,
          activeIcon: CupertinoIcons.house_fill,
        ),
        const NavItemData(
          label: 'Add',
          icon: CupertinoIcons.plus_circle,
          activeIcon: CupertinoIcons.plus_circle_fill,
        ),
        NavItemData(
          label: 'Chat',
          icon: CupertinoIcons.chat_bubble_2,
          activeIcon: CupertinoIcons.chat_bubble_2_fill,
          badgeCount: unreadChatCount,
        ),
      ];
    }
    if (role == UserRole.viewer) {
      return [
        const NavItemData(
          label: 'Projects',
          icon: CupertinoIcons.briefcase,
          activeIcon: CupertinoIcons.briefcase_fill,
        ),
        const NavItemData(
          label: 'Reports',
          icon: CupertinoIcons.chart_pie,
          activeIcon: CupertinoIcons.chart_pie_fill,
        ),
        const NavItemData(
          label: 'Home',
          icon: CupertinoIcons.house,
          activeIcon: CupertinoIcons.house_fill,
        ),
        const NavItemData(
          label: 'Add',
          icon: CupertinoIcons.plus_circle,
          activeIcon: CupertinoIcons.plus_circle_fill,
        ),
        NavItemData(
          label: 'Chat',
          icon: CupertinoIcons.chat_bubble_2,
          activeIcon: CupertinoIcons.chat_bubble_2_fill,
          badgeCount: unreadChatCount,
        ),
      ];
    }
    return [
      const NavItemData(
        label: 'Projects',
        icon: CupertinoIcons.briefcase,
        activeIcon: CupertinoIcons.briefcase_fill,
      ),
      NavItemData(
        label: 'Approvals',
        icon: CupertinoIcons.checkmark_seal,
        activeIcon: CupertinoIcons.checkmark_seal_fill,
        badgeCount: pendingApprovalsCount,
      ),
      const NavItemData(
        label: 'Home',
        icon: CupertinoIcons.house,
        activeIcon: CupertinoIcons.house_fill,
      ),
      const NavItemData(
        label: 'Add',
        icon: CupertinoIcons.plus_circle,
        activeIcon: CupertinoIcons.plus_circle_fill,
      ),
      const NavItemData(
        label: 'Attendance',
        icon: CupertinoIcons.clock,
        activeIcon: CupertinoIcons.clock_fill,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _getAllItems();

    // Vibrant Electric Blue & Indigo dock bar (matching reference image #1, #2, #5)
    final dockColor = const Color(0xFF2563EB); // Vibrant Electric Royal Blue
    final buttonBg = const Color(0xFF1D4ED8); // Deep vibrant blue floating hub
    final activeIconColor = Colors.white;
    final inactiveIconColor = const Color(0xFFBFDBFE); // Soft pastel blue

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CurvedDockBar(
          index: currentIndex.clamp(0, items.length - 1),
          height: 60.0,
          color: dockColor,
          buttonBackgroundColor: buttonBg,
          backgroundColor: Colors.transparent,
            animationDuration: const Duration(milliseconds: 320),
            animationCurve: Curves.easeInOutCubic,
            letIndexChange: (index) {
              if (index == 3) {
                if (onAddTap != null) {
                  onAddTap!();
                }
                return false;
              }
              return true;
            },
            onTap: onTap,
            items: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isSelected = idx == currentIndex;

              return Tooltip(
                message: item.label,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? activeIconColor : inactiveIconColor,
                      size: isSelected ? 22 : 20,
                    ),
                    if (item.badgeCount > 0)
                      Positioned(
                        top: isSelected ? -2 : -4,
                        right: isSelected ? -5 : -7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                          child: Text(
                            item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (bottomInset > 0)
          Container(
            height: bottomInset,
            width: double.infinity,
            color: dockColor,
          ),
      ],
    );
  }
}
