import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/snackbar_service.dart';
import '../bank_account_encryption_service.dart';
import '../models/bank_account_model.dart';
import '../repository/bank_account_repository.dart';

class BankAccountController extends GetxController {
  // ------------------------------------------------------------------ //
  // Dependencies
  // ------------------------------------------------------------------ //
  final BankAccountRepository _repo = BankAccountRepository();
  final BankAccountEncryptionService _encService =
      BankAccountEncryptionService();

  // visibility state — keyed by encryptedAccountNumber
  final RxMap<String, bool> accountVisibility = <String, bool>{}.obs;
  // revealed plain text — keyed by encryptedAccountNumber, populated only on demand
  final RxMap<String, String> revealedNumbers = <String, String>{}.obs;
  final RxSet<String> isRevealing = <String>{}.obs; // loading state per card

  // ------------------------------------------------------------------ //
  // Observable State
  // ------------------------------------------------------------------ //

  /// Full list of bank accounts for the active account
  final RxList<BankAccountModel> bankAccounts = <BankAccountModel>[].obs;

  // --- Form Controllers ---
  final formKey = GlobalKey<FormState>();
  final bankNameCtrl = TextEditingController();
  final holderNameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController();
  final bankAccountNumberCtrl = TextEditingController();

  final selectedAccountType = 'Savings'.obs;
  final accountTypes = ['Savings', 'Current'];

  // Keep track of the account being edited (null if adding new)
  BankAccountModel? editingAccount;

  /// Per-operation loading flags — bind each to its own UI indicator
  final RxBool isLoadingFetch = false.obs;
  final RxBool isLoadingAdd = false.obs;
  final RxBool isLoadingUpdate = false.obs;
  final RxBool isLoadingDelete = false.obs;

  /// True whenever ANY operation is in progress
  bool get isBusy =>
      isLoadingFetch.value ||
      isLoadingAdd.value ||
      isLoadingUpdate.value ||
      isLoadingDelete.value;

  // ------------------------------------------------------------------ //
  // Lifecycle
  // ------------------------------------------------------------------ //

  @override
  void onInit() {
    super.onInit();
    fetchBankAccounts(accountId: LocalStorageService.instance.accountId);
    _initEncryption();
  }

  Future<void> _initEncryption() async {
    await _encService.init();
    fetchBankAccounts(accountId: LocalStorageService.instance.accountId);
  }

  // ------------------------------------------------------------------ //
  // FETCH
  // ------------------------------------------------------------------ //

  Future<void> fetchBankAccounts({required int accountId}) async {
    if (accountId <= 0) {
      SnackbarService.showWarning(
        title: 'Invalid Account',
        message: 'Account ID is invalid. Cannot load bank accounts.',
      );
      return;
    }

    if (isLoadingFetch.value) return; // prevent concurrent fetches

    try {
      isLoadingFetch.value = true;

      final List<BankAccountModel> result = await _repo.getAllBankAccounts(
        accountId: accountId,
      );

      bankAccounts.assignAll(result);

      if (result.isEmpty) {
        log(
          '[BankAccountController] fetchBankAccounts: empty list for accountId=$accountId',
        );
      }
    } catch (e, stack) {
      log('[BankAccountController] fetchBankAccounts: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Load Failed',
        message: 'Could not load bank accounts. Please try again.',
      );
    } finally {
      isLoadingFetch.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // UTILITY METHODS FOR PARSER
  // ------------------------------------------------------------------ //

  Future<BankAccountModel?> findAccountByNumber(String plainNumber) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return null;

    // Ensure encryption is initialized

    await _initEncryption();

    // Fetch directly to ensure latest or use cached list
    final List<BankAccountModel> allAccounts = await _repo.getAllBankAccounts(
      accountId: accountId,
    );

    for (var acc in allAccounts) {
      try {
        final decrypted = _encService.decryptAccountNumber(
          acc.encryptedAccountNumber,
        );
        // Only compare the last digits if the parsed one is masked, or full if both full
        // The parser usually returns full. Let's compare exactly or suffix
        if (decrypted == plainNumber || decrypted.endsWith(plainNumber)) {
          return acc;
        }
      } catch (_) {
        // ignore decryption err for individual account
      }
    }
    return null;
  }

  Future<BankAccountModel?> createAccount({
    required String bankName,
    required String plainNumber,
    required String holderName,
    required String accountType,
    required double balance,
  }) async {
    final now = DateTime.now().toIso8601String();
    final lastFour = plainNumber.length >= 4
        ? plainNumber.substring(plainNumber.length - 4)
        : plainNumber;

    await _initEncryption();

    final encrypted = _encService.encryptAccountNumber(plainNumber);

    final model = BankAccountModel(
      encryptedAccountNumber: encrypted,
      lastFourDigits: lastFour,
      accountId: LocalStorageService.instance.accountId,
      bankName: bankName.trim(),
      accountHolderName: holderName.trim(),
      accountType: accountType,
      currentBalance: balance,
      dateAdded: now,
      createdAt: now,
      updatedAt: now,
    );

    final String? error = _validateModel(model);
    if (error != null) {
      SnackbarService.showWarning(title: 'Validation Error', message: error);
      return null;
    }

    try {
      isLoadingAdd.value = true;
      final int insertedId = await _repo.addBankAccount(model);
      if (insertedId == -1) {
        SnackbarService.showError(
          title: 'Add Failed',
          message: 'Could not save. Please try again.',
        );
        return null;
      }
      bankAccounts.add(model);
      return model;
    } catch (e, stack) {
      log('[BankAccountController] createAccount: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Add Failed',
        message: 'Unexpected error. Please try again.',
      );
      return null;
    } finally {
      isLoadingAdd.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // ADD — extract last 4, encrypt full number (UI bound)
  // ------------------------------------------------------------------ //
  Future<void> addBankAccount() async {
    if (!formKey.currentState!.validate()) return;
    if (isLoadingAdd.value) return;

    final plainNumber = bankAccountNumberCtrl.text.trim();
    final bankName = bankNameCtrl.text.trim();
    final holderName = holderNameCtrl.text.trim();
    final balance = double.tryParse(balanceCtrl.text) ?? 0.0;
    final accountType = selectedAccountType.value;

    final model = await createAccount(
      bankName: bankName,
      plainNumber: plainNumber,
      holderName: holderName,
      accountType: accountType,
      balance: balance,
    );

    if (model != null) {
      Get.back();
      SnackbarService.showSuccess(
        title: 'Account Added',
        message: '{bankName} account added.'.replaceAll('{bankName}', model.bankName),
      );
      clearForm();
      _closeSheet();
    }
  }

  // ------------------------------------------------------------------ //
  // UPDATE — re-encrypt if account number changed
  // ------------------------------------------------------------------ //
  Future<void> updateBankAccount() async {
    if (!formKey.currentState!.validate()) return;
    if (isLoadingUpdate.value) return;

    final now = DateTime.now().toIso8601String();
    final plainNumber = bankAccountNumberCtrl.text.trim();
    final lastFour = plainNumber.substring(plainNumber.length - 4);
    String encryptedAcNum = editingAccount!.encryptedAccountNumber;
    final encrypted = _encService.encryptAccountNumber(plainNumber);

    final newPlain = _encService.decryptAccountNumber(
      editingAccount!.encryptedAccountNumber,
    );
    if (newPlain != plainNumber) {
      encryptedAcNum = encrypted;
    }

    final model = BankAccountModel(
      encryptedAccountNumber: encryptedAcNum,
      lastFourDigits: lastFour,
      accountId: LocalStorageService.instance.accountId,
      bankName: bankNameCtrl.text.trim(),
      accountHolderName: holderNameCtrl.text.trim(),
      accountType: selectedAccountType.value,
      currentBalance: double.tryParse(balanceCtrl.text) ?? 0.0,
      dateAdded: editingAccount?.dateAdded ?? now,
      createdAt: editingAccount?.createdAt ?? now,
      updatedAt: now,
    );

    final String? error = _validateModel(model);
    if (error != null) {
      SnackbarService.showWarning(title: 'Validation Error', message: error);
      return;
    }

    try {
      isLoadingUpdate.value = true;
      final int rowsAffected = await _repo.updateBankAccount(
        model,
        editingAccount!.encryptedAccountNumber,
      );
      if (rowsAffected == 0) {
        SnackbarService.showWarning(
          title: 'Not Found',
          message: 'Account not found to update.',
        );
        return;
      }
      final int idx = bankAccounts.indexWhere(
        (e) =>
            e.encryptedAccountNumber == editingAccount?.encryptedAccountNumber,
      );
      if (idx != -1) bankAccounts[idx] = model;
      // clear cached reveal for old encrypted key
      revealedNumbers.remove(editingAccount?.encryptedAccountNumber);
      accountVisibility.remove(editingAccount?.encryptedAccountNumber);

      Get.back();
      SnackbarService.showSuccess(
        title: 'Account Updated',
        message: '{bankName} updated.'.replaceAll('{bankName}', model.bankName),
      );
      clearForm();
      _closeSheet();
    } catch (e, stack) {
      log('[BankAccountController] updateBankAccount: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Update Failed',
        message: 'Unexpected error.',
      );
    } finally {
      isLoadingUpdate.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // DELETE — also clear cached reveal
  // ------------------------------------------------------------------ //
  Future<void> deleteBankAccount({
    required String encryptedAccountNumber,
  }) async {
    if (encryptedAccountNumber.isEmpty) return;
    if (isLoadingDelete.value) return;

    try {
      isLoadingDelete.value = true;
      final int rowsAffected = await _repo.deleteBankAccount(
        encryptedAccountNumber,
      );
      if (rowsAffected == 0) {
        SnackbarService.showWarning(
          title: 'Not Found',
          message: 'Account not found to delete.',
        );
        return;
      }
      bankAccounts.removeWhere(
        (e) => e.encryptedAccountNumber == encryptedAccountNumber,
      );
      revealedNumbers.remove(encryptedAccountNumber);
      accountVisibility.remove(encryptedAccountNumber);
      Get.back();
      SnackbarService.showSuccess(
        title: 'Account Deleted',
        message: 'Account deleted successfully.',
      );
    } catch (e, stack) {
      log('[BankAccountController] deleteBankAccount: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Delete Failed',
        message: 'Unexpected error.',
      );
    } finally {
      isLoadingDelete.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // initForm — for edit, we need to decrypt first to pre-fill the field
  // ------------------------------------------------------------------ //
  void initForm(BankAccountModel? account) async {
    editingAccount = account;
    if (account != null) {
      bankNameCtrl.text = account.bankName;
      holderNameCtrl.text = account.accountHolderName;
      balanceCtrl.text = account.currentBalance.toString();
      selectedAccountType.value = account.accountType;
      // Decrypt only for the edit form
      try {
        final plain = _encService.decryptAccountNumber(
          account.encryptedAccountNumber,
        );
        bankAccountNumberCtrl.text = plain;
      } catch (_) {
        bankAccountNumberCtrl.text = '';
        SnackbarService.showWarning(
          title: 'Decrypt Error',
          message: 'Could not load account number.',
        );
      }
    } else {
      clearForm();
    }
  }

  // ------------------------------------------------------------------ //
  // Eye toggle — decrypt on first reveal, cache in RAM
  // ------------------------------------------------------------------ //
  Future<void> toggleVisibility(String encryptedAccountNumber) async {
    final isCurrentlyVisible =
        accountVisibility[encryptedAccountNumber] ?? false;

    if (isCurrentlyVisible) {
      // just hide — no decrypt needed
      accountVisibility[encryptedAccountNumber] = false;
      return;
    }

    // Reveal — decrypt only if not already cached
    if (!revealedNumbers.containsKey(encryptedAccountNumber)) {
      isRevealing.add(encryptedAccountNumber);
      try {
        final plain = _encService.decryptAccountNumber(encryptedAccountNumber);
        revealedNumbers[encryptedAccountNumber] = plain;
      } catch (_) {
        SnackbarService.showError(
          title: 'Error',
          message: 'Could not reveal account number.',
        );
        return;
      } finally {
        isRevealing.remove(encryptedAccountNumber);
      }
    }

    accountVisibility[encryptedAccountNumber] = true;
  }

  // Masked display — uses lastFourDigits, no decrypt
  String maskedDisplay(String lastFourDigits) => '************$lastFourDigits';

  // ------------------------------------------------------------------ //
  // _validateModel — updated for new model shape
  // ------------------------------------------------------------------ //
  String? _validateModel(BankAccountModel model) {
    if (model.bankName.trim().isEmpty) return 'Bank name cannot be empty.';
    if (model.encryptedAccountNumber.trim().isEmpty)
      return 'Account number cannot be empty.';
    if (model.lastFourDigits.length != 4) return 'Invalid account number.';
    if (model.accountHolderName.trim().isEmpty)
      return 'Account holder name cannot be empty.';
    if (model.accountType.trim().isEmpty)
      return 'Account type cannot be empty.';
    if (model.currentBalance < 0) return 'Balance cannot be negative.';
    if (model.accountId <= 0) return 'Linked account reference is invalid.';
    return null;
  }

  void _closeSheet() {
    if (Get.isBottomSheetOpen == true || Get.isDialogOpen == true) Get.back();
  }

  void clearForm() {
    bankNameCtrl.clear();
    holderNameCtrl.clear();
    balanceCtrl.clear();
    bankAccountNumberCtrl.clear();
    selectedAccountType.value = 'Savings';
    editingAccount = null;
  }
}
