import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

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
  final int pendingApprovalsCount;
  final int unreadNotificationsCount;

  const AppBottomNavBar({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
    this.pendingApprovalsCount = 0,
    this.unreadNotificationsCount = 0,
  });

  List<NavItemData> _getNavItems() {
    switch (role) {
      case UserRole.employee:
        // Employee: Home, Submit Expense, My Expenses, Notifications, Profile (PRD Section 3)
        return [
          const NavItemData(
            label: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
          ),
          const NavItemData(
            label: 'Submit',
            icon: Icons.add_circle_outline_rounded,
            activeIcon: Icons.add_circle_rounded,
          ),
          const NavItemData(
            label: 'Expenses',
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
          ),
          NavItemData(
            label: 'Alerts',
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            badgeCount: unreadNotificationsCount,
          ),
          const NavItemData(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
          ),
        ];

      case UserRole.manager:
      case UserRole.finance:
        // Manager / Finance: Home, Approvals, Projects, Reports, Profile (PRD Section 3)
        return [
          const NavItemData(
            label: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
          ),
          NavItemData(
            label: 'Approvals',
            icon: Icons.fact_check_outlined,
            activeIcon: Icons.fact_check_rounded,
            badgeCount: pendingApprovalsCount,
          ),
          const NavItemData(
            label: 'Projects',
            icon: Icons.folder_open_rounded,
            activeIcon: Icons.folder_rounded,
          ),
          const NavItemData(
            label: 'Reports',
            icon: Icons.bar_chart_rounded,
            activeIcon: Icons.analytics_rounded,
          ),
          const NavItemData(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
          ),
        ];

      case UserRole.admin:
        // Administrator: Home, Approvals, Company, Reports, Profile (PRD Section 3)
        return [
          const NavItemData(
            label: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
          ),
          NavItemData(
            label: 'Approvals',
            icon: Icons.fact_check_outlined,
            activeIcon: Icons.fact_check_rounded,
            badgeCount: pendingApprovalsCount,
          ),
          const NavItemData(
            label: 'Company',
            icon: Icons.business_outlined,
            activeIcon: Icons.business_rounded,
          ),
          const NavItemData(
            label: 'Reports',
            icon: Icons.bar_chart_rounded,
            activeIcon: Icons.analytics_rounded,
          ),
          const NavItemData(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _getNavItems();
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        boxShadow: AppColors.floatingShadow(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.getBorder(context).withValues(alpha: 0.8),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;

              final activeColor = isDark ? AppColors.darkPrimary : AppColors.primary;
              final inactiveColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
              final activePillColor = isDark
                  ? AppColors.darkPrimarySubtle.withValues(alpha: 0.8)
                  : AppColors.primarySubtle.withValues(alpha: 0.6);

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? activePillColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 22,
                                color: isSelected ? activeColor : inactiveColor,
                              ),
                            ),
                            if (item.badgeCount > 0)
                              Positioned(
                                top: -4,
                                right: -9,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.crimson,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.crimson.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                                  child: Text(
                                    item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
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
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? activeColor : inactiveColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
