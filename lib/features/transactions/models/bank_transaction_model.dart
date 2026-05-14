import '../../../core/utils/app_constants.dart';

/// Represents a single row from:
///   transactions LEFT JOIN tags ON txn_tag_id = tag_id
///                LEFT JOIN bank_accounts ON txn_account_id = bank_account_number
///
/// Internal transfers (Cash↔Bank, Bank↔Bank) have [isInternalTransfer] = true
/// and a human-readable [transferLabel] e.g. "Cash Wallet → HDFC ···4321".
/// They must NOT be counted in income/expense totals.
class BankTransactionModel {
  final int txnId;
  final String txnDate;
  final double txnAmount;

  /// 'CR' (credit/income) or 'DR' (debit/expense)
  final String txnType;
  final String txnNarration;

  /// FK → bank_accounts.bank_account_number (encrypted TEXT).
  /// 'CASH' for cash wallet entries.
  final String encryptedAccountId;
  final int txnTagId;

  // ── Joined from tags ───────────────────────────────────────
  final String? tagName;

  // ── Joined from bank_accounts ──────────────────────────────
  final String? bankName;
  final String? lastFourDigits;
  final String? accountHolderName;
  final bool isManual;

  // ── Transfer grouping ──────────────────────────────────────
  /// The raw txn_ref value from the DB. Internal transfer entries carry a
  /// 'TRF_*' prefix. Regular imports use other values or null.
  final String? txnRef;

  /// True when this entry is one leg of an internal transfer (Cash↔Bank or
  /// Bank↔Bank). Set by [AllTransactionsController] at fetch time.
  final bool isInternalTransfer;

  /// Human-readable direction label, e.g. "Cash Wallet → HDFC ···4321".
  /// Only non-null when [isInternalTransfer] is true.
  final String? transferLabel;

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
    this.txnRef,
    this.isInternalTransfer = false,
    this.transferLabel,
  });

  // ────────────────────────────────────────────────────────────
  // Convenience helpers
  // ────────────────────────────────────────────────────────────

  bool get isCredit => txnType.toUpperCase() == 'CR';
  bool get isDebit => txnType.toUpperCase() == 'DR';

  /// True when txnRef carries the internal-transfer prefix.
  bool get hasTrfRef => txnRef?.startsWith('TRF_') == true;

  /// Human-readable masked bank identifier e.g. "SBI ···4321"
  String get maskedAccountLabel {
    final bank = (bankName?.isNotEmpty == true) ? bankName! : 'Bank';
    final last4 = (lastFourDigits?.isNotEmpty == true) ? lastFourDigits! : '????';
    return '$bank ···$last4';
  }

  /// Resolves tag name, falling back gracefully
  String get resolvedTagName =>
      (tagName?.isNotEmpty == true) ? tagName! : 'Untagged';

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
      txnRef: map[TXN_REF] as String?,
    );
  }

  // ────────────────────────────────────────────────────────────
  // fromCashWallet — mapping CashWalletTransactionModel to BankTransactionModel
  // ────────────────────────────────────────────────────────────
  factory BankTransactionModel.fromCashWallet(dynamic cashTxn) {
    // using dynamic here since CashWalletTransactionModel is not imported in
    // this file, but the fields are well known.
    final type = cashTxn.transactionType as String;
    final isCashTransfer =
        type == 'Cash Withdrawn From Bank' || type == 'Cash Deposited To Bank';
    return BankTransactionModel(
      txnId: cashTxn.cashWalletTransactionId ?? 0,
      txnDate: cashTxn.dateAdded,
      txnAmount: (cashTxn.amount as num).toDouble().abs(),
      txnType: (type == 'Income' || type == 'Cash Withdrawn From Bank')
          ? 'CR'
          : 'DR',
      txnNarration: cashTxn.transactionNote ?? 'Cash Transaction',
      encryptedAccountId: 'CASH',
      txnTagId: cashTxn.tagId,
      tagName: cashTxn.resolvedTagName,
      bankName: 'Cash Wallet',
      lastFourDigits: '',
      isManual: true,
      // Cash transfer entries carry the linked bank account id — used for
      // pairing with the bank-side entry in AllTransactionsController.
      txnRef: isCashTransfer ? cashTxn.bankAccountId : null,
      isInternalTransfer: isCashTransfer,
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
    String? txnRef,
    bool? isInternalTransfer,
    String? transferLabel,
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
      txnRef: txnRef ?? this.txnRef,
      isInternalTransfer: isInternalTransfer ?? this.isInternalTransfer,
      transferLabel: transferLabel ?? this.transferLabel,
    );
  }

  @override
  String toString() {
    return 'BankTransactionModel(txnId: $txnId, txnDate: $txnDate, '
        'txnAmount: $txnAmount, txnType: $txnType, '
        'isInternalTransfer: $isInternalTransfer, '
        'tagName: $tagName, bank: $maskedAccountLabel)';
  }
}
