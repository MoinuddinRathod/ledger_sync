# Requirements Document

## Introduction

This document specifies the requirements for replacing the current bank account delete functionality with a dual-state system: activate/deactivate (soft state change) and permanent delete (hard delete with cascading cleanup). The feature enables users to temporarily hide bank accounts from view while preserving all data, and separately provides a destructive permanent delete option with proper data cleanup across related tables.

## Glossary

- **Bank_Account**: A user's bank account record stored in the bank_accounts table
- **Active_State**: A bank account with is_active = 1, visible in all queries and UI
- **Inactive_State**: A bank account with is_active = 0, hidden from queries but data preserved
- **Soft_Delete**: Setting deleted_at timestamp to mark records as deleted without removing data
- **Hard_Delete**: Physically removing records from database tables
- **Transaction**: A bank transaction record linked to a bank account via foreign key
- **Import_Session**: A record tracking CSV import operations for a bank account
- **Tag**: A categorization label that can be scoped to a specific bank account or user-level
- **Bank_Scoped_Tag**: A tag with tag_bank_account_id set to a specific bank account
- **User_Scoped_Tag**: A tag with tag_user_id set but tag_bank_account_id is NULL
- **Database_Transaction**: An atomic database operation ensuring all-or-nothing execution
- **Cascading_Cleanup**: The process of deleting or soft-deleting related records when a parent record is deleted

## Requirements

### Requirement 1: Database Schema Extension

**User Story:** As a developer, I want to add an is_active column to the bank_accounts table, so that I can track whether accounts are active or inactive without losing data.

#### Acceptance Criteria

1. THE System SHALL add an is_active column to the bank_accounts table with type INTEGER NOT NULL DEFAULT 1
2. WHEN is_active equals 1, THE Bank_Account SHALL be considered active and visible
3. WHEN is_active equals 0, THE Bank_Account SHALL be considered inactive and hidden
4. THE System SHALL preserve the existing deleted_at column for permanent delete operations
5. THE System SHALL update the CREATE TABLE statement directly without requiring a migration

### Requirement 2: Activate/Deactivate Toggle

**User Story:** As a user, I want to toggle my bank accounts between active and inactive states, so that I can temporarily hide accounts without losing transaction history.

#### Acceptance Criteria

1. WHEN a user toggles a Bank_Account to inactive, THE System SHALL set is_active to 0 and preserve all related data
2. WHEN a user toggles a Bank_Account to active, THE System SHALL set is_active to 1 and restore visibility
3. WHEN toggling active state, THE System SHALL NOT modify deleted_at, transactions, import_sessions, or tags
4. WHEN toggling active state, THE System SHALL update the updated_at timestamp
5. THE System SHALL complete the toggle operation within a single database update statement

### Requirement 3: Query Filtering for Active Accounts

**User Story:** As a user, I want to see only active bank accounts in my account list, so that inactive accounts don't clutter my view.

#### Acceptance Criteria

1. WHEN querying bank accounts, THE System SHALL filter WHERE is_active = 1 AND deleted_at IS NULL
2. WHEN calculating dashboard balances, THE System SHALL include only active bank accounts
3. WHEN displaying recent transactions, THE System SHALL include only transactions from active bank accounts
4. WHEN listing bank accounts for selection, THE System SHALL show only active accounts
5. THE System SHALL exclude inactive accounts from all user-facing queries

### Requirement 4: Permanent Delete with Cascading Cleanup

**User Story:** As a user, I want to permanently delete a bank account and all its related data, so that I can completely remove accounts I no longer need.

#### Acceptance Criteria

1. WHEN a user permanently deletes a Bank_Account, THE System SHALL soft-delete all linked transactions by setting deleted_at
2. WHEN a user permanently deletes a Bank_Account, THE System SHALL hard-delete all linked import_sessions
3. WHEN a user permanently deletes a Bank_Account, THE System SHALL soft-delete all Bank_Scoped_Tags
4. WHEN a user permanently deletes a Bank_Account, THE System SHALL NOT modify User_Scoped_Tags
5. WHEN a user permanently deletes a Bank_Account, THE System SHALL hard-delete the bank_account row
6. THE System SHALL execute all permanent delete operations within a single Database_Transaction
7. IF any operation in the permanent delete fails, THEN THE System SHALL rollback all changes

### Requirement 5: Data Access Layer Methods

**User Story:** As a developer, I want clear database methods for activate/deactivate and permanent delete, so that the implementation is maintainable and correct.

#### Acceptance Criteria

1. THE System SHALL provide a toggleBankAccountActive method accepting accountNumber and isActive parameters
2. THE System SHALL provide a permanentlyDeleteBankAccount method accepting accountNumber parameter
3. THE System SHALL remove the existing deleteBankAccount method that sets deleted_at
4. WHEN toggleBankAccountActive is called, THE System SHALL update only the is_active and updated_at columns
5. WHEN permanentlyDeleteBankAccount is called, THE System SHALL execute Cascading_Cleanup within a Database_Transaction
6. THE System SHALL validate accountId is greater than 0 before executing any database operations
7. THE System SHALL return the number of affected rows for update operations

### Requirement 6: UI Toggle Switch

**User Story:** As a user, I want a toggle switch on each bank account card showing active/inactive status, so that I can quickly change account visibility.

#### Acceptance Criteria

1. WHEN displaying a Bank_Account card, THE System SHALL show a toggle switch indicating current active state
2. WHEN the toggle switch is in the on position, THE System SHALL display "Active" label
3. WHEN the toggle switch is in the off position, THE System SHALL display "Inactive" label
4. WHEN a user taps the toggle switch, THE System SHALL call toggleBankAccountActive with the new state
5. WHEN the toggle operation completes, THE System SHALL refresh the bank account list
6. THE System SHALL position the toggle switch in the top section of the bank account card

### Requirement 7: Permanent Delete Button

**User Story:** As a user, I want a clearly marked permanent delete button, so that I understand this action is destructive and irreversible.

#### Acceptance Criteria

1. THE System SHALL replace the existing delete button with a "Delete Permanently" button
2. THE System SHALL style the permanent delete button with red color to indicate destructive action
3. WHEN a user taps the permanent delete button, THE System SHALL display a confirmation dialog before proceeding
4. THE System SHALL position the permanent delete button separately from the toggle switch
5. THE System SHALL use a trash/delete icon for the permanent delete button

### Requirement 8: Permanent Delete Confirmation Dialog

**User Story:** As a user, I want a confirmation dialog before permanently deleting an account, so that I don't accidentally lose important data.

#### Acceptance Criteria

1. WHEN a user initiates permanent delete, THE System SHALL display a confirmation dialog with title "Permanently Delete?"
2. THE System SHALL display the bank name and last four digits in the confirmation dialog body
3. THE System SHALL include warning text stating "This will permanently delete the account and all related transactions, import sessions, and bank-scoped tags. This action cannot be undone."
4. THE System SHALL provide a "Delete Permanently" button in red color for confirmation
5. THE System SHALL provide a "Cancel" button to abort the operation
6. WHEN the user confirms, THE System SHALL call permanentlyDeleteBankAccount
7. WHEN the user cancels, THE System SHALL close the dialog without any database changes

### Requirement 9: Transaction Soft Delete Behavior

**User Story:** As a user, I want transactions to be soft-deleted when I permanently delete a bank account, so that the data can potentially be recovered if needed.

#### Acceptance Criteria

1. WHEN permanently deleting a Bank_Account, THE System SHALL set deleted_at timestamp for all transactions WHERE txn_account_id equals the bank account number
2. THE System SHALL preserve all transaction data including amounts, dates, narrations, and tag associations
3. THE System SHALL NOT modify transactions belonging to other bank accounts
4. THE System SHALL execute transaction soft-delete within the permanent delete Database_Transaction
5. THE System SHALL update deleted_at to the current ISO 8601 timestamp

### Requirement 10: Import Session Hard Delete Behavior

**User Story:** As a developer, I want import sessions to be hard-deleted when permanently deleting a bank account, so that orphaned import records don't remain in the database.

#### Acceptance Criteria

1. WHEN permanently deleting a Bank_Account, THE System SHALL hard-delete all import_sessions WHERE import_bank_account_number equals the bank account number
2. THE System SHALL NOT modify import_sessions belonging to other bank accounts
3. THE System SHALL execute import session deletion within the permanent delete Database_Transaction
4. THE System SHALL use DELETE FROM statement to physically remove import session records

### Requirement 11: Bank-Scoped Tag Soft Delete Behavior

**User Story:** As a user, I want bank-specific tags to be soft-deleted when I permanently delete a bank account, so that account-specific categorizations are removed but can be recovered.

#### Acceptance Criteria

1. WHEN permanently deleting a Bank_Account, THE System SHALL set deleted_at timestamp for all tags WHERE tag_bank_account_id equals the bank account number
2. THE System SHALL NOT modify User_Scoped_Tags where tag_bank_account_id IS NULL
3. THE System SHALL preserve all tag data including tag names, keywords, and priorities
4. THE System SHALL execute tag soft-delete within the permanent delete Database_Transaction
5. THE System SHALL update deleted_at to the current ISO 8601 timestamp

### Requirement 12: Preservation of Unrelated Features

**User Story:** As a developer, I want to ensure that unrelated features remain unchanged, so that the activate/deactivate implementation doesn't introduce regressions.

#### Acceptance Criteria

1. THE System SHALL NOT modify cash wallet logic or queries
2. THE System SHALL NOT modify virtual entries logic or queries
3. THE System SHALL NOT modify dashboard balance calculation logic beyond filtering for is_active
4. THE System SHALL NOT modify transaction display logic beyond filtering for active bank accounts
5. THE System SHALL NOT modify tag management logic beyond soft-deleting bank-scoped tags in permanent delete
6. THE System SHALL NOT modify any screens other than bank_accounts_screen.dart

### Requirement 13: Error Handling and Validation

**User Story:** As a user, I want proper error handling during activate/deactivate and permanent delete operations, so that I'm informed if something goes wrong.

#### Acceptance Criteria

1. WHEN toggleBankAccountActive receives an invalid accountId, THE System SHALL return 0 without executing database operations
2. WHEN permanentlyDeleteBankAccount receives an invalid accountId, THE System SHALL return 0 without executing database operations
3. IF the permanent delete Database_Transaction fails, THEN THE System SHALL rollback all changes and log the error
4. WHEN a database operation fails, THE System SHALL display an error message to the user
5. WHEN a toggle operation succeeds, THE System SHALL display a success message or visual feedback
6. WHEN a permanent delete succeeds, THE System SHALL display a success message and refresh the account list

### Requirement 14: State Management Integration

**User Story:** As a developer, I want the GetX controller to properly manage activate/deactivate and permanent delete operations, so that the UI stays synchronized with the database.

#### Acceptance Criteria

1. THE Bank_Account_Controller SHALL provide a toggleBankAccountActive method accepting accountNumber and isActive parameters
2. THE Bank_Account_Controller SHALL provide a permanentlyDeleteBankAccount method accepting accountNumber parameter
3. WHEN toggleBankAccountActive is called, THE Controller SHALL update the database and refresh the observable bank account list
4. WHEN permanentlyDeleteBankAccount is called, THE Controller SHALL execute Cascading_Cleanup and refresh the observable bank account list
5. THE Controller SHALL handle loading states during database operations
6. THE Controller SHALL display appropriate success or error messages using GetX snackbar
