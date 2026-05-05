import 'package:get_storage/get_storage.dart';

import '../utils/app_constants.dart';

class LocalStorageService {
  // make this a singleton class
  LocalStorageService._privateConstructor();
  static final LocalStorageService instance =
      LocalStorageService._privateConstructor();

  final box = GetStorage();

  // for logged in or not
  bool get isLoggedIn => box.read(IS_LOGGED_IN) ?? false;
  set isLoggedIn(bool value) => box.write(IS_LOGGED_IN, value);

  // for account id
  int get accountId => box.read(ACCOUNT_ID) ?? -1;
  set accountId(int value) => box.write(ACCOUNT_ID, value);

  // for account name
  String get accountName => box.read(ACCOUNT_NAME) ?? '';
  set accountName(String value) => box.write(ACCOUNT_NAME, value);

  // for default account or not
  bool get isDefault => box.read(IS_DEFAULT) ?? false;
  set isDefault(bool value) => box.write(IS_DEFAULT, value);

  // for first-time onboarding tracking
  bool get hasCompletedOnboarding =>
      box.read(HAS_COMPLETED_ONBOARDING) ?? false;
  set hasCompletedOnboarding(bool value) =>
      box.write(HAS_COMPLETED_ONBOARDING, value);
}
