import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leave_model.dart';
import '../repositories/leave_repository.dart';
import 'auth_provider.dart';

class LeaveState {
  final List<LeaveRecordModel> leaves;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String activeFilter; // 'all', 'approved', 'pending', 'rejected'

  const LeaveState({
    this.leaves = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.activeFilter = 'all',
  });

  LeaveState copyWith({
    List<LeaveRecordModel>? leaves,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? activeFilter,
  }) {
    return LeaveState(
      leaves: leaves ?? this.leaves,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  List<LeaveRecordModel> get filteredLeaves {
    switch (activeFilter) {
      case 'approved':
        return leaves.where((l) => l.isApproved).toList();
      case 'pending':
        return leaves.where((l) => l.isPending).toList();
      case 'rejected':
        return leaves.where((l) => l.isRejected).toList();
      case 'all':
      default:
        return leaves;
    }
  }

  int get casualDaysUsed => leaves
      .where((l) => l.isApproved && l.leaveType.toLowerCase() == 'casual')
      .fold<int>(0, (sum, l) => sum + l.totalDays);

  int get sickDaysUsed => leaves
      .where((l) => l.isApproved && l.leaveType.toLowerCase() == 'sick')
      .fold<int>(0, (sum, l) => sum + l.totalDays);

  int get emergencyDaysUsed => leaves
      .where((l) => l.isApproved && l.leaveType.toLowerCase() == 'emergency')
      .fold<int>(0, (sum, l) => sum + l.totalDays);

  int get unpaidDaysUsed => leaves
      .where((l) => l.isApproved && l.leaveType.toLowerCase() == 'unpaid')
      .fold<int>(0, (sum, l) => sum + l.totalDays);
}

final leaveProvider = NotifierProvider<LeaveNotifier, LeaveState>(() {
  return LeaveNotifier();
});

class LeaveNotifier extends Notifier<LeaveState> {
  @override
  LeaveState build() {
    return const LeaveState();
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> fetchLeaves({bool force = false}) async {
    final user = ref.read(authProvider).currentUser;
    if (user == null || user.id.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final leaves = await repo.getLeaves(
        userId: user.role.canApproveMembers ? null : user.id,
      );
      // Sort newest start date first
      leaves.sort((a, b) => b.startDate.compareTo(a.startDate));
      state = state.copyWith(leaves: leaves, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> applyLeave({
    required String startDate,
    required String endDate,
    required String leaveType,
    required String reason,
  }) async {
    final user = ref.read(authProvider).currentUser;
    if (user == null || user.id.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please log in to submit leave request',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final newRecord = await repo.createLeave(
        userId: user.id,
        startDate: startDate,
        endDate: endDate,
        leaveType: leaveType,
        reason: reason,
        // Submission creates a request for review for every role. Approval is
        // performed through the explicit review action, never on create.
        isApproved: false,
      );

      final updated = [
        newRecord,
        ...state.leaves.where((l) => l.id != newRecord.id),
      ];
      updated.sort((a, b) => b.startDate.compareTo(a.startDate));
      state = state.copyWith(leaves: updated, isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> cancelLeave(String id) async {
    try {
      final repo = ref.read(leaveRepositoryProvider);
      await repo.deleteLeave(id);
      final updated = state.leaves.where((l) => l.id != id).toList();
      state = state.copyWith(leaves: updated);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> decideLeave(String id, {required bool approved}) async {
    try {
      final repo = ref.read(leaveRepositoryProvider);
      await repo.decideLeave(id, approved: approved);
      await fetchLeaves(force: true);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}
