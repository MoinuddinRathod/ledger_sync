// MODIFIED: New model for Feature B - Virtual Entry Auto-Matching
// MODIFIED: Added isCashWalletMatch field and sourceLabel getter for cash wallet transaction matching
import '../../../core/utils/app_constants.dart';

/// Represents a matched pair of virtual entry and transaction
class VirtualEntryMatch {
  final Map<String, dynamic> virtualEntry;
  final Map<String, dynamic> matchedTransaction;
  final double amountDifference;
  final bool isCashWalletMatch;

  VirtualEntryMatch({
    required this.virtualEntry,
    required this.matchedTransaction,
    required this.amountDifference,
    this.isCashWalletMatch = false,
  });

  int get virtualEntryId => virtualEntry[VIRTUAL_ENTRY_ID] as int;
  int get txnId => matchedTransaction[TXN_ID] as int;

  String get entryType => virtualEntry[VE_ENTRY_TYPE] as String? ?? '';
  double get entryAmount =>
      (virtualEntry[VE_AMOUNT] as num?)?.toDouble() ?? 0.0;
  String get entryNote => virtualEntry[VE_NOTE] as String? ?? '';
  String get tagName =>
      virtualEntry['resolvedTagName'] as String? ?? 'Untagged';

  String get txnNarration => matchedTransaction[TXN_NARRATION] as String? ?? '';
  double get txnAmount =>
      (matchedTransaction[TXN_AMOUNT] as num?)?.toDouble() ?? 0.0;
  String get txnDate => matchedTransaction[TXN_DATE] as String? ?? '';
  String get txnType => matchedTransaction[TXN_TYPE] as String? ?? '';
  String get bankName => matchedTransaction['bank_name'] as String? ?? '';
  String get lastFourDigits =>
      matchedTransaction['last_four_digits'] as String? ?? '';

  bool get isReceivable => entryType == 'Receivable';
  bool get isPayable => entryType == 'Payable';

  /// Returns a user-friendly label for the transaction source
  String get sourceLabel {
    if (isCashWalletMatch) {
      return 'Cash Wallet';
    } else {
      return bankName.isNotEmpty ? bankName : 'Bank Account';
    }
  }
}
