import 'package:flutter/material.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';

class InventoryScreen extends StatefulWidget {
  final List<InventoryItem> items;
  final int thresholdDays;
  final void Function(InventoryItem item) onAdd;
  final void Function(String id, int newEstimatedDays) onRestock;
  final void Function(String id) onDelete;
  final void Function(InventoryItem item) onAddToShoppingList;
  final void Function(String movedId, String newZone, List<String> orderedIds)
      onReorder;

  const InventoryScreen({
    super.key,
    required this.items,
    required this.thresholdDays,
    required this.onAdd,
    required this.onRestock,
    required this.onDelete,
    required this.onAddToShoppingList,
    required this.onReorder,
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
            i.category.label.contains(q))
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
        zoneFor: _zoneFor,
      ),
    );
  }

  // ── Item detail / reset sheet ────────────────────────────────────────────────

  void _showDetailSheet(InventoryItem item) {
    final status = item.statusFor(widget.thresholdDays);
    int selectedDays = item.estimatedDays;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final l = L10n.of(ctx);
          return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + category chip
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.data(item.name),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: item.category.bgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      l.category(item.category),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.category.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: Color(0xFFBDBDBD)),
                  const SizedBox(width: 3),
                  Text(
                    l.data(item.shelfZone),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar + status
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: item.progressRatio,
                  backgroundColor: status.color.withValues(alpha: 0.12),
                  color: status.color,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l.stockStatus(status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    status == StockStatus.empty
                        ? l.usedUp
                        : l.daysRemainingLong(item.daysRemaining),
                    style: TextStyle(fontSize: 13, color: status.color),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF0F0EA)),
              const SizedBox(height: 16),
              // Reset section
              Text(
                l.resetTimerSection,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [3, 5, 7, 14, 30].map((d) {
                  final sel = selectedDays == d;
                  return GestureDetector(
                    onTap: () => setModal(() => selectedDays = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF5F5F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.days(d),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white
                              : const Color(0xFF424242),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: const Color(0xFF4CAF50),
                  inactiveTrackColor: const Color(0xFFE0E0E0),
                  thumbColor: const Color(0xFF4CAF50),
                  overlayColor:
                      const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: selectedDays.toDouble().clamp(1, 60),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: l.days(selectedDays),
                  onChanged: (v) =>
                      setModal(() => selectedDays = v.round()),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onRestock(item.id, selectedDays);
                  },
                  child: Text(
                    l.resetTimer(selectedDays),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(
                        color: Color(0xFF4CAF50), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onAddToShoppingList(item);
                  },
                  child: Text(
                    l.addToRestockList,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onDelete(item.id);
                  },
                  child: Text(
                    l.deleteFromInventory,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  String _zoneFor(Category cat) {
    switch (cat) {
      case Category.produce:
        return '果蔬区';
      case Category.dairy:
      case Category.meat:
        return '冷藏/乳制品';
      case Category.grain:
        return '粮油区';
      case Category.cleaning:
        return '日用品';
      default:
        return '其他';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2ED),
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
                    color: Color(0xFF1A1A1A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.inventorySummary(widget.items.length, _needRestockCount),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9E9E9E)),
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
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.30),
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
              color: Color(0x09000000),
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
                const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFFBDBDBD), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 4),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFFBDBDBD), size: 18),
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
        kShelfZones[zone]?.dotColor ?? const Color(0xFF9E9E9E);
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
              color: Color(0xFF1A1A1A),
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
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _query.isEmpty
                ? l.inventoryEmptySubtitle
                : l.inventoryEmptySubtitleQuery,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFFBDBDBD)),
          ),
          if (_query.isEmpty) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showAddSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
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

// ── Inventory Card ─────────────────────────────────────────────────────────────

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final int thresholdDays;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final int? reorderIndex;

  const _InventoryCard({
    super.key,
    required this.item,
    required this.thresholdDays,
    required this.onTap,
    required this.onDelete,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final status = item.statusFor(thresholdDays);
    final remaining = item.daysRemaining;
    final dn = l.data(item.name);
    final barColor =
        kShelfZones[item.shelfZone]?.dotColor ?? item.category.color;

    return Dismissible(
      key: Key('inv_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x09000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left color bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14)),
                  ),
                ),
                const SizedBox(width: 12),
                // Thumbnail
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: item.category.bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      dn.length > 2 ? dn.substring(0, 2) : dn,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: item.category.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dn,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ProgressBar(
                          ratio: item.progressRatio,
                          color: status.color,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          status == StockStatus.empty
                              ? l.usedUp
                              : (remaining <= 3
                                  ? l.daysShortApprox(remaining)
                                  : l.daysShort(remaining)),
                          style: TextStyle(
                            fontSize: 12,
                            color: status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Status badge
                Container(
                  margin: EdgeInsets.only(right: reorderIndex == null ? 14 : 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status.bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.stockStatus(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status.color,
                    ),
                  ),
                ),
                // Drag handle (only in reorderable mode)
                if (reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10, left: 2),
                      child: Icon(Icons.drag_handle_rounded,
                          size: 20, color: Color(0xFFD0D0D0)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Flat list entry for drag-reorder (header or item) ───────────────────────────

class _InvEntry {
  final String groupKey;
  final InventoryItem? item;
  _InvEntry.header(this.groupKey) : item = null;
  _InvEntry.forItem(this.item, this.groupKey);
  bool get isHeader => item == null;
}

// ── Add Inventory Sheet ────────────────────────────────────────────────────────

class _AddInventorySheet extends StatefulWidget {
  final void Function(InventoryItem) onAdd;
  final String Function(Category) zoneFor;

  const _AddInventorySheet({required this.onAdd, required this.zoneFor});

  @override
  State<_AddInventorySheet> createState() => _AddInventorySheetState();
}

class _AddInventorySheetState extends State<_AddInventorySheet> {
  final _nameCtrl = TextEditingController();
  Category _category = Category.produce;
  int _days = 7;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    widget.onAdd(InventoryItem(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: _category,
      shelfZone: widget.zoneFor(_category),
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
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: l.productNameHint,
              hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
              filled: true,
              fillColor: const Color(0xFFF5F5F0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          Text(
            l.categoryLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: Category.values.map((cat) {
              final sel = _category == cat;
              return GestureDetector(
                onTap: () => setState(() => _category = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? cat.color : cat.bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.category(cat),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : cat.color,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            l.estimatedUseDays,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [3, 5, 7, 14, 30].map((d) {
              final sel = _days == d;
              return GestureDetector(
                onTap: () => setState(() => _days = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF5F5F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l.days(d),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : const Color(0xFF424242),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF4CAF50),
              inactiveTrackColor: const Color(0xFFE0E0E0),
              thumbColor: const Color(0xFF4CAF50),
              overlayColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _days.toDouble().clamp(1, 60),
              min: 1,
              max: 60,
              divisions: 59,
              label: l.days(_days),
              onChanged: (v) => setState(() => _days = v.round()),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE0E0E0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _nameCtrl.text.trim().isEmpty ? null : _submit,
              child: Text(
                l.addToInventoryBtn,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress Bar ───────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double ratio;
  final Color color;
  const _ProgressBar({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        FractionallySizedBox(
          widthFactor: ratio.clamp(0.0, 1.0),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}
