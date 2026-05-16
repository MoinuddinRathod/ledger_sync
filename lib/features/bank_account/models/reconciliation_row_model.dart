/// Represents a virtual row shown in the transaction list to explain
/// the gap between stored transactions and the actual bank balance.
class ReconciliationRowModel {
  /// The absolute value of the difference
  final double amount;

  /// true  = untracked credits (balance > computed → missing income)
  /// false = untracked debits  (balance < computed → missing expense)
  final bool isCredit;

  /// Human-readable label
  String get label => isCredit ? 'Untracked Credits' : 'Untracked Debits';

  String get description => isCredit
      ? 'Your balance is higher than recorded transactions. '
          'Some credits may not be imported yet.'
      : 'Your balance is lower than recorded transactions. '
          'Some debits may not be imported yet.';

  const ReconciliationRowModel({
    required this.amount,
    required this.isCredit,
  });
}
