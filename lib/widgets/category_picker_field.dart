import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import 'category_chip_picker.dart';
import 'anchored_picker.dart';

/// Read-only category display for *editing* an existing item: shows just
/// the current category as a single chip, tapping opens a small popup
/// anchored to the chip (not a full-width sheet) with the full picker
/// (select or quick-create) to change it. Unlike the inline
/// [CategoryChipPicker] used when adding a new item, this keeps every
/// other category out of view — irrelevant clutter once an item already
/// has one assigned.
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
    final l = L10n.of(context);
    final picked = await showAnchoredPicker<Category>(
      context,
      maxWidth: 300,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.categoryLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            CategoryChipPicker(
              categories: categories,
              selected: selected,
              onAddCategory: onAddCategory,
              onSelect: (cat) => Navigator.pop(ctx, cat),
            ),
          ],
        ),
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
            Text(
              l.data(selected.name),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
