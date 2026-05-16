import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/snackbar_service.dart';
import '../../bank_account/models/bank_account_model.dart';
import '../../bank_account/models/reconciliation_row_model.dart';
import '../../bank_account/repository/bank_account_repository.dart';
import '../../cash_wallet/repository/cash_wallet_repository.dart';
import '../models/bank_transaction_model.dart';
import '../repository/transaction_repository.dart';

class TransactionsController extends GetxController {
  // ── Dependencies ────────────────────────────────────
  final TransactionRepository _repo = TransactionRepository();
  final CashWalletRepository _cashRepo = CashWalletRepository();
  final BankAccountRepository _bankRepo = BankAccountRepository();
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ── Encrypted account number (set before navigation) ──
  /// The encrypted bank_account_number FK that scopes this screen.
  /// Null means "show all accounts" (future use — currently per-account).
  String? encryptedAccountNumber;

  /// The resolved bank account model — populated on first fetch.
  BankAccountModel? _bankAccount;

  // ── State ──────────────────────────────────────────
  final RxList<BankTransactionModel> _allTransactions =
      <BankTransactionModel>[].obs;
  final RxList<BankTransactionModel> transactions =
      <BankTransactionModel>[].obs;

  final RxBool isLoadingFetch = false.obs;

  // ── Reconciliation ─────────────────────────────────
  /// Non-null when a balance gap is detected for this account.
  final Rxn<ReconciliationRowModel> reconciliationRow =
      Rxn<ReconciliationRowModel>();

  // ── Search ─────────────────────────────────────────
  final RxBool isSearching = false.obs;
  final RxString searchQuery = ''.obs;

  // ── Filter ─────────────────────────────────────────
  final List<String> filters = ['All', 'Credit', 'Debit'];
  final RxString selectedFilter = 'All'.obs;

  // ── Sort ───────────────────────────────────────────
  final List<String> sortOptions = ['Date', 'Amount'];
  final RxString selectedSort = 'Date'.obs;

  // ── Date range ─────────────────────────────────────
  final RxString selectedDateRange = ''.obs;
  DateTimeRange? _activeDateRange;

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    // Receive encryptedAccountNumber via Get.arguments
    final args = Get.arguments;
    if (args is Map && args.containsKey('encryptedAccountNumber')) {
      encryptedAccountNumber = args['encryptedAccountNumber'] as String?;
    } else if (args is String && args.isNotEmpty) {
      encryptedAccountNumber = args;
    }
    fetchTransactions();
  }

  // ─────────────────────────────────────────────
  // Fetch
  // ─────────────────────────────────────────────

  Future<void> fetchTransactions() async {
    if (isLoadingFetch.value) return; // guard concurrent calls

    try {
      isLoadingFetch.value = true;

      final acct = encryptedAccountNumber;
      if (acct == null || acct.trim().isEmpty) {
        log(
          '[TransactionsController] fetchTransactions: no account number provided',
        );
        isLoadingFetch.value = false;
        return;
      }

      final data = await _repo.getByAccount(acct);
      _allTransactions.assignAll(data);
      _applyFilters();

      // Resolve bank account model once (cache it for subsequent refreshes)
      _bankAccount ??= await _resolveBankAccount(acct);

      // Compute reconciliation gap after transactions are loaded
      await computeReconciliation();

      log('[TransactionsController] fetched ${data.length} transactions');
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(
        '[TransactionsController] fetchTransactions error: $e',
        stackTrace: stackTrace,
      );
      SnackbarService.showError(
        title: 'Load Failed',
        message: 'Could not load transactions. Please try again.',
      );
    } finally {
      isLoadingFetch.value = false;
    }
  }

  // ─────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────

  Future<void> deleteTransaction({required BankTransactionModel txn}) async {
    try {
      int rows = 0;
      if (txn.encryptedAccountId == 'CASH') {
        rows = await _cashRepo.deleteCashWalletTransaction(txn.txnId);
      } else {
        rows = await _repo.softDelete(txn.txnId);
        if (rows > 0) {
          await _repo.recomputeAndSave(txn.encryptedAccountId);
        }
      }

      if (rows <= 0) {
        SnackbarService.showWarning(
          title: 'Not Found',
          message: 'Transaction could not be deleted.',
        );
        return;
      }
      SnackbarService.showSuccess(
        title: 'Deleted',
        message: 'Transaction removed.',
      );
      await fetchTransactions();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(
        '[TransactionsController] deleteTransaction error: $e',
        stackTrace: stackTrace,
      );
      SnackbarService.showError(
        title: 'Delete Failed',
        message: 'Could not delete transaction.',
      );
    }
  }

  // ─────────────────────────────────────────────
  // Search
  // ─────────────────────────────────────────────

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) clearSearch();
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  void clearSearch() {
    searchQuery.value = '';
    _applyFilters();
  }

  // ─────────────────────────────────────────────
  // Filter
  // ─────────────────────────────────────────────

  void setFilter(String filter) {
    selectedFilter.value = filter;
    _applyFilters();
  }

  // ─────────────────────────────────────────────
  // Sort
  // ─────────────────────────────────────────────

  void setSort(String sort) {
    selectedSort.value = sort;
    _applyFilters();
  }

  // ─────────────────────────────────────────────
  // Date range
  // ─────────────────────────────────────────────

  Future<void> pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _activeDateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme),
        child: child!,
      ),
    );
    if (picked != null) {
      _activeDateRange = picked;
      final fmt = DateFormat('MMM dd');
      selectedDateRange.value =
          '${fmt.format(picked.start)} – ${fmt.format(picked.end)}';
      _applyFilters();
    }
  }

  void clearDateRange() {
    _activeDateRange = null;
    selectedDateRange.value = '';
    _applyFilters();
  }

  // ─────────────────────────────────────────────
  // Pipeline — filter + sort + search
  // ─────────────────────────────────────────────

  void _applyFilters() {
    List<BankTransactionModel> result = List.from(_allTransactions);

    // 1. Filter by type
    switch (selectedFilter.value) {
      case 'Credit':
        result = result.where((t) => t.isCredit).toList();
        break;
      case 'Debit':
        result = result.where((t) => t.isDebit).toList();
        break;
      default: // 'All'
        break;
    }

    // 2. Filter by date range
    if (_activeDateRange != null) {
      result = result.where((t) {
        final d = _parseTxnDate(t.txnDate);
        if (d == null) return false;
        return !d.isBefore(_activeDateRange!.start) &&
            !d.isAfter(_activeDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // 3. Search (narration or tag name)
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      result = result.where((t) {
        return t.txnNarration.toLowerCase().contains(q) ||
            t.resolvedTagName.toLowerCase().contains(q) ||
            (t.bankName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // 4. Sort
    switch (selectedSort.value) {
      case 'Amount':
        result.sort((a, b) => b.txnAmount.compareTo(a.txnAmount));
        break;
      case 'Date':
      default:
        result.sort((a, b) {
          final da = _parseTxnDate(a.txnDate);
          final db = _parseTxnDate(b.txnDate);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da); // newest first
        });
        break;
    }
    transactions.assignAll(result);
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Safely parse multiple date formats stored in DB.
  DateTime? _parseTxnDate(String raw) {
    if (raw.isEmpty) return null;
    // Formats seen: 'YYYY-MM-DD', 'DD/MM/YYYY', ISO8601 full
    try {
      // Try ISO first (most common)
      return DateTime.parse(raw);
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
    try {
      return DateFormat('dd/MM/yyyy').parse(raw);
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
    try {
      return DateFormat('MM/dd/yyyy').parse(raw);
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
    return null;
  }

  /// Expose a formatted date string for the tile.
  String formatDisplayDate(String raw) {
    final d = _parseTxnDate(raw);
    if (d == null) return raw;
    return DateFormat('dd MMM yyyy').format(d);
  }

  // ─────────────────────────────────────────────
  // Summary stats (for future use / header card)
  // ─────────────────────────────────────────────

  double get totalCredit => _allTransactions
      .where((t) => t.isCredit)
      .fold(0.0, (s, t) => s + t.txnAmount);

  double get totalDebit => _allTransactions
      .where((t) => t.isDebit)
      .fold(0.0, (s, t) => s + t.txnAmount);

  int get accountId => LocalStorageService.instance.accountId;

  // ─────────────────────────────────────────────
  // Reconciliation
  // ─────────────────────────────────────────────

  /// Resolves the BankAccountModel for [encryptedAccountNumber].
  /// Returns null if not found or on error.
  Future<BankAccountModel?> _resolveBankAccount(String encAcct) async {
    try {
      final id = LocalStorageService.instance.accountId;
      if (id <= 0) return null;
      final accounts = await _bankRepo.getAllBankAccounts(accountId: id);
      return accounts.firstWhereOrNull(
        (a) => a.encryptedAccountNumber == encAcct,
      );
    } catch (e) {
      log('[TransactionsController] _resolveBankAccount error: $e');
      return null;
    }
  }

  /// Computes the gap between the user-declared real balance and the
  /// DB-computed balance (openingBalance + credits − debits).
  ///
  /// Logic:
  /// - [declaredBalance] = what the user typed when creating/editing the account.
  ///   This is NEVER overwritten by recomputeAndSave, so it stays as the "truth".
  /// - [currentBalance] = recomputed after every import (always = computed).
  /// - If declaredBalance == 0: user never declared a real balance → no banner.
  /// - If declaredBalance > 0: compare vs computeCurrentBalance() to find gap.
  ///
  /// Scenario A (normal import cycle, no manual balance):
  ///   declaredBalance == 0 → guard triggers → no banner.
  ///
  /// Scenario B (user declared ₹5000, imported old statement → computed ₹1000):
  ///   difference = 5000 - 1000 = 4000 → green banner "+₹4000 untracked credits".
  ///
  /// Scenario C (user imports latest statement, computed ≈ declared):
  ///   difference < ₹1 → treated as balanced → no banner.
  Future<void> computeReconciliation() async {
    // Always re-fetch so we pick up the latest declaredBalance after edits.
    if (encryptedAccountNumber != null) {
      _bankAccount = await _resolveBankAccount(encryptedAccountNumber!);
    }
    final account = _bankAccount;

    // Guard: no account model available
    if (account == null) {
      reconciliationRow.value = null;
      return;
    }

    // Guard: user never declared a real balance → nothing to reconcile.
    // Users who just import continuously never set declaredBalance, so
    // this keeps the banner hidden for them (their computed IS the truth).
    if (account.declaredBalance == 0) {
      reconciliationRow.value = null;
      return;
    }

    // Guard: no transactions means nothing to reconcile
    if (_allTransactions.isEmpty) {
      reconciliationRow.value = null;
      return;
    }

    try {
      // Guard: no import sessions recorded means opening balance unknown
      final opening = await _db.getEarliestOpeningBalance(
        account.encryptedAccountNumber,
      );
      if (opening == null) {
        reconciliationRow.value = null;
        return;
      }

      // Compute balance from ALL imported transactions
      final computed = await _db.computeCurrentBalance(
        account.encryptedAccountNumber,
      );

      // Gap = real declared balance minus what transactions explain
      final difference = account.declaredBalance - computed;

      // Guard: floating-point noise threshold (< ₹1)
      if (difference.abs() < 1.0) {
        reconciliationRow.value = null;
        return;
      }

      reconciliationRow.value = ReconciliationRowModel(
        amount: difference.abs(),
        isCredit: difference > 0,
      );
    } catch (e) {
      log('[TransactionsController] computeReconciliation error: $e');
      reconciliationRow.value = null;
    }
  }
}

