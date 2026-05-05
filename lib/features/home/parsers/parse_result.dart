import '../models/parsed_transaction_model.dart'; // added

class ParseResult {
  final String? bankName;
  final String? accountName;
  final String? accountNumber;
  final bool isEmpty;
  final String? errorMessage;
  final List<ParsedTransactionModel> transactions;
  final double? initialBalance;
  final double? currentBalance;
  final String? fromDate; // earliest txn date in this file: 'yyyy-MM-dd'
  final String? toDate; // latest txn date in this file:   'yyyy-MM-dd'
  const ParseResult({
    this.bankName,
    this.accountName,
    this.accountNumber,
    this.isEmpty = false,
    this.errorMessage,
    this.transactions = const [],
    this.initialBalance,
    this.currentBalance,
    this.fromDate,
    this.toDate,
  });

  bool get hasAccountName =>
      accountName != null && accountName!.trim().isNotEmpty;
  bool get hasAccountNumber =>
      accountNumber != null && accountNumber!.trim().isNotEmpty;
  bool get hasBothDetails => hasAccountName && hasAccountNumber;
  bool get hasError => errorMessage != null;
  bool get hasInitialBalance =>
      initialBalance != null && initialBalance!.toString().isNotEmpty;
}
