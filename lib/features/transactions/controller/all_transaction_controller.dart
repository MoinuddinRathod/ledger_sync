import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

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

      final merged = [
        ...bankData,
        ...cashData.map((e) => BankTransactionModel.fromCashWallet(e)),
      ];

      _allTransactions.assignAll(merged);
      _applyFilters();
    } catch (e) {
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
    } catch (_) {
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
      result = result.where((e) => e.isCredit).toList();
    } else if (selectedFilter.value == 'Debit') {
      result = result.where((e) => e.isDebit).toList();
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

    // 3. Search (narration, tag name, or bank name)
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      result = result.where((t) {
        return t.txnNarration.toLowerCase().contains(q) ||
            t.resolvedTagName.toLowerCase().contains(q) ||
            (t.bankName?.toLowerCase().contains(q) ?? false);
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
    } catch (_) {}
    try {
      return DateFormat('dd/MM/yyyy').parse(raw);
    } catch (_) {}
    try {
      return DateFormat('MM/dd/yyyy').parse(raw);
    } catch (_) {}
    return null;
  }

  /// Expose a formatted date string for the tile.
  String formatDisplayDate(String raw) {
    final d = _parseTxnDate(raw);
    if (d == null) return raw;
    return DateFormat('dd MMM yyyy').format(d);
  }

  // ─────────────────────────────────────────────
  // Summary
  // ─────────────────────────────────────────────

  double get totalCredit => _allTransactions
      .where((e) => e.isCredit)
      .fold(0.0, (s, e) => s + e.txnAmount);

  double get totalDebit => _allTransactions
      .where((e) => e.isDebit)
      .fold(0.0, (s, e) => s + e.txnAmount);

  void _refreshDashboard() {
    try {
      Get.find<DashboardController>().refreshDashboard();
    } catch (_) {}
  }
}
