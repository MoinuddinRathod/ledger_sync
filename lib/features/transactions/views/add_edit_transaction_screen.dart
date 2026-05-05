import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../tags/widgets/tag_selection_sheet.dart';
import '../controller/add_edit_transaction_controller.dart';
import '../../bank_account/models/bank_account_model.dart';

class AddEditTransactionScreen extends GetWidget<AddEditTransactionController> {
  const AddEditTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEditing = controller.editingTxn != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Date Picker (Moved to Top) ──
              _buildDateField(colorScheme),
              const SizedBox(height: 24),

              // ── Mode Switch: Bank vs Cash ──
              _buildSegmentedControl(colorScheme),
              const SizedBox(height: 24),

              // ── Type Switch: IN (CR) vs OUT (DR) ──
              _buildTypeSwitch(colorScheme),
              const SizedBox(height: 24),

              // ── Amount ──
              _buildAmountField(colorScheme),
              const SizedBox(height: 24),

              // ── Bank Account (conditionally shown) ──
              Obx(
                () => controller.selectedMode.value == 'Bank'
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBankDropdown(colorScheme),
                          const SizedBox(height: 24),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Tag Selection ──
              _buildTagSelector(context, colorScheme),
              const SizedBox(height: 24),

              // ── Note / Narration ──
              _buildNoteField(colorScheme),
              const SizedBox(height: 48),

              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoadingSave.value
                        ? null
                        : controller.saveTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: controller.isLoadingSave.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Transaction',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Obx(() {
        final mode = controller.selectedMode.value;
        // If editing, lock mode based on the transaction type
        final canChangeMode = controller.editingTxn == null;

        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: canChangeMode
                    ? () => controller.selectedMode.value = 'Bank'
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: mode == 'Bank'
                        ? colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: mode == 'Bank'
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Bank',
                    style: TextStyle(
                      fontWeight: mode == 'Bank'
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: mode == 'Bank'
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: canChangeMode
                    ? () => controller.selectedMode.value = 'Cash'
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: mode == 'Cash'
                        ? colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: mode == 'Cash'
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cash',
                    style: TextStyle(
                      fontWeight: mode == 'Cash'
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: mode == 'Cash'
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTypeSwitch(ColorScheme colorScheme) {
    return Obx(() {
      final type = controller.selectedType.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TypeChip(
            title: 'Expense',
            icon: Icons.arrow_upward_rounded,
            isSelected: type == 'DR',
            activeColor: colorScheme.error,
            onTap: () => controller.selectedType.value = 'DR',
            colorScheme: colorScheme,
          ),
          const SizedBox(width: 16),
          _TypeChip(
            title: 'Income',
            icon: Icons.arrow_downward_rounded,
            isSelected: type == 'CR',
            activeColor: Colors.green,
            onTap: () => controller.selectedType.value = 'CR',
            colorScheme: colorScheme,
          ),
        ],
      );
    });
  }

  Widget _buildAmountField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            hintText: '0.00',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }

  Widget _buildBankDropdown(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Account',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          if (controller.isLoadingBanks.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.bankAccounts.isEmpty) {
            return Text(
              'No bank accounts found.',
              style: TextStyle(color: colorScheme.error),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BankAccountModel>(
                value: controller.selectedBankAccount.value,
                hint: const Text('Select Bank Account'),
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                items: controller.bankAccounts.map((b) {
                  return DropdownMenuItem<BankAccountModel>(
                    value: b,
                    child: Text('${b.bankName} •••• ${b.lastFourDigits}'),
                  );
                }).toList(),
                onChanged: (val) {
                  controller.selectedBankAccount.value = val;
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTagSelector(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Tag',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            TagSelectionSheet.show(
              context,
              onTagSelected: (tag) {
                controller.selectedTag.value = tag;
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.label_outline_rounded, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() {
                    final tag = controller.selectedTag.value;
                    if (tag == null) {
                      return Text(
                        'Select a Tag',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                      );
                    }
                    return Text(
                      tag.tagName,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    );
                  }),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.noteCtrl,
          decoration: InputDecoration(
            hintText: 'What was this for?',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() {
                    final date = controller.selectedDate.value;
                    return Text(
                      DateFormat('MMM dd, yyyy').format(date),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    );
                  }),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _TypeChip({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? activeColor
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
