import '../../../core/utils/app_constants.dart';

class BankAccountModel {
  int accountId;
  String bankName;
  String encryptedAccountNumber; // PK — stored in DB (AES encrypted)
  String lastFourDigits; // stored in DB — plain, for masked display only
  String?
  bankAccountNumber; // NOT stored in DB — only in RAM after eye-tap decrypt
  String accountHolderName;
  String accountType;
  /// Recomputed balance — updated by recomputeAndSave after every import.
  double currentBalance;
  /// User-declared real bank balance — set only when user manually enters it.
  /// NEVER overwritten by recomputeAndSave. 0 means not declared.
  double declaredBalance;
  String dateAdded;
  String createdAt;
  String? updatedAt;
  String? deletedAt;
  bool isActive;

  BankAccountModel({
    required this.encryptedAccountNumber,
    required this.lastFourDigits,
    this.bankAccountNumber, // optional — populated only on demand
    required this.accountId,
    required this.bankName,
    required this.accountHolderName,
    required this.accountType,
    this.currentBalance = 0,
    this.declaredBalance = 0,
    required this.dateAdded,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isActive = true,
  });

  // ------------------------------------------------------------------ //
  // toMap — used for INSERT and UPDATE queries
  // ------------------------------------------------------------------ //
  Map<String, dynamic> toMap() {
    return {
      ACCOUNT_ID: accountId,
      BANK_NAME: bankName,
      BANK_ACCOUNT_NUMBER: encryptedAccountNumber, // encrypted goes to DB
      LAST_FOUR_DIGITS: lastFourDigits, // plain last 4 goes to DB
      ACCOUNT_HOLDER_NAME: accountHolderName,
      ACCOUNT_TYPE: accountType,
      CURRENT_BALANCE: currentBalance,
      DECLARED_BALANCE: declaredBalance,
      DATE_ADDED: dateAdded,
      CREATED_AT: createdAt,
      UPDATED_AT: updatedAt,
      DELETED_AT: deletedAt,
      IS_ACTIVE: isActive ? 1 : 0,
      // bankAccountNumber is intentionally NOT in toMap — never persisted
    };
  }

  // ------------------------------------------------------------------ //
  // fromMap — used when reading rows back from SQLite
  // ------------------------------------------------------------------ //
  factory BankAccountModel.fromMap(Map<String, dynamic> map) {
    return BankAccountModel(
      encryptedAccountNumber: map[BANK_ACCOUNT_NUMBER] as String,
      lastFourDigits: map[LAST_FOUR_DIGITS] as String,
      bankAccountNumber: null, // not in DB — will be set in RAM after decrypt
      accountId: map[ACCOUNT_ID] as int,
      bankName: map[BANK_NAME] as String,
      accountHolderName: map[ACCOUNT_HOLDER_NAME] as String,
      accountType: map[ACCOUNT_TYPE] as String,
      currentBalance: (map[CURRENT_BALANCE] as num?)?.toDouble() ?? 0.0,
      declaredBalance: (map[DECLARED_BALANCE] as num?)?.toDouble() ?? 0.0,
      dateAdded: map[DATE_ADDED] as String,
      createdAt: map[CREATED_AT] as String,
      updatedAt: map[UPDATED_AT] as String?,
      deletedAt: map[DELETED_AT] as String?,
      isActive: (map[IS_ACTIVE] as int? ?? 1) == 1,
    );
  }

  // ------------------------------------------------------------------ //
  // copyWith
  // ------------------------------------------------------------------ //
  BankAccountModel copyWith({
    String? encryptedAccountNumber,
    String? lastFourDigits,
    String? bankAccountNumber,
    int? accountId,
    String? bankName,
    String? accountHolderName,
    String? accountType,
    double? currentBalance,
    double? declaredBalance,
    String? dateAdded,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    bool? isActive,
  }) {
    return BankAccountModel(
      encryptedAccountNumber:
          encryptedAccountNumber ?? this.encryptedAccountNumber,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      accountId: accountId ?? this.accountId,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountType: accountType ?? this.accountType,
      currentBalance: currentBalance ?? this.currentBalance,
      declaredBalance: declaredBalance ?? this.declaredBalance,
      dateAdded: dateAdded ?? this.dateAdded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // ------------------------------------------------------------------ //
  // toString — bankAccountNumber masked in logs for security
  // ------------------------------------------------------------------ //
  @override
  String toString() {
    return 'BankAccountModel('
        'encryptedAccountNumber: [ENCRYPTED], '
        'lastFourDigits: ****$lastFourDigits, '
        'accountId: $accountId, '
        'bankName: $bankName, '
        'accountHolderName: $accountHolderName, '
        'accountType: $accountType, '
        'currentBalance: $currentBalance, '
        'declaredBalance: $declaredBalance, '
        'dateAdded: $dateAdded, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt, '
        'deletedAt: $deletedAt, '
        'isActive: $isActive'
        ')';
  }
}
