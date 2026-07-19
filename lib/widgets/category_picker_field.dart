import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import 'quick_add_category_sheet.dart';

/// Read-only category display for *editing* an existing item: shows just
/// the current category as a single chip, tapping opens a Cancel/Save sheet
/// (matching the Reminder-time / Language pickers elsewhere in the app)
/// with a scroll wheel to change it, instead of a full grid of every other
/// category — irrelevant clutter once an item already has one assigned.
class CategoryPickerField extends StatelessWidget {
  final List<Category> categories;
  final Category selected;
  final ValueChanged<Category> onChanged;
  final Category Function(
      String name, Color color, String shelfZone, int defaultDays)
      onAddCategory;

  const CategoryPickerField({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
    required this.onAddCategory,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CategoryPickerSheet(
        categories: categories,
        selected: selected,
        onAddCategory: onAddCategory,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected.color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l.data(selected.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<Category> categories;
  final Category selected;
  final Category Function(
      String name, Color color, String shelfZone, int defaultDays)
      onAddCategory;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selected,
    required this.onAddCategory,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late List<Category> _categories = widget.categories;
  late int _index = _categories
      .indexWhere((c) => c.id == widget.selected.id)
      .clamp(0, _categories.length - 1);
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: _index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addCategory() {
    showQuickAddCategorySheet(
      context,
      existingNames: _categories.map((c) => c.name).toList(),
      onSubmit: (name, color) {
        // Quick-add doesn't ask for a shelf zone, so borrow the curated
        // "other" category's zone rather than an arbitrary list position —
        // deterministic regardless of category ordering.
        final zone = _categories.isNotEmpty
            ? _categories.fallback.shelfZone
            : widget.selected.shelfZone;
        final cat = widget.onAddCategory(name, color, zone, 7);
        setState(() {
          _categories = [..._categories, cat];
          _index = _categories.length - 1;
        });
        _controller.animateToItem(
          _index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel,
                      style: const TextStyle(
                          fontSize: 17, color: AppColors.textMuted)),
                ),
                Text(l.categoryLabel,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _addCategory,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, _categories[_index]),
                      child: Text(l.save,
                          style: const TextStyle(
                              fontSize: 17,
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 216,
            child: CupertinoPicker(
              scrollController: _controller,
              itemExtent: 40,
              onSelectedItemChanged: (i) => _index = i,
              children: _categories
                  .map((cat) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: cat.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l.data(cat.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 19,
                                      color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
