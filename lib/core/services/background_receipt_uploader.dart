import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/file_upload_repository.dart';
import '../../state/expense_provider.dart';
import 'push_notification_service.dart';

/// Background task manager for uploading receipt images asynchronously.
///
/// Ensures expense claims submit instantly in the UI with optimistic local paths,
/// while uploading receipt photos in the background and linking them to the server.
class BackgroundReceiptUploader {
  BackgroundReceiptUploader._();

  static final BackgroundReceiptUploader instance = BackgroundReceiptUploader._();

  final Set<String> _pendingExpenseIds = <String>{};

  bool isUploading(String expenseId) => _pendingExpenseIds.contains(expenseId);

  /// Enqueues a receipt upload for [expenseId] using [localFilePath].
  /// This runs completely in the background without blocking UI or navigation.
  void enqueue({
    required String expenseId,
    required String localFilePath,
    required dynamic ref,
  }) {
    if (localFilePath.isEmpty || localFilePath.startsWith('http://') || localFilePath.startsWith('https://')) {
      return;
    }

    _pendingExpenseIds.add(expenseId);

    // Fire un-awaited background async task
    unawaited(_processUpload(
      expenseId: expenseId,
      localFilePath: localFilePath,
      ref: ref,
    ));
  }

  Future<void> _processUpload({
    required String expenseId,
    required String localFilePath,
    required dynamic ref,
  }) async {
    try {
      debugPrint('[BackgroundReceiptUploader] Starting background upload for expense: $expenseId');

      final fileUploadRepo = ref.read(fileUploadRepositoryProvider);
      final uploadResult = await fileUploadRepo.upload(
        filePathOrDataUri: localFilePath,
        category: UploadCategory.receipts,
        entityId: expenseId,
      );

      final remoteUrl = uploadResult.url;
      debugPrint('[BackgroundReceiptUploader] Upload succeeded for $expenseId -> $remoteUrl');

      // 1. Update local Riverpod state so UI displays server URL
      ref.read(expenseProvider.notifier).updateExpenseReceiptUrl(expenseId, remoteUrl);

      // 2. Patch backend database with the remote receipt URL
      try {
        final expenseRepo = ref.read(expenseRepositoryProvider);
        final currentExpenses = ref.read(expenseProvider);
        final matching = currentExpenses.where((e) => e.id == expenseId).toList();

        if (matching.isNotEmpty && !matching.first.id.startsWith('exp_')) {
          final expense = matching.first;
          await expenseRepo.updateExpense(
            expense.copyWith(
              receiptPhotoUrl: remoteUrl,
              hasReceipt: true,
              justificationStatus: JustificationStatus.none,
            ),
          );
        }
      } catch (backendError) {
        debugPrint('[BackgroundReceiptUploader] Warning: Could not patch backend expense record: $backendError');
      }

      // 3. Notify user with confirmation
      PushNotificationService.instance.showExpenseAlert(
        title: 'Receipt Upload Complete ✓',
        body: 'Receipt attached and synchronized to cloud.',
        expenseId: expenseId,
        notificationId: 'upload_$expenseId',
      );
    } catch (e) {
      debugPrint('[BackgroundReceiptUploader] Error uploading receipt in background for $expenseId: $e');
    } finally {
      _pendingExpenseIds.remove(expenseId);
    }
  }
}
