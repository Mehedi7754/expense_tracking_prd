import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_env.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/fcm_service.dart';
import 'state/settings_provider.dart';
import 'state/auth_provider.dart';
import 'models/user_role.dart';
import 'core/services/notification_router.dart';
import 'state/attendance_settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.initialize();

  // Initialize OS-level push notification & FCM service asynchronously without blocking startup
  PushNotificationService.instance.initialize().catchError((_) {});
  FcmService.instance.initialize().catchError((_) {});

  runApp(
    const ProviderScope(
      child: GWProjectApp(),
    ),
  );
}


UserRole? _lastRole;

class GWProjectApp extends ConsumerWidget {
  const GWProjectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    NotificationRouter.attach(router);

    // Employees only get check-in reminders; Super Admin / Finance / Viewer never do
    final role = ref.watch(authProvider.select((s) => s.currentUser?.role));
    if (role != _lastRole) {
      _lastRole = role;
      final isEmployee = role == UserRole.projectMember || role == UserRole.projectManager;
      NotificationRouter.canManageAttendance = role?.canManageAttendanceAndSalary ?? false;
      final attSettings = ref.read(attendanceSettingsProvider).value;
      PushNotificationService.instance.syncAttendanceReminders(
        isEmployee: isEmployee,
        morningHour: attSettings?.morningStartHour ?? 9,
        cutoffHour: attSettings?.morningEndHour ?? 13,
      );
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}

typedef SpendWiseApp = GWProjectApp;

