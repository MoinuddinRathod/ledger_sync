import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/service/snackbar_service.dart';
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colorScheme.onSurface,
          ),
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

        return _buildTransactionsList(context, colorScheme, tag);
      }),
    );
  }

  // ─────────────────────────────────────────────
  // Transaction list
  // ─────────────────────────────────────────────

  Widget _buildTransactionsList(
    BuildContext context,
    ColorScheme colorScheme,
    TagModel tag,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: controller.tagTransactions.length,
      itemBuilder: (_, index) {
        final txn = controller.tagTransactions[index];
        return _buildTransactionTile(
          context: context,
          txn: txn,
          colorScheme: colorScheme,
          dismissKey: ValueKey('tag_txn_${txn.txnId}'),
          onDelete: () {
            // Guard: imported transactions cannot be deleted
            if (controller.isImportedTransaction(txn)) {
              SnackbarService.showWarning(
                title: 'Cannot Delete',
                message:
                    'Imported transactions cannot be deleted. You can change the tag instead.',
              );
              return;
            }
            // Remove locally and refresh counts
            controller.tagTransactions.removeWhere((t) => t.txnId == txn.txnId);
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
    required BuildContext context,
    required BankTransactionModel txn,
    required ColorScheme colorScheme,
    required Key dismissKey,
    required VoidCallback onDelete,
  }) {
    final isCredit = txn.isCredit;
    final amountColor = isCredit
        ? const Color(0xFF00C853)
        : const Color(0xFFFF3D00);
    final isImported = controller.isImportedTransaction(txn);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: dismissKey,
        direction: isImported
            ? DismissDirection.none
            : DismissDirection.endToStart,
        background: _buildDismissibleBackground(),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24), // Softer, rounder corners
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: () => _showChangeTagSheet(context, txn),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Modern Glassmorphic Icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isCredit
                                  ? [
                                      Colors.green.withValues(alpha: 0.2),
                                      Colors.green.withValues(alpha: 0.05),
                                    ]
                                  : [
                                      Colors.red.withValues(alpha: 0.2),
                                      Colors.red.withValues(alpha: 0.05),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            isCredit
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: amountColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Narration & Meta
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.txnNarration,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(txn.txnDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _inrFormatter.format(txn.txnAmount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: amountColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (isImported)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Imported',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Action Footer
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 14,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                txn.maskedAccountLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.label_rounded,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Change Tag',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissibleBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 32),
      margin: const EdgeInsets.only(
        bottom: 16,
      ), // Match your card's bottom margin
      decoration: BoxDecoration(
        // A vibrant coral-to-red gradient looks more modern than flat red
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Change Tag bottom sheet trigger
  // ─────────────────────────────────────────────

  void _showChangeTagSheet(
    BuildContext context,
    BankTransactionModel transaction,
  ) {
    Get.bottomSheet(
      _ChangeTagSheet(transaction: transaction, controller: controller),
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
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
            'Transactions tagged with "{tagName}"\nwill appear here.'
                .replaceAll('{tagName}', tagName),
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
    ColorScheme colorScheme,
    String title,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
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
      return DateFormat(
        'dd MMM yyyy',
      ).format(DateFormat('dd/MM/yyyy').parse(raw));
    } catch (_) {}
    return raw;
  }
}

// ═══════════════════════════════════════════════════════════
// _ChangeTagSheet — private bottom sheet for tag selection
// ═══════════════════════════════════════════════════════════

class _ChangeTagSheet extends StatelessWidget {
  final BankTransactionModel transaction;

  final TagsController controller;

  const _ChangeTagSheet({required this.transaction, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,

        decoration: BoxDecoration(
          color: colorScheme.surface,

          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),

        child: Column(
          children: [
            // ── Handle bar ──────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12),

              width: 40,

              height: 4,

              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),

                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            // ── Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Change Tag',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,

                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    transaction.txnNarration,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 12,

                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tag list ────────────────────────────────────────────
            Expanded(
              child: Obx(() {
                if (controller.isLoadingFetch.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.tags.isEmpty) {
                  return Center(
                    child: Text(
                      'No tags available',

                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),

                  itemCount: controller.tags.length,

                  itemBuilder: (context, index) {
                    final tag = controller.tags[index];

                    final isCurrent = tag.tagId == transaction.txnTagId;

                    return ListTile(
                      leading: Container(
                        width: 36,

                        height: 36,

                        decoration: BoxDecoration(
                          color: isCurrent
                              ? colorScheme.primary.withValues(alpha: 0.15)
                              : colorScheme.surfaceContainerHighest,

                          shape: BoxShape.circle,
                        ),

                        child: Icon(
                          isCurrent ? Icons.check_circle : Icons.label_outline,

                          size: 18,

                          color: isCurrent
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),

                      title: Text(
                        tag.tagName,

                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,

                          color: isCurrent
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),

                      subtitle: tag.tagKeywords.isNotEmpty
                          ? Text(
                              tag.tagKeywords
                                  .take(3)
                                  .map((k) => k['name'].toString())
                                  .join(', '),

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: TextStyle(
                                fontSize: 11,

                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            )
                          : null,

                      trailing: isCurrent
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,

                                vertical: 4,
                              ),

                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),

                                borderRadius: BorderRadius.circular(8),
                              ),

                              child: Text(
                                'Current',

                                style: TextStyle(
                                  fontSize: 11,

                                  color: colorScheme.primary,

                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,

                      onTap: isCurrent
                          ? null // tapping current tag does nothing
                          : () {
                              // Close sheet first, then perform async work

                              Get.back();

                              controller.changeTransactionTag(
                                transaction: transaction,

                                newTag: tag,
                              );
                            },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
