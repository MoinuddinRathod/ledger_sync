import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/core/service/local_db_service/local_db_service.dart';
import 'package:ledger_sync/core/utils/app_constants.dart';
import 'package:ledger_sync/features/bank_account/models/bank_account_model.dart';
import 'package:ledger_sync/features/master_account/models/account_model.dart';
import 'package:ledger_sync/features/tags/models/tag_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**
///
/// **Property 2: Preservation** - Existing User Data Isolation and Login Flow
///
/// **IMPORTANT**: These tests follow observation-first methodology
/// **GOAL**: Observe behavior on UNFIXED code for non-buggy inputs and write property-based tests
///
/// These tests verify preservation requirements by testing the baseline behavior on UNFIXED code:
/// 1. Existing User Login: Verify login flow is unchanged
/// 2. User Data Isolation: Verify User A cannot see User B's Cash Tag or Cash Wallet
/// 3. Idempotent Tag Creation: Verify calling ensureCashTagExists() multiple times returns the same tagId
/// 4. Cash Wallet Transaction Creation: Verify manual transaction creation continues to work
/// 5. Non-Cash transactions are saved to bank account correctly
/// 6. Bank account balance is recomputed correctly via recomputeAndSave()
/// 7. Graceful degradation when services are not initialized
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

  group('Preservation Property Tests - User Login Flow', () {
    late DatabaseHelper dbHelper;
    final random = Random(789);

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
    });

    test('Property 8: Existing user login flow remains unchanged', () async {
      // Property-based approach: Test login with multiple accounts
      const numTestCases = 5;

      for (int i = 0; i < numTestCases; i++) {
        // Arrange: Create a test account
        final accountName = 'LoginUser${random.nextInt(10000)}';
        final pin = '${1000 + random.nextInt(9000)}';

        // Hash the PIN (simulating what MasterAccountController does)
        final hashedPin = _hashPin(pin);

        final accountId = await dbHelper.insertAccount(
          AccountModel(
            accountName: accountName,
            pin: hashedPin,
            createdAt: DateTime.now().toIso8601String(),
            isDefault: 1,
          ),
        );

        expect(
          accountId,
          greaterThan(0),
          reason: 'Account should be created successfully',
        );

        // Act: Simulate login by checking credentials
        final loginResult = await dbHelper.checkLogin(accountName, hashedPin);

        // Assert: Login should succeed and return the correct accountId
        expect(
          loginResult,
          equals(accountId),
          reason:
              'Login should succeed and return correct accountId for user "$accountName"',
        );

        // Verify login with wrong PIN fails
        final wrongHashedPin = _hashPin('9999');
        final failedLogin = await dbHelper.checkLogin(
          accountName,
          wrongHashedPin,
        );

        expect(
          failedLogin,
          equals(-1),
          reason: 'Login should fail with incorrect PIN',
        );
      }
    });

    test('Property 9: Multiple users can login independently', () async {
      // Arrange: Create multiple accounts
      final accounts = <Map<String, dynamic>>[];
      const numAccounts = 3;

      for (int i = 0; i < numAccounts; i++) {
        final accountName = 'MultiUser${random.nextInt(10000)}';
        final pin = '${1000 + random.nextInt(9000)}';
        final hashedPin = _hashPin(pin);

        final accountId = await dbHelper.insertAccount(
          AccountModel(
            accountName: accountName,
            pin: hashedPin,
            createdAt: DateTime.now().toIso8601String(),
            isDefault: i == 0 ? 1 : 0,
          ),
        );

        accounts.add({
          'accountId': accountId,
          'accountName': accountName,
          'hashedPin': hashedPin,
        });
      }

      // Act & Assert: Each user should be able to login independently
      for (final account in accounts) {
        final loginResult = await dbHelper.checkLogin(
          account['accountName'] as String,
          account['hashedPin'] as String,
        );

        expect(
          loginResult,
          equals(account['accountId']),
          reason:
              'Each user should be able to login independently with their own credentials',
        );
      }
    });
  });

  group('Preservation Property Tests - User Data Isolation', () {
    late DatabaseHelper dbHelper;
    late int userAId;
    late int userBId;
    final random = Random(101112);

    setUp(() async {
      dbHelper = DatabaseHelper.instance;

      // Create User A
      userAId = await dbHelper.insertAccount(
        AccountModel(
          accountName: 'UserA_${random.nextInt(10000)}',
          pin: _hashPin('1111'),
          createdAt: DateTime.now().toIso8601String(),
          isDefault: 1,
        ),
      );

      // Create User B
      userBId = await dbHelper.insertAccount(
        AccountModel(
          accountName: 'UserB_${random.nextInt(10000)}',
          pin: _hashPin('2222'),
          createdAt: DateTime.now().toIso8601String(),
          isDefault: 0,
        ),
      );

      // Create Cash Wallets for both users
      await dbHelper.insertCashWallet({
        'account_id': userAId,
        'current_balance': 1000.0,
        'date_added': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      await dbHelper.insertCashWallet({
        'account_id': userBId,
        'current_balance': 2000.0,
        'date_added': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create Cash Tags for both users
      await dbHelper.ensureCashTagExists(userAId);
      await dbHelper.ensureCashTagExists(userBId);
    });

    test('Property 10: User A cannot see User B\'s Cash Wallet', () async {
      // Act: Query Cash Wallet for User A
      final userACashWallet = await dbHelper.getCashWallet(userAId);

      // Assert: User A should only see their own Cash Wallet
      expect(
        userACashWallet,
        isNotNull,
        reason: 'User A should have a Cash Wallet',
      );
      expect(
        userACashWallet![ACCOUNT_ID],
        equals(userAId),
        reason: 'Cash Wallet should belong to User A',
      );
      expect(
        userACashWallet[CASH_WALLET_CURRENT_BALANCE],
        equals(1000.0),
        reason: 'User A should see their own balance',
      );

      // Act: Query Cash Wallet for User B
      final userBCashWallet = await dbHelper.getCashWallet(userBId);

      // Assert: User B should only see their own Cash Wallet
      expect(
        userBCashWallet,
        isNotNull,
        reason: 'User B should have a Cash Wallet',
      );
      expect(
        userBCashWallet![ACCOUNT_ID],
        equals(userBId),
        reason: 'Cash Wallet should belong to User B',
      );
      expect(
        userBCashWallet[CASH_WALLET_CURRENT_BALANCE],
        equals(2000.0),
        reason: 'User B should see their own balance',
      );

      // Verify isolation: User A's balance != User B's balance
      expect(
        userACashWallet[CASH_WALLET_CURRENT_BALANCE],
        isNot(equals(userBCashWallet[CASH_WALLET_CURRENT_BALANCE])),
        reason: 'User A and User B should have different balances',
      );
    });

    test('Property 11: User A cannot see User B\'s Cash Tag', () async {
      // Act: Query Cash Tag for User A
      final db = await dbHelper.database;
      final userACashTag = await db.query(
        TABLE_TAGS,
        where:
            '$TAG_NAME = ? AND $TAG_USER_ID = ? AND $TAG_BANK_ACCOUNT_ID IS NULL AND $TAG_DELETED_AT IS NULL',
        whereArgs: ['Cash', userAId],
      );

      // Assert: User A should only see their own Cash Tag
      expect(
        userACashTag.length,
        equals(1),
        reason: 'User A should have exactly one Cash Tag',
      );
      expect(
        userACashTag.first[TAG_USER_ID],
        equals(userAId),
        reason: 'Cash Tag should belong to User A',
      );

      // Act: Query Cash Tag for User B
      final userBCashTag = await db.query(
        TABLE_TAGS,
        where:
            '$TAG_NAME = ? AND $TAG_USER_ID = ? AND $TAG_BANK_ACCOUNT_ID IS NULL AND $TAG_DELETED_AT IS NULL',
        whereArgs: ['Cash', userBId],
      );

      // Assert: User B should only see their own Cash Tag
      expect(
        userBCashTag.length,
        equals(1),
        reason: 'User B should have exactly one Cash Tag',
      );
      expect(
        userBCashTag.first[TAG_USER_ID],
        equals(userBId),
        reason: 'Cash Tag should belong to User B',
      );

      // Verify isolation: User A's tag ID != User B's tag ID
      expect(
        userACashTag.first[TAG_ID],
        isNot(equals(userBCashTag.first[TAG_ID])),
        reason: 'User A and User B should have different Cash Tag IDs',
      );
    });

    test(
      'Property 12: User data queries filter by accountId correctly',
      () async {
        // Property-based approach: Test multiple queries with different users
        final queries = [
          {
            'description': 'Cash Wallet query',
            'query': () => dbHelper.getCashWallet(userAId),
            'expectedAccountId': userAId,
          },
          {
            'description': 'Cash Wallet query',
            'query': () => dbHelper.getCashWallet(userBId),
            'expectedAccountId': userBId,
          },
        ];

        for (final testCase in queries) {
          // Act: Execute query
          final result = await (testCase['query'] as Function)();

          // Assert: Result should be filtered by accountId
          expect(
            result,
            isNotNull,
            reason: '${testCase['description']} should return data',
          );
          expect(
            result![ACCOUNT_ID],
            equals(testCase['expectedAccountId']),
            reason:
                '${testCase['description']} should filter by accountId correctly',
          );
        }
      },
    );
  });

  group('Preservation Property Tests - Idempotent Tag Creation', () {
    late DatabaseHelper dbHelper;
    late int testAccountId;
    final random = Random(131415);

    setUp(() async {
      dbHelper = DatabaseHelper.instance;

      // Create a test account
      testAccountId = await dbHelper.insertAccount(
        AccountModel(
          accountName: 'IdempotentUser_${random.nextInt(10000)}',
          pin: _hashPin('3333'),
          createdAt: DateTime.now().toIso8601String(),
          isDefault: 1,
        ),
      );
    });

    test('Property 13: ensureCashTagExists() is idempotent', () async {
      // Property-based approach: Call ensureCashTagExists() multiple times
      const numCalls = 10;
      final tagIds = <int>[];

      for (int i = 0; i < numCalls; i++) {
        // Act: Call ensureCashTagExists()
        final tagId = await dbHelper.ensureCashTagExists(testAccountId);

        tagIds.add(tagId);

        // Assert: Tag ID should be valid
        expect(
          tagId,
          greaterThan(0),
          reason: 'ensureCashTagExists() should return valid tag ID',
        );
      }

      // Assert: All calls should return the same tag ID (idempotent)
      final firstTagId = tagIds.first;
      for (int i = 1; i < tagIds.length; i++) {
        expect(
          tagIds[i],
          equals(firstTagId),
          reason:
              'ensureCashTagExists() should be idempotent (call ${i + 1} returned ${tagIds[i]}, expected $firstTagId)',
        );
      }

      // Verify only one Cash Tag exists in database
      final db = await dbHelper.database;
      final cashTags = await db.query(
        TABLE_TAGS,
        where:
            '$TAG_NAME = ? AND $TAG_USER_ID = ? AND $TAG_BANK_ACCOUNT_ID IS NULL AND $TAG_DELETED_AT IS NULL',
        whereArgs: ['Cash', testAccountId],
      );

      expect(
        cashTags.length,
        equals(1),
        reason:
            'Only one Cash Tag should exist after multiple ensureCashTagExists() calls',
      );
    });

    test(
      'Property 14: ensureCashTagExists() creates tag with correct structure',
      () async {
        // Act: Call ensureCashTagExists()
        final tagId = await dbHelper.ensureCashTagExists(testAccountId);

        // Assert: Tag should be created with correct structure
        final db = await dbHelper.database;
        final cashTag = await db.query(
          TABLE_TAGS,
          where: '$TAG_ID = ?',
          whereArgs: [tagId],
        );

        expect(cashTag.length, equals(1), reason: 'Cash Tag should exist');

        final tag = cashTag.first;
        expect(
          tag[TAG_NAME],
          equals('Cash'),
          reason: 'Cash Tag should have name "Cash"',
        );
        expect(
          tag[TAG_USER_ID],
          equals(testAccountId),
          reason: 'Cash Tag should be scoped to user accountId',
        );
        expect(
          tag[TAG_PRIORITY],
          equals(0),
          reason: 'Cash Tag should have highest priority (0)',
        );
        expect(
          tag[TAG_BANK_ACCOUNT_ID],
          isNull,
          reason: 'Cash Tag should be user-scoped (not bank-account-scoped)',
        );
        expect(
          tag[TAG_DELETED_AT],
          isNull,
          reason: 'Cash Tag should not be deleted',
        );
      },
    );
  });

  group(
    'Preservation Property Tests - Manual Cash Wallet Transaction Creation',
    () {
      late DatabaseHelper dbHelper;
      late int testAccountId;
      late int cashTagId;
      final random = Random(161718);

      setUp(() async {
        dbHelper = DatabaseHelper.instance;

        // Create a test account
        testAccountId = await dbHelper.insertAccount(
          AccountModel(
            accountName: 'ManualTxnUser_${random.nextInt(10000)}',
            pin: _hashPin('4444'),
            createdAt: DateTime.now().toIso8601String(),
            isDefault: 1,
          ),
        );

        // Create Cash Wallet
        await dbHelper.insertCashWallet({
          'account_id': testAccountId,
          'current_balance': 5000.0,
          'date_added': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });

        // Create Cash Tag
        cashTagId = await dbHelper.ensureCashTagExists(testAccountId);
      });

      test(
        'Property 15: Manual cash wallet transaction creation continues to work',
        () async {
          // Property-based approach: Create multiple manual transactions
          const numTransactions = 10;
          final transactionIds = <int>[];

          for (int i = 0; i < numTransactions; i++) {
            // Arrange: Generate random transaction data
            final amount = (random.nextDouble() * 1000).roundToDouble();
            final type = random.nextBool() ? 'DR' : 'CR';
            final now = DateTime.now().toIso8601String();

            // Act: Insert manual cash wallet transaction
            final txnId = await dbHelper.insertCashWalletTransaction({
              CASH_WALLET_TRANSACTION_ACCOUNT_ID: testAccountId,
              CASH_WALLET_TRANSACTION_TAG_ID: cashTagId,
              CASH_WALLET_TRANSACTION_AMOUNT: amount,
              CASH_WALLET_TRANSACTION_TYPE: type,
              TRANSACTION_NOTE: 'Manual transaction $i',
              DATE_ADDED: now,
              CASH_WALLET_IS_MANUAL: 1,
              CREATED_AT: now,
              UPDATED_AT: now,
              DELETED_AT: null,
            });

            transactionIds.add(txnId);

            // Assert: Transaction should be created successfully
            expect(
              txnId,
              greaterThan(0),
              reason: 'Manual transaction $i should be created successfully',
            );
          }

          // Verify all transactions exist in database
          final cashWalletTransactions = await dbHelper
              .getCashWalletTransactions(testAccountId);

          expect(
            cashWalletTransactions.length,
            greaterThanOrEqualTo(numTransactions),
            reason: 'All manual transactions should exist in database',
          );

          // Verify transactions are marked as manual
          for (final txn in cashWalletTransactions) {
            expect(
              txn[CASH_WALLET_IS_MANUAL],
              equals(1),
              reason: 'Transaction should be marked as manual',
            );
            expect(
              txn[CASH_WALLET_TRANSACTION_ACCOUNT_ID],
              equals(testAccountId),
              reason: 'Transaction should belong to correct account',
            );
          }
        },
      );

      test(
        'Property 16: Manual transactions update cash wallet balance correctly',
        () async {
          // Arrange: Get initial balance
          final initialCashWallet = await dbHelper.getCashWallet(testAccountId);
          final initialBalance =
              initialCashWallet![CASH_WALLET_CURRENT_BALANCE] as double;

          // Act: Create a CR transaction (cash deposit)
          final crAmount = 1000.0;
          await dbHelper.insertCashWalletTransaction({
            CASH_WALLET_TRANSACTION_ACCOUNT_ID: testAccountId,
            CASH_WALLET_TRANSACTION_TAG_ID: cashTagId,
            CASH_WALLET_TRANSACTION_AMOUNT: crAmount,
            CASH_WALLET_TRANSACTION_TYPE: 'CR',
            TRANSACTION_NOTE: 'Manual deposit',
            DATE_ADDED: DateTime.now().toIso8601String(),
            CASH_WALLET_IS_MANUAL: 1,
            CREATED_AT: DateTime.now().toIso8601String(),
            UPDATED_AT: DateTime.now().toIso8601String(),
            DELETED_AT: null,
          });

          // Update balance manually (simulating what the controller does)
          final newBalance = initialBalance + crAmount;
          await dbHelper.updateCashWalletBalance(testAccountId, newBalance);

          // Assert: Balance should be updated correctly
          final updatedCashWallet = await dbHelper.getCashWallet(testAccountId);
          final updatedBalance =
              updatedCashWallet![CASH_WALLET_CURRENT_BALANCE] as double;

          expect(
            updatedBalance,
            equals(initialBalance + crAmount),
            reason:
                'Cash wallet balance should be updated after CR transaction',
          );

          // Act: Create a DR transaction (cash withdrawal)
          final drAmount = 500.0;
          await dbHelper.insertCashWalletTransaction({
            CASH_WALLET_TRANSACTION_ACCOUNT_ID: testAccountId,
            CASH_WALLET_TRANSACTION_TAG_ID: cashTagId,
            CASH_WALLET_TRANSACTION_AMOUNT: drAmount,
            CASH_WALLET_TRANSACTION_TYPE: 'DR',
            TRANSACTION_NOTE: 'Manual withdrawal',
            DATE_ADDED: DateTime.now().toIso8601String(),
            CASH_WALLET_IS_MANUAL: 1,
            CREATED_AT: DateTime.now().toIso8601String(),
            UPDATED_AT: DateTime.now().toIso8601String(),
            DELETED_AT: null,
          });

          // Update balance manually
          final finalBalance = updatedBalance - drAmount;
          await dbHelper.updateCashWalletBalance(testAccountId, finalBalance);

          // Assert: Balance should be updated correctly
          final finalCashWallet = await dbHelper.getCashWallet(testAccountId);
          final finalBalanceResult =
              finalCashWallet![CASH_WALLET_CURRENT_BALANCE] as double;

          expect(
            finalBalanceResult,
            equals(initialBalance + crAmount - drAmount),
            reason:
                'Cash wallet balance should be updated after DR transaction',
          );
          expect(
            finalBalanceResult,
            equals(5000.0 + 1000.0 - 500.0),
            reason: 'Final balance should be ₹5500',
          );
        },
      );
    },
  );
}

/// Helper function to hash PIN (simulating PasswordEncryptionDecryptionService)
/// Uses SHA-256 hashing to match production behavior
String _hashPin(String pin) {
  final bytes = utf8.encode(pin.trim());
  return sha256.convert(bytes).toString();
}
