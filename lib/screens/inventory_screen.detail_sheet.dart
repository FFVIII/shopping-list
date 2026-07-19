part of 'inventory_screen.dart';

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
      String name, Color color, String shelfZone, int defaultDays)
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
    final previewDays = _resetPending ? _selectedDays : widget.item.daysRemaining;
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
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textDisabled),
                        const SizedBox(width: 4),
                        Text(
                          l.aisleLabel,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textMuted),
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
                        horizontal: 16, vertical: 8),
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
                      horizontal: 10, vertical: 4),
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
                  child: TextField(
                    controller: _nameCtrl,
                    maxLength: 30,
                    style: const TextStyle(fontSize: 15),
                    decoration: fieldDecoration(l.productNameHint, verticalPadding: 10),
                    onChanged: (v) {
                      _draft
                        ..name = v
                        ..dirty = true;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 10,
                    style: const TextStyle(fontSize: 15),
                    decoration: fieldDecoration(l.quantityFieldLabel, verticalPadding: 10),
                    onChanged: (v) {
                      _draft
                        ..quantity = v
                        ..dirty = true;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Shelf code ─────────────────────────────────────────────────
            TextField(
              controller: _shelfCtrl,
              maxLength: 20,
              style: const TextStyle(fontSize: 15),
              decoration: fieldDecoration(l.shelfCodeFieldLabel, verticalPadding: 10).copyWith(
                  suffixIcon: widget.shelfCodeOrder.isEmpty
                      ? null
                      : Builder(
                          builder: (iconContext) => IconButton(
                            icon: const Icon(Icons.list_alt_rounded,
                                size: 20, color: AppColors.textSecondary),
                            onPressed: () async {
                              final picked = await pickShelfCode(
                                  iconContext, widget.shelfCodeOrder);
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
                        )),
              onChanged: (v) {
                _draft
                  ..shelfCode = v
                  ..dirty = true;
              },
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
                foregroundColor:
                    _addedToList ? AppColors.textMuted : AppColors.brand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                              foregroundColor: AppColors.danger),
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
                    fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
