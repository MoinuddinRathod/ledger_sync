import '../utils/app_constants.dart';

enum MasterAccountType {
  cash,
  bank,
  party,
  expense,
  income;

  String get value => name;

  static MasterAccountType fromString(String value) {
    return MasterAccountType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MasterAccountType.party,
    );
  }
}

class MasterAccountModel {
  final int? id;
  final String name;
  final MasterAccountType type;
  final String alias; // comma-separated keywords
  final double openingBalance;
  final String? phone; // for party type
  final String createdAt;
  final String? updatedAt;
  final bool isActive;

  MasterAccountModel({
    this.id,
    required this.name,
    required this.type,
    this.alias = '',
    this.openingBalance = 0.0,
    this.phone,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      MA_ID: id,
      MA_NAME: name,
      MA_TYPE: type.value,
      MA_ALIAS: alias,
      MA_OPENING_BALANCE: openingBalance,
      MA_PHONE: phone,
      MA_CREATED_AT: createdAt,
      MA_UPDATED_AT: updatedAt,
      MA_IS_ACTIVE: isActive ? 1 : 0,
    };
  }

  factory MasterAccountModel.fromMap(Map<String, dynamic> map) {
    return MasterAccountModel(
      id: map[MA_ID] as int?,
      name: map[MA_NAME] ?? '',
      type: MasterAccountType.fromString(map[MA_TYPE] ?? 'party'),
      alias: map[MA_ALIAS] ?? '',
      openingBalance: (map[MA_OPENING_BALANCE] ?? 0).toDouble(),
      phone: map[MA_PHONE],
      createdAt: map[MA_CREATED_AT] ?? '',
      updatedAt: map[MA_UPDATED_AT],
      isActive: (map[MA_IS_ACTIVE] ?? 1) == 1,
    );
  }

  MasterAccountModel copyWith({
    int? id,
    String? name,
    MasterAccountType? type,
    String? alias,
    double? openingBalance,
    String? phone,
    String? createdAt,
    String? updatedAt,
    bool? isActive,
  }) {
    return MasterAccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      alias: alias ?? this.alias,
      openingBalance: openingBalance ?? this.openingBalance,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Parse alias string into a list of keywords
  List<String> get keywords => alias
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  String toString() {
    return 'MasterAccountModel(id: $id, name: $name, type: $type, alias: $alias, openingBalance: $openingBalance, isActive: $isActive)';
  }
}
