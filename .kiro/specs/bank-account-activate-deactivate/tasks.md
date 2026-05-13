# Implementation Plan

## Task 1: Database Schema and Constants

- [x] 1.1 Add IS_ACTIVE constant to app_constants.dart
  - Open file: `lib/core/utils/app_constants.dart`
  - Locate the bank accounts constants section (after `LAST_FOUR_DIGITS`)
  - Add new constant: `const String IS_ACTIVE = 'is_active';`
  - Follow the exact same naming pattern as existing constants (SCREAMING_SNAKE_CASE)
  - _Requirements: 1.1, 1.5_

- [x] 1.2 Update bank_accounts table schema in local_db_service.dart
  - Open file: `lib/core/service/local_db_service/local_db_service.dart`
  - Locate the `onCreate` method and find the `CREATE TABLE $TABLE_BANK_ACCOUNTS` statement
  - Add new column after `deleted_at`: `$IS_ACTIVE INTEGER NOT NULL DEFAULT 1`
  - Do NOT add any migration logic (fresh app - no onUpgrade needed)
  - Verify the column is added before the FOREIGN KEY constraint
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

## Task 2: Data Model Updates

- [x] 2.1 Update BankAccountModel class
  - Open file: `lib/features/bank_account/models/bank_account_model.dart`
  - Add new property: `final bool isActive;` (after `deletedAt` property)
  - Update constructor to include `this.isActive = true` with default value
  - Update `fromMap` factory: Add `isActive: (map[IS_ACTIVE] as int? ?? 1) == 1`
  - Update `toMap` method: Add `IS_ACTIVE: isActive ? 1 : 0`
  - Update `copyWith` method: Add `bool? isActive` parameter and assignment
  - Update `toString` method: Add `isActive: $isActive` to the output
  - Import `app_constants.dart` if not already imported
  - _Requirements: 1.1, 1.2, 1.3_

## Task 3: Data Access Layer Methods

- [x] 3.1 Add toggleBankAccountActive method to DatabaseHelper
  - Open file: `lib/core/service/local_db_service/local_db_service.dart`
  - Add new method after `deleteBankAccount` method
  - Method signature: `Future<int> toggleBankAccountActive(String encryptedAccountNumber, bool isActive, int accountId) async`
  - Implementation:
    - Validate accountId using `_isValidAccountId(accountId)`, return 0 if invalid
    - Get database instance
    - Execute `db.update()` on `TABLE_BANK_ACCOUNTS`
    - Update map: `{IS_ACTIVE: isActive ? 1 : 0, UPDATED_AT: DateTime.now().toIso8601String()}`
    - WHERE clause: `"$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?"`
    - WHERE args: `[encryptedAccountNumber, accountId]`
    - Return the number of rows affected
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 5.1, 5.4, 5.6, 5.7_

- [x] 3.2 Add permanentlyDeleteBankAccount method to DatabaseHelper
  - Open file: `lib/core/service/local_db_service/local_db_service.dart`
  - Add new method after `toggleBankAccountActive` method
  - Method signature: `Future<int> permanentlyDeleteBankAccount(String encryptedAccountNumber, int accountId) async`
  - Implementation:
    - Validate accountId using `_isValidAccountId(accountId)`, return 0 if invalid
    - Get database instance
    - Wrap everything in `db.transaction((txn) async { ... })`
    - Inside transaction:
      - Create timestamp: `final now = DateTime.now().toIso8601String();`
      - Step 1: Soft-delete transactions: `await txn.update(TABLE_TRANSACTIONS, {DELETED_AT: now}, where: "$TXN_ACCOUNT_ID = ?", whereArgs: [encryptedAccountNumber])`
      - Step 2: Hard-delete import_sessions: `await txn.delete(TABLE_IMPORT_SESSIONS, where: "$IMPORT_BANK_ACCOUNT_NUMBER = ?", whereArgs: [encryptedAccountNumber])`
      - Step 3: Soft-delete bank-scoped tags: `await txn.update(TABLE_TAGS, {TAG_DELETED_AT: now}, where: "$TAG_BANK_ACCOUNT_ID = ?", whereArgs: [encryptedAccountNumber])`
      - Step 4: Hard-delete bank_account: `final rowsDeleted = await txn.delete(TABLE_BANK_ACCOUNTS, where: "$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?", whereArgs: [encryptedAccountNumber, accountId])`
      - Return rowsDeleted
    - CRITICAL: Use `txn.update()` and `txn.delete()` inside transaction, NEVER `db.*`
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.2, 5.5, 5.6, 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.2, 10.3, 10.4, 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 3.3 Update getBankAccounts method to filter by is_active
  - Open file: `lib/core/service/local_db_service/local_db_service.dart`
  - Locate the `getBankAccounts` method
  - Update WHERE clause from `"$ACCOUNT_ID = ? AND $DELETED_AT IS NULL"` to `"$ACCOUNT_ID = ? AND $IS_ACTIVE = 1 AND $DELETED_AT IS NULL"`
  - Update whereArgs to remain `[accountId]` (no change needed)
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 3.4 Deprecate or remove old deleteBankAccount method
  - Open file: `lib/core/service/local_db_service/local_db_service.dart`
  - Locate the `deleteBankAccount` method (the one that sets `deleted_at`)
  - Option 1: Add `@Deprecated('Use toggleBankAccountActive or permanentlyDeleteBankAccount instead')` annotation
  - Option 2: Comment out the method with a note explaining replacement
  - Do NOT remove yet - will be removed after updating all call sites
  - _Requirements: 5.3_

## Task 4: Repository Layer Updates

- [x] 4.1 Add toggleBankAccountActive method to BankAccountRepository
  - Open file: `lib/features/bank_account/repository/bank_account_repository.dart`
  - Add new method after `deleteBankAccount` method
  - Method signature: `Future<int> toggleBankAccountActive(String encryptedAccountNumber, bool isActive) async`
  - Implementation:
    - Get accountId: `final accountId = LocalStorageService.instance.accountId;`
    - Validate: `if (accountId <= 0) return 0;`
    - Delegate to db: `return await db.toggleBankAccountActive(encryptedAccountNumber, isActive, accountId);`
  - Follow the exact same pattern as existing repository methods
  - _Requirements: 5.1, 5.4_

- [x] 4.2 Add permanentlyDeleteBankAccount method to BankAccountRepository
  - Open file: `lib/features/bank_account/repository/bank_account_repository.dart`
  - Add new method after `toggleBankAccountActive` method
  - Method signature: `Future<int> permanentlyDeleteBankAccount(String encryptedAccountNumber) async`
  - Implementation:
    - Get accountId: `final accountId = LocalStorageService.instance.accountId;`
    - Validate: `if (accountId <= 0) return 0;`
    - Delegate to db: `return await db.permanentlyDeleteBankAccount(encryptedAccountNumber, accountId);`
  - Follow the exact same pattern as existing repository methods
  - _Requirements: 5.2, 5.5_

- [x] 4.3 Search for all deleteBankAccount call sites and document them
  - Use grep/search to find all files calling `deleteBankAccount`
  - Expected locations:
    - `lib/features/bank_account/controllers/bank_account_controller.dart`
    - `lib/features/bank_account/views/bank_accounts_screen.dart` (indirect via controller)
  - Document the call sites in a comment for the next task
  - _Requirements: 5.3_

- [x] 4.4 Remove old deleteBankAccount method from repository
  - Open file: `lib/features/bank_account/repository/bank_account_repository.dart`
  - Remove the `deleteBankAccount` method entirely
  - Verify no compilation errors (all call sites should be updated in controller)
  - _Requirements: 5.3_

## Task 5: Controller Layer Updates

- [x] 5.1 Add isLoadingToggle observable to BankAccountController
  - Open file: `lib/features/bank_account/controllers/bank_account_controller.dart`
  - Locate the loading state observables section (near `isLoadingDelete`)
  - Add new observable: `final RxBool isLoadingToggle = false.obs;`
  - Update `isBusy` getter to include `isLoadingToggle.value` in the OR condition
  - _Requirements: 14.5_

- [x] 5.2 Add toggleAccountActive method to BankAccountController
  - Open file: `lib/features/bank_account/controllers/bank_account_controller.dart`
  - Add new method after `deleteBankAccount` method
  - Method signature: `Future<void> toggleAccountActive(BankAccountModel account) async`
  - Implementation:
    - Check if already loading: `if (isLoadingToggle.value) return;`
    - Wrap in try-catch-finally
    - Set loading: `isLoadingToggle.value = true;`
    - Calculate new state: `final newState = !account.isActive;`
    - Call repository: `final int rowsAffected = await _repo.toggleBankAccountActive(account.encryptedAccountNumber, newState);`
    - If rowsAffected == 0, show warning and return
    - Update local state: Find account in `bankAccounts` list and update with `copyWith(isActive: newState, updatedAt: DateTime.now().toIso8601String())`
    - Refresh list: `await fetchBankAccounts(accountId: LocalStorageService.instance.accountId);`
    - Show success: `SnackbarService.showSuccess(title: newState ? 'Account Activated' : 'Account Deactivated', message: '${account.bankName} is now ${newState ? "active" : "inactive"}.');`
    - Catch errors and show error message
    - Finally: `isLoadingToggle.value = false;`
  - Add import for `dart:developer` if not already present (for log)
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 13.5, 14.1, 14.3, 14.5, 14.6_

- [x] 5.3 Add permanentlyDeleteAccount method to BankAccountController
  - Open file: `lib/features/bank_account/controllers/bank_account_controller.dart`
  - Add new method after `toggleAccountActive` method
  - Method signature: `Future<void> permanentlyDeleteAccount(BankAccountModel account) async`
  - Implementation:
    - Check if already loading: `if (isLoadingDelete.value) return;`
    - Wrap in try-catch-finally
    - Set loading: `isLoadingDelete.value = true;`
    - Call repository: `final int rowsAffected = await _repo.permanentlyDeleteBankAccount(account.encryptedAccountNumber);`
    - If rowsAffected == 0, show warning and return
    - Remove from local state: `bankAccounts.removeWhere((e) => e.encryptedAccountNumber == account.encryptedAccountNumber);`
    - Clear cached data: `revealedNumbers.remove(account.encryptedAccountNumber);` and `accountVisibility.remove(account.encryptedAccountNumber);`
    - Close dialogs: `Get.back();`
    - Show success: `SnackbarService.showSuccess(title: 'Account Deleted', message: '${account.bankName} and all related data permanently deleted.');`
    - Catch errors and show error message
    - Finally: `isLoadingDelete.value = false;`
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 13.6, 14.2, 14.4, 14.5, 14.6_

- [x] 5.4 Remove old deleteBankAccount method from controller
  - Open file: `lib/features/bank_account/controllers/bank_account_controller.dart`
  - Remove the `deleteBankAccount` method entirely
  - Verify no compilation errors (UI should be updated to call new methods)
  - _Requirements: 5.3_

## Task 6: UI Updates

- [x] 6.1 Locate the bank account card widget in bank_accounts_screen.dart
  - Open file: `lib/features/bank_account/views/bank_accounts_screen.dart`
  - Find the widget that displays individual bank account cards
  - Locate the existing delete button (likely an IconButton with Icons.delete)
  - Document the current structure for reference
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 6.2 Add toggle switch to bank account card
  - Open file: `lib/features/bank_account/views/bank_accounts_screen.dart`
  - Locate the top section of the bank account card (near bank name or balance display)
  - Add a Row widget with:
    - Text widget showing "Active" or "Inactive" based on `account.isActive`
    - Style: fontSize 12, fontWeight w600, color green for active / grey for inactive
    - Obx wrapper around Switch widget
    - Switch properties:
      - `value: account.isActive`
      - `onChanged: controller.isLoadingToggle.value ? null : (value) { controller.toggleAccountActive(account); }`
      - `activeColor: Colors.green.shade600`
      - `inactiveThumbColor: Colors.grey.shade400`
  - Position the Row with `mainAxisAlignment: MainAxisAlignment.spaceBetween`
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 6.3 Replace delete button with permanent delete button
  - Open file: `lib/features/bank_account/views/bank_accounts_screen.dart`
  - Locate the existing delete IconButton
  - Replace with new IconButton:
    - `icon: Icon(Icons.delete_forever)`
    - `color: Colors.red.shade700`
    - `tooltip: 'Delete Permanently'`
    - `onPressed: controller.isLoadingDelete.value ? null : () async { ... }`
  - Inside onPressed:
    - Call `DialogService.showWarningDialog()`
    - title: `'Permanently Delete?'`
    - description: `'This will permanently remove ${account.bankName} (****${account.lastFourDigits}) and ALL its transactions, import history, and linked data. This cannot be undone.'`
    - confirmText: `'Delete Permanently'`
    - onConfirm: `() { Get.back(result: true); }`
    - Store result: `final bool? confirmed = await DialogService.showWarningDialog(...);`
    - If confirmed == true, call: `controller.permanentlyDeleteAccount(account);`
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

- [x] 6.4 Verify DialogService import
  - Open file: `lib/features/bank_account/views/bank_accounts_screen.dart`
  - Check if `DialogService` is imported: `import '../../../core/service/dialog_service.dart';`
  - Add import if missing
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

## Task 7: Testing and Verification

- [x] 7.1 Manual testing - Toggle functionality
  - Run the app and navigate to bank accounts screen
  - Test toggling an account from active to inactive
  - Verify:
    - Switch animates correctly
    - Account disappears from list (filtered out)
    - Success message appears
    - No errors in console
  - Test toggling back to active (if you add a way to view inactive accounts)
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 7.2 Manual testing - Permanent delete functionality
  - Run the app and navigate to bank accounts screen
  - Create a test bank account with some transactions
  - Tap the permanent delete button
  - Verify:
    - Confirmation dialog appears with correct title and description
    - Bank name and last 4 digits are shown correctly
    - Warning text is clear
    - Cancel button closes dialog without deleting
    - Confirm button triggers deletion
    - Account is removed from list
    - Success message appears
    - No errors in console
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

- [x] 7.3 Database verification - Cascading delete
  - Use a database inspector tool (e.g., DB Browser for SQLite)
  - Before permanent delete:
    - Note the bank account number
    - Note transaction IDs linked to this account
    - Note import session IDs linked to this account
    - Note tag IDs scoped to this account
  - After permanent delete:
    - Verify bank_account row is hard-deleted (not present)
    - Verify transactions have `deleted_at` set (soft-deleted)
    - Verify import_sessions are hard-deleted (not present)
    - Verify bank-scoped tags have `tag_deleted_at` set (soft-deleted)
    - Verify user-scoped tags are untouched
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.2, 10.3, 10.4, 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 7.4 Error handling verification
  - Test toggle with invalid account (simulate by modifying accountId)
  - Test permanent delete with invalid account
  - Test permanent delete with database locked (simulate by holding a transaction)
  - Verify:
    - Appropriate error messages appear
    - No crashes occur
    - Loading states are cleared
    - UI remains responsive
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6_

- [x] 7.5 Regression testing - Unrelated features
  - Verify cash wallet functionality is unchanged
  - Verify virtual entries functionality is unchanged
  - Verify dashboard balance calculations work correctly (only active accounts)
  - Verify transaction display works correctly (only active accounts)
  - Verify tag management works correctly (except bank-scoped tags in permanent delete)
  - Verify no other screens are affected
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

## Task 8: Final Verification Checklist

- [x] 8.1 Schema verification
  - [x] is_active column added to CREATE TABLE in onCreate
  - [x] IS_ACTIVE constant added to app_constants
  - [x] No migration logic added (fresh app)
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 8.2 Model verification
  - [x] BankAccountModel has isActive property
  - [x] fromMap includes isActive mapping
  - [x] toMap includes IS_ACTIVE mapping
  - [x] copyWith includes isActive parameter
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 8.3 Database helper verification
  - [x] toggleBankAccountActive method added
  - [x] permanentlyDeleteBankAccount method added with transaction
  - [x] getBankAccounts filters by is_active = 1
  - [x] Old deleteBankAccount removed or deprecated
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [x] 8.4 Repository verification
  - [x] toggleBankAccountActive method added
  - [x] permanentlyDeleteBankAccount method added
  - [x] Old deleteBankAccount removed
  - [x] All methods follow existing patterns
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 8.5 Controller verification
  - [x] isLoadingToggle observable added
  - [x] toggleAccountActive method added
  - [x] permanentlyDeleteAccount method added
  - [x] Old deleteBankAccount removed
  - [x] All call sites updated
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6_

- [x] 8.6 UI verification
  - [x] Toggle switch added to bank account card
  - [x] Permanent delete button replaces old delete button
  - [x] Confirmation dialog implemented correctly
  - [x] No unrelated files modified
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 7.1, 7.2, 7.3, 7.4, 7.5, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 12.6_

- [x] 8.7 Testing verification
  - [x] Manual testing completed for toggle
  - [x] Manual testing completed for permanent delete
  - [x] Database cascading verified
  - [x] Error handling verified
  - [x] Regression testing completed
  - _Requirements: All requirements verified_

## Notes

- **Implementation Order**: Follow tasks sequentially (1 → 2 → 3 → 4 → 5 → 6 → 7 → 8)
- **No Parallel Work**: Complete each task fully before moving to the next
- **Testing**: Manual testing is required after UI updates (Task 7)
- **Database Inspection**: Use DB Browser for SQLite or similar tool for Task 7.3
- **Rollback**: If issues arise, revert changes in reverse order (8 → 7 → 6 → 5 → 4 → 3 → 2 → 1)
- **Fresh App**: No migration logic needed - this is a fresh app with no production data
- **Minimal Changes**: Only modify files directly related to bank account management
- **Existing Patterns**: Follow established code style, naming conventions, and architecture
