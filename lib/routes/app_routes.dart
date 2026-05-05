import 'package:get/get.dart';
import '../features/transactions/controller/add_edit_transaction_controller.dart';
import '../features/transactions/views/add_edit_transaction_screen.dart';

import '../features/bank_account/views/add_edit_bank_account_screen.dart';
import '../features/bank_account/views/bank_accounts_screen.dart';
import '../features/cash_wallet/views/cash_wallet_screen.dart';
import '../features/home/bindings/home_binding.dart';
import '../features/home/bindings/upload_flow_binding.dart';
import '../features/home/views/upload_file_screen.dart';
import '../features/master_account/bindings/master_account_binding.dart';
import '../features/master_account/views/chhose_account_screen.dart';
import '../features/master_account/views/create_account_screen.dart';
import '../features/master_account/views/login_screen.dart';
import '../features/master_account/views/setup_master_account_screen.dart';
import '../features/navbar/views/navbar_screen.dart';
import '../features/onboarding/views/get_started_screen.dart';
import '../features/profile/bindings/profile_binding.dart';
import '../features/profile/views/profile_screen.dart';
import '../features/splash/bindings/splash_binding.dart';
import '../features/splash/views/splash_screen.dart';
import '../features/tags/views/tag_add_edit_screen.dart';
import '../features/tags/views/tags_screen.dart';
import '../features/tags/views/tag_transactions_screen.dart';
import '../features/home/views/review_transactions_screen.dart';
import '../features/transactions/views/transactions_screen.dart';
import '../features/virtual_entries/views/virtual_entries_screen.dart';

class AppRoutes {
  static const String splashScreen = '/splash';
  static const String getStartedScreen = '/get-started';
  static const String masterAccountSetupScreen = '/master_account_setup_screen';
  static const String chooseAccountScreen = '/choose_account_screen';
  static const String loginScreen = '/login_screen';
  static const String createAccountScreen = '/create_account_screen';
  static const String homeScreen = '/home_screen';
  static const String uploadFileScreen = '/upload_file_screen';
  static const String accountMappingScreen = '/account_mapping_screen';
  static const String profileScreen = '/profile_screen';
  static const String tagsScreen = '/tags_screen';
  static const String transactionsScreen = '/transactions';
  static const String transactionAddEdit = '/transaction-add-edit';
  static const String tagTransactionsScreen = '/tag-transactions';
  static const String allLedgerScreen = '/all_ledger_screen';
  static const String groupsScreen = "/groups_screen";
  static const String importPreviewScreen = '/import_preview_screen';
  static const String assignTagsScreen = '/assign_tags_screen';
  static const String transactionSuccessScreen = '/transaction_success_screen';
  static const String masterListScreen = '/master_list_screen';
  static const String masterFormScreen = '/master_form_screen';
  static const String transactionMappingScreen = '/transaction_mapping_screen';
  static const String manualEntryScreen = '/manual_entry_screen';
  static const String quickEntryScreen = '/quick_entry_screen';
  static const String importStatement = '/import_statement';
  static const String masterAccounts = '/master_accounts';
  static const String reviewTransactions = '/review_transactions';
  static const String transactionDetail = '/transaction_detail';
  static const String bankAccountsScreen = '/bank_accounts_screen';
  static const String addEditBankAccountScreen =
      '/add_edit_bank_account_screen';
  static const String cashWalletScreen = '/cash_wallet_screen';
  static const tagAddEdit = '/tag-add-edit';
  static const String virtualEntriesScreen = '/virtual_entries_screen';

  static List<GetPage> pages = [
    GetPage(
      name: splashScreen,
      page: () => SplashScreen(),
      binding: SplashBinding(),
    ),
    GetPage(name: getStartedScreen, page: () => GetStartedScreen()),
    GetPage(
      name: masterAccountSetupScreen,
      page: () => SetupMasterAccountScreen(),
      binding: MasterAccountBinding(),
    ),
    GetPage(
      name: chooseAccountScreen,
      page: () => ChooseAccountScreen(),
      binding: MasterAccountBinding(),
    ),
    GetPage(
      name: loginScreen,
      page: () => LoginScreen(),
      binding: MasterAccountBinding(),
    ),
    GetPage(
      name: createAccountScreen,
      page: () => CreateAccountScreen(),
      binding: MasterAccountBinding(),
    ),
    GetPage(
      name: homeScreen,
      page: () => NavbarScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: uploadFileScreen,
      page: () => const UploadFileScreen(),
      binding: UploadFlowBinding(),
    ),

    GetPage(
      name: profileScreen,
      page: () => ProfileScreen(),
      binding: ProfileBinding(),
    ),

    GetPage(name: tagsScreen, page: () => TagsScreen()),

    GetPage(
      name: reviewTransactions,
      page: () => ReviewTransactionsScreen(),
      binding: ReviewTransactionsBinding(),
    ),

    GetPage(name: bankAccountsScreen, page: () => const BankAccountsScreen()),
    GetPage(
      name: addEditBankAccountScreen,
      page: () => const AddEditBankAccountScreen(),
    ),

    GetPage(name: cashWalletScreen, page: () => CashWalletScreen()),

    GetPage(name: tagAddEdit, page: () => TagAddEditScreen()),

    GetPage(name: virtualEntriesScreen, page: () => VirtualEntriesScreen()),

    GetPage(name: transactionsScreen, page: () => TransactionsScreen()),
    GetPage(
      name: transactionAddEdit,
      page: () => const AddEditTransactionScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AddEditTransactionController>(
          () => AddEditTransactionController(),
        );
      }),
    ),
    GetPage(name: tagTransactionsScreen, page: () => TagTransactionsScreen()),
  ];
}
