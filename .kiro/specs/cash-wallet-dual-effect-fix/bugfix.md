# Bugfix Requirements Document

## Introduction

This document defines the requirements for fixing the cash wallet dual-effect and virtual entry matching features in the ReviewTransactionsController. When transactions tagged with "Cash" are imported, the system should automatically create corresponding entries in the cash wallet (dual-effect logic). Additionally, virtual entries should be matched with imported transactions based on keywords and amounts. Currently, both features are silently failing - the methods are called but produce no observable effect.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN transactions tagged with "Cash" are imported via `saveTransactions()` THEN the system calls `_applyCashTagDualEffect()` but the cash wallet balance remains unchanged

1.2 WHEN `_applyCashTagDualEffect()` executes THEN the system does not create corresponding cash wallet transactions

1.3 WHEN transactions are imported via `saveTransactions()` THEN the system calls `_runVirtualEntryMatching()` but virtual entries remain in "pending" status

1.4 WHEN `_runVirtualEntryMatching()` executes THEN the system does not match virtual entries with imported transactions based on keywords

1.5 WHEN the dual-effect or matching logic fails THEN the system does not display any error messages to the user (silent failure)

### Expected Behavior (Correct)

2.1 WHEN a transaction tagged with "Cash" and type "DR" (debit/withdrawal) is imported THEN the system SHALL create a cash wallet transaction of type "Cash Withdrawn From Bank" and increase the cash wallet balance by the transaction amount

2.2 WHEN a transaction tagged with "Cash" and type "CR" (credit/deposit) is imported THEN the system SHALL create a cash wallet transaction of type "Cash Deposited To Bank" and decrease the cash wallet balance by the transaction amount (clamped to zero minimum)

2.3 WHEN virtual entries exist with tags that have matching keywords in imported transaction narrations THEN the system SHALL identify these matches and populate the `matchedEntries` list in VirtualEntriesController

2.4 WHEN virtual entry matching finds a match THEN the system SHALL prefer the transaction with the closest amount match to the virtual entry amount

2.5 WHEN the CashTagService is not initialized or not registered THEN the system SHALL log the condition and skip dual-effect logic gracefully without crashing

2.6 WHEN the VirtualEntriesController is not registered THEN the system SHALL skip virtual entry matching gracefully without crashing

2.7 WHEN dual-effect or matching logic encounters an error THEN the system SHALL log the error with sufficient detail for debugging

### Unchanged Behavior (Regression Prevention)

3.1 WHEN transactions NOT tagged with "Cash" are imported THEN the system SHALL CONTINUE TO save them to the bank account without affecting the cash wallet

3.2 WHEN transactions are imported successfully THEN the system SHALL CONTINUE TO update bank account balances correctly using `recomputeAndSave()`

3.3 WHEN transactions are imported THEN the system SHALL CONTINUE TO perform continuity checks, overlap warnings, and reconciliation checks as currently implemented

3.4 WHEN the import completes THEN the system SHALL CONTINUE TO refresh the DashboardController and TagsController

3.5 WHEN transactions are imported THEN the system SHALL CONTINUE TO display appropriate success, warning, or error messages to the user

3.6 WHEN virtual entries are manually created or deleted THEN the system SHALL CONTINUE TO function correctly independent of the auto-matching feature

3.7 WHEN cash wallet transactions are manually created THEN the system SHALL CONTINUE TO update the cash wallet balance correctly
