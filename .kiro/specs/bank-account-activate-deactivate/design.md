# Design Document

## Introduction

This document provides the technical design for implementing the Bank Account Activate/Deactivate feature. The design replaces the current soft-delete mechanism (which sets `deleted_at`) with a dual-state system: a reversible activate/deactivate toggle using an `is_active` flag, and a separate permanent delete operation that performs cascading cleanup across related tables.

The implementation follows the existing Flutter + SQLite + GetX architecture patterns established in the codebase, ensuring consistency with current code style, naming conventions, and data access patterns.

## System Architecture

### Technology Stack
- **Frontend**: Flutter with GetX state management
- **Database**: SQLite (sqflite package)
- **Encryption**: AES encryption for bank account numbers (existing BankAccountEncryptionService)
- **UI Components**: Material Design with custom dialog service

### Architectural Layers
1. **Data Layer**: SQLite database with LocalDbService (DatabaseHelper)
2. **Repository Layer**: BankAccountRepository for business logic
3. **Controller Layer**: BankAccountController (GetX) for state management
4. **View Layer**: bank_accounts_screen.dart with Material UI components

## Database Schema Design

### Schema Changes

#### bank_accounts Table Modification

**Current Schema:**
```sql
CREATE TABLE bank_accounts (
  bank_account_number TEXT PRIMARY KEY,
  last_four_digits TEXT NOT NULL,
  account_id INTEGER NOT NULL,
  bank_name TEXT NOT NULL,
  account_holder_name TEXT NOT NULL,
  account_type TEXT NOT NULL,
  current_balance REAL NOT NULL,
  date_added TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  deleted_at TEXT,
  FOREIGN KEY (account_id) REFERENCES accounts(account_id)
)
```

**Updated Schema:**
```sql
CREATE TABLE bank_accounts (
  bank_account_number TEXT PRIMARY KEY,
  last_four_digits TEXT NOT NULL,
  account_id INTEGER NOT NULL,
  bank_name TEXT NOT NULL,
  account_holder_name TEXT NOT NULL,
  account_type TEXT NOT NULL,
  current_balance REAL NOT NULL,
  date_added TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  deleted_at TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,  -- NEW COLUMN
  FOREIGN KEY (account_id) REFERENCES accounts(account_id)
)
```

**Column Specification:**
- **Name**: `is_active`
- **Type**: `INTEGER NOT NULL DEFAULT 1`
- **Values**: 
  - `1` = Active (visible in queries, normal operation)
  - `0` = Inactive (hidden from queries, data preserved)
- **Purpose**: Enables soft state toggle without data loss
- **Migration**: Not required (fresh app - direct CREATE TABLE update)

### Constants Addition

**File**: `lib/core/utils/app_constants.dart`

**New Constant:**
```dart
const String IS_ACTIVE = 'is_active';
```

**Location**: Add after `DELETED_AT` constant in the bank accounts section

## Data Model Design

### BankAccountModel Updates

**File**: `lib/features/bank_account/models/bank_account_model.dart`

#### Property Addition
```dart
class BankAccountModel {
  // ... existing properties ...
  final bool isActive;  // NEW PROPERTY
  
  BankAccountModel({
    // ... existing parameters ...
    this.isActive = true,  // DEFAULT VALUE
  });
}
```

#### fromMap Update
```dart
factory BankAccountModel.fromMap(Map<String, dynamic> map) {
  return BankAccountModel(
    // ... existing mappings ...
    isActive: (map[IS_ACTIVE] as int? ?? 1) == 1,  // NEW MAPPING
  );
}
```

#### toMap Update
```dart
Map<String, dynamic> toMap() {
  return {
    // ... existing mappings ...
    IS_ACTIVE: isActive ? 1 : 0,  // NEW MAPPING
  };
}
```

#### copyWith Update
```dart
BankAccountModel copyWith({
  // ... existing parameters ...
  bool? isActive,  // NEW PARAMETER
}) {
  return BankAccountModel(
    // ... existing assignments ...
    isActive: isActive ?? this.isActive,  // NEW ASSIGNMENT
  );
}
```

## Data Access Layer Design

### LocalDbService (DatabaseHelper) Methods

**File**: `lib/core/service/local_db_service/local_db_service.dart`

#### Method 1: toggleBankAccountActive

**Purpose**: Update the `is_active` flag for a bank account

**Signature:**
```dart
Future<int> toggleBankAccountActive(
  String encryptedAccountNumber,
  bool isActive,
  int accountId,
) async
```

**Implementation:**
```dart
Future<int> toggleBankAccountActive(
  String encryptedAccountNumber,
  bool isActive,
  int accountId,
) async {
  if (!_isValidAccountId(accountId)) return 0;
  final db = await instance.database;
  return await db.update(
    TABLE_BANK_ACCOUNTS,
    {
      IS_ACTIVE: isActive ? 1 : 0,
      UPDATED_AT: DateTime.now().toIso8601String(),
    },
    where: "$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?",
    whereArgs: [encryptedAccountNumber, accountId],
  );
}
```

**Parameters:**
- `encryptedAccountNumber`: The encrypted bank account number (PK)
- `isActive`: Target state (true = active, false = inactive)
- `accountId`: User's account ID for security scoping

**Returns**: Number of rows affected (1 on success, 0 on failure)

**Validation**: Uses existing `_isValidAccountId()` helper

#### Method 2: permanentlyDeleteBankAccount

**Purpose**: Hard delete a bank account with cascading cleanup

**Signature:**
```dart
Future<int> permanentlyDeleteBankAccount(
  String encryptedAccountNumber,
  int accountId,
) async
```

**Implementation:**
```dart
Future<int> permanentlyDeleteBankAccount(
  String encryptedAccountNumber,
  int accountId,
) async {
  if (!_isValidAccountId(accountId)) return 0;
  final db = await instance.database;
  
  return await db.transaction((txn) async {
    final now = DateTime.now().toIso8601String();
    
    // Step 1: Soft-delete all linked transactions
    await txn.update(
      TABLE_TRANSACTIONS,
      {DELETED_AT: now},
      where: "$TXN_ACCOUNT_ID = ?",
      whereArgs: [encryptedAccountNumber],
    );
    
    // Step 2: Hard-delete all linked import_sessions
    await txn.delete(
      TABLE_IMPORT_SESSIONS,
      where: "$IMPORT_BANK_ACCOUNT_NUMBER = ?",
      whereArgs: [encryptedAccountNumber],
    );
    
    // Step 3: Soft-delete all bank-scoped tags
    await txn.update(
      TABLE_TAGS,
      {TAG_DELETED_AT: now},
      where: "$TAG_BANK_ACCOUNT_ID = ?",
      whereArgs: [encryptedAccountNumber],
    );
    
    // Step 4: Hard-delete the bank_account row
    final rowsDeleted = await txn.delete(
      TABLE_BANK_ACCOUNTS,
      where: "$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?",
      whereArgs: [encryptedAccountNumber, accountId],
    );
    
    return rowsDeleted;
  });
}
```

**Transaction Flow:**
1. **Soft-delete transactions**: Sets `deleted_at` on all transactions linked to this account
2. **Hard-delete import_sessions**: Physically removes import session records
3. **Soft-delete bank-scoped tags**: Sets `tag_deleted_at` on tags where `tag_bank_account_id` matches
4. **Hard-delete bank_account**: Physically removes the bank account row

**Critical Rules:**
- All operations wrapped in `db.transaction()` for atomicity
- Uses `txn.update()` and `txn.delete()` inside transaction (never `db.*`)
- Rollback occurs automatically if any operation fails
- User-scoped tags (where `tag_bank_account_id IS NULL`) are NOT modified

**Returns**: Number of bank account rows deleted (1 on success, 0 on failure)

#### Method 3: getBankAccounts Update

**Current Implementation:**
```dart
Future<List<BankAccountModel>> getBankAccounts(int accountId) async {
  final db = await instance.database;
  final result = await db.query(
    TABLE_BANK_ACCOUNTS,
    where: "$ACCOUNT_ID = ? AND $DELETED_AT IS NULL",
    whereArgs: [accountId],
  );
  return result.map((e) => BankAccountModel.fromMap(e)).toList();
}
```

**Updated Implementation:**
```dart
Future<List<BankAccountModel>> getBankAccounts(int accountId) async {
  final db = await instance.database;
  final result = await db.query(
    TABLE_BANK_ACCOUNTS,
    where: "$ACCOUNT_ID = ? AND $IS_ACTIVE = 1 AND $DELETED_AT IS NULL",
    whereArgs: [accountId],
  );
  return result.map((e) => BankAccountModel.fromMap(e)).toList();
}
```

**Change**: Added `$IS_ACTIVE = 1` filter to WHERE clause

#### Method 4: deleteBankAccount Deprecation

**Current Method:**
```dart
Future<int> deleteBankAccount(
  String encryptedAccountNumber,
  int accountId,
) async {
  if (!_isValidAccountId(accountId)) return 0;
  final db = await instance.database;
  return await db.update(
    TABLE_BANK_ACCOUNTS,
    {DELETED_AT: DateTime.now().toIso8601String()},
    where: "$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?",
    whereArgs: [encryptedAccountNumber, accountId],
  );
}
```

**Action**: Mark as `@Deprecated` or remove entirely after updating all call sites

**Reason**: Replaced by `toggleBankAccountActive` (for soft state) and `permanentlyDeleteBankAccount` (for hard delete)

## Repository Layer Design

### BankAccountRepository Updates

**File**: `lib/features/bank_account/repository/bank_account_repository.dart`

#### Method 1: toggleBankAccountActive

**Signature:**
```dart
Future<int> toggleBankAccountActive(
  String encryptedAccountNumber,
  bool isActive,
) async
```

**Implementation:**
```dart
Future<int> toggleBankAccountActive(
  String encryptedAccountNumber,
  bool isActive,
) async {
  final accountId = LocalStorageService.instance.accountId;
  if (accountId <= 0) return 0;
  return await db.toggleBankAccountActive(
    encryptedAccountNumber,
    isActive,
    accountId,
  );
}
```

**Pattern**: Follows existing repository pattern (get accountId from LocalStorageService, validate, delegate to db)

#### Method 2: permanentlyDeleteBankAccount

**Signature:**
```dart
Future<int> permanentlyDeleteBankAccount(
  String encryptedAccountNumber,
) async
```

**Implementation:**
```dart
Future<int> permanentlyDeleteBankAccount(
  String encryptedAccountNumber,
) async {
  final accountId = LocalStorageService.instance.accountId;
  if (accountId <= 0) return 0;
  return await db.permanentlyDeleteBankAccount(
    encryptedAccountNumber,
    accountId,
  );
}
```

**Pattern**: Follows existing repository pattern

#### Method 3: deleteBankAccount Removal

**Action**: Remove the existing `deleteBankAccount` method after updating all call sites

**Call Sites to Update**: Found via grep search for `deleteBankAccount` usage

## Controller Layer Design

### BankAccountController Updates

**File**: `lib/features/bank_account/controllers/bank_account_controller.dart`

#### State Management

**New Observable:**
```dart
final RxBool isLoadingToggle = false.obs;
```

**Purpose**: Track loading state for toggle operations separately from other operations

**Updated isBusy Getter:**
```dart
bool get isBusy =>
    isLoadingFetch.value ||
    isLoadingAdd.value ||
    isLoadingUpdate.value ||
    isLoadingDelete.value ||
    isLoadingToggle.value;  // NEW
```

#### Method 1: toggleAccountActive

**Signature:**
```dart
Future<void> toggleAccountActive(BankAccountModel account) async
```

**Implementation:**
```dart
Future<void> toggleAccountActive(BankAccountModel account) async {
  if (isLoadingToggle.value) return;
  
  try {
    isLoadingToggle.value = true;
    
    final newState = !account.isActive;
    final int rowsAffected = await _repo.toggleBankAccountActive(
      account.encryptedAccountNumber,
      newState,
    );
    
    if (rowsAffected == 0) {
      SnackbarService.showWarning(
        title: 'Not Found',
        message: 'Account not found to update.',
      );
      return;
    }
    
    // Update local state
    final int idx = bankAccounts.indexWhere(
      (e) => e.encryptedAccountNumber == account.encryptedAccountNumber,
    );
    if (idx != -1) {
      bankAccounts[idx] = account.copyWith(
        isActive: newState,
        updatedAt: DateTime.now().toIso8601String(),
      );
    }
    
    // Refresh list to apply filter
    await fetchBankAccounts(
      accountId: LocalStorageService.instance.accountId,
    );
    
    SnackbarService.showSuccess(
      title: newState ? 'Account Activated' : 'Account Deactivated',
      message: '${account.bankName} is now ${newState ? "active" : "inactive"}.',
    );
  } catch (e, stack) {
    log('[BankAccountController] toggleAccountActive: $e', stackTrace: stack);
    SnackbarService.showError(
      title: 'Toggle Failed',
      message: 'Could not update account status.',
    );
  } finally {
    isLoadingToggle.value = false;
  }
}
```

**Flow:**
1. Check if already loading (prevent concurrent toggles)
2. Flip the current `isActive` state
3. Call repository method
4. Update local observable list
5. Refresh full list (to apply active filter)
6. Show success notification
7. Handle errors with user feedback

#### Method 2: permanentlyDeleteAccount

**Signature:**
```dart
Future<void> permanentlyDeleteAccount(BankAccountModel account) async
```

**Implementation:**
```dart
Future<void> permanentlyDeleteAccount(BankAccountModel account) async {
  if (isLoadingDelete.value) return;
  
  try {
    isLoadingDelete.value = true;
    
    final int rowsAffected = await _repo.permanentlyDeleteBankAccount(
      account.encryptedAccountNumber,
    );
    
    if (rowsAffected == 0) {
      SnackbarService.showWarning(
        title: 'Not Found',
        message: 'Account not found to delete.',
      );
      return;
    }
    
    // Remove from local state
    bankAccounts.removeWhere(
      (e) => e.encryptedAccountNumber == account.encryptedAccountNumber,
    );
    
    // Clear cached reveal data
    revealedNumbers.remove(account.encryptedAccountNumber);
    accountVisibility.remove(account.encryptedAccountNumber);
    
    Get.back(); // Close any open dialogs
    
    SnackbarService.showSuccess(
      title: 'Account Deleted',
      message: '${account.bankName} and all related data permanently deleted.',
    );
  } catch (e, stack) {
    log('[BankAccountController] permanentlyDeleteAccount: $e', stackTrace: stack);
    SnackbarService.showError(
      title: 'Delete Failed',
      message: 'Could not delete account. Please try again.',
    );
  } finally {
    isLoadingDelete.value = false;
  }
}
```

**Flow:**
1. Check if already loading
2. Call repository method (executes transaction)
3. Remove from local observable list
4. Clear cached decryption data
5. Close any open dialogs
6. Show success notification
7. Handle errors with user feedback

#### Method 3: deleteBankAccount Removal

**Action**: Remove the existing `deleteBankAccount` method

**Replacement**: UI will call `permanentlyDeleteAccount` instead (after confirmation)

## UI/UX Design

### bank_accounts_screen.dart Updates

**File**: `lib/features/bank_account/views/bank_accounts_screen.dart`

#### Current Delete Button Location

**Search Pattern**: Look for `IconButton` with `Icons.delete` or similar in the bank account card

**Current Implementation** (approximate):
```dart
IconButton(
  icon: Icon(Icons.delete),
  color: Colors.red.shade400,
  onPressed: () {
    DialogService.showDeleteDialog(
      onConfirm: () {
        controller.deleteBankAccount(
          encryptedAccountNumber: account.encryptedAccountNumber,
        );
      },
    );
  },
)
```

#### Updated UI Components

**Component 1: Toggle Switch**

**Location**: Top section of bank account card (near bank name or balance)

**Implementation:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      account.isActive ? 'Active' : 'Inactive',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: account.isActive 
          ? Colors.green.shade600 
          : Colors.grey.shade600,
      ),
    ),
    Obx(() => Switch(
      value: account.isActive,
      onChanged: controller.isLoadingToggle.value 
        ? null 
        : (value) {
            controller.toggleAccountActive(account);
          },
      activeColor: Colors.green.shade600,
      inactiveThumbColor: Colors.grey.shade400,
    )),
  ],
)
```

**Features:**
- Shows "Active" or "Inactive" label
- Switch reflects current `isActive` state
- Disabled during loading (`isLoadingToggle`)
- Calls `toggleAccountActive` on change
- Green color for active, grey for inactive

**Component 2: Permanent Delete Button**

**Location**: Replace existing delete button location

**Implementation:**
```dart
IconButton(
  icon: Icon(Icons.delete_forever),
  color: Colors.red.shade700,
  tooltip: 'Delete Permanently',
  onPressed: controller.isLoadingDelete.value 
    ? null 
    : () async {
        final bool? confirmed = await DialogService.showWarningDialog(
          title: 'Permanently Delete?',
          description: 
            'This will permanently remove ${account.bankName} '
            '(****${account.lastFourDigits}) and ALL its transactions, '
            'import history, and linked data. This cannot be undone.',
          confirmText: 'Delete Permanently',
          onConfirm: () {
            Get.back(result: true);
          },
        );
        
        if (confirmed == true) {
          controller.permanentlyDeleteAccount(account);
        }
      },
)
```

**Features:**
- Uses `Icons.delete_forever` (more destructive visual)
- Red color (`Colors.red.shade700`)
- Tooltip for clarity
- Disabled during loading
- Shows confirmation dialog before proceeding
- Dialog includes bank name and last 4 digits
- Dialog warns about data loss
- Only proceeds if user confirms

#### Confirmation Dialog Specification

**Dialog Type**: `DialogService.showWarningDialog`

**Properties:**
- **Title**: "Permanently Delete?"
- **Description**: Dynamic text including:
  - Bank name
  - Last 4 digits (masked format: `****1234`)
  - Warning about data loss
  - "This cannot be undone" emphasis
- **Confirm Button**: "Delete Permanently" (red color)
- **Cancel Button**: "Cancel" (default style)
- **Icon**: Warning icon (yellow)

**Example Description:**
```
This will permanently remove HDFC Bank (****1234) and ALL its transactions, import history, and linked data. This cannot be undone.
```

## Error Handling Design

### Validation Rules

**Account ID Validation:**
- Use existing `_isValidAccountId()` helper in DatabaseHelper
- Return 0 (no rows affected) for invalid IDs
- Prevents operations on invalid accounts

**Encrypted Account Number Validation:**
- Check for empty string before operations
- Return early with 0 rows affected

### Transaction Rollback

**Permanent Delete Transaction:**
- All operations wrapped in `db.transaction()`
- Automatic rollback on any failure
- Preserves data integrity
- Error logged for debugging

### User Feedback

**Success Messages:**
- Toggle Active: "Account Activated" / "Account Deactivated"
- Permanent Delete: "Account Deleted"
- Uses `SnackbarService.showSuccess()`

**Error Messages:**
- Not Found: "Account not found to update/delete"
- Generic Error: "Could not update/delete account"
- Uses `SnackbarService.showError()` or `showWarning()`

**Loading States:**
- Toggle: `isLoadingToggle` observable
- Delete: `isLoadingDelete` observable
- UI components disabled during loading

## Data Integrity Design

### Foreign Key Relationships

**Identified Relationships:**
1. **transactions.txn_account_id** → bank_accounts.bank_account_number
2. **import_sessions.import_bank_account_number** → bank_accounts.bank_account_number
3. **tags.tag_bank_account_id** → bank_accounts.bank_account_number
4. **cash_wallet_transactions.cash_wallet_transaction_bank_account_id** → bank_accounts.bank_account_number (nullable)

**Cascading Delete Strategy:**

| Table | Action | Reason |
|-------|--------|--------|
| transactions | Soft-delete (set `deleted_at`) | Preserve for potential recovery, audit trail |
| import_sessions | Hard-delete (DELETE FROM) | No value after account removal, orphaned data |
| tags (bank-scoped) | Soft-delete (set `tag_deleted_at`) | Preserve for potential recovery |
| tags (user-scoped) | No action | Shared across accounts, must not be modified |
| cash_wallet_transactions | No action | FK is nullable, transactions remain valid |

### Query Filtering Updates

**All queries that fetch bank accounts MUST include:**
```sql
WHERE is_active = 1 AND deleted_at IS NULL
```

**Affected Queries:**
- `getBankAccounts()` - ✅ Updated
- Dashboard balance calculations - ⚠️ Review needed
- Transaction queries joining bank_accounts - ⚠️ Review needed
- Any dropdown/selection lists - ⚠️ Review needed

**Note**: The design explicitly states NOT to modify dashboard or transaction logic beyond filtering for active accounts. Verify existing queries already filter by `deleted_at IS NULL`.

## Security Considerations

### Encryption Handling

**Account Number Encryption:**
- Existing `BankAccountEncryptionService` handles encryption/decryption
- Encrypted values stored in database
- Plain text only in RAM after user action (eye icon tap)
- Toggle and delete operations use encrypted account number

**No Changes Required:**
- Encryption service remains unchanged
- Model continues to store encrypted values
- Controller continues to manage reveal state

### User Scoping

**All Operations Scoped by accountId:**
- `toggleBankAccountActive` requires accountId parameter
- `permanentlyDeleteBankAccount` requires accountId parameter
- WHERE clauses include `account_id = ?` filter
- Prevents cross-user data access

### Transaction Safety

**Database Transactions:**
- Permanent delete uses `db.transaction()`
- Atomic operations (all-or-nothing)
- Automatic rollback on failure
- Prevents partial deletes

## Testing Considerations

### Unit Test Scenarios

**DatabaseHelper Tests:**
1. `toggleBankAccountActive` with valid data → returns 1
2. `toggleBankAccountActive` with invalid accountId → returns 0
3. `toggleBankAccountActive` with non-existent account → returns 0
4. `permanentlyDeleteBankAccount` with valid data → returns 1, cascades correctly
5. `permanentlyDeleteBankAccount` with invalid accountId → returns 0
6. `permanentlyDeleteBankAccount` transaction rollback on failure
7. `getBankAccounts` filters by `is_active = 1`

**Repository Tests:**
1. `toggleBankAccountActive` delegates correctly
2. `permanentlyDeleteBankAccount` delegates correctly
3. Methods handle LocalStorageService.accountId correctly

**Controller Tests:**
1. `toggleAccountActive` updates local state
2. `toggleAccountActive` refreshes list
3. `toggleAccountActive` shows success message
4. `permanentlyDeleteAccount` removes from list
5. `permanentlyDeleteAccount` clears cached data
6. Error handling for both methods

### Integration Test Scenarios

**Toggle Flow:**
1. User taps toggle switch
2. Account becomes inactive
3. Account disappears from list (filtered out)
4. User can still see inactive accounts if filter changed (future feature)

**Permanent Delete Flow:**
1. User taps delete button
2. Confirmation dialog appears
3. User confirms
4. Account and related data deleted
5. Account removed from list
6. Success message shown

**Cascading Delete Verification:**
1. Create bank account with transactions, import sessions, tags
2. Permanently delete account
3. Verify transactions soft-deleted
4. Verify import sessions hard-deleted
5. Verify bank-scoped tags soft-deleted
6. Verify user-scoped tags untouched

## Migration Strategy

### No Migration Required

**Reason**: Fresh app with no production data

**Approach**: Direct CREATE TABLE update in `onCreate`

**Steps:**
1. Update CREATE TABLE statement in `local_db_service.dart`
2. Add `is_active INTEGER NOT NULL DEFAULT 1` column
3. No `onUpgrade` logic needed
4. Existing installs will need app reinstall (acceptable for fresh app)

### Backward Compatibility

**Not Applicable**: Fresh app, no existing users

**If Production Data Existed:**
```dart
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      'ALTER TABLE $TABLE_BANK_ACCOUNTS ADD COLUMN $IS_ACTIVE INTEGER NOT NULL DEFAULT 1'
    );
  }
}
```

## Performance Considerations

### Query Performance

**Index Recommendations:**
- Existing index on `account_id` sufficient
- `is_active` filter uses simple integer comparison (fast)
- No additional indexes needed for this feature

**Query Impact:**
- `getBankAccounts`: Added one integer comparison (negligible)
- `toggleBankAccountActive`: Single UPDATE (fast)
- `permanentlyDeleteBankAccount`: Transaction with 4 operations (acceptable for infrequent operation)

### UI Performance

**Toggle Switch:**
- Optimistic UI update (immediate visual feedback)
- Background database update
- Refresh list after success

**Permanent Delete:**
- Confirmation dialog prevents accidental triggers
- Loading state prevents double-taps
- Transaction ensures data consistency

## Rollback Plan

### If Issues Arise

**Rollback Steps:**
1. Revert CREATE TABLE to remove `is_active` column
2. Restore `deleteBankAccount` method (soft-delete via `deleted_at`)
3. Revert UI to original delete button
4. Remove new methods from repository and controller

**Data Recovery:**
- Inactive accounts: Change `is_active` back to 1
- Permanently deleted accounts: No recovery (by design)

**Testing Before Rollback:**
- Verify existing soft-delete logic still works
- Verify queries still filter by `deleted_at IS NULL`

## Future Enhancements

### Potential Features

**View Inactive Accounts:**
- Add filter toggle in UI to show/hide inactive accounts
- Modify `getBankAccounts` to accept optional `includeInactive` parameter
- Allow reactivation of inactive accounts

**Audit Trail:**
- Log toggle events (who, when, old state, new state)
- Log permanent delete events
- Store in separate audit table

**Soft Delete for Permanent Delete:**
- Instead of hard delete, use `deleted_at` for bank_accounts too
- Add "purge" operation for true hard delete
- Allows recovery window

**Bulk Operations:**
- Toggle multiple accounts at once
- Bulk permanent delete with confirmation

## Dependencies

### External Packages
- `sqflite`: ^2.0.0 (existing)
- `get`: ^4.6.0 (existing)
- `crypto`: ^3.0.0 (existing, for encryption)

### Internal Dependencies
- `LocalStorageService`: For accountId retrieval
- `SnackbarService`: For user notifications
- `DialogService`: For confirmation dialogs
- `BankAccountEncryptionService`: For account number encryption

### No New Dependencies Required

## Conclusion

This design provides a complete technical specification for implementing the Bank Account Activate/Deactivate feature. The implementation follows existing architectural patterns, maintains data integrity through transactions, and provides clear user feedback through the UI. The design is minimal, focused, and avoids modifying unrelated features (cash wallet, virtual entries, dashboard logic beyond filtering).

**Key Design Principles:**
1. **Minimal Changes**: Only modify files directly related to bank account management
2. **Existing Patterns**: Follow established code style and architecture
3. **Data Integrity**: Use transactions for cascading operations
4. **User Safety**: Confirmation dialogs for destructive actions
5. **Clear Feedback**: Loading states and success/error messages
6. **Security**: Maintain encryption and user scoping

**Implementation Order:**
1. Database schema (constants, CREATE TABLE)
2. Model updates (BankAccountModel)
3. Data access layer (DatabaseHelper methods)
4. Repository layer (BankAccountRepository methods)
5. Controller layer (BankAccountController methods)
6. UI layer (bank_accounts_screen.dart updates)
7. Testing and verification
