import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import '../widgets/toast.dart';
import '../widgets/days_selector.dart';
import '../widgets/drag_handle.dart';
import '../widgets/sort_toggle_button.dart';
import '../widgets/batch_bar.dart';

part 'inventory_screen.widgets.dart';

/// Grouping mode (base view): items shown under section headers, draggable.
enum InvGroupMode { shelf, category }

/// Value sort overlay: when active, overrides grouping with a flat sorted list.
enum InvSortMode { none, expiry, lastTime }

class InventoryScreen extends StatefulWidget {
  final List<InventoryItem> items;
  final List<Category> categories;
  final int thresholdDays;
  final void Function(InventoryItem item) onAdd;
  final void Function(String id, int newEstimatedDays) onRestock;
  final void Function(String id) onDelete;
  final void Function(InventoryItem item) onAddToShoppingList;
  final void Function(
    String movedId,
    String? newZone,
    Category? newCategory,
    List<String> orderedIds,
  ) onReorder;
  final void Function(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) onEdit;
  final void Function(List<String> ids) onBatchDelete;
  final void Function(List<InventoryItem> items) onBatchAddToRestock;

  const InventoryScreen({
    super.key,
    required this.items,
    required this.categories,
    required this.thresholdDays,
    required this.onAdd,
    required this.onRestock,
    required this.onDelete,
    required this.onAddToShoppingList,
    required this.onReorder,
    required this.onEdit,
    required this.onBatchDelete,
    required this.onBatchAddToRestock,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Batch selection state
  bool _batchMode = false;
  final Set<String> _selected = {};

  // Sort state: grouping mode (base) + optional value-sort overlay
  InvGroupMode _invGroup = InvGroupMode.shelf;
  InvSortMode _invSort = InvSortMode.none;
  SortDir _invDir = SortDir.asc;
  SortDir _invGroupDir = SortDir.asc;
  bool get _byCategory => _invGroup == InvGroupMode.category;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InventoryItem> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((i) =>
            i.name.contains(q) ||
            i.shelfZone.contains(q) ||
            i.category.name.contains(q))
        .toList();
  }

  Map<String, List<InventoryItem>> get _grouped {
    final map = <String, List<InventoryItem>>{};
    for (final item in _filtered) {
      final key = _byCategory ? item.category.name : item.shelfZone;
      map.putIfAbsent(key, () => []).add(item);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => _invGroupDir == SortDir.asc
          ? a.key.compareTo(b.key)
          : b.key.compareTo(a.key));
    return Map.fromEntries(entries);
  }

  // Flat list sorted by the active value sort (expiry / last purchase time).
  // Ascending = small → large (soonest expiry / oldest purchase first);
  // _invDir flips it.
  List<InventoryItem> get _sortedFlat {
    final items = [..._filtered];
    if (_invSort != InvSortMode.none) {
      items.sort((a, b) {
        final cmp = _invSort == InvSortMode.expiry
            ? a.daysRemaining.compareTo(b.daysRemaining)
            : a.purchasedAt.compareTo(b.purchasedAt);
        return _invDir == SortDir.asc ? cmp : -cmp;
      });
    }
    return items;
  }

  int get _needRestockCount => widget.items
      .where((i) =>
          i.statusFor(widget.thresholdDays) != StockStatus.sufficient)
      .length;

  // ── Add new inventory item ───────────────────────────────────────────────────

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddInventorySheet(
        onAdd: widget.onAdd,
        categories: widget.categories,
      ),
    );
  }

  // ── Item detail + inline edit sheet ──────────────────────────────────────────

  void _showDetailSheet(InventoryItem item) {
    final draft = _DetailDraft.from(item);
    bool saved = false;

    void commitEdit() {
      final name = draft.name.trim();
      if (name.isEmpty) return;
      final shelf = draft.shelfCode.trim();
      widget.onEdit(
        item.id,
        name,
        draft.quantity.trim(),
        shelf.isEmpty ? null : shelf,
        draft.category,
        draft.zone,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _InventoryDetailSheet(
        item: item,
        categories: widget.categories,
        thresholdDays: widget.thresholdDays,
        draft: draft,
        onRestock: (days) => widget.onRestock(item.id, days),
        onAddToList: () => widget.onAddToShoppingList(item),
        onDelete: () => widget.onDelete(item.id),
        onSave: () {
          saved = true;
          commitEdit();
          if (mounted) showAppToast(context, L10n.of(context).savedToast);
        },
      ),
    ).whenComplete(() {
      if (!draft.dirty || saved) return;
      if (!mounted) return;
      final l = L10n.of(context);
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.saveChangesTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.discardChanges),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.save),
            ),
          ],
        ),
      ).then((shouldSave) {
        if (!mounted) return;
        if (shouldSave != true) return;
        commitEdit();
      });
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (!_batchMode) _buildSortToggle(),
            const SizedBox(height: 4),
            Expanded(
              child: _filtered.isEmpty
                  ? _emptyState()
                  : _invSort != InvSortMode.none
                      ? _buildSortedFlatList()
                      : _query.isEmpty
                          ? _buildReorderableGroupedList()
                          : _buildGroupedList(),
            ),
            if (_batchMode) _buildBatchBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.inventoryTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.inventorySummary(widget.items.length, _needRestockCount),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_batchMode)
            GestureDetector(
              onTap: () => setState(() {
                _batchMode = false;
                _selected.clear();
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  l.batchDone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _showAddSheet,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
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
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: l.searchHint,
            hintStyle:
                const TextStyle(color: AppColors.textDisabled, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textDisabled, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 4),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textDisabled, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // Cycle a value sort: tapping a different key activates it ascending;
  // tapping the active key cycles asc → desc → off.
  void _cycleInvSort(InvSortMode mode) {
    if (_invSort != mode) {
      _invSort = mode;
      _invDir = SortDir.asc;
    } else if (_invDir == SortDir.asc) {
      _invDir = SortDir.desc;
    } else {
      _invSort = InvSortMode.none;
    }
  }

  // Sort toggle row: grouping pills (按货架/按品类) + value-sort pills
  // (按到期/按上次). Value sorts override grouping; tapping a grouping pill
  // clears the value sort.
  Widget _buildSortToggle() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SortToggleButton(
              label: l.sortByCategory,
              selected: _invSort == InvSortMode.none && _byCategory,
              direction: _invSort == InvSortMode.none && _byCategory
                  ? _invGroupDir
                  : null,
              onTap: () => setState(() {
                if (_invGroup == InvGroupMode.category &&
                    _invSort == InvSortMode.none) {
                  _invGroupDir = _invGroupDir == SortDir.asc
                      ? SortDir.desc
                      : SortDir.asc;
                } else {
                  _invGroup = InvGroupMode.category;
                  _invSort = InvSortMode.none;
                  _invGroupDir = SortDir.asc;
                }
              }),
            ),
            const SizedBox(width: 4),
            SortToggleButton(
              label: l.byShelf,
              selected: _invSort == InvSortMode.none && !_byCategory,
              direction: _invSort == InvSortMode.none && !_byCategory
                  ? _invGroupDir
                  : null,
              onTap: () => setState(() {
                if (_invGroup == InvGroupMode.shelf &&
                    _invSort == InvSortMode.none) {
                  _invGroupDir = _invGroupDir == SortDir.asc
                      ? SortDir.desc
                      : SortDir.asc;
                } else {
                  _invGroup = InvGroupMode.shelf;
                  _invSort = InvSortMode.none;
                  _invGroupDir = SortDir.asc;
                }
              }),
            ),
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: AppColors.border,
            ),
            SortToggleButton(
              label: l.sortByExpiry,
              selected: _invSort == InvSortMode.expiry,
              direction: _invSort == InvSortMode.expiry ? _invDir : null,
              onTap: () => setState(() => _cycleInvSort(InvSortMode.expiry)),
            ),
            const SizedBox(width: 4),
            SortToggleButton(
              label: l.sortByLastTime,
              selected: _invSort == InvSortMode.lastTime,
              direction: _invSort == InvSortMode.lastTime ? _invDir : null,
              onTap: () => setState(() => _cycleInvSort(InvSortMode.lastTime)),
            ),
          ],
        ),
      ),
    );
  }

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
          onDelete: () => widget.onDelete(item.id),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        for (final entry in groups.entries) ...[
          _buildSectionHeader(entry.key, entry.value.length),
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
                onDelete: () => widget.onDelete(item.id),
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
  // within a zone or into another zone (which updates their shelf zone).
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
            key: Key('invh_${entry.groupKey}'),
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
          onDelete: () => widget.onDelete(item.id),
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
    final selectedItems = widget.items.where((i) => _selected.contains(i.id)).toList();

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
      extraActions: [
        BatchBarAction(
          label: l.batchAddToRestock,
          color: AppColors.brand,
          onTap: hasSelection
              ? () {
                  widget.onBatchAddToRestock(selectedItems);
                  setState(() {
                    _selected.clear();
                    _batchMode = false;
                  });
                }
              : null,
        ),
      ],
      onDelete: hasSelection
          ? () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.selectedCount(_selected.length)),
                  content: const Text('确定要删除吗？此操作无法撤销。'),
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
    );
  }

  void _onInvReorder(int oldIndex, int newIndex, List<_InvEntry> flat) {
    if (flat[oldIndex].isHeader) return;
    final movedItem = flat[oldIndex].item!;

    final mutable = List<_InvEntry>.from(flat);
    final moved = mutable.removeAt(oldIndex);
    mutable.insert(newIndex, moved);

    // Nearest preceding header determines the new zone.
    String newZone = '';
    for (int i = newIndex; i >= 0; i--) {
      if (mutable[i].isHeader) {
        newZone = mutable[i].groupKey;
        break;
      }
    }
    if (newZone.isEmpty) {
      for (final e in mutable) {
        if (e.isHeader) {
          newZone = e.groupKey;
          break;
        }
      }
    }
    if (newZone.isEmpty) return;

    final orderedIds =
        mutable.where((e) => !e.isHeader).map((e) => e.item!.id).toList();
    if (_byCategory) {
      // Cross-group drag in category mode updates the item's category.
      final newCat = widget.categories.firstWhere(
        (c) => c.name == newZone,
        orElse: () => movedItem.category,
      );
      widget.onReorder(movedItem.id, null, newCat, orderedIds);
    } else {
      widget.onReorder(movedItem.id, newZone, null, orderedIds);
    }
  }

  Widget _buildSectionHeader(String zone, int count, {Key? key}) {
    final l = L10n.of(context);
    final color = _byCategory
        ? (widget.categories
                .firstWhere((c) => c.name == zone,
                    orElse: () => widget.categories.fallback)
                .color)
        : (defaultShelfZones.findByName(zone)?.dotColor ?? AppColors.textMuted);
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
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
              color: color.withValues(alpha: 0.12),
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
