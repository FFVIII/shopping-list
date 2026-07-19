part of 'list_screen.dart';

// ── Smart mode state extension ────────────────────────────────────────────────

extension _SmartModeState on _ListScreenState {
  // Hides items mid-swipe-delete (undo toast still up) from every grouping.
  List<ShoppingItem> get _visibleSmartItems => widget.smartItems
      .where((i) => !_pendingDeleteIds.contains(i.id))
      .toList();

  Map<String, List<ShoppingItem>> _groupByShelf() {
    final map = <String, List<ShoppingItem>>{};
    final untagged = <ShoppingItem>[];
    for (final item in _visibleSmartItems) {
      final code = item.shelfCode?.trim();
      if (code != null && code.isNotEmpty) {
        map.putIfAbsent(code, () => []).add(item);
      } else {
        untagged.add(item);
      }
    }
    final order = widget.shelfCodeOrder;
    final sorted = Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) {
          int cmp;
          if (order.isNotEmpty) {
            final ai = order.indexOf(a.key);
            final bi = order.indexOf(b.key);
            if (ai >= 0 && bi >= 0) {
              cmp = ai.compareTo(bi);
            } else if (ai >= 0) {
              cmp = -1;
            } else if (bi >= 0) {
              cmp = 1;
            } else {
              cmp = a.key.compareTo(b.key);
            }
          } else {
            cmp = a.key.compareTo(b.key);
          }
          return _smartGroupDir == SortDir.asc ? cmp : -cmp;
        }),
    );
    // Untagged items always appear at the end regardless of direction.
    if (untagged.isNotEmpty) {
      sorted[L10n.of(context).untaggedShelf] = untagged;
    }
    return sorted;
  }

  Map<String, List<ShoppingItem>> _groupByCategory() {
    final map = <String, List<ShoppingItem>>{};
    for (final item in _visibleSmartItems) {
      map.putIfAbsent(item.category.name, () => []).add(item);
    }
    return Map.fromEntries(
      map.entries.toList()
        ..sort((a, b) => _smartGroupDir == SortDir.asc
            ? a.key.compareTo(b.key)
            : b.key.compareTo(a.key)),
    );
  }

  List<_FlatEntry> _buildFlatEntries(Map<String, List<ShoppingItem>> groups) {
    final entries = <_FlatEntry>[];
    for (final entry in groups.entries) {
      entries.add(_FlatEntry.header(entry.key));
      for (final item in entry.value) {
        entries.add(_FlatEntry.forItem(item, entry.key));
      }
    }
    return entries;
  }

  void _onSmartReorder(int oldIndex, int newIndex, List<_FlatEntry> flat) {
    if (flat[oldIndex].isHeader) return;
    HapticFeedback.lightImpact();
    final movedItem = flat[oldIndex].item!;

    final mutable = List<_FlatEntry>.from(flat);
    final moved = mutable.removeAt(oldIndex);
    mutable.insert(newIndex, moved);

    final orderedIds = mutable
        .where((e) => !e.isHeader)
        .map((e) => e.item!.id)
        .toList();

    if (_smartGroup == SmartGroupMode.manual) {
      // Manual mode: just reorder, no shelf/category change
      widget.onReorderSmart(movedItem.id, null, null, orderedIds, null);
    } else {
      String newGroup = '';
      for (int i = newIndex; i >= 0; i--) {
        if (mutable[i].isHeader) {
          newGroup = mutable[i].groupKey;
          break;
        }
      }
      if (newGroup.isEmpty) {
        for (final e in mutable) {
          if (e.isHeader) {
            newGroup = e.groupKey;
            break;
          }
        }
      }
      if (newGroup.isEmpty) return;

      if (_byShelf) {
        final l = L10n.of(context);
        final newCode = newGroup == l.untaggedShelf ? '' : newGroup;
        widget.onReorderSmart(movedItem.id, null, null, orderedIds, newCode);
      } else {
        final newCat = widget.categories.firstWhere(
          (c) => c.name == newGroup,
          orElse: () => movedItem.category,
        );
        widget.onReorderSmart(movedItem.id, null, newCat, orderedIds, null);
      }
    }
  }

  Widget _buildSmartList() {
    final groupCounts = <String, int>{};
    final groupColors = <String, Color>{};
    final List<_FlatEntry> flat;
    if (_smartGroup == SmartGroupMode.manual) {
      flat = _visibleSmartItems
          .map((item) => _FlatEntry.forItem(item, ''))
          .toList();
    } else {
      final groups = _byShelf ? _groupByShelf() : _groupByCategory();
      flat = _buildFlatEntries(groups);
      for (final e in groups.entries) {
        groupCounts[e.key] = e.value.length;
        groupColors[e.key] = e.value.first.category.color;
      }
    }

    final firstHeaderIndex = flat.indexWhere((e) => e.isHeader);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      buildDefaultDragHandles: false,
      itemCount: flat.length,
      itemBuilder: (ctx, i) {
        final entry = flat[i];
        if (entry.isHeader) {
          return _buildSectionHeader(
            entry.groupKey,
            groupCounts[entry.groupKey] ?? 0,
            color: groupColors[entry.groupKey],
            key: Key('h_${entry.groupKey}'),
            trailing: i == firstHeaderIndex ? _buildSummaryTrailing() : null,
          );
        }
        final item = entry.item!;
        final zoneColor = item.category.color;
        final isTutorialExampleItem =
            TutorialController.instance.isExampleItemName(item.name);
        final row = _SmartRow(
          key: isTutorialExampleItem ? null : Key('si_${item.id}'),
          item: item,
          zoneColor: zoneColor,
          showShelfCode: !_byShelf,
          onToggle: () {
            HapticFeedback.lightImpact();
            widget.onToggleSmart(item.id);
          },
          onDelete: () => _handleSwipeDelete(
              id: item.id,
              label: L10n.of(context).data(item.name),
              realDelete: () => widget.onDeleteSmart(item.id)),
          onLongPress: _smartBatchMode ? null : () => _enterSmartBatchWithItem(item.id),
          reorderIndex: i,
          batchMode: _smartBatchMode,
          selected: _smartSelected.contains(item.id),
          onSelect: () => _toggleSmartSelection(item.id),
          tripSelected: _tripSelected.contains(item.id),
          onTripToggle: () => _toggleTripSelection(item.id),
          onHandleTap: _smartBatchMode
              ? () => _toggleSmartSelection(item.id)
              : () => _enterSmartBatchWithItem(item.id),
        );
        return isTutorialExampleItem
            ? TutorialRectReporter(
                key: Key('si_${item.id}'),
                id: 'example_smart_item',
                child: row,
              )
            : row;
      },
      onReorderItem: (old, newIdx) => _onSmartReorder(old, newIdx, flat),
      proxyDecorator: (child, index, animation) => Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        shadowColor: Colors.black26,
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(String zone, int count,
      {Key? key, Color? color, Widget? trailing}) {
    final l = L10n.of(context);
    final color0 = color ?? AppColors.textMuted;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color0, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              l.data(zone),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color0.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l.itemCountChip(count),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color0,
              ),
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: trailing,
            ),
          ],
        ],
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
  final int reorderIndex;
  final bool batchMode;
  final bool selected;
  final VoidCallback? onSelect;
  final bool tripSelected;
  final VoidCallback? onTripToggle;
  final VoidCallback? onHandleTap;
  // The shelf code is redundant with the section header when grouped by
  // aisle — hide it there, but keep it when grouped by category (or
  // ungrouped), where it's the only indication of the item's shelf.
  final bool showShelfCode;

  const _SmartRow({
    super.key,
    required this.item,
    required this.zoneColor,
    required this.onToggle,
    required this.onDelete,
    this.onLongPress,
    required this.reorderIndex,
    this.batchMode = false,
    this.selected = false,
    this.onSelect,
    this.tripSelected = true,
    this.onTripToggle,
    this.onHandleTap,
    this.showShelfCode = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final qty = l.data(item.quantityLabel);
    final code = item.shelfCode != null ? l.data(item.shelfCode!) : null;
    final circleSelected = batchMode ? selected : tripSelected;
    final circleTap = batchMode ? onSelect : onTripToggle;

    return Dismissible(
      key: Key('smart_${item.id}'),
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
        child: Stack(
          children: [
            // Left color bar — positioned to fill the card height without IntrinsicHeight
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  color: zoneColor,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Row(
                children: [
                  // Circle selector (always visible)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: circleTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      child: _SelectCircle(selected: circleSelected),
                    ),
                  ),
                  // Content (tap to edit)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggle,
                      onLongPress: onLongPress,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l.data(item.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (qty.isNotEmpty) ...[
                                  QuantityBadge(qty: qty),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    l.days(item.estimatedDays ??
                                        item.category.defaultDays),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textDisabled,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (showShelfCode && code != null) ...[
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: zoneColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  code,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: zoneColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: reorderIndex,
                    child: const SizedBox(width: 12),
                  ),
                  DragHandle(index: reorderIndex, onTap: onHandleTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
