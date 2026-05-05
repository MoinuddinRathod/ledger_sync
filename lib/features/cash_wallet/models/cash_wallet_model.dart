import '../../../core/utils/app_constants.dart';

class CashWalletModel {
  int? cashWalletId;
  int accountId;
  double currentBalance;
  String dateAdded;
  String createdAt;
  String? updatedAt;
  String? deletedAt;

  CashWalletModel({
    this.cashWalletId,
    required this.accountId,
    this.currentBalance = 0.0,
    required this.dateAdded,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      ACCOUNT_ID: accountId,
      CASH_WALLET_CURRENT_BALANCE: currentBalance,
      DATE_ADDED: dateAdded,
      CREATED_AT: createdAt,
      UPDATED_AT: updatedAt,
      DELETED_AT: deletedAt,
    };
  }

  factory CashWalletModel.fromMap(Map<String, dynamic> map) {
    return CashWalletModel(
      cashWalletId: map[CASH_WALLET_ID] as int?,
      accountId: map[ACCOUNT_ID] as int,
      currentBalance: (map[CASH_WALLET_CURRENT_BALANCE] as num?)?.toDouble() ?? 0.0,
      dateAdded: map[DATE_ADDED] as String,
      createdAt: map[CREATED_AT] as String,
      updatedAt: map[UPDATED_AT] as String?,
      deletedAt: map[DELETED_AT] as String?,
    );
  }

  CashWalletModel copyWith({
    int? cashWalletId,
    int? accountId,
    double? currentBalance,
    String? dateAdded,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
  }) {
    return CashWalletModel(
      cashWalletId: cashWalletId ?? this.cashWalletId,
      accountId: accountId ?? this.accountId,
      currentBalance: currentBalance ?? this.currentBalance,
      dateAdded: dateAdded ?? this.dateAdded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
