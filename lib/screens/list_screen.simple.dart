part of 'list_screen.dart';

// ── Simple mode state extension ───────────────────────────────────────────────

extension _SimpleModeState on _ListScreenState {
  Widget _buildSimpleList() {
    final l = L10n.of(context);
    final visible =
        widget.simpleItems.where((i) => !_pendingDeleteIds.contains(i.id));
    final pendingRaw = visible.where((i) => !i.checked).toList();
    final pending = _simpleDir != null
        ? ([...pendingRaw]..sort((a, b) => _simpleDir == SortDir.asc
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name)))
        : pendingRaw;
    final done = visible.where((i) => i.checked).toList();

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
                trailing: _buildSummaryTrailing(),
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
                onToggle: () {
                  HapticFeedback.lightImpact();
                  widget.onToggleSimple(item.id);
                },
                onDelete: () => _handleSwipeDelete(id: item.id, label: l.data(item.name), realDelete: () => widget.onDeleteSimple(item.id)),
                onLongPress: () => _showRenameSheet(item, false),
                showDragHandle: true,
                batchMode: _simpleBatchMode,
                selected: _simpleSelected.contains(item.id),
                onSelect: () => _toggleSimpleSelection(item.id),
                onHandleTap: _simpleBatchMode
                    ? () => _toggleSimpleSelection(item.id)
                    : () => _enterSimpleBatchWithItem(item.id),
              );
            },
            onReorderItem: (oldIdx, newIdx) {
              HapticFeedback.lightImpact();
              final newPending = [...pending];
              final moved = newPending.removeAt(oldIdx);
              newPending.insert(newIdx, moved);
              widget.onReorderSimple([
                ...newPending.map((i) => i.id),
                ...done.map((i) => i.id),
              ]);
              // False positive: this extension method runs on the real
              // _ListScreenState instance, but the analyzer doesn't treat
              // extension bodies as members of the extended class.
              // ignore: invalid_use_of_protected_member
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
                  trailing: pending.isEmpty ? _buildSummaryTrailing() : null,
                ),
                ...done.map((item) => _SimpleRow(
                      key: Key('d_${item.id}'),
                      item: item,
                      onToggle: () {
                  HapticFeedback.lightImpact();
                  widget.onToggleSimple(item.id);
                },
                      onDelete: () => _handleSwipeDelete(id: item.id, label: l.data(item.name), realDelete: () => widget.onDeleteSimple(item.id)),
                      onLongPress: () => _showRenameSheet(item, false),
                      batchMode: _simpleBatchMode,
                      selected: _simpleSelected.contains(item.id),
                      onSelect: () => _toggleSimpleSelection(item.id),
                      onHandleTap: _simpleBatchMode
                          ? () => _toggleSimpleSelection(item.id)
                          : () => _enterSimpleBatchWithItem(item.id),
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
    Widget? trailing,
  }) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, topPad, 4, 6),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
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
          if (trailing != null) ...[
            const Spacer(),
            Flexible(child: trailing),
          ],
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
  final bool batchMode;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onHandleTap;

  const _SimpleRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
    this.onLongPress,
    this.showDragHandle = false,
    this.reorderIndex,
    this.batchMode = false,
    this.selected = false,
    this.onSelect,
    this.onHandleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('simple_${item.id}'),
      direction: batchMode ? DismissDirection.none : DismissDirection.endToStart,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                  onTap: batchMode ? onSelect : onToggle,
                  onLongPress: batchMode ? null : onLongPress,
                  child: Row(
                    children: [
                      if (batchMode) ...[
                        _SelectCircle(selected: selected),
                        const SizedBox(width: 14),
                      ] else ...[
                        _Checkbox(checked: item.checked),
                        const SizedBox(width: 14),
                      ],
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
                DragHandle(index: reorderIndex, onTap: onHandleTap),
              ] else if (onHandleTap != null)
                DragHandle(onTap: onHandleTap),
            ],
          ),
        ),
    );
  }
}
