import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/service/dialog_service.dart';
import '../../../routes/app_routes.dart';
import '../../navbar/widgets/navbar_scroll_listener.dart';
import '../controller/all_transaction_controller.dart';
import '../models/bank_transaction_model.dart';

class AllTransactionsScreen extends GetWidget<AllTransactionsController> {
  AllTransactionsScreen({super.key});

  final TextEditingController _searchController = TextEditingController();
  final _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(colorScheme),
      body: Column(
        children: [
          _buildSummaryCard(colorScheme),
          _buildFilters(colorScheme),
          _buildSortingRow(colorScheme),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.transactions.isEmpty) {
                return _buildEmptyState(colorScheme);
              }
              return _buildTransactionsList(colorScheme);
            }),
          ),
        ],
      ),
      floatingActionButton: _buildFab(context, colorScheme),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ─────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme) {
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,

      title: Obx(() {
        if (controller.isSearching.value) {
          return TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search by narration or tag...',
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              suffixIcon: controller.searchQuery.value.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colorScheme.onSurface),
                      onPressed: () {
                        _searchController.clear();
                        controller.clearSearch();
                      },
                    )
                  : null,
            ),
            onChanged: controller.onSearchChanged,
          );
        }
        return Text(
          'Transactions',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        );
      }),
      centerTitle: true,
      actions: [
        Obx(() {
          if (controller.isSearching.value) {
            return TextButton(
              onPressed: () {
                _searchController.clear();
                controller.toggleSearch();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.primary),
              ),
            );
          }
          return Row(
            children: [
              // Date range chip / icon
              if (controller.selectedDateRange.value.isNotEmpty)
                GestureDetector(
                  onTap: () => controller.pickDateRange(Get.context!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          controller.selectedDateRange.value,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: controller.clearDateRange,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.calendar_today_outlined,
                    color: colorScheme.onSurface,
                  ),
                  onPressed: () => controller.pickDateRange(Get.context!),
                ),
              IconButton(
                icon: Icon(Icons.search, color: colorScheme.onSurface),
                onPressed: controller.toggleSearch,
              ),
            ],
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Summary card (CR vs DR totals)
  // ─────────────────────────────────────────────

  Widget _buildSummaryCard(ColorScheme colorScheme) {
    return Obx(() {
      final credit = controller.totalCredit;
      final debit = controller.totalDebit;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem(
              label: 'Total Credit',
              amount: credit,
              icon: Icons.arrow_downward_rounded,
              color: Colors.greenAccent.shade200,
            ),
            Container(width: 1, height: 40, color: Colors.white24),
            _summaryItem(
              label: 'Total Debit',
              amount: debit,
              icon: Icons.arrow_upward_rounded,
              color: Colors.redAccent.shade100,
            ),
          ],
        ),
      );
    });
  }

  Widget _summaryItem({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _inrFormatter.format(amount),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Filters row
  // ─────────────────────────────────────────────

  Widget _buildFilters(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: controller.filters.length,
        itemBuilder: (_, index) {
          final filter = controller.filters[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Obx(
              () => FilterChip(
                label: Text(filter),
                selected: controller.selectedFilter.value == filter,
                onSelected: (_) => controller.setFilter(filter),
                backgroundColor: colorScheme.secondaryContainer.withValues(
                  alpha: 0.3,
                ),
                selectedColor: colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: controller.selectedFilter.value == filter
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: controller.selectedFilter.value == filter
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: controller.selectedFilter.value == filter
                        ? Colors.transparent
                        : colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                showCheckmark: false,
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Sorting row
  // ─────────────────────────────────────────────

  Widget _buildSortingRow(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => Text(
              '${controller.transactions.length} transaction'
              '${controller.transactions.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                'Sort: ',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Obx(
                () => PopupMenuButton<String>(
                  initialValue: controller.selectedSort.value,
                  onSelected: controller.setSort,
                  itemBuilder: (_) => controller.sortOptions
                      .map(
                        (s) => PopupMenuItem<String>(
                          value: s,
                          child: Text(
                            s,
                            style: TextStyle(
                              color: controller.selectedSort.value == s
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontWeight: controller.selectedSort.value == s
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  child: Row(
                    children: [
                      Text(
                        controller.selectedSort.value,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Transactions Found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import a bank statement to see transactions here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: controller.fetchAllTransactions,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Transactions list
  // ─────────────────────────────────────────────

  Widget _buildTransactionsList(ColorScheme colorScheme) {
    final txns = controller.transactions;
    return NavbarScrollListener(
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 100,
          top: 4,
        ),
        itemCount: txns.length,
        itemBuilder: (_, index) {
          final txn = txns[index];
          return _buildTransactionTile(
            txn: txn,
            colorScheme: colorScheme,
            dismissKey: ValueKey(txn.txnId),
            onDelete: () => controller.deleteTransaction(txn),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Transaction tile
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // Transaction tile (Updated Design)
  // ─────────────────────────────────────────────

  Widget _buildTransactionTile({
    required BankTransactionModel txn,
    required ColorScheme colorScheme,
    required Key dismissKey,
    required VoidCallback onDelete,
  }) {
    // ── Internal Transfer tile ─────────────────────────────────────────────
    if (txn.isInternalTransfer) {
      return _buildTransferTile(txn: txn, colorScheme: colorScheme);
    }

    // ── Regular Credit / Debit tile ────────────────────────────────────────
    final isDark = colorScheme.brightness == Brightness.dark;
    final isCredit = txn.isCredit;
    final color = isCredit ? Colors.green : colorScheme.error;
    final icon = isCredit
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    final amountPrefix = isCredit ? '+ ' : '- ';
    final formattedAmount = _inrFormatter.format(txn.txnAmount);
    final formattedDate = controller.formatDisplayDate(txn.txnDate);

    final tileContent = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C35) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D52) : const Color(0xFFE4E6FF),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Circular Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),

          // Title (Narration) + Tag Chip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.txnNarration,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Tag chip
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          txn.resolvedTagName,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Amount & Account info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix$formattedAmount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                txn.maskedAccountLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  overflow: TextOverflow.ellipsis,
                ),
                overflow: TextOverflow.clip,
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: txn.isManual
          ? Dismissible(
              key: dismissKey,
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.endToStart) {
                  return await DialogService.showDeleteDialog(
                    onConfirm: () => Get.back(result: true),
                  );
                } else {
                  Get.toNamed(AppRoutes.transactionAddEdit, arguments: txn);
                  return false;
                }
              },
              onDismissed: (direction) {
                if (direction == DismissDirection.endToStart) {
                  onDelete();
                }
              },
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 24),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              child: tileContent,
            )
          : tileContent,
    );
  }

  /// Distinct tile style for internal transfers (Cash↔Bank, Bank↔Bank).
  /// Uses a neutral swap icon and amber/blue color — NOT red or green —
  /// to communicate that net worth is unchanged.
  Widget _buildTransferTile({
    required BankTransactionModel txn,
    required ColorScheme colorScheme,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    const transferColor = Color(0xFF7C83FD); // soft indigo
    final formattedAmount = _inrFormatter.format(txn.txnAmount);
    final formattedDate = controller.formatDisplayDate(txn.txnDate);
    final label = txn.transferLabel ?? 'Internal Transfer';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1C35) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? transferColor.withValues(alpha: 0.25)
                : transferColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Swap icon with soft indigo background
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: transferColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: transferColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Transfer label + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: transferColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Transfer',
                          style: TextStyle(
                            fontSize: 10,
                            color: transferColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount (neutral color, no +/- prefix)
            Text(
              formattedAmount,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: transferColor,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFab(BuildContext context, ColorScheme colorScheme) {
    return FloatingActionButton.extended(
      onPressed: () {
        Get.toNamed(AppRoutes.transactionAddEdit);
      },
      heroTag: 'add_transaction_fab',
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      icon: const Icon(Icons.add_rounded, size: 22),
      label: const Text(
        'Add',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
          fontSize: 14,
        ),
      ),
    );
  }
}
