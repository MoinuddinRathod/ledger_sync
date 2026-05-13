# deleteBankAccount Call Sites Documentation

This document lists all call sites of the `deleteBankAccount` method that need to be replaced with the new `permanentlyDeleteBankAccount` method as part of the Bank Account Activate/Deactivate feature implementation.

## Summary

The `deleteBankAccount` method is currently used in 4 layers of the application:

1. **UI Layer** - bank_accounts_screen.dart
2. **Controller Layer** - bank_account_controller.dart  
3. **Repository Layer** - bank_account_repository.dart
4. **Data Access Layer** - local_db_service.dart

## Call Site Details

### 1. UI Layer Call Site

**File**: `/Users/x25020/flutterapps/ledger_sync/lib/features/bank_account/views/bank_accounts_screen.dart`

**Location**: Line 262-265

**Current Code**:
```dart
DialogService.showDeleteDialog(
  onConfirm: () {
    controller.deleteBankAccount(
      encryptedAccountNumber:
          account.encryptedAccountNumber,
    );
  },
);
```

**Context**: 
- Called from an IconButton with delete icon
- Wrapped in a confirmation dialog (DialogService.showDeleteDialog)
- Passes the encrypted account number from the bank account card

**Action Required**: 
- Replace with call to `controller.permanentlyDeleteAccount(account)`
- Update the dialog to use the new warning dialog with destructive messaging
- Update the button icon to `Icons.delete_forever`

---

### 2. Controller Layer Call Site

**File**: `/Users/x25020/flutterapps/ledger_sync/lib/features/bank_account/controllers/bank_account_controller.dart`

**Location**: Line 320-349 (method definition)

**Current Code**:
```dart
Future<void> deleteBankAccount({
  required String encryptedAccountNumber,
}) async {
  if (encryptedAccountNumber.isEmpty) return;
  if (isLoadingDelete.value) return;

  try {
    isLoadingDelete.value = true;
    final int rowsAffected = await _repo.deleteBankAccount(
      encryptedAccountNumber,
    );
    if (rowsAffected == 0) {
      SnackbarService.showWarning(
        title: 'Not Found',
        message: 'Account not found to delete.',
      );
      return;
    }
    bankAccounts.removeWhere(
      (e) => e.encryptedAccountNumber == encryptedAccountNumber,
    );
    revealedNumbers.remove(encryptedAccountNumber);
    accountVisibility.remove(encryptedAccountNumber);
    Get.back();
    SnackbarService.showSuccess(
      title: 'Account Deleted',
      message: 'Account deleted successfully.',
    );
  } catch (e, stack) {
    log('[BankAccountController] deleteBankAccount: $e', stackTrace: stack);
    SnackbarService.showError(
      title: 'Delete Failed',
      message: 'Unexpected error.',
    );
  } finally {
    isLoadingDelete.value = false;
  }
}
```

**Context**:
- This is the controller method that orchestrates the delete operation
- Calls the repository layer's `deleteBankAccount` method (line 328)
- Manages loading state, updates observable lists, clears cached data
- Provides user feedback via snackbars

**Action Required**:
- Replace this entire method with the new `permanentlyDeleteAccount` method per design spec
- Update to accept `BankAccountModel account` parameter instead of just encrypted account number
- Update success message to indicate permanent deletion
- Call `_repo.permanentlyDeleteBankAccount` instead

---

### 3. Repository Layer Call Site

**File**: `/Users/x25020/flutterapps/ledger_sync/lib/features/bank_account/repository/bank_account_repository.dart`

**Location**: Line 41-46 (method definition)

**Current Code**:
```dart
// delete bank account -------- //
Future<int> deleteBankAccount(String bankAccountNumber) async {
  final accountId = LocalStorageService.instance.accountId;
  if (accountId <= 0) return 0;
  return await db.deleteBankAccount(bankAccountNumber, accountId);
}
```

**Context**:
- Repository layer method that delegates to the database layer
- Retrieves accountId from LocalStorageService
- Validates accountId before proceeding
- Calls the database layer's `deleteBankAccount` method (line 44)

**Action Required**:
- Replace this method with the new `permanentlyDeleteBankAccount` method per design spec
- Update to call `db.permanentlyDeleteBankAccount` instead
- Keep the same validation and delegation pattern

---

### 4. Data Access Layer Call Site

**File**: `/Users/x25020/flutterapps/ledger_sync/lib/core/service/local_db_service/local_db_service.dart`

**Location**: Line 286-291 (method definition)

**Current Code**:
```dart
// -------- delete bank account ------------- //
@Deprecated(
  'Use toggleBankAccountActive or permanentlyDeleteBankAccount instead',
)
Future<int> deleteBankAccount(
  String encryptedAccountNumber,
  int accountId,
) async {
  // ... implementation that sets deleted_at ...
}
```

**Context**:
- Database layer method that performs the actual SQL operation
- Currently sets `deleted_at` timestamp (soft delete)
- Already marked as `@Deprecated` with guidance to use new methods
- This is the lowest layer that interacts with SQLite

**Action Required**:
- This method is already deprecated and should be removed after all call sites are updated
- The new `permanentlyDeleteBankAccount` method already exists (line 322) and implements the cascading delete logic

---

## Related Methods (Already Implemented)

The following new methods have already been implemented in the data access layer:

### permanentlyDeleteBankAccount
**File**: `/Users/x25020/flutterapps/ledger_sync/lib/core/service/local_db_service/local_db_service.dart`
**Location**: Line 322+

This method implements the cascading delete logic:
1. Soft-deletes all linked transactions
2. Hard-deletes all linked import_sessions  
3. Soft-deletes all bank-scoped tags
4. Hard-deletes the bank_account row

All operations are wrapped in a database transaction for atomicity.

---

## Implementation Order

To replace `deleteBankAccount` with the new permanent delete functionality:

1. **Repository Layer** - Add `permanentlyDeleteBankAccount` method
2. **Controller Layer** - Add `permanentlyDeleteAccount` method  
3. **UI Layer** - Update button and dialog to call new controller method
4. **Cleanup** - Remove deprecated `deleteBankAccount` methods from all layers

---

## Requirements Mapping

This documentation supports **Requirement 5.3** from the requirements document:

> THE System SHALL remove the existing deleteBankAccount method that sets deleted_at

All call sites identified above need to be updated to use the new permanent delete functionality before the deprecated method can be safely removed.

---

**Document Created**: Task 4.3 - Search for all deleteBankAccount call sites and document them
**Next Task**: Task 4.4 will implement the replacement of these call sites with the new methods.
