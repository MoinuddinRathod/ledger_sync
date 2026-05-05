import 'dart:developer';

import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/utils/app_constants.dart';
import '../../home/controllers/review_transactions_controller.dart';
import '../../home/parsers/parse_result.dart';
import '../models/bank_transaction_model.dart';

class TransactionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ─────────────────────────────────────────────────────────
  // WRITE
  // ─────────────────────────────────────────────────────────

  /// Insert a single transaction map into the DB.
  Future<int> addTransaction(Map<String, dynamic> data) async {
    return await _db.insertTransaction(data);
  }

  /// Bulk-insert all [MappableTransaction] objects while preventing duplicates.
  ///
  /// **Duplicate check logic:**
  /// - Same `TXN_REF` (your unique transaction reference)
  /// - Same `TXN_ACCOUNT_ID` (bank account)
  /// - Same `TXN_DATE` + `TXN_AMOUNT` + `TXN_TYPE` as fallback
  ///
  /// Returns: number of **newly inserted** transactions (or -1 on error)
  Future<int> addBulkTransactions(List<MappableTransaction> list) async {
    if (list.isEmpty) return 0;

    try {
      final db = await _db.database;
      int insertedCount = 0;
      final touchedAccounts = <String>{};

      // ── Step 1: Fetch all existing refs and composites in BULK ────────
      // Instead of N individual queries inside the loop,
      // pull all existing txn refs for these accounts in one query.
      final accountNumbers = list
          .map((t) => t.bankAccountNumber)
          .where((a) => a.isNotEmpty)
          .toSet()
          .toList();

      if (accountNumbers.isEmpty) return 0;

      // Fetch all existing refs for these accounts in one shot
      final placeholders = accountNumbers.map((_) => '?').join(',');
      final existingRows = await db.rawQuery('''
      SELECT $TXN_REF, $TXN_ACCOUNT_ID, $TXN_DATE, $TXN_AMOUNT, 
             UPPER($TXN_TYPE) as $TXN_TYPE, $TXN_NARRATION
      FROM $TABLE_TRANSACTIONS
      WHERE $TXN_ACCOUNT_ID IN ($placeholders)
        AND $DELETED_AT IS NULL
      ''', accountNumbers);

      // Build in-memory lookup sets for O(1) dedup checks
      final existingRefs = <String>{};
      final existingComposites = <String>{};

      for (final row in existingRows) {
        final ref = (row[TXN_REF] as String?) ?? '';
        if (ref.isNotEmpty) existingRefs.add(ref);

        // Composite key: accountId|date|amount|type|narrationHash
        final compositeKey = _buildCompositeKey(
          accountNumber: (row[TXN_ACCOUNT_ID] as String?) ?? '',
          date: (row[TXN_DATE] as String?) ?? '',
          amount: ((row[TXN_AMOUNT] as num?) ?? 0).toDouble(),
          type: (row[TXN_TYPE] as String?) ?? '',
          narration: (row[TXN_NARRATION] as String?) ?? '',
        );
        existingComposites.add(compositeKey);
      }

      // ── Step 2: Insert in a single DB transaction ─────────────────────
      await db.transaction((txn) async {
        for (final item in list) {
          final map = item.toMap();
          final accountNumber = (map[TXN_ACCOUNT_ID] as String?) ?? '';
          if (accountNumber.isEmpty) continue;

          final txnRef = (map[TXN_REF] as String?) ?? '';

          // Check ref dedup
          if (txnRef.isNotEmpty && existingRefs.contains(txnRef)) {
            log('Duplicate by ref skipped: $txnRef');
            continue;
          }

          // Check composite dedup
          final compositeKey = _buildCompositeKey(
            accountNumber: accountNumber,
            date: (map[TXN_DATE] as String?) ?? '',
            amount: ((map[TXN_AMOUNT] as num?) ?? 0).toDouble(),
            type: (map[TXN_TYPE] as String?) ?? '',
            narration: (map[TXN_NARRATION] as String?) ?? '',
          );
          if (existingComposites.contains(compositeKey)) {
            log('Duplicate by composite skipped: $txnRef');
            continue;
          }

          // Insert inside the transaction object — this is the key fix
          // Using txn.insert NOT db.insert avoids lock contention
          final saved = await txn.insert(TABLE_TRANSACTIONS, map);
          if (saved > 0) {
            insertedCount++;
            touchedAccounts.add(accountNumber);
            // Add to in-memory sets to catch duplicates within the same import
            if (txnRef.isNotEmpty) existingRefs.add(txnRef);
            existingComposites.add(compositeKey);
          }
        }
      });

      return insertedCount;
    } catch (e) {
      log('addBulkTransactions error: $e');
      return -1;
    }
  }

  /// Builds a deterministic composite dedup key from transaction fields.
  String _buildCompositeKey({
    required String accountNumber,
    required String date,
    required double amount,
    required String type,
    required String narration,
  }) {
    final normalizedNarration = narration.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return '$accountNumber|$date|${amount.toStringAsFixed(2)}|${type.toUpperCase()}|$normalizedNarration';
  }

  /// Soft-delete a transaction (sets deleted_at). Returns rows affected.
  Future<int> softDelete(int txnId) async {
    if (txnId <= 0) {
      log('softDelete: invalid txnId $txnId');
      return -1;
    }
    return await _db.softDeleteTransaction(txnId);
  }

  // ─────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────

  /// Return all non-deleted transactions for [encryptedAccountNumber],
  /// with tag name and bank info joined in.
  Future<List<BankTransactionModel>> getByAccount(
    String encryptedAccountNumber,
  ) async {
    if (encryptedAccountNumber.trim().isEmpty) {
      log('getByAccount: encryptedAccountNumber is empty');
      return [];
    }
    try {
      final rows = await _db.getTransactionsByAccount(encryptedAccountNumber);
      return rows.map(BankTransactionModel.fromMap).toList();
    } catch (e) {
      log('getByAccount error: $e');
      return [];
    }
  }

  /// Return all non-deleted transactions that belong to [tagId],
  /// scoped to bank accounts owned by [masterAccountId].
  Future<List<BankTransactionModel>> getByTagId(
    int tagId,
    int masterAccountId,
  ) async {
    if (tagId <= 0) {
      log('getByTagId: invalid tagId $tagId');
      return [];
    }
    if (masterAccountId <= 0) {
      log('getByTagId: invalid masterAccountId $masterAccountId');
      return [];
    }
    try {
      final rows = await _db.getTransactionsByTagId(tagId, masterAccountId);
      return rows.map(BankTransactionModel.fromMap).toList();
    } catch (e) {
      log('getByTagId error: $e');
      return [];
    }
  }

  /// Returns { tagId → count } for all tags with at least one transaction
  /// in [masterAccountId]'s bank accounts.
  Future<Map<int, int>> getCountsByTag(int masterAccountId) async {
    if (masterAccountId <= 0) {
      log('getCountsByTag: invalid masterAccountId $masterAccountId');
      return {};
    }
    try {
      return await _db.getTagTransactionCounts(masterAccountId);
    } catch (e) {
      log('getCountsByTag error: $e');
      return {};
    }
  }

  /// --- Get by account id
  Future<List<BankTransactionModel>> getByAccountId(int accountId) async {
    if (accountId <= 0) {
      log('getByAccountId: invalid accountId $accountId');
      return [];
    }
    try {
      final rows = await _db.getTransactionsByAccountId(accountId);
      return rows.map(BankTransactionModel.fromMap).toList();
    } catch (e) {
      log('getByAccountId error: $e');
      return [];
    }
  }

  Future<int> saveStatementImportSassion({
    required ParseResult result,
    required String bankAccountNumber,
  }) async {
    if (result.fromDate == null) return -1;

    // ── Derive correct opening balance ──────────────────────────────────
    // Priority 1: explicit opening balance row from parser
    // Priority 2: derive from first transaction's running balance
    double? openingBalance = result.initialBalance;

    if (openingBalance == null && result.transactions.isNotEmpty) {
      final sorted = List.from(result.transactions)
        ..sort((a, b) => a.date.compareTo(b.date));
      final first = sorted.first;
      if (first.balance != null) {
        // DR: balance = opening - amount → opening = balance + amount
        // CR: balance = opening + amount → opening = balance - amount
        openingBalance = first.type == 'Cr'
            ? first.balance! - first.amount
            : first.balance! + first.amount;
      }
    }

    if (openingBalance == null) return -1; // cannot proceed without opening

    // ── Insert or correct existing session ──────────────────────────────
    final existing = await _db.getImportSession(
      bankAccountNumber: bankAccountNumber,
      fromDate: result.fromDate!,
      toDate: result.toDate ?? result.fromDate!,
    );

    if (existing == null) {
      return await _db.insertImportSession(
        bankAccountNumber: bankAccountNumber,
        openingBalance: openingBalance,
        fromDate: result.fromDate!,
        toDate: result.toDate ?? result.fromDate!,
      );
    } else {
      // Correct stale opening balance on re-import
      await _db.updateImportSessionOpeningBalance(
        sessionId: existing[IMPORT_SESSION_ID] as int,
        openingBalance: openingBalance,
      );
      return existing[IMPORT_SESSION_ID] as int;
    }
    // NOTE: do NOT call recomputeAndSave here.
    // Transactions are inserted AFTER this call in saveTransactions().
    // recomputeAndSave is called in review_transactions_controller.dart
    // after addBulkTransactions() completes.
  }

  Future<String?> validateOpeningBalanceContinuity({
    required ParseResult result,
    required String bankAccountNumber,
  }) async {
    if (result.fromDate == null || result.initialBalance == null) return null;
    final expected = await _db.expectedOpeningBalanceAtDate(
      bankAccountNumber: bankAccountNumber,
      fromDate: result.fromDate!,
    );
    if (expected == null) return null;
    final actual = result.initialBalance!;
    if ((expected - actual).abs() <= 0.01) return null;
    return 'Opening balance mismatch for ${result.fromDate}: expected ${expected.toStringAsFixed(2)}, imported ${actual.toStringAsFixed(2)}.';
  }

  Future<bool> hasOverlappingImportRange({
    required ParseResult result,
    required String bankAccountNumber,
  }) async {
    if (result.fromDate == null) return false;
    return _db.hasOverlappingImportSession(
      bankAccountNumber: bankAccountNumber,
      fromDate: result.fromDate!,
      toDate: result.toDate ?? result.fromDate!,
    );
  }

  Future<double> recomputeAndSave(String bankAccountNumber) {
    return _db.recomputeAndSave(bankAccountNumber);
  }
}
