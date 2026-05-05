import '../../../core/utils/app_constants.dart';

// MODIFIED: Added ve_status and ve_matched_txn_id fields for Feature B
class VirtualEntryModel {
  int? virtualEntryId;
  int accountId;
  int tagId;
  String entryType; // 'Receivable' or 'Payable'
  double amount;
  String? note;
  String dateAdded;
  String createdAt;
  String? updatedAt;
  String? deletedAt;
  String status; // 'pending' or 'resolved'
  int? matchedTxnId; // FK to transactions table
  String? dueDate; // Optional due date (ISO8601)

  // Joined from tags table
  String? resolvedTagName;

  VirtualEntryModel({
    this.virtualEntryId,
    required this.accountId,
    required this.tagId,
    required this.entryType,
    required this.amount,
    this.note,
    required this.dateAdded,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.status = 'pending',
    this.matchedTxnId,
    this.resolvedTagName,
    this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      VE_ACCOUNT_ID: accountId,
      VE_TAG_ID: tagId,
      VE_ENTRY_TYPE: entryType,
      VE_AMOUNT: amount,
      VE_NOTE: note,
      VE_DATE_ADDED: dateAdded,
      VE_CREATED_AT: createdAt,
      VE_UPDATED_AT: updatedAt,
      VE_DELETED_AT: deletedAt,
      VE_STATUS: status,
      VE_MATCHED_TXN_ID: matchedTxnId,
      VE_DUE_DATE: dueDate,
    };
  }

  factory VirtualEntryModel.fromMap(Map<String, dynamic> map) {
    return VirtualEntryModel(
      virtualEntryId: map[VIRTUAL_ENTRY_ID] as int?,
      accountId: map[VE_ACCOUNT_ID] as int,
      tagId: map[VE_TAG_ID] as int,
      entryType: map[VE_ENTRY_TYPE] as String,
      amount: (map[VE_AMOUNT] as num?)?.toDouble() ?? 0.0,
      note: map[VE_NOTE] as String?,
      dateAdded: map[VE_DATE_ADDED] as String,
      createdAt: map[VE_CREATED_AT] as String,
      updatedAt: map[VE_UPDATED_AT] as String?,
      deletedAt: map[VE_DELETED_AT] as String?,
      status: map[VE_STATUS] as String? ?? 'pending',
      matchedTxnId: map[VE_MATCHED_TXN_ID] as int?,
      resolvedTagName: map['resolvedTagName'] as String?,
      dueDate: map[VE_DUE_DATE] as String?,
    );
  }

  VirtualEntryModel copyWith({
    int? virtualEntryId,
    int? accountId,
    int? tagId,
    String? entryType,
    double? amount,
    String? note,
    String? dateAdded,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    String? status,
    int? matchedTxnId,
    String? resolvedTagName,
    String? dueDate,
  }) {
    return VirtualEntryModel(
      virtualEntryId: virtualEntryId ?? this.virtualEntryId,
      accountId: accountId ?? this.accountId,
      tagId: tagId ?? this.tagId,
      entryType: entryType ?? this.entryType,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      dateAdded: dateAdded ?? this.dateAdded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      status: status ?? this.status,
      matchedTxnId: matchedTxnId ?? this.matchedTxnId,
      resolvedTagName: resolvedTagName ?? this.resolvedTagName,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}
