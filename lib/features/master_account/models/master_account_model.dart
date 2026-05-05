import 'dart:convert';
import '../../../core/utils/app_constants.dart';

class MasterAccountModel {
  final String id; // UUID
  final String name;
  final String
  type; // 'PartyAccount', 'BankAccount', 'CashAccount', 'ExpenseLedger', 'IncomeLedger'
  final List<String> keywords;
  final String createdAt;

  MasterAccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.keywords,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      MASTER_ACCOUNT_ID: id,
      MASTER_ACCOUNT_NAME: name,
      MASTER_ACCOUNT_TYPE: type,
      MASTER_ACCOUNT_KEYWORDS: jsonEncode(keywords),
      MASTER_ACCOUNT_CREATED_AT: createdAt,
    };
  }

  factory MasterAccountModel.fromMap(Map<String, dynamic> map) {
    return MasterAccountModel(
      id: map[MASTER_ACCOUNT_ID] ?? '',
      name: map[MASTER_ACCOUNT_NAME] ?? '',
      type: map[MASTER_ACCOUNT_TYPE] ?? '',
      keywords: List<String>.from(
        jsonDecode(map[MASTER_ACCOUNT_KEYWORDS] ?? '[]'),
      ),
      createdAt: map[MASTER_ACCOUNT_CREATED_AT] ?? '',
    );
  }

  MasterAccountModel copyWith({
    String? id,
    String? name,
    String? type,
    List<String>? keywords,
    String? createdAt,
  }) {
    return MasterAccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      keywords: keywords ?? this.keywords,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
