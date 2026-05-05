import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/service/dialog_service.dart';
import '../../../routes/app_routes.dart';
import '../../tags/controllers/tags_controller.dart';
import '../controllers/review_transactions_controller.dart';

// List<String> _buildKeywordPreview(MappableTransaction txn) {
//   final set = <String>{};

//   // Words to STRIP entirely (generic banking noise, transaction type prefixes)
//   final stripWords = RegExp(
//     r'\b(dep|wdl|tfr|transfer|payment|credit|debit|toward|towards|being|'
//     r'charges|charge|fee|fees|amt|amount|bal|bal\.|balance|opening|closing|'
//     r'total|ledger|available|trf|to|by|for|of|on|at|the|and|ref|no|'
//     r'transaction|txn|settled|settlement|received|sent|mandate|emi|auto|'
//     r'registered|unregistered|autopay|nach|ach|ecs|standing|instruction|'
//     r'return|reversal|reversed|bounced|failed|success|pending|processed|'
//     r'dated|date|value|dr|cr|inr|rs|rupees|via)\b',
//     caseSensitive: false,
//   );

//   // Words to KEEP as-is (important banking channels / methods)
//   final keepWords = {
//     'neft', 'rtgs', 'imps', 'upi', 'atm', 'pos', 'mmts',
//     'nach', 'ach', // keep these even though they're in stripWords above?
//     // Actually NACH/ACH are generic infrastructure — remove from keepWords if you want
//   };

//   final narration = txn.narration;

//   // Remove amount/balance patterns first (numbers, decimals, commas in numbers)
//   String cleaned = narration
//       .replaceAll(RegExp(r'\b\d{1,3}(,\d{3})*(\.\d+)?\b'), ' ') // 1,23,456.78
//       .replaceAll(RegExp(r'\b\d+(\.\d+)?\b'), ' ') // plain numbers
//       .replaceAll(RegExp(r'@[A-Za-z0-9._]+'), ' ') // @upi handles
//       .replaceAll(RegExp(r'[^\w\s]'), ' ') // punctuation
//       .trim();

//   // Tokenize
//   final tokens = cleaned
//       .split(RegExp(r'\s+'))
//       .map((t) => t.trim().toLowerCase())
//       .where((t) => t.length >= 3)
//       .toList();

//   for (final token in tokens) {
//     // Always keep important channel words
//     if (keepWords.contains(token)) {
//       set.add(token);
//       continue;
//     }

//     // Skip bank names (common ones)
//     // if (RegExp(
//     //   r'^(sbi|hdfc|icici|axis|kotak|pnb|bob|yesbank|indusind|canara|'
//     //   r'union|idbi|idfc|federal|rbl|bandhan|paytm|phonepe|gpay|bhim|'
//     //   r'googlepay|amazon|flipkart|juspay|razorpay|cashfree),
//     // ).hasMatch(token))
//     //   continue;

//     // Skip generic banking noise
//     if (stripWords.hasMatch(token)) continue;

//     // Skip if it looks like a date fragment (jan, feb, 2024, etc.)
//     if (RegExp(
//       r^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{4}),
//     ).hasMatch(token))
//       continue;

//     // Skip very short or all-digit tokens
//     if (token.length < 3) continue;

//     set.add(token);
//   }

//   final result = set.toList()..sort();
//   return result.take(10).toList();
// }

/// ----- new keyword build method (first try)
List<String> _buildKeywordPreview(MappableTransaction txn) {
  final narration = txn.narration.trim();
  final result = <String>{};

  final noiseTokens = {
    'dr',
    'cr',
    'txn',
    'ref',
    'no',
    'num',
    'to',
    'by',
    'for',
    'at',
    'of',
    'and',
    'via',
    'the',
    'on',
    'in',
    'rs',
    'inr',
    'amt',
    'bal',
    'dep',
    'wdl',
    'tfr',
    'trf',
    'upi',
    'neft',
    'rtgs',
    'imps',
    'atm',
    'pos',
    'nach',
    'ach',
    'ecs',
    'transfer',
    'payment',
    'transaction',
    'debit',
    'credit',
    'balance',
    'opening',
    'closing',
    'settled',
    'settlement',
    'received',
    'sent',
    'return',
    'reversal',
    'failed',
    'success',
    'pending',
    'processed',
    'mandate',
    'emi',
    'auto',
    'autopay',
    'charges',
    'charge',
    'fee',
    'fees',
    'dated',
    'date',
    'value',
  };

  bool isMeaningful(String s) =>
      s.length >= 3 &&
      !RegExp(r'^\d+$').hasMatch(s) &&
      !noiseTokens.contains(s);

  // ── STEP 1: Slash-separated segments with position-aware adjacency ────
  // Key fix: track ORIGINAL index so numerics/noise are skipped but
  // adjacency (index diff == 1) is still based on the original position.
  // pos/dr/45285454/store/mumbai → store(3), mumbai(4) → diff 1 → paired ✓
  // pos(0) + mumbai(4) → diff 4 → never paired ✗
  final slashWords = narration.split(RegExp(r'\s+'));

  for (final word in slashWords) {
    if (!word.contains('/')) continue;

    final rawSegments = word
        .split('/')
        .map((s) => s.trim().toLowerCase())
        .toList();

    // Build list of (originalIndex, segment) for meaningful segments only
    final indexed = <({int idx, String seg})>[];
    for (int i = 0; i < rawSegments.length; i++) {
      final s = rawSegments[i];
      if (s.isNotEmpty && isMeaningful(s)) {
        indexed.add((idx: i, seg: s));
      }
    }

    // Add individual meaningful segments
    for (final item in indexed) {
      result.add(item.seg);
    }

    // Add pairs — ONLY when original indices are adjacent (diff == 1)
    for (int i = 0; i < indexed.length - 1; i++) {
      final a = indexed[i];
      final b = indexed[i + 1];
      if (b.idx - a.idx == 1) {
        result.add('${a.seg}/${b.seg}');
      }
    }

    // Add triplets — ONLY when all three original indices are consecutive
    for (int i = 0; i < indexed.length - 2; i++) {
      final a = indexed[i];
      final b = indexed[i + 1];
      final c = indexed[i + 2];
      if (b.idx - a.idx == 1 && c.idx - b.idx == 1) {
        result.add('${a.seg}/${b.seg}/${c.seg}');
      }
    }
  }

  // ── STEP 2: Cross-segment name combinations ───────────────────────────
  // e.g. SARFARAJ/SBIN ... rathod safu → "sarfaraj/sbin/rathod safu"
  final slashGroupPattern = RegExp(
    r'([A-Za-z][A-Za-z0-9]*(?:/[A-Za-z][A-Za-z0-9]*)+)',
  );

  // ── STEP 2: Cross-segment name combinations ───────────────────────────
  for (final match in slashGroupPattern.allMatches(narration)) {
    // Skip if the slash group has no meaningful segment — e.g. "pos/cr", "upi/dr"
    final groupSegments = match
        .group(0)!
        .toLowerCase()
        .split('/')
        .where((s) => isMeaningful(s))
        .toList();

    if (groupSegments.isEmpty) continue; // ← nothing useful in the slash group

    final afterMatch = narration.substring(match.end).trim();

    final afterWords = afterMatch
        .split(RegExp(r'[\s/]+'))
        .map((w) => w.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase())
        .where((w) => w.length >= 3 && !noiseTokens.contains(w))
        .take(2)
        .toList();

    if (afterWords.isNotEmpty) {
      final slashGroup = match.group(0)!.toLowerCase();
      result.add('$slashGroup/${afterWords.join(' ')}');
      result.add(afterWords.join(' '));
    }
  }

  // ── STEP 3: Plain word extraction ────────────────────────────────────
  final cleaned = narration
      .replaceAll(RegExp(r'\b\d+\b'), ' ')
      .replaceAll(RegExp(r'@[A-Za-z0-9._]+'), ' ')
      .replaceAll(RegExp(r'[/\\|]'), ' ')
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .toLowerCase();

  final words = cleaned
      .split(RegExp(r'\s+'))
      .map((w) => w.trim())
      .where((w) => w.length >= 3 && isMeaningful(w))
      .toList();

  for (final w in words) {
    result.add(w);
  }

  for (int i = 0; i < words.length - 1; i++) {
    result.add('${words[i]} ${words[i + 1]}');
  }

  // ── STEP 4: Filter and rank ───────────────────────────────────────────
  final filtered = result
      .where((kw) => kw.length >= 3 && !noiseTokens.contains(kw))
      .where((kw) {
        final parts = kw.split(RegExp(r'[/\s]'));
        return parts.any((p) => p.length >= 3 && !noiseTokens.contains(p));
      })
      .toList();

  filtered.sort((a, b) => _kwScore(b).compareTo(_kwScore(a)));

  return filtered.toSet().toList().take(12).toList();
}

int _kwScore(String kw) {
  int score = 0;
  if (kw.contains('/')) score += 3;
  if (kw.contains(' ')) score += 2;
  score += kw.length ~/ 4;
  return score;
}

class ReviewTransactionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReviewTransactionsController>(
      () => ReviewTransactionsController(),
      fenix: true,
    );
  }
}

class ReviewTransactionsScreen extends GetView<ReviewTransactionsController> {
  ReviewTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldExit = await DialogService.showWarningDialog(
          title: "Exit Mapping",
          description: "Are you sure you want to exit?",
          onConfirm: () {
            Get.back(result: true); // close dialog with TRUE
          },
        );

        if (shouldExit == true) {
          Get.back(); //  ACTUAL SCREEN POP
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,

          title: Obx(
            () => Column(
              children: [
                const Text(
                  'Map Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${controller.mappedCount} of ${controller.totalCount} mapped',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          centerTitle: true,
          actions: [
            Obx(
              () => IconButton(
                onPressed: controller.toggleFilter,
                icon: Icon(controller.filterIcon),
                tooltip: controller.filterLabel,
              ),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.mappableTransactions.isEmpty) {
            return _buildEmptyState(context);
          }
          return Column(
            children: [
              _buildProgressBar(context),
              _buildStatusRow(context),
              Expanded(
                child: Obx(
                  () => ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: controller.filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final txn = controller.filteredTransactions[index];
                      return _TransactionRow(
                        transaction: txn,
                        controller: controller,
                      );
                    },
                  ),
                ),
              ),
              _buildBottomBar(context),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No more transactions to review.',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              Get.back(result: true);
              Get.back();
            },
            icon: const Icon(Icons.home),
            label: const Text('Go Home'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Obx(
      () => Column(
        children: [
          LinearProgressIndicator(
            value: controller.progressRatio,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            minHeight: 4,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Auto-matched count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${controller.autoMatchedCount} auto-matched',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('✅', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Need review count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${controller.needReviewCount} need review',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber[800],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('⚠️', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatChip(
                    context,
                    icon: Icons.check_circle_outline,
                    label: '${controller.mappedCount} Mapped',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildStatChip(
                    context,
                    icon: Icons.error_outline,
                    label: '${controller.unmappedCount} Unmapped',
                    color: controller.unmappedCount > 0
                        ? colorScheme.error
                        : Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => FilledButton(
                onPressed: controller.canSaveAll && !controller.isSaving.value
                    ? () async {
                        Get.closeAllSnackbars();
                        final confirm = await DialogService.showWarningDialog(
                          title: "Save Transactions",
                          description:
                              "Are you sure you want to save and continue? You won't be able to modify these mappings later.",
                          onConfirm: () {
                            Get.back(result: true);
                          },
                        );

                        if (confirm == true) {
                          controller.saveTransactions();
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: controller.canSaveAll
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                ),
                child: controller.isSaving.value
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Saving...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Save & Continue'),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: controller.canSaveAll
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Transaction Row Widget
class _TransactionRow extends StatelessWidget {
  final MappableTransaction transaction;
  final ReviewTransactionsController controller;

  const _TransactionRow({required this.transaction, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAutoMatched = transaction.isAutoMatched;

    // Determine border color: green for auto-matched, amber for unmatched
    final borderColor = isAutoMatched
        ? Colors.green.withValues(alpha: 0.6)
        : Colors.amber.withValues(alpha: 0.6);

    return Opacity(
      opacity: isAutoMatched ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: borderColor, width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Date + Amount + Type Badge
              Row(
                children: [
                  Text(
                    _formatDate(transaction.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${transaction.isDebit ? "-" : "+"}₹${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: transaction.isDebit
                          ? colorScheme.error
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTypeBadge(context),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: Clean Name (bold)
              Text(
                transaction.cleanName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Row 3: Narration (Subtitle)
              Text(
                transaction.narration,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Row 3: Account Dropdown
              _AccountDropdownWidget(
                transaction: transaction,
                controller: controller,
                isAutoMatched: isAutoMatched,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDebit = transaction.isDebit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDebit
            ? colorScheme.error.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isDebit ? 'Dr' : 'Cr',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDebit ? colorScheme.error : Colors.green,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final s = dateStr.trim();
      DateTime? dt;

      // ISO: yyyy-MM-dd
      final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
      if (isoMatch != null) {
        dt = DateTime(
          int.parse(isoMatch.group(1)!),
          int.parse(isoMatch.group(2)!),
          int.parse(isoMatch.group(3)!),
        );
      }

      // dd/mm/yyyy or dd-mm-yyyy
      if (dt == null) {
        final slashMatch = RegExp(
          r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$',
        ).firstMatch(s);
        if (slashMatch != null) {
          dt = DateTime(
            int.parse(slashMatch.group(3)!),
            int.parse(slashMatch.group(2)!),
            int.parse(slashMatch.group(1)!),
          );
        }
      }

      // dd MMM yyyy
      if (dt == null) {
        final mnameMatch = RegExp(
          r'^(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})$',
          caseSensitive: false,
        ).firstMatch(s);
        if (mnameMatch != null) {
          dt = DateTime.tryParse(
            '${mnameMatch.group(3)!}-'
            '${_mn(mnameMatch.group(2)!)}-'
            '${mnameMatch.group(1)!.padLeft(2, '0')}',
          );
        }
      }

      if (dt != null) return DateFormat('dd MMM').format(dt);
      return dateStr; // fallback: show raw string
    } catch (_) {
      return dateStr;
    }
  }

  String _mn(String abbr) {
    const m = {
      'jan': '01',
      'feb': '02',
      'mar': '03',
      'apr': '04',
      'may': '05',
      'jun': '06',
      'jul': '07',
      'aug': '08',
      'sep': '09',
      'oct': '10',
      'nov': '11',
      'dec': '12',
    };
    return m[abbr.toLowerCase()] ?? '01';
  }
}

/// Custom Account Dropdown Widget
class _AccountDropdownWidget extends StatelessWidget {
  final MappableTransaction transaction;
  final ReviewTransactionsController controller;
  final bool isAutoMatched;

  const _AccountDropdownWidget({
    required this.transaction,
    required this.controller,
    required this.isAutoMatched,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMapped = transaction.isMapped;
    final displayText = transaction.tagName ?? 'Tag Transaction';

    return GestureDetector(
      onTap: () => _showAccountSelectionSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMapped
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.amber.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Show checkmark with ✅ for auto-matched
            if (isAutoMatched) ...[
              const Text('✅', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ] else
              Icon(
                isMapped
                    ? Icons.check_circle
                    : Icons.account_balance_wallet_outlined,
                size: 18,
                color: isMapped ? Colors.green : Colors.amber,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 14,
                  color: isMapped ? colorScheme.onSurface : Colors.amber[700],
                  fontWeight: isMapped ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountSelectionSheet(BuildContext context) {
    Get.closeAllSnackbars();
    Get.bottomSheet(
      _AccountSelectionSheet(transaction: transaction, controller: controller),
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
    );
  }
}

class _AccountSelectionSheet extends StatelessWidget {
  final MappableTransaction transaction;
  final ReviewTransactionsController controller;

  const _AccountSelectionSheet({
    required this.transaction,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),

            const Text(
              "Tag Transaction",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                transaction.narration,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                itemCount: controller.tags.length + 1,
                itemBuilder: (context, index) {
                  /// ✅ FIRST ITEM → CREATE NEW TAG
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.add, color: Colors.blue),
                      title: const Text(
                        "Create New Tag",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Get.back();

                        _openCreateTagSheet(context);
                      },
                    );
                  }

                  /// ✅ EXISTING TAGS
                  final tag = controller.tags[index - 1];

                  final keywordsStr = tag.tagKeywords
                      .map((kw) => kw["name"].toString())
                      .where((s) => s.isNotEmpty)
                      .join(', ');

                  return ListTile(
                    title: Text(tag.tagName),
                    subtitle: Text(keywordsStr),
                    onTap: () {
                      controller.assignTag(txn: transaction, tag: tag);
                      Get.back();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateTagSheet(BuildContext context) {
    final keywords = _buildKeywordPreview(transaction);
    Get.find<TagsController>().clearCreateTagState();

    Get.toNamed(
      AppRoutes.tagAddEdit, // your route name
      arguments: {
        'narration': transaction.narration,
        'prefilledName': transaction.cleanName,
        'keywords': keywords,
      },
    )?.then((result) {
      if (result != null && result is Map) {
        // After tag is created, reload tags in ReviewTransactionsController
        controller.loadTagsThenAutoMatch();
      }
    });
  }
}
