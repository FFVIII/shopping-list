part of 'list_screen.dart';

// ── Complete Trip Sheet ───────────────────────────────────────────────────────

class _CompleteTripSheet extends StatefulWidget {
  final List<ShoppingItem> items;
  final Set<String> initialSelected;
  final void Function(List<String>) onConfirm;

  const _CompleteTripSheet({
    required this.items,
    required this.initialSelected,
    required this.onConfirm,
  });

  @override
  State<_CompleteTripSheet> createState() => _CompleteTripSheetState();
}

class _CompleteTripSheetState extends State<_CompleteTripSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  // Title + hint + spacing + button — everything in the Column besides the
  // item list itself. Used to size the list so the Column's total height
  // never exceeds what the sheet actually has available (which shrinks
  // when the keyboard is up, or on shorter screens) — a static fraction of
  // the full screen height ignored both of those and could overflow.
  static const _reservedHeight = 170.0;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The item list can be arbitrarily long, so it gets its own
            // height cap (unlike the app's other, few-field sheets) —
            // otherwise its content grows past the screen and the header
            // gets pushed off the top instead of the list becoming
            // scrollable. Only the item list itself is capped + scrollable
            // (as a shrink-wrapped ListView); the header and Save button
            // are plain Column children so they always stay fully visible.
            final listMaxHeight = constraints.hasBoundedHeight
                ? (constraints.maxHeight - _reservedHeight).clamp(
                    80.0,
                    double.infinity,
                  )
                : MediaQuery.of(context).size.height * 0.5;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.addToInventoryButton,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.tripInventoryHint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: listMaxHeight),
                  child: ListView(
                    shrinkWrap: true,
                    children: widget.items.map((item) {
                      final sel = _selected.contains(item.id);
                      final qty = item.quantityLabel;
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) {
                            _selected.remove(item.id);
                          } else {
                            _selected.add(item.id);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              _SelectCircle(selected: sel),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l.data(item.name),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: sel
                                        ? AppColors.textPrimary
                                        : AppColors.textDisabled,
                                  ),
                                ),
                              ),
                              if (qty.isNotEmpty)
                                Text(
                                  l.data(qty),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                TutorialTarget(
                  id: 'confirm_trip_button',
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onConfirm(_selected.toList());
                    },
                    child: Text(
                      l.addToInventoryButton,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Smart Add Sheet ───────────────────────────────────────────────────────────

class _SmartAddSheet extends StatefulWidget {
  final String name;
  final List<Category> categories;
  final List<String> shelfCodeOrder;
  final void Function(
    Category category,
    String zone,
    String quantityLabel,
    String? shelfCode,
    int estimatedDays,
    double? unitPrice,
  )
  onConfirm;
  final Category Function(
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  )
  onAddCategory;

  const _SmartAddSheet({
    required this.name,
    required this.categories,
    required this.shelfCodeOrder,
    required this.onConfirm,
    required this.onAddCategory,
  });

  @override
  State<_SmartAddSheet> createState() => _SmartAddSheetState();
}

class _SmartAddSheetState extends State<_SmartAddSheet> {
  late Category _selectedCategory;
  late String _selectedZone;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _shelfCtrl;
  late int _days;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.first;
    _selectedZone = _selectedCategory.shelfZone;
    _days = _selectedCategory.defaultDays;
    _qtyCtrl = TextEditingController();
    _shelfCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final daysParts = l.estimatedDaysSelected(_days).split(RegExp(r'\d+'));
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
              l.quantityFieldLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyCtrl,
              // Skip autofocus while the tutorial is running: the user
              // should follow the tutorial's prescribed sequence rather
              // than jump ahead into a field the current step hasn't
              // pointed at yet.
              autofocus: TutorialController.instance.step == TutorialStep.done,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              style: const TextStyle(fontSize: 15),
              decoration: fieldDecoration('1'),
            ),
            const SizedBox(height: 14),
            Text(
              l.shelfCodeFieldLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _shelfCtrl,
              maxLength: 20,
              style: const TextStyle(fontSize: 15),
              decoration: fieldDecoration(l.shelfCodeFieldHint).copyWith(
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
            const SizedBox(height: 14),
            Text(
              l.categoryLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            CategoryChipPicker(
              categories: widget.categories,
              selected: _selectedCategory,
              onAddCategory: widget.onAddCategory,
              onSelect: (cat) => setState(() {
                _selectedCategory = cat;
                _selectedZone = cat.shelfZone;
                _days = cat.defaultDays;
              }),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(text: daysParts[0]),
                    TextSpan(
                      text: '$_days',
                      style: const TextStyle(color: AppColors.brand),
                    ),
                    TextSpan(text: daysParts[1]),
                  ],
                ),
              ),
            ),
            DaysSelector(
              initialDays: _days,
              onChanged: (d) => setState(() => _days = d),
            ),
            const SizedBox(height: 12),
            TutorialTarget(
              id: 'confirm_add_button',
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () {
                  final shelf = _shelfCtrl.text.trim();
                  Navigator.pop(context);
                  widget.onConfirm(
                    _selectedCategory,
                    _selectedZone,
                    _qtyCtrl.text.trim(),
                    shelf.isEmpty ? null : shelf,
                    _days,
                    null,
                  );
                },
                child: Text(
                  l.addToList,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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
    double? unitPrice,
  )
  onConfirm;
  final Category Function(
    String name,
    Color color,
    String shelfZone,
    int defaultDays,
  )
  onAddCategory;
  final List<String> shelfCodeOrder;

  const _EditSmartSheet({
    required this.item,
    required this.categories,
    required this.onConfirm,
    required this.onAddCategory,
    required this.shelfCodeOrder,
  });

  @override
  State<_EditSmartSheet> createState() => _EditSmartSheetState();
}

class _EditSmartSheetState extends State<_EditSmartSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _shelfCtrl;
  late final TextEditingController _priceCtrl;
  late Category _category;
  late String _zone;

  // See lib/l10n/canonical_edit.dart: seeded items store canonical Chinese
  // text, so the fields are pre-filled with the translated display text and
  // resolved back to the raw value on submit if left untouched.
  bool _textsInitialized = false;
  late String _nameDisplay;
  late String _qtyDisplay;
  late String _shelfDisplay;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _qtyCtrl = TextEditingController();
    _shelfCtrl = TextEditingController();
    _priceCtrl = TextEditingController(
      text: widget.item.unitPrice == null
          ? ''
          : _trimNum(widget.item.unitPrice!),
    );
    _category = widget.item.category;
    _zone = widget.item.shelfZone;
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_textsInitialized) {
      final l = L10n.of(context);
      _nameDisplay = canonicalDisplay(l, widget.item.name);
      _qtyDisplay = canonicalDisplay(l, widget.item.quantityLabel);
      _shelfDisplay = canonicalDisplay(l, widget.item.shelfCode ?? '');
      _nameCtrl.text = _nameDisplay;
      _qtyCtrl.text = _qtyDisplay;
      _shelfCtrl.text = _shelfDisplay;
      _textsInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final typedName = _nameCtrl.text.trim();
    if (typedName.isEmpty) return;
    final name = resolveCanonicalEdit(
      typedName,
      _nameDisplay,
      widget.item.name,
    );
    final typedShelf = _shelfCtrl.text.trim();
    final shelf = resolveCanonicalEdit(
      typedShelf,
      _shelfDisplay,
      widget.item.shelfCode ?? '',
    );
    final qty = resolveCanonicalEdit(
      _qtyCtrl.text.trim(),
      _qtyDisplay,
      widget.item.quantityLabel,
    );
    final price = double.tryParse(_priceCtrl.text.trim());
    Navigator.pop(context);
    widget.onConfirm(
      name,
      qty,
      shelf.isEmpty ? null : shelf,
      _category,
      _zone,
      price,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.editItem,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: CategoryPickerField(
                      categories: widget.categories,
                      selected: _category,
                      onAddCategory: widget.onAddCategory,
                      onChanged: (cat) => setState(() {
                        _category = cat;
                        _zone = cat.shelfZone;
                      }),
                    ),
                  ),
                ),
              ],
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
                      _label(l.productNameHint),
                      TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        maxLength: 30,
                        style: const TextStyle(fontSize: 15),
                        decoration: fieldDecoration(''),
                        onSubmitted: (_) => _confirm(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(l.quantityFieldLabel),
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 10,
                        style: const TextStyle(fontSize: 15),
                        decoration: fieldDecoration('1'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // ── Shelf code + Price row ────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(l.shelfCodeFieldLabel),
                      TextField(
                        controller: _shelfCtrl,
                        maxLength: 20,
                        style: const TextStyle(fontSize: 15),
                        decoration: fieldDecoration('').copyWith(
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
                                        setState(
                                          () => _shelfCtrl.text = picked,
                                        );
                                      }
                                    },
                                  ),
                                ),
                        ),
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
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*$'),
                          ),
                        ],
                        maxLength: 8,
                        style: const TextStyle(fontSize: 15),
                        decoration: fieldDecoration(l.currencySymbol),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _confirm,
              child: Text(
                l.confirmEdit,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
