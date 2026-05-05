import '../../../core/utils/app_constants.dart';

class AccountModel {
  final int? accountId;
  final String accountName;
  final String pin;
  final String createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final int isDefault;

  AccountModel({
    this.accountId,
    required this.accountName,
    required this.pin,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.isDefault,
  });

  // Convert a Map into an AccountModel
  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      accountId: map[ACCOUNT_ID],
      accountName: map[ACCOUNT_NAME],
      pin: map[ACCOUNT_PIN],
      createdAt: map[CREATED_AT],
      updatedAt: map[UPDATED_AT],
      deletedAt: map[DELETED_AT],
      isDefault: map[IS_DEFAULT],
    );
  }

  // Convert an AccountModel into a Map
  Map<String, dynamic> toMap() {
    return {
      ACCOUNT_ID: accountId,
      ACCOUNT_NAME: accountName,
      ACCOUNT_PIN: pin,
      CREATED_AT: createdAt,
      UPDATED_AT: updatedAt,
      DELETED_AT: deletedAt,
      IS_DEFAULT: isDefault,
    };
  }
}
