import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import 'audit_log_screen.dart';
import 'category_management_screen.dart';
import 'company_setup_screen.dart';
import 'user_management_screen.dart';

/// Centralized Administrative Control Center for PRD Section 4.6
/// Seamlessly unites Company Setup, User Management, Category Management, and Audit Trail.
class CompanyHubScreen extends ConsumerStatefulWidget {
  const CompanyHubScreen({super.key});

  @override
  ConsumerState<CompanyHubScreen> createState() => _CompanyHubScreenState();
}

class _CompanyHubScreenState extends ConsumerState<CompanyHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company & Governance', style: AppTextStyles.titleMedium),
            Text(
              'Enterprise administrative controls',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.getTextMuted(context)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Invite / Add User',
            onPressed: () => context.push(RoutePaths.addUser),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          indicatorWeight: 3,
          indicatorColor: AppColors.getPrimary(context),
          labelColor: AppColors.getPrimary(context),
          unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          tabs: const [
            Tab(
              icon: Icon(Icons.business_rounded, size: 20),
              text: 'Profile',
            ),
            Tab(
              icon: Icon(Icons.people_alt_rounded, size: 20),
              text: 'Users',
            ),
            Tab(
              icon: Icon(Icons.category_rounded, size: 20),
              text: 'Categories',
            ),
            Tab(
              icon: Icon(Icons.history_edu_rounded, size: 20),
              text: 'Audit',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CompanySetupScreen(isEmbedded: true),
          UserManagementScreen(isEmbedded: true),
          CategoryManagementScreen(isEmbedded: true),
          AuditLogScreen(isEmbedded: true),
        ],
      ),
    );
  }
}
