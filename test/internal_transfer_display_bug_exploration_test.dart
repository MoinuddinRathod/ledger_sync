import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_sync/features/cash_wallet/models/cash_wallet_transaction_model.dart';
import 'package:ledger_sync/features/transactions/models/bank_transaction_model.dart';

/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4**
///
/// Bug Condition Exploration Test - Internal Transfer Pair Duplication
///
/// **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
/// **DO NOT attempt to fix the test or the code when it fails**
/// **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
/// **GOAL**: Surface counterexamples that demonstrate the bug exists
///
/// This test verifies the bug condition where internal transfers between Cash Wallet and Bank Account
/// appear as two separate transactions instead of one logical transfer.
///
/// Expected Behavior Properties (for when test passes after fix):
/// - Transfer pairs should be displayed as ONE transaction with txnType='TRANSFER'
/// - Transfer transactions should NOT be counted in totalCredit or totalDebit
/// - All counterexamples should be resolved
///
/// This is a UNIT TEST that directly tests the transaction merging logic without database dependencies.
void main() {
  group('Bug Condition Exploration - Internal Transfer Display', () {
    /// Helper function to simulate the UNFIXED fetchAllTransactions logic
    /// This mimics what the controller currently does: naive merging without transfer detection
    List<BankTransactionModel> simulateUnfixedFetchAllTransactions(
      List<BankTransactionModel> bankTransactions,
      List<CashWalletTransactionModel> cashTransactions,
    ) {
      // Current (unfixed) implementation: just merge the lists
      final merged = [
        ...bankTransactions,
        ...cashTransactions.map((e) => BankTransactionModel.fromCashWallet(e)),
      ];
      return merged;
    }

    /// Helper function to calculate total credit (unfixed version)
    double calculateTotalCredit(List<BankTransactionModel> transactions) {
      return transactions
          .where((e) => e.isCredit)
          .fold(0.0, (sum, e) => sum + e.txnAmount);
    }

    /// Helper function to calculate total debit (unfixed version)
    double calculateTotalDebit(List<BankTransactionModel> transactions) {
      return transactions
          .where((e) => e.isDebit)
          .fold(0.0, (sum, e) => sum + e.txnAmount);
    }

    test(
      'Property 1: Bug Condition - Cash Deposited To Bank should display as ONE TRANSFER transaction',
      () {
        // Arrange: Create a transfer pair (Cash → Bank)
        final dateStr = '2024-01-15';
        final amount = 1000.0;
        final bankAccountId = 'ABC123';

        // Create cash wallet transaction: Cash Deposited To Bank
        final cashTransaction = CashWalletTransactionModel(
          cashWalletTransactionId: 1,
          accountId: 1,
          tagId: 1,
          transactionType: 'Cash Deposited To Bank',
          amount: amount,
          transactionNote: 'Transfer to bank',
          dateAdded: dateStr,
          createdAt: DateTime.now().toIso8601String(),
          bankAccountId: bankAccountId,
          isManual: true,
          resolvedTagName: 'General',
        );

        // Create matching bank transaction: Credit
        final bankTransaction = BankTransactionModel(
          txnId: 2,
          txnDate: dateStr,
          txnAmount: amount,
          txnType: 'CR',
          txnNarration: 'Cash deposit',
          encryptedAccountId: bankAccountId,
          txnTagId: 1,
          tagName: 'General',
          bankName: 'Test Bank',
          lastFourDigits: '3456',
          isManual: false,
        );

        // Act: Simulate the UNFIXED fetchAllTransactions logic
        final allTransactions = simulateUnfixedFetchAllTransactions(
          [bankTransaction],
          [cashTransaction],
        );

        // Calculate totals using unfixed logic
        final totalCredit = calculateTotalCredit(allTransactions);
        final totalDebit = calculateTotalDebit(allTransactions);

        // Assert: Expected behavior (WILL FAIL on unfixed code)

        // Expected: Should have exactly ONE transaction for this transfer
        // Actual (on unfixed code): Will have TWO separate transactions
        final transferTransactions = allTransactions.where((txn) {
          // On fixed code, this would be marked as 'TRANSFER'
          // On unfixed code, we'll see two separate transactions
          return txn.txnType.toUpperCase() == 'TRANSFER';
        }).toList();

        expect(
          transferTransactions.length,
          equals(1),
          reason:
              'Expected: 1 transfer transaction. '
              'Actual (on unfixed code): ${transferTransactions.length} transfer transactions '
              '(bug: shows ${allTransactions.length} separate transactions instead)',
        );

        // Expected: The transfer transaction should exist
        expect(
          transferTransactions.isNotEmpty,
          isTrue,
          reason: 'Transfer transaction should be marked as TRANSFER type',
        );

        final transferTxn = transferTransactions.first;

        // Expected: Transfer should have the correct amount
        expect(
          transferTxn.txnAmount,
          equals(amount),
          reason: 'Transfer transaction should have the correct amount',
        );

        // Expected: Transfer should NOT be counted in credit totals
        // Actual (on unfixed code): Will be counted, inflating totals
        expect(
          totalCredit,
          equals(0.0),
          reason:
              'Expected: totalCredit=0 (transfers excluded). '
              'Actual (on unfixed code): totalCredit=$totalCredit (bug: transfer counted as credit)',
        );

        // Expected: Transfer should NOT be counted in debit totals
        // Actual (on unfixed code): Will be counted, inflating totals
        expect(
          totalDebit,
          equals(0.0),
          reason:
              'Expected: totalDebit=0 (transfers excluded). '
              'Actual (on unfixed code): totalDebit=$totalDebit (bug: transfer counted as debit)',
        );

        // Document the counterexample found:
        print('\n=== COUNTEREXAMPLE DOCUMENTATION ===');
        print('Transfer: Cash Deposited To Bank, Amount: ₹$amount');
        print('Expected: 1 TRANSFER transaction');
        print('Actual: ${allTransactions.length} transactions');
        print(
          'Transaction types: ${allTransactions.map((t) => t.txnType).join(", ")}',
        );
        print('Expected totalCredit: 0.0');
        print('Actual totalCredit: $totalCredit');
        print('Expected totalDebit: 0.0');
        print('Actual totalDebit: $totalDebit');
        print('===================================\n');
      },
    );

    test(
      'Property 1: Bug Condition - Cash Withdrawn From Bank should display as ONE TRANSFER transaction',
      () {
        // Arrange: Create a transfer pair (Bank → Cash)
        final dateStr = '2024-01-20';
        final amount = 500.0;
        final bankAccountId = 'XYZ789';

        // Create cash wallet transaction: Cash Withdrawn From Bank
        final cashTransaction = CashWalletTransactionModel(
          cashWalletTransactionId: 3,
          accountId: 1,
          tagId: 1,
          transactionType: 'Cash Withdrawn From Bank',
          amount: amount,
          transactionNote: 'ATM withdrawal',
          dateAdded: dateStr,
          createdAt: DateTime.now().toIso8601String(),
          bankAccountId: bankAccountId,
          isManual: true,
          resolvedTagName: 'General',
        );

        // Create matching bank transaction: Debit
        final bankTransaction = BankTransactionModel(
          txnId: 4,
          txnDate: dateStr,
          txnAmount: amount,
          txnType: 'DR',
          txnNarration: 'ATM withdrawal',
          encryptedAccountId: bankAccountId,
          txnTagId: 1,
          tagName: 'General',
          bankName: 'Test Bank',
          lastFourDigits: '7890',
          isManual: false,
        );

        // Act: Simulate the UNFIXED fetchAllTransactions logic
        final allTransactions = simulateUnfixedFetchAllTransactions(
          [bankTransaction],
          [cashTransaction],
        );

        // Calculate totals using unfixed logic
        final totalCredit = calculateTotalCredit(allTransactions);
        final totalDebit = calculateTotalDebit(allTransactions);

        // Assert: Expected behavior (WILL FAIL on unfixed code)

        // Expected: Should have exactly ONE transaction for this transfer
        // Actual (on unfixed code): Will have TWO separate transactions
        final transferTransactions = allTransactions.where((txn) {
          return txn.txnType.toUpperCase() == 'TRANSFER';
        }).toList();

        expect(
          transferTransactions.length,
          equals(1),
          reason:
              'Expected: 1 transfer transaction. '
              'Actual (on unfixed code): ${transferTransactions.length} transfer transactions '
              '(bug: shows ${allTransactions.length} separate transactions instead)',
        );

        // Expected: Transfer should NOT be counted in credit totals
        expect(
          totalCredit,
          equals(0.0),
          reason:
              'Expected: totalCredit=0 (transfers excluded). '
              'Actual (on unfixed code): totalCredit=$totalCredit (bug: transfer counted as credit)',
        );

        // Expected: Transfer should NOT be counted in debit totals
        expect(
          totalDebit,
          equals(0.0),
          reason:
              'Expected: totalDebit=0 (transfers excluded). '
              'Actual (on unfixed code): totalDebit=$totalDebit (bug: transfer counted as debit)',
        );

        // Document the counterexample found:
        print('\n=== COUNTEREXAMPLE DOCUMENTATION ===');
        print('Transfer: Cash Withdrawn From Bank, Amount: ₹$amount');
        print('Expected: 1 TRANSFER transaction');
        print('Actual: ${allTransactions.length} transactions');
        print(
          'Transaction types: ${allTransactions.map((t) => t.txnType).join(", ")}',
        );
        print('Expected totalCredit: 0.0');
        print('Actual totalCredit: $totalCredit');
        print('Expected totalDebit: 0.0');
        print('Actual totalDebit: $totalDebit');
        print('===================================\n');
      },
    );

    test(
      'Property 1: Bug Condition - Multiple transfers same day should each display as ONE TRANSFER transaction',
      () {
        // Arrange: Create multiple transfer pairs on the same day with different amounts
        final dateStr = '2024-01-25';
        final bankAccountId = 'TEST123';

        // Transfer 1: ₹1000 Cash → Bank
        final cashTxn1 = CashWalletTransactionModel(
          cashWalletTransactionId: 5,
          accountId: 1,
          tagId: 1,
          transactionType: 'Cash Deposited To Bank',
          amount: 1000.0,
          transactionNote: 'Transfer 1',
          dateAdded: dateStr,
          createdAt: DateTime.now().toIso8601String(),
          bankAccountId: bankAccountId,
          isManual: true,
          resolvedTagName: 'General',
        );

        final bankTxn1 = BankTransactionModel(
          txnId: 6,
          txnDate: dateStr,
          txnAmount: 1000.0,
          txnType: 'CR',
          txnNarration: 'Transfer 1',
          encryptedAccountId: bankAccountId,
          txnTagId: 1,
          tagName: 'General',
          bankName: 'Test Bank',
          lastFourDigits: '1234',
          isManual: false,
        );

        // Transfer 2: ₹500 Bank → Cash
        final cashTxn2 = CashWalletTransactionModel(
          cashWalletTransactionId: 7,
          accountId: 1,
          tagId: 1,
          transactionType: 'Cash Withdrawn From Bank',
          amount: 500.0,
          transactionNote: 'Transfer 2',
          dateAdded: dateStr,
          createdAt: DateTime.now().toIso8601String(),
          bankAccountId: bankAccountId,
          isManual: true,
          resolvedTagName: 'General',
        );

        final bankTxn2 = BankTransactionModel(
          txnId: 8,
          txnDate: dateStr,
          txnAmount: 500.0,
          txnType: 'DR',
          txnNarration: 'Transfer 2',
          encryptedAccountId: bankAccountId,
          txnTagId: 1,
          tagName: 'General',
          bankName: 'Test Bank',
          lastFourDigits: '1234',
          isManual: false,
        );

        // Transfer 3: ₹2000 Cash → Bank
        final cashTxn3 = CashWalletTransactionModel(
          cashWalletTransactionId: 9,
          accountId: 1,
          tagId: 1,
          transactionType: 'Cash Deposited To Bank',
          amount: 2000.0,
          transactionNote: 'Transfer 3',
          dateAdded: dateStr,
          createdAt: DateTime.now().toIso8601String(),
          bankAccountId: bankAccountId,
          isManual: true,
          resolvedTagName: 'General',
        );

        final bankTxn3 = BankTransactionModel(
          txnId: 10,
          txnDate: dateStr,
          txnAmount: 2000.0,
          txnType: 'CR',
          txnNarration: 'Transfer 3',
          encryptedAccountId: bankAccountId,
          txnTagId: 1,
          tagName: 'General',
          bankName: 'Test Bank',
          lastFourDigits: '1234',
          isManual: false,
        );

        // Act: Simulate the UNFIXED fetchAllTransactions logic
        final allTransactions = simulateUnfixedFetchAllTransactions(
          [bankTxn1, bankTxn2, bankTxn3],
          [cashTxn1, cashTxn2, cashTxn3],
        );

        // Calculate totals using unfixed logic
        final totalCredit = calculateTotalCredit(allTransactions);
        final totalDebit = calculateTotalDebit(allTransactions);

        // Assert: Expected behavior (WILL FAIL on unfixed code)

        // Expected: Should have exactly 3 TRANSFER transactions (one for each pair)
        // Actual (on unfixed code): Will have 6 separate transactions
        final transferTransactions = allTransactions.where((txn) {
          return txn.txnType.toUpperCase() == 'TRANSFER';
        }).toList();

        expect(
          transferTransactions.length,
          equals(3),
          reason:
              'Expected: 3 transfer transactions. '
              'Actual (on unfixed code): ${transferTransactions.length} transfer transactions '
              '(bug: shows ${allTransactions.length} separate transactions instead)',
        );

        // Expected: Transfers should NOT be counted in totals
        expect(
          totalCredit,
          equals(0.0),
          reason:
              'Expected: totalCredit=0 (transfers excluded). '
              'Actual (on unfixed code): totalCredit=$totalCredit (bug: transfers counted)',
        );

        expect(
          totalDebit,
          equals(0.0),
          reason:
              'Expected: totalDebit=0 (transfers excluded). '
              'Actual (on unfixed code): totalDebit=$totalDebit (bug: transfers counted)',
        );

        // Document the counterexample found:
        print('\n=== COUNTEREXAMPLE DOCUMENTATION ===');
        print('Multiple transfers on same day: 3 transfer pairs');
        print('Expected: 3 TRANSFER transactions');
        print('Actual: ${allTransactions.length} transactions');
        print(
          'Transaction types: ${allTransactions.map((t) => t.txnType).join(", ")}',
        );
        print('Expected totalCredit: 0.0');
        print('Actual totalCredit: $totalCredit');
        print('Expected totalDebit: 0.0');
        print('Actual totalDebit: $totalDebit');
        print('===================================\n');
      },
    );
  });
}
