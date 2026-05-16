import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/service/dialog_service.dart';
import '../../navbar/widgets/navbar_scroll_listener.dart';
import '../../../routes/app_routes.dart';
import '../controllers/tags_controller.dart';
import '../models/tag_model.dart';

class TagsScreen extends GetWidget<TagsController> {
  TagsScreen({super.key});

  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Obx(() {
          if (controller.isSearching.value) {
            return TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search by tag name or keyword...',
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
          } else {
            return Text(
              'All Tags',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            );
          }
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
            } else {
              return Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.search, color: colorScheme.onSurface),
                    onPressed: controller.toggleSearch,
                  ),
                ],
              );
            }
          }),
        ],
      ),
      body: Column(
        children: [
          _buildSortingRow(colorScheme),
          Expanded(
            child: Obx(() {
              if (controller.isLoadingFetch.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.tags.isEmpty) {
                return _buildEmptyState(colorScheme);
              }
              return _buildTagsList(colorScheme);
            }),
          ),
        ],
      ),
      floatingActionButton: _buildFab(context, colorScheme),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

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
            'No Tags found',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a new Tags',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortingRow(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tags',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Text(
                'Sort by:',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Obx(
                () => PopupMenuButton<String>(
                  initialValue: controller.selectedSort.value,
                  onSelected: controller.setSort,
                  itemBuilder: (BuildContext context) {
                    return controller.sortOptions.map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(
                          choice,
                          style: TextStyle(
                            color: controller.selectedSort.value == choice
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: controller.selectedSort.value == choice
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList();
                  },
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

  Widget _buildFab(BuildContext context, ColorScheme colorScheme) {
    return FloatingActionButton.extended(
      onPressed: () {
        controller.clearCreateTagState();
        controller.fetchBankAccouts();
        controller.initCreateTag();
        Get.toNamed(AppRoutes.tagAddEdit);
      },
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      icon: const Icon(Icons.add_rounded, size: 22),
      label: const Text(
        'Add Tags',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
          fontSize: 14,
        ),
      ),
    );
  }

  // ----- tag list ----- //
  Widget _buildTagsList(ColorScheme colorScheme) {
    final tags = controller.tags;

    return NavbarScrollListener(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100, top: 8),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
          return _buildTagTile(
            tag: tag,
            colorScheme: colorScheme,
            dismissKey: ObjectKey(tag),
            onEdit: () {
              controller.initForm(tag); // preload data

              Get.toNamed(AppRoutes.tagAddEdit);
            },
            onDelete: () {
              controller.deleteTag(tagId: tag.tagId!);
            },
          );
        },
      ),
    );
  }

  Widget _TagTileContent({
    required TagModel tag,
    required ColorScheme colorScheme,
  }) {
    final avatarColor =
        Colors.primaries[tag.tagName.length % Colors.primaries.length];

    final _inrFmt = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );

    return Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              tag.tagName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tag.tagName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  controller.mapPriorityToScope(tag.tagPriority),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),

        // DR / CR
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _inrFmt.format(tag.totalCr),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.green,
                  size: 18,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _inrFmt.format(tag.totalDr),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade600,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_up_rounded,
                  color: Colors.red.shade600,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagTile({
    required TagModel tag,
    required ColorScheme colorScheme,
    required Key dismissKey,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final borderRadius = BorderRadius.circular(20);

    return Container(
      decoration: BoxDecoration(borderRadius: borderRadius),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Dismissible(
          key: dismissKey,
          direction: DismissDirection.horizontal,

          /// Swipe Logic (unchanged)
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              onEdit();
              return false;
            } else {
              final result = await DialogService.showDeleteDialog(
                onConfirm: () {
                  Get.back(result: true);
                },
              );
              return result ?? false;
            }
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              onDelete();
            }
          },

          /// Backgrounds
          background: _buildEditBg(),
          secondaryBackground: _buildDeleteBg(),

          /// FINAL CHILD
          child: Material(
            color: colorScheme.surface,
            child: InkWell(
              onTap: () async {
                if (tag.tagId == null) return;
                await controller.fetchTransactionsForTag(tag.tagId!);
                Get.toNamed(AppRoutes.tagTransactionsScreen, arguments: tag);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),

                /// USE YOUR UI HERE
                child: _TagTileContent(tag: tag, colorScheme: colorScheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditBg() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      color: const Color(0xFF3B82F6),
      child: const Row(
        children: [
          Icon(Icons.edit_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text("Edit", style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildDeleteBg() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: const Color(0xFFEF4444),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Delete', style: TextStyle(color: Colors.white)),
          SizedBox(width: 8),
          Icon(Icons.delete_rounded, color: Colors.white),
        ],
      ),
    );
  }
}
