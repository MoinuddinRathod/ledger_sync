class ParsedTransactionModel {
  final String
  txnRef; // Unique transaction reference (generated if not in file)
  final String date;
  final String narration;
  final double amount;
  String? bankAccountNumber;
  final String type; // 'Dr' or 'Cr' (or 'debit'/'credit')
  final int? suggestedAccountId; // Auto-matched master account ID
  final double matchConfidence; // 0.0 to 1.0
  final Map<String, dynamic> rawRow; // Original row data for debugging
  final double? balance;

  // User-selected tags (set during review)
  final int? selectedAccountId; // User-selected master account ID
  final int? selectedPartyId; // User-selected party ID
  final bool isReviewed; // Whether user has reviewed this transaction
  final String? accountName; // For display purposes
  final String? partyName; // For display purposes
  final bool rememberMapping; // Save keyword mapping for future

  // Legacy fields for backward compatibility
  String? mappedMasterAccountId;
  String? mappedMasterAccountType;
  String? mappedMasterAccountName;

  ParsedTransactionModel({
    String? txnRef,
    required this.date,
    required this.narration,
    this.bankAccountNumber,
    required this.amount,
    required this.type,
    this.suggestedAccountId,
    this.matchConfidence = 0.0,
    Map<String, dynamic>? rawRow,
    this.selectedAccountId,
    this.selectedPartyId,
    this.isReviewed = false,
    this.accountName,
    this.partyName,
    this.rememberMapping = false,
    this.mappedMasterAccountId,
    this.mappedMasterAccountType,
    this.mappedMasterAccountName,
    this.balance,
  }) : txnRef = txnRef ?? '',
       rawRow = rawRow ?? {};

  /// Whether this is a debit (outflow)
  bool get isDebit =>
      type.toLowerCase() == 'dr' || type.toLowerCase() == 'debit';

  /// Whether this is a credit (inflow)
  bool get isCredit =>
      type.toLowerCase() == 'cr' || type.toLowerCase() == 'credit';

  /// Whether this transaction has been matched (auto or manual)
  bool get isMatched => selectedAccountId != null || suggestedAccountId != null;

  /// Get the effective account ID (user selection takes priority)
  int? get effectiveAccountId => selectedAccountId ?? suggestedAccountId;

  /// Match status for display
  MatchStatus get matchStatus {
    if (selectedAccountId != null) return MatchStatus.reviewed;
    if (suggestedAccountId != null) return MatchStatus.autoMatched;
    return MatchStatus.unmatched;
  }

  ParsedTransactionModel copyWith({
    String? txnRef,
    String? date,
    String? narration,
    double? amount,
    String? type,
    int? suggestedAccountId,
    double? matchConfidence,
    Map<String, dynamic>? rawRow,
    int? selectedAccountId,
    int? selectedPartyId,
    bool? isReviewed,
    String? accountName,
    String? partyName,
    bool? rememberMapping,
    String? mappedMasterAccountId,
    String? mappedMasterAccountType,
    String? mappedMasterAccountName,
    double? balance,
    String? bankAccountNumber,
  }) {
    return ParsedTransactionModel(
      txnRef: txnRef ?? this.txnRef,
      date: date ?? this.date,
      narration: narration ?? this.narration,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      suggestedAccountId: suggestedAccountId ?? this.suggestedAccountId,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      rawRow: rawRow ?? this.rawRow,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      selectedPartyId: selectedPartyId ?? this.selectedPartyId,
      isReviewed: isReviewed ?? this.isReviewed,
      accountName: accountName ?? this.accountName,
      partyName: partyName ?? this.partyName,
      rememberMapping: rememberMapping ?? this.rememberMapping,
      mappedMasterAccountId:
          mappedMasterAccountId ?? this.mappedMasterAccountId,
      mappedMasterAccountType:
          mappedMasterAccountType ?? this.mappedMasterAccountType,
      mappedMasterAccountName:
          mappedMasterAccountName ?? this.mappedMasterAccountName,
      balance: balance ?? this.balance,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    );
  }

  @override
  String toString() {
    return 'ParsedTransactionModel(txnRef: $txnRef, date: $date, narration: $narration, amount: $amount, type: $type, balance: $balance)';
  }
}

/// Match status for display
enum MatchStatus {
  autoMatched, // ✅ Auto-matched

  reviewed, // ✅ User reviewed
  unmatched, // ❌ Unmatched
}
