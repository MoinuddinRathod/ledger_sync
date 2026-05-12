import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/service/dialog_service.dart';
import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/snackbar_service.dart';
import '../../../core/service/manual_transaction_service.dart';
import '../../../core/utils/balance_validator.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../../bank_account/models/bank_account_model.dart';
import '../../cash_wallet/repository/cash_wallet_repository.dart';
import '../../cash_wallet/models/cash_wallet_transaction_model.dart';
import '../../bank_account/repository/bank_account_repository.dart';
import '../../home/controllers/dashboard_controller.dart';
import '../../tags/models/tag_model.dart';
import '../models/bank_transaction_model.dart';
import '../repository/transaction_repository.dart';
import 'all_transaction_controller.dart';
import 'transaction_controller.dart'; // To refresh list
import '../../tags/controllers/tags_controller.dart';

// MODIFIED: Integrated ManualTransactionService for Cash tag dual-effect (Feature A)
class AddEditTransactionController extends GetxController {
  final CashWalletRepository _cashRepo = CashWalletRepository();
  final BankAccountRepository _acctRepo = BankAccountRepository();
  final TransactionRepository _txnRepo = TransactionRepository();
  final ManualTransactionService _manualTxnService = ManualTransactionService();

  // Model passed from arguments (if editing)
  BankTransactionModel? editingTxn;

  // Form State
  final RxString selectedMode = 'Bank'.obs; // 'Bank' or 'Cash'
  final RxString selectedType = 'DR'.obs; // 'DR' or 'CR'
  final Rx<BankAccountModel?> selectedBankAccount = Rx<BankAccountModel?>(null);
  final Rx<TagModel?> selectedTag = Rx<TagModel?>(null);
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();

  final RxList<BankAccountModel> bankAccounts = <BankAccountModel>[].obs;

  final RxBool isLoadingSave = false.obs;
  final RxBool isLoadingBanks = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is BankTransactionModel) {
      editingTxn = args;
    }
    _fetchBankAccounts();
  }

  Future<void> _fetchBankAccounts() async {
    isLoadingBanks.value = true;
    try {
      final acctId = LocalStorageService.instance.accountId;
      final accountsList = await _acctRepo.getAllBankAccounts(
        accountId: acctId,
      );
      bankAccounts.assignAll(accountsList);

      _initFormState();
    } catch (e, stack) {
      log('[_fetchBankAccounts] Error: $e', stackTrace: stack);
    } finally {
      isLoadingBanks.value = false;
    }
  }

  void _initFormState() {
    if (editingTxn != null) {
      selectedMode.value = editingTxn!.encryptedAccountId == 'CASH'
          ? 'Cash'
          : 'Bank';
      selectedType.value = editingTxn!.txnType.toUpperCase();
      amountCtrl.text = editingTxn!.txnAmount.toStringAsFixed(2);
      noteCtrl.text = editingTxn!.txnNarration;
      selectedDate.value =
          DateTime.tryParse(editingTxn!.txnDate) ?? DateTime.now();

      // CRITICAL FIX: Always set tag immediately with fallback, then try to find full tag
      // This ensures the UI shows the tag name on first open
      selectedTag.value = TagModel(
        tagId: editingTxn!.txnTagId,
        tagName: editingTxn!.resolvedTagName,
        tagKeywords: [],
        tagPriority: 0, // Default to Bank Account Level (highest priority)
        tagCreatedAt: DateTime.now().toIso8601String(),
      );

      // Try to find the full tag object from TagsController for complete data
      try {
        final tagsController = Get.find<TagsController>();
        // Wait a frame to ensure TagsController has loaded
        Future.microtask(() {
          final tag = tagsController.tags.firstWhereOrNull(
            (t) => t.tagId == editingTxn!.txnTagId,
          );
          if (tag != null) {
            selectedTag.value = tag;
            log('[AddEditTransaction] Found full tag: ${tag.tagName}');
          } else {
            log(
              '[AddEditTransaction] Tag not found in TagsController, using fallback',
            );
          }
        });
      } catch (e) {
        log('[AddEditTransaction] TagsController not found: $e');
      }

      if (selectedMode.value == 'Bank') {
        selectedBankAccount.value = bankAccounts.firstWhereOrNull(
          (b) => b.encryptedAccountNumber == editingTxn!.encryptedAccountId,
        );
      }
    }
  }

  Future<void> saveTransaction() async {
    final double amount = double.tryParse(amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      SnackbarService.showError(
        title: 'Validation',
        message: 'Please enter a valid amount.',
      );
      return;
    }

    if (selectedMode.value == 'Bank' && selectedBankAccount.value == null) {
      SnackbarService.showError(
        title: 'Validation',
        message: 'Please select a Bank Account.',
      );
      return;
    }

    if (selectedMode.value == 'Bank' && selectedTag.value == null) {
      SnackbarService.showError(
        title: 'Validation',
        message: 'Please select a Tag.',
      );
      return;
    }

    isLoadingSave.value = true;
    try {
      final String note = noteCtrl.text.trim();
      final accountId = LocalStorageService.instance.accountId;
      final now = DateTime.now().toIso8601String();
      final selectedDateStr = selectedDate.value.toIso8601String();

      // --- STRICT BALANCE VALIDATION ---
      if (selectedType.value == 'DR') {
        if (selectedMode.value == 'Bank') {
          final selectedBank = selectedBankAccount.value!;
          double currentBalance = selectedBank.currentBalance;
          double oldAmount = editingTxn != null
              ? editingTxn!.txnAmount.abs()
              : 0.0;
          bool isOldDebit =
              editingTxn != null && editingTxn!.txnType.toUpperCase() == 'DR';

          double tempBalance = BalanceValidator.calculateAdjustedBalance(
            currentBalance: currentBalance,
            oldAmount: oldAmount,
            isOldDebit: isOldDebit,
          );

          if (!await _validateAndShowDialog(tempBalance, amount)) {
            isLoadingSave.value = false;
            return;
          }
        } else {
          // Cash Mode
          final cashBal = await _cashRepo.getCashWallet(accountId);
          double currentBalance = cashBal?.currentBalance ?? 0.0;
          double oldAmount = editingTxn != null
              ? editingTxn!.txnAmount.abs()
              : 0.0;
          bool isOldDebit =
              editingTxn != null && editingTxn!.txnType.toUpperCase() != 'CR';

          double tempBalance = BalanceValidator.calculateAdjustedBalance(
            currentBalance: currentBalance,
            oldAmount: oldAmount,
            isOldDebit: isOldDebit,
          );

          if (!await _validateAndShowDialog(tempBalance, amount)) {
            isLoadingSave.value = false;
            return;
          }
        }
      }
      // --- END VALIDATION ---

      if (selectedMode.value == 'Bank') {
        final selectedBank = selectedBankAccount.value!;

        if (editingTxn != null) {
          // UPDATE - use direct DB update
          final Map<String, dynamic> data = {
            'txn_date': selectedDateStr,
            'txn_account_id': selectedBank.encryptedAccountNumber,
            'txn_tag_id': selectedTag.value!.tagId,
            'txn_amount': amount,
            'txn_type': selectedType.value,
            'txn_narration': note.isEmpty ? 'Manual Entry' : note,
            'txn_ref': 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
            'txn_is_manual': 1,
            'created_at': editingTxn!.txnDate,
            'updated_at': now,
            'txn_id': editingTxn!.txnId,
          };

          final db = DatabaseHelper.instance.database;
          await (await db).update(
            'transactions',
            data,
            where:
                'txn_id = ? AND txn_account_id IN (SELECT bank_account_number FROM bank_accounts WHERE account_id = ? AND deleted_at IS NULL)',
            whereArgs: [editingTxn!.txnId, accountId],
          );

          await _recomputeTouchedBankBalances(
            selectedBank.encryptedAccountNumber,
          );
        } else {
          // INSERT - use ManualTransactionService for Cash tag dual-effect
          final success = await _manualTxnService.createManualTransaction(
            txnDate: selectedDateStr,
            bankAccountNumber: selectedBank.encryptedAccountNumber,
            tagId: selectedTag.value!.tagId!,
            amount: amount,
            narration: note.isEmpty ? 'Manual Entry' : note,
            txnType: selectedType.value,
          );

          if (!success) {
            throw Exception('Failed to create transaction');
          }
        }
      } else {
        // CASH
        // Step 1: Ensure Cash tag exists or use selected Cash tag.
        int tagId = selectedTag.value?.tagId ?? 0;

        final cashTxn = CashWalletTransactionModel(
          cashWalletTransactionId: editingTxn?.txnId,
          accountId: accountId,
          tagId: tagId,
          transactionType: selectedType.value == 'CR' ? 'Income' : 'Expense',
          amount: amount,
          transactionNote: note.isEmpty ? 'Cash Entry' : note,
          dateAdded: selectedDateStr,
          createdAt: editingTxn != null ? editingTxn!.txnDate : now,
          updatedAt: now,
        );

        if (editingTxn != null) {
          final cashBal = await _cashRepo.getCashWallet(accountId);

          if (cashBal != null) {
            double currentBalance = cashBal.currentBalance;

            // OLD signed amount
            double oldAmount = editingTxn!.txnType == 'CR'
                ? editingTxn!.txnAmount
                : -editingTxn!.txnAmount;

            // NEW signed amount
            double newAmount = selectedType.value == 'CR' ? amount : -amount;

            // Remove old effect
            double tempBalance = currentBalance - oldAmount;

            // Apply new effect
            double newBalance = tempBalance + newAmount;

            await _cashRepo.updateCashWalletBalance(accountId, newBalance);
          }

          // Update transaction
          await _cashRepo.updateCashWalletTransaction(
            cashTxn,
            editingTxn!.txnId,
          );
        } else {
          final cashBal = await _cashRepo.getCashWallet(accountId);
          if (cashBal != null) {
            final adjustedBalance = selectedType.value == 'CR'
                ? cashBal.currentBalance + amount
                : cashBal.currentBalance - amount;
            await _cashRepo.updateCashWalletBalance(accountId, adjustedBalance);
          }
          await _cashRepo.insertCashWalletTransaction(cashTxn);
        }
      }

      // Refresh list
      if (Get.isRegistered<TransactionsController>()) {
        Get.find<TransactionsController>().fetchTransactions();
      }
      if (Get.isRegistered<AllTransactionsController>()) {
        Get.find<AllTransactionsController>().fetchAllTransactions();
      }
      if (Get.isRegistered<TagsController>()) {
        Get.find<TagsController>().fetchTags();
      }
      _refreshDashboard();

      Get.back();
      SnackbarService.showSuccess(
        title: 'Success',
        message: editingTxn != null
            ? 'Transaction updated'
            : 'Transaction created',
      );
    } catch (e, stack) {
      log('[AddEditTransaction] save error: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Error',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      isLoadingSave.value = false;
    }
  }

  Future<void> _recomputeTouchedBankBalances(
    String newBankAccountNumber,
  ) async {
    final editing = editingTxn;
    if (editing == null || editing.encryptedAccountId == newBankAccountNumber) {
      await _txnRepo.recomputeAndSave(newBankAccountNumber);
      return;
    }
    await _txnRepo.recomputeAndSave(editing.encryptedAccountId);
    await _txnRepo.recomputeAndSave(newBankAccountNumber);
  }

  void _refreshDashboard() {
    try {
      Get.find<DashboardController>().refreshDashboard();
      Get.find<BankAccountController>().fetchBankAccounts(
        accountId: LocalStorageService.instance.accountId,
      );
    } catch (_) {}
  }

  Future<bool> _validateAndShowDialog(double balance, double amount) async {
    String? errorMessage = BalanceValidator.validateBalance(balance, amount);
    if (errorMessage == 'Insufficient balance') {
      await DialogService.showWarningDialog(
        title: "Insufficient Balance",
        description:
            'You do not have enough balance to complete this transaction.',
        showCancel: false,
        confirmText: "OK",
      );
      return false;
    } else if (errorMessage != null) {
      SnackbarService.showError(title: 'Error', message: errorMessage);
      return false;
    }
    return true;
  }

  @override
  void onClose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }
}
