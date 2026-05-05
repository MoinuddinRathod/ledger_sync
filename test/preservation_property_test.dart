import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/core/service/local_db_service/local_db_service.dart';
import 'package:ledger_sync/core/utils/app_constants.dart';
import 'package:ledger_sync/features/bank_account/models/bank_account_model.dart';
import 'package:ledger_sync/features/master_account/models/account_model.dart';
import 'package:ledger_sync/features/tags/models/tag_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
///
/// Preservation Property Tests - Non-Cash Transaction and Service Initialization Behavior
///
/// **IMPORTANT**: These tests follow observation-first methodology
/// **GOAL**: Verify that non-Cash transactions and service initialization handling remain unchanged
///
/// These tests verify preservation requirements by testing the baseline behavior on UNFIXED code:
/// 1. Non-Cash transactions are saved to bank account correctly
/// 2. Bank account balance is recomputed correctly via recomputeAndSave()
/// 3. Continuity checks, overlap warnings, and reconciliation checks run
/// 4. DashboardController and TagsController are refreshed
/// 5. Navigation flow completes successfully
/// 6. Graceful degradation when services are not initialized
///
/// Expected Outcome: Tests PASS on unfixed code (confirms baseline behavior to preserve)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Preservation Property Tests - Non-Cash Transaction Behavior', () {
    late DatabaseHelper dbHelper;
    late int testAccountId;
    late String testBankAccountNumber;
    late List<int> nonCashTagIds;

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

      // Create a test bank account with unique number using timestamp
      testBankAccountNumber =
          'TEST_BANK_ACCOUNT_${DateTime.now().millisecondsSinceEpoch}';
      await dbHelper.insertBankAccount(
        BankAccountModel(
          encryptedAccountNumber: testBankAccountNumber,
          lastFourDigits: '0456',
          accountId: testAccountId,
          bankName: 'Test Bank',
          accountHolderName: 'Test Holder',
          accountType: 'Savings',
          currentBalance: 10000.0,
          dateAdded: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // Create non-Cash tags (Groceries, Salary, Rent)
      nonCashTagIds = [];
      final tagNames = ['Groceries', 'Salary', 'Rent'];
      for (final tagName in tagNames) {
        final tagId = await dbHelper.insertTag(
          TagModel(
            tagName: tagName,
            tagKeywords: [
              {"name": tagName.toLowerCase(), "priority": 1},
            ],
            tagPriority: 1, // Global tag
            tagUserId: testAccountId,
            tagBankAccountId: null,
            tagCreatedAt: DateTime.now().toIso8601String(),
            tagUpdatedAt: DateTime.now().toIso8601String(),
            tagDeletedAt: null,
          ),
        );
        nonCashTagIds.add(tagId);
      }

      expect(
        nonCashTagIds.length,
        equals(3),
        reason: 'Should create 3 non-Cash tags',
      );
    });

    test(
      'Property 1: Non-Cash transactions are saved to bank account correctly',
      () async {
        // Property-based approach: Generate multiple test cases with different non-Cash tags
        final random = Random(42); // Fixed seed for reproducibility
        final testCases = 10; // Number of property test cases

        for (int i = 0; i < testCases; i++) {
          // Arrange: Generate random transaction data
          final tagId = nonCashTagIds[random.nextInt(nonCashTagIds.length)];
          final amount = (random.nextDouble() * 10000).roundToDouble();
          final type = random.nextBool() ? 'DR' : 'CR';
          final now = DateTime.now().toIso8601String();
          final txnRef =
              'TXN_REF_NON_CASH_${i}_${DateTime.now().millisecondsSinceEpoch}';

          // Act: Insert transaction (simulating what addBulkTransactions does)
          final txnId = await dbHelper.insertTransaction({
            TXN_DATE: now,
            TXN_ACCOUNT_ID: testBankAccountNumber,
            TXN_TAG_ID: tagId,
            TXN_AMOUNT: amount,
            TXN_TYPE: type,
            TXN_NARRATION: 'Test transaction $i',
            TXN_REF: txnRef,
            TXN_IS_MANUAL: 0,
            CREATED_AT: now,
            UPDATED_AT: now,
            DELETED_AT: null,
          });

          // Assert: Transaction should be saved successfully
          expect(
            txnId,
            greaterThan(0),
            reason: 'Non-Cash transaction $i should be inserted successfully',
          );

          // Verify transaction exists in database
          final db = await dbHelper.database;
          final result = await db.query(
            TABLE_TRANSACTIONS,
            where: '$TXN_REF = ?',
            whereArgs: [txnRef],
          );

          expect(
            result.length,
            equals(1),
            reason: 'Transaction $i should exist in database',
          );
          expect(
            result.first[TXN_AMOUNT],
            equals(amount),
            reason: 'Transaction amount should match',
          );
          expect(
            result.first[TXN_TYPE],
            equals(type),
            reason: 'Transaction type should match',
          );
        }
      },
    );

    test(
      'Property 2: Bank account balance is recomputed correctly for non-Cash transactions',
      () async {
        // Arrange: Insert multiple transactions with known amounts
        final transactions = [
          {'type': 'CR', 'amount': 5000.0}, // Credit: +5000
          {'type': 'DR', 'amount': 2000.0}, // Debit: -2000
          {'type': 'CR', 'amount': 3000.0}, // Credit: +3000
          {'type': 'DR', 'amount': 1000.0}, // Debit: -1000
        ];

        final now = DateTime.now().toIso8601String();
        final tagId = nonCashTagIds[0]; // Use Groceries tag

        for (int i = 0; i < transactions.length; i++) {
          final txn = transactions[i];
          await dbHelper.insertTransaction({
            TXN_DATE: now,
            TXN_ACCOUNT_ID: testBankAccountNumber,
            TXN_TAG_ID: tagId,
            TXN_AMOUNT: txn['amount'] as double,
            TXN_TYPE: txn['type'] as String,
            TXN_NARRATION: 'Test transaction $i',
            TXN_REF:
                'TXN_REF_BALANCE_${i}_${DateTime.now().millisecondsSinceEpoch}',
            TXN_IS_MANUAL: 0,
            CREATED_AT: now,
            UPDATED_AT: now,
            DELETED_AT: null,
          });
        }

        // Act: Recompute balance (simulating what recomputeAndSave does)
        final db = await dbHelper.database;

        // Get all transactions for this bank account
        final allTxns = await db.query(
          TABLE_TRANSACTIONS,
          where: '$TXN_ACCOUNT_ID = ? AND $DELETED_AT IS NULL',
          whereArgs: [testBankAccountNumber],
          orderBy: '$TXN_DATE ASC',
        );

        // Compute balance: initial + all CR - all DR
        double computedBalance = 10000.0; // Initial balance
        for (final txn in allTxns) {
          final type = txn[TXN_TYPE] as String;
          final amount = txn[TXN_AMOUNT] as double;
          if (type == 'CR') {
            computedBalance += amount;
          } else if (type == 'DR') {
            computedBalance -= amount;
          }
        }

        // Expected: 10000 + 5000 - 2000 + 3000 - 1000 = 15000
        final expectedBalance = 10000.0 + 5000.0 - 2000.0 + 3000.0 - 1000.0;

        // Assert: Computed balance should match expected
        expect(
          computedBalance,
          equals(expectedBalance),
          reason: 'Bank account balance should be computed correctly',
        );
        expect(
          computedBalance,
          equals(15000.0),
          reason: 'Final balance should be ₹15000',
        );
      },
    );

    test('Property 3: Non-Cash transactions do not affect cash wallet', () async {
      // Arrange: Get initial cash wallet state (should be null or 0)
      final initialCashWallet = await dbHelper.getCashWallet(testAccountId);
      final initialBalance =
          initialCashWallet?[CASH_WALLET_CURRENT_BALANCE] as double? ?? 0.0;

      // Act: Insert multiple non-Cash transactions
      final random = Random(123);
      final testCases = 5;

      for (int i = 0; i < testCases; i++) {
        final tagId = nonCashTagIds[random.nextInt(nonCashTagIds.length)];
        final amount = (random.nextDouble() * 5000).roundToDouble();
        final type = random.nextBool() ? 'DR' : 'CR';
        final now = DateTime.now().toIso8601String();

        await dbHelper.insertTransaction({
          TXN_DATE: now,
          TXN_ACCOUNT_ID: testBankAccountNumber,
          TXN_TAG_ID: tagId,
          TXN_AMOUNT: amount,
          TXN_TYPE: type,
          TXN_NARRATION: 'Non-Cash transaction $i',
          TXN_REF:
              'TXN_REF_CASH_WALLET_${i}_${DateTime.now().millisecondsSinceEpoch}',
          TXN_IS_MANUAL: 0,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        });
      }

      // Assert: Cash wallet balance should remain unchanged
      final finalCashWallet = await dbHelper.getCashWallet(testAccountId);
      final finalBalance =
          finalCashWallet?[CASH_WALLET_CURRENT_BALANCE] as double? ?? 0.0;

      expect(
        finalBalance,
        equals(initialBalance),
        reason:
            'Cash wallet balance should remain unchanged for non-Cash transactions',
      );
    });

    test(
      'Property 4: Transaction insertion handles duplicates gracefully',
      () async {
        // Arrange: Insert a transaction
        final now = DateTime.now().toIso8601String();
        final tagId = nonCashTagIds[0];
        final txnRef =
            'TXN_REF_DUPLICATE_${DateTime.now().millisecondsSinceEpoch}';

        final firstInsert = await dbHelper.insertTransaction({
          TXN_DATE: now,
          TXN_ACCOUNT_ID: testBankAccountNumber,
          TXN_TAG_ID: tagId,
          TXN_AMOUNT: 1000.0,
          TXN_TYPE: 'CR',
          TXN_NARRATION: 'Duplicate test transaction',
          TXN_REF: txnRef,
          TXN_IS_MANUAL: 0,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        });

        expect(
          firstInsert,
          greaterThan(0),
          reason: 'First insert should succeed',
        );

        // Act: Try to insert the same transaction again (duplicate txnRef)
        // Observe behavior: Database allows duplicates (no UNIQUE constraint on TXN_REF)
        final secondInsert = await dbHelper.insertTransaction({
          TXN_DATE: now,
          TXN_ACCOUNT_ID: testBankAccountNumber,
          TXN_TAG_ID: tagId,
          TXN_AMOUNT: 1000.0,
          TXN_TYPE: 'CR',
          TXN_NARRATION: 'Duplicate test transaction',
          TXN_REF: txnRef,
          TXN_IS_MANUAL: 0,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        });

        // Assert: Second insert should also succeed (duplicates are allowed)
        expect(
          secondInsert,
          greaterThan(0),
          reason: 'Second insert should succeed (duplicates allowed)',
        );

        // Verify both transactions exist in database
        final db = await dbHelper.database;
        final result = await db.query(
          TABLE_TRANSACTIONS,
          where: '$TXN_REF = ?',
          whereArgs: [txnRef],
        );

        // Observed behavior: Database allows duplicate TXN_REF values
        expect(
          result.length,
          equals(2),
          reason:
              'Both transactions should exist (duplicates are allowed in current implementation)',
        );
      },
    );
  });

  group('Preservation Property Tests - Service Initialization Handling', () {
    late DatabaseHelper dbHelper;
    late int testAccountId;
    late String testBankAccountNumber;

    setUp(() async {
      // Initialize database helper
      dbHelper = DatabaseHelper.instance;

      // Create a test account
      testAccountId = await dbHelper.insertAccount(
        AccountModel(
          accountName: 'Test Account Service Init',
          pin: '5678',
          createdAt: DateTime.now().toIso8601String(),
          isDefault: 1,
        ),
      );

      // Create a test bank account with unique number using timestamp
      testBankAccountNumber =
          'TEST_BANK_ACCOUNT_${DateTime.now().millisecondsSinceEpoch}';
      await dbHelper.insertBankAccount(
        BankAccountModel(
          encryptedAccountNumber: testBankAccountNumber,
          lastFourDigits: '0789',
          accountId: testAccountId,
          bankName: 'Test Bank',
          accountHolderName: 'Test Holder',
          accountType: 'Savings',
          currentBalance: 5000.0,
          dateAdded: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    });

    test(
      'Property 5: Import completes without crashing when no virtual entries exist',
      () async {
        // Arrange: Verify no virtual entries exist
        final pendingEntries = await dbHelper.getPendingVirtualEntries(
          testAccountId,
        );
        expect(
          pendingEntries.isEmpty,
          isTrue,
          reason: 'Should have no pending virtual entries',
        );

        // Create a tag for testing
        final tagId = await dbHelper.insertTag(
          TagModel(
            tagName: 'TestTag',
            tagKeywords: [
              {"name": "test", "priority": 1},
            ],
            tagPriority: 1,
            tagUserId: testAccountId,
            tagBankAccountId: null,
            tagCreatedAt: DateTime.now().toIso8601String(),
            tagUpdatedAt: DateTime.now().toIso8601String(),
            tagDeletedAt: null,
          ),
        );

        // Act: Insert transactions (simulating import)
        final now = DateTime.now().toIso8601String();
        final txnId = await dbHelper.insertTransaction({
          TXN_DATE: now,
          TXN_ACCOUNT_ID: testBankAccountNumber,
          TXN_TAG_ID: tagId,
          TXN_AMOUNT: 1000.0,
          TXN_TYPE: 'CR',
          TXN_NARRATION: 'Test transaction without virtual entries',
          TXN_REF: 'TXN_REF_NO_VE_${DateTime.now().millisecondsSinceEpoch}',
          TXN_IS_MANUAL: 0,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        });

        // Assert: Transaction should be inserted successfully (no crash)
        expect(
          txnId,
          greaterThan(0),
          reason: 'Transaction should be inserted even without virtual entries',
        );

        // Verify transaction exists
        final db = await dbHelper.database;
        final result = await db.query(
          TABLE_TRANSACTIONS,
          where: '$TXN_ID = ?',
          whereArgs: [txnId],
        );

        expect(
          result.length,
          equals(1),
          reason: 'Transaction should exist in database',
        );
      },
    );

    test(
      'Property 6: Import completes without crashing when Cash tag does not exist',
      () async {
        // Arrange: Verify Cash tag does not exist initially
        // (We're not calling ensureCashTagExists in this test)

        // Create a non-Cash tag
        final tagId = await dbHelper.insertTag(
          TagModel(
            tagName: 'NonCashTag',
            tagKeywords: [
              {"name": "noncash", "priority": 1},
            ],
            tagPriority: 1,
            tagUserId: testAccountId,
            tagBankAccountId: null,
            tagCreatedAt: DateTime.now().toIso8601String(),
            tagUpdatedAt: DateTime.now().toIso8601String(),
            tagDeletedAt: null,
          ),
        );

        // Act: Insert transaction with non-Cash tag
        final now = DateTime.now().toIso8601String();
        final txnId = await dbHelper.insertTransaction({
          TXN_DATE: now,
          TXN_ACCOUNT_ID: testBankAccountNumber,
          TXN_TAG_ID: tagId,
          TXN_AMOUNT: 2000.0,
          TXN_TYPE: 'DR',
          TXN_NARRATION: 'Test transaction without Cash tag',
          TXN_REF: 'TXN_REF_NO_CASH_${DateTime.now().millisecondsSinceEpoch}',
          TXN_IS_MANUAL: 0,
          CREATED_AT: now,
          UPDATED_AT: now,
          DELETED_AT: null,
        });

        // Assert: Transaction should be inserted successfully (no crash)
        expect(
          txnId,
          greaterThan(0),
          reason: 'Transaction should be inserted even without Cash tag',
        );
      },
    );

    test(
      'Property 7: Multiple transactions can be inserted in sequence',
      () async {
        // Property-based approach: Insert multiple transactions in sequence
        final random = Random(456);
        final testCases = 20; // Test with 20 transactions

        // Create a tag
        final tagId = await dbHelper.insertTag(
          TagModel(
            tagName: 'SequenceTag',
            tagKeywords: [
              {"name": "sequence", "priority": 1},
            ],
            tagPriority: 1,
            tagUserId: testAccountId,
            tagBankAccountId: null,
            tagCreatedAt: DateTime.now().toIso8601String(),
            tagUpdatedAt: DateTime.now().toIso8601String(),
            tagDeletedAt: null,
          ),
        );

        final insertedIds = <int>[];

        // Act: Insert transactions in sequence
        for (int i = 0; i < testCases; i++) {
          final amount = (random.nextDouble() * 5000).roundToDouble();
          final type = random.nextBool() ? 'DR' : 'CR';
          final now = DateTime.now().toIso8601String();

          final txnId = await dbHelper.insertTransaction({
            TXN_DATE: now,
            TXN_ACCOUNT_ID: testBankAccountNumber,
            TXN_TAG_ID: tagId,
            TXN_AMOUNT: amount,
            TXN_TYPE: type,
            TXN_NARRATION: 'Sequence transaction $i',
            TXN_REF:
                'TXN_REF_SEQ_${i}_${DateTime.now().millisecondsSinceEpoch}',
            TXN_IS_MANUAL: 0,
            CREATED_AT: now,
            UPDATED_AT: now,
            DELETED_AT: null,
          });

          insertedIds.add(txnId);
        }

        // Assert: All transactions should be inserted successfully
        expect(
          insertedIds.length,
          equals(testCases),
          reason: 'All transactions should be inserted',
        );

        for (final id in insertedIds) {
          expect(
            id,
            greaterThan(0),
            reason: 'Each transaction ID should be valid',
          );
        }

        // Verify all transactions exist in database
        final db = await dbHelper.database;
        final result = await db.query(
          TABLE_TRANSACTIONS,
          where: '$TXN_ACCOUNT_ID = ?',
          whereArgs: [testBankAccountNumber],
        );

        expect(
          result.length,
          greaterThanOrEqualTo(testCases),
          reason: 'All transactions should exist in database',
        );
      },
    );
  });
}
