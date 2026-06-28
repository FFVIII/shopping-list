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
        kShelfZones[item.shelfZone]?.dotColor ?? item.category.color;
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

// ── Edit Inventory Sheet (name + quantity + shelf code + category) ───────────

class _EditInventorySheet extends StatefulWidget {
  final InventoryItem item;
  final String Function(Category) zoneFor;
  final void Function(
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) onConfirm;

  const _EditInventorySheet({
    required this.item,
    required this.zoneFor,
    required this.onConfirm,
  });

  @override
  State<_EditInventorySheet> createState() => _EditInventorySheetState();
}

class _EditInventorySheetState extends State<_EditInventorySheet> {
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
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              decoration: _dec(l.productNameHint),
              onSubmitted: (_) => _confirm(),
            ),
            _label(l.quantityFieldLabel),
            TextField(
              controller: _qtyCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: _dec(l.quantityFieldLabel),
            ),
            _label(l.shelfCodeFieldLabel),
            TextField(
              controller: _shelfCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: _dec(l.shelfCodeFieldLabel),
            ),
            _label(l.categoryLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Category.values.map((cat) {
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _category = cat;
                    _zone = widget.zoneFor(cat);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? cat.color : cat.bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l.category(cat),
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

// ── Add Inventory Sheet ────────────────────────────────────────────────────────

class _AddInventorySheet extends StatefulWidget {
  final void Function(InventoryItem) onAdd;
  final String Function(Category) zoneFor;

  const _AddInventorySheet({required this.onAdd, required this.zoneFor});

  @override
  State<_AddInventorySheet> createState() => _AddInventorySheetState();
}

class _AddInventorySheetState extends State<_AddInventorySheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _shelfCtrl = TextEditingController();
  Category _category = Category.produce;
  int _days = 7;

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
      shelfZone: widget.zoneFor(_category),
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
            children: Category.values.map((cat) {
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
                    l.category(cat),
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
