// MODIFIED: Service for handling manual transaction creation with Cash tag dual-effect (Feature A)
import 'dart:developer';
import 'package:get/get.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'local_db_service/local_db_service.dart';
import 'local_storage_service.dart';
import 'cash_tag_service.dart';
import '../utils/app_constants.dart';

/// Service for creating manual transactions with proper Cash tag handling
class ManualTransactionService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Create a manual transaction with Cash tag dual-effect if applicable
  Future<bool> createManualTransaction({
    required String txnDate,
    required String bankAccountNumber,
    required int tagId,
    required double amount,
    required String narration,
    required String txnType, // 'CR' or 'DR'
  }) async {
    try {
      final accountId = LocalStorageService.instance.accountId;
      if (accountId <= 0) {
        log('[ManualTransactionService] Invalid account ID');
        return false;
      }

      final db = await _db.database;

      // Execute in transaction for atomicity
      await db.transaction((txn) async {
        // Insert the bank transaction
        final now = DateTime.now().toIso8601String();
        final txnId = await _db.insertTransaction({
          TXN_DATE: txnDate,
          TXN_ACCOUNT_ID: bankAccountNumber,
          TXN_TAG_ID: tagId,
          TXN_AMOUNT: amount,
          TXN_NARRATION: narration,
          TXN_TYPE: txnType.toUpperCase(),
          TXN_REF: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
          TXN_IS_MANUAL: 1,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        }, executor: txn);

        if (txnId <= 0) {
          throw Exception('Failed to insert transaction');
        }

        // Recompute bank balance
        await _db.recomputeAndSave(bankAccountNumber, executor: txn);

        // Check if this is a Cash tag transaction
        if (Get.isRegistered<CashTagService>()) {
          final cashTagService = Get.find<CashTagService>();
          if (cashTagService.isCashTag(tagId)) {
            // Apply dual-effect
            await cashTagService.applyDualEffect(
              txnType: txnType,
              txnAmount: amount,
              txnDate: txnDate,
              txnNarration: narration,
              bankAccountNumber: bankAccountNumber,
              executor: txn,
            );
          }
        }
      });

      log('[ManualTransactionService] Manual transaction created successfully');
      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('[ManualTransactionService] createManualTransaction error: $e');
      return false;
    }
  }
}
