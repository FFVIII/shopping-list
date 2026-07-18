import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import 'quick_add_category_sheet.dart';
import 'toast.dart';

/// Category selector used by the Plan/Inventory add and edit sheets: a Wrap
/// of chips plus a trailing "+" chip that creates a new category inline
/// (via [showQuickAddCategorySheet]) and selects it immediately, without
/// leaving the current sheet. Each chip (except the fallback "other"
/// category, which can't be deleted) has a small "x" for quick removal.
class CategoryChipPicker extends StatefulWidget {
  final List<Category> categories;
  final Category selected;
  final void Function(Category category) onSelect;
  final Category Function(
      String name, Color color, String shelfZone, int defaultDays)
      onAddCategory;
  final void Function(String id) onDeleteCategory;

  const CategoryChipPicker({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.onAddCategory,
    required this.onDeleteCategory,
  });

  @override
  State<CategoryChipPicker> createState() => _CategoryChipPickerState();
}

class _CategoryChipPickerState extends State<CategoryChipPicker> {
  // Above this many categories, a search box appears above the chips so
  // finding one doesn't mean scanning a wall of Wrap-wrapped rows.
  static const int _searchThreshold = 8;
  // Hard cap on quick-added categories — the chip picker has no pagination,
  // so an unbounded list would eventually make every add/edit sheet unusable.
  static const int _maxCategories = 30;

  late List<Category> _categories = widget.categories;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void didUpdateWidget(CategoryChipPicker old) {
    super.didUpdateWidget(old);
    if (widget.categories != old.categories) _categories = widget.categories;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addCategory() {
    if (_categories.length >= _maxCategories) {
      showAppToast(
          context, L10n.of(context).categoryLimitReachedToast(_maxCategories));
      return;
    }
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
        setState(() => _categories = [..._categories, cat]);
        widget.onSelect(cat);
      },
    );
  }

  // Removes the chip immediately (with an undo window), matching the
  // swipe-to-delete pattern used elsewhere for items. If the deleted
  // category was selected, selection falls back to "other" until/unless
  // the delete is undone.
  void _deleteCategory(Category cat) {
    final l = L10n.of(context);
    final index = _categories.indexOf(cat);
    final wasSelected = widget.selected == cat;
    setState(() => _categories = _categories.where((c) => c != cat).toList());
    if (wasSelected) widget.onSelect(_categories.fallback);
    showUndoToast(
      context,
      message: l.itemDeletedToast(l.data(cat.name)),
      actionLabel: l.undo,
      onAction: () {
        if (!mounted) return;
        setState(() {
          final restoreAt = index.clamp(0, _categories.length);
          _categories = [..._categories]..insert(restoreAt, cat);
        });
        if (wasSelected) widget.onSelect(cat);
      },
      onTimeout: () => widget.onDeleteCategory(cat.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final showSearch = _categories.length > _searchThreshold;
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? _categories
        : _categories
            .where((cat) => l.data(cat.name).toLowerCase().contains(query))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: l.categorySearchHint,
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppColors.textDisabled),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...visible.map((cat) {
              final sel = widget.selected == cat;
              final deletable = cat.id != kFallbackCategoryId;
              final fg = sel ? Colors.white : cat.color;
              return GestureDetector(
                onTap: () => widget.onSelect(cat),
                child: Container(
                  padding: EdgeInsets.only(
                      left: 14, right: deletable ? 8 : 14, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: sel ? cat.color : cat.bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.data(cat.name),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      if (deletable) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _deleteCategory(cat),
                          child: Icon(Icons.close_rounded,
                              size: 14, color: fg.withValues(alpha: 0.7)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: _addCategory,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.fieldBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
