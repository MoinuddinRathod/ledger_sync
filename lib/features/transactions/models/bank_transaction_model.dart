import '../../../core/utils/app_constants.dart';

/// Represents a single row from:
///   transactions LEFT JOIN tags ON txn_tag_id = tag_id
///                LEFT JOIN bank_accounts ON txn_account_id = bank_account_number
class BankTransactionModel {
  final int txnId;
  final String txnDate;
  final double txnAmount;

  /// 'CR' (credit/income) or 'DR' (debit/expense)
  final String txnType;
  final String txnNarration;

  /// FK → bank_accounts.bank_account_number (encrypted TEXT)
  final String encryptedAccountId;
  final int txnTagId;

  // ── Joined from tags ───────────────────────────────────────
  final String? tagName;

  // ── Joined from bank_accounts ──────────────────────────────
  final String? bankName;
  final String? lastFourDigits;
  final String? accountHolderName;
  final bool isManual;

  const BankTransactionModel({
    required this.txnId,
    required this.txnDate,
    required this.txnAmount,
    required this.txnType,
    required this.txnNarration,
    required this.encryptedAccountId,
    required this.txnTagId,
    this.tagName,
    this.bankName,
    this.lastFourDigits,
    this.accountHolderName,
    this.isManual = false,
  });

  // ────────────────────────────────────────────────────────────
  // Convenience helpers
  // ────────────────────────────────────────────────────────────

  bool get isCredit => txnType.toUpperCase() == 'CR';
  bool get isDebit => txnType.toUpperCase() == 'DR';

  /// Human-readable masked bank identifier e.g. "SBI ···4321"
  String get maskedAccountLabel {
    final bank = (bankName?.isNotEmpty == true) ? bankName! : 'Bank';
    final last4 = (lastFourDigits?.isNotEmpty == true) ? lastFourDigits! : '????';
    return '$bank ···$last4';
  }

  /// Resolves tag name, falling back gracefully
  String get resolvedTagName => (tagName?.isNotEmpty == true) ? tagName! : 'Untagged';

  // ────────────────────────────────────────────────────────────
  // fromMap — built from a rawQuery JOIN result row
  // ────────────────────────────────────────────────────────────
  factory BankTransactionModel.fromMap(Map<String, dynamic> map) {
    return BankTransactionModel(
      txnId: (map[TXN_ID] as num?)?.toInt() ?? 0,
      txnDate: (map[TXN_DATE] as String?) ?? '',
      txnAmount: (map[TXN_AMOUNT] as num?)?.toDouble() ?? 0.0,
      txnType: (map[TXN_TYPE] as String?) ?? 'DR',
      txnNarration: (map[TXN_NARRATION] as String?) ?? '',
      encryptedAccountId: (map[TXN_ACCOUNT_ID] as String?) ?? '',
      txnTagId: (map[TXN_TAG_ID] as num?)?.toInt() ?? 0,
      tagName: map[TAG_NAME] as String?,
      bankName: map[BANK_NAME] as String?,
      lastFourDigits: map[LAST_FOUR_DIGITS] as String?,
      accountHolderName: map[ACCOUNT_HOLDER_NAME] as String?,
      isManual: (map[TXN_IS_MANUAL] as num?)?.toInt() == 1,
    );
  }

  // ────────────────────────────────────────────────────────────
  // fromCashWallet — mapping CashWalletTransactionModel to BankTransactionModel
  // ────────────────────────────────────────────────────────────
  factory BankTransactionModel.fromCashWallet(dynamic cashTxn) {
    // using dynamic here since CashWalletTransactionModel is not imported in this file
    // but the fields are well known.
    return BankTransactionModel(
      txnId: cashTxn.cashWalletTransactionId ?? 0,
      txnDate: cashTxn.dateAdded,
      txnAmount: cashTxn.amount,
      txnType: cashTxn.transactionType == 'Income' ? 'CR' : 'DR',
      txnNarration: cashTxn.transactionNote ?? 'Cash Transaction',
      encryptedAccountId: 'CASH',
      txnTagId: cashTxn.tagId,
      tagName: cashTxn.resolvedTagName,
      bankName: 'Cash Wallet',
      lastFourDigits: '',
      isManual: true,
    );
  }

  // ────────────────────────────────────────────────────────────
  // copyWith
  // ────────────────────────────────────────────────────────────
  BankTransactionModel copyWith({
    int? txnId,
    String? txnDate,
    double? txnAmount,
    String? txnType,
    String? txnNarration,
    String? encryptedAccountId,
    int? txnTagId,
    String? tagName,
    String? bankName,
    String? lastFourDigits,
    String? accountHolderName,
    bool? isManual,
  }) {
    return BankTransactionModel(
      txnId: txnId ?? this.txnId,
      txnDate: txnDate ?? this.txnDate,
      txnAmount: txnAmount ?? this.txnAmount,
      txnType: txnType ?? this.txnType,
      txnNarration: txnNarration ?? this.txnNarration,
      encryptedAccountId: encryptedAccountId ?? this.encryptedAccountId,
      txnTagId: txnTagId ?? this.txnTagId,
      tagName: tagName ?? this.tagName,
      bankName: bankName ?? this.bankName,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      isManual: isManual ?? this.isManual,
    );
  }

  @override
  String toString() {
    return 'BankTransactionModel(txnId: $txnId, txnDate: $txnDate, '
        'txnAmount: $txnAmount, txnType: $txnType, '
        'tagName: $tagName, bank: $maskedAccountLabel)';
  }
}
