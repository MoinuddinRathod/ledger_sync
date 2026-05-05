import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/service/dialog_service.dart';
import '../../transactions/models/bank_transaction_model.dart';
import '../controllers/tags_controller.dart';
import '../models/tag_model.dart';

/// Shows all transactions that are assigned to a specific [TagModel].
/// Receives the [TagModel] via [Get.arguments] and reads transactions
/// from [TagsController.tagTransactions] (pre-fetched before navigation).
class TagTransactionsScreen extends GetWidget<TagsController> {
  TagTransactionsScreen({super.key});

  final _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Safely resolve the tag passed as argument
    final tag = Get.arguments is TagModel ? Get.arguments as TagModel : null;
    final tagName = tag?.tagName ?? 'Tag Transactions';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              tagName,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Obx(() {
              final count = controller.tagTransactions.length;
              return Text(
                '$count transaction${count == 1 ? '' : 's'}',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              );
            }),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colorScheme.onSurface),
            tooltip: 'Refresh',
            onPressed: () {
              if (tag?.tagId != null) {
                controller.fetchTransactionsForTag(tag!.tagId!);
              }
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoadingTagTxns.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (tag == null) {
          return _buildErrorState(
            colorScheme,
            'Invalid Tag',
            'The tag data could not be loaded. Please go back and try again.',
          );
        }

        if (controller.tagTransactions.isEmpty) {
          return _buildEmptyState(colorScheme, tagName);
        }

        return _buildTransactionsList(colorScheme, tag);
      }),
    );
  }

  // ─────────────────────────────────────────────
  // Transaction list
  // ─────────────────────────────────────────────

  Widget _buildTransactionsList(ColorScheme colorScheme, TagModel tag) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: controller.tagTransactions.length,
      itemBuilder: (_, index) {
        final txn = controller.tagTransactions[index];
        return _buildTransactionTile(
          txn: txn,
          colorScheme: colorScheme,
          dismissKey: ValueKey('tag_txn_${txn.txnId}'),
          onDelete: () {
            // Remove locally and refresh counts
            controller.tagTransactions
                .removeWhere((t) => t.txnId == txn.txnId);
            // Also refresh tag count badge
            controller.fetchTagTransactionCounts();
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Transaction tile
  // ─────────────────────────────────────────────

  Widget _buildTransactionTile({
    required BankTransactionModel txn,
    required ColorScheme colorScheme,
    required Key dismissKey,
    required VoidCallback onDelete,
  }) {
    final isCredit = txn.isCredit;
    final amountColor =
        isCredit ? Colors.green.shade600 : Colors.red.shade600;
    final amountPrefix = isCredit ? '+ ' : '– ';
    final iconBgColor = isCredit
        ? Colors.green.withValues(alpha: 0.12)
        : Colors.red.withValues(alpha: 0.10);
    final iconColor =
        isCredit ? Colors.green.shade600 : Colors.red.shade600;
    final formattedAmount = _inrFormatter.format(txn.txnAmount);
    final formattedDate = _formatDate(txn.txnDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: dismissKey,
        direction: DismissDirection.endToStart, // swipe left = delete
        confirmDismiss: (_) async {
          return await DialogService.showDeleteDialog(
            onConfirm: () => Get.back(result: true),
          );
        },
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 26),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCredit
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Narration + bank info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.txnNarration,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 11,
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            txn.maskedAccountLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Amount
              Text(
                '$amountPrefix$formattedAmount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────

  Widget _buildEmptyState(ColorScheme colorScheme, String tagName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.label_off_outlined,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Transactions for "$tagName"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transactions tagged with "{tagName}"\nwill appear here.'.replaceAll('{tagName}', tagName),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Error state
  // ─────────────────────────────────────────────

  Widget _buildErrorState(
      ColorScheme colorScheme, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56,
                color: colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Get.back(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
    } catch (_) {}
    try {
      return DateFormat('dd MMM yyyy')
          .format(DateFormat('dd/MM/yyyy').parse(raw));
    } catch (_) {}
    return raw;
  }
}
