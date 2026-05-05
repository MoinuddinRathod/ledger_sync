
class BalanceValidator {
  static String? validateBalance(double balance, double amount) {
    if (amount <= 0) {
      return 'Enter valid amount';
    }
    if (amount > balance) {
      return 'Insufficient balance';
    }
    return null;
  }

  /// Calculates the adjusted balance by reversing the old transaction impact
  /// [currentBalance]: The current balance of the account/wallet
  /// [oldAmount]: The absolute amount of the old transaction (0 if new transaction)
  /// [isOldDebit]: True if the old transaction was a debit/expense
  static double calculateAdjustedBalance({
    required double currentBalance,
    required double oldAmount,
    required bool isOldDebit,
  }) {
    if (oldAmount <= 0) return currentBalance;
    // Reverse old transaction impact
    return isOldDebit ? currentBalance + oldAmount : currentBalance - oldAmount;
  }
}
