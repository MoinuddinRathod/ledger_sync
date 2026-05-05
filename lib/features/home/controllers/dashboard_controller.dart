import 'dart:developer';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../../cash_wallet/controller/cash_wallet_controller.dart';

/// Lightweight model to hold a recent transaction for dashboard display.
class DashboardRecentTx {
  final int id;
  final String date;
  final double amount;
  final String type; // 'cr' or 'dr'
  final String narration;
  final String tagName;
  final String bankName;
  final String lastFourDigits;

  DashboardRecentTx({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.narration,
    required this.tagName,
    required this.bankName,
    required this.lastFourDigits,
  });

  bool get isCredit => type.toLowerCase() == 'cr';

  String get formattedAmount {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    return isCredit ? '+₹${fmt.format(amount)}' : '-₹${fmt.format(amount)}';
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return date;
    }
  }

  factory DashboardRecentTx.fromMap(Map<String, dynamic> map) {
    return DashboardRecentTx(
      id: (map['txn_id'] as num?)?.toInt() ?? 0,
      date: map['txn_date'] as String? ?? '',
      amount: (map['txn_amount'] as num?)?.toDouble() ?? 0.0,
      type: map['txn_type'] as String? ?? '',
      narration: map['txn_narration'] as String? ?? '',
      tagName: map['tag_name'] as String? ?? 'Untagged',
      bankName: map['bank_name'] as String? ?? '',
      lastFourDigits: map['last_four_digits'] as String? ?? '',
    );
  }
}

class DashboardController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ─── Observables ────────────────────────────────────────────────────────────
  final RxBool isLoading = true.obs;

  // Balance
  final RxDouble totalBalance = 0.0.obs;
  final RxDouble bankBalance = 0.0.obs;
  final RxDouble cashBalance = 0.0.obs;

  // Income / Expense (all-time)
  final RxDouble totalIncome = 0.0.obs;
  final RxDouble totalExpenses = 0.0.obs;

  // Virtual Entries
  final RxDouble totalReceivable = 0.0.obs;
  final RxDouble totalPayable = 0.0.obs;

  // Recent Transactions
  final RxList<DashboardRecentTx> recentTransactions =
      <DashboardRecentTx>[].obs;

  final RxString lastUpdated = ''.obs;

  @override
  void onInit() {
    super.onInit();
    refreshDashboard();
  }

  // ─── Main Refresh ────────────────────────────────────────────────────────────
  /// Call this from any controller after a mutation (add, update, delete).
  Future<void> refreshDashboard() async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) {
      log('[DashboardController] Invalid accountId — skipping refresh.');
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    try {
      await Future.wait([
        _loadBalances(accountId),
        _loadIncomeExpense(accountId),
        _loadVirtualEntrySummary(accountId),
        _loadRecentTransactions(accountId),
      ]);

      if (Get.isRegistered<BankAccountController>()) {
        Get.find<BankAccountController>().fetchBankAccounts(accountId: accountId);
      }
      if (Get.isRegistered<CashWalletController>()) {
        Get.find<CashWalletController>().fetchData();
      }

      lastUpdated.value = DateFormat('hh:mm a').format(DateTime.now());
    } catch (e, stack) {
      log('[DashboardController] refreshDashboard error: $e', stackTrace: stack);
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Private Loaders ────────────────────────────────────────────────────────

  Future<void> _loadBalances(int accountId) async {
    try {
      final result = await _db.getDashboardBalances(accountId);
      bankBalance.value =
          (result['bank_total'] as num?)?.toDouble() ?? 0.0;
      cashBalance.value =
          (result['cash_total'] as num?)?.toDouble() ?? 0.0;
      totalBalance.value = bankBalance.value + cashBalance.value;
    } catch (e) {
      log('[DashboardController] _loadBalances error: $e');
      bankBalance.value = 0.0;
      cashBalance.value = 0.0;
      totalBalance.value = 0.0;
    }
  }

  Future<void> _loadIncomeExpense(int accountId) async {
    try {
      final result = await _db.getDashboardIncomeExpense(accountId);
      totalIncome.value =
          (result['total_income'] as num?)?.toDouble() ?? 0.0;
      totalExpenses.value =
          (result['total_expense'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      log('[DashboardController] _loadIncomeExpense error: $e');
      totalIncome.value = 0.0;
      totalExpenses.value = 0.0;
    }
  }

  Future<void> _loadVirtualEntrySummary(int accountId) async {
    try {
      final result = await _db.getVirtualEntrySummary(accountId);
      totalReceivable.value = result['receivable'] ?? 0.0;
      totalPayable.value = result['payable'] ?? 0.0;
    } catch (e) {
      log('[DashboardController] _loadVirtualEntrySummary error: $e');
      totalReceivable.value = 0.0;
      totalPayable.value = 0.0;
    }
  }

  Future<void> _loadRecentTransactions(int accountId) async {
    try {
      final rows =
          await _db.getRecentTransactions(accountId, limit: 5);
      recentTransactions.value =
          rows.map(DashboardRecentTx.fromMap).toList();
    } catch (e) {
      log('[DashboardController] _loadRecentTransactions error: $e');
      recentTransactions.clear();
    }
  }

  // ─── Formatters (use from UI directly) ──────────────────────────────────────
  String formatCurrency(double amount) {
    final fmt = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );
    return fmt.format(amount);
  }
}
