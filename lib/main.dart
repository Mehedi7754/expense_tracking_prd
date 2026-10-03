import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_env.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.initialize();

  // Initialize OS-level push notification service safely
  try {
    await PushNotificationService.instance.initialize();
    // Fire schedule in background
    PushNotificationService.instance.scheduleDailyAttendanceReminder(
      id: 1,
      title: '📍 Morning Check-in Reminder',
      body: "Don't forget to mark your attendance for today!",
      hour: 9,
      minute: 0,
    );
    PushNotificationService.instance.scheduleDailyAttendanceReminder(
      id: 2,
      title: '📍 End-of-Day Check-out',
      body: 'Please mark your check-out before leaving.',
      hour: 17,
      minute: 0,
    );
  } catch (e) {
    debugPrint('[Main] PushNotificationService init: $e');
  }

  runApp(
    const ProviderScope(
      child: GWProjectApp(),
    ),
  );
}


class GWProjectApp extends ConsumerWidget {
  const GWProjectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);

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

