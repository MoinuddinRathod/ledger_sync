class DashboardStatsModel {
  // Balances
  final double bankTotal;
  final double cashTotal;
  final double combinedTotal;

  // All-time
  final double allTimeIncome;
  final double allTimeExpense;
  final double allTimeBankIncome;
  final double allTimeBankExpense;
  final double allTimeCashIncome;
  final double allTimeCashExpense;

  // Current month
  final double monthIncome;
  final double monthExpense;
  final double monthBankIncome;
  final double monthBankExpense;
  final double monthCashIncome;
  final double monthCashExpense;

  DashboardStatsModel({
    this.bankTotal = 0.0,
    this.cashTotal = 0.0,
    this.combinedTotal = 0.0,
    this.allTimeIncome = 0.0,
    this.allTimeExpense = 0.0,
    this.allTimeBankIncome = 0.0,
    this.allTimeBankExpense = 0.0,
    this.allTimeCashIncome = 0.0,
    this.allTimeCashExpense = 0.0,
    this.monthIncome = 0.0,
    this.monthExpense = 0.0,
    this.monthBankIncome = 0.0,
    this.monthBankExpense = 0.0,
    this.monthCashIncome = 0.0,
    this.monthCashExpense = 0.0,
  });

  double get allTimeNet => allTimeIncome - allTimeExpense;
  double get monthNet => monthIncome - monthExpense;
}
