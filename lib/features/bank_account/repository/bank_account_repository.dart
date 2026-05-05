import '../../../core/service/local_db_service/local_db_service.dart';
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
    return await db.updateBankAccount(model, oldEncryptedAccountNumber);
  }

  // delete bank account -------- //
  Future<int> deleteBankAccount(String bankAccountNumber) async {
    return await db.deleteBankAccount(bankAccountNumber);
  }

  // update bank balance ------- //
  Future<void> updateBankAccountBalance(
    String bankAccountNumber,
    double newBalance,
  ) async {
    await db.updateBankAccountBalance(bankAccountNumber, newBalance);
  }
}
