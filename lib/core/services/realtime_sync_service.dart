import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../models/user_role.dart';
import '../../state/auth_provider.dart';
import '../../state/expense_provider.dart';
import '../../state/notification_provider.dart';
import '../../state/project_provider.dart';

/// Real-time background sync engine with dual event detection:
///
/// 1. Notification polling: polls backend notifications periodically.
/// 2. Live Data State Differential: polls expenses and projects.
/// 3. Lifecycle aware: pauses polling when backgrounded to save resources.
class RealtimeSyncService with WidgetsBindingObserver {
  RealtimeSyncService._();

  static final RealtimeSyncService instance = RealtimeSyncService._();

  Timer? _notificationSyncTimer;
  Timer? _dataSyncTimer;
  ProviderContainer? _container;
  bool _isInitialized = false;
  bool _isSyncing = false;

  /// Tracks previous status of expenses to detect real-time status transitions.
  final Map<String, ExpenseStatus> _previousExpenseStatuses = <String, ExpenseStatus>{};
  bool _expenseBaselineRecorded = false;

  void initialize(WidgetRef ref) {
    try {
      _container = ref.container;
    } catch (_) {}

    if (_isInitialized) return;

    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    startSyncLoop();
  }

  void startSyncLoop() {
    _notificationSyncTimer?.cancel();
    _dataSyncTimer?.cancel();

    // Notification polling
    _notificationSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollNotifications();
    });

    // Live data sync
    _dataSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _syncAppData();
    });
  }

  void stopSyncLoop() {
    _notificationSyncTimer?.cancel();
    _dataSyncTimer?.cancel();
    _notificationSyncTimer = null;
    _dataSyncTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startSyncLoop();
      _pollNotifications(forceImmediateRefresh: true);
      _syncAppData(forceImmediate: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      stopSyncLoop();
    }
  }

  Future<void> _pollNotifications({bool forceImmediateRefresh = false}) async {
    final container = _container;
    if (container == null) return;

    try {
      final authState = container.read(authProvider);
      if (!authState.isAuthenticated || authState.currentUser == null) return;

      // Authoritatively fetch remote notifications into Riverpod state
      await container.read(notificationProvider.notifier).fetchNotifications();

      if (forceImmediateRefresh) {
        await _syncAppData();
      }
    } catch (_) {}
  }

  /// Syncs live expense & project records and detects status differentials.
  Future<void> _syncAppData({bool forceImmediate = false}) async {
    final container = _container;
    if (container == null || _isSyncing) return;

    try {
      final authState = container.read(authProvider);
      if (!authState.isAuthenticated || authState.currentUser == null) return;

      _isSyncing = true;
      await Future.wait([
        container.read(expenseProvider.notifier).fetchExpenses(force: true),
        container.read(projectProvider.notifier).fetchProjects(force: true),
      ]);

      final allExpenses = container.read(expenseProvider);

      if (!_expenseBaselineRecorded) {
        // Record baseline state on first run
        for (final exp in allExpenses) {
          _previousExpenseStatuses[exp.id] = exp.status;
        }
        _expenseBaselineRecorded = true;
        return;
      }

      for (final exp in allExpenses) {
        _previousExpenseStatuses[exp.id] = exp.status;
      }
    } catch (_) {
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    stopSyncLoop();
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _isInitialized = false;
    _container = null;
  }
}
