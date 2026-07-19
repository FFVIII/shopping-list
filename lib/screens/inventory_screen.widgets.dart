part of 'inventory_screen.dart';

// Persistent field label shown above each editable input in the inventory
// add/detail sheets, so the field's purpose stays visible once it has a value
// (a bare hint disappears as soon as you type). Matches the section-label
// style used for "Category" / "Estimated days" lower in the same sheets.
Widget _invFieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(left: 2, bottom: 6),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  ),
);

// ── Inventory Card ─────────────────────────────────────────────────────────────

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final int thresholdDays;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final int? reorderIndex;
  final bool batchMode;
  final bool selected;
  final VoidCallback? onHandleTap;
  // The shelf code is redundant with the section header when grouped by
  // aisle — hide it there, but keep it when grouped by category (or
  // ungrouped), where it's the only indication of the item's shelf.
  final bool showShelfCode;

  const _InventoryCard({
    super.key,
    required this.item,
    required this.thresholdDays,
    required this.onTap,
    required this.onDelete,
    this.reorderIndex,
    this.batchMode = false,
    this.selected = false,
    this.onHandleTap,
    this.showShelfCode = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final status = item.statusFor(thresholdDays);
    final remaining = item.daysRemaining;
    final dn = l.data(item.name);
    final q = l.data(item.quantityLabel);
    final endDate = item.purchasedAt.add(Duration(days: item.estimatedDays));
    final endDateStr = l.expiryLabel('${endDate.month}/${endDate.day}');

    return Dismissible(
      key: Key('inv_${item.id}'),
      direction: batchMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Row(
                  children: [
                    // Batch selection circle
                    if (batchMode) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppColors.brand
                              : Colors.transparent,
                          border: selected
                              ? null
                              : Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 15,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                    ],
                    // Muted thumbnail
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.category.bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            dn.isNotEmpty ? dn.substring(0, 1) : '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: item.category.color.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + quantity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (q.isNotEmpty) ...[
                                QuantityBadge(qty: q),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  l.lastBoughtLabel(
                                    '${item.purchasedAt.month}/${item.purchasedAt.day}',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textDisabled,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (showShelfCode &&
                              item.shelfCode != null &&
                              item.shelfCode!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.category.color.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.shelfCode!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: item.category.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right: date / progress bar / days:status — drag zone when reorderable
            () {
              final col = Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        endDateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: _ProgressBar(
                      ratio: item.progressRatio,
                      color: status.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 64,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        status == StockStatus.empty
                            ? l.usedUp
                            : '${l.stockStatus(status)}(${l.daysShort(remaining.clamp(0, 999))})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: status.color,
                        ),
                      ),
                    ),
                  ),
                ],
              );
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: reorderIndex != null
                    ? ReorderableDragStartListener(
                        index: reorderIndex!,
                        child: col,
                      )
                    : col,
              );
            }(),
            // Drag handle: always shown when onHandleTap is set.
            // reorderIndex=null in flat/grouped views = tap-only (no drag).
            if (onHandleTap != null)
              DragHandle(index: reorderIndex, onTap: onHandleTap)
            else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}

// ── Flat list entry for drag-reorder (header or item) ───────────────────────────

class _InvEntry {
  final String groupKey;
  final InventoryItem? item;
  _InvEntry.header(this.groupKey) : item = null;
  _InvEntry.forItem(this.item, this.groupKey);
  bool get isHeader => item == null;
}

// ── Detail draft (edits committed on sheet close) ────────────────────────────

class _DetailDraft {
  String name;
  String quantity;
  String shelfCode;
  Category category;
  String zone;
  bool dirty = false;

  _DetailDraft({
    required this.name,
    required this.quantity,
    required this.shelfCode,
    required this.category,
    required this.zone,
  });

  factory _DetailDraft.from(InventoryItem item) => _DetailDraft(
    name: item.name,
    quantity: item.quantityLabel,
    shelfCode: item.shelfCode ?? '',
    category: item.category,
    zone: item.shelfZone,
  );
}

// ── Inventory detail sheet (inline-editable header + reset / restock / delete) ─

class _InventoryDetailSheet extends StatefulWidget {
  final InventoryItem item;
  final List<Category> categories;
  final int thresholdDays;
  final _DetailDraft draft;
  final void Function(int days) onRestock;
  final VoidCallback onAddToList;
  final VoidCallback onDelete;
  final VoidCallback onSave;
  final Category Function(
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  )
  onAddCategory;
  final List<String> shelfCodeOrder;

  const _InventoryDetailSheet({
    required this.item,
    required this.categories,
    required this.thresholdDays,
    required this.draft,
    required this.onRestock,
    required this.onAddToList,
    required this.onDelete,
    required this.onSave,
    required this.onAddCategory,
    required this.shelfCodeOrder,
  });

  @override
  State<_InventoryDetailSheet> createState() => _InventoryDetailSheetState();
}

class _InventoryDetailSheetState extends State<_InventoryDetailSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _shelfCtrl;
  late int _selectedDays;
  bool _resetPending = false;
  bool _addedToList = false;
  bool _textsInitialized = false;

  _DetailDraft get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _qtyCtrl = TextEditingController();
    _shelfCtrl = TextEditingController();
    _selectedDays = widget.item.estimatedDays;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_textsInitialized) {
      // Draft fields stay canonical (raw) — only the displayed text is
      // translated. Programmatic controller.text assignment doesn't fire
      // TextField.onChanged, so this can't itself mark the draft dirty;
      // the explicit reset below is just a defensive belt-and-suspenders.
      final l = L10n.of(context);
      _nameCtrl.text = canonicalDisplay(l, _draft.name);
      _qtyCtrl.text = canonicalDisplay(l, _draft.quantity);
      _shelfCtrl.text = canonicalDisplay(l, _draft.shelfCode);
      _draft.dirty = false;
      _textsInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final status = widget.item.statusFor(widget.thresholdDays);
    final previewStatus = _resetPending
        ? (_selectedDays <= 0
              ? StockStatus.empty
              : _selectedDays <= widget.thresholdDays
              ? StockStatus.low
              : StockStatus.sufficient)
        : status;
    final previewDays = _resetPending
        ? _selectedDays
        : widget.item.daysRemaining;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Aisle/category + Add to restock list ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.aisleLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        CategoryPickerField(
                          categories: widget.categories,
                          selected: _draft.category,
                          onAddCategory: widget.onAddCategory,
                          onChanged: (cat) => setState(() {
                            _draft
                              ..category = cat
                              ..zone = cat.shelfZone
                              ..dirty = true;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSave();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l.save,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: previewStatus.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l.stockStatus(previewStatus),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: previewStatus.color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    previewStatus == StockStatus.empty
                        ? l.usedUp
                        : l.daysRemainingLong(previewDays),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: previewStatus.color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Editable header ──
            // ── Name + Qty row ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _invFieldLabel(l.productNameHint),
                      TextField(
                        controller: _nameCtrl,
                        maxLength: 30,
                        style: const TextStyle(fontSize: 15),
                        decoration: fieldDecoration(
                          l.productNameHint,
                          verticalPadding: 10,
                        ),
                        onChanged: (v) {
                          _draft
                            ..name = v
                            ..dirty = true;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _invFieldLabel(l.quantityFieldLabel),
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 10,
                        style: const TextStyle(fontSize: 15),
                        decoration: fieldDecoration(
                          l.quantityFieldLabel,
                          verticalPadding: 10,
                        ),
                        onChanged: (v) {
                          _draft
                            ..quantity = v
                            ..dirty = true;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Shelf code ─────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _invFieldLabel(l.shelfCodeFieldLabel),
                TextField(
                  controller: _shelfCtrl,
                  maxLength: 20,
                  style: const TextStyle(fontSize: 15),
                  decoration:
                      fieldDecoration(
                        l.shelfCodeFieldLabel,
                        verticalPadding: 10,
                      ).copyWith(
                        suffixIcon: widget.shelfCodeOrder.isEmpty
                            ? null
                            : Builder(
                                builder: (iconContext) => IconButton(
                                  icon: const Icon(
                                    Icons.inventory_outlined,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () async {
                                    final picked = await pickShelfCode(
                                      iconContext,
                                      widget.shelfCodeOrder,
                                    );
                                    if (picked == null) return;
                                    // Programmatic controller.text writes don't
                                    // fire onChanged, so the draft needs updating
                                    // explicitly here too.
                                    setState(() {
                                      _shelfCtrl.text = picked;
                                      _draft
                                        ..shelfCode = picked
                                        ..dirty = true;
                                    });
                                  },
                                ),
                              ),
                      ),
                  onChanged: (v) {
                    _draft
                      ..shelfCode = v
                      ..dirty = true;
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF0F0EA)),
            const SizedBox(height: 16),
            // ── Reset section ──
            Text(
              l.resetTimerSection,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            DaysSelector(
              initialDays: _selectedDays,
              onChanged: (d) {
                setState(() {
                  _selectedDays = d;
                  _resetPending = true;
                });
                widget.onRestock(d);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _addedToList
                    ? AppColors.fieldBg
                    : AppColors.brand.withValues(alpha: 0.12),
                foregroundColor: _addedToList
                    ? AppColors.textMuted
                    : AppColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _addedToList
                  ? null
                  : () {
                      widget.onAddToList();
                      setState(() => _addedToList = true);
                    },
              child: Text(
                _addedToList ? l.alreadyInList : l.addToRestockList,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.deleteFromInventory),
                    content: Text(l.deleteConfirmMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.cancel),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.delete),
                      ),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                // Discard pending edits — the item is being removed.
                _draft.dirty = false;
                Navigator.pop(context);
                widget.onDelete();
              },
              child: Text(
                l.deleteFromInventory,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Inventory Sheet ────────────────────────────────────────────────────────

class _AddInventorySheet extends StatefulWidget {
  final void Function(InventoryItem) onAdd;
  final List<Category> categories;
  final List<String> shelfCodeOrder;
  final Category Function(
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  )
  onAddCategory;

  const _AddInventorySheet({
    required this.onAdd,
    required this.categories,
    required this.shelfCodeOrder,
    required this.onAddCategory,
  });

  @override
  State<_AddInventorySheet> createState() => _AddInventorySheetState();
}

class _AddInventorySheetState extends State<_AddInventorySheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _shelfCtrl = TextEditingController();
  late Category _category = widget.categories.first;
  late int _days = _category.defaultDays;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final shelf = _shelfCtrl.text.trim();
    Navigator.pop(context);
    widget.onAdd(
      InventoryItem(
        id: generateId('inv'),
        name: name,
        category: _category,
        shelfZone: _category.shelfZone,
        shelfCode: shelf.isEmpty ? null : shelf,
        quantityLabel: _qtyCtrl.text.trim(),
        purchasedAt: DateTime.now(),
        estimatedDays: _days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.addToInventoryTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          // ── Name + Qty row ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _invFieldLabel(l.productNameHint),
                    TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      maxLength: 30,
                      style: const TextStyle(fontSize: 15),
                      decoration: fieldDecoration(l.productNameHint),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _invFieldLabel(l.quantityFieldLabel),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 10,
                      style: const TextStyle(fontSize: 15),
                      decoration: fieldDecoration(l.quantityFieldLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Shelf code ─────────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _invFieldLabel(l.shelfCodeFieldLabel),
              TextField(
                controller: _shelfCtrl,
                maxLength: 20,
                style: const TextStyle(fontSize: 15),
                decoration: fieldDecoration(l.shelfCodeFieldLabel).copyWith(
                  suffixIcon: widget.shelfCodeOrder.isEmpty
                      ? null
                      : Builder(
                          builder: (iconContext) => IconButton(
                            icon: const Icon(
                              Icons.inventory_outlined,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () async {
                              final picked = await pickShelfCode(
                                iconContext,
                                widget.shelfCodeOrder,
                              );
                              if (picked != null) {
                                setState(() => _shelfCtrl.text = picked);
                              }
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.categoryLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          CategoryChipPicker(
            categories: widget.categories,
            selected: _category,
            onAddCategory: widget.onAddCategory,
            onSelect: (cat) => setState(() => _category = cat),
          ),
          const SizedBox(height: 16),
          Text(
            l.estimatedUseDays,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DaysSelector(
            initialDays: _days,
            onChanged: (d) => setState(() => _days = d),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _nameCtrl.text.trim().isEmpty ? null : _submit,
            child: Text(
              l.addToInventoryBtn,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress Bar ───────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double ratio;
  final Color color;
  const _ProgressBar({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        FractionallySizedBox(
          widthFactor: ratio.clamp(0.0, 1.0),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}
