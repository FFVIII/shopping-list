part of 'inventory_screen.dart';

// ── Add Inventory Sheet ────────────────────────────────────────────────────────

class _AddInventorySheet extends StatefulWidget {
  final void Function(InventoryItem) onAdd;
  final List<Category> categories;
  final List<String> shelfCodeOrder;
  final Category Function(
      String name, Color color, String shelfZone, int defaultDays)
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
    widget.onAdd(InventoryItem(
      id: generateId('inv'),
      name: name,
      category: _category,
      shelfZone: _category.shelfZone,
      shelfCode: shelf.isEmpty ? null : shelf,
      quantityLabel: _qtyCtrl.text.trim(),
      purchasedAt: DateTime.now(),
      estimatedDays: _days,
    ));
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
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
                              icon: const Icon(Icons.list_alt_rounded,
                                  size: 20, color: AppColors.textSecondary),
                              onPressed: () async {
                                final picked = await pickShelfCode(
                                    iconContext, widget.shelfCodeOrder);
                                if (picked != null) {
                                  setState(() => _shelfCtrl.text = picked);
                                }
                              },
                            ),
                          )),
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
                  borderRadius: BorderRadius.circular(14)),
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
