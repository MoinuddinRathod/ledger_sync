import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/keyword_mapping_model.dart';
import '../../../core/models/master_account_model.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/narration_cleaner.dart';
import '../../../core/service/snackbar_service.dart';
import '../../../core/service/dialog_service.dart';
import '../../../core/service/cash_tag_service.dart';
import '../../../core/utils/app_constants.dart';
import '../../tags/controllers/tags_controller.dart';
import '../../tags/models/tag_model.dart';
import '../../tags/repository/tag_repositary.dart';
import '../parsers/parse_result.dart';
import 'dashboard_controller.dart';
import '../../transactions/controller/all_transaction_controller.dart';
import '../../transactions/repository/transaction_repository.dart';
import '../../navbar/controller/navbar_controller.dart';
import '../models/parsed_transaction_model.dart';
import 'upload_file_controller.dart';
import '../../virtual_entries/controller/virtual_entries_controller.dart';

class ReviewTransactionsController extends GetxController {
  final TagRepository _repo = TagRepository();
  final TransactionRepository _txnRepo = TransactionRepository();
  late final String fileName;
  late final String bankName;

  late final ParseResult _parseResult;
  late final String _bankAccountNumber;
  @override
  void onInit() {
    final args = Get.arguments as Map<String, dynamic>;
    if (args['parseResult'] != null) {
      _parseResult = args['parseResult'] as ParseResult;
    } else {
      SnackbarService.showError(
        title: 'Error',
        message: 'No parse result found',
      );
      Get.back();
      return;
    }

    _bankAccountNumber = args['bankAccountNumber'] as String? ?? '';
    getTransactions();
    loadTagsThenAutoMatch();
    super.onInit();
  }

  // ── replace _loadTags() with this ──
  Future<void> loadTagsThenAutoMatch() async {
    final result = await _repo.getAllTags();

    tags.assignAll(result);
    _autoMatchTransactions(); // ← run after tags are ready
  }

  // -- auto mathc transactions ----- //
  void _autoMatchTransactions() {
    if (tags.isEmpty) return;

    // Get current bank account number from the first transaction (if any)
    // to identify which transactions belong to which bank account
    final updated = mappableTransactions.map((txn) {
      // Skip manually tagged transactions (user explicitly set, not auto)
      if (txn.tagId != null && !txn.isAutoMatched) return txn;

      final narration = txn.narration.toLowerCase();
      final txnBankAccountNumber = txn.bankAccountNumber;

      TagModel? bestMatch;
      String? bestKeyword;

      // ── STEP 1: Try Bank Account Level tags first (priority = 3 in DB? or 2?)
      // Based on your description: bankAccount=3(int), party=2, global=1
      // But your DB comment says: bankAccount stores account number + int=2 for party, int=1 for global
      // Let's follow: tagPriority=3 → bank account level, =2 → party, =1 → global, =0 → global
      // Actually from your tagTransaction(): Bank=3, Party=2, Global=1
      // And your _autoMatchTransactions comment says Bank(3) > Party(2) > Global(1)

      // Try each scope level in descending priority order
      for (final scopeLevel in [3, 1, 0]) {
        final scopeTags = tags
            .where((t) => t.tagPriority == scopeLevel)
            .toList();

        if (scopeTags.isEmpty) continue;

        // For bank account level, only consider tags matching THIS transaction's bank account
        final filteredTags = scopeLevel == 3
            ? scopeTags
                  .where((t) => t.tagBankAccountId == txnBankAccountNumber)
                  .toList()
            : scopeLevel == 1
            ? scopeTags
                  .where(
                    (t) =>
                        t.tagUserId == LocalStorageService.instance.accountId,
                  )
                  .toList()
            : scopeTags; // global — no filter

        if (filteredTags.isEmpty) continue;

        // Within this scope, find the best matching tag using keyword priorities
        TagModel? scopeMatch;
        String? scopeKeyword;
        int scopeBestKwPriority = 999999; // lower is better

        for (final tag in filteredTags) {
          // Sort keywords by priority ascending (1 = highest priority)
          final sortedKws = List<Map<String, dynamic>>.from(tag.tagKeywords)
            ..sort(
              (a, b) => (a['priority'] as int).compareTo(b['priority'] as int),
            );

          for (final kwData in sortedKws) {
            final name = kwData['name'];
            if (name == null) continue;
            final keyword = name.toString().toLowerCase().trim();
            if (keyword.isEmpty) continue;

            if (narration.contains(keyword)) {
              final kwPriority = (kwData['priority'] as int? ?? 999999);
              // Among all tags in this scope, pick the one with the highest priority keyword match
              if (kwPriority < scopeBestKwPriority) {
                scopeBestKwPriority = kwPriority;
                scopeMatch = tag;
                scopeKeyword = keyword;
              }
              break; // Found best keyword for THIS tag, move to next tag
            }
          }
        }

        if (scopeMatch != null) {
          bestMatch = scopeMatch;
          bestKeyword = scopeKeyword;
          break; // Found a match at this scope level, stop searching lower scopes
        }
      }

      if (bestMatch != null) {
        return txn.copyWith(
          tagId: bestMatch.tagId,
          tagName: bestMatch.tagName,
          isAutoMatched: true,
          matchedKeyword: bestKeyword,
        );
      }

      return txn;
    }).toList();

    mappableTransactions.assignAll(updated);
    _sortTransactions();
  }

  /// ---------------- FETCH TRANSACTIONS ---------------- ///
  void getTransactions() {
    mappableTransactions.assignAll(
      Get.find<UploadFileController>().parsedTransactions.map(
        (txn) => MappableTransaction.fromParsed(txn),
      ),
    );
  }

  /// ---------------- STATE ---------------- ///
  final RxList<MappableTransaction> mappableTransactions =
      <MappableTransaction>[].obs;

  final RxList<MasterAccountModel> masterAccounts = <MasterAccountModel>[].obs;

  final RxMap<String, KeywordMappingModel> keywordMappings =
      <String, KeywordMappingModel>{}.obs;

  final RxList<TagModel> tags = <TagModel>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = ''.obs;

  final RxBool showAllTransactions = true.obs;

  /// ---------------- SORT ---------------- ///
  void _sortTransactions() {
    final sorted = List<MappableTransaction>.from(mappableTransactions);

    sorted.sort((a, b) {
      /// Unmapped first
      if (a.isMapped != b.isMapped) {
        return a.isMapped ? 1 : -1;
      }

      /// Auto matched at bottom
      if (a.isMapped && b.isMapped) {
        if (a.isAutoMatched != b.isAutoMatched) {
          return a.isAutoMatched ? 1 : -1;
        }
      }

      return 0;
    });

    mappableTransactions.assignAll(sorted);
  }

  /// ---------------- STATS ---------------- ///
  int get totalCount => mappableTransactions.length;

  int get mappedCount => mappableTransactions.where((t) => t.isMapped).length;

  int get unmappedCount =>
      mappableTransactions.where((t) => !t.isMapped).length;

  int get autoMatchedCount =>
      mappableTransactions.where((t) => t.isAutoMatched).length;

  int get needReviewCount =>
      unmappedCount +
      mappableTransactions.where((t) => t.isMapped && !t.isAutoMatched).length;

  double get progressRatio => totalCount > 0 ? mappedCount / totalCount : 0.0;

  bool get canSaveAll => unmappedCount == 0;

  /// ---------------- FILTER ---------------- ///
  void toggleFilter() {
    showAllTransactions.value = !showAllTransactions.value;
  }

  String get filterLabel =>
      showAllTransactions.value ? 'Show All' : 'Unmapped Only';

  IconData get filterIcon =>
      showAllTransactions.value ? Icons.visibility : Icons.filter_list;

  List<MappableTransaction> get filteredTransactions {
    var list = mappableTransactions.toList();

    if (!showAllTransactions.value) {
      list = list.where((t) => !t.isMapped).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list
          .where(
            (t) =>
                t.narration.toLowerCase().contains(query) ||
                (t.tagName?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    return list;
  }

  /// =========================================================
  /// TAG SYSTEM (MAIN PART)
  /// =========================================================

  /// Assign existing tag
  void assignTag({required MappableTransaction txn, required TagModel tag}) {
    final index = mappableTransactions.indexWhere(
      (t) => t.txnRef == txn.txnRef,
    );

    if (index == -1) return;

    mappableTransactions[index] = txn.copyWith(
      tagId: tag.tagId,
      tagName: tag.tagName,
      isAutoMatched: false,
    );

    _sortTransactions();
  }

  /// ✅ Create new tag + assign
  Future<void> tagTransaction({
    required MappableTransaction transaction,
    required String tagName,
    required Map<String, int> keywordPriorities,
    required String scopePriorityLabel,
  }) async {
    if (keywordPriorities.isEmpty) {
      SnackbarService.showError(
        title: 'Error',
        message: 'At least one keyword is required.',
      );
      return;
    }

    try {
      isSaving.value = true;

      int scopePriorityValue = 1;
      if (scopePriorityLabel == 'Party Level') scopePriorityValue = 2;
      if (scopePriorityLabel == 'Bank Account Level') scopePriorityValue = 3;

      final now = DateTime.now().toIso8601String();
      TagModel? lastSavedTag;

      final jsonKeywords = keywordPriorities.entries
          .where((e) => e.key.trim().isNotEmpty)
          .map((e) => {"name": e.key.trim().toLowerCase(), "priority": e.value})
          .toList();

      if (jsonKeywords.isNotEmpty) {
        final newTag = TagModel(
          tagName: tagName,
          tagKeywords: jsonKeywords,
          tagPriority: scopePriorityValue,
          tagBankAccountId: null,
          tagUserId: LocalStorageService.instance.accountId,
          tagCreatedAt: now,
          tagUpdatedAt: now,
          tagDeletedAt: null,
        );

        //  Use the shared repo — same instance TagsController uses
        final insertedId = await _repo.addTag(newTag);

        if (insertedId == -1) {
          SnackbarService.showError(
            title: 'Error',
            message: 'Failed to save tag',
          );
        } else {
          final savedTag = newTag.copyWith(tagId: insertedId);
          lastSavedTag = savedTag;

          // ✅ Keep ReviewTransactionsController.tags in sync
          tags.insert(0, savedTag);

          // ✅ Also push into TagsController so its screen stays fresh
          if (Get.isRegistered<TagsController>()) {
            Get.find<TagsController>().tags.insert(0, savedTag);
          }
        }
      }

      if (lastSavedTag != null) {
        assignTag(txn: transaction, tag: lastSavedTag);
        Get.closeAllSnackbars();
        SnackbarService.showSuccess(
          title: 'Success',
          message: 'Tag created & assigned',
        );
      }
    } catch (e) {
      SnackbarService.showError(
        title: 'Error',
        message: 'Something went wrong',
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> saveTransactions() async {
    try {
      isSaving.value = true;
      List<String> importWarnings = [];

      // ── Step 1: Continuity + overlap warnings (Collect them, don't show yet) ──
      final continuityWarning = await _txnRepo.validateOpeningBalanceContinuity(
        result: _parseResult,
        bankAccountNumber: _bankAccountNumber,
      );
      if (continuityWarning != null) {
        importWarnings.add(continuityWarning);
      }

      final hasOverlap = await _txnRepo.hasOverlappingImportRange(
        result: _parseResult,
        bankAccountNumber: _bankAccountNumber,
      );
      if (hasOverlap) {
        importWarnings.add(
          'This statement overlaps a previously imported date range.',
        );
      }

      // ── Step 2: Save import session ───────────────────────────────────
      await _txnRepo.saveStatementImportSassion(
        result: _parseResult,
        bankAccountNumber: _bankAccountNumber,
      );

      // ── Step 3: Insert transactions ───────────────────────────────────
      final totalToSave = mappableTransactions.length;
      final insertResult = await _txnRepo.addBulkTransactions(
        mappableTransactions,
      );

      if (insertResult == -1) {
        Get.closeAllSnackbars();
        SnackbarService.showError(
          title: 'Error',
          message: 'Failed to save transactions',
        );
        isSaving.value = false; // Manually reset before returning
        return;
      }

      // ── Step 3.5: Apply Cash tag dual-effect logic (Feature A) ────────
      // Wait a bit to ensure bulk insert transaction is fully committed
      await Future.delayed(const Duration(milliseconds: 100));
      await _applyCashTagDualEffect();

      // ── Step 4: Recompute balance ─────────────────────────────────────
      if (_bankAccountNumber.isNotEmpty) {
        // Wait to ensure cash wallet operations are complete
        await Future.delayed(const Duration(milliseconds: 50));
        final recomputed = await _txnRepo.recomputeAndSave(_bankAccountNumber);

        // ── Step 5: Reconciliation check ────────────────────────────────
        if (_parseResult.currentBalance != null) {
          final diff = (recomputed - _parseResult.currentBalance!).abs();
          if (diff > 0.01) {
            importWarnings.add(
              'Balance Mismatch! Statement: ₹${_parseResult.currentBalance!.toStringAsFixed(2)}, '
              'Computed: ₹${recomputed.toStringAsFixed(2)}.',
            );
          }
        }
      }

      // ── Step 5.5: Run virtual entry matching (Feature B) ──────────────
      // Wait to ensure all previous DB operations are complete
      await Future.delayed(const Duration(milliseconds: 100));
      await _runVirtualEntryMatching();

      // ── Step 6: Refresh UI Controllers ────────────────────────────────
      try {
        if (Get.isRegistered<DashboardController>()) {
          Get.find<DashboardController>().refreshDashboard();
        }
        if (Get.isRegistered<TagsController>()) {
          Get.find<TagsController>().fetchTags();
        }
        if (Get.isRegistered<AllTransactionsController>()) {
          Get.find<AllTransactionsController>().fetchAllTransactions();
        }
      } catch (_) {}

      if (Get.isRegistered<NavbarController>()) {
        Get.find<NavbarController>().resetScrollTracking();
      }

      // ── Step 7: Safely Navigate FIRST, then show Snackbars/Dialogs ──

      final bool allSkipped = insertResult == 0 && totalToSave > 0;
      final bool someSkipped = insertResult > 0 && insertResult < totalToSave;

      // Stop the loading spinner BEFORE navigating to prevent disposed-controller errors
      isSaving.value = false;

      // Clear the routing stack to trigger empty state
      mappableTransactions.clear();

      // Add a slight delay to allow the new route's overlay to build
      Future.delayed(const Duration(milliseconds: 300), () {
        Get.closeAllSnackbars();

        if (allSkipped) {
          DialogService.showSuccessDialog(
            title: 'Already Imported',
            description:
                'All transactions were skipped because they are already in the database.',
            confirmText: 'Okay',
            onConfirm: () => Get.back(),
          );
        } else if (someSkipped) {
          DialogService.showConfirmDialog(
            title: 'Partially Saved',
            description:
                '$insertResult transactions saved successfully. ${totalToSave - insertResult} were skipped as they are already in the database.',
            confirmText: 'Okay',
            onConfirm: () => Get.back(),
          );
        } else {
          // If there were warnings, show them so the user actually sees them
          if (importWarnings.isNotEmpty) {
            SnackbarService.showWarning(
              title: 'Saved with Warnings',

              message: importWarnings.join('\n\n'),
            );
          } else {
            SnackbarService.showSuccess(
              title: 'Success',
              message: '$insertResult transactions saved successfully',
            );
          }
        }
      });
    } catch (e) {
      isSaving.value = false;
      Get.closeAllSnackbars();
      SnackbarService.showError(
        title: 'Error',
        message: 'Something went wrong: $e',
      );
      debugPrint('[ReviewTransactionsController] saveTransactions error: $e');
    }
    // Removed the 'finally { isSaving.value = false; }' block because doing this
    // after Get.offNamedUntil can cause a crash if the controller was disposed.
  }

  /// FEATURE A: Apply dual-effect logic for transactions tagged with Cash
  Future<void> _applyCashTagDualEffect() async {
    // Check if CashTagService is registered
    if (!Get.isRegistered<CashTagService>()) {
      debugPrint(
        '[ReviewTransactionsController] CashTagService not registered, skipping dual-effect logic',
      );
      return; // Service not initialized yet
    }

    final cashTagService = Get.find<CashTagService>();

    // Check if CashTagService is initialized
    if (!cashTagService.isInitialized.value) {
      debugPrint(
        '[ReviewTransactionsController] CashTagService not initialized, skipping dual-effect logic',
      );
      return;
    }

    // Find all transactions tagged with Cash
    final cashTransactions = mappableTransactions
        .where((txn) => cashTagService.isCashTag(txn.tagId))
        .toList();

    if (cashTransactions.isEmpty) {
      debugPrint(
        '[ReviewTransactionsController] No cash-tagged transactions found',
      );
      return;
    }

    debugPrint(
      '[ReviewTransactionsController] Processing ${cashTransactions.length} cash-tagged transactions',
    );

    int successCount = 0;
    int failureCount = 0;

    for (final txn in cashTransactions) {
      try {
        await cashTagService.applyDualEffect(
          txnType: txn.type,
          txnAmount: txn.amount,
          txnDate: txn.date,
          txnNarration: txn.narration,
          bankAccountNumber: txn.bankAccountNumber,
        );
        successCount++;
      } catch (e, stackTrace) {
        failureCount++;
        debugPrint(
          '[ReviewTransactionsController] Failed to apply dual-effect for transaction:\n'
          '  Ref: ${txn.txnRef}\n'
          '  Type: ${txn.type}\n'
          '  Amount: ${txn.amount}\n'
          '  Date: ${txn.date}\n'
          '  Narration: ${txn.narration}\n'
          '  Bank Account: ${txn.bankAccountNumber}\n'
          '  Error: $e\n'
          '  Stack trace: $stackTrace',
        );
      }
    }

    debugPrint(
      '[ReviewTransactionsController] Cash dual-effect completed: '
      '$successCount succeeded, $failureCount failed',
    );
  }

  /// FEATURE B: Run virtual entry matching after import
  Future<void> _runVirtualEntryMatching() async {
    try {
      // Register with fenix: true so the SAME instance is reused when
      // VirtualEntriesScreen opens. If already registered, Get.lazyPut
      // with fenix: true is a no-op — it will not overwrite the existing one.
      if (!Get.isRegistered<VirtualEntriesController>()) {
        Get.lazyPut<VirtualEntriesController>(
          () => VirtualEntriesController(),
          fenix: true,
        );
      }

      final veController = Get.find<VirtualEntriesController>();

      await veController.runAutoMatching(
        bankAccountNumber: _bankAccountNumber,
        importDateRange: (_parseResult.fromDate, _parseResult.toDate),
      );
    } catch (e) {
      debugPrint(
        '[ReviewTransactionsController] Virtual entry matching error: $e',
      );
    }
  }
}

/// Extended model with clean name and auto-match tracking
class MappableTransaction {
  final String txnRef;
  final String date;
  final String narration;
  final String cleanName;
  final double amount;
  final String type;
  final String? accountName;
  final String bankAccountNumber;
  final bool isAutoMatched;
  final String? matchedKeyword;

  /// ✅ TAG STATE
  final int? tagId;
  final String? tagName;

  MappableTransaction({
    required this.txnRef,
    required this.date,
    required this.narration,
    required this.cleanName,
    required this.amount,
    required this.type,
    required this.bankAccountNumber,
    this.accountName,
    this.isAutoMatched = false,
    this.matchedKeyword,
    this.tagId,
    this.tagName,
  });

  factory MappableTransaction.fromParsed(ParsedTransactionModel parsed) {
    return MappableTransaction(
      txnRef: parsed.txnRef,
      date: parsed.date,
      narration: parsed.narration,
      cleanName: NarrationCleaner.parse(parsed.narration).partyName,
      amount: parsed.amount,
      type: parsed.type,
      bankAccountNumber: parsed.bankAccountNumber ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    if (tagId == null) {
      throw Exception("Transaction not tagged: $txnRef");
    }

    final now = DateTime.now().toIso8601String();

    return {
      TXN_DATE: date,
      TXN_ACCOUNT_ID: bankAccountNumber,
      TXN_NARRATION: narration,
      TXN_TAG_ID: tagId,
      TXN_AMOUNT: amount,
      TXN_TYPE: type.toUpperCase(),
      TXN_REF: txnRef,
      CREATED_AT: now,
      UPDATED_AT: now,
      DELETED_AT: null,
    };
  }

  bool get isDebit =>
      type.toLowerCase() == 'dr' || type.toLowerCase() == 'debit';

  bool get isCredit =>
      type.toLowerCase() == 'cr' || type.toLowerCase() == 'credit';

  /// ✅ IMPORTANT: NOW TAG BASED
  bool get isMapped => tagId != null;

  MappableTransaction copyWith({
    String? txnRef,
    String? date,
    String? narration,
    String? cleanName,
    double? amount,
    String? type,
    bool? isAutoMatched,
    String? matchedKeyword,
    int? tagId,
    String? tagName,
    String? bankAccountNumber,
  }) {
    return MappableTransaction(
      txnRef: txnRef ?? this.txnRef,
      date: date ?? this.date,
      narration: narration ?? this.narration,
      cleanName: cleanName ?? this.cleanName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      isAutoMatched: isAutoMatched ?? this.isAutoMatched,
      matchedKeyword: matchedKeyword ?? this.matchedKeyword,
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    );
  }
}
