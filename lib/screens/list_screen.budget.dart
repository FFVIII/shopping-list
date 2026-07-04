part of 'list_screen.dart';

// ── Budget mode state extension ───────────────────────────────────────────────

extension _BudgetModeState on _ListScreenState {
  void _showBudgetSheet({BudgetItem? item, String initialName = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BudgetSheet(
        item: item,
        initialName: initialName,
        onConfirm: (name, qty, price) {
          if (item != null) {
            widget.onEditBudget(item.id, name, qty, price);
          } else {
            widget.onAddBudget(name, qty, price);
          }
        },
      ),
    );
  }

  Widget _buildBudgetList() {
    final visible = widget.budgetItems
        .where((i) => !_pendingDeleteIds.contains(i.id))
        .toList();
    final sorted = _budgetSort != BudgetSortMode.manual
        ? ([...visible]..sort((a, b) {
            final cmp = _budgetSort == BudgetSortMode.name
                ? a.name.compareTo(b.name)
                : a.lineTotal.compareTo(b.lineTotal);
            return _budgetDir == SortDir.asc ? cmp : -cmp;
          }))
        : visible;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      buildDefaultDragHandles: false,
      onReorderItem: (oldIdx, newIdx) {
        final newSorted = [...sorted];
        final moved = newSorted.removeAt(oldIdx);
        newSorted.insert(newIdx, moved);
        widget.onReorderBudget(newSorted.map((i) => i.id).toList());
        if (_budgetSort != BudgetSortMode.manual) {
          // False positive: this extension method runs on the real
          // _ListScreenState instance, but the analyzer doesn't treat
          // extension bodies as members of the extended class.
          // ignore: invalid_use_of_protected_member
          setState(() => _budgetSort = BudgetSortMode.manual);
        }
      },
      proxyDecorator: (child, index, animation) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        shadowColor: Colors.black26,
        child: child,
      ),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final item = sorted[i];
        return _BudgetRow(
          key: Key('budget_${item.id}'),
          item: item,
          reorderIndex: i,
          batchMode: _budgetBatchMode,
          selected: _budgetSelected.contains(item.id),
          onTap: () => _budgetBatchMode
              ? _toggleBudgetSelection(item.id)
              : _showBudgetSheet(item: item),
          onDelete: () => _handleSwipeDelete(
              id: item.id,
              label: L10n.of(context).data(item.name),
              realDelete: () => widget.onDeleteBudget(item.id)),
          onHandleTap: () => _budgetBatchMode
              ? _toggleBudgetSelection(item.id)
              : _enterBudgetBatchWithItem(item.id),
        );
      },
    );
  }

  Widget _buildBudgetTotalBar() {
    final l = L10n.of(context);
    final total =
        widget.budgetItems.fold<double>(0, (s, i) => s + i.lineTotal);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            l.budgetTotalLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            l.budgetCount(widget.budgetItems.length),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l.money(total),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetEmptyState() {
    final l = L10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 56, color: Color(0xFFD8D8D3)),
          const SizedBox(height: 16),
          Text(
            l.budgetEmptyTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.budgetEmptySubtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

// ── Budget Row ────────────────────────────────────────────────────────────────

class _BudgetRow extends StatelessWidget {
  final BudgetItem item;
  final int reorderIndex;
  final bool batchMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onHandleTap;

  const _BudgetRow({
    super.key,
    required this.item,
    required this.reorderIndex,
    required this.batchMode,
    required this.selected,
    required this.onTap,
    required this.onDelete,
    required this.onHandleTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Dismissible(
      key: Key('budget_dismiss_${item.id}'),
      direction:
          batchMode ? DismissDirection.none : DismissDirection.endToStart,
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
      child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 2)),
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
                      if (batchMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _SelectCircle(selected: selected),
                        ),
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
                    ],
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: reorderIndex,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    l.money(item.lineTotal),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              DragHandle(index: reorderIndex, onTap: onHandleTap),
            ],
          ),
        ),
    );
  }
}

// ── Budget Sheet (add / edit) ─────────────────────────────────────────────────

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
        text: widget.item == null ? '' : _trimNum(widget.item!.unitPrice));
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

  // When a name is already provided (typed in the add bar, or editing an
  // existing item), focus the quantity field instead of re-focusing the name —
  // otherwise opening the sheet yanks the keyboard back onto the name the user
  // just entered.
  bool get _namePrefilled =>
      (widget.item?.name ?? widget.initialName).trim().isNotEmpty;

  int get _qty {
    final n = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    return n < 1 ? 1 : n;
  }

  double get _price => double.tryParse(_priceCtrl.text.trim()) ?? 0;

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showAppToast(context, L10n.of(context).addItemNameRequired);
      return;
    }
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
              autofocus: !_namePrefilled,
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
                        autofocus: _namePrefilled,
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
