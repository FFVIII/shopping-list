part of 'inventory_screen.dart';

// ── Inventory Card ─────────────────────────────────────────────────────────────

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final int thresholdDays;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final int? reorderIndex;

  const _InventoryCard({
    super.key,
    required this.item,
    required this.thresholdDays,
    required this.onTap,
    required this.onDelete,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final status = item.statusFor(thresholdDays);
    final remaining = item.daysRemaining;
    final dn = l.data(item.name);
    final barColor =
        defaultShelfZones.findByName(item.shelfZone)?.dotColor ?? item.category.color;
    final q = l.data(item.quantityLabel);
    final code = item.shelfCode != null ? l.data(item.shelfCode!) : '';
    final meta = [
      if (q.isNotEmpty) q,
      if (code.isNotEmpty) code,
    ].join(' · ');

    return Dismissible(
      key: Key('inv_${item.id}'),
      direction: DismissDirection.endToStart,
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
        onTap: onTap,
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
                    color: barColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14)),
                  ),
                ),
                const SizedBox(width: 12),
                // Thumbnail
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: item.category.bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      dn.length > 2 ? dn.substring(0, 2) : dn,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: item.category.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dn,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _ProgressBar(
                          ratio: item.progressRatio,
                          color: status.color,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          status == StockStatus.empty
                              ? l.usedUp
                              : (remaining <= 3
                                  ? l.daysShortApprox(remaining)
                                  : l.daysShort(remaining)),
                          style: TextStyle(
                            fontSize: 12,
                            color: status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Status badge
                Container(
                  margin: EdgeInsets.only(right: reorderIndex == null ? 14 : 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status.bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.stockStatus(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status.color,
                    ),
                  ),
                ),
                // Drag handle (only in reorderable mode)
                if (reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10, left: 2),
                      child: Icon(Icons.drag_handle_rounded,
                          size: 20, color: AppColors.border),
                    ),
                  ),
              ],
            ),
          ),
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

  const _InventoryDetailSheet({
    required this.item,
    required this.categories,
    required this.thresholdDays,
    required this.draft,
    required this.onRestock,
    required this.onAddToList,
    required this.onDelete,
  });

  @override
  State<_InventoryDetailSheet> createState() => _InventoryDetailSheetState();
}

class _InventoryDetailSheetState extends State<_InventoryDetailSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _shelfCtrl;
  late int _selectedDays;

  _DetailDraft get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _draft.name);
    _qtyCtrl = TextEditingController(text: _draft.quantity);
    _shelfCtrl = TextEditingController(text: _draft.shelfCode);
    _selectedDays = widget.item.estimatedDays;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        isDense: true,
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 12),
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
    final status = widget.item.statusFor(widget.thresholdDays);
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
            // ── Editable header ──
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: _dec(l.productNameHint),
              onChanged: (v) {
                _draft
                  ..name = v
                  ..dirty = true;
              },
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: TextField(
                      controller: _qtyCtrl,
                      style: const TextStyle(fontSize: 15),
                      decoration: _dec(l.quantityFieldLabel),
                      onChanged: (v) {
                        _draft
                          ..quantity = v
                          ..dirty = true;
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5, top: 10),
                    child: TextField(
                      controller: _shelfCtrl,
                      style: const TextStyle(fontSize: 15),
                      decoration: _dec(l.shelfCodeFieldLabel),
                      onChanged: (v) {
                        _draft
                          ..shelfCode = v
                          ..dirty = true;
                      },
                    ),
                  ),
                ),
              ],
            ),
            _label(l.categoryLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories.map((cat) {
                final sel = _draft.category == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _draft
                      ..category = cat
                      ..zone = cat.shelfZone
                      ..dirty = true;
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
                  l.shelfZoneInline(l.data(_draft.zone)),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Progress + status (read-only) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: widget.item.progressRatio,
                backgroundColor: status.color.withValues(alpha: 0.12),
                color: status.color,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l.stockStatus(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status.color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  status == StockStatus.empty
                      ? l.usedUp
                      : l.daysRemainingLong(widget.item.daysRemaining),
                  style: TextStyle(fontSize: 13, color: status.color),
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
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [3, 5, 7, 14, 30].map((d) {
                final sel = _selectedDays == d;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDays = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.brand : AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l.days(d),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textChip,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.brand,
                inactiveTrackColor: AppColors.divider,
                thumbColor: AppColors.brand,
                overlayColor: AppColors.brand.withValues(alpha: 0.15),
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _selectedDays.toDouble().clamp(1, 60),
                min: 1,
                max: 60,
                divisions: 59,
                label: l.days(_selectedDays),
                onChanged: (v) => setState(() => _selectedDays = v.round()),
              ),
            ),
            const SizedBox(height: 8),
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
                  Navigator.pop(context);
                  widget.onRestock(_selectedDays);
                },
                child: Text(
                  l.resetTimer(_selectedDays),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brand, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onAddToList();
                },
                child: Text(
                  l.addToRestockList,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () {
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

  const _AddInventorySheet({required this.onAdd, required this.categories});

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
    widget.onAdd(InventoryItem(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: _category,
      shelfZone: _category.shelfZone,
      shelfCode: shelf.isEmpty ? null : shelf,
      quantityLabel: _qtyCtrl.text.trim(),
      purchasedAt: DateTime.now(),
      estimatedDays: _days,
    ));
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
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: l.productNameHint,
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
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  style: const TextStyle(fontSize: 15),
                  decoration: _fieldDecoration(l.quantityFieldLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _shelfCtrl,
                  style: const TextStyle(fontSize: 15),
                  decoration: _fieldDecoration(l.shelfCodeFieldLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l.categoryLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.categories.map((cat) {
              final sel = _category == cat;
              return GestureDetector(
                onTap: () => setState(() => _category = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          Text(
            l.estimatedUseDays,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [3, 5, 7, 14, 30].map((d) {
              final sel = _days == d;
              return GestureDetector(
                onTap: () => setState(() => _days = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.brand
                        : AppColors.fieldBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.days(d),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.textChip,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.brand,
              inactiveTrackColor: AppColors.divider,
              thumbColor: AppColors.brand,
              overlayColor: AppColors.brand.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _days.toDouble().clamp(1, 60),
              min: 1,
              max: 60,
              divisions: 59,
              label: l.days(_days),
              onChanged: (v) => setState(() => _days = v.round()),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.divider,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _nameCtrl.text.trim().isEmpty ? null : _submit,
              child: Text(
                l.addToInventoryBtn,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
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
