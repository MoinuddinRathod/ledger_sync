import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// Note: Update these imports based on your actual project structure
import '../controller/virtual_entries_controller.dart';
import '../../../core/service/dialog_service.dart';
import '../models/virtual_entry_model.dart';
import '../../tags/widgets/tag_selection_sheet.dart';
import '../../tags/controllers/tags_controller.dart';
import 'settlement_screen.dart';

class VirtualEntriesScreen extends GetWidget<VirtualEntriesController> {
  VirtualEntriesScreen({super.key});
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Use standard theme surface colors to match HomeScreen
    final bgColor = theme.colorScheme.surface;
    final surfaceColor = isDark ? const Color(0xFF1A1C35) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A2D52)
        : const Color(0xFFE4E6FF);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent, // Matched with HomeScreen
          elevation: 0, // Matched with HomeScreen
          centerTitle: false,
          titleSpacing: 0,
          title: Obx(() {
            if (controller.isSearching.value) {
              return Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1C35)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search entries...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    suffixIcon: controller.searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 18,
                              color: colorScheme.onSurface,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              controller.searchQuery.value = '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => controller.searchQuery.value = value,
                ),
              );
            } else {
              return Text(
                'Virtual Entries',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              );
            }
          }),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Obx(
                  () => Icon(
                    controller.isSearching.value ? Icons.close : Icons.search,
                    color: colorScheme.onSurface,
                  ),
                ),
                onPressed: () {
                  controller.isSearching.toggle();
                  if (!controller.isSearching.value) {
                    _searchController.clear();
                    controller.searchQuery.value = '';
                  }
                },
              ),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          print('[Screen] controller hashCode: ${controller.hashCode}');
          print('matchedEntries count: ${controller.matchedEntries.length}');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Dual Summary Cards (Styled like Home Balance Cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        theme: theme,
                        isDark: isDark,
                        title: 'To Receive',
                        amount: controller.totalReceivable.value,
                        isReceivable: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        theme: theme,
                        isDark: isDark,
                        title: 'To Pay',
                        amount: controller.totalPayable.value,
                        isReceivable: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Settlement Banner (shown when matches exist)
              Obx(() {
                if (controller.matchedEntries.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _buildSettlementBanner(theme, isDark);
              }),

              // Tab Bar Container with custom style
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1C35)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  labelColor: theme.colorScheme.onPrimary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.6,
                  ),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Receivables'),
                    Tab(text: 'Payments'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildEntriesList(
                      theme: theme,
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      entries: controller.receivableEntries,
                      isEmptyMessage: 'No pending receivables',
                    ),
                    _buildEntriesList(
                      theme: theme,
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      entries: controller.payableEntries,
                      isEmptyMessage: 'No pending payments',
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
        floatingActionButton: FloatingActionButton(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: () {
            controller.clearForm();
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
      ),
    );
  }

  // --- Summary Card Widget ---
  Widget _buildSummaryCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required double amount,
    required bool isReceivable,
  }) {
    final currencyFormatter = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );
    final formattedAmount = currencyFormatter.format(amount);

    final colors = isReceivable
        ? (isDark
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [Colors.green.shade600, Colors.green.shade400])
        : (isDark
              ? [const Color(0xFFB71C1C), const Color(0xFFD32F2F)]
              : [Colors.red.shade700, Colors.redAccent]);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: isDark ? 0.2 : 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isReceivable
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formattedAmount,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Settlement Banner Widget ---
  Widget _buildSettlementBanner(ThemeData theme, bool isDark) {
    final matchCount = controller.matchedEntries.length;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      child: InkWell(
        onTap: () {
          Get.to(() => const SettlementScreen());
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
                  : [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$matchCount Match${matchCount > 1 ? 'es' : ''} Found",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tap to review and settle",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- List Section ---
  Widget _buildEntriesList({
    required ThemeData theme,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required List<VirtualEntryModel> entries,
    required String isEmptyMessage,
  }) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              isEmptyMessage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    Map<String, List<Widget>> groupedEntries = {};

    for (var entry in entries) {
      DateTime dt = DateTime.parse(entry.dateAdded);
      String dateKey = DateFormat('yyyy-MM-dd').format(dt);
      String time = DateFormat('h:mm a').format(dt);

      bool isReceivable = entry.entryType == 'Receivable';
      String formattedAmount =
          "₹${NumberFormat('#,##0.00', 'en_IN').format(entry.amount)}";

      IconData iconData = isReceivable
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded;
      Color iconColor = isReceivable ? Colors.green : Colors.redAccent;

      Widget item = _buildEntryItem(
        theme: theme,
        isDark: isDark,
        title: entry.resolvedTagName ?? "Unknown Tag",
        subtitle: entry.entryType,
        time: time,
        amount: formattedAmount,
        icon: iconData,
        iconColor: iconColor,
        note: entry.note?.isNotEmpty == true ? entry.note : null,
        entryDate: DateFormat(
          'dd MMM yyyy',
        ).format(DateTime.parse(entry.dateAdded)),
        dueDate: entry.dueDate != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(entry.dueDate!))
            : null,
        dismissKey: ObjectKey(entry),
        onEdit: () async {
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

          controller.populateFormForEdit(entry, tagsController.tags);
          _showAddEntryBottomSheet(
            Get.context!,
            theme,
            isDark,
            surfaceColor,
            borderColor,
            isEditing: true,
            entryId: entry.virtualEntryId,
          );
        },
        confirmDismiss: (direction) async {
          final result = await DialogService.showDeleteDialog(
            onConfirm: () {
              Get.back(result: true);
            },
          );
          return result ?? false;
        },
        onDismissed: (direction) {
          controller.deleteEntry(entry);
        },
      );

      if (!groupedEntries.containsKey(dateKey)) {
        groupedEntries[dateKey] = [];
      }
      groupedEntries[dateKey]!.add(item);
    }

    List<Widget> children = [];
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 1)));

    groupedEntries.forEach((dateKey, widgets) {
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
    });

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDateHeader(ThemeData theme, String date) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        date.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildEntryItem({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String subtitle,
    required String time,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onEdit,
    String? note,
    required String entryDate,
    required String? dueDate,
    required Key dismissKey,
    required Future<bool?> Function(DismissDirection) confirmDismiss,
    required void Function(DismissDirection) onDismissed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: dismissKey,
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onEdit();
            return false;
          } else {
            return await confirmDismiss(direction);
          }
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        onDismissed: onDismissed,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1C35) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2D52) : Colors.grey.shade100,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      "$subtitle • $time",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entryDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        if (dueDate != null) ...[
                          Text(
                            '  →  ',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.event_outlined,
                            size: 11,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dueDate,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Bottom Sheet ---
  void _showAddEntryBottomSheet(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color surfaceColor,
    Color borderColor, {
    bool isEditing = false,
    int? entryId,
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
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    isEditing ? 'Edit Virtual Entry' : 'New Virtual Entry',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                _buildInputLabel(theme, "Entry Type"),
                Obx(
                  () => DropdownButtonFormField<String>(
                    dropdownColor: surfaceColor,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    decoration: _buildDropdownDecoration(
                      theme,
                      isDark,
                      Icons.swap_vert_rounded,
                    ),
                    initialValue: controller.selectedEntryType.value,
                    items: ['Receivable', 'Payable'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text("Pending $value"),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        controller.selectedEntryType.value = val!,
                  ),
                ),
                const SizedBox(height: 20),

                _buildInputLabel(theme, "Select Tag"),
                Obx(() {
                  final selectedTag = controller.selectedTag.value;
                  return InkWell(
                    onTap: () {
                      TagSelectionSheet.show(
                        context,
                        title: "Select Virtual Entry Tag",
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
                        color: isDark
                            ? const Color(0xFF131426)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2D52)
                              : Colors.grey.shade200,
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
                              selectedTag != null
                                  ? selectedTag.tagName
                                  : "Select a tag",
                              style: TextStyle(
                                fontSize: 16,
                                color: selectedTag != null
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
                  );
                }),
                const SizedBox(height: 20),

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
                const SizedBox(height: 20),

                // --- Transaction Date (required) ---
                _buildInputLabel(theme, 'Transaction Date'),
                Obx(() {
                  final date = controller.selectedEntryDate.value;
                  final formatted = DateFormat('dd MMM yyyy').format(date);
                  return GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: controller.selectedEntryDate.value,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        controller.selectedEntryDate.value = picked;
                        // If due date is before new entry date, clear it
                        if (controller.selectedDueDate.value != null &&
                            controller.selectedDueDate.value!.isBefore(
                              picked,
                            )) {
                          controller.selectedDueDate.value = null;
                        }
                      }
                    },
                    child: _buildDateDisplay(
                      theme: theme,
                      isDark: isDark,
                      text: formatted,
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // --- Due Date (optional) ---
                Obx(() {
                  final entryType = controller.selectedEntryType.value;
                  return _buildInputLabel(
                    theme,
                    entryType == 'Receivable'
                        ? "Expected Receive Date (Optional)"
                        : "Due Date (Optional)",
                  );
                }),
                Obx(() {
                  final dueDate = controller.selectedDueDate.value;
                  final formatted = dueDate != null
                      ? DateFormat('dd MMM yyyy').format(dueDate)
                      : 'Select due date';
                  return GestureDetector(
                    onTap: () async {
                      final minDate = controller.selectedEntryDate.value;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? minDate,
                        firstDate: minDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        controller.selectedDueDate.value = picked;
                      }
                    },
                    child: _buildDateDisplay(
                      theme: theme,
                      isDark: isDark,
                      text: formatted,
                      isPlaceholder: dueDate == null,
                      showClear: dueDate != null,
                      onClear: () => controller.selectedDueDate.value = null,
                    ),
                  );
                }),
                const SizedBox(height: 20),

                _buildInputLabel(theme, "Note"),
                _buildTextField(
                  controller: controller.noteController,
                  theme: theme,
                  isDark: isDark,
                  hintText: "Enter a note (optional)",
                  icon: Icons.note_alt_outlined,
                ),
                const SizedBox(height: 40),

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
                      elevation: 4,
                      shadowColor: theme.colorScheme.primary.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    onPressed: () {
                      if (controller.formKey.currentState!.validate()) {
                        controller.saveEntry(
                          isEditing: isEditing,
                          entryId: entryId,
                        );
                      }
                    },
                    child: Text(
                      isEditing ? "Update Entry" : "Save Entry",
                      style: const TextStyle(
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

  Widget _buildInputLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildDateDisplay({
    required ThemeData theme,
    required bool isDark,
    required String text,
    bool isPlaceholder = false,
    bool showClear = false,
    VoidCallback? onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131426) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D52) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: isPlaceholder
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (showClear && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(
                Icons.close,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            )
          else
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
        ],
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
      fillColor: isDark ? const Color(0xFF131426) : Colors.grey.shade50,
      prefixIcon: Icon(
        icon,
        color: theme.colorScheme.primary.withValues(alpha: 0.7),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A2D52) : Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A2D52) : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
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
        fillColor: isDark ? const Color(0xFF131426) : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A2D52) : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A2D52) : Colors.grey.shade200,
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
}
