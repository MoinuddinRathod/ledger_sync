import 'dart:developer';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';

import '../../../features/bank_account/models/bank_account_model.dart';
import '../../../features/master_account/models/account_model.dart';
import '../../../features/tags/models/tag_model.dart';
import '../../utils/app_constants.dart';

class DatabaseHelper {
  // make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // only have a single app-wide reference to the database
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), LEDGER_SYNC_DB);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('PRAGMA foreign_keys = ON');

        // ---  TABLES  ---
        await db.execute('''
      CREATE TABLE $TABLE_ACCOUNTS (
        $ACCOUNT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $ACCOUNT_NAME TEXT NOT NULL,
        $ACCOUNT_PIN TEXT NOT NULL,
        $CREATED_AT TEXT NOT NULL,
        $UPDATED_AT TEXT,
        $DELETED_AT TEXT,
        $IS_DEFAULT INTEGER NOT NULL
      )
    ''');

        // ------- bank accounts table ------- //
        await db.execute('''
      CREATE TABLE $TABLE_BANK_ACCOUNTS (
        $BANK_ACCOUNT_NUMBER TEXT PRIMARY KEY,
        $LAST_FOUR_DIGITS TEXT NOT NULL,
        $ACCOUNT_ID INTEGER NOT NULL,
        $BANK_NAME TEXT NOT NULL,
        $ACCOUNT_HOLDER_NAME TEXT NOT NULL,
        $ACCOUNT_TYPE TEXT NOT NULL,
        $CURRENT_BALANCE REAL NOT NULL,
        $DATE_ADDED TEXT NOT NULL,
        $CREATED_AT TEXT NOT NULL,
        $UPDATED_AT TEXT,
        $DELETED_AT TEXT,
        $IS_ACTIVE INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY ($ACCOUNT_ID) REFERENCES $TABLE_ACCOUNTS($ACCOUNT_ID)
      )
    ''');

        // ---- cash wallet table ---- //
        await db.execute('''
      CREATE TABLE $TABLE_CASH_WALLET (
        $CASH_WALLET_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $ACCOUNT_ID INTEGER NOT NULL,
        $CASH_WALLET_CURRENT_BALANCE REAL NOT NULL,
        $DATE_ADDED TEXT NOT NULL,
        $CREATED_AT TEXT NOT NULL,
        $UPDATED_AT TEXT,
        $DELETED_AT TEXT,
        FOREIGN KEY ($ACCOUNT_ID) REFERENCES $TABLE_ACCOUNTS($ACCOUNT_ID)
      )
    ''');

        // ------- cash wallet transactions table ------- //
        await db.execute('''
      CREATE TABLE $TABLE_CASH_WALLET_TRANSACTIONS (
        $CASH_WALLET_TRANSACTION_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $ACCOUNT_ID INTEGER NOT NULL,
        $CASH_WALLET_TRANSACTION_TYPE TEXT NOT NULL,
        $AMOUNT REAL NOT NULL,
        $CASH_WALLET_TRANSACTION_TAG_ID INTEGER NOT NULL,
        $TRANSACTION_NOTE TEXT,
        $DATE_ADDED TEXT NOT NULL,
        $CREATED_AT TEXT NOT NULL,
        $UPDATED_AT TEXT,
        $DELETED_AT TEXT,
        $CASH_WALLET_TRANSACTION_BANK_ACCOUNT_ID TEXT,
        $CASH_WALLET_IS_MANUAL INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY ($ACCOUNT_ID) REFERENCES $TABLE_ACCOUNTS($ACCOUNT_ID),
        FOREIGN KEY ($CASH_WALLET_TRANSACTION_TAG_ID) REFERENCES $TABLE_TAGS($TAG_ID)
      )
    ''');

        // ------- virtual entries table ------- //
        await db.execute('''
      CREATE TABLE $TABLE_VIRTUAL_ENTRIES (
        $VIRTUAL_ENTRY_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $VE_ACCOUNT_ID INTEGER NOT NULL,
        $VE_TAG_ID INTEGER NOT NULL,
        $VE_ENTRY_TYPE TEXT NOT NULL,
        $VE_AMOUNT REAL NOT NULL,
        $VE_NOTE TEXT,
        $VE_DATE_ADDED TEXT NOT NULL,
        $VE_CREATED_AT TEXT NOT NULL,
        $VE_UPDATED_AT TEXT,
        $VE_DELETED_AT TEXT,
        $VE_STATUS TEXT NOT NULL DEFAULT 'pending',
        $VE_MATCHED_TXN_ID INTEGER,
        $VE_DUE_DATE TEXT,
        FOREIGN KEY ($VE_ACCOUNT_ID) REFERENCES $TABLE_ACCOUNTS($ACCOUNT_ID),
        FOREIGN KEY ($VE_TAG_ID) REFERENCES $TABLE_TAGS($TAG_ID),
        FOREIGN KEY ($VE_MATCHED_TXN_ID) REFERENCES $TABLE_TRANSACTIONS($TXN_ID)
      )
    ''');

        // ------- tags table ------- //
        await db.execute('''
      CREATE TABLE $TABLE_TAGS (
        $TAG_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $TAG_NAME TEXT NOT NULL,
        $TAG_KEYWORDS TEXT NOT NULL,
        $TAG_PRIORITY INTEGER NOT NULL,
        $TAG_BANK_ACCOUNT_ID TEXT,
        $TAG_USER_ID INTEGER,
        $TAG_CREATED_AT TEXT NOT NULL,
        $TAG_UPDATED_AT TEXT,
        $TAG_DELETED_AT TEXT,
        FOREIGN KEY ($TAG_BANK_ACCOUNT_ID) REFERENCES $TABLE_BANK_ACCOUNTS($BANK_ACCOUNT_NUMBER),
        FOREIGN KEY ($TAG_USER_ID) REFERENCES $TABLE_ACCOUNTS($ACCOUNT_ID)
      )
    ''');

        // -------- transactons table -------- //
        await db.execute('''
      CREATE TABLE $TABLE_TRANSACTIONS (
        $TXN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        $TXN_DATE TEXT NOT NULL,
        $TXN_ACCOUNT_ID INTEGER NOT NULL,
        $TXN_TAG_ID INTEGER NOT NULL,
        $TXN_AMOUNT REAL NOT NULL,
        $TXN_NARRATION TEXT NOT NULL,
        $TXN_TYPE TEXT NOT NULL,
        $TXN_REF TEXT NOT NULL,
        $TXN_IS_MANUAL INTEGER DEFAULT 0,
        $CREATED_AT TEXT NOT NULL,
        $UPDATED_AT TEXT,
        $DELETED_AT TEXT,
        FOREIGN KEY ($TXN_ACCOUNT_ID) REFERENCES $TABLE_BANK_ACCOUNTS($BANK_ACCOUNT_NUMBER),
        FOREIGN KEY ($TXN_TAG_ID) REFERENCES $TABLE_TAGS($TAG_ID)
      )
    ''');

        await db.execute('''
  CREATE TABLE $TABLE_IMPORT_SESSIONS (
    $IMPORT_SESSION_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    $IMPORT_BANK_ACCOUNT_NUMBER TEXT NOT NULL,
    $IMPORT_OPENING_BALANCE REAL NOT NULL,
    $IMPORT_FROM_DATE TEXT NOT NULL,
    $IMPORT_TO_DATE TEXT NOT NULL,
    $IMPORT_CREATED_AT TEXT NOT NULL,
    FOREIGN KEY ($IMPORT_BANK_ACCOUNT_NUMBER)
      REFERENCES $TABLE_BANK_ACCOUNTS($BANK_ACCOUNT_NUMBER)
  )
''');
      },

      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ============================================================
  // ALL QUERY METHODS
  // ============================================================
  bool _isValidAccountId(int accountId) => accountId > 0;

  // ------- insert account -------- //
  Future<int> insertAccount(AccountModel account) async {
    try {
      final db = await instance.database;
      return await db.insert(TABLE_ACCOUNTS, account.toMap());
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return -1;
    }
  }

  // ------- check login -------- //
  Future<int> checkLogin(String accountName, String pin) async {
    try {
      final db = await instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        TABLE_ACCOUNTS,
        where: '$ACCOUNT_NAME = ? AND $ACCOUNT_PIN = ?',
        whereArgs: [accountName, pin],
      );
      return maps.isNotEmpty ? maps.first[ACCOUNT_ID] : -1;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return -1;
    }
  }

  // ------- get all accounts -------- //
  Future<List<AccountModel>> getAllAccounts() async {
    try {
      final db = await instance.database;
      final List<Map<String, dynamic>> maps = await db.query(TABLE_ACCOUNTS);
      return List.generate(maps.length, (i) {
        return AccountModel.fromMap(maps[i]);
      });
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return [];
    }
  }

  // ---- see if account present with same account holder name ---- //

  // -------- insert bank account ------------- //
  Future<int> insertBankAccount(BankAccountModel model) async {
    final db = await instance.database;
    return await db.insert(TABLE_BANK_ACCOUNTS, model.toMap());
  }

  // -------- get bank accounts for a specific account ------------- //
  Future<List<BankAccountModel>> getBankAccounts(int accountId) async {
    final db = await instance.database;
    final result = await db.query(
      TABLE_BANK_ACCOUNTS,
      where: "$ACCOUNT_ID = ?",
      whereArgs: [accountId],
    );
    return result.map((e) => BankAccountModel.fromMap(e)).toList();
  }

  // -------- update bank account ------------- //
  Future<int> updateBankAccount(
    BankAccountModel model,
    String oldEncryptedAccountNumber,
    int accountId,
  ) async {
    if (!_isValidAccountId(accountId)) return 0;
    final db = await instance.database;
    return await db.update(
      TABLE_BANK_ACCOUNTS,
      model.toMap(),
      where: "$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?",
      whereArgs: [oldEncryptedAccountNumber, accountId],
    );
  }

  Future<void> updateBankAccountBalance(
    String bankAccountNumber,
    double newBalance, {
    int? accountId,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await instance.database;
    if (accountId != null && !_isValidAccountId(accountId)) return;
    final whereClause = accountId == null
        ? '$BANK_ACCOUNT_NUMBER = ?'
        : '$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?';
    final whereArgs = accountId == null
        ? [bankAccountNumber]
        : [bankAccountNumber, accountId];
    await db.update(
      TABLE_BANK_ACCOUNTS,
      {
        CURRENT_BALANCE: newBalance,
        UPDATED_AT: DateTime.now().toIso8601String(),
      },
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  // -------- delete bank account ------------- //
  @Deprecated(
    'Use toggleBankAccountActive or permanentlyDeleteBankAccount instead',
  )
  Future<int> deleteBankAccount(
    String encryptedAccountNumber,
    int accountId,
  ) async {
    if (!_isValidAccountId(accountId)) return 0;
    final db = await instance.database;
    return await db.update(
      TABLE_BANK_ACCOUNTS,
      {DELETED_AT: DateTime.now().toIso8601String()},
      where: "$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?",
      whereArgs: [encryptedAccountNumber, accountId],
    );
  }

  // -------- toggle bank account active state ------------- //
  Future<int> toggleBankAccountActive(
    String encryptedAccountNumber,
    bool isActive,
    int accountId,
  ) async {
    if (!_isValidAccountId(accountId)) return 0;
    final db = await instance.database;
    return await db.update(
      TABLE_BANK_ACCOUNTS,
      {
        IS_ACTIVE: isActive ? 1 : 0,
        UPDATED_AT: DateTime.now().toIso8601String(),
      },
      where: "$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?",
      whereArgs: [encryptedAccountNumber, accountId],
    );
  }

  // -------- permanently delete bank account ------------- //
  Future<int> permanentlyDeleteBankAccount(
    String encryptedAccountNumber,
    int accountId,
  ) async {
    if (!_isValidAccountId(accountId)) return 0;
    final db = await instance.database;

    return await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // Step 1: Soft-delete all linked transactions
      await txn.update(
        TABLE_TRANSACTIONS,
        {DELETED_AT: now},
        where: "$TXN_ACCOUNT_ID = ?",
        whereArgs: [encryptedAccountNumber],
      );

      // Step 2: Hard-delete all linked import_sessions
      await txn.delete(
        TABLE_IMPORT_SESSIONS,
        where: "$IMPORT_BANK_ACCOUNT_NUMBER = ?",
        whereArgs: [encryptedAccountNumber],
      );

      // Step 3: Soft-delete all bank-scoped tags
      await txn.update(
        TABLE_TAGS,
        {TAG_DELETED_AT: now},
        where: "$TAG_BANK_ACCOUNT_ID = ?",
        whereArgs: [encryptedAccountNumber],
      );

      // Step 4: Hard-delete the bank_account row
      final rowsDeleted = await txn.delete(
        TABLE_BANK_ACCOUNTS,
        where: "$BANK_ACCOUNT_NUMBER = ? AND $ACCOUNT_ID = ?",
        whereArgs: [encryptedAccountNumber, accountId],
      );

      return rowsDeleted;
    });
  }

  // =========================================== //
  // --------- CASH WALLET ------------- //
  // =========================================== //

  // -------- insert cash wallet ------------- //
  Future<int> insertCashWallet(
    Map<String, dynamic> data, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await instance.database;
    return await db.insert(TABLE_CASH_WALLET, data);
  }

  // -------- get cash wallet by account id ------------- //
  Future<Map<String, dynamic>?> getCashWallet(
    int accountId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await instance.database;
    final result = await db.query(
      TABLE_CASH_WALLET,
      where: "$ACCOUNT_ID = ? AND $DELETED_AT IS NULL",
      whereArgs: [accountId],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // -------- update cash wallet ------------- //
  Future<int> updateCashWalletBalance(
    int accountId,
    double newBalance, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await instance.database;
    return await db.update(
      TABLE_CASH_WALLET,
      {
        CASH_WALLET_CURRENT_BALANCE: newBalance,
        UPDATED_AT: DateTime.now().toIso8601String(),
      },
      where: "$ACCOUNT_ID = ?",
      whereArgs: [accountId],
    );
  }

  // -------- insert cash wallet transaction ------------- //
  Future<int> insertCashWalletTransaction(
    Map<String, dynamic> data, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await instance.database;
    return await db.insert(TABLE_CASH_WALLET_TRANSACTIONS, data);
  }

  // -------- get cash wallet transactions ------------- //
  Future<List<Map<String, dynamic>>> getCashWalletTransactions(
    int accountId,
  ) async {
    final db = await instance.database;
    final String query =
        '''
      SELECT cw.*, cw.$CASH_WALLET_TRANSACTION_BANK_ACCOUNT_ID, t.$TAG_NAME as resolvedTagName
      FROM $TABLE_CASH_WALLET_TRANSACTIONS cw
      LEFT JOIN $TABLE_TAGS t ON cw.$CASH_WALLET_TRANSACTION_TAG_ID = t.$TAG_ID
      WHERE cw.$ACCOUNT_ID = ? AND cw.$DELETED_AT IS NULL
      ORDER BY cw.$DATE_ADDED DESC, cw.$CASH_WALLET_TRANSACTION_ID DESC
    ''';
    return await db.rawQuery(query, [accountId]);
  }

  // -------- update cash wallet transaction ------------- //
  Future<int> updateCashWalletTransaction(
    Map<String, dynamic> data,
    int transactionId,
    int accountId,
  ) async {
    if (!_isValidAccountId(accountId)) return 0;
    final db = await instance.database;
    return await db.update(
      TABLE_CASH_WALLET_TRANSACTIONS,
      data,
      where: "$CASH_WALLET_TRANSACTION_ID = ? AND $ACCOUNT_ID = ?",
      whereArgs: [transactionId, accountId],
    );
  }

  // -------- delete cash wallet transaction ------------- //
  Future<int> deleteCashWalletTransaction(
    int transactionId,
    int accountId,
  ) async {
    if (!_isValidAccountId(accountId)) return 0;
    final db = await instance.database;
    return await db.update(
      TABLE_CASH_WALLET_TRANSACTIONS,
      {DELETED_AT: DateTime.now().toIso8601String()},
      where: "$CASH_WALLET_TRANSACTION_ID = ? AND $ACCOUNT_ID = ?",
      whereArgs: [transactionId, accountId],
    );
  }

  // =========================================== //
  // --------- VIRTUAL ENTRIES ----------------- //
  // =========================================== //

  Future<int> insertVirtualEntry(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert(TABLE_VIRTUAL_ENTRIES, data);
  }

  Future<List<Map<String, dynamic>>> getVirtualEntries(int accountId) async {
    final db = await instance.database;
    final String query =
        '''
      SELECT ve.*, t.$TAG_NAME as resolvedTagName
      FROM $TABLE_VIRTUAL_ENTRIES ve
      LEFT JOIN $TABLE_TAGS t ON ve.$VE_TAG_ID = t.$TAG_ID
      WHERE ve.$VE_ACCOUNT_ID = ? AND ve.$VE_DELETED_AT IS NULL
      ORDER BY ve.$VE_CREATED_AT DESC
    ''';
    return await db.rawQuery(query, [accountId]);
  }

  Future<int> updateVirtualEntry(
    Map<String, dynamic> data,
    int virtualEntryId,
    int accountId,
  ) async {
    if (!_isValidAccountId(accountId)) return 0;
    final db = await instance.database;
    return await db.update(
      TABLE_VIRTUAL_ENTRIES,
      data,
      where: "$VIRTUAL_ENTRY_ID = ? AND $VE_ACCOUNT_ID = ?",
      whereArgs: [virtualEntryId, accountId],
    );
  }

  Future<int> softDeleteVirtualEntry(int virtualEntryId, int accountId) async {
    if (!_isValidAccountId(accountId)) return 0;
    final db = await instance.database;
    return await db.update(
      TABLE_VIRTUAL_ENTRIES,
      {VE_DELETED_AT: DateTime.now().toIso8601String()},
      where: "$VIRTUAL_ENTRY_ID = ? AND $VE_ACCOUNT_ID = ?",
      whereArgs: [virtualEntryId, accountId],
    );
  }

  // =========================================== //
  // --------- TAGS ------------- //
  // =========================================== //

  // -------- insert tag ------------- //
  Future<int> insertTag(TagModel model) async {
    try {
      final db = await instance.database;
      return await db.insert(TABLE_TAGS, model.toMap());
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return -1;
    }
  }

  // -------- get all tags (global — no account/bank filter) ------------- //
  Future<List<TagModel>> getAllTags(int userId) async {
    try {
      if (!_isValidAccountId(userId)) return [];
      final db = await instance.database;
      final result = await db.rawQuery(
        '''
        SELECT
          tg.*,
          COALESCE(SUM(CASE WHEN UPPER(t.$TXN_TYPE) = 'DR' THEN t.$TXN_AMOUNT ELSE 0 END), 0.0) as totalDr,
          COALESCE(SUM(CASE WHEN UPPER(t.$TXN_TYPE) = 'CR' THEN t.$TXN_AMOUNT ELSE 0 END), 0.0) as totalCr
        FROM $TABLE_TAGS tg
        LEFT JOIN $TABLE_TRANSACTIONS t ON tg.$TAG_ID = t.$TXN_TAG_ID AND t.$DELETED_AT IS NULL
        WHERE tg.$TAG_USER_ID = ? AND tg.$TAG_DELETED_AT IS NULL
        GROUP BY tg.$TAG_ID
        ORDER BY tg.$TAG_PRIORITY ASC
      ''',
        [userId],
      );
      log(
        "here is all tags presents : : : : ::  :: :: : : : : ${result.toList()}",
      );
      return result.map((e) => TagModel.fromMap(e)).toList();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return [];
    }
  }

  // -------- get tags by user id (account-level) ------------- //
  Future<List<TagModel>> getTagsByUserId(int userId) async {
    try {
      if (!_isValidAccountId(userId)) return [];
      final db = await instance.database;
      final result = await db.rawQuery(
        '''
        SELECT 
          tg.*,
          COALESCE(SUM(CASE WHEN UPPER(t.$TXN_TYPE) = 'DR' THEN t.$TXN_AMOUNT ELSE 0 END), 0.0) as totalDr,
          COALESCE(SUM(CASE WHEN UPPER(t.$TXN_TYPE) = 'CR' THEN t.$TXN_AMOUNT ELSE 0 END), 0.0) as totalCr
        FROM $TABLE_TAGS tg
        LEFT JOIN $TABLE_TRANSACTIONS t ON tg.$TAG_ID = t.$TXN_TAG_ID AND t.$DELETED_AT IS NULL
        WHERE tg.$TAG_USER_ID = ? AND tg.$TAG_DELETED_AT IS NULL
        GROUP BY tg.$TAG_ID
        ORDER BY tg.$TAG_PRIORITY ASC
      ''',
        [userId],
      );
      return result.map((e) => TagModel.fromMap(e)).toList();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return [];
    }
  }

  // -------- get tags by bank account id (account-level) ------------- //
  Future<List<TagModel>> getTagsByBankAccountId(
    String bankAccountId,
    int userId,
  ) async {
    try {
      if (!_isValidAccountId(userId)) return [];
      final db = await instance.database;
      final result = await db.rawQuery(
        '''
        SELECT 
          tg.*,
          COALESCE(SUM(CASE WHEN UPPER(t.$TXN_TYPE) = 'DR' THEN t.$TXN_AMOUNT ELSE 0 END), 0.0) as totalDr,
          COALESCE(SUM(CASE WHEN UPPER(t.$TXN_TYPE) = 'CR' THEN t.$TXN_AMOUNT ELSE 0 END), 0.0) as totalCr
        FROM $TABLE_TAGS tg
        LEFT JOIN $TABLE_TRANSACTIONS t ON tg.$TAG_ID = t.$TXN_TAG_ID AND t.$DELETED_AT IS NULL
        WHERE tg.$TAG_BANK_ACCOUNT_ID = ?
          AND tg.$TAG_USER_ID = ?
          AND tg.$TAG_DELETED_AT IS NULL
        GROUP BY tg.$TAG_ID
        ORDER BY tg.$TAG_PRIORITY ASC
      ''',
        [bankAccountId, userId],
      );
      return result.map((e) => TagModel.fromMap(e)).toList();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return [];
    }
  }

  // -------- update tag ------------- //
  Future<int> updateTag(TagModel model, int userId) async {
    try {
      if (!_isValidAccountId(userId)) return 0;
      final db = await instance.database;
      return await db.update(
        TABLE_TAGS,
        model.toMap(),
        where: "$TAG_ID = ? AND $TAG_USER_ID = ?",
        whereArgs: [model.tagId, userId],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return -1;
    }
  }

  // -------- soft delete tag ------------- //
  Future<int> deleteTag(int tagId, int userId) async {
    try {
      if (!_isValidAccountId(userId)) return 0;
      final db = await instance.database;
      return await db.update(
        TABLE_TAGS,
        {TAG_DELETED_AT: DateTime.now().toIso8601String()},
        where: "$TAG_ID = ? AND $TAG_USER_ID = ?",
        whereArgs: [tagId, userId],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return -1;
    }
  }

  // =========================================== //
  // --------- TRANSACTIONS READ ------------- //
  // =========================================== //

  /// Fetch all non-deleted transactions for a single bank account,
  /// joined with [TABLE_TAGS] (for tag name) and [TABLE_BANK_ACCOUNTS]
  /// (for display info). Ordered newest-first.
  Future<List<Map<String, dynamic>>> getTransactionsByAccount(
    String encryptedAccountNumber,
    int masterAccountId,
  ) async {
    try {
      if (encryptedAccountNumber.isEmpty ||
          !_isValidAccountId(masterAccountId)) {
        return [];
      }
      final db = await instance.database;
      return await db.rawQuery(
        '''
        SELECT
          t.$TXN_ID,
          t.$TXN_DATE,
          t.$TXN_AMOUNT,
          t.$TXN_TYPE,
          t.$TXN_NARRATION,
          t.$TXN_ACCOUNT_ID,
          t.$TXN_TAG_ID,
          tg.$TAG_NAME,
          ba.$BANK_NAME,
          ba.$LAST_FOUR_DIGITS,
          ba.$ACCOUNT_HOLDER_NAME
        FROM $TABLE_TRANSACTIONS t
        LEFT JOIN $TABLE_TAGS tg
          ON t.$TXN_TAG_ID = tg.$TAG_ID
          AND tg.$TAG_DELETED_AT IS NULL
        LEFT JOIN $TABLE_BANK_ACCOUNTS ba
          ON t.$TXN_ACCOUNT_ID = ba.$BANK_ACCOUNT_NUMBER
          AND ba.$DELETED_AT IS NULL
        WHERE t.$TXN_ACCOUNT_ID = ?
          AND t.$TXN_ACCOUNT_ID IN (
            SELECT $BANK_ACCOUNT_NUMBER
            FROM $TABLE_BANK_ACCOUNTS
            WHERE $ACCOUNT_ID = ?
              AND $DELETED_AT IS NULL
          )
          AND t.$DELETED_AT IS NULL
        ORDER BY t.$TXN_DATE DESC, t.$TXN_ID DESC
        ''',
        [encryptedAccountNumber, masterAccountId],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('getTransactionsByAccount error: $e');
      return [];
    }
  }

  /// Fetch all non-deleted transactions for a given [tagId],
  /// scoped to bank accounts owned by [masterAccountId].
  /// Joined with [TABLE_TAGS] and [TABLE_BANK_ACCOUNTS].
  Future<List<Map<String, dynamic>>> getTransactionsByTagId(
    int tagId,
    int masterAccountId,
  ) async {
    try {
      if (tagId <= 0 || masterAccountId <= 0) return [];
      final db = await instance.database;
      return await db.rawQuery(
        '''
        SELECT
          t.$TXN_ID,
          t.$TXN_DATE,
          t.$TXN_AMOUNT,
          t.$TXN_TYPE,
          t.$TXN_NARRATION,
          t.$TXN_ACCOUNT_ID,
          t.$TXN_TAG_ID,
          t.$TXN_IS_MANUAL,
          t.$TXN_REF,
          tg.$TAG_NAME,
          ba.$BANK_NAME,
          ba.$LAST_FOUR_DIGITS,
          ba.$ACCOUNT_HOLDER_NAME
        FROM $TABLE_TRANSACTIONS t
        LEFT JOIN $TABLE_TAGS tg
          ON t.$TXN_TAG_ID = tg.$TAG_ID
          AND tg.$TAG_DELETED_AT IS NULL
        LEFT JOIN $TABLE_BANK_ACCOUNTS ba
          ON t.$TXN_ACCOUNT_ID = ba.$BANK_ACCOUNT_NUMBER
          AND ba.$DELETED_AT IS NULL
        WHERE t.$TXN_TAG_ID = ?
          AND t.$TXN_ACCOUNT_ID IN (
            SELECT $BANK_ACCOUNT_NUMBER
            FROM $TABLE_BANK_ACCOUNTS
            WHERE $ACCOUNT_ID = ?
              AND $DELETED_AT IS NULL
          )
          AND t.$DELETED_AT IS NULL
        ORDER BY t.$TXN_DATE DESC, t.$TXN_ID DESC
        ''',
        [tagId, masterAccountId],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('getTransactionsByTagId error: $e');
      return [];
    }
  }

  /// Returns a map of { tagId → transactionCount } for all tags
  /// that have transactions belonging to [masterAccountId]'s bank accounts.
  /// Tags with zero transactions are NOT included (use ?? 0 on the caller side).
  Future<Map<int, int>> getTagTransactionCounts(int masterAccountId) async {
    try {
      if (masterAccountId <= 0) return {};
      final db = await instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT t.$TXN_TAG_ID, COUNT(*) as txn_count
        FROM $TABLE_TRANSACTIONS t
        WHERE t.$TXN_ACCOUNT_ID IN (
          SELECT $BANK_ACCOUNT_NUMBER
          FROM $TABLE_BANK_ACCOUNTS
          WHERE $ACCOUNT_ID = ?
            AND $DELETED_AT IS NULL
        )
        AND t.$DELETED_AT IS NULL
        GROUP BY t.$TXN_TAG_ID
        ''',
        [masterAccountId],
      );
      final Map<int, int> result = {};
      for (final row in rows) {
        final tagId = (row[TXN_TAG_ID] as num?)?.toInt();
        final count = (row['txn_count'] as num?)?.toInt() ?? 0;
        if (tagId != null) result[tagId] = count;
      }
      return result;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('getTagTransactionCounts error: $e');
      return {};
    }
  }

  /// Soft-delete a single transaction by setting its [DELETED_AT] timestamp.
  Future<int> softDeleteTransaction(int txnId, int masterAccountId) async {
    try {
      if (!_isValidAccountId(masterAccountId)) return 0;
      final db = await instance.database;
      return await db.update(
        TABLE_TRANSACTIONS,
        {DELETED_AT: DateTime.now().toIso8601String()},
        where:
            '$TXN_ID = ? AND $TXN_ACCOUNT_ID IN (SELECT $BANK_ACCOUNT_NUMBER FROM $TABLE_BANK_ACCOUNTS WHERE $ACCOUNT_ID = ? AND $DELETED_AT IS NULL)',
        whereArgs: [txnId, masterAccountId],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('softDeleteTransaction error: $e');
      return -1;
    }
  }

  /// Reassign a transaction to a new tag. Returns rows updated (0 = not found).
  Future<int> updateTransactionTag({
    required int txnId,
    required int newTagId,
  }) async {
    try {
      final db = await instance.database;
      return await db.update(
        TABLE_TRANSACTIONS,
        {
          TXN_TAG_ID: newTagId,
          UPDATED_AT: DateTime.now().toIso8601String(),
        },
        where: '$TXN_ID = ? AND $DELETED_AT IS NULL',
        whereArgs: [txnId],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('updateTransactionTag error: $e');
      return -1;
    }
  }

  // --- insert map transaction
  // -------- insert transaction ------------- //
  Future<int> insertTransaction(
    Map<String, dynamic> data, {
    DatabaseExecutor? executor,
  }) async {
    try {
      final db = executor ?? await instance.database;
      return await db.insert(TABLE_TRANSACTIONS, data);
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log("insertTransaction error: $e");
      return -1;
    }
  }

  // =========================================== //
  // --------- DASHBOARD ------------- //
  // =========================================== //

  /// Total balance = sum of all bank accounts + cash wallet for a given accountId
  Future<Map<String, dynamic>> getDashboardBalances(int accountId) async {
    try {
      final db = await instance.database;

      // Bank accounts total
      final bankResult = await db.rawQuery(
        '''
      SELECT COALESCE(SUM($CURRENT_BALANCE), 0.0) as bank_total
      FROM $TABLE_BANK_ACCOUNTS
      WHERE $ACCOUNT_ID = ? AND $DELETED_AT IS NULL
    ''',
        [accountId],
      );

      // Cash wallet balance
      final cashResult = await db.rawQuery(
        '''
      SELECT COALESCE($CASH_WALLET_CURRENT_BALANCE, 0.0) as cash_total
      FROM $TABLE_CASH_WALLET
      WHERE $ACCOUNT_ID = ? AND $DELETED_AT IS NULL
      LIMIT 1
    ''',
        [accountId],
      );

      double bankTotal = (bankResult.first['bank_total'] as num).toDouble();
      double cashTotal = cashResult.isNotEmpty
          ? (cashResult.first['cash_total'] as num).toDouble()
          : 0.0;

      return {
        'bank_total': bankTotal,
        'cash_total': cashTotal,
        'combined_total': bankTotal + cashTotal,
      };
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return {'bank_total': 0.0, 'cash_total': 0.0, 'combined_total': 0.0};
    }
  }

  /// Income & Expense from both TABLE_TRANSACTIONS and TABLE_CASH_WALLET_TRANSACTIONS
  /// txnType: 'cr' = income, 'dr' = expense in TABLE_TRANSACTIONS
  /// Cash wallet: 'Income'/'Cash Withdrawn From Bank' = income, 'Expense'/'Cash Deposited To Bank' = expense
  Future<Map<String, dynamic>> getDashboardIncomeExpense(
    int accountId, {
    String? monthYear, // format: 'YYYY-MM' — pass null for all-time
  }) async {
    try {
      final db = await instance.database;

      String dateFilter = monthYear != null
          ? "AND strftime('%Y-%m', $TXN_DATE) = ?"
          : "";
      List<dynamic> bankArgs = monthYear != null
          ? [accountId, monthYear]
          : [accountId];

      // Bank transactions income (CR) — EXCLUDE internal transfers
      final bankIncomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM($TXN_AMOUNT), 0.0) as total
      FROM $TABLE_TRANSACTIONS
      WHERE $TXN_ACCOUNT_ID IN (
        SELECT $BANK_ACCOUNT_NUMBER FROM $TABLE_BANK_ACCOUNTS
        WHERE $ACCOUNT_ID = ? AND $DELETED_AT IS NULL
      )
      AND UPPER($TXN_TYPE) = 'CR'
      AND ($TXN_REF IS NULL OR $TXN_REF NOT LIKE 'TRF_%')
      AND $DELETED_AT IS NULL
      $dateFilter
    ''', bankArgs);

      // Bank transactions expense (DR) — EXCLUDE internal transfers
      final bankExpenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM($TXN_AMOUNT), 0.0) as total
      FROM $TABLE_TRANSACTIONS
      WHERE $TXN_ACCOUNT_ID IN (
        SELECT $BANK_ACCOUNT_NUMBER FROM $TABLE_BANK_ACCOUNTS
        WHERE $ACCOUNT_ID = ? AND $DELETED_AT IS NULL
      )
      AND UPPER($TXN_TYPE) = 'DR'
      AND ($TXN_REF IS NULL OR $TXN_REF NOT LIKE 'TRF_%')
      AND $DELETED_AT IS NULL
      $dateFilter
    ''', bankArgs);

      String cashDateFilter = monthYear != null
          ? "AND strftime('%Y-%m', $DATE_ADDED) = ?"
          : "";
      List<dynamic> cashArgs = monthYear != null
          ? [accountId, monthYear]
          : [accountId];

      // Cash wallet income — ONLY 'Income' (transfers excluded)
      final cashIncomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(ABS($AMOUNT)), 0.0) as total
      FROM $TABLE_CASH_WALLET_TRANSACTIONS
      WHERE $ACCOUNT_ID = ?
      AND $CASH_WALLET_TRANSACTION_TYPE IN ('Income')
      AND $DELETED_AT IS NULL
      $cashDateFilter
    ''', cashArgs);

      // Cash wallet expense — ONLY 'Expense' (transfers excluded)
      final cashExpenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(ABS($AMOUNT)), 0.0) as total
      FROM $TABLE_CASH_WALLET_TRANSACTIONS
      WHERE $ACCOUNT_ID = ?
      AND $CASH_WALLET_TRANSACTION_TYPE IN ('Expense')
      AND $DELETED_AT IS NULL
      $cashDateFilter
    ''', cashArgs);

      double bankIncome = (bankIncomeResult.first['total'] as num).toDouble();
      double bankExpense = (bankExpenseResult.first['total'] as num).toDouble();
      double cashIncome = (cashIncomeResult.first['total'] as num).toDouble();
      double cashExpense = (cashExpenseResult.first['total'] as num).toDouble();

      return {
        'total_income': bankIncome + cashIncome,
        'total_expense': bankExpense + cashExpense,
        'bank_income': bankIncome,
        'bank_expense': bankExpense,
        'cash_income': cashIncome,
        'cash_expense': cashExpense,
      };
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log(e.toString());
      return {
        'total_income': 0.0,
        'total_expense': 0.0,
        'bank_income': 0.0,
        'bank_expense': 0.0,
        'cash_income': 0.0,
        'cash_expense': 0.0,
      };
    }
  }

  /// Fetch the most recent [limit] bank transactions across all accounts
  /// for this user, joined with tags and bank account info.
  Future<List<Map<String, dynamic>>> getRecentTransactions(
    int accountId, {
    int limit = 5,
  }) async {
    try {
      if (accountId <= 0) return [];
      final db = await instance.database;
      return await db.rawQuery(
        '''
        SELECT
          t.$TXN_ID,
          t.$TXN_DATE,
          t.$TXN_AMOUNT,
          t.$TXN_TYPE,
          t.$TXN_NARRATION,
          t.$TXN_ACCOUNT_ID,
          t.$TXN_TAG_ID,
          tg.$TAG_NAME,
          ba.$BANK_NAME,
          ba.$LAST_FOUR_DIGITS
        FROM $TABLE_TRANSACTIONS t
        LEFT JOIN $TABLE_TAGS tg
          ON t.$TXN_TAG_ID = tg.$TAG_ID
          AND tg.$TAG_DELETED_AT IS NULL
        LEFT JOIN $TABLE_BANK_ACCOUNTS ba
          ON t.$TXN_ACCOUNT_ID = ba.$BANK_ACCOUNT_NUMBER
          AND ba.$DELETED_AT IS NULL
        WHERE t.$TXN_ACCOUNT_ID IN (
          SELECT $BANK_ACCOUNT_NUMBER
          FROM $TABLE_BANK_ACCOUNTS
          WHERE $ACCOUNT_ID = ? AND $DELETED_AT IS NULL
        )
        AND t.$DELETED_AT IS NULL
        ORDER BY t.$TXN_DATE DESC, t.$TXN_ID DESC
        LIMIT ?
        ''',
        [accountId, limit],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('getRecentTransactions error: $e');
      return [];
    }
  }

  /// Returns total receivable and payable from virtual_entries for this account.
  /// MODIFIED: Now only sums 'pending' entries (resolved ones don't inflate dashboard)
  Future<Map<String, double>> getVirtualEntrySummary(int accountId) async {
    try {
      if (accountId <= 0) return {'receivable': 0.0, 'payable': 0.0};
      final db = await instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT
          $VE_ENTRY_TYPE,
          COALESCE(SUM($VE_AMOUNT), 0.0) as total
        FROM $TABLE_VIRTUAL_ENTRIES
        WHERE $VE_ACCOUNT_ID = ? 
          AND $VE_DELETED_AT IS NULL
          AND $VE_STATUS = 'pending'
        GROUP BY $VE_ENTRY_TYPE
        ''',
        [accountId],
      );

      double receivable = 0.0;
      double payable = 0.0;
      for (final row in rows) {
        final type = row[VE_ENTRY_TYPE] as String? ?? '';
        final total = (row['total'] as num?)?.toDouble() ?? 0.0;
        if (type == 'Receivable') receivable = total;
        if (type == 'Payable') payable = total;
      }
      return {'receivable': receivable, 'payable': payable};
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('getVirtualEntrySummary error: $e');
      return {'receivable': 0.0, 'payable': 0.0};
    }
  }

  // =========================================== //
  // --------- CASH TAG (FEATURE A) ------------ //
  // =========================================== //

  /// Ensures the global 'Cash' tag exists. Returns the tag_id.
  /// Called once on app initialization.
  Future<int> ensureCashTagExists(int userId) async {
    try {
      if (!_isValidAccountId(userId)) return -1;
      final db = await instance.database;

      // Check if Cash tag already exists for this user.
      final existing = await db.query(
        TABLE_TAGS,
        where:
            '$TAG_NAME = ? AND $TAG_USER_ID = ? AND $TAG_BANK_ACCOUNT_ID IS NULL AND $TAG_DELETED_AT IS NULL',
        whereArgs: ['Cash', userId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return existing.first[TAG_ID] as int;
      }

      // Create user-scoped Cash tag.
      final keywords = jsonEncode([
        {"name": "atm/wdl", "priority": 1},
        {"name": "atm withdrawal", "priority": 2},
        {"name": "atm withdraw", "priority": 3},
        {"name": "cash withdrawal", "priority": 4},
        {"name": "cash withdraw", "priority": 5},
        {"name": "cash deposit", "priority": 6},
        {"name": "cash deposited", "priority": 7},
        {"name": "atm deposit", "priority": 8},
        {"name": "atm deposited", "priority": 9},
        {"name": "deposited at atm", "priority": 10},
        {"name": "withdrawal at atm", "priority": 11},
        {"name": "cash at counter", "priority": 12},
        {"name": "teller withdrawal", "priority": 13},
        {"name": "teller deposit", "priority": 14},
        {"name": "branch cash", "priority": 15},
        {"name": "cdm deposit", "priority": 16},
        {"name": "cdm", "priority": 17},
      ]);

      final now = DateTime.now().toIso8601String();
      final tagId = await db.insert(TABLE_TAGS, {
        TAG_NAME: 'Cash',
        TAG_KEYWORDS: keywords,
        TAG_PRIORITY: 2, // Highest priority - must match first
        TAG_USER_ID: userId,
        TAG_BANK_ACCOUNT_ID: null,
        TAG_CREATED_AT: now,
        TAG_UPDATED_AT: now,
        TAG_DELETED_AT: null,
      });

      log('Cash tag created with ID: $tagId');
      return tagId;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('ensureCashTagExists error: $e');
      return -1;
    }
  }

  // =========================================== //
  // --- VIRTUAL ENTRY MATCHING (FEATURE B) --- //
  // =========================================== //

  /// Get all pending virtual entries for matching
  Future<List<Map<String, dynamic>>> getPendingVirtualEntries(
    int accountId,
  ) async {
    try {
      if (accountId <= 0) return [];
      final db = await instance.database;
      final String query =
          '''
        SELECT ve.*, t.$TAG_NAME as resolvedTagName
        FROM $TABLE_VIRTUAL_ENTRIES ve
        LEFT JOIN $TABLE_TAGS t ON ve.$VE_TAG_ID = t.$TAG_ID
        WHERE ve.$VE_ACCOUNT_ID = ? 
          AND ve.$VE_STATUS = 'pending'
          AND ve.$VE_DELETED_AT IS NULL
        ORDER BY ve.$VE_CREATED_AT DESC
      ''';
      return await db.rawQuery(query, [accountId]);
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('getPendingVirtualEntries error: $e');
      return [];
    }
  }

  /// Mark a virtual entry as resolved and link it to a transaction
  Future<int> markVirtualEntryResolved(
    int virtualEntryId,
    int matchedTxnId,
    int accountId,
  ) async {
    try {
      if (!_isValidAccountId(accountId)) return 0;
      final db = await instance.database;
      return await db.update(
        TABLE_VIRTUAL_ENTRIES,
        {
          VE_STATUS: 'resolved',
          VE_MATCHED_TXN_ID: matchedTxnId,
          VE_UPDATED_AT: DateTime.now().toIso8601String(),
        },
        where: '$VIRTUAL_ENTRY_ID = ? AND $VE_ACCOUNT_ID = ?',
        whereArgs: [virtualEntryId, accountId],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('markVirtualEntryResolved error: $e');
      return -1;
    }
  }

  /// Get cash wallet transactions for virtual entry matching
  Future<List<Map<String, dynamic>>> getCashWalletTransactionsForMatching(
    int accountId,
  ) async {
    try {
      if (accountId <= 0) return [];

      final db = await instance.database;

      // Use the same constant names as aliases so runFullMatching reads them correctly
      final String query =
          '''
      SELECT
        c.$CASH_WALLET_TRANSACTION_ID AS $TXN_ID,
        c.$DATE_ADDED                 AS $TXN_DATE,
        c.$AMOUNT                     AS $TXN_AMOUNT,
        c.$CASH_WALLET_TRANSACTION_TYPE AS $TXN_TYPE,
        c.$TRANSACTION_NOTE           AS $TXN_NARRATION,
        c.$ACCOUNT_ID                 AS $TXN_ACCOUNT_ID,
        'Cash Wallet'                 AS $BANK_NAME,
        ''                            AS $LAST_FOUR_DIGITS,
        c.$DATE_ADDED                 AS $DATE_ADDED
      FROM $TABLE_CASH_WALLET_TRANSACTIONS c
      WHERE c.$ACCOUNT_ID = ?
        AND c.$DELETED_AT IS NULL
      ORDER BY c.$DATE_ADDED DESC
    ''';

      return await db.rawQuery(query, [accountId]);
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('getCashWalletTransactionsForMatching error: $e');
      return [];
    }
  }

  // ------- get transactions by account id ------- //
  Future<List<Map<String, dynamic>>> getTransactionsByAccountId(
    int accountId,
  ) async {
    try {
      if (accountId <= 0) return [];
      final db = await instance.database;
      return await db.rawQuery(
        '''
        SELECT
          t.$TXN_ID,
          t.$TXN_DATE,
          t.$TXN_AMOUNT,
          t.$TXN_TYPE,
          t.$TXN_NARRATION,
          t.$TXN_ACCOUNT_ID,
          t.$TXN_TAG_ID,
          t.$TXN_IS_MANUAL,
          tg.$TAG_NAME,
          ba.$BANK_NAME,
          ba.$LAST_FOUR_DIGITS
        FROM $TABLE_TRANSACTIONS t
        LEFT JOIN $TABLE_TAGS tg
          ON t.$TXN_TAG_ID = tg.$TAG_ID
          AND tg.$TAG_DELETED_AT IS NULL
        LEFT JOIN $TABLE_BANK_ACCOUNTS ba
          ON t.$TXN_ACCOUNT_ID = ba.$BANK_ACCOUNT_NUMBER
          AND ba.$DELETED_AT IS NULL
        WHERE t.$TXN_ACCOUNT_ID IN (
          SELECT $BANK_ACCOUNT_NUMBER
          FROM $TABLE_BANK_ACCOUNTS
          WHERE $ACCOUNT_ID = ? AND $DELETED_AT IS NULL
        )
        AND t.$DELETED_AT IS NULL
        ORDER BY t.$TXN_DATE DESC, t.$TXN_ID DESC
        ''',
        [accountId],
      );
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('getRecentTransactions error: $e');
      return [];
    }
  }

  // ----------- import sessions ---------- //
  /// Save a new import session record
  Future<int> insertImportSession({
    required String bankAccountNumber,
    required double openingBalance,
    required String fromDate,
    required String toDate,
  }) async {
    final db = await instance.database;
    return await db.insert(TABLE_IMPORT_SESSIONS, {
      IMPORT_BANK_ACCOUNT_NUMBER: bankAccountNumber,
      IMPORT_OPENING_BALANCE: openingBalance,
      IMPORT_FROM_DATE: fromDate,
      IMPORT_TO_DATE: toDate,
      IMPORT_CREATED_AT: DateTime.now().toIso8601String(),
    });
  }

  Future<bool> importSessionExists({
    required String bankAccountNumber,
    required String fromDate,
    required String toDate,
  }) async {
    final db = await instance.database;
    final rows = await db.query(
      TABLE_IMPORT_SESSIONS,
      columns: [IMPORT_SESSION_ID],
      where:
          '$IMPORT_BANK_ACCOUNT_NUMBER = ? AND $IMPORT_FROM_DATE = ? AND $IMPORT_TO_DATE = ?',
      whereArgs: [bankAccountNumber, fromDate, toDate],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> hasOverlappingImportSession({
    required String bankAccountNumber,
    required String fromDate,
    required String toDate,
  }) async {
    final db = await instance.database;
    final rows = await db.query(
      TABLE_IMPORT_SESSIONS,
      columns: [IMPORT_SESSION_ID],
      where:
          '$IMPORT_BANK_ACCOUNT_NUMBER = ? AND $IMPORT_FROM_DATE <= ? AND $IMPORT_TO_DATE >= ?',
      whereArgs: [bankAccountNumber, toDate, fromDate],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Returns the opening balance from the session with the EARLIEST fromDate.
  /// This is the only correct opening balance regardless of import order.
  Future<double?> getEarliestOpeningBalance(
    String bankAccountNumber, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await instance.database;
    final result = await db.rawQuery(
      '''
    SELECT $IMPORT_OPENING_BALANCE
    FROM $TABLE_IMPORT_SESSIONS
    WHERE $IMPORT_BANK_ACCOUNT_NUMBER = ?
    ORDER BY $IMPORT_FROM_DATE ASC
    LIMIT 1
  ''',
      [bankAccountNumber],
    );

    if (result.isEmpty) return null;
    return (result.first[IMPORT_OPENING_BALANCE] as num?)?.toDouble();
  }

  /// Deduplicate check — does this txnRef already exist for this account?
  Future<bool> transactionExistsByRef(
    String txnRef,
    String bankAccountNumber,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      TABLE_TRANSACTIONS,
      where: '$TXN_REF = ? AND $TXN_ACCOUNT_ID = ? AND $DELETED_AT IS NULL',
      whereArgs: [txnRef, bankAccountNumber],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<bool> transactionExistsByComposite({
    required String bankAccountNumber,
    required String date,
    required double amount,
    required String type,
    required String narration,
  }) async {
    final db = await instance.database;
    final rows = await db.query(
      TABLE_TRANSACTIONS,
      columns: [TXN_NARRATION],
      where:
          '$TXN_ACCOUNT_ID = ? AND $TXN_DATE = ? AND $TXN_AMOUNT = ? AND UPPER($TXN_TYPE) = ? AND $DELETED_AT IS NULL',
      whereArgs: [bankAccountNumber, date, amount, type.toUpperCase()],
    );
    if (rows.isEmpty) return false;

    final targetHash = _normalizedNarrationHash(narration);
    for (final row in rows) {
      final existingNarration = (row[TXN_NARRATION] as String?) ?? '';
      if (_normalizedNarrationHash(existingNarration) == targetHash) {
        return true;
      }
    }
    return false;
  }

  /// Recomputes currentBalance = earliestOpeningBalance + credits - debits
  Future<double> computeCurrentBalance(
    String bankAccountNumber, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await instance.database;

    final opening =
        await getEarliestOpeningBalance(bankAccountNumber, executor: db) ?? 0.0;

    final result = await db.rawQuery(
      '''
    SELECT
      COALESCE(SUM(CASE WHEN UPPER($TXN_TYPE) = 'CR' THEN $TXN_AMOUNT ELSE 0 END), 0.0) AS credits,
      COALESCE(SUM(CASE WHEN UPPER($TXN_TYPE) = 'DR' THEN $TXN_AMOUNT ELSE 0 END), 0.0) AS debits
    FROM $TABLE_TRANSACTIONS
    WHERE $TXN_ACCOUNT_ID = ?
      AND $DELETED_AT IS NULL
  ''',
      [bankAccountNumber],
    );

    final credits = (result.first['credits'] as num).toDouble();
    final debits = (result.first['debits'] as num).toDouble();
    return opening + credits - debits;
  }

  Future<double> recomputeAndSave(
    String bankAccountNumber, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await instance.database;
    final latest = await computeCurrentBalance(bankAccountNumber, executor: db);
    await updateBankAccountBalance(bankAccountNumber, latest, executor: db);
    return latest;
  }

  Future<double?> expectedOpeningBalanceAtDate({
    required String bankAccountNumber,
    required String fromDate,
  }) async {
    final db = await instance.database;
    final earliest = await db.rawQuery(
      '''
      SELECT $IMPORT_OPENING_BALANCE, $IMPORT_FROM_DATE
      FROM $TABLE_IMPORT_SESSIONS
      WHERE $IMPORT_BANK_ACCOUNT_NUMBER = ?
      ORDER BY $IMPORT_FROM_DATE ASC
      LIMIT 1
      ''',
      [bankAccountNumber],
    );
    if (earliest.isEmpty) return null;

    final anchorOpening = (earliest.first[IMPORT_OPENING_BALANCE] as num)
        .toDouble();
    final anchorDate =
        (earliest.first[IMPORT_FROM_DATE] as String?) ?? fromDate;
    final startDate = anchorDate.compareTo(fromDate) < 0
        ? anchorDate
        : fromDate;
    final endDateExclusive = anchorDate.compareTo(fromDate) < 0
        ? fromDate
        : anchorDate;

    final sums = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN UPPER($TXN_TYPE) = 'CR' THEN $TXN_AMOUNT ELSE 0 END), 0.0) AS credits,
        COALESCE(SUM(CASE WHEN UPPER($TXN_TYPE) = 'DR' THEN $TXN_AMOUNT ELSE 0 END), 0.0) AS debits
      FROM $TABLE_TRANSACTIONS
      WHERE $TXN_ACCOUNT_ID = ?
        AND $DELETED_AT IS NULL
        AND $TXN_DATE >= ?
        AND $TXN_DATE < ?
      ''',
      [bankAccountNumber, startDate, endDateExclusive],
    );
    final credits = (sums.first['credits'] as num).toDouble();
    final debits = (sums.first['debits'] as num).toDouble();

    if (anchorDate.compareTo(fromDate) < 0) {
      return anchorOpening + credits - debits;
    }
    return anchorOpening - credits + debits;
  }

  /// Returns existing session for exact date range, or null if not found.
  /// Used to prevent duplicate sessions and to correct stale opening balances.
  Future<Map<String, dynamic>?> getImportSession({
    required String bankAccountNumber,
    required String fromDate,
    required String toDate,
  }) async {
    final db = await instance.database;
    final result = await db.query(
      TABLE_IMPORT_SESSIONS,
      where:
          '$IMPORT_BANK_ACCOUNT_NUMBER = ? '
          'AND $IMPORT_FROM_DATE = ? '
          'AND $IMPORT_TO_DATE = ?',
      whereArgs: [bankAccountNumber, fromDate, toDate],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  /// Corrects the opening balance of an existing session.
  /// Called on re-import to ensure stale values are fixed.
  Future<void> updateImportSessionOpeningBalance({
    required int sessionId,
    required double openingBalance,
  }) async {
    final db = await instance.database;
    await db.update(
      TABLE_IMPORT_SESSIONS,
      {IMPORT_OPENING_BALANCE: openingBalance},
      where: '$IMPORT_SESSION_ID = ?',
      whereArgs: [sessionId],
    );
  }

  String _normalizedNarrationHash(String narration) {
    final normalized = narration.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return sha1.convert(utf8.encode(normalized)).toString();
  }
}
