import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/snackbar_service.dart';
import '../../../routes/app_routes.dart';
import '../models/account_model.dart';
import '../services/password_encryption_decryption_service.dart';
import '../services/session_service.dart';
import 'bear_controller.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../../cash_wallet/controller/cash_wallet_controller.dart';
import '../../home/controllers/dashboard_controller.dart';
import '../../tags/controllers/tags_controller.dart';
import '../../transactions/controller/all_transaction_controller.dart';
import '../../transactions/controller/transaction_controller.dart';
import '../../virtual_entries/controller/virtual_entries_controller.dart';

class MasterAccountController extends GetxController {
  // ── Controllers ──
  final TextEditingController accountNameController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final TextEditingController confirmPinController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // ── Observables ──
  final RxBool isLoading = false.obs;
  final RxBool isPinVisible = false.obs;
  final RxBool isConfirmPinVisible = false.obs;
  final RxBool isAcceptedTerms = false.obs;
  final RxList<AccountModel> accounts = <AccountModel>[].obs;
  final Rxn<AccountModel> selectedAccount = Rxn<AccountModel>();

  // ── Typing Debouncer ──
  Timer? _typingTimer;
  void startTypingTimer(VoidCallback onStopTyping) {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1500), onStopTyping);
  }

  // ── Services ──
  final PasswordEncryptionDecryptionService _encDecService =
      PasswordEncryptionDecryptionService.instance;
  final SessionService _sessionService = SessionService.instance;

  // ── BANK LIST ──
  final RxList<Map<String, dynamic>> bankList = [
    {"name": "State Bank of India", "logo": "logo_sbi_bank.png"},
    {"name": "HDFC Bank", "logo": "logo_hdfc_bank.png"},
    {"name": "ICICI Bank", "logo": "logo_icici_bank.png"},
    {"name": "Axis Bank", "logo": "logo_axis_bank.png"},
    {"name": "Kotak Mahindra Bank", "logo": "logo_kotak_bank.png"},
    {"name": "Yes Bank", "logo": "logo_yes_bank.png"},
    {"name": "Bank of India", "logo": "logo_boi_bank.png"},
    {"name": "IDFC Bank", "logo": "logo_idfc_bank.png"},
    {"name": "IDBI Bank", "logo": "logo_idbi_bank.png"},
    {"name": "Union Bank of India", "logo": "logo_union_bank.png"},
    {"name": "Bank of Baroda", "logo": "logo_bob_bank.png"},
  ].obs;

  RxList<Map<String, dynamic>> filteredBankList = <Map<String, dynamic>>[].obs;
  RxInt selectedBankIndex = (-1).obs;

  @override
  void onInit() {
    super.onInit();
    _encDecService.init(); // init AES key from secure storage
    fetchAccounts();
    filteredBankList.assignAll(bankList);
  }

  Future<void> fetchAccounts() async {
    accounts.value = await DatabaseHelper.instance.getAllAccounts();
  }

  // ─────────────────────────────────────────────
  // CREATE ACCOUNT
  // Hashes PIN with SHA-256 → stores hash in SQLite
  // ─────────────────────────────────────────────
  Future<void> createAccount() async {
    if (!formKey.currentState!.validate()) {
      SnackbarService.showError(
        title: 'Oops!',
        message: "Please enter all the fields",
      );
      return;
    }
    if (!isAcceptedTerms.value) {
      SnackbarService.showError(
        title: 'Oops!',
        message: "Please accept terms and conditions",
      );
      return;
    }

    isLoading.value = true;

    // SHA-256 hash of PIN — stored in DB
    final hashedPin = _encDecService.hashPin(pinController.text.trim());

    final account = AccountModel(
      accountName: accountNameController.text.trim(),
      pin: hashedPin,
      createdAt: DateTime.now().toIso8601String(),
      isDefault: 1,
    );

    final result = await DatabaseHelper.instance.insertAccount(account);
    // -- Bear Controller for handle success and failures
    final bearCtr = Get.find<BearController>();
    if (result != -1) {
      //  CREATE CASH WALLET ASSOCIATED WITH MASTER ACCOUNT
      try {
        bearCtr.fireSuccess(() async {
          await DatabaseHelper.instance.insertCashWallet({
            'account_id': result,
            'current_balance': 0.0,
            'date_added': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          });

          // Create Cash Tag for the new user
          final cashTagId = await DatabaseHelper.instance.ensureCashTagExists(
            result,
          );
          if (cashTagId <= 0) {
            debugPrint(
              "Warning: Failed to create Cash tag for account $result",
            );
          } else {
            debugPrint("Cash tag created successfully with ID: $cashTagId");
          }
        });
      } catch (e) {
        debugPrint("Error creating cash wallet: $e");
      }

      clearControllers();
      SnackbarService.showSuccess(
        title: 'Success!',
        message: "Account created successfully",
      );
      await fetchAccounts();
      Get.offAllNamed(AppRoutes.masterAccountSetupScreen);
    } else {
      bearCtr.fireFail();
      SnackbarService.showError(
        title: 'Oops!',
        message: "Failed to create account",
      );
    }

    isLoading.value = false;
  }

  void togglePinVisibility() {
    isPinVisible.value = !isPinVisible.value;
  }
  // ─────────────────────────────────────────────
  // LOGIN
  // 1. Hash entered PIN
  // 2. Compare with stored hash in SQLite
  // 3. Generate token → save in FlutterSecureStorage
  // 4. Save to LocalStorageService (your existing service)
  // 5. Navigate to home
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // LOGIN METHOD
  // ─────────────────────────────────────────────
  Future<void> login() async {
    // -- Bear Controller for handle success and failures
    final bearCtr = Get.find<BearController>();
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;

    final hashedPin = _encDecService.hashPin(pinController.text.trim());

    final accountId = await DatabaseHelper.instance.checkLogin(
      accountNameController.text.trim(),
      hashedPin,
    );

    if (accountId != -1) {
      // Bear celebrates → navigation fires only after animation ends
      bearCtr.fireSuccess(() async {
        _clearUserScopedState();
        await _sessionService.saveSession(
          accountId: accountId,
          accountName: accountNameController.text.trim(),
        );

        final local = LocalStorageService.instance;
        local.accountName = accountNameController.text.trim();
        local.isLoggedIn = true;
        local.accountId = accountId;
        clearControllers();
        Get.offAllNamed(AppRoutes.homeScreen);
      });
    } else {
      bearCtr.fireFail();
      await Future.delayed(const Duration(milliseconds: 1500));
      SnackbarService.showError(
        title: 'Login failed',
        message: "Incorrect account name or PIN",
      );
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // Clears both SecureStorage token + LocalStorage
  // ─────────────────────────────────────────────
  Future<void> logout() async {
    _clearUserScopedState();
    await _sessionService.logout();
    final local = LocalStorageService.instance;
    local.isLoggedIn = false;
    local.accountName = '';
    local.accountId = -1;
    Get.offAllNamed(AppRoutes.masterAccountSetupScreen);
  }

  void _clearUserScopedState() {
    if (Get.isRegistered<BankAccountController>()) {
      Get.delete<BankAccountController>(force: true);
    }
    if (Get.isRegistered<CashWalletController>()) {
      Get.delete<CashWalletController>(force: true);
    }
    if (Get.isRegistered<TagsController>()) {
      Get.delete<TagsController>(force: true);
    }
    if (Get.isRegistered<DashboardController>()) {
      Get.delete<DashboardController>(force: true);
    }
    if (Get.isRegistered<AllTransactionsController>()) {
      Get.delete<AllTransactionsController>(force: true);
    }
    if (Get.isRegistered<TransactionsController>()) {
      Get.delete<TransactionsController>(force: true);
    }
    if (Get.isRegistered<VirtualEntriesController>()) {
      Get.delete<VirtualEntriesController>(force: true);
    }
  }

  // ─────────────────────────────────────────────
  // CHECK SESSION — call from SplashScreen
  // ─────────────────────────────────────────────
  Future<void> checkSession() async {
    try {
      final loggedIn = await _sessionService.isLoggedIn();
      if (loggedIn) {
        final accountId = await _sessionService.getAccountId();
        if (accountId == null || accountId == -1) {
          // Invalid session data, force logout
          await logout();
          return;
        }

        // Restore LocalStorageService from SecureStorage
        final local = LocalStorageService.instance;
        local.accountId = accountId;
        local.accountName = (await _sessionService.getAccountName()) ?? '';
        local.isLoggedIn = true;
        Get.offAllNamed(AppRoutes.homeScreen);
      } else {
        await fetchAccounts();
        if (accounts.isEmpty) {
          Get.offAllNamed(AppRoutes.masterAccountSetupScreen);
        } else {
          Get.offAllNamed(AppRoutes.chooseAccountScreen);
        }
      }
    } catch (e, stackTrace) {
      debugPrint("Error in checkSession: $e\n$stackTrace");
      // Fallback in case of error
      Get.offAllNamed(AppRoutes.masterAccountSetupScreen);
    }
  }

  // ─────────────────────────────────────────────
  // CLEAR CONTROLLERS
  // ─────────────────────────────────────────────
  void clearControllers() {
    accountNameController.clear();
    pinController.clear();
    confirmPinController.clear();
    isAcceptedTerms.value = false;
  }

  // ─────────────────────────────────────────────
  // BANK METHODS
  // ─────────────────────────────────────────────

  void chooseBank(String bankName) {
    selectedBankIndex.value = bankList.indexWhere(
      (bank) => bank["name"] == bankName,
    );
  }

  void filterBanks(String query) {
    selectedBankIndex.value = -1;
    if (query.isEmpty) {
      filteredBankList.assignAll(bankList);
    } else {
      filteredBankList.value = bankList
          .where(
            (bank) => bank["name"].toString().toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    }
  }
}
