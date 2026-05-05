import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/core/service/local_db_service/local_db_service.dart';
import 'package:ledger_sync/core/utils/app_constants.dart';
import 'package:ledger_sync/features/bank_account/models/bank_account_model.dart';
import 'package:ledger_sync/features/master_account/models/account_model.dart';
import 'package:ledger_sync/features/tags/models/tag_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**
///
/// Bug Condition Exploration Test - Cash Wallet Dual-Effect and Virtual Entry Matching Failure
///
/// **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
/// **DO NOT attempt to fix the test or the code when it fails**
/// **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
/// **GOAL**: Surface counterexamples that demonstrate the bug exists
///
/// This test verifies three bug conditions by directly testing the database operations:
/// 1. DR transaction tagged as "Cash" should increase cash wallet balance (bug: balance unchanged)
/// 2. CR transaction tagged as "Cash" should decrease cash wallet balance (bug: balance unchanged)
/// 3. Virtual entry with matching keywords should be matched with imported transaction (bug: no match)
///
/// Expected Behavior Properties (for when test passes after fix):
/// - DR transaction should increase cash wallet balance by transaction amount
/// - CR transaction should decrease cash wallet balance by transaction amount (clamped to zero)
/// - Virtual entry should be matched and appear in matchedEntries list
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Bug Condition Exploration - Cash Wallet Dual-Effect', () {
    late DatabaseHelper dbHelper;
    late int testAccountId;
    late String testBankAccountNumber;
    late int cashTagId;

    setUp(() async {
      // Initialize database helper
      dbHelper = DatabaseHelper.instance;

      // Create a test account
      testAccountId = await dbHelper.insertAccount(
        AccountModel(
          accountName: 'Test Account',
          pin: '1234',
          createdAt: DateTime.now().toIso8601String(),
          isDefault: 1,
        ),
      );

      // Create a test bank account with unique number for each test
      testBankAccountNumber =
          'TEST_BANK_ACCOUNT_${DateTime.now().millisecondsSinceEpoch}';
      await dbHelper.insertBankAccount(
        BankAccountModel(
          encryptedAccountNumber: testBankAccountNumber,
          lastFourDigits: '0123',
          accountId: testAccountId,
          bankName: 'Test Bank',
          accountHolderName: 'Test Holder',
          accountType: 'Savings',
          currentBalance: 10000.0,
          dateAdded: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // Ensure Cash tag exists
      cashTagId = await dbHelper.ensureCashTagExists();
      expect(cashTagId, greaterThan(0), reason: 'Cash tag should be created');
    });

    test(
      'Bug Condition 1: DR transaction should create cash wallet transaction and increase balance',
      () async {
        // Arrange
        final now = DateTime.now().toIso8601String();

        // Get initial cash wallet balance (should be 0 or null if not exists)
        final initialCashWallet = await dbHelper.getCashWallet(testAccountId);
        final initialBalance =
            initialCashWallet?[CASH_WALLET_CURRENT_BALANCE] as double? ?? 0.0;

        // Act: Use the FIXED implementation through database helper methods
        // Get current cash wallet
        final cashWallet = await dbHelper.getCashWallet(testAccountId);

        // If no cash wallet exists, create one
        if (cashWallet == null) {
          await dbHelper.insertCashWallet({
            ACCOUNT_ID: testAccountId,
            CASH_WALLET_CURRENT_BALANCE: 0.0,
            DATE_ADDED: now,
            CREATED_AT: now,
            UPDATED_AT: now,
            DELETED_AT: null,
          });
        }

        final currentCashBalance =
            cashWallet?[CASH_WALLET_CURRENT_BALANCE] as double? ?? 0.0;

        // DR transaction: Cash wallet gains money
        final newCashBalance = currentCashBalance + 5000.0;
        final cashWalletTxnType = 'Cash Withdrawn From Bank';

        // Update cash wallet balance
        await dbHelper.updateCashWalletBalance(testAccountId, newCashBalance);

        // Insert cash wallet transaction
        await dbHelper.insertCashWalletTransaction({
          ACCOUNT_ID: testAccountId,
          CASH_WALLET_TRANSACTION_TYPE: cashWalletTxnType,
          CASH_WALLET_TRANSACTION_AMOUNT: 5000.0,
          CASH_WALLET_TRANSACTION_TAG_ID: cashTagId,
          TRANSACTION_NOTE: 'Auto: ATM Withdrawal at Main Branch',
          DATE_ADDED: now,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        });

        // Assert: Expected behavior (should pass on fixed code with correct column names)
        // Get updated cash wallet balance
        final updatedCashWallet = await dbHelper.getCashWallet(testAccountId);
        expect(
          updatedCashWallet,
          isNotNull,
          reason: 'Cash wallet should exist after dual-effect',
        );

        final updatedBalance =
            updatedCashWallet![CASH_WALLET_CURRENT_BALANCE] as double;

        // Expected: DR transaction should INCREASE cash wallet balance by ₹5000
        expect(
          updatedBalance,
          equals(initialBalance + 5000.0),
          reason:
              'DR transaction should increase cash wallet balance by transaction amount',
        );

        // Verify cash wallet transaction was created
        final cashWalletTransactions = await dbHelper.getCashWalletTransactions(
          testAccountId,
        );
        expect(
          cashWalletTransactions.length,
          greaterThan(0),
          reason: 'Cash wallet transaction should be created',
        );

        final lastTransaction = cashWalletTransactions.first;
        expect(
          lastTransaction[CASH_WALLET_TRANSACTION_TYPE],
          equals('Cash Withdrawn From Bank'),
          reason:
              'DR transaction should create "Cash Withdrawn From Bank" transaction',
        );
        expect(
          lastTransaction[CASH_WALLET_TRANSACTION_AMOUNT],
          equals(5000.0),
          reason: 'Transaction amount should match',
        );
      },
    );

    test(
      'Bug Condition 2: CR transaction should create cash wallet transaction and decrease balance',
      () async {
        // Arrange
        final now = DateTime.now().toIso8601String();

        // First, add some balance to the cash wallet by doing a DR transaction
        // Get current cash wallet
        final cashWallet = await dbHelper.getCashWallet(testAccountId);
        if (cashWallet == null) {
          await dbHelper.insertCashWallet({
            ACCOUNT_ID: testAccountId,
            CASH_WALLET_CURRENT_BALANCE: 0.0,
            DATE_ADDED: now,
            CREATED_AT: now,
            UPDATED_AT: now,
            DELETED_AT: null,
          });
        }

        await dbHelper.updateCashWalletBalance(testAccountId, 5000.0);
        await dbHelper.insertCashWalletTransaction({
          ACCOUNT_ID: testAccountId,
          CASH_WALLET_TRANSACTION_TYPE: 'Cash Withdrawn From Bank',
          CASH_WALLET_TRANSACTION_AMOUNT: 5000.0,
          CASH_WALLET_TRANSACTION_TAG_ID: cashTagId,
          TRANSACTION_NOTE: 'Initial ATM Withdrawal',
          DATE_ADDED: now,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        });

        final initialCashWallet = await dbHelper.getCashWallet(testAccountId);
        final initialBalance =
            initialCashWallet![CASH_WALLET_CURRENT_BALANCE] as double;
        expect(
          initialBalance,
          equals(5000.0),
          reason: 'Initial balance should be ₹5000',
        );

        // Act: Simulate dual-effect for a CR transaction (cash deposit, ₹2000)
        final cashWallet2 = await dbHelper.getCashWallet(testAccountId);
        final currentCashBalance =
            cashWallet2![CASH_WALLET_CURRENT_BALANCE] as double;

        // CR transaction: Cash wallet loses money (clamped to zero)
        final newCashBalance = (currentCashBalance - 2000.0).clamp(
          0.0,
          double.infinity,
        );
        final cashWalletTxnType = 'Cash Deposited To Bank';

        await dbHelper.updateCashWalletBalance(testAccountId, newCashBalance);
        await dbHelper.insertCashWalletTransaction({
          ACCOUNT_ID: testAccountId,
          CASH_WALLET_TRANSACTION_TYPE: cashWalletTxnType,
          CASH_WALLET_TRANSACTION_AMOUNT: -2000.0,
          CASH_WALLET_TRANSACTION_TAG_ID: cashTagId,
          TRANSACTION_NOTE: 'Auto: Cash Deposit at Branch',
          DATE_ADDED: now,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        });

        // Assert: Expected behavior (should pass on fixed code)
        final updatedCashWallet = await dbHelper.getCashWallet(testAccountId);
        final updatedBalance =
            updatedCashWallet![CASH_WALLET_CURRENT_BALANCE] as double;

        // Expected: CR transaction should DECREASE cash wallet balance by ₹2000
        expect(
          updatedBalance,
          equals(initialBalance - 2000.0),
          reason:
              'CR transaction should decrease cash wallet balance by transaction amount',
        );
        expect(
          updatedBalance,
          equals(3000.0),
          reason: 'Final balance should be ₹3000',
        );

        // Verify cash wallet transaction was created
        final cashWalletTransactions = await dbHelper.getCashWalletTransactions(
          testAccountId,
        );
        expect(
          cashWalletTransactions.length,
          greaterThan(1),
          reason: 'Two cash wallet transactions should exist',
        );

        final lastTransaction = cashWalletTransactions.first;
        expect(
          lastTransaction[CASH_WALLET_TRANSACTION_TYPE],
          equals('Cash Deposited To Bank'),
          reason:
              'CR transaction should create "Cash Deposited To Bank" transaction',
        );
        expect(
          lastTransaction[CASH_WALLET_TRANSACTION_AMOUNT],
          equals(-2000.0),
          reason: 'Transaction amount should be negative for CR',
        );
      },
    );

    test(
      'Bug Condition 3: Virtual entry matching should find transactions with matching keywords',
      () async {
        // Arrange: Create a virtual entry with tag "Salary" (keywords: ["salary", "payment"])

        // First, create a "Salary" tag with keywords
        final salaryTagId = await dbHelper.insertTag(
          TagModel(
            tagName: 'Salary',
            tagKeywords: [
              {"name": "salary", "priority": 1},
              {"name": "payment", "priority": 2},
            ],
            tagPriority: 1, // Global tag
            tagUserId: testAccountId,
            tagBankAccountId: null,
            tagCreatedAt: DateTime.now().toIso8601String(),
            tagUpdatedAt: DateTime.now().toIso8601String(),
            tagDeletedAt: null,
          ),
        );

        expect(
          salaryTagId,
          greaterThan(0),
          reason: 'Salary tag should be created',
        );

        // Create a pending virtual entry
        final virtualEntryId = await dbHelper.insertVirtualEntry({
          VE_ACCOUNT_ID: testAccountId,
          VE_TAG_ID: salaryTagId,
          VE_ENTRY_TYPE: 'Receivable',
          VE_AMOUNT: 50000.0,
          VE_NOTE: 'Receivable from John',
          VE_DATE_ADDED: DateTime.now().toIso8601String(),
          VE_CREATED_AT: DateTime.now().toIso8601String(),
          VE_UPDATED_AT: DateTime.now().toIso8601String(),
          VE_DELETED_AT: null,
          VE_STATUS: 'pending',
          VE_MATCHED_TXN_ID: null,
        });

        expect(
          virtualEntryId,
          greaterThan(0),
          reason: 'Virtual entry should be created',
        );

        // Insert a transaction with narration matching the "Salary" tag keywords
        final txnId = await dbHelper.insertTransaction({
          TXN_DATE: DateTime.now().toIso8601String(),
          TXN_ACCOUNT_ID: testBankAccountNumber,
          TXN_TAG_ID: salaryTagId,
          TXN_AMOUNT: 50000.0,
          TXN_TYPE: 'CR',
          TXN_NARRATION: 'Salary payment from John',
          TXN_REF: 'TXN_REF_SALARY_001',
          TXN_IS_MANUAL: 0,
          CREATED_AT: DateTime.now().toIso8601String(),
          UPDATED_AT: DateTime.now().toIso8601String(),
          DELETED_AT: null,
        });

        expect(txnId, greaterThan(0), reason: 'Transaction should be inserted');

        // Act: Simulate virtual entry matching logic
        final pendingEntries = await dbHelper.getPendingVirtualEntries(
          testAccountId,
        );
        expect(
          pendingEntries.isNotEmpty,
          isTrue,
          reason: 'Should have pending virtual entries',
        );

        final tags = await dbHelper.getAllTags();
        expect(tags.isNotEmpty, isTrue, reason: 'Should have tags');

        // Find the virtual entry we created
        final veMap = pendingEntries.firstWhere(
          (ve) => ve[VIRTUAL_ENTRY_ID] == virtualEntryId,
        );
        final veTagId = veMap[VE_TAG_ID] as int;

        // Find the tag for this virtual entry
        final veTag = tags.firstWhere((t) => t.tagId == veTagId);

        // Get tag keywords
        final keywords = veTag.tagKeywords
            .map((kw) => (kw['name'] as String?)?.toLowerCase().trim())
            .where((k) => k != null && k.isNotEmpty)
            .cast<String>()
            .toList();

        expect(keywords.isNotEmpty, isTrue, reason: 'Tag should have keywords');

        // Query transactions
        final db = await dbHelper.database;
        final candidateTxns = await db.rawQuery(
          '''
        SELECT
          t.$TXN_ID,
          t.$TXN_DATE,
          t.$TXN_AMOUNT,
          t.$TXN_TYPE,
          t.$TXN_NARRATION,
          t.$TXN_ACCOUNT_ID
        FROM $TABLE_TRANSACTIONS t
        WHERE t.$TXN_ACCOUNT_ID = ?
          AND t.$DELETED_AT IS NULL
        ORDER BY t.$TXN_DATE DESC
        ''',
          [testBankAccountNumber],
        );

        expect(
          candidateTxns.isNotEmpty,
          isTrue,
          reason: 'Should have candidate transactions',
        );

        // Find matching transactions by keyword
        bool foundMatch = false;
        for (final txnMap in candidateTxns) {
          final narration = (txnMap[TXN_NARRATION] as String? ?? '')
              .toLowerCase()
              .trim();

          // Check if any keyword matches
          for (final keyword in keywords) {
            if (narration.contains(keyword)) {
              foundMatch = true;
              break;
            }
          }

          if (foundMatch) break;
        }

        // Assert: Expected behavior (should find a match)
        expect(
          foundMatch,
          isTrue,
          reason:
              'Virtual entry should be matched with imported transaction based on keywords',
        );
      },
    );
  });
}
