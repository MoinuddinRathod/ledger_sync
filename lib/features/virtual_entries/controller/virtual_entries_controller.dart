import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/service/snackbar_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/utils/app_constants.dart';
import '../../home/controllers/dashboard_controller.dart';
import '../../tags/models/tag_model.dart';
import '../models/virtual_entry_model.dart';
import '../models/virtual_entry_match_model.dart';
import '../repository/virtual_entry_repository.dart';
import 'dart:developer';

// MODIFIED: Added virtual entry auto-matching logic (Feature B)
class VirtualEntriesController extends GetxController {
  final VirtualEntryRepository _repository = VirtualEntryRepository();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final formKey = GlobalKey<FormState>();

  // Observables
  var isLoading = false.obs;
  var isSearching = false.obs;
  var searchQuery = ''.obs;

  // Data
  RxList<VirtualEntryModel> receivableEntries = <VirtualEntryModel>[].obs;
  RxList<VirtualEntryModel> payableEntries = <VirtualEntryModel>[].obs;

  var totalReceivable = 0.0.obs;
  var totalPayable = 0.0.obs;

  // Feature B: Matched entries for settlement
  RxList<VirtualEntryMatch> matchedEntries = <VirtualEntryMatch>[].obs;

  // Form Controllers
  var selectedEntryType = 'Receivable'.obs; // 'Receivable' or 'Payable'
  Rx<TagModel?> selectedTag = Rx<TagModel?>(null);

  // Date fields for the form
  Rx<DateTime> selectedEntryDate = DateTime.now().obs;
  Rx<DateTime?> selectedDueDate = Rx<DateTime?>(null);

  final amountController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchEntries().then((_) => runFullMatching());
  }

  Future<void> fetchEntries() async {
    isLoading.value = true;
    try {
      final entries = await _repository.getVirtualEntries();

      receivableEntries.value = entries
          .where((e) => e.entryType == 'Receivable' && e.status == 'pending')
          .toList();
      payableEntries.value = entries
          .where((e) => e.entryType == 'Payable' && e.status == 'pending')
          .toList();

      _calculateTotals();
    } catch (e) {
      debugPrint("Error fetching virtual entries: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void _calculateTotals() {
    double rec = 0;
    for (var entry in receivableEntries) {
      rec += entry.amount;
    }
    totalReceivable.value = rec;

    double pay = 0;
    for (var entry in payableEntries) {
      pay += entry.amount;
    }
    totalPayable.value = pay;
  }

  void clearForm() {
    selectedTag.value = null;
    amountController.clear();
    noteController.clear();
    selectedEntryType.value = 'Receivable';
    selectedEntryDate.value = DateTime.now();
    selectedDueDate.value = null;
  }

  void populateFormForEdit(
    VirtualEntryModel entry,
    List<TagModel> availableTags,
  ) {
    amountController.text = entry.amount.toString();
    noteController.text = entry.note ?? '';
    selectedEntryType.value = entry.entryType;

    selectedTag.value = availableTags.firstWhereOrNull(
      (tag) => tag.tagId == entry.tagId,
    );

    selectedEntryDate.value =
        DateTime.tryParse(entry.dateAdded) ?? DateTime.now();
    selectedDueDate.value = entry.dueDate != null
        ? DateTime.tryParse(entry.dueDate!)
        : null;
  }

  Future<void> saveEntry({bool isEditing = false, int? entryId}) async {
    if (!formKey.currentState!.validate()) return;

    if (selectedTag.value == null) {
      SnackbarService.showError(
        title: 'Error',
        message: 'Please select a tag.',
      );
      return;
    }

    double amount = double.tryParse(amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      SnackbarService.showError(
        title: 'Error',
        message: 'Please enter a valid amount.',
      );
      return;
    }

    isLoading.value = true;
    try {
      final entry = VirtualEntryModel(
        virtualEntryId: entryId,
        accountId: 0, // Assigned correctly in Repo
        tagId: selectedTag.value!.tagId!,
        entryType: selectedEntryType.value,
        amount: amount,
        note: noteController.text.trim(),
        dateAdded: selectedEntryDate.value.toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: isEditing ? DateTime.now().toIso8601String() : null,
        status: 'pending',
        dueDate: selectedDueDate.value?.toIso8601String(),
      );

      bool success = false;
      if (isEditing) {
        success = await _repository.updateVirtualEntry(entry);
      } else {
        success = await _repository.insertVirtualEntry(entry);
      }

      if (success) {
        await fetchEntries();
        _refreshDashboard();
        Get.back(); // close bottom sheet
        SnackbarService.showSuccess(
          title: 'Success',
          message: isEditing ? 'Entry updated.' : 'Entry saved.',
        );
      }
    } catch (e) {
      debugPrint("Virtual Entries error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteEntry(VirtualEntryModel entry) async {
    if (entry.virtualEntryId == null) return;

    isLoading.value = true;
    try {
      final success = await _repository.softDeleteVirtualEntry(
        entry.virtualEntryId!,
      );
      if (success) {
        await fetchEntries();
        _refreshDashboard();
        SnackbarService.showSuccess(
          title: 'Deleted',
          message: 'Entry removed successfully.',
        );
      }
    } catch (e) {
      debugPrint("Error deleting Entry: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================================
  // FEATURE B: VIRTUAL ENTRY AUTO-MATCHING
  // =========================================================================

  /// Run auto-matching after import completes
  /// Called from ReviewTransactionsController after transactions are saved
  Future<void> runAutoMatching({
    required String bankAccountNumber,
    required (String?, String?) importDateRange,
  }) async {
    log('[VirtualEntriesController] instance hashCode: $hashCode');
    try {
      final accountId = LocalStorageService.instance.accountId;
      if (accountId <= 0) {
        log(
          '[VirtualEntriesController] runAutoMatching: Invalid account ID, skipping',
        );
        return;
      }

      // Get all pending virtual entries
      final pendingEntries = await _db.getPendingVirtualEntries(accountId);
      if (pendingEntries.isEmpty) {
        log(
          '[VirtualEntriesController] runAutoMatching: No pending virtual entries found, skipping',
        );
        return;
      }

      log(
        '[VirtualEntriesController] runAutoMatching: Found ${pendingEntries.length} pending virtual entries',
      );

      // Get all tags for keyword matching
      final tags = await _db.getAllTags(accountId);
      if (tags.isEmpty) {
        log(
          '[VirtualEntriesController] runAutoMatching: No tags found, skipping',
        );
        return;
      }

      final List<VirtualEntryMatch> matches = [];

      // Query transactions in the import date range once
      final candidateTxns = await _getCandidateTransactions(
        bankAccountNumber: bankAccountNumber,
        fromDate: importDateRange.$1,
        toDate: importDateRange.$2,
      );

      if (candidateTxns.isEmpty) {
        log(
          '[VirtualEntriesController] runAutoMatching: No imported transactions found in date range',
        );
        return;
      }

      log(
        '[VirtualEntriesController] runAutoMatching: Scanning ${candidateTxns.length} imported transactions',
      );

      // MODIFIED: Extended to also scan cash wallet transactions
      // Get cash wallet transactions
      final cashWalletTxns = await _db.getCashWalletTransactionsForMatching(
        accountId,
      );

      log(
        '[VirtualEntriesController] runAutoMatching: Scanning ${cashWalletTxns.length} cash wallet transactions',
      );

      // Combine both bank and cash wallet transactions
      final allCandidateTxns = [...candidateTxns, ...cashWalletTxns];

      for (final veMap in pendingEntries) {
        final veTagId = veMap[VE_TAG_ID] as int?;
        if (veTagId == null) continue;

        // Find the tag for this virtual entry
        final veTag = tags.firstWhereOrNull((t) => t.tagId == veTagId);
        if (veTag == null) continue;

        // Get tag keywords
        final keywords = veTag.tagKeywords
            .map((kw) => (kw['name'] as String?)?.toLowerCase().trim())
            .where((k) => k != null && k.isNotEmpty)
            .cast<String>()
            .toList();

        if (keywords.isEmpty) {
          log(
            '[VirtualEntriesController] runAutoMatching: Virtual entry ${veMap[VIRTUAL_ENTRY_ID]} has no keywords, skipping',
          );
          continue;
        }

        log(
          '[VirtualEntriesController] runAutoMatching: Matching virtual entry ${veMap[VIRTUAL_ENTRY_ID]} with keywords: ${keywords.join(", ")}',
        );

        // Find matching transactions by keyword
        VirtualEntryMatch? bestMatch;
        double bestAmountDiff = double.infinity;

        for (final txnMap in allCandidateTxns) {
          final narration = (txnMap[TXN_NARRATION] as String? ?? '')
              .toLowerCase()
              .trim();

          // Check if any keyword matches
          bool keywordMatch = false;
          String? matchedKeyword;
          for (final keyword in keywords) {
            if (narration.contains(keyword)) {
              keywordMatch = true;
              matchedKeyword = keyword;
              break;
            }
          }

          if (!keywordMatch) continue;

          // Direction filter: Payable → DR only, Receivable → CR only
          final txnType = (txnMap[TXN_TYPE] as String? ?? '')
              .toUpperCase()
              .trim();
          final veEntryType = veMap[VE_ENTRY_TYPE] as String? ?? '';
          if (veEntryType == 'Payable' && txnType != 'DR') continue;
          if (veEntryType == 'Receivable' && txnType != 'CR') continue;

          // Date range filter
          final txnDateStr = txnMap[TXN_DATE] as String? ?? '';
          final veEntryDateStr = veMap[VE_DATE_ADDED] as String? ?? '';
          final veDueDateStr = veMap[VE_DUE_DATE] as String?;

          if (txnDateStr.isNotEmpty && veEntryDateStr.isNotEmpty) {
            final txnDate = DateTime.tryParse(txnDateStr);
            final veEntryDate = DateTime.tryParse(veEntryDateStr);
            final veDueDate = veDueDateStr != null
                ? DateTime.tryParse(veDueDateStr)
                : null;

            if (txnDate != null && veEntryDate != null) {
              if (txnDate.isBefore(veEntryDate)) continue;
              if (veDueDate != null && txnDate.isAfter(veDueDate)) continue;
            }
          }

          // Calculate amount difference
          final txnAmount = (txnMap[TXN_AMOUNT] as num?)?.toDouble() ?? 0.0;
          final veAmount = (veMap[VE_AMOUNT] as num?)?.toDouble() ?? 0.0;
          final amountDiff = (txnAmount - veAmount).abs();

          // Check if this is a cash wallet transaction
          final isCashWallet = txnMap[TXN_ACCOUNT_ID] == 'cash';

          log(
            '[VirtualEntriesController] runAutoMatching: Found keyword match "$matchedKeyword" in ${isCashWallet ? "cash wallet" : "bank"} transaction ${txnMap[TXN_ID]}, amount diff: ₹${amountDiff.toStringAsFixed(2)}',
          );

          // Prefer closest amount match
          if (amountDiff < bestAmountDiff) {
            bestAmountDiff = amountDiff;
            bestMatch = VirtualEntryMatch(
              virtualEntry: veMap,
              matchedTransaction: txnMap,
              amountDifference: amountDiff,
              isCashWalletMatch: isCashWallet,
            );
          }
        }

        if (bestMatch != null) {
          matches.add(bestMatch);
          log(
            '[VirtualEntriesController] runAutoMatching: Best match for virtual entry ${veMap[VIRTUAL_ENTRY_ID]}: ${bestMatch.isCashWalletMatch ? "cash wallet" : "bank"} transaction ${bestMatch.txnId} with amount diff ₹${bestAmountDiff.toStringAsFixed(2)}',
          );
        }
      }

      matchedEntries.assignAll(matches);
      log(
        '[VirtualEntriesController] runAutoMatching: Completed - found ${matches.length} total matches',
      );
    } catch (e) {
      log('[VirtualEntriesController] runAutoMatching error: $e');
    }
  }

  /// Get candidate transactions for matching
  Future<List<Map<String, dynamic>>> _getCandidateTransactions({
    required String bankAccountNumber,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final accountId = LocalStorageService.instance.accountId;
      if (accountId <= 0) return [];
      final db = await _db.database;

      String dateFilter = '';
      List<dynamic> args = [bankAccountNumber, accountId];

      if (fromDate != null && toDate != null) {
        dateFilter = 'AND t.$TXN_DATE >= ? AND t.$TXN_DATE <= ?';
        args.addAll([fromDate, toDate]);
      } else if (fromDate != null) {
        dateFilter = 'AND t.$TXN_DATE >= ?';
        args.add(fromDate);
      }

      final query =
          '''
        SELECT
          t.$TXN_ID,
          t.$TXN_DATE,
          t.$TXN_AMOUNT,
          t.$TXN_TYPE,
          t.$TXN_NARRATION,
          t.$TXN_ACCOUNT_ID,
          ba.$BANK_NAME,
          ba.$LAST_FOUR_DIGITS
        FROM $TABLE_TRANSACTIONS t
        LEFT JOIN $TABLE_BANK_ACCOUNTS ba
          ON t.$TXN_ACCOUNT_ID = ba.$BANK_ACCOUNT_NUMBER
        WHERE t.$TXN_ACCOUNT_ID = ?
          AND t.$TXN_ACCOUNT_ID IN (
            SELECT $BANK_ACCOUNT_NUMBER
            FROM $TABLE_BANK_ACCOUNTS
            WHERE $ACCOUNT_ID = ?
              AND $DELETED_AT IS NULL
          )
          AND t.$DELETED_AT IS NULL
          $dateFilter
        ORDER BY t.$TXN_DATE DESC
      ''';

      return await db.rawQuery(query, args);
    } catch (e) {
      log('[VirtualEntriesController] _getCandidateTransactions error: $e');
      return [];
    }
  }

  /// Mark a virtual entry as resolved (settlement action)
  Future<void> markAsResolved(VirtualEntryMatch match) async {
    try {
      isLoading.value = true;

      final result = await _db.markVirtualEntryResolved(
        match.virtualEntryId,
        match.txnId,
        LocalStorageService.instance.accountId,
      );

      if (result > 0) {
        // Remove from matched list
        matchedEntries.remove(match);

        // Refresh entries
        await fetchEntries();
        _refreshDashboard();

        final message = match.isReceivable
            ? 'Payment received — entry marked resolved'
            : 'Payment made — entry marked resolved';

        SnackbarService.showSuccess(title: 'Resolved', message: message);
      }
    } catch (e) {
      log('[VirtualEntriesController] markAsResolved error: $e');
      SnackbarService.showError(
        title: 'Error',
        message: 'Failed to mark entry as resolved',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Dismiss a match (user rejects the suggestion)
  void dismissMatch(VirtualEntryMatch match) {
    matchedEntries.remove(match);
  }

  /// Run cash wallet matching on controller initialization
  /// Scans all cash wallet transactions for potential matches with pending virtual entries
  Future<void> runCashWalletMatching() async {
    try {
      final accountId = LocalStorageService.instance.accountId;
      if (accountId <= 0) {
        log(
          '[VirtualEntriesController] runCashWalletMatching: Invalid account ID, skipping',
        );
        return;
      }

      // Get all pending virtual entries
      final pendingEntries = await _db.getPendingVirtualEntries(accountId);
      if (pendingEntries.isEmpty) {
        log(
          '[VirtualEntriesController] runCashWalletMatching: No pending virtual entries found, skipping',
        );
        return;
      }

      log(
        '[VirtualEntriesController] runCashWalletMatching: Found ${pendingEntries.length} pending virtual entries',
      );

      // Get all tags for keyword matching
      final tags = await _db.getAllTags(accountId);
      if (tags.isEmpty) {
        log(
          '[VirtualEntriesController] runCashWalletMatching: No tags found, skipping',
        );
        return;
      }

      // Get cash wallet transactions
      final cashWalletTxns = await _db.getCashWalletTransactionsForMatching(
        accountId,
      );

      if (cashWalletTxns.isEmpty) {
        log(
          '[VirtualEntriesController] runCashWalletMatching: No cash wallet transactions found, skipping',
        );
        return;
      }

      log(
        '[VirtualEntriesController] runCashWalletMatching: Scanning ${cashWalletTxns.length} cash wallet transactions',
      );

      final List<VirtualEntryMatch> matches = [];

      for (final veMap in pendingEntries) {
        final veTagId = veMap[VE_TAG_ID] as int?;
        if (veTagId == null) continue;

        // Find the tag for this virtual entry
        final veTag = tags.firstWhereOrNull((t) => t.tagId == veTagId);
        if (veTag == null) continue;

        // Get tag keywords
        final keywords = veTag.tagKeywords
            .map((kw) => (kw['name'] as String?)?.toLowerCase().trim())
            .where((k) => k != null && k.isNotEmpty)
            .cast<String>()
            .toList();

        if (keywords.isEmpty) {
          log(
            '[VirtualEntriesController] runCashWalletMatching: Virtual entry ${veMap[VIRTUAL_ENTRY_ID]} has no keywords, skipping',
          );
          continue;
        }

        log(
          '[VirtualEntriesController] runCashWalletMatching: Matching virtual entry ${veMap[VIRTUAL_ENTRY_ID]} with keywords: ${keywords.join(", ")}',
        );

        // Find matching transactions by keyword
        VirtualEntryMatch? bestMatch;
        double bestAmountDiff = double.infinity;

        for (final txnMap in cashWalletTxns) {
          final narration = (txnMap[TXN_NARRATION] as String? ?? '')
              .toLowerCase()
              .trim();

          // Check if any keyword matches
          bool keywordMatch = false;
          String? matchedKeyword;
          for (final keyword in keywords) {
            if (narration.contains(keyword)) {
              keywordMatch = true;
              matchedKeyword = keyword;
              break;
            }
          }

          if (!keywordMatch) continue;

          // Calculate amount difference
          final txnAmount = (txnMap[TXN_AMOUNT] as num?)?.toDouble() ?? 0.0;
          final veAmount = (veMap[VE_AMOUNT] as num?)?.toDouble() ?? 0.0;
          final amountDiff = (txnAmount - veAmount).abs();

          log(
            '[VirtualEntriesController] runCashWalletMatching: Found keyword match "$matchedKeyword" in cash wallet transaction ${txnMap[TXN_ID]}, amount diff: ₹${amountDiff.toStringAsFixed(2)}',
          );

          // Prefer closest amount match
          if (amountDiff < bestAmountDiff) {
            bestAmountDiff = amountDiff;
            bestMatch = VirtualEntryMatch(
              virtualEntry: veMap,
              matchedTransaction: txnMap,
              amountDifference: amountDiff,
              isCashWalletMatch: true,
            );
          }
        }

        if (bestMatch != null) {
          matches.add(bestMatch);
          log(
            '[VirtualEntriesController] runCashWalletMatching: Best match for virtual entry ${veMap[VIRTUAL_ENTRY_ID]}: cash wallet transaction ${bestMatch.txnId} with amount diff ₹${bestAmountDiff.toStringAsFixed(2)}',
          );
        }
      }

      matchedEntries.assignAll(matches);
      log(
        '[VirtualEntriesController] runCashWalletMatching: Completed - found ${matches.length} total matches',
      );
    } catch (e) {
      log('[VirtualEntriesController] runCashWalletMatching error: $e');
    }
  }

  /// Run full matching across ALL bank accounts and cash wallet
  /// Called on controller initialization - scans all transactions with no date filter
  Future<void> runFullMatching() async {
    try {
      final accountId = LocalStorageService.instance.accountId;
      if (accountId <= 0) {
        log(
          '[VirtualEntriesController] runFullMatching: Invalid account ID, skipping',
        );
        return;
      }

      // Get all pending virtual entries
      final pendingEntries = await _db.getPendingVirtualEntries(accountId);
      if (pendingEntries.isEmpty) {
        log(
          '[VirtualEntriesController] runFullMatching: No pending virtual entries found, skipping',
        );
        return;
      }

      // Get all tags for keyword matching
      final tags = await _db.getAllTags(accountId);
      if (tags.isEmpty) {
        log(
          '[VirtualEntriesController] runFullMatching: No tags found, skipping',
        );
        return;
      }

      // Fetch ALL transactions across ALL bank accounts of this user
      final allTxns = await _db.getTransactionsByAccountId(accountId);

      // Fetch ALL cash wallet transactions for this user
      final cashTxns = await _db.getCashWalletTransactionsForMatching(
        accountId,
      );

      log(
        '[VirtualEntriesController] runFullMatching: '
        '${pendingEntries.length} pending VEs, '
        '${allTxns.length} bank txns, '
        '${cashTxns.length} cash txns',
      );

      final List<VirtualEntryMatch> newMatches = [];

      // Track which VE IDs already have a match in this run
      // (bank match takes priority over cash match — bank loop runs first)

      // ── BANK TRANSACTIONS LOOP ──
      for (final veMap in pendingEntries) {
        final veId = veMap[VIRTUAL_ENTRY_ID] as int?;
        if (veId == null) continue;

        final veTagId = veMap[VE_TAG_ID] as int?;
        if (veTagId == null) continue;

        final veTag = tags.firstWhereOrNull((t) => t.tagId == veTagId);
        if (veTag == null) continue;

        final keywords = veTag.tagKeywords
            .map((kw) => (kw['name'] as String?)?.toLowerCase().trim())
            .where((k) => k != null && k.isNotEmpty)
            .cast<String>()
            .toList();

        if (keywords.isEmpty) continue;

        VirtualEntryMatch? bestMatch;
        double bestDiff = double.infinity;

        for (final txnMap in allTxns) {
          final narration = (txnMap[TXN_NARRATION] as String? ?? '')
              .toLowerCase()
              .trim();

          bool keywordMatch = false;
          for (final kw in keywords) {
            if (narration.contains(kw)) {
              keywordMatch = true;
              break;
            }
          }

          if (!keywordMatch) continue;

          // Direction filter: Payable → DR only, Receivable → CR only
          final txnType = (txnMap[TXN_TYPE] as String? ?? '')
              .toUpperCase()
              .trim();
          final veEntryType = veMap[VE_ENTRY_TYPE] as String? ?? '';
          if (veEntryType == 'Payable' && txnType != 'DR') continue;
          if (veEntryType == 'Receivable' && txnType != 'CR') continue;

          // Date range filter (bank transactions loop)
          final txnDateStr = txnMap[TXN_DATE] as String? ?? '';
          final veEntryDateStr = veMap[VE_DATE_ADDED] as String? ?? '';
          final veDueDateStr = veMap[VE_DUE_DATE] as String?;

          if (txnDateStr.isNotEmpty && veEntryDateStr.isNotEmpty) {
            final txnDate = DateTime.tryParse(txnDateStr);
            final veEntryDate = DateTime.tryParse(veEntryDateStr);
            final veDueDate = veDueDateStr != null
                ? DateTime.tryParse(veDueDateStr)
                : null;

            if (txnDate != null && veEntryDate != null) {
              if (txnDate.isBefore(veEntryDate)) continue;
              if (veDueDate != null && txnDate.isAfter(veDueDate)) continue;
            }
          }

          final txnAmount = (txnMap[TXN_AMOUNT] as num?)?.toDouble() ?? 0.0;
          final veAmount = (veMap[VE_AMOUNT] as num?)?.toDouble() ?? 0.0;
          final diff = (txnAmount - veAmount).abs();

          if (diff < bestDiff) {
            bestDiff = diff;
            bestMatch = VirtualEntryMatch(
              virtualEntry: veMap,
              matchedTransaction: txnMap,
              amountDifference: diff,
              isCashWalletMatch: false,
            );
          }
        }

        if (bestMatch != null) {
          newMatches.add(bestMatch);
        }
      }

      // ── CASH WALLET LOOP ──
      final matchedVeIds = newMatches.map((m) => m.virtualEntryId).toSet();

      for (final veMap in pendingEntries) {
        final veId = veMap[VIRTUAL_ENTRY_ID] as int?;
        if (veId == null) continue;

        if (matchedVeIds.contains(veId)) continue; // bank match wins

        final veTagId = veMap[VE_TAG_ID] as int?;
        if (veTagId == null) continue;

        final veTag = tags.firstWhereOrNull((t) => t.tagId == veTagId);
        if (veTag == null) continue;

        final keywords = veTag.tagKeywords
            .map((kw) => (kw['name'] as String?)?.toLowerCase().trim())
            .where((k) => k != null && k.isNotEmpty)
            .cast<String>()
            .toList();

        if (keywords.isEmpty) continue;

        VirtualEntryMatch? bestCashMatch;
        double bestDiff = double.infinity;

        for (final cashTxn in cashTxns) {
          // Direction filter for cash wallet types
          const drCashTypes = ['EXPENSE', 'CASH DEPOSITED TO BANK'];
          const crCashTypes = ['INCOME', 'CASH WITHDRAWN FROM BANK'];
          final cwType = (cashTxn[TXN_TYPE] as String? ?? '')
              .toUpperCase()
              .trim();
          final veEntryType = veMap[VE_ENTRY_TYPE] as String? ?? '';
          if (veEntryType == 'Payable' && !drCashTypes.contains(cwType)) {
            continue;
          }
          if (veEntryType == 'Receivable' && !crCashTypes.contains(cwType)) {
            continue;
          }

          // Date range filter (cash wallet loop)
          final txnDateStr = cashTxn[DATE_ADDED] as String? ?? '';
          final veEntryDateStr = veMap[VE_DATE_ADDED] as String? ?? '';
          final veDueDateStr = veMap[VE_DUE_DATE] as String?;

          if (txnDateStr.isNotEmpty && veEntryDateStr.isNotEmpty) {
            final txnDate = DateTime.tryParse(txnDateStr);
            final veEntryDate = DateTime.tryParse(veEntryDateStr);
            final veDueDate = veDueDateStr != null
                ? DateTime.tryParse(veDueDateStr)
                : null;

            if (txnDate != null && veEntryDate != null) {
              if (txnDate.isBefore(veEntryDate)) continue;
              if (veDueDate != null && txnDate.isAfter(veDueDate)) continue;
            }
          }

          final cashAmount = (cashTxn[TXN_AMOUNT] as num?)?.toDouble() ?? 0.0;
          final veAmount = (veMap[VE_AMOUNT] as num?)?.toDouble() ?? 0.0;
          final diff = (cashAmount - veAmount).abs();

          if (diff < bestDiff) {
            bestDiff = diff;
            bestCashMatch = VirtualEntryMatch(
              virtualEntry: veMap,
              matchedTransaction: cashTxn,
              amountDifference: diff,
              isCashWalletMatch: true,
            );
          }
        }

        if (bestCashMatch != null) {
          newMatches.add(bestCashMatch);
        }
      }

      // Replace matchedEntries completely — fresh scan result
      matchedEntries.assignAll(newMatches);

      log(
        '[VirtualEntriesController] runFullMatching: '
        'completed with ${newMatches.length} matches',
      );
    } catch (e) {
      log('[VirtualEntriesController] runFullMatching error: $e');
    }
  }

  /// Soft-trigger dashboard refresh without blocking the current flow.
  void _refreshDashboard() {
    try {
      Get.find<DashboardController>().refreshDashboard();
    } catch (_) {}
  }
}
