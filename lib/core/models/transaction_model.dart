enum TransactionType {
  debit,
  credit;

  String get value => name;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TransactionType.debit,
    );
  }
}

enum EntryType {
  payment,
  receipt,
  contra,
  journal,
  imported;

  String get value => name;

  static EntryType fromString(String value) {
    return EntryType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => EntryType.journal,
    );
  }
}

enum TransactionSource {
  manual,
  imported;

  String get value => name;

  static TransactionSource fromString(String value) {
    return TransactionSource.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TransactionSource.manual,
    );
  }
}

class TransactionModel {
  final int? id;
  final String txnRef; // UNIQUE transaction reference
  final String date;
  final String particulars;
  final double amount;
  final TransactionType type;
  final EntryType entryType;
  final int? masterAccountId; // FK to master_accounts
  final int? partyId; // FK to master_accounts (party type)
  final String narration;
  final TransactionSource source;
  final String createdAt;
  final String? updatedAt;

  TransactionModel({
    this.id,
    required this.txnRef,
    required this.date,
    required this.particulars,
    required this.amount,
    required this.type,
    required this.entryType,
    this.masterAccountId,
    this.partyId,
    this.narration = '',
    required this.source,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {};
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      txnRef: '',
      date: '',
      particulars: '',
      amount: 0.0,
      type: TransactionType.debit,
      entryType: EntryType.imported,
      source: TransactionSource.imported,
      createdAt: '',
    );
  }

  TransactionModel copyWith({
    int? id,
    String? txnRef,
    String? date,
    String? particulars,
    double? amount,
    TransactionType? type,
    EntryType? entryType,
    int? masterAccountId,
    int? partyId,
    String? narration,
    TransactionSource? source,
    String? createdAt,
    String? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      txnRef: txnRef ?? this.txnRef,
      date: date ?? this.date,
      particulars: particulars ?? this.particulars,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      entryType: entryType ?? this.entryType,
      masterAccountId: masterAccountId ?? this.masterAccountId,
      partyId: partyId ?? this.partyId,
      narration: narration ?? this.narration,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, txnRef: $txnRef, date: $date, amount: $amount, type: $type, entryType: $entryType)';
  }
}
