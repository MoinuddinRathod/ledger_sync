import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/snackbar_service.dart';
import '../../../core/service/dialog_service.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../../bank_account/models/bank_account_model.dart';
import '../../bank_account/repository/bank_account_repository.dart';
import '../../../core/utils/balance_validator.dart';
import '../../home/controllers/dashboard_controller.dart';
import '../../tags/models/tag_model.dart';
import '../../transactions/controller/all_transaction_controller.dart';
import '../models/cash_wallet_model.dart';
import '../models/cash_wallet_transaction_model.dart';
import '../repository/cash_wallet_repository.dart';

class CashWalletController extends GetxController {
  final CashWalletRepository _repository = CashWalletRepository();
  final BankAccountRepository _bankRepository = BankAccountRepository();

  RxBool isLoading = false.obs;
  Rx<CashWalletModel?> cashWallet = Rx<CashWalletModel?>(null);
  RxList<CashWalletTransactionModel> transactions =
      <CashWalletTransactionModel>[].obs;
  RxList<BankAccountModel> bankAccounts = <BankAccountModel>[].obs;

  // Search State
  RxBool isSearching = false.obs;
  RxString searchQuery = "".obs;

  // Form Controllers
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  // Dropdown States
  final List<String> transactionTypes = [
    'Cash Withdrawn From Bank',
    'Cash Deposited To Bank',
    'Expense',
    'Income',
  ];
  RxString selectedTransactionType = 'Cash Withdrawn From Bank'.obs;
  Rx<BankAccountModel?> selectedBankAccount = Rx<BankAccountModel?>(null);
  Rx<TagModel?> selectedTag = Rx<TagModel?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      int accountId = LocalStorageService.instance.accountId;
      if (accountId == -1) return;

      cashWallet.value = await _repository.getCashWallet(accountId);

      // If none found, maybe one wasn't created yet? Let's just create one.
      if (cashWallet.value == null) {
        await _repository.createCashWallet(
          CashWalletModel(
            accountId: accountId,
            dateAdded: DateTime.now().toIso8601String(),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        cashWallet.value = await _repository.getCashWallet(accountId);
      }

      transactions.value = await _repository.getCashWalletTransactions(
        accountId,
      );
      bankAccounts.value = await _bankRepository.getAllBankAccounts(
        accountId: accountId,
      );
    } catch (e) {
      debugPrint("Error fetching cash wallet data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void onChangeTransactionType(String? value) {
    if (value != null) {
      selectedTransactionType.value = value;
      selectedBankAccount.value = null; // reset bank selection
    }
  }

  Future<void> saveTransaction() async {
    if (!formKey.currentState!.validate()) return;

    // Validate bank selection if required
    if ((selectedTransactionType.value == 'Cash Withdrawn From Bank' ||
            selectedTransactionType.value == 'Cash Deposited To Bank') &&
        selectedBankAccount.value == null) {
      SnackbarService.showError(
        title: 'Error',
        message: 'Please select a bank account',
      );
      return;
    }

    if (selectedTag.value == null) {
      SnackbarService.showError(title: 'Error', message: 'Please select a tag');
      return;
    }

    final int accountId = LocalStorageService.instance.accountId;
    if (accountId == -1) return;

    double amount = double.tryParse(amountController.text.trim()) ?? 0.0;

    double currentBalance = cashWallet.value?.currentBalance ?? 0.0;
    double bankBalance = selectedBankAccount.value?.currentBalance ?? 0.0;

    // Strict Balance Validation
    if (selectedTransactionType.value == 'Cash Withdrawn From Bank') {
      // Withdrawing from bank -> reduces bank balance
      if (!await _validateAndShowDialog(bankBalance, amount)) return;
    } else if (selectedTransactionType.value == 'Cash Deposited To Bank' ||
        selectedTransactionType.value == 'Expense') {
      // Deducting from Cash -> reduces cash balance
      if (!await _validateAndShowDialog(currentBalance, amount)) return;
    } else if (amount <= 0) {
      SnackbarService.showError(title: 'Error', message: 'Enter valid amount');
      return;
    }

    bool isAddition =
        (selectedTransactionType.value == 'Income' ||
        selectedTransactionType.value == 'Cash Withdrawn From Bank');
    double newBalance = isAddition
        ? (currentBalance + amount)
        : (currentBalance - amount);

    isLoading.value = true;
    try {
      String baseNote = noteController.text.trim();
      String fullNote = baseNote;

      if (selectedTransactionType.value == 'Cash Withdrawn From Bank') {
        fullNote = 'From ${selectedBankAccount.value?.bankName} - $baseNote';
      } else if (selectedTransactionType.value == 'Cash Deposited To Bank') {
        fullNote = 'To ${selectedBankAccount.value?.bankName} - $baseNote';
      }

      final selectedDateStr = selectedDate.value.toIso8601String();

      CashWalletTransactionModel newTx = CashWalletTransactionModel(
        accountId: accountId,
        tagId: selectedTag.value!.tagId!,
        transactionType: selectedTransactionType.value,
        amount: amount, // Storing as positive or negative helps UI later
        transactionNote: fullNote,
        dateAdded: selectedDateStr,
        createdAt: selectedDateStr,
        isManual: true,
        // Store encrypted bank account number for bank-related types only
        bankAccountId:
            (selectedTransactionType.value == 'Cash Withdrawn From Bank' ||
                selectedTransactionType.value == 'Cash Deposited To Bank')
            ? selectedBankAccount.value?.encryptedAccountNumber
            : null,
      );

      // Save Tx
      await _repository.insertCashWalletTransaction(newTx);

      // Update Balance
      await _repository.updateCashWalletBalance(accountId, newBalance);

      if (selectedTransactionType.value == 'Cash Withdrawn From Bank') {
        await _updateBankBalance(amount, true); // bank goes DOWN
      } else if (selectedTransactionType.value == 'Cash Deposited To Bank') {
        await _updateBankBalance(amount, false); // bank goes UP
      }

      // Fetch new data
      await fetchData();
      // Refresh dashboard metrics
      _refreshDashboard();
      _refreshAllTransactions();

      Get.back(); // close bottom sheet
      SnackbarService.showSuccess(
        title: 'Success',
        message: 'Transaction saved successfully',
      );

      // Reset form
      resetForm();
    } catch (e) {
      debugPrint(e.toString());
      SnackbarService.showError(
        title: 'Error',
        message: 'Failed to save transaction',
      );
    } finally {
      isLoading.value = false;
    }
  }

  // -------- update transaction --------
  Future<void> updateTransaction(CashWalletTransactionModel oldTx) async {
    if (!formKey.currentState!.validate()) return;

    if ((selectedTransactionType.value == 'Cash Withdrawn From Bank' ||
            selectedTransactionType.value == 'Cash Deposited To Bank') &&
        selectedBankAccount.value == null) {
      SnackbarService.showError(
        title: 'Error',
        message: 'Please select a bank account',
      );
      return;
    }

    if (selectedTag.value == null) {
      SnackbarService.showError(title: 'Error', message: 'Please select a tag');
      return;
    }

    final int accountId = LocalStorageService.instance.accountId;
    if (accountId == -1) return;

    double amount = double.tryParse(amountController.text.trim()) ?? 0.0;

    double currentBalance = cashWallet.value?.currentBalance ?? 0.0;
    final oldType = oldTx.transactionType;
    final newType = selectedTransactionType.value;

    // Determine signed amounts
    bool isNewAddition =
        (newType == 'Income' || newType == 'Cash Withdrawn From Bank');
    double newSignedAmount = isNewAddition ? amount : -amount;

    // 1. Validate Cash Balance
    bool isOldCashDebit =
        (oldType == 'Cash Deposited To Bank' || oldType == 'Expense');
    double tempCashBalance = BalanceValidator.calculateAdjustedBalance(
      currentBalance: currentBalance,
      oldAmount: oldTx.amount.abs(),
      isOldDebit: isOldCashDebit,
    );

    if (newType == 'Cash Deposited To Bank' || newType == 'Expense') {
      if (!await _validateAndShowDialog(tempCashBalance, amount)) return;
    } else if (amount <= 0) {
      SnackbarService.showError(title: 'Error', message: 'Enter valid amount');
      return;
    }

    // 2. Validate Bank Balance if applicable
    if (selectedBankAccount.value != null) {
      double currentBankBalance = selectedBankAccount.value!.currentBalance;
      bool isOldBankDebit = (oldType == 'Cash Withdrawn From Bank');
      double oldBankAmount =
          (oldType == 'Cash Withdrawn From Bank' ||
              oldType == 'Cash Deposited To Bank')
          ? oldTx.amount.abs()
          : 0.0;

      double tempBankBalance = BalanceValidator.calculateAdjustedBalance(
        currentBalance: currentBankBalance,
        oldAmount: oldBankAmount,
        isOldDebit: isOldBankDebit,
      );

      if (newType == 'Cash Withdrawn From Bank') {
        if (!await _validateAndShowDialog(tempBankBalance, amount)) return;
      }
    }

    //  Final Cash Balance
    double newBalance = tempCashBalance + newSignedAmount;

    isLoading.value = true;

    try {
      String baseNote = noteController.text.trim();
      String fullNote = baseNote;

      if (selectedTransactionType.value == 'Cash Withdrawn From Bank') {
        fullNote = 'From ${selectedBankAccount.value?.bankName} - $baseNote';
      } else if (selectedTransactionType.value == 'Cash Deposited To Bank') {
        fullNote = 'To ${selectedBankAccount.value?.bankName} - $baseNote';
      }

      final selectedDateStr = selectedDate.value.toIso8601String();

      CashWalletTransactionModel updatedTx = CashWalletTransactionModel(
        cashWalletTransactionId: oldTx.cashWalletTransactionId,
        accountId: accountId,
        tagId: selectedTag.value!.tagId!,
        transactionType: selectedTransactionType.value,
        amount: newSignedAmount,
        transactionNote: fullNote,
        dateAdded: selectedDateStr,
        createdAt: oldTx.createdAt,
        isManual: true,
        bankAccountId:
            (selectedTransactionType.value == 'Cash Withdrawn From Bank' ||
                selectedTransactionType.value == 'Cash Deposited To Bank')
            ? selectedBankAccount.value?.encryptedAccountNumber
            : null,
      );
      final result = await _repository.updateCashWalletTransaction(
        updatedTx,
        updatedTx.cashWalletTransactionId!,
      );

      if (result == 0) {
        SnackbarService.showError(
          title: 'Error',
          message: 'Failed to update transaction',
        );
        return;
      }

      final isValidBal = await _validateAndShowDialog(newBalance, amount);
      if (isValidBal) {
        //  UPDATE BALANCE
        await _repository.updateCashWalletBalance(accountId, newBalance);

        //  ADD THIS: reverse old bank effect, apply new bank effect
        final oldType = oldTx.transactionType;
        final newType = selectedTransactionType.value;
        final bank = selectedBankAccount.value;

        if (bank != null) {
          double bankBalance = bank.currentBalance;

          // Reverse old transaction's bank impact
          if (oldType == 'Cash Withdrawn From Bank') {
            bankBalance += oldTx.amount
                .abs(); // undo withdrawal → bank goes back UP
          } else if (oldType == 'Cash Deposited To Bank') {
            bankBalance -= oldTx.amount
                .abs(); // undo deposit → bank goes back DOWN
          }

          // Apply new transaction's bank impact
          if (newType == 'Cash Withdrawn From Bank') {
            bankBalance -= amount; // new withdrawal → bank goes DOWN
          } else if (newType == 'Cash Deposited To Bank') {
            bankBalance += amount; // new deposit → bank goes UP
          }

          final updatedBank = bank.copyWith(currentBalance: bankBalance);
          await _bankRepository.updateBankAccount(
            updatedBank,
            bank.encryptedAccountNumber,
          );
        }

        await fetchData();
        _refreshDashboard();
        _refreshAllTransactions();
        resetForm();
        Get.back();
        SnackbarService.showSuccess(
          title: 'Success',
          message: 'Transaction updated successfully',
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      SnackbarService.showError(
        title: 'Error',
        message: 'Failed to update transaction',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteTransaction(CashWalletTransactionModel tx) async {
    isLoading.value = true;
    try {
      final int accountId = LocalStorageService.instance.accountId;
      if (accountId == -1) return;

      double currentBalance = cashWallet.value?.currentBalance ?? 0.0;

      // Reverse the original balance impact based on transaction type
      // Income/Withdrawn: originally added to balance → delete subtracts
      // Expense/Deposited: originally subtracted from balance → delete adds
      bool wasAdditionType =
          (tx.transactionType == 'Income' ||
          tx.transactionType == 'Cash Withdrawn From Bank');
      double newBalance = wasAdditionType
          ? (currentBalance - tx.amount)
          : (currentBalance + tx.amount);

      await _repository.deleteCashWalletTransaction(
        tx.cashWalletTransactionId!,
      );
      await _repository.updateCashWalletBalance(accountId, newBalance);

      if ((tx.transactionType == 'Cash Withdrawn From Bank' ||
              tx.transactionType == 'Cash Deposited To Bank') &&
          tx.bankAccountId == null) {
        debugPrint(
          '[CashWalletController] deleteTransaction: bankAccountId is null for ${tx.transactionType}. Bank balance not reversed.',
        );
      }

      if (tx.transactionType == 'Cash Withdrawn From Bank' &&
          tx.bankAccountId != null) {
        // Cash was withdrawn from bank — reverse: give money back to bank
        final bank = bankAccounts.firstWhereOrNull(
          (b) => b.encryptedAccountNumber == tx.bankAccountId,
        );
        if (bank != null) {
          final updatedBank = bank.copyWith(
            currentBalance: bank.currentBalance + tx.amount.abs(),
          );
          await _bankRepository.updateBankAccount(
            updatedBank,
            bank.encryptedAccountNumber,
          );
        } else {
          debugPrint(
            '[CashWalletController] deleteTransaction: bank not found '
            'for bankAccountId=${tx.bankAccountId}',
          );
        }
      } else if (tx.transactionType == 'Cash Deposited To Bank' &&
          tx.bankAccountId != null) {
        // Cash was deposited to bank — reverse: take money back from bank
        final bank = bankAccounts.firstWhereOrNull(
          (b) => b.encryptedAccountNumber == tx.bankAccountId,
        );
        if (bank != null) {
          final updatedBank = bank.copyWith(
            currentBalance: bank.currentBalance - tx.amount.abs(),
          );
          await _bankRepository.updateBankAccount(
            updatedBank,
            bank.encryptedAccountNumber,
          );
        } else {
          debugPrint(
            '[CashWalletController] deleteTransaction: bank not found '
            'for bankAccountId=${tx.bankAccountId}',
          );
        }
      }
      await fetchData();
      _refreshDashboard();
      _refreshAllTransactions();
      Get.back(result: true);
      SnackbarService.showSuccess(
        title: 'Deleted',
        message: 'Transaction removed successfully',
      );
    } catch (e) {
      debugPrint(e.toString());
      SnackbarService.showError(
        title: 'Error',
        message: 'Failed to delete transaction',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Soft-trigger dashboard refresh without blocking the current flow.
  void _refreshDashboard() {
    try {
      Get.find<DashboardController>().refreshDashboard();
    } catch (_) {} // DashboardController may not be mounted in certain flows
  }

  void _refreshAllTransactions() {
    try {
      Get.find<AllTransactionsController>().fetchAllTransactions();
    } catch (_) {}
  }

  /// Updates the selected bank account's balance when cash moves to/from bank.
  /// [isDeductingFromBank] = true  → Cash Withdrawn (bank goes DOWN)
  /// [isDeductingFromBank] = false → Cash Deposited  (bank goes UP)
  Future<void> _updateBankBalance(
    double amount,
    bool isDeductingFromBank,
  ) async {
    final bank = selectedBankAccount.value;
    if (bank == null) return;

    final double newBankBalance = isDeductingFromBank
        ? bank.currentBalance - amount
        : bank.currentBalance + amount;

    final updatedBank = bank.copyWith(currentBalance: newBankBalance);
    await _bankRepository.updateBankAccount(
      updatedBank,
      bank.encryptedAccountNumber, // pass the existing encrypted number as the "old" key
    );
    Get.find<BankAccountController>().fetchBankAccounts(
      accountId: LocalStorageService.instance.accountId,
    );
  }

  Future<bool> _validateAndShowDialog(double balance, double amount) async {
    String? errorMessage = BalanceValidator.validateBalance(balance, amount);
    if (errorMessage == 'Insufficient balance') {
      Get.back();
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

  resetForm() {
    amountController.clear();
    noteController.clear();
    selectedTransactionType.value = 'Cash Withdrawn From Bank';
    selectedBankAccount.value = null;
    selectedTag.value = null;
    selectedDate.value = DateTime.now();
  }
}
