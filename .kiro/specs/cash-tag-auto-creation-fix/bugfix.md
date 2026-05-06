# Bugfix Requirements Document

## Introduction

This bugfix restores the automatic Cash Tag creation logic that was removed or broken during recent user-data isolation changes. The system currently creates a Cash Wallet for new users but fails to create the corresponding Cash Tag, which is required for the dual-effect cash transaction logic to function properly.

The Cash Tag is a special system tag with predefined keywords (e.g., "atm withdrawal", "cash deposit") that enables automatic detection and dual-effect processing of cash-related bank transactions. Without this tag, the CashTagService cannot initialize properly, and cash transactions imported from bank statements will not automatically update the cash wallet balance.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a new user account is created/registered THEN the system creates a Cash Wallet but does NOT create a Cash Tag for that user

1.2 WHEN the CashTagService attempts to initialize after user login THEN it fails to find a Cash Tag and logs "Failed to initialize Cash tag"

1.3 WHEN bank transactions containing cash-related keywords are imported THEN the dual-effect logic does not apply because the Cash Tag does not exist

1.4 WHEN a user navigates to the Cash Wallet screen THEN the Cash Wallet exists but has no associated Cash Tag for automatic transaction categorization

### Expected Behavior (Correct)

2.1 WHEN a new user account is created/registered THEN the system SHALL create both a Cash Wallet AND a Cash Tag for that user

2.2 WHEN the CashTagService attempts to initialize after user login THEN it SHALL successfully find the Cash Tag and initialize with a valid tag ID

2.3 WHEN bank transactions containing cash-related keywords are imported THEN the dual-effect logic SHALL apply correctly, updating both the bank account and cash wallet balances

2.4 WHEN a user navigates to the Cash Wallet screen THEN both the Cash Wallet and Cash Tag SHALL exist and be properly linked to the authenticated user

2.5 WHEN the automatic Cash Tag creation runs THEN it SHALL check if a Cash Tag already exists for the user to prevent duplicate creation

2.6 WHEN the automatic Cash Tag creation runs THEN it SHALL use the same tag structure as `ensureCashTagExists()` method (name: "Cash", priority: 0, user-scoped, with predefined cash-related keywords)

### Unchanged Behavior (Regression Prevention)

3.1 WHEN an existing user logs in THEN the system SHALL CONTINUE TO use their existing Cash Tag without creating duplicates

3.2 WHEN user data isolation queries execute THEN the system SHALL CONTINUE TO filter all cash wallet and tag data by the authenticated user's account ID

3.3 WHEN a user views their Cash Wallet transactions THEN the system SHALL CONTINUE TO show only transactions belonging to that user

3.4 WHEN multiple users exist in the system THEN each user SHALL CONTINUE TO have their own isolated Cash Wallet and Cash Tag

3.5 WHEN the CashTagService.ensureCashTagExists() method is called THEN it SHALL CONTINUE TO check for existing tags before creating new ones

3.6 WHEN cash wallet transactions are created manually THEN the system SHALL CONTINUE TO require tag selection and enforce user-scoped tag filtering
