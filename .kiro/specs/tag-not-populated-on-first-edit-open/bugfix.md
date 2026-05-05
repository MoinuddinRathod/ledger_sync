# Bugfix Requirements Document

## Introduction

When opening an existing transaction for edit from CashWalletScreen, the selected tag is not populated in the tag field on the first open. The tag field displays "Select a tag" instead of the actual tag value. If the screen is closed and reopened, the tag appears correctly. This is a timing/initialization issue where the tag data is not available when the edit form is being initialized.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN opening an existing transaction for edit from CashWalletScreen on first open THEN the tag field displays "Select a tag" instead of the actual tag name

1.2 WHEN the TagsController is still loading or has empty tags list THEN the tag lookup in CashWalletScreen.onEdit() returns null even though the tag exists in the database

1.3 WHEN AddEditTransactionController._initFormState() uses Future.microtask() to find the full tag THEN the tag may not be found because TagsController.tags is still empty or loading

### Expected Behavior (Correct)

2.1 WHEN opening an existing transaction for edit from CashWalletScreen on first open THEN the tag field SHALL display the actual tag name correctly

2.2 WHEN the TagsController is loading or has empty tags list THEN the system SHALL wait for tags to be fully loaded before attempting tag lookup

2.3 WHEN AddEditTransactionController._initFormState() initializes the tag THEN the system SHALL ensure TagsController has loaded tags before attempting to find the full tag object

### Unchanged Behavior (Regression Prevention)

3.1 WHEN adding a new transaction (not editing) THEN the system SHALL CONTINUE TO work normally without requiring tag pre-population

3.2 WHEN reopening the edit screen after closing it THEN the system SHALL CONTINUE TO display the tag correctly (this already works)

3.3 WHEN the tag does not exist in TagsController THEN the system SHALL CONTINUE TO use the fallback TagModel with the tag name from the transaction

3.4 WHEN TagsController is not registered in GetX THEN the system SHALL CONTINUE TO handle the exception gracefully without crashing
