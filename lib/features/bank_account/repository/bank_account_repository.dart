import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../models/bank_account_model.dart';

class BankAccountRepository {
  // ----- for making db method call ----- //
  var db = DatabaseHelper.instance;

  // ----- business logic methods ----- //

  // add bank account -------- //
  Future<int> addBankAccount(BankAccountModel model) async {
    // --- check for duplicate ac --- //
    //:TODO

    return await db.insertBankAccount(model);
  }

  // get all bank accounts -------- //
  Future<List<BankAccountModel>> getAllBankAccounts({
    required int accountId,
  }) async {
    return await db.getBankAccounts(accountId);
  }

  // update bank account -------- //
  Future<int> updateBankAccount(
    BankAccountModel model,
    String oldEncryptedAccountNumber,
  ) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return 0;
    return await db.updateBankAccount(
      model,
      oldEncryptedAccountNumber,
      accountId,
    );
  }

  // toggle bank account active -------- //
  Future<int> toggleBankAccountActive(
    String encryptedAccountNumber,
    bool isActive,
  ) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return 0;
    return await db.toggleBankAccountActive(
      encryptedAccountNumber,
      isActive,
      accountId,
    );
  }

  // permanently delete bank account -------- //
  Future<int> permanentlyDeleteBankAccount(
    String encryptedAccountNumber,
  ) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return 0;
    return await db.permanentlyDeleteBankAccount(
      encryptedAccountNumber,
      accountId,
    );
  }

  // update bank balance ------- //
  Future<void> updateBankAccountBalance(
    String bankAccountNumber,
    double newBalance,
  ) async {
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) return;
    await db.updateBankAccountBalance(
      bankAccountNumber,
      newBalance,
      accountId: accountId,
    );
  }
}
