import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/drag_handle.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import '../widgets/batch_bar.dart';

class CategoryManageScreen extends StatefulWidget {
  final List<Category> categories;
  final List<ShelfZone> shelfZones;
  final Category Function(String name, Color color, String shelfZone, int defaultDays)
      onAdd;
  final void Function(
    String id,
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  ) onEdit;
  final void Function(String id) onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  const CategoryManageScreen({
    super.key,
    required this.categories,
    required this.shelfZones,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  State<CategoryManageScreen> createState() => _CategoryManageScreenState();
}

class _CategoryManageScreenState extends State<CategoryManageScreen> {
  late List<Category> _categories;
  bool _batchMode = false;
  final Set<String> _selected = {};

  static const List<Color> _palette = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE53935),
    Color(0xFFFF9800),
    Color(0xFF7B1FA2),
    Color(0xFF8D6E63),
    Color(0xFF0288D1),
    Color(0xFF78909C),
  ];

  @override
  void initState() {
    super.initState();
    _categories = List<Category>.from(widget.categories);
  }

  void _openEdit(Category cat) {
    if (_batchMode) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryEditSheet(
        initial: cat,
        shelfZones: widget.shelfZones,
        palette: _palette,
        onSubmit: (name, color, zone, days) {
          widget.onEdit(cat.id, name, color, zone, days);
          setState(() => _categories = List<Category>.from(_categories));
        },
      ),
    );
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryEditSheet(
        initial: null,
        shelfZones: widget.shelfZones,
        palette: _palette,
        onSubmit: (name, color, zone, days) {
          final cat = widget.onAdd(name, color, zone, days);
          setState(() => _categories = [..._categories, cat]);
        },
      ),
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    widget.onReorder(oldIndex, newIndex);
    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
  }

  Future<void> _batchDelete() async {
    final l = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.selectedCount(_selected.length)),
        content: Text(l.deleteCategoryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in _selected) {
      widget.onDelete(id);
    }
    setState(() {
      _categories = _categories.where((c) => !_selected.contains(c.id)).toList();
      _selected.clear();
      _batchMode = false;
    });
  }

  Widget _buildBatchBar() {
    final allIds = _categories
        .where((c) => c.id != kFallbackCategoryId)
        .map((c) => c.id)
        .toSet();
    final allSelected = allIds.isNotEmpty && _selected.containsAll(allIds);
    final hasSelection = _selected.isNotEmpty;

    return BatchBar(
      selectedCount: _selected.length,
      showCountLabel: true,
      allSelected: allSelected,
      onToggleAll: () => setState(() {
        if (allSelected) {
          _selected.clear();
        } else {
          _selected.addAll(allIds);
        }
      }),
      onDelete: hasSelection ? _batchDelete : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          l.manageCategories,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_batchMode)
            IconButton(
              onPressed: () => setState(() {
                _batchMode = false;
                _selected.clear();
              }),
              icon: const Icon(Icons.close_rounded),
            )
          else
            IconButton(
              onPressed: _openAdd,
              icon: const Icon(Icons.add_rounded),
              tooltip: l.add,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _categories.length,
                buildDefaultDragHandles: false,
                onReorderItem: _handleReorder,
                proxyDecorator: (child, index, animation) => Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  shadowColor: Colors.black26,
                  child: child,
                ),
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final isFallback = cat.id == kFallbackCategoryId;
                  final isSelected = _selected.contains(cat.id);
                  return Container(
                    key: ValueKey('cat_${cat.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _batchMode
                          ? (isFallback
                              ? null
                              : () => setState(() {
                                    if (isSelected) {
                                      _selected.remove(cat.id);
                                    } else {
                                      _selected.add(cat.id);
                                    }
                                  }))
                          : () => _openEdit(cat),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            if (_batchMode && !isFallback)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 20,
                                  color: isSelected
                                      ? AppColors.brand
                                      : AppColors.textDisabled,
                                ),
                              ),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: cat.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l.data(cat.shelfZone)} · ${l.days(cat.defaultDays)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DragHandle(
                              index: i,
                              onTap: isFallback
                                  ? null
                                  : () => setState(() {
                                        _batchMode = true;
                                        _selected.add(cat.id);
                                      }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_batchMode) _buildBatchBar(),
          ],
        ),
      ),
    );
  }
}

// ── Edit sheet (add + edit) ──────────────────────────────────────────────────

class _CategoryEditSheet extends StatefulWidget {
  final Category? initial;
  final List<ShelfZone> shelfZones;
  final List<Color> palette;
  final void Function(String name, Color color, String shelfZone, int defaultDays)
      onSubmit;

  const _CategoryEditSheet({
    required this.initial,
    required this.shelfZones,
    required this.palette,
    required this.onSubmit,
  });

  @override
  State<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<_CategoryEditSheet> {
  late final TextEditingController _nameCtrl;
  late Color _color;
  late String _zone;
  late int _days;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl = TextEditingController(text: init?.name ?? '');
    _color = init?.color ?? widget.palette.first;
    _zone = init?.shelfZone ?? widget.shelfZones.first.name;
    _days = init?.defaultDays ?? 7;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    widget.onSubmit(name, _color, _zone, _days);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initial == null ? l.addCategoryTitle : l.editCategoryTitle,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            _label(l.categoryNameLabel),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: l.categoryNameLabel,
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            _label(l.categoryColorLabel),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.palette.map((c) {
                final sel = c.toARGB32() == _color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: AppColors.textPrimary, width: 2)
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            _label(l.shelfZoneLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.shelfZones.map((z) {
                final sel = z.name == _zone;
                return GestureDetector(
                  onTap: () => setState(() => _zone = z.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.brand.withValues(alpha: 0.12)
                          : AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: z.dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.data(z.name),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? AppColors.brand
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            _label(l.defaultDaysLabel),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.brand,
                      inactiveTrackColor: AppColors.divider,
                      thumbColor: AppColors.brand,
                      overlayColor: AppColors.brand.withValues(alpha: 0.15),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _days.toDouble().clamp(1, 60),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      onChanged: (v) => setState(() => _days = v.round()),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    l.days(_days),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _submit,
                child: Text(
                  widget.initial == null ? l.addToList : l.confirmEdit,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
