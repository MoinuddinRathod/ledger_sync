import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../bank_account/models/bank_account_model.dart';
import '../controllers/tags_controller.dart';

class TagAddEditScreen extends GetWidget<TagsController> {
  const TagAddEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    // INIT ONLY ONCE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.editingTag != null) return;
      final args = Get.arguments ?? {};
      controller.initCreateTag(
        narrationArg: args['narration'],
        prefilledName: args['prefilledName'],
        keywords: List<String>.from(args['keywords'] ?? []),
      );
    });

    // Dynamic colors for the Keyword/Narration sections
    final fieldColor = cs.onSurface.withValues(alpha: 0.04);
    final borderColor = cs.outline.withValues(alpha: 0.15);
    final textMutedColor = cs.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.onSurface),
        title: Text(
          controller.editingTag == null ? 'Create Tag' : 'Edit Tag',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Obx(
                () => SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Narration Box (KEPT ORIGINAL) ──
                      if (controller.narration != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: fieldColor,
                                border: Border(
                                  left: BorderSide(color: cs.primary, width: 4),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TRANSACTION',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textMutedColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    controller.narration!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // ── Tag Name (UPDATED UI) ──
                      _buildInputLabel(theme, 'Tag Name'),
                      _buildTextField(
                        controller: controller.tagNameCtrl,
                        theme: theme,
                        isDark: isDark,
                        hintText: 'e.g., Groceries',
                        icon: Icons.label_outline_rounded,
                      ),
                      const SizedBox(height: 20),

                      // ── Scope (UPDATED UI) ──
                      _buildInputLabel(theme, 'Scope'),
                      _buildDropdown(
                        theme: theme,
                        isDark: isDark,
                        value: controller.selectedScope.value,
                        items: controller.scopeOptions,
                        icon: Icons.track_changes_rounded,
                        onChanged: (String? val) {
                          if (val != null) controller.changeScope(val);
                        },
                      ),

                      // ── Bank Dropdown (UPDATED UI) ──
                      if (controller.selectedScope.value ==
                          'Bank Account Level') ...[
                        const SizedBox(height: 20),
                        if (controller.bankAccounts.isEmpty)
                          _buildErrorBox('No bank accounts found.')
                        else ...[
                          _buildInputLabel(theme, 'Select Bank Account'),
                          _buildBankAccountDropdown(theme, isDark),
                        ],
                      ],

                      const SizedBox(height: 32),

                      // ── Keywords Section (KEPT ORIGINAL DESIGN) ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInputLabel(theme, 'Keywords'),
                          Text(
                            'Drag to reorder priority',
                            style: TextStyle(
                              fontSize: 12,
                              color: textMutedColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: controller.keywordList.length,
                        onReorder: controller.reorderKeyword,
                        itemBuilder: (context, index) {
                          final entry = controller.keywordList[index];
                          return Container(
                            key: ValueKey(entry.keyword),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      color: textMutedColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer.withValues(
                                      alpha: 0.5,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.keyword,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: textMutedColor,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      controller.removeKeyword(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // ── Add Keyword Input (UPDATED UI) ──
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: controller.addKeywordCtrl,
                              theme: theme,
                              isDark: isDark,
                              hintText: 'Add keyword...',
                              icon: Icons.add_circle_outline_rounded,
                              onSubmitted: (_) => controller.addKeyword(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.primary,
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: controller.addKeyword,
                              child: const Text(
                                'Add',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildFooterInfoBox(cs),
                    ],
                  ),
                ),
              ),
            ),
            _buildSaveButton(cs),
          ],
        ),
      ),
    );
  }

  // --- UI Methods Matching Bank Screen ---

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

  Widget _buildTextField({
    required TextEditingController controller,
    required ThemeData theme,
    required bool isDark,
    required String hintText,
    required IconData icon,
    Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      onFieldSubmitted: onSubmitted,
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
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required ThemeData theme,
    required bool isDark,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: isDark ? const Color(0xFF1E213A) : Colors.white,
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
      icon: const Icon(Icons.expand_more_rounded),
      decoration: InputDecoration(
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
          ),
        ),
      ),
      items: items
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBankAccountDropdown(ThemeData theme, bool isDark) {
    return DropdownButtonFormField<BankAccountModel>(
      isExpanded: true,
      value: controller.selectedBankAccount.value,
      dropdownColor: isDark ? const Color(0xFF1E213A) : Colors.white,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1C35) : const Color(0xFFF5F7FA),
        prefixIcon: Icon(
          Icons.account_balance_wallet_outlined,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: controller.bankAccounts.map((bank) {
        return DropdownMenuItem(
          value: bank,
          child: Text("${bank.bankName} (********${bank.lastFourDigits})"),
        );
      }).toList(),
      onChanged: (val) => controller.selectedBankAccount.value = val,
    );
  }

  // --- Additional Helpers ---

  Widget _buildFooterInfoBox(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Priority 1 is matched first. Drag rows to reorder. Higher priority keywords override lower ones.',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withValues(alpha: 0.7),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: controller.saveCreatedTag,
        child: Obx(
          () => controller.isLoadingAdd.value
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  controller.editingTag == null ? 'Create Tag' : 'Update Tag',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildErrorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 13)),
    );
  }
}
