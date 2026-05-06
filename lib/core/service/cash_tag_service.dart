// MODIFIED: New service for managing the global Cash tag (Feature A)
import 'dart:developer';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'local_db_service/local_db_service.dart';
import 'local_storage_service.dart';
import '../utils/app_constants.dart';

/// Singleton service that manages the global 'Cash' tag.
/// Ensures the tag exists and provides its ID for dual-effect logic.
class CashTagService extends GetxService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  final RxInt cashTagId = 0.obs;
  final RxBool isInitialized = false.obs;

  /// Initialize the Cash tag on app startup
  Future<void> initialize() async {
    try {
      final accountId = LocalStorageService.instance.accountId;
      if (accountId <= 0) {
        log('[CashTagService] No authenticated account, skipping init');
        return;
      }
      final tagId = await _db.ensureCashTagExists(accountId);
      if (tagId > 0) {
        cashTagId.value = tagId;
        isInitialized.value = true;
        log('[CashTagService] Cash tag initialized with ID: $tagId');
      } else {
        log('[CashTagService] Failed to initialize Cash tag');
      }
    } catch (e) {
      log('[CashTagService] initialize error: $e');
    }
  }

  /// Apply dual-effect logic when a transaction is tagged with Cash
  /// This is called during import confirmation or manual transaction creation
  Future<bool> applyDualEffect({
    required String txnType,
    required double txnAmount,
    required String txnDate,
    required String txnNarration,
    required String bankAccountNumber,
    DatabaseExecutor? executor,
  }) async {
    if (cashTagId.value <= 0) {
      log('[CashTagService] Cash tag not initialized, skipping dual effect');
      return false;
    }

    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) {
      log('[CashTagService] Invalid account ID');
      return false;
    }

    try {
      // Get current cash wallet
      final cashWallet = await _db.getCashWallet(accountId, executor: executor);

      // If no cash wallet exists, create one
      if (cashWallet == null) {
        log('[CashTagService] No cash wallet found, creating one');
        final now = DateTime.now().toIso8601String();
        try {
          await _db.insertCashWallet({
            ACCOUNT_ID: accountId,
            CASH_WALLET_CURRENT_BALANCE: 0.0,
            DATE_ADDED: now,
            CREATED_AT: now,
            UPDATED_AT: now,
            DELETED_AT: null,
          }, executor: executor);
        } catch (e) {
          log('[CashTagService] Failed to insert cash wallet: $e');
          return false;
        }
      }

      final currentCashBalance =
          cashWallet?[CASH_WALLET_CURRENT_BALANCE] as double? ?? 0.0;
      double newCashBalance;
      String cashWalletTxnType;

      if (txnType.toUpperCase() == 'DR') {
        // ATM withdrawal / cash withdrawal from bank
        // Bank loses money (already handled by normal txn insert)
        // Cash wallet gains money
        newCashBalance = currentCashBalance + txnAmount;
        cashWalletTxnType = 'Cash Withdrawn From Bank';
      } else {
        // CR - cash deposit to bank / ATM deposit
        // Bank gains money (already handled by normal txn insert)
        // Cash wallet loses money (never go negative)
        newCashBalance = (currentCashBalance - txnAmount).clamp(
          0.0,
          double.infinity,
        );
        cashWalletTxnType = 'Cash Deposited To Bank';
      }

      // Update cash wallet balance
      try {
        await _db.updateCashWalletBalance(
          accountId,
          newCashBalance,
          executor: executor,
        );
      } catch (e) {
        log('[CashTagService] Failed to update cash wallet balance: $e');
        return false;
      }

      // Insert cash wallet transaction
      final now = DateTime.now().toIso8601String();
      try {
        await _db.insertCashWalletTransaction({
          ACCOUNT_ID: accountId,
          CASH_WALLET_TRANSACTION_TYPE: cashWalletTxnType,
          CASH_WALLET_TRANSACTION_AMOUNT: txnAmount,
          CASH_WALLET_TRANSACTION_TAG_ID: cashTagId.value,
          TRANSACTION_NOTE: 'Auto: $txnNarration',
          DATE_ADDED: txnDate,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        }, executor: executor);
      } catch (e) {
        log('[CashTagService] Failed to insert cash wallet transaction: $e');
        return false;
      }

      log(
        '[CashTagService] Dual effect applied successfully for $txnType transaction: '
        '$cashWalletTxnType, amount: ${txnType.toUpperCase() == 'DR' ? txnAmount : -txnAmount}, '
        'new balance: $newCashBalance',
      );
      return true;
    } catch (e) {
      log('[CashTagService] applyDualEffect error: $e');
      return false;
    }
  }

  /// Check if a tag ID is the Cash tag
  bool isCashTag(int? tagId) {
    return tagId != null && tagId == cashTagId.value;
  }
}
