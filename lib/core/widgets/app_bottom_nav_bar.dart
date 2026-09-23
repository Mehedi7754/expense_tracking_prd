import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../constants/app_colors.dart';

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

  const AppBottomNavBar({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
    this.onAddTap,
    this.pendingApprovalsCount = 0,
    this.unreadNotificationsCount = 0,
  });

  List<NavItemData> _getLeftItems() {
    if (role == UserRole.projectMember) {
      return [
        const NavItemData(
          label: 'Home',
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
        ),
        const NavItemData(
          label: 'Expenses',
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
        ),
      ];
    }
    return [
      const NavItemData(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      const NavItemData(
        label: 'Projects',
        icon: Icons.business_center_outlined,
        activeIcon: Icons.business_center_rounded,
      ),
    ];
  }

  List<NavItemData> _getRightItems() {
    if (role == UserRole.projectMember) {
      return [
        NavItemData(
          label: 'Compliance',
          icon: Icons.verified_user_outlined,
          activeIcon: Icons.verified_user_rounded,
          badgeCount: unreadNotificationsCount,
        ),
        const NavItemData(
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
        ),
      ];
    }
    return [
      NavItemData(
        label: 'Approvals',
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
        badgeCount: pendingApprovalsCount,
      ),
      const NavItemData(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leftItems = _getLeftItems();
    final rightItems = _getRightItems();

    const activeColor = Color(0xFF4F46E5);
    final inactiveColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Left Item 1 (Index 0)
            Expanded(
              child: _buildNavItem(
                item: leftItems[0],
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ),

            // Left Item 2 (Index 1)
            Expanded(
              child: _buildNavItem(
                item: leftItems[1],
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ),

            // Center Floating Circular Add Button (Image 2 style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: const Offset(0, -10), // Float slightly above dock
                child: GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withAlpha(64),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right Item 1 (Index 2)
            Expanded(
              child: _buildNavItem(
                item: rightItems[0],
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ),

            // Right Item 2 (Index 3)
            Expanded(
              child: _buildNavItem(
                item: rightItems[1],
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required NavItemData item,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
              if (item.badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              color: isSelected ? activeColor : inactiveColor,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 10,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? activeColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
