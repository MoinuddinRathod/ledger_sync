import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/snackbar_service.dart';
import '../../bank_account/controllers/bank_account_controller.dart';
import '../../bank_account/models/bank_account_model.dart';
import '../../transactions/models/bank_transaction_model.dart';
import '../../transactions/repository/transaction_repository.dart';
import '../models/tag_model.dart';
import '../repository/tag_repositary.dart';

// model class for keywords
class KeywordEntry {
  String keyword;
  final TextEditingController ctrl;

  KeywordEntry({required this.keyword})
    : ctrl = TextEditingController(text: keyword);

  void dispose() => ctrl.dispose();
}

class TagsController extends GetxController {
  // ------------------------------------------------------------------ //
  // Dependencies
  // ------------------------------------------------------------------ //
  final TagRepository _repo = TagRepository();
  final TransactionRepository _txnRepo = TransactionRepository();
  final bankController = Get.find<BankAccountController>();

  // ------------------------------------------------------------------ //
  // Observable State
  // ------------------------------------------------------------------ //

  /// Full list of tags (filtered view)
  final RxList<TagModel> _allTags = <TagModel>[].obs;
  final RxList<TagModel> tags = <TagModel>[].obs;

  /// { tagId → txn count } — populated by [fetchTagTransactionCounts]
  final RxMap<int, int> tagTransactionCounts = <int, int>{}.obs;

  /// Transactions for the currently selected tag (used by TagTransactionsScreen)
  final RxList<BankTransactionModel> tagTransactions =
      <BankTransactionModel>[].obs;

  final RxBool isLoadingTagTxns = false.obs;

  // ─────────────────────────────────────────────────────
  // Create Tag Screen State (NEW)
  // ─────────────────────────────────────────────────────

  String? narration;

  final addKeywordCtrl = TextEditingController();
  final FocusNode addKeywordFocus = FocusNode();

  final RxList<KeywordEntry> keywordList = <KeywordEntry>[].obs;
  final RxString selectedScope = 'Bank Account Level'.obs;

  List<String> get scopeOptions {
    if (hasNoBankAccounts) {
      return ['Party Level', 'Global'];
    }
    return ['Bank Account Level', 'Party Level', 'Global'];
  }

  final formKey = GlobalKey<FormState>();
  final tagNameCtrl = TextEditingController();
  final tagPriorityCtrl = TextEditingController();

  // Keep track of the tag being edited (null if adding new)
  TagModel? editingTag;

  /// Per-operation loading flags — bind each to its own UI indicator
  final RxBool isLoadingFetch = false.obs;
  final RxBool isLoadingAdd = false.obs;
  final RxBool isLoadingUpdate = false.obs;
  final RxBool isLoadingDelete = false.obs;

  // ---------- Getters -------------- //
  bool get hasNoBankAccounts => bankAccounts.isEmpty;
  bool get hasSingleBankAccount => bankAccounts.length == 1;
  bool get hasMultipleBankAccounts => bankAccounts.length > 1;

  /// True whenever ANY operation is in progress
  bool get isBusy =>
      isLoadingFetch.value ||
      isLoadingAdd.value ||
      isLoadingUpdate.value ||
      isLoadingDelete.value;

  // ------------------------------------------------------------------ //
  // Filters / Search / Sort (kept from original skeleton)
  // ------------------------------------------------------------------ //

  final RxBool isSearching = false.obs;
  final RxString searchQuery = ''.obs;

  final sortOptions = ['Newest', 'Oldest', 'Priority ↑', 'Priority ↓'].obs;
  final RxString selectedSort = 'Newest'.obs;

  final Rxn<DateTime> dateFrom = Rxn<DateTime>();
  final Rxn<DateTime> dateTo = Rxn<DateTime>();
  final RxString selectedDateRange = ''.obs;

  RxList<BankAccountModel> bankAccounts = <BankAccountModel>[].obs;

  final Rxn<BankAccountModel> selectedBankAccount = Rxn<BankAccountModel>();

  // ------------------------------------------------------------------ //
  // Lifecycle
  // ------------------------------------------------------------------ //

  @override
  void onInit() {
    super.onInit();
    fetchTags();

    fetchBankAccouts();
    // ✅ FIX: Set valid default scope
    if (hasNoBankAccounts) {
      selectedScope.value = 'Global';
    } else {
      selectedScope.value = 'Bank Account Level';
    }
  }

  // ------- fetch bank accounts --------- //
  fetchBankAccouts() {
    bankAccounts.assignAll(bankController.bankAccounts);
  }

  String _toTitleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void initCreateTag({
    String? narrationArg,
    String? prefilledName,
    List<String> keywords = const [],
  }) {
    editingTag = null;
    narration = narrationArg;

    tagNameCtrl.text =
        prefilledName ??
        (keywords.isNotEmpty ? _toTitleCase(keywords.first) : '');

    keywordList.clear();

    for (final kw in keywords) {
      keywordList.add(KeywordEntry(keyword: kw.toLowerCase()));
    }
    // ✅ FIX: Ensure valid scope every time screen opens
    if (hasNoBankAccounts) {
      selectedScope.value = 'Global';
    }
  }

  void addKeyword() {
    final text = addKeywordCtrl.text.trim().toLowerCase();
    if (text.isEmpty) return;

    final exists = keywordList.any((e) => e.keyword == text);
    if (!exists) {
      keywordList.add(KeywordEntry(keyword: text));
    }

    addKeywordCtrl.clear();
    addKeywordFocus.requestFocus();
  }

  void removeKeyword(int index) {
    final entry = keywordList[index];
    keywordList.removeAt(index);
    entry.dispose();
  }

  void reorderKeyword(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = keywordList.removeAt(oldIndex);
    keywordList.insert(newIndex, item);
  }

  void changeScope(String value) {
    //  Prevent invalid selection
    if (value == 'Bank Account Level' && hasNoBankAccounts) {
      SnackbarService.showWarning(
        title: 'Not Allowed',
        message: 'No bank accounts available',
      );
      return;
    }
    selectedScope.value = value;

    if (value == 'Bank Account Level') {
      if (hasSingleBankAccount) {
        //  Auto select
        selectedBankAccount.value = bankAccounts.first;
      } else {
        // reset selection
        selectedBankAccount.value = null;
      }
    } else {
      // Not needed for other scopes
      selectedBankAccount.value = null;
    }
  }

  // ---- map priority
  int mapScopeToPriority(String scope) {
    switch (scope) {
      case 'Global':
        return 2;
      case 'Party Level':
        return 1;
      case 'Bank Account Level':
        return 0;
      default:
        return 2;
    }
  }

  // --- map priority to scope ---
  String mapPriorityToScope(int priority) {
    switch (priority) {
      case 0:
        return 'Bank Account Level';
      case 1:
        return 'Party Level';
      case 2:
        return 'Global';
      default:
        return 'Global';
    }
  }

  Future<void> saveCreatedTag() async {
    final tagName = tagNameCtrl.text.trim();

    // ── Validate tag name ──
    if (tagName.isEmpty) {
      SnackbarService.showWarning(
        title: 'Validation',
        message: 'Tag name is required',
      );
      return;
    }

    // ── Validate keywords ──
    if (keywordList.isEmpty) {
      SnackbarService.showWarning(
        title: 'Validation',
        message: 'Add at least one keyword',
      );
      return;
    }

    // ── Validate bank account selection for Bank Account Level ──
    if (selectedScope.value == 'Bank Account Level' &&
        selectedBankAccount.value == null) {
      SnackbarService.showWarning(
        title: 'Validation',
        message: 'Please select a bank account',
      );
      return;
    }

    // ── Validate master account (user must be logged in) ──
    final accountId = LocalStorageService.instance.accountId;
    if (accountId <= 0) {
      SnackbarService.showError(
        title: 'Session Error',
        message: 'Invalid session. Please log in again.',
      );
      return;
    }

    try {
      isLoadingAdd.value = true;

      final now = DateTime.now().toIso8601String();

      // Resolve the correct FK values based on scope:
      //   tag_bank_account_id → bank_accounts.bank_account_number (encrypted TEXT PK)
      //   tag_user_id         → accounts.account_id (INTEGER PK)
      final String? bankAccountFk;
      switch (selectedScope.value) {
        case 'Bank Account Level':
          // Must use the encrypted account number — that is the PK of bank_accounts
          final bank = selectedBankAccount.value;
          if (bank == null || bank.encryptedAccountNumber.isEmpty) {
            SnackbarService.showError(
              title: 'Error',
              message: 'Selected bank account is invalid. Please re-select.',
            );
            return;
          }
          bankAccountFk = bank.encryptedAccountNumber;
          break;
        default:
          // Party Level / Global — no bank account FK
          bankAccountFk = null;
      }

      // Save ONE row per tag, packing all keywords
      List<Map<String, dynamic>> keywordsToSave = [];
      for (int i = 0; i < keywordList.length; i++) {
        final kw = keywordList[i];
        if (kw.keyword.trim().isEmpty) continue;
        keywordsToSave.add({
          "name": kw.keyword.trim().toLowerCase(),
          "priority": i + 1,
        });
      }

      if (keywordsToSave.isEmpty) {
        SnackbarService.showWarning(
          title: 'Nothing Saved',
          message: 'No valid keywords were saved.',
        );
        return;
      }

      final model = TagModel(
        tagId: editingTag?.tagId, // Passed if editing
        tagName: tagName,
        tagKeywords: keywordsToSave,
        tagPriority: mapScopeToPriority(selectedScope.value),
        tagBankAccountId: bankAccountFk,
        tagUserId: accountId,
        tagCreatedAt:
            editingTag?.tagCreatedAt ?? now, // Retain original creation date
        tagUpdatedAt: now,
        tagDeletedAt: editingTag?.tagDeletedAt,
      );

      // Perform update or insert based on editing mode
      if (editingTag != null) {
        isLoadingUpdate.value = true;
        final updated = await _repo.updateTag(model);
        if (updated == 0) {
          SnackbarService.showError(
            title: 'Update Failed',
            message: 'Could not update tag. Please try again.',
          );
          return;
        }
      } else {
        final inserted = await _repo.addTag(model);
        if (inserted == -1) {
          SnackbarService.showError(
            title: 'Save Failed',
            message: 'Could not save tag. Please try again.',
          );
          return;
        }
      }

      await fetchTags();

      Get.back(
        result: {
          'tagName': tagName,
          'keywords': keywordList.map((e) => e.keyword).toList(),
          'scope': selectedScope.value,
        },
      );

      SnackbarService.showSuccess(
        title: editingTag != null ? 'Tag Updated' : 'Tag Created',
        message: editingTag != null
            ? '$tagName updated successfully.'
            : '{tagName} saved with {count} keyword{s}.'
                  .replaceAll('{tagName}', tagName)
                  .replaceAll('{count}', keywordsToSave.length.toString())
                  .replaceAll('{s}', keywordsToSave.length > 1 ? 's' : ''),
      );

      clearCreateTagState();
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      log('[TagsController] saveCreatedTag error: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Error',
        message:
            'Failed to ${editingTag != null ? "update" : "create"} tag. Please try again.',
      );
    } finally {
      isLoadingAdd.value = false;
      isLoadingUpdate.value = false;
    }
  }

  void clearCreateTagState() {
    narration = null;
    tagNameCtrl.clear();
    editingTag = null;
    addKeywordCtrl.clear();
    for (final e in keywordList) e.dispose();
    keywordList.clear();
    // ✅ FIX: reset safely
    selectedScope.value = hasNoBankAccounts ? 'Global' : 'Bank Account Level';
    selectedBankAccount.value = null;
  }

  // ------------------------------------------------------------------ //
  // FETCH — loads based on current filter
  // ------------------------------------------------------------------ //

  Future<void> fetchTags() async {
    if (isLoadingFetch.value) return; // prevent concurrent fetches

    try {
      isLoadingFetch.value = true;

      List<TagModel> result;

      result = await _repo.getAllTags();

      _allTags.assignAll(result);
      tags.assignAll(_applySortAndSearch(_allTags));

      if (result.isEmpty) {
        log('[TagsController] fetchTags: empty list');
      }

      // ── Refresh transaction counts in parallel ──
      fetchTagTransactionCounts();
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      log('[TagsController] fetchTags: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Load Failed',
        message: 'Could not load tags. Please try again.',
      );
    } finally {
      isLoadingFetch.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // TAG TRANSACTION COUNTS
  // ------------------------------------------------------------------ //

  /// Fetches { tagId → count } from the DB and populates [tagTransactionCounts].
  Future<void> fetchTagTransactionCounts() async {
    try {
      final accountId = LocalStorageService.instance.accountId;
      if (accountId <= 0) return;
      final counts = await _txnRepo.getCountsByTag(accountId);
      tagTransactionCounts.assignAll(counts);
      log(
        '[TagsController] fetchTagTransactionCounts: ${counts.length} tags with transactions',
      );
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      log('[TagsController] fetchTagTransactionCounts: $e', stackTrace: stack);
      // Non-critical — silently fail; counts will just show 0
    }
  }

  /// Returns the transaction count for [tagId], defaulting to 0.
  int transactionCountForTag(int? tagId) {
    if (tagId == null) return 0;
    return tagTransactionCounts[tagId] ?? 0;
  }

  // ------------------------------------------------------------------ //
  // FETCH TRANSACTIONS FOR A SPECIFIC TAG
  // ------------------------------------------------------------------ //

  /// Loads all transactions under [tagId] into [tagTransactions].
  /// Call this before navigating to TagTransactionsScreen.
  Future<void> fetchTransactionsForTag(int tagId) async {
    if (isLoadingTagTxns.value) return;
    try {
      isLoadingTagTxns.value = true;
      tagTransactions.clear();

      final accountId = LocalStorageService.instance.accountId;
      if (accountId <= 0) {
        SnackbarService.showWarning(
          title: 'Session Error',
          message: 'Please log in again.',
        );
        return;
      }

      final result = await _txnRepo.getByTagId(tagId, accountId);
      tagTransactions.assignAll(result);
      log(
        '[TagsController] fetchTransactionsForTag(tagId=$tagId): ${result.length} rows',
      );
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      log('[TagsController] fetchTransactionsForTag: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Load Failed',
        message: 'Could not load transactions for this tag.',
      );
    } finally {
      isLoadingTagTxns.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // CHANGE TRANSACTION TAG
  // ------------------------------------------------------------------ //

  /// Returns true when [txn] was imported from a bank statement
  /// (i.e. [isManual] == false → TXN_IS_MANUAL = 0 in the DB).
  bool isImportedTransaction(BankTransactionModel txn) => !txn.isManual;

  /// Reassigns [transaction] to [newTag], updates the DB, removes the row
  /// from the current tag's list, and refreshes tag totals.
  Future<void> changeTransactionTag({
    required BankTransactionModel transaction,
    required TagModel newTag,
  }) async {
    // Guard: same tag selected — no-op
    if (transaction.txnTagId == newTag.tagId) return;

    try {
      final updated = await _txnRepo.updateTransactionTag(
        txnId: transaction.txnId,
        newTagId: newTag.tagId!,
      );

      if (updated <= 0) {
        SnackbarService.showError(
          title: 'Update Failed',
          message: 'Could not change tag. Please try again.',
        );
        return;
      }

      // Remove transaction from current tag's list immediately
      tagTransactions.removeWhere((t) => t.txnId == transaction.txnId);

      // Refresh tag list so CR/DR totals and counts update for both tags.
      // fetchTags() calls fetchTagTransactionCounts() internally.
      await fetchTags();

      SnackbarService.showSuccess(
        title: 'Tag Changed',
        message: 'Transaction moved to ${newTag.tagName}.',
      );
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      log('[TagsController] changeTransactionTag: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Error',
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Fetch tags scoped to a specific bank account (Party level use-case).
  Future<void> fetchTagsByBankAccount(String encryptedBankAccountId) async {
    if (encryptedBankAccountId.isEmpty) return;
    if (isLoadingFetch.value) return;

    try {
      isLoadingFetch.value = true;
      final result = await _repo.getTagsByBankAccountId(encryptedBankAccountId);
      _allTags.assignAll(result);
      tags.assignAll(_applySortAndSearch(_allTags));
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      log('[TagsController] fetchTagsByBankAccount: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Load Failed',
        message: 'Could not load tags for this account.',
      );
    } finally {
      isLoadingFetch.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // UPDATE
  // ------------------------------------------------------------------ //
  Future<void> updateTag() async {
    if (!formKey.currentState!.validate()) return;
    if (isLoadingUpdate.value) return;
    if (editingTag == null) return;

    final now = DateTime.now().toIso8601String();

    List<Map<String, dynamic>> keywordsToSave = [];
    for (int i = 0; i < keywordList.length; i++) {
      final kw = keywordList[i];
      if (kw.keyword.trim().isEmpty) continue;
      keywordsToSave.add({
        "name": kw.keyword.trim().toLowerCase(),
        "priority": i + 1,
      });
    }

    final model = editingTag!.copyWith(
      tagName: tagNameCtrl.text.trim(),
      tagKeywords: keywordsToSave,
      tagPriority:
          int.tryParse(tagPriorityCtrl.text.trim()) ?? editingTag!.tagPriority,
      tagUpdatedAt: now,
    );

    final String? error = _validateModel(model);
    if (error != null) {
      SnackbarService.showWarning(title: 'Validation Error', message: error);
      return;
    }

    try {
      isLoadingUpdate.value = true;
      final int rowsAffected = await _repo.updateTag(model);
      if (rowsAffected == 0) {
        SnackbarService.showWarning(
          title: 'Not Found',
          message: 'Tag not found to update.',
        );
        return;
      }
      final int idx = _allTags.indexWhere((e) => e.tagId == editingTag!.tagId);
      if (idx != -1) _allTags[idx] = model;

      Get.back();
      SnackbarService.showSuccess(
        title: 'Tag Updated',
        message: '{tagName} updated successfully.'.replaceAll(
          '{tagName}',
          model.tagName,
        ),
      );
      _refreshView();
      clearForm();
      editingTag = null;
      _closeSheet();
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      log('[TagsController] updateTag: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Update Failed',
        message: 'Unexpected error.',
      );
    } finally {
      isLoadingUpdate.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // DELETE — soft delete
  // ------------------------------------------------------------------ //
  Future<void> deleteTag({required int tagId}) async {
    if (tagId <= 0) return;
    if (isLoadingDelete.value) return;

    try {
      isLoadingDelete.value = true;
      final int rowsAffected = await _repo.deleteTag(tagId);
      if (rowsAffected == 0) {
        SnackbarService.showWarning(
          title: 'Not Found',
          message: 'Tag not found to delete.',
        );
        return;
      }
      _allTags.removeWhere((e) => e.tagId == tagId);
      _refreshView();
      Get.back();
      SnackbarService.showSuccess(
        title: 'Tag Deleted',
        message: 'Tag deleted successfully.',
      );
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      log('[TagsController] deleteTag: $e', stackTrace: stack);
      SnackbarService.showError(
        title: 'Delete Failed',
        message: 'Unexpected error.',
      );
    } finally {
      isLoadingDelete.value = false;
    }
  }

  // ------------------------------------------------------------------ //
  // initForm — pre-fill form for editing
  // ------------------------------------------------------------------ //
  void initForm(TagModel? tag) {
    log("initForm called");

    editingTag = tag;

    if (tag != null) {
      log("Editing Tag ID: ${tag.tagId}");
      log("Tag Name: ${tag.tagName}");
      log("Tag Priority: ${tag.tagPriority}");
      log("Tag User ID: ${tag.tagUserId}");
      log("Tag Bank Account ID: ${tag.tagBankAccountId}");
      log("Tag Created At: ${tag.tagCreatedAt}");
      log("Tag Updated At: ${tag.tagUpdatedAt}");

      tagNameCtrl.text = tag.tagName;
      tagPriorityCtrl.text = mapPriorityToScope(tag.tagPriority);
      selectedScope.value = mapPriorityToScope(tag.tagPriority);

      // Auto-select bank account if scope is Bank Account Level
      if (selectedScope.value == 'Bank Account Level' &&
          tag.tagBankAccountId != null) {
        selectedBankAccount.value = bankAccounts.firstWhereOrNull(
          (b) => b.encryptedAccountNumber == tag.tagBankAccountId,
        );
      } else {
        selectedBankAccount.value = null;
      }

      keywordList.clear();

      log("Keywords:");

      for (final kw in tag.tagKeywords) {
        final name = kw["name"]?.toString() ?? "";
        final priority = kw["priority"]?.toString() ?? "";

        if (name.isNotEmpty) {
          log(" - Keyword: $name | Priority: $priority");
          keywordList.add(KeywordEntry(keyword: name));
        }
      }
    } else {
      log("initForm called with NULL tag (create mode)");
      clearForm();
    }
  }
  // ------------------------------------------------------------------ //
  // Filter / Sort / Search helpers
  // ------------------------------------------------------------------ //

  void setSort(String sort) {
    selectedSort.value = sort;
    _refreshView();
  }

  void _refreshView() {
    tags.assignAll(_applySortAndSearch(_allTags));
  }

  List<TagModel> _applySortAndSearch(List<TagModel> source) {
    List<TagModel> list = List.from(source);

    // Search filter
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list.where((t) {
        if (t.tagName.toLowerCase().contains(q)) return true;
        for (var kw in t.tagKeywords) {
          if (kw["name"] != null &&
              kw["name"].toString().toLowerCase().contains(q)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    // Sort
    switch (selectedSort.value) {
      case 'Oldest':
        list.sort((a, b) => a.tagCreatedAt.compareTo(b.tagCreatedAt));
        break;
      case 'Priority ↑':
        list.sort((a, b) => a.tagPriority.compareTo(b.tagPriority));
        break;
      case 'Priority ↓':
        list.sort((a, b) => b.tagPriority.compareTo(a.tagPriority));
        break;
      case 'Newest':
      default:
        list.sort((a, b) => b.tagCreatedAt.compareTo(a.tagCreatedAt));
        break;
    }

    return list;
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    dateFrom.value = from;
    dateTo.value = to;

    if (from != null && to != null) {
      if (from.year == to.year &&
          from.month == to.month &&
          from.day == to.day) {
        selectedDateRange.value = DateFormat('dd MMM').format(from);
      } else {
        selectedDateRange.value =
            '${DateFormat('dd MMM').format(from)} - ${DateFormat('dd MMM').format(to)}';
      }
    } else if (from != null) {
      selectedDateRange.value = 'From ${DateFormat('dd MMM').format(from)}';
    } else if (to != null) {
      selectedDateRange.value = 'Until ${DateFormat('dd MMM').format(to)}';
    } else {
      selectedDateRange.value = '';
    }
  }

  void clearDateRange() {
    dateFrom.value = null;
    dateTo.value = null;
    selectedDateRange.value = '';
  }

  Future<void> pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: dateFrom.value != null && dateTo.value != null
          ? DateTimeRange(start: dateFrom.value!, end: dateTo.value!)
          : null,
    );
    if (picked != null) {
      setDateRange(picked.start, picked.end);
    }
  }

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) clearSearch();
  }

  void clearSearch() {
    searchQuery.value = '';
    _refreshView();
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    _refreshView();
  }

  // ------------------------------------------------------------------ //
  // Validation
  // ------------------------------------------------------------------ //
  String? _validateModel(TagModel model) {
    if (model.tagName.trim().isEmpty) return 'Tag name cannot be empty.';
    if (model.tagKeywords.isEmpty) return 'Keyword cannot be empty.';
    if (model.tagPriority < 0) return 'Priority cannot be negative.';
    return null;
  }

  void _closeSheet() {
    if (Get.isBottomSheetOpen == true || Get.isDialogOpen == true) Get.back();
  }

  void clearForm() {
    tagNameCtrl.clear();
    tagPriorityCtrl.clear();
    for (final e in keywordList) e.dispose();
    keywordList.clear();
    editingTag = null;
  }
}
