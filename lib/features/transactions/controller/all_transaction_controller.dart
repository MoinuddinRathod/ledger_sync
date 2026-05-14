import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/service/local_storage_service.dart';
import '../../../core/service/snackbar_service.dart';
import '../../home/controllers/dashboard_controller.dart';
import '../../cash_wallet/repository/cash_wallet_repository.dart';
import '../models/bank_transaction_model.dart';
import '../repository/transaction_repository.dart';

class AllTransactionsController extends GetxController {
  // ── Dependencies ────────────────────────────────────
  final TransactionRepository _repo = TransactionRepository();
  final CashWalletRepository _cashRepo = CashWalletRepository();

  // ── State ──────────────────────────────────────────
  final RxList<BankTransactionModel> _allTransactions =
      <BankTransactionModel>[].obs;

  final RxList<BankTransactionModel> transactions =
      <BankTransactionModel>[].obs;

  final RxBool isLoading = false.obs;

  // ── Search ─────────────────────────────────────────
  final RxBool isSearching = false.obs;
  final RxString searchQuery = ''.obs;

  // ── Filter ─────────────────────────────────────────
  /// 'Transfer' is the new filter for internal transfers only.
  final List<String> filters = ['All', 'Credit', 'Debit', 'Transfer'];
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
    fetchAllTransactions();
  }

  // ─────────────────────────────────────────────
  // Fetch
  // ─────────────────────────────────────────────

  Future<void> fetchAllTransactions() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      final accountId = LocalStorageService.instance.accountId;

      final bankData = await _repo.getByAccountId(accountId);
      final cashData = await _cashRepo.getCashWalletTransactions(accountId);

      // Convert cash wallet entries into BankTransactionModel instances.
      // Transfer types (Cash Withdrawn/Deposited) already have isInternalTransfer=true
      // and txnRef = bankAccountId set in fromCashWallet factory.
      final cashModels = cashData
          .map((e) => BankTransactionModel.fromCashWallet(e))
          .toList();

      // Build a lookup: bankAccountEncryptedId → cash transfer model.
      // Used to derive the human-readable direction label on the bank-side row.
      final Map<String, BankTransactionModel> cashTransferByBankId = {};
      for (final c in cashModels) {
        if (c.isInternalTransfer && c.txnRef != null) {
          cashTransferByBankId[c.txnRef!] = c;
        }
      }

      // Process bank rows:
      //  - Rows with TRF_* txnRef are the bank leg of a Cash↔Bank transfer.
      //    Annotate them with isInternalTransfer=true and a transferLabel.
      //  - All other rows pass through unchanged.
      final processedBank = bankData.map((txn) {
        if (txn.hasTrfRef) {
          // Derive direction from the paired cash entry (if available).
          final cashLeg = cashTransferByBankId[txn.encryptedAccountId];
          String transferLabel;
          if (cashLeg != null) {
            final cashType = cashLeg.txnRef != null
                ? 'Cash Wallet'
                : 'Cash Wallet';
            final isCashToBank =
                txn.txnType.toUpperCase() == 'CR'; // bank received money
            transferLabel = isCashToBank
                ? 'Cash Wallet → ${txn.maskedAccountLabel}'
                : '${txn.maskedAccountLabel} → Cash Wallet';
          } else {
            transferLabel = 'Internal Transfer · ${txn.maskedAccountLabel}';
          }
          return txn.copyWith(
            isInternalTransfer: true,
            transferLabel: transferLabel,
          );
        }
        return txn;
      }).toList();

      // Only include non-transfer cash entries in the merged list.
      // Transfer cash entries are already represented through the bank-side row.
      final nonTransferCash = cashModels
          .where((c) => !c.isInternalTransfer)
          .toList();

      final merged = [...processedBank, ...nonTransferCash];

      _allTransactions.assignAll(merged);
      _applyFilters();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      SnackbarService.showError(
        title: 'Error',
        message: 'Failed to load transactions',
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────

  Future<void> deleteTransaction(BankTransactionModel txn) async {
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

      if (rows > 0) {
        await fetchAllTransactions(); // refresh
        _refreshDashboard();
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      SnackbarService.showError(
        title: 'Delete Failed',
        message: 'Unable to delete transaction',
      );
    }
  }

  // ─────────────────────────────────────────────
  // Search / Filter / Sort
  // ─────────────────────────────────────────────

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) clearSearch();
  }

  void onSearchChanged(String val) {
    searchQuery.value = val;
    _applyFilters();
  }

  void clearSearch() {
    searchQuery.value = '';
    _applyFilters();
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    _applyFilters();
  }

  void setSort(String sort) {
    selectedSort.value = sort;
    _applyFilters();
  }

  Future<void> pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
  // Pipeline
  // ─────────────────────────────────────────────

  void _applyFilters() {
    List<BankTransactionModel> result = List.from(_allTransactions);

    // 1. Filter by type
    if (selectedFilter.value == 'Credit') {
      result = result
          .where((e) => e.isCredit && !e.isInternalTransfer)
          .toList();
    } else if (selectedFilter.value == 'Debit') {
      result = result.where((e) => e.isDebit && !e.isInternalTransfer).toList();
    } else if (selectedFilter.value == 'Transfer') {
      result = result.where((e) => e.isInternalTransfer).toList();
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

    // 3. Search (narration, tag name, bank name, or transfer label)
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      result = result.where((t) {
        return t.txnNarration.toLowerCase().contains(q) ||
            t.resolvedTagName.toLowerCase().contains(q) ||
            (t.bankName?.toLowerCase().contains(q) ?? false) ||
            (t.transferLabel?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // 4. Sort
    if (selectedSort.value == 'Amount') {
      result.sort((a, b) => b.txnAmount.compareTo(a.txnAmount));
    } else {
      // Sort by Date
      result.sort((a, b) {
        final da = _parseTxnDate(a.txnDate);
        final db = _parseTxnDate(b.txnDate);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da); // newest first
      });
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
  // Summary — internal transfers are EXCLUDED from CR/DR totals
  // ─────────────────────────────────────────────

  double get totalCredit => _allTransactions
      .where((e) => e.isCredit && !e.isInternalTransfer)
      .fold(0.0, (s, e) => s + e.txnAmount);

  double get totalDebit => _allTransactions
      .where((e) => e.isDebit && !e.isInternalTransfer)
      .fold(0.0, (s, e) => s + e.txnAmount);

  /// Total amount moved via internal transfers (for display in Transfer filter view).
  double get totalTransfers => _allTransactions
      .where((e) => e.isInternalTransfer)
      .fold(0.0, (s, e) => s + e.txnAmount);

  void _refreshDashboard() {
    try {
      Get.find<DashboardController>().refreshDashboard();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }
}
