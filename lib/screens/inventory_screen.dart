import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';

part 'inventory_screen.widgets.dart';

class InventoryScreen extends StatefulWidget {
  final List<InventoryItem> items;
  final List<Category> categories;
  final int thresholdDays;
  final void Function(InventoryItem item) onAdd;
  final void Function(String id, int newEstimatedDays) onRestock;
  final void Function(String id) onDelete;
  final void Function(InventoryItem item) onAddToShoppingList;
  final void Function(String movedId, String newZone, List<String> orderedIds)
      onReorder;
  final void Function(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) onEdit;

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
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

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
      map.putIfAbsent(item.shelfZone, () => []).add(item);
    }
    return map;
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
    // Shared draft mutated by the sheet's editable fields; committed on close.
    final draft = _DetailDraft.from(item);

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
      ),
    ).whenComplete(() {
      if (!draft.dirty) return;
      final name = draft.name.trim();
      if (name.isEmpty) return; // ignore invalid edits
      final shelf = draft.shelfCode.trim();
      widget.onEdit(
        item.id,
        name,
        draft.quantity.trim(),
        shelf.isEmpty ? null : shelf,
        draft.category,
        draft.zone,
      );
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
            const SizedBox(height: 4),
            Expanded(
              child: _filtered.isEmpty
                  ? _emptyState()
                  : _query.isEmpty
                      ? _buildReorderableGroupedList()
                      : _buildGroupedList(),
            ),
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
                onTap: () => _showDetailSheet(item),
                onDelete: () => widget.onDelete(item.id),
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
          onTap: () => _showDetailSheet(item),
          onDelete: () => widget.onDelete(item.id),
          reorderIndex: i,
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
    widget.onReorder(movedItem.id, newZone, orderedIds);
  }

  Widget _buildSectionHeader(String zone, int count, {Key? key}) {
    final l = L10n.of(context);
    final color =
        defaultShelfZones.findByName(zone)?.dotColor ?? AppColors.textMuted;
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
