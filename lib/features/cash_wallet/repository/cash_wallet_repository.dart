import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../models/cash_wallet_model.dart';
import '../models/cash_wallet_transaction_model.dart';

class CashWalletRepository {
  var db = DatabaseHelper.instance;

  // -------- get cash wallet ------------- //
  Future<CashWalletModel?> getCashWallet(int accountId) async {
    final result = await db.getCashWallet(accountId);
    if (result != null) {
      return CashWalletModel.fromMap(result);
    }
    return null;
  }

  // -------- create cash wallet ------------- //
  Future<int> createCashWallet(CashWalletModel model) async {
    return await db.insertCashWallet(model.toMap());
  }

  // -------- update cash wallet balance ------------- //
  Future<int> updateCashWalletBalance(int accountId, double newBalance) async {
    return await db.updateCashWalletBalance(accountId, newBalance);
  }

  // -------- insert cash wallet transaction ------------- //
  Future<int> insertCashWalletTransaction(
    CashWalletTransactionModel model,
  ) async {
    return await db.insertCashWalletTransaction(model.toMap());
  }

  // -------- get cash wallet transactions ------------- //
  Future<List<CashWalletTransactionModel>> getCashWalletTransactions(
    int accountId,
  ) async {
    final result = await db.getCashWalletTransactions(accountId);
    return result.map((e) => CashWalletTransactionModel.fromMap(e)).toList();
  }

  // -------- delete cash wallet transaction ------------- //
  Future<int> deleteCashWalletTransaction(int transactionId) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return 0;
    return await db.deleteCashWalletTransaction(transactionId, accountId);
  }

  // -------- update cash wallet transaction ------------- //
  Future<int> updateCashWalletTransaction(
    CashWalletTransactionModel model,
    int transactionId,
  ) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return 0;
    return await db.updateCashWalletTransaction(
      model.toMap(),
      transactionId,
      accountId,
    );
  }
}
