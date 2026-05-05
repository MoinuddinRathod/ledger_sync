import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/service/dialog_service.dart';
import '../../bank_account/models/bank_account_model.dart';
import '../controller/cash_wallet_controller.dart';
import 'package:intl/intl.dart';

import '../models/cash_wallet_transaction_model.dart';
import '../../tags/widgets/tag_selection_sheet.dart';
import '../../tags/controllers/tags_controller.dart';

class CashWalletScreen extends GetWidget<CashWalletController> {
  CashWalletScreen({super.key});
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Matched with HomeScreen surface colors
    final bgColor = theme.colorScheme.surface;
    final surfaceColor = isDark ? const Color(0xFF1A1C35) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A2D52)
        : const Color(0xFFE4E6FF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        centerTitle: true,
        title: Obx(() {
          if (controller.isSearching.value) {
            return TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                suffixIcon: controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: colorScheme.onSurface),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {},
            );
          } else {
            return Text(
              "Cash Wallet",
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            );
          }
        }),

        /////////////////////////////////////////////////////////////////////////////
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.cashWallet.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildBalanceSection(theme),
              const SizedBox(height: 32),
              _buildTransactionsSection(
                theme,
                context,
                isDark,
                surfaceColor,
                borderColor,
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      }),

      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () async {
          controller.resetForm();
          await controller.fetchData();
          _showAddEntryBottomSheet(
            context,
            theme,
            isDark,
            surfaceColor,
            borderColor,
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBalanceSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    // 1. Get the raw balance
    double balance = controller.cashWallet.value?.currentBalance ?? 0.0;

    // 2. Format the full number to exactly 2 decimal places as a string
    // This handles the "110.0999..." precision issue automatically
    String formattedString = balance.toStringAsFixed(2); // "110.10"

    // 3. Split the string by the decimal point
    List<String> parts = formattedString.split('.');

    // 4. Format the integer part with Indian grouping (en_IN)
    final integerPart = NumberFormat(
      '#,##0',
      'en_IN',
    ).format(double.parse(parts[0]));

    // 5. Get the decimal part (it will be "10")
    final decimalPart = parts[1];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF4A4E9E), const Color(0xFF2A2D52)]
                : [theme.colorScheme.primary, theme.colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Cash Balance",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ],
                ),
                Icon(
                  Icons.pie_chart_outline_rounded,
                  color: theme.colorScheme.onPrimary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹ $integerPart",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimary,
                    letterSpacing: -1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, left: 4),
                  child: Text(
                    ".${decimalPart.toString().padLeft(2, '0')}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection(
    ThemeData theme,
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    if (controller.transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            "No transactions found",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    // Group transactions by date
    Map<String, List<Widget>> groupedTransactions = {};

    for (var tx in controller.transactions) {
      DateTime dt = DateTime.parse(tx.dateAdded);
      String dateKey = DateFormat('yyyy-MM-dd').format(dt);

      // Determine time
      String time = DateFormat('h:mm a').format(dt);

      // Format amount
      String prefix =
          tx.transactionType == 'Income' ||
              tx.transactionType == 'Cash Withdrawn From Bank'
          ? "+"
          : "-";
      String formattedAmount =
          "$prefix₹ ${NumberFormat('#,##0.00', 'en_IN').format(tx.amount)}";

      IconData iconData = Icons.receipt_long;
      Color iconColor = Colors.grey;

      if (tx.transactionType == 'Cash Withdrawn From Bank') {
        iconData = Icons.atm_rounded;
        iconColor = Colors.teal;
      } else if (tx.transactionType == 'Cash Deposited To Bank') {
        iconData = Icons.account_balance_rounded;
        iconColor = Colors.indigo;
      } else if (tx.transactionType == 'Expense') {
        iconData = Icons.shopping_bag_rounded;
        iconColor = Colors.redAccent;
      } else if (tx.transactionType == 'Income') {
        iconData = Icons.arrow_downward_rounded;
        iconColor = Colors.green;
      }

      Widget item = _buildTransactionItem(
        theme: theme,
        title: tx.transactionType,
        transaction: tx,
        onEdit: () async {
          // 1. Pre-fill the controllers

          controller.amountController.text = tx.amount.abs().toString();
          controller.noteController.text = tx.transactionNote ?? "";
          controller.selectedTransactionType.value = tx.transactionType;
          controller.selectedDate.value =
              DateTime.tryParse(tx.dateAdded) ?? DateTime.now();

          // 2. Set the account if it exists
          if (tx.bankAccountId != null) {
            controller.selectedBankAccount.value = controller.bankAccounts
                .firstWhereOrNull(
                  (bank) => bank.encryptedAccountNumber == tx.bankAccountId,
                );
          }

          // 3. Set the Tag if it exists
          final tagsController = Get.find<TagsController>();

          // Wait for any in-progress fetch to complete first
          if (tagsController.isLoadingFetch.value) {
            // Poll until loading is done — max 3 seconds
            int waited = 0;
            while (tagsController.isLoadingFetch.value && waited < 3000) {
              await Future.delayed(const Duration(milliseconds: 50));
              waited += 50;
            }
          }

          // If still empty after waiting, force a fresh fetch
          if (tagsController.tags.isEmpty) {
            await tagsController.fetchTags();
          }

          controller.selectedTag.value = tagsController.tags.firstWhereOrNull(
            (tag) => tag.tagId == tx.tagId,
          );

          // 4. Open the bottom sheet
          _showAddEntryBottomSheet(
            context,
            theme,
            isDark,
            surfaceColor,
            borderColor,
            isEditing: true,
            transaction: tx,
          );
        },
        time: time,
        amount: formattedAmount,
        icon: iconData,
        iconColor: iconColor,
        bankRef: tx.resolvedTagName ?? tx.transactionNote ?? '',
        // Passing unique key to Identify which item to dismiss
        dismissKey: ObjectKey(tx),
        isManual: tx.isManual,
      );

      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(item);
    }

    List<Widget> children = [];

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 1)));

    groupedTransactions.forEach((dateKey, widgets) {
      String displayDate = dateKey;
      if (dateKey == today) {
        displayDate = "Today";
      } else if (dateKey == yesterday) {
        displayDate = "Yesterday";
      } else {
        displayDate = DateFormat('MMM d, yyyy').format(DateTime.parse(dateKey));
      }

      children.add(_buildDateHeader(theme, displayDate));
      children.addAll(widgets);
      children.add(const SizedBox(height: 16));
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDateHeader(ThemeData theme, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        date,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required ThemeData theme,
    required String title,
    required String time,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onEdit,
    required CashWalletTransactionModel transaction,
    String? bankRef,
    required Key dismissKey,
    required bool isManual,
  }) {
    final isPositive = amount.startsWith('+');
    final amountColor = isPositive ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: dismissKey,
        direction: isManual
            ? DismissDirection.horizontal
            : DismissDirection.none,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onEdit();
            return false;
          } else {
            final result = await DialogService.showDeleteDialog(
              onConfirm: () async {
                await controller.deleteTransaction(transaction);
              },
            );
            return result ?? false;
          }
        },

        // Edit Background (Swipe Right)
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24.0),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.edit_outlined, color: Colors.white, size: 28),
        ),
        // Delete Background (Swipe Left)
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24.0),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          color: Colors
              .transparent, // Ensures swiping feels attached to background surface
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    if (bankRef != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        bankRef,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
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

  void _showAddEntryBottomSheet(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color surfaceColor,
    Color borderColor, {
    bool isEditing = false,
    CashWalletTransactionModel? transaction,
  }) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          border: Border(top: BorderSide(color: borderColor, width: 1.5)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: controller.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    isEditing ? 'Edit Transaction' : "New Cash Entry",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildInputLabel(theme, 'Transaction Date'),
                _buildDateField(theme, isDark),
                const SizedBox(height: 24),

                _buildInputLabel(theme, "Transaction Type"),
                Obx(
                  () => DropdownButtonFormField<String>(
                    dropdownColor: isDark
                        ? const Color(0xFF1E213A)
                        : Colors.white,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    decoration: _buildDropdownDecoration(
                      theme,
                      isDark,
                      Icons.category_outlined,
                    ),

                    initialValue: controller.selectedTransactionType.value,
                    items: controller.transactionTypes.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: controller.onChangeTransactionType,
                    validator: (value) =>
                        value == null ? 'Please select type' : null,
                  ),
                ),
                const SizedBox(height: 16),

                Obx(() {
                  if (controller.selectedTransactionType.value ==
                          'Cash Withdrawn From Bank' ||
                      controller.selectedTransactionType.value ==
                          'Cash Deposited To Bank') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInputLabel(theme, 'Select Bank Account'),
                          DropdownButtonFormField<BankAccountModel>(
                            isExpanded: true,
                            dropdownColor: isDark
                                ? const Color(0xFF1E213A)
                                : Colors.white,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 16,
                            ),
                            decoration: _buildDropdownDecoration(
                              theme,
                              isDark,
                              Icons.account_balance,
                            ),
                            initialValue: controller.selectedBankAccount.value,
                            items: controller.bankAccounts.map((
                              BankAccountModel bank,
                            ) {
                              return DropdownMenuItem<BankAccountModel>(
                                value: bank,
                                child: Text(
                                  "${bank.bankName} (********${bank.lastFourDigits})",
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              controller.selectedBankAccount.value = value;
                            },
                            validator: (value) => value == null
                                ? 'Please select bank account'
                                : null,
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                _buildInputLabel(theme, "Select Tag"),
                Obx(
                  () => InkWell(
                    onTap: () {
                      TagSelectionSheet.show(
                        context,
                        title: "Select Cash Wallet Tag",
                        onTagSelected: (tag) {
                          controller.selectedTag.value = tag;
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E213A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2D52)
                              : const Color(0xFFE4E6FF),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.label_outline,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              controller.selectedTag.value != null
                                  ? controller.selectedTag.value!.tagName
                                  : "Select a tag",
                              style: TextStyle(
                                fontSize: 16,
                                color: controller.selectedTag.value != null
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildInputLabel(theme, 'Amount'),
                _buildTextField(
                  controller: controller.amountController,
                  theme: theme,
                  isDark: isDark,
                  hintText: '0.00',
                  icon: Icons.currency_rupee,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter amount';
                    if (double.tryParse(value) == null)
                      return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildInputLabel(theme, "Note"),
                _buildTextField(
                  controller: controller.noteController,
                  theme: theme,
                  isDark: isDark,
                  hintText: "Enter a note (optional)",
                  icon: Icons.note_alt_outlined,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      // Confirmation dialog
                      await DialogService.showWarningDialog(
                        title: "Confirm Transaction",
                        description:
                            "Are you sure you want to save this transaction?",
                        onConfirm: () {
                          if (isEditing) {
                            controller.updateTransaction(transaction!);
                          } else {
                            controller.saveTransaction();
                          }
                        },
                      );
                    },
                    child: Text(
                      isEditing ? "Update Transaction" : 'Save Transaction',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // --- Reusable Design Widgets from AddEditBankAccountScreen ---

  Widget _buildInputLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  InputDecoration _buildDropdownDecoration(
    ThemeData theme,
    bool isDark,
    IconData icon,
  ) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1C35) : const Color(0xFFF5F7FA),
      prefixIcon: Icon(
        icon,
        color: theme.colorScheme.primary.withValues(alpha: 0.7),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A2D52) : Colors.transparent,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required ThemeData theme,
    required bool isDark,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        prefixIcon: Icon(
          icon,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1C35) : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A2D52) : Colors.transparent,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
      ),
    );
  }

  Widget _buildDateField(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: Get.context!,
          initialDate: controller.selectedDate.value,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          controller.selectedDate.value = picked;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1C35) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2D52) : const Color(0xFFE4E6FF),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() {
                final date = controller.selectedDate.value;
                return Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                );
              }),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
