# Cash Wallet Dual-Effect Fix Design

## Overview

This design addresses the silent failure of two critical features in the ReviewTransactionsController: the cash wallet dual-effect logic (Feature A) and virtual entry auto-matching (Feature B). Both features are implemented and called during transaction import, but they fail silently due to incorrect database column names and missing transaction context. The fix ensures that transactions tagged with "Cash" automatically create corresponding cash wallet entries, and that virtual entries are matched with imported transactions based on keyword matching.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug - when `_applyCashTagDualEffect()` or `_runVirtualEntryMatching()` are called but produce no observable effect
- **Property (P)**: The desired behavior - cash wallet transactions are created for Cash-tagged imports, and virtual entries are matched with imported transactions
- **Preservation**: Existing transaction import, balance computation, and UI refresh logic that must remain unchanged by the fix
- **CashTagService**: The service in `lib/core/service/cash_tag_service.dart` that manages the global "Cash" tag and applies dual-effect logic
- **VirtualEntriesController**: The controller in `lib/features/virtual_entries/controller/virtual_entries_controller.dart` that manages virtual entry matching
- **ReviewTransactionsController**: The controller in `lib/features/home/controllers/review_transactions_controller.dart` that orchestrates transaction import
- **Dual-Effect Logic**: When a bank transaction is tagged with "Cash", a corresponding cash wallet transaction is automatically created (DR → Cash Withdrawn, CR → Cash Deposited)

## Bug Details

### Bug Condition

The bug manifests when transactions are imported via `ReviewTransactionsController.saveTransactions()`. The method calls `_applyCashTagDualEffect()` and `_runVirtualEntryMatching()`, but both features fail silently with no observable effect on the cash wallet or virtual entries.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type TransactionImportContext
  OUTPUT: boolean
  
  RETURN input.hasCashTaggedTransactions OR input.hasPendingVirtualEntries
         AND (_applyCashTagDualEffect() is called OR _runVirtualEntryMatching() is called)
         AND (cashWalletBalance is unchanged OR virtualEntryStatus is unchanged)
END FUNCTION
```

### Examples

- **Example 1**: User imports a bank statement with an ATM withdrawal transaction auto-tagged as "Cash" (DR, ₹5000). Expected: Cash wallet balance increases by ₹5000 and a "Cash Withdrawn From Bank" transaction is created. Actual: Cash wallet remains unchanged.

- **Example 2**: User imports a bank statement with a cash deposit transaction tagged as "Cash" (CR, ₹2000). Expected: Cash wallet balance decreases by ₹2000 and a "Cash Deposited To Bank" transaction is created. Actual: Cash wallet remains unchanged.

- **Example 3**: User has a pending virtual entry "Receivable from John" with tag "Salary" (keywords: ["salary", "payment"]). User imports a transaction with narration "Salary payment from John" tagged as "Salary". Expected: Virtual entry is matched and appears in `matchedEntries` list. Actual: Virtual entry remains in "pending" status with no match.

- **Edge Case**: User imports transactions when CashTagService is not initialized. Expected: System logs the condition and skips dual-effect logic gracefully. Actual: System may crash or fail silently depending on implementation.

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Transaction insertion via `addBulkTransactions()` must continue to work exactly as before
- Bank account balance recomputation via `recomputeAndSave()` must remain unchanged
- Continuity checks, overlap warnings, and reconciliation checks must continue to function
- UI refresh logic for DashboardController and TagsController must remain unchanged
- Navigation flow after import completion must remain unchanged
- Manual cash wallet transaction creation must continue to work independently
- Manual virtual entry creation and deletion must continue to work independently

**Scope:**
All inputs that do NOT involve Cash-tagged transactions or pending virtual entries should be completely unaffected by this fix. This includes:
- Transactions tagged with non-Cash tags
- Imports when no virtual entries exist
- Manual transaction creation (not via import)
- Cash wallet operations performed outside the import flow

## Hypothesized Root Cause

Based on the bug description and code analysis, the most likely issues are:

1. **Incorrect Column Names in CashTagService**: The `applyDualEffect()` method uses lowercase column names like `'account_id'`, `'transaction_type'`, `'tag_id'`, etc., but the database schema expects uppercase constant names like `ACCOUNT_ID`, `CASH_WALLET_TRANSACTION_TYPE`, `CASH_WALLET_TRANSACTION_TAG_ID`, etc. This causes the insert to fail silently because SQLite doesn't recognize the columns.

2. **Missing Transaction Context**: The `db.transaction()` call in `CashTagService.applyDualEffect()` creates a new transaction context, but then calls `_db.getCashWallet()`, `_db.insertCashWallet()`, `_db.updateCashWalletBalance()`, and `_db.insertCashWalletTransaction()` which all call `await instance.database` internally, creating a new database connection outside the transaction context. This breaks atomicity and may cause deadlocks or silent failures.

3. **Incorrect Amount Column Name**: The cash wallet transaction insert uses `'amount'` but the constant is `CASH_WALLET_TRANSACTION_AMOUNT` which maps to `"amount"`. However, the schema uses `$AMOUNT` which is a different constant. Need to verify the correct column name.

4. **Virtual Entry Matching Logic**: The `_runVirtualEntryMatching()` method may be working correctly but the results are not persisted or displayed because the `matchedEntries` list is only stored in memory and not shown to the user after import completes.

## Correctness Properties

Property 1: Bug Condition - Cash Wallet Dual-Effect

_For any_ transaction import where one or more transactions are tagged with the Cash tag (isCashTag returns true), the fixed `_applyCashTagDualEffect()` function SHALL create corresponding cash wallet transactions with correct types (DR → "Cash Withdrawn From Bank", CR → "Cash Deposited To Bank") and update the cash wallet balance accordingly (DR increases balance, CR decreases balance clamped to zero).

**Validates: Requirements 2.1, 2.2**

Property 2: Bug Condition - Virtual Entry Matching

_For any_ transaction import where pending virtual entries exist with tags that have matching keywords in imported transaction narrations, the fixed `_runVirtualEntryMatching()` function SHALL identify these matches, populate the `matchedEntries` list, and prefer transactions with the closest amount match.

**Validates: Requirements 2.3, 2.4**

Property 3: Preservation - Non-Cash Transaction Behavior

_For any_ transaction import where NO transactions are tagged with Cash (isCashTag returns false for all transactions), the fixed code SHALL produce exactly the same behavior as the original code, preserving all existing transaction insertion, balance computation, and UI refresh logic.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

Property 4: Preservation - Service Initialization Handling

_For any_ transaction import where CashTagService is not initialized or VirtualEntriesController is not registered, the fixed code SHALL skip the respective feature gracefully without crashing, logging the condition for debugging.

**Validates: Requirements 2.5, 2.6, 2.7**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `lib/core/service/cash_tag_service.dart`

**Function**: `applyDualEffect()`

**Specific Changes**:

1. **Fix Column Names**: Replace all lowercase column names with the correct uppercase constants from `app_constants.dart`:
   - `'account_id'` → `ACCOUNT_ID`
   - `'transaction_type'` → `CASH_WALLET_TRANSACTION_TYPE`
   - `'tag_id'` → `CASH_WALLET_TRANSACTION_TAG_ID`
   - `'amount'` → `AMOUNT` (verify this is correct, not `CASH_WALLET_TRANSACTION_AMOUNT`)
   - `'transaction_note'` → `TRANSACTION_NOTE`
   - `'date_added'` → `DATE_ADDED`
   - `'created_at'` → `CREATED_AT`
   - `'updated_at'` → `UPDATED_AT`
   - `'deleted_at'` → `DELETED_AT`
   - `'current_balance'` → `CASH_WALLET_CURRENT_BALANCE`

2. **Fix Transaction Context**: Remove the `db.transaction()` wrapper and execute operations sequentially without creating a new transaction context. The individual database methods already handle their own transactions if needed.

3. **Add Import Statements**: Ensure all required constants are imported from `app_constants.dart` at the top of the file.

4. **Improve Error Logging**: Add more detailed error logging to capture the exact failure point (e.g., "Failed to get cash wallet", "Failed to insert cash wallet transaction", etc.).

5. **Add Null Safety**: Add null checks for `cashWallet` result before accessing `current_balance` to prevent null pointer exceptions.

**File**: `lib/features/home/controllers/review_transactions_controller.dart`

**Function**: `_applyCashTagDualEffect()`

**Specific Changes**:

1. **Add Error Logging**: Wrap the `applyDualEffect()` call in a try-catch block and log any errors with the transaction details for debugging.

2. **Add Success Logging**: Log the number of cash transactions processed successfully.

**File**: `lib/features/virtual_entries/controller/virtual_entries_controller.dart`

**Function**: `runAutoMatching()`

**Specific Changes**:

1. **Verify Implementation**: The implementation looks correct based on code review. The main issue may be that the `matchedEntries` list is not displayed to the user after import. This is a UI issue, not a logic issue.

2. **Add Logging**: Add more detailed logging to show how many matches were found and what the match criteria were.

3. **Persist Matches**: Consider persisting the matches to the database or displaying them in a dialog after import completes, so the user can review and confirm them.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write tests that import transactions tagged with "Cash" and verify that cash wallet transactions are created. Run these tests on the UNFIXED code to observe failures and understand the root cause. Also test virtual entry matching with pending entries and imported transactions.

**Test Cases**:
1. **Cash Withdrawal Test**: Import a DR transaction tagged as "Cash" (will fail on unfixed code - no cash wallet transaction created)
2. **Cash Deposit Test**: Import a CR transaction tagged as "Cash" (will fail on unfixed code - no cash wallet transaction created)
3. **Virtual Entry Match Test**: Import a transaction with narration matching a pending virtual entry's tag keywords (will fail on unfixed code - no match created)
4. **Service Not Initialized Test**: Import Cash-tagged transactions when CashTagService is not initialized (may crash or fail silently on unfixed code)

**Expected Counterexamples**:
- Cash wallet balance remains unchanged after importing Cash-tagged transactions
- No cash wallet transactions are created in the database
- Virtual entries remain in "pending" status after importing matching transactions
- Possible causes: incorrect column names, broken transaction context, missing error handling

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := saveTransactions_fixed(input)
  ASSERT expectedBehavior(result)
END FOR
```

**Expected Behavior:**
- Cash wallet balance is updated correctly (DR increases, CR decreases)
- Cash wallet transactions are created with correct types and amounts
- Virtual entries are matched and appear in `matchedEntries` list
- No crashes or silent failures occur

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT saveTransactions_original(input) = saveTransactions_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain
- It catches edge cases that manual unit tests might miss
- It provides strong guarantees that behavior is unchanged for all non-buggy inputs

**Test Plan**: Observe behavior on UNFIXED code first for non-Cash transactions and imports without virtual entries, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Non-Cash Transaction Preservation**: Observe that transactions tagged with non-Cash tags are imported correctly on unfixed code, then write test to verify this continues after fix
2. **Balance Computation Preservation**: Observe that bank account balances are computed correctly on unfixed code, then write test to verify this continues after fix
3. **UI Refresh Preservation**: Observe that DashboardController and TagsController are refreshed correctly on unfixed code, then write test to verify this continues after fix

### Unit Tests

- Test `CashTagService.applyDualEffect()` with DR and CR transactions
- Test `CashTagService.applyDualEffect()` when cash wallet doesn't exist (should create one)
- Test `CashTagService.applyDualEffect()` when CashTagService is not initialized (should skip gracefully)
- Test `VirtualEntriesController.runAutoMatching()` with matching and non-matching transactions
- Test `VirtualEntriesController.runAutoMatching()` with multiple matches (should prefer closest amount)
- Test `ReviewTransactionsController._applyCashTagDualEffect()` with mixed Cash and non-Cash transactions

### Property-Based Tests

- Generate random transaction imports with varying percentages of Cash-tagged transactions and verify dual-effect logic works correctly
- Generate random virtual entries and transaction imports and verify matching logic finds all valid matches
- Generate random transaction imports without Cash tags and verify behavior is unchanged from original implementation

### Integration Tests

- Test full import flow with Cash-tagged transactions and verify cash wallet is updated
- Test full import flow with pending virtual entries and verify matches are found
- Test full import flow with both features enabled and verify both work correctly
- Test import flow when services are not initialized and verify graceful degradation
