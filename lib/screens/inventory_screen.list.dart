part of 'inventory_screen.dart';

// Extension methods live outside the State subclass, so calls to the
// protected setState() would otherwise trip invalid_use_of_protected_member.
// ignore_for_file: invalid_use_of_protected_member

// ── Inventory list rendering + reorder (flat / grouped / batch bar) ──────────

extension _InvListBuilders on _InventoryScreenState {
  // Flat, value-sorted list (no headers, no drag). Used when a value sort
  // overlay is active.
  Widget _buildSortedFlatList() {
    final items = _sortedFlat;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return _InventoryCard(
          key: Key('invs_${item.id}'),
          item: item,
          thresholdDays: widget.thresholdDays,
          onTap: _batchMode
              ? () => setState(() {
                    if (_selected.contains(item.id)) {
                      _selected.remove(item.id);
                    } else {
                      _selected.add(item.id);
                    }
                  })
              : () => _showDetailSheet(item),
          onDelete: () => _handleSwipeDelete(item),
          batchMode: _batchMode,
          selected: _selected.contains(item.id),
          onHandleTap: () => setState(() {
            if (_batchMode) {
              if (_selected.contains(item.id)) {
                _selected.remove(item.id);
              } else {
                _selected.add(item.id);
              }
            } else {
              _batchMode = true;
              _selected.add(item.id);
            }
          }),
        );
      },
    );
  }

  Widget _buildGroupedList() {
    final groups = _grouped;
    final firstKey = groups.keys.firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        for (final entry in groups.entries) ...[
          _buildSectionHeader(entry.key, entry.value.length,
              color: _byCategory ? null : entry.value.first.category.color,
              trailing: entry.key == firstKey
                  ? _buildInventorySummaryTrailing()
                  : null),
          ...entry.value.map((item) => _InventoryCard(
                item: item,
                thresholdDays: widget.thresholdDays,
                onTap: _batchMode
                    ? () => setState(() {
                          if (_selected.contains(item.id)) {
                            _selected.remove(item.id);
                          } else {
                            _selected.add(item.id);
                          }
                        })
                    : () => _showDetailSheet(item),
                onDelete: () => _handleSwipeDelete(item),
                batchMode: _batchMode,
                selected: _selected.contains(item.id),
                onHandleTap: () => setState(() {
                  if (_batchMode) {
                    if (_selected.contains(item.id)) {
                      _selected.remove(item.id);
                    } else {
                      _selected.add(item.id);
                    }
                  } else {
                    _batchMode = true;
                    _selected.add(item.id);
                  }
                }),
              )),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  // Drag-to-reorder list (used when not searching). Items can be dragged
  // within a group or into another group — updating category (by type) or
  // shelf code (by aisle) accordingly.
  Widget _buildReorderableGroupedList() {
    final groups = _grouped;
    final flat = <_InvEntry>[];
    for (final entry in groups.entries) {
      flat.add(_InvEntry.header(entry.key));
      for (final item in entry.value) {
        flat.add(_InvEntry.forItem(item, entry.key));
      }
    }
    final groupCounts = {
      for (final e in groups.entries) e.key: e.value.length
    };
    final groupColors = {
      for (final e in groups.entries)
        if (!_byCategory) e.key: e.value.first.category.color
    };

    final firstHeaderIndex = flat.indexWhere((e) => e.isHeader);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      buildDefaultDragHandles: false,
      itemCount: flat.length,
      itemBuilder: (ctx, i) {
        final entry = flat[i];
        if (entry.isHeader) {
          return _buildSectionHeader(
            entry.groupKey,
            groupCounts[entry.groupKey] ?? 0,
            color: groupColors[entry.groupKey],
            key: Key('invh_${entry.groupKey}'),
            trailing:
                i == firstHeaderIndex ? _buildInventorySummaryTrailing() : null,
          );
        }
        final item = entry.item!;
        return _InventoryCard(
          key: Key('invc_${item.id}'),
          item: item,
          thresholdDays: widget.thresholdDays,
          onTap: _batchMode
              ? () => setState(() {
                    if (_selected.contains(item.id)) {
                      _selected.remove(item.id);
                    } else {
                      _selected.add(item.id);
                    }
                  })
              : () => _showDetailSheet(item),
          onDelete: () => _handleSwipeDelete(item),
          reorderIndex: i,
          batchMode: _batchMode,
          selected: _selected.contains(item.id),
          onHandleTap: () => setState(() {
            if (_batchMode) {
              if (_selected.contains(item.id)) {
                _selected.remove(item.id);
              } else {
                _selected.add(item.id);
              }
            } else {
              _batchMode = true;
              _selected.add(item.id);
            }
          }),
        );
      },
      onReorderItem: (oldIndex, newIndex) =>
          _onInvReorder(oldIndex, newIndex, flat),
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        shadowColor: Colors.black26,
        child: child,
      ),
    );
  }

  Widget _buildBatchBar() {
    final l = L10n.of(context);
    final allIds = widget.items.map((i) => i.id).toSet();
    final allSelected = allIds.isNotEmpty && _selected.containsAll(allIds);
    final hasSelection = _selected.isNotEmpty;

    return BatchBar(
      selectedCount: _selected.length,
      showCountLabel: true,
      allSelected: allSelected,
      onToggleAll: () => setState(() {
        if (allSelected) {
          _selected.clear();
        } else {
          _selected.addAll(allIds);
        }
      }),
      onDelete: hasSelection
          ? () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.selectedCount(_selected.length)),
                  content: Text(l.deleteConfirmMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.cancel),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.delete),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              widget.onBatchDelete(_selected.toList());
              setState(() {
                _selected.clear();
                _batchMode = false;
              });
            }
          : null,
      onCancel: () => setState(() {
        _batchMode = false;
        _selected.clear();
      }),
    );
  }

  void _onInvReorder(int oldIndex, int newIndex, List<_InvEntry> flat) {
    if (flat[oldIndex].isHeader) return;
    final movedItem = flat[oldIndex].item!;

    final mutable = List<_InvEntry>.from(flat);
    final moved = mutable.removeAt(oldIndex);
    mutable.insert(newIndex, moved);

    // Nearest preceding header determines the new group.
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

    final orderedIds =
        mutable.where((e) => !e.isHeader).map((e) => e.item!.id).toList();
    if (_byCategory) {
      // Cross-group drag in category mode updates the item's category.
      final newCat = widget.categories.firstWhere(
        (c) => c.name == newGroup,
        orElse: () => movedItem.category,
      );
      widget.onReorder(movedItem.id, null, newCat, orderedIds, null);
    } else {
      // Cross-group drag in aisle mode updates the item's shelf code.
      final l = L10n.of(context);
      final newCode = newGroup == l.untaggedShelf ? '' : newGroup;
      widget.onReorder(movedItem.id, null, null, orderedIds, newCode);
    }
  }

  Widget _buildSectionHeader(String zone, int count,
      {Key? key, Color? color, Widget? trailing}) {
    final l = L10n.of(context);
    final resolvedColor = color ??
        (_byCategory
            ? widget.categories
                .firstWhere((c) => c.name == zone,
                    orElse: () => widget.categories.fallback)
                .color
            : AppColors.textMuted);
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: resolvedColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            l.data(zone),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: resolvedColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l.itemCountChip(count),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: resolvedColor,
              ),
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    final l = L10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: Color(0xFFD8D8D3),
          ),
          const SizedBox(height: 16),
          Text(
            _query.isEmpty
                ? l.inventoryEmptyTitle
                : l.inventoryNoResults(_query),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _query.isEmpty
                ? l.inventoryEmptySubtitle
                : l.inventoryEmptySubtitleQuery,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textDisabled),
          ),
          if (_query.isEmpty) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showAddSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  l.addManually,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
