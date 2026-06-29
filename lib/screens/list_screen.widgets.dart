part of 'list_screen.dart';

// ── Flat list entry for smart-mode drag ──────────────────────────────────────

class _FlatEntry {
  final String groupKey;
  final ShoppingItem? item;
  _FlatEntry.header(this.groupKey) : item = null;
  _FlatEntry.forItem(this.item, this.groupKey);
  bool get isHeader => item == null;
}

// ── Simple Row ────────────────────────────────────────────────────────────────

class _SimpleRow extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool showDragHandle;
  final int? reorderIndex;

  const _SimpleRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
    this.onLongPress,
    this.showDragHandle = false,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('simple_${item.id}'),
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
        onTap: onToggle,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 15),
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
          child: Row(
            children: [
              _Checkbox(checked: item.checked),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: item.checked
                        ? AppColors.textDisabled
                        : AppColors.textPrimary,
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: AppColors.textDisabled,
                  ),
                ),
              ),
              if (showDragHandle && !item.checked && reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.drag_handle_rounded,
                        size: 20, color: AppColors.border),
                  ),
                ),
            ],
          ),
        ),
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

  const _SmartRow({
    super.key,
    required this.item,
    required this.zoneColor,
    required this.onToggle,
    required this.onDelete,
    this.onLongPress,
    this.showDragHandle = false,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Dismissible(
      key: Key('smart_${item.id}'),
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
        onTap: onToggle,
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 15),
                  child: _Checkbox(checked: item.checked),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l.data(item.name),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: item.checked
                                ? AppColors.textDisabled
                                : AppColors.textPrimary,
                            decoration: item.checked
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.textDisabled,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.itemMeta(
                              l.data(item.quantityLabel),
                              item.shelfCode != null
                                  ? l.data(item.shelfCode!)
                                  : null),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                if (item.addedToInventory)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
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
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.drag_handle_rounded,
                          size: 20, color: AppColors.border),
                    ),
                  ),
                // Right color bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: item.checked
                        ? const Color(0xFFE8E8E8)
                        : zoneColor,
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(14)),
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

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Checkbox extends StatelessWidget {
  final bool checked;
  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            checked ? AppColors.brand : Colors.transparent,
        border: checked
            ? null
            : Border.all(
                color: AppColors.border, width: 1.5),
      ),
      child: checked
          ? const Icon(Icons.check_rounded,
              color: Colors.white, size: 15)
          : null,
    );
  }
}

// ── Mic Button ────────────────────────────────────────────────────────────────

class _MicButton extends StatefulWidget {
  final bool isListening;
  final bool available;
  final VoidCallback onTap;

  const _MicButton({
    required this.isListening,
    required this.available,
    required this.onTap,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isListening) {
      return GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                AppColors.danger,
                const Color(0xFFEF9A9A),
                _pulse.value,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger
                      .withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded,
                size: 22, color: Colors.white),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.available ? widget.onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.mic_none_rounded,
          size: 22,
          color: widget.available
              ? AppColors.brand
              : AppColors.border,
        ),
      ),
    );
  }
}

class _SegmentBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentBtn(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: selected
                  ? AppColors.textPrimary
                  : const Color(0xFF8A8A8A),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rename Sheet ──────────────────────────────────────────────────────────────

class _RenameSheet extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onConfirm;

  const _RenameSheet({required this.initialName, required this.onConfirm});

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    widget.onConfirm(name);
  }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.rename,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
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
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 14),
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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit Smart Item Sheet (name + quantity + shelf code + category) ──────────

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

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
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
  }

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

class _TextToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TextToggleBtn(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? AppColors.brand
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Budget Row (记账) ──────────────────────────────────────────────────────────

class _BudgetRow extends StatelessWidget {
  final BudgetItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BudgetRow({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Dismissible(
      key: Key('budget_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 6),
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
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.data(item.name),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.quantity} × ${l.money(item.unitPrice)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l.money(item.lineTotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Budget Sheet (add / edit 记账) ─────────────────────────────────────────────

class _BudgetSheet extends StatefulWidget {
  final BudgetItem? item;
  final String initialName;
  final void Function(String name, int quantity, double unitPrice) onConfirm;

  const _BudgetSheet({
    this.item,
    this.initialName = '',
    required this.onConfirm,
  });

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.item?.name ?? widget.initialName);
    _qtyCtrl =
        TextEditingController(text: '${widget.item?.quantity ?? 1}');
    _priceCtrl = TextEditingController(
        text: widget.item == null
            ? ''
            : _trimNum(widget.item!.unitPrice));
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  int get _qty {
    final n = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    return n < 1 ? 1 : n;
  }

  double get _price => double.tryParse(_priceCtrl.text.trim()) ?? 0;

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    widget.onConfirm(name, _qty, _price);
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
              widget.item == null ? l.addBudgetTitle : l.editBudgetTitle,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(l.quantityFieldLabel),
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 15),
                        decoration: _dec('1'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(l.unitPriceFieldLabel),
                      TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(fontSize: 15),
                        decoration: _dec(l.currencySymbol),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  l.budgetTotalLabel,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
                Text(
                  l.money(_qty * _price),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                  l.save,
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
