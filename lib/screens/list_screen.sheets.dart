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

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    // The item list can be arbitrarily long, so it gets its own height cap
    // (unlike the app's other, few-field sheets) — otherwise its content
    // grows past the screen and the header gets pushed off the top instead
    // of the list becoming scrollable. Only the item list itself is capped +
    // scrollable (as a shrink-wrapped ListView); the header and Save button
    // are plain Column children so they always stay fully visible.
    final listMaxHeight = MediaQuery.of(context).size.height * 0.5;
    return SafeArea(
      child: Padding(
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
              l.addToInventoryButton,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l.tripInventoryHint,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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
                                  fontSize: 13, color: AppColors.textMuted),
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
                      borderRadius: BorderRadius.circular(14)),
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

// ── Smart Add Sheet ───────────────────────────────────────────────────────────

class _SmartAddSheet extends StatefulWidget {
  final String name;
  final List<Category> categories;
  final List<String> shelfCodeOrder;
  final void Function(Category category, String zone, String quantityLabel, String? shelfCode, int estimatedDays) onConfirm;
  final Category Function(
      String name, Color color, String shelfZone, int defaultDays)
      onAddCategory;
  final void Function(String id) onDeleteCategory;

  const _SmartAddSheet({
    required this.name,
    required this.categories,
    required this.shelfCodeOrder,
    required this.onConfirm,
    required this.onAddCategory,
    required this.onDeleteCategory,
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
                        // Skip autofocus while the tutorial is running: the
                        // user should follow the tutorial's prescribed
                        // sequence rather than jump ahead into a field the
                        // current step hasn't pointed at yet.
                        autofocus:
                            TutorialController.instance.step == TutorialStep.done,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 10,
                        style: const TextStyle(fontSize: 15),
                        decoration: _fieldDecoration('1').copyWith(
                            counterStyle: const TextStyle(
                                fontSize: 10, color: AppColors.textDisabled)),
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
                        maxLength: 20,
                        style: const TextStyle(fontSize: 15),
                        decoration: _fieldDecoration(l.shelfCodeFieldHint).copyWith(
                            counterStyle: const TextStyle(
                                fontSize: 10, color: AppColors.textDisabled),
                            suffixIcon: widget.shelfCodeOrder.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.list_alt_rounded,
                                        size: 20,
                                        color: AppColors.textSecondary),
                                    onPressed: () async {
                                      final picked = await pickShelfCode(
                                          context, widget.shelfCodeOrder);
                                      if (picked != null) {
                                        setState(() => _shelfCtrl.text = picked);
                                      }
                                    },
                                  )),
                      ),
                    ],
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
            const SizedBox(height: 6),
            CategoryChipPicker(
              categories: widget.categories,
              selected: _selectedCategory,
              onAddCategory: widget.onAddCategory,
              onDeleteCategory: widget.onDeleteCategory,
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
                      borderRadius: BorderRadius.circular(14)),
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
  final Category Function(
      String name, Color color, String shelfZone, int defaultDays)
      onAddCategory;
  final void Function(String id) onDeleteCategory;
  final List<String> shelfCodeOrder;

  const _EditSmartSheet({
    required this.item,
    required this.categories,
    required this.onConfirm,
    required this.onAddCategory,
    required this.onDeleteCategory,
    required this.shelfCodeOrder,
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
    _category = widget.item.category;
    _zone = widget.item.shelfZone;
  }

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
    super.dispose();
  }

  void _confirm() {
    final typedName = _nameCtrl.text.trim();
    if (typedName.isEmpty) return;
    final name = resolveCanonicalEdit(typedName, _nameDisplay, widget.item.name);
    final typedShelf = _shelfCtrl.text.trim();
    final shelf = resolveCanonicalEdit(
        typedShelf, _shelfDisplay, widget.item.shelfCode ?? '');
    final qty = resolveCanonicalEdit(
        _qtyCtrl.text.trim(), _qtyDisplay, widget.item.quantityLabel);
    Navigator.pop(context);
    widget.onConfirm(
      name,
      qty,
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
              maxLength: 30,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration('').copyWith(
                  counterStyle: const TextStyle(
                      fontSize: 10, color: AppColors.textDisabled)),
              onSubmitted: (_) => _confirm(),
            ),
            _label(l.quantityFieldLabel),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration('1').copyWith(
                  counterStyle: const TextStyle(
                      fontSize: 10, color: AppColors.textDisabled)),
            ),
            _label(l.shelfCodeFieldLabel),
            TextField(
              controller: _shelfCtrl,
              maxLength: 20,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration('').copyWith(
                  counterStyle: const TextStyle(
                      fontSize: 10, color: AppColors.textDisabled),
                  suffixIcon: widget.shelfCodeOrder.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.list_alt_rounded,
                              size: 20, color: AppColors.textSecondary),
                          onPressed: () async {
                            final picked = await pickShelfCode(
                                context, widget.shelfCodeOrder);
                            if (picked != null) {
                              setState(() => _shelfCtrl.text = picked);
                            }
                          },
                        )),
            ),
            _label(l.categoryLabel),
            CategoryChipPicker(
              categories: widget.categories,
              selected: _category,
              onAddCategory: widget.onAddCategory,
              onDeleteCategory: widget.onDeleteCategory,
              onSelect: (cat) => setState(() {
                _category = cat;
                _zone = cat.shelfZone;
              }),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _confirm,
              child: Text(
                l.confirmEdit,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
