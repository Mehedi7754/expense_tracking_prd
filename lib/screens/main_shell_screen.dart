import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/routing/route_paths.dart';
import '../core/services/realtime_sync_service.dart';
import '../core/widgets/app_bottom_nav_bar.dart';
import '../core/widgets/home_location_setup_modal.dart';
import '../core/widgets/quick_access_dock_menu.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../state/auth_provider.dart';
import '../state/expense_provider.dart';
import '../state/notification_provider.dart';
import '../state/attendance_provider.dart';
import '../state/chat_provider.dart';
import 'approvals/approvals_queue_screen.dart';
import 'attendance/attendance_dashboard_screen.dart';
import 'attendance/my_attendance_screen.dart';
import 'chat/chat_list_screen.dart';
import 'expenses/my_expenses_screen.dart';
import 'home/home_dashboard_screen.dart';
import 'projects/projects_list_screen.dart';
import 'reports/reports_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 2;
  bool _quickMenuOpen = false;
  UserRole? _lastRole;
  static bool _hasPromptedHomeLocationThisSession = false;

  void _checkEmployeeHomeLocationPrompt(UserModel user) {
    if (_hasPromptedHomeLocationThisSession) return;
    // Strictly for employee (projectMember) only, never for admin
    if (user.role != UserRole.projectMember) return;

    final hasLocation = user.homeLatitude != null &&
        user.homeLongitude != null &&
        !(user.homeLatitude == 0.0 && user.homeLongitude == 0.0);

    if (!hasLocation) {
      _hasPromptedHomeLocationThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HomeLocationSetupModal.show(context, user, isMandatoryPrompt: true);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Auth flow (login/restoreSession) already triggers fetches.
    // TTL cache in each notifier prevents redundant calls on tab switches.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;

    if (user == null || !authState.isAuthenticated) {
      return const Scaffold(body: Center(child: SizedBox.shrink()));
    }

    // Check if employee needs to set their home/office location for geofencing
    _checkEmployeeHomeLocationPrompt(user);

    // Start real-time notification & app data sync loop
    RealtimeSyncService.instance.initialize(ref);

    // Pre-warm chat channels in memory so chat list opens in 0ms
    ref.watch(chatChannelsProvider);
    ref.watch(chatUnreadCountProvider);

    final role = user.role;

    // Reset tab to 2 (center notch) if the role was switched
    if (_lastRole != role) {
      _lastRole = role;
      _currentIndex = 2;
    }

    final expenses = ref.watch(expenseProvider);
    final pendingCount =
        expenses.where((e) => e.status == ExpenseStatus.pending).length;

    final notifications = ref.watch(notificationProvider);
    final unreadNotifsCount =
        notifications.where((n) {
          return (n.userId == user.id || n.userId.isEmpty) && !n.isRead;
        }).length;

    final unreadChatCount = ref.watch(chatUnreadCountProvider);

    final List<Widget> screens = _getScreensForRole(role);

    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: _currentIndex.clamp(0, screens.length - 1),
            children: screens,
          ),
          QuickAccessDockMenu(
            role: role,
            expanded: _quickMenuOpen,
            onClose: () {
              if (_quickMenuOpen) setState(() => _quickMenuOpen = false);
            },
            onNavigate: (path) {
              setState(() => _quickMenuOpen = false);
              if (path == RoutePaths.homeLocation) {
                HomeLocationSetupModal.show(context, user);
              } else {
                context.push(path);
              }
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNavBar(
              role: role,
              currentIndex: _currentIndex,
              menuOpen: _quickMenuOpen,
              onMenuTap: () => setState(() => _quickMenuOpen = !_quickMenuOpen),
              pendingApprovalsCount: pendingCount,
              unreadNotificationsCount: unreadNotifsCount,
              unreadChatCount: unreadChatCount,
              onTap: (index) {
                setState(() {
                  _quickMenuOpen = false;
                  _currentIndex = index;
                });
                if (role == UserRole.projectMember && index == 1) {
                  ref
                      .read(attendanceProvider.notifier)
                      .fetchAttendanceRecords(userId: user.id, force: true);
                } else if (role != UserRole.projectMember &&
                    role != UserRole.viewer &&
                    index == 1) {
                  ref.read(expenseProvider.notifier).fetchExpenses(force: true);
                } else if (role != UserRole.projectMember &&
                    role != UserRole.viewer &&
                    index == 4) {
                  ref
                      .read(attendanceProvider.notifier)
                      .fetchDailyOverview(force: true);
                }
              },
              onAddTap: () => _handleCenterAction(context, user),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCenterAction(BuildContext context, UserModel user) {
    final role = user.role;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.78,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF312E81)
                            : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: Color(0xFF4F46E5),
                    size: 22,
                  ),
                ),
                title: Text(
                  role == UserRole.projectMember
                      ? 'My Tasks'
                      : 'Task Management',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: const Text(
                  'View assignments and update task status',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(RoutePaths.tasks);
                },
              ),
              const Divider(height: 16),
              if (role == UserRole.projectMember) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF065F46)
                              : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: Color(0xFF059669),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Leave Requests',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Apply for leave or view leave status',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(RoutePaths.leaves);
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF0E7490)
                              : const Color(0xFFCFFAFE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF0891B2),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'My Financials & Salary',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'View earnings breakdown and payslips',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(RoutePaths.mySalary);
                  },
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Home / Office Location',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Setup location coordinates for geofenced attendance',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    HomeLocationSetupModal.show(context, user);
                  },
                ),
                const Divider(height: 16),
              ],
              if (role.canApproveExpenses) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF312E81)
                              : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Expense Approvals Queue',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Review & batch approve employee cost claims',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(RoutePaths.approvalsQueue);
                  },
                ),
                const Divider(height: 16),
              ],
              if (role.canCreateProject) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF312E81)
                              : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.business_center_rounded,
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Create New Project',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Setup scope, requirements, budget & team',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(RoutePaths.addProject);
                  },
                ),
                const Divider(height: 16),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF064E3B)
                            : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Submit Expense Claim',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: const Text(
                  'Record project expenditure with receipt',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(RoutePaths.submitExpense);
                },
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Team Messenger & Chat',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: const Text(
                  'Direct messaging and project team rooms',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(RoutePaths.chatList);
                },
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  List<Widget> _getScreensForRole(UserRole role) {
    switch (role) {
      case UserRole.projectMember:
        return const [
          MyExpensesScreen(),
          MyAttendanceScreen(),
          HomeDashboardScreen(),
          HomeDashboardScreen(),
          ChatListScreen(hasBottomDock: true),
        ];

      case UserRole.projectManager:
      case UserRole.finance:
      case UserRole.mainAdmin:
        return const [
          ProjectsListScreen(),
          ApprovalsQueueScreen(),
          HomeDashboardScreen(),
          HomeDashboardScreen(),
          AttendanceDashboardScreen(),
        ];

      case UserRole.viewer:
        return const [
          ProjectsListScreen(),
          ReportsScreen(),
          HomeDashboardScreen(),
          HomeDashboardScreen(),
          ChatListScreen(hasBottomDock: true),
        ];
    }
  }
}
