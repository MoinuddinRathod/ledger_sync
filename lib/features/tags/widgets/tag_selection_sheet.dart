import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../controllers/tags_controller.dart';
import '../models/tag_model.dart';

class TagSelectionSheet extends StatefulWidget {
  final String title;
  final String? narrationPreview;
  final Function(TagModel) onTagSelected;

  const TagSelectionSheet({
    super.key,
    required this.title,
    this.narrationPreview,
    required this.onTagSelected,
  });

  @override
  State<TagSelectionSheet> createState() => _TagSelectionSheetState();

  static void show(
    BuildContext context, {
    String title = "Select Tag",
    String? narrationPreview,
    required Function(TagModel) onTagSelected,
  }) {
    Get.bottomSheet(
      TagSelectionSheet(
        title: title,
        narrationPreview: narrationPreview,
        onTagSelected: onTagSelected,
      ),
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
    );
  }
}

class _TagSelectionSheetState extends State<TagSelectionSheet> {
  // We can just use the global TagsController
  final TagsController controller = Get.find<TagsController>();

  @override
  void initState() {
    super.initState();
    // Ensure tags are loaded if not already
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchTags();
    });
  }

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

            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            if (widget.narrationPreview != null &&
                widget.narrationPreview!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.narrationPreview!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 12),

            Expanded(
              child: Obx(() {
                if (controller.isLoadingFetch.value &&
                    controller.tags.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  itemCount: controller.tags.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.add, color: Colors.blue),
                        title: const Text(
                          "Create New Tag",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          Get.back(); // close sheet
                          if (widget.narrationPreview != null &&
                              widget.narrationPreview!.isNotEmpty) {
                            _openCreateTagSheet(context);
                          } else {
                            controller.clearCreateTagState();
                            controller.initCreateTag();
                            Get.toNamed(AppRoutes.tagAddEdit);
                          }
                        },
                      );
                    }

                    final tag = controller.tags[index - 1];
                    final keywordsStr = tag.tagKeywords
                        .map((kw) => kw["name"].toString())
                        .where((s) => s.isNotEmpty)
                        .join(', ');

                    return ListTile(
                      title: Text(tag.tagName),
                      subtitle: Text(keywordsStr),
                      onTap: () {
                        Get.back(); // dismiss sheet
                        widget.onTagSelected(tag);
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

  void _openCreateTagSheet(BuildContext context) {
    Get.toNamed(
      AppRoutes.tagAddEdit,
      arguments: {
        'narration': widget.narrationPreview ?? '',
        'prefilledName': '',
        'keywords': <String>[],
      },
    )?.then((result) {
      if (result != null && result is Map) {
        // Tag was created. Refresh controller
        controller.fetchTags();
      }
    });
  }
}
