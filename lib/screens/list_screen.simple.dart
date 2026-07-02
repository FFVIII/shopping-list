part of 'list_screen.dart';

// ── Simple mode state extension ───────────────────────────────────────────────

extension _SimpleModeState on _ListScreenState {
  Widget _buildSimpleList() {
    final l = L10n.of(context);
    final pendingRaw = widget.simpleItems.where((i) => !i.checked).toList();
    final pending = _simpleDir != null
        ? ([...pendingRaw]..sort((a, b) => _simpleDir == SortDir.asc
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name)))
        : pendingRaw;
    final done = widget.simpleItems.where((i) => i.checked).toList();

    return CustomScrollView(
      slivers: [
        if (pending.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _simpleSectionHeader(
                label: l.pendingSection,
                count: pending.length,
                color: AppColors.textSecondary,
                chipBg: AppColors.fieldBg,
                topPad: 4,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverReorderableList(
            itemCount: pending.length,
            itemBuilder: (ctx, i) {
              final item = pending[i];
              return _SimpleRow(
                key: Key('p_${item.id}'),
                item: item,
                reorderIndex: i,
                onToggle: () => widget.onToggleSimple(item.id),
                onDelete: () => widget.onDeleteSimple(item.id),
                onLongPress: () => _showRenameSheet(item, false),
                showDragHandle: true,
              );
            },
            onReorderItem: (oldIdx, newIdx) {
              final newPending = [...pending];
              final moved = newPending.removeAt(oldIdx);
              newPending.insert(newIdx, moved);
              widget.onReorderSimple([
                ...newPending.map((i) => i.id),
                ...done.map((i) => i.id),
              ]);
              if (_simpleDir != null) setState(() => _simpleDir = null);
            },
            proxyDecorator: (child, index, animation) => Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black26,
              child: child,
            ),
          ),
        ),
        if (done.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _simpleSectionHeader(
                  icon: Icons.check_circle_outline_rounded,
                  label: l.purchasedSection,
                  count: done.length,
                  color: const Color(0xFFAAAAAA),
                  chipBg: const Color(0xFFF0F0EA),
                  topPad: 18,
                ),
                ...done.map((item) => _SimpleRow(
                      item: item,
                      onToggle: () => widget.onToggleSimple(item.id),
                      onDelete: () => widget.onDeleteSimple(item.id),
                      onLongPress: () => _showRenameSheet(item, false),
                    )),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _simpleSectionHeader({
    IconData? icon,
    required String label,
    required int count,
    required Color color,
    required Color chipBg,
    required double topPad,
  }) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, topPad, 4, 6),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 14, color: color),
          ],
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l.itemCountChip(count),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                  onTap: onToggle,
                  onLongPress: onLongPress,
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
                            decoration:
                                item.checked ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textDisabled,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showDragHandle && !item.checked && reorderIndex != null) ...[
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: const SizedBox(width: 12, height: 44),
                ),
                DragHandle(index: reorderIndex!),
              ],
            ],
          ),
        ),
    );
  }
}
