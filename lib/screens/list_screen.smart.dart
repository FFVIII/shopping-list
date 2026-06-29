part of 'list_screen.dart';

// ── Smart mode state extension ────────────────────────────────────────────────

extension _SmartModeState on _ListScreenState {
  Map<String, List<ShoppingItem>> _groupByShelf() {
    final map = <String, List<ShoppingItem>>{};
    final untagged = <ShoppingItem>[];
    for (final item in widget.smartItems) {
      final code = item.shelfCode?.trim();
      if (code != null && code.isNotEmpty) {
        map.putIfAbsent(code, () => []).add(item);
      } else {
        untagged.add(item);
      }
    }
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    if (untagged.isNotEmpty) {
      sorted[L10n.of(context).untaggedShelf] = untagged;
    }
    return sorted;
  }

  Map<String, List<ShoppingItem>> _groupByCategory() {
    final map = <String, List<ShoppingItem>>{};
    for (final item in widget.smartItems) {
      map.putIfAbsent(item.category.name, () => []).add(item);
    }
    return map;
  }

  List<_FlatEntry> _buildFlatEntries(Map<String, List<ShoppingItem>> groups) {
    final entries = <_FlatEntry>[];
    for (final entry in groups.entries) {
      entries.add(_FlatEntry.header(entry.key));
      for (final item in entry.value) {
        entries.add(_FlatEntry.forItem(item, entry.key));
      }
    }
    return entries;
  }

  void _onSmartReorder(int oldIndex, int newIndex, List<_FlatEntry> flat) {
    if (flat[oldIndex].isHeader) return;
    final movedItem = flat[oldIndex].item!;

    final mutable = List<_FlatEntry>.from(flat);
    final moved = mutable.removeAt(oldIndex);
    mutable.insert(newIndex, moved);

    String newGroup = '';
    for (int i = newIndex; i >= 0; i--) {
      if (mutable[i].isHeader) {
        newGroup = mutable[i].groupKey;
        break;
      }
    }
    if (newGroup.isEmpty) {
      for (final e in mutable) {
        if (e.isHeader) {
          newGroup = e.groupKey;
          break;
        }
      }
    }
    if (newGroup.isEmpty) return;

    final orderedIds = mutable
        .where((e) => !e.isHeader)
        .map((e) => e.item!.id)
        .toList();

    if (_byShelf) {
      widget.onReorderSmart(movedItem.id, newGroup, null, orderedIds);
    } else {
      final newCat = widget.categories.firstWhere(
        (c) => c.name == newGroup,
        orElse: () => movedItem.category,
      );
      widget.onReorderSmart(movedItem.id, null, newCat, orderedIds);
    }
  }

  Widget _buildSmartList() {
    final groups = _byShelf ? _groupByShelf() : _groupByCategory();
    final flat = _buildFlatEntries(groups);
    final groupCounts = {
      for (final e in groups.entries) e.key: e.value.length
    };
    final groupColors = {
      for (final e in groups.entries)
        e.key: e.value.first.category.color,
    };

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      buildDefaultDragHandles: false,
      itemCount: flat.length,
      itemBuilder: (ctx, i) {
        final entry = flat[i];
        if (entry.isHeader) {
          return _buildSectionHeader(
            entry.groupKey,
            groupCounts[entry.groupKey] ?? 0,
            color: groupColors[entry.groupKey],
            key: Key('h_${entry.groupKey}'),
          );
        }
        final item = entry.item!;
        final zoneColor = item.category.color;
        return _SmartRow(
          key: Key('si_${item.id}'),
          item: item,
          zoneColor: zoneColor,
          onToggle: () => widget.onToggleSmart(item.id),
          onDelete: () => widget.onDeleteSmart(item.id),
          onLongPress: _smartBatchMode ? null : () => _showRenameSheet(item, true),
          showDragHandle: !item.checked && !_smartBatchMode,
          reorderIndex: (item.checked || _smartBatchMode) ? null : i,
          batchMode: _smartBatchMode,
          selected: _smartSelected.contains(item.id),
          onSelect: () => _toggleSmartSelection(item.id),
          onHandleTap: () => _enterSmartBatchWithItem(item.id),
        );
      },
      onReorderItem: (old, newIdx) => _onSmartReorder(old, newIdx, flat),
      proxyDecorator: (child, index, animation) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        shadowColor: Colors.black26,
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(String zone, int count, {Key? key, Color? color}) {
    final l = L10n.of(context);
    final color0 = color ?? AppColors.textMuted;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color0, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            l.data(zone),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color0.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l.itemCountChip(count),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Smart Row ─────────────────────────────────────────────────────────────────

class _SmartRow extends StatelessWidget {
  final ShoppingItem item;
  final Color zoneColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool showDragHandle;
  final int? reorderIndex;
  final bool batchMode;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onHandleTap;

  const _SmartRow({
    super.key,
    required this.item,
    required this.zoneColor,
    required this.onToggle,
    required this.onDelete,
    this.onLongPress,
    this.showDragHandle = false,
    this.reorderIndex,
    this.batchMode = false,
    this.selected = false,
    this.onSelect,
    this.onHandleTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final qty = l.data(item.quantityLabel);
    final code = item.shelfCode != null ? l.data(item.shelfCode!) : null;
    final faded = item.checked;

    return Dismissible(
      key: Key('smart_${item.id}'),
      direction: batchMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: batchMode ? onSelect : onToggle,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
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
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left color bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: faded ? const Color(0xFFE8E8E8) : zoneColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14)),
                  ),
                ),
                // Selection circle (only in batch mode)
                if (batchMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    child: _SelectCircle(selected: selected),
                  )
                else
                  const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                l.data(item.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: faded
                                      ? AppColors.textDisabled
                                      : AppColors.textPrimary,
                                  decoration: faded
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: AppColors.textDisabled,
                                ),
                              ),
                            ),
                            if (qty.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  qty,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: faded
                                        ? AppColors.textDisabled
                                        : AppColors.textMuted,
                                    decoration: faded
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: AppColors.textDisabled,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (code != null) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: faded
                                  ? const Color(0xFFF0F0EC)
                                  : zoneColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: faded
                                    ? AppColors.textDisabled
                                    : zoneColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Right badges + drag
                if (item.addedToInventory)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l.recordedBadge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: zoneColor,
                      ),
                    ),
                  ),
                if (showDragHandle && !item.checked && reorderIndex != null)
                  GestureDetector(
                    onTap: onHandleTap,
                    child: ReorderableDragStartListener(
                      index: reorderIndex!,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.drag_handle_rounded,
                            size: 20, color: AppColors.border),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Smart Add Sheet ───────────────────────────────────────────────────────────

class _SmartAddSheet extends StatefulWidget {
  final String name;
  final List<Category> categories;
  final void Function(Category category, String zone, String quantityLabel, String? shelfCode) onConfirm;

  const _SmartAddSheet({
    required this.name,
    required this.categories,
    required this.onConfirm,
  });

  @override
  State<_SmartAddSheet> createState() => _SmartAddSheetState();
}

class _SmartAddSheetState extends State<_SmartAddSheet> {
  late Category _selectedCategory;
  late String _selectedZone;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _shelfCtrl;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.first;
    _selectedZone = _selectedCategory.shelfZone;
    _qtyCtrl = TextEditingController();
    _shelfCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
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
              l.addItemTitle(l.data(widget.name)),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l.chooseCategoryHint,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories.map((cat) {
                final sel = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = cat;
                    _selectedZone = cat.shelfZone;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? cat.color : cat.bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : cat.color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          l.quantityFieldLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _qtyCtrl,
                        style: const TextStyle(fontSize: 15),
                        decoration: _fieldDecoration('1件'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          l.shelfCodeFieldLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextField(
                        controller: _shelfCtrl,
                        style: const TextStyle(fontSize: 15),
                        decoration: _fieldDecoration('货架B1'),
                      ),
                    ],
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
                onPressed: () {
                  final shelf = _shelfCtrl.text.trim();
                  Navigator.pop(context);
                  widget.onConfirm(
                    _selectedCategory,
                    _selectedZone,
                    _qtyCtrl.text.trim(),
                    shelf.isEmpty ? null : shelf,
                  );
                },
                child: Text(
                  l.addToList,
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

// ── Edit Smart Item Sheet ─────────────────────────────────────────────────────

class _EditSmartSheet extends StatefulWidget {
  final ShoppingItem item;
  final List<Category> categories;
  final void Function(
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) onConfirm;

  const _EditSmartSheet({
    required this.item,
    required this.categories,
    required this.onConfirm,
  });

  @override
  State<_EditSmartSheet> createState() => _EditSmartSheetState();
}

class _EditSmartSheetState extends State<_EditSmartSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _shelfCtrl;
  late Category _category;
  late String _zone;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _qtyCtrl = TextEditingController(text: widget.item.quantityLabel);
    _shelfCtrl = TextEditingController(text: widget.item.shelfCode ?? '');
    _category = widget.item.category;
    _zone = widget.item.shelfZone;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final shelf = _shelfCtrl.text.trim();
    Navigator.pop(context);
    widget.onConfirm(
      name,
      _qtyCtrl.text.trim(),
      shelf.isEmpty ? null : shelf,
      _category,
      _zone,
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
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
              l.editItem,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration(''),
              onSubmitted: (_) => _confirm(),
            ),
            _label(l.quantityFieldLabel),
            TextField(
              controller: _qtyCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration('1'),
            ),
            _label(l.shelfCodeFieldLabel),
            TextField(
              controller: _shelfCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration(''),
            ),
            _label(l.categoryLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories.map((cat) {
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _category = cat;
                    _zone = cat.shelfZone;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? cat.color : cat.bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : cat.color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textDisabled),
                const SizedBox(width: 4),
                Text(
                  l.shelfZoneInline(l.data(_zone)),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
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
                onPressed: _confirm,
                child: Text(
                  l.confirmEdit,
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
