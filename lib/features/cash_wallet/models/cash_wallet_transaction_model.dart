import '../../../core/utils/app_constants.dart';

class CashWalletTransactionModel {
  int? cashWalletTransactionId;
  int accountId;
  int tagId; // Replaces raw transactionNote reliance or supplements it
  String transactionType; // e.g., 'Expense', 'Income'
  double amount;
  String? transactionNote;
  String dateAdded;
  String createdAt;
  String? updatedAt;
  String? deletedAt;
  String? bankAccountId; // encrypted bank account number FK
  bool
  isManual; // true for user-created, false for auto-generated (ATM/cash tag dual-effect)

  // Joined from tags table
  String? resolvedTagName;

  CashWalletTransactionModel({
    this.cashWalletTransactionId,
    required this.accountId,
    required this.tagId,
    required this.transactionType,
    required this.amount,
    this.transactionNote,
    required this.dateAdded,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.resolvedTagName,
    this.bankAccountId,
    this.isManual = false,
  });

  Map<String, dynamic> toMap() {
    return {
      ACCOUNT_ID: accountId,
      CASH_WALLET_TRANSACTION_TAG_ID: tagId,
      CASH_WALLET_TRANSACTION_TYPE: transactionType,
      AMOUNT: amount,
      TRANSACTION_NOTE: transactionNote,
      DATE_ADDED: dateAdded,
      CREATED_AT: createdAt,
      UPDATED_AT: updatedAt,
      DELETED_AT: deletedAt,
      CASH_WALLET_TRANSACTION_BANK_ACCOUNT_ID: bankAccountId,
      CASH_WALLET_IS_MANUAL: isManual ? 1 : 0,
    };
  }

  factory CashWalletTransactionModel.fromMap(Map<String, dynamic> map) {
    return CashWalletTransactionModel(
      cashWalletTransactionId: map[CASH_WALLET_TRANSACTION_ID] as int?,
      accountId: map[ACCOUNT_ID] as int,
      tagId: map[CASH_WALLET_TRANSACTION_TAG_ID] as int,
      transactionType: map[CASH_WALLET_TRANSACTION_TYPE] as String,
      amount: (map[AMOUNT] as num?)?.toDouble() ?? 0.0,
      transactionNote: map[TRANSACTION_NOTE] as String?,
      dateAdded: map[DATE_ADDED] as String,
      createdAt: map[CREATED_AT] as String,
      updatedAt: map[UPDATED_AT] as String?,
      deletedAt: map[DELETED_AT] as String?,
      resolvedTagName: map['resolvedTagName'] as String?,
      bankAccountId: map[CASH_WALLET_TRANSACTION_BANK_ACCOUNT_ID] as String?,
      isManual: ((map[CASH_WALLET_IS_MANUAL] as int?) ?? 0) == 1,
    );
  }

  CashWalletTransactionModel copyWith({
    int? cashWalletTransactionId,
    int? accountId,
    int? tagId,
    String? transactionType,
    double? amount,
    String? transactionNote,
    String? dateAdded,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    String? resolvedTagName,
    String? bankAccountId,
    bool? isManual,
  }) {
    return CashWalletTransactionModel(
      cashWalletTransactionId:
          cashWalletTransactionId ?? this.cashWalletTransactionId,
      accountId: accountId ?? this.accountId,
      tagId: tagId ?? this.tagId,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      transactionNote: transactionNote ?? this.transactionNote,
      dateAdded: dateAdded ?? this.dateAdded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      resolvedTagName: resolvedTagName ?? this.resolvedTagName,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      isManual: isManual ?? this.isManual,
    );
  }
}
