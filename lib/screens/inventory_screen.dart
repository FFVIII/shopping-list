import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import '../widgets/toast.dart';
import '../widgets/days_selector.dart';
import '../widgets/drag_handle.dart';
import '../widgets/sort_toggle_button.dart';
import '../widgets/batch_bar.dart';
import '../widgets/quantity_badge.dart';
import '../services/tutorial_controller.dart';
import '../widgets/tutorial_target.dart';

part 'inventory_screen.card.dart';
part 'inventory_screen.detail_sheet.dart';
part 'inventory_screen.add_sheet.dart';
part 'inventory_screen.list.dart';

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
    String? newShelfCode,
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
  // Custom shelf-code ordering from the Shelf Order screen. Used to sort
  // "by aisle" groups; empty = fall back to alphabetical.
  final List<String> shelfCodeOrder;

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
    required this.shelfCodeOrder,
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

  // Items mid-swipe-delete: hidden from view while their undo toast is up.
  final Set<String> _pendingDeleteIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleSwipeDelete(InventoryItem item) {
    final l = L10n.of(context);
    setState(() => _pendingDeleteIds.add(item.id));
    showUndoToast(
      context,
      message: l.itemDeletedToast(l.data(item.name)),
      actionLabel: l.undo,
      onAction: () {
        if (mounted) setState(() => _pendingDeleteIds.remove(item.id));
      },
      onTimeout: () {
        widget.onDelete(item.id);
        if (mounted) setState(() => _pendingDeleteIds.remove(item.id));
      },
    );
  }

  List<InventoryItem> get _filtered {
    final visible =
        widget.items.where((i) => !_pendingDeleteIds.contains(i.id));
    if (_query.isEmpty) return visible.toList();
    final q = _query.toLowerCase();
    return visible
        .where((i) =>
            i.name.contains(q) ||
            i.shelfZone.contains(q) ||
            i.category.name.contains(q))
        .toList();
  }

  Map<String, List<InventoryItem>> get _grouped {
    if (_byCategory) {
      final map = <String, List<InventoryItem>>{};
      for (final item in _filtered) {
        map.putIfAbsent(item.category.name, () => []).add(item);
      }
      final entries = map.entries.toList()
        ..sort((a, b) => _invGroupDir == SortDir.asc
            ? a.key.compareTo(b.key)
            : b.key.compareTo(a.key));
      return Map.fromEntries(entries);
    }

    // "By aisle": group by the item's custom shelf code (same as the Plan
    // list's shelf grouping), not by the broader category shelf zone.
    final map = <String, List<InventoryItem>>{};
    final untagged = <InventoryItem>[];
    for (final item in _filtered) {
      final code = item.shelfCode?.trim();
      if (code != null && code.isNotEmpty) {
        map.putIfAbsent(code, () => []).add(item);
      } else {
        untagged.add(item);
      }
    }
    final order = widget.shelfCodeOrder;
    final entries = map.entries.toList()
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
        return _invGroupDir == SortDir.asc ? cmp : -cmp;
      });
    final sorted = Map.fromEntries(entries);
    // Untagged items always appear at the end regardless of direction.
    if (untagged.isNotEmpty) {
      sorted[L10n.of(context).untaggedShelf] = untagged;
    }
    return sorted;
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

  // Trailing summary text ("2 stocked · 1 to restock"), tucked onto the
  // first group's section header rather than the page header, so it only
  // appears once there's at least one item to anchor it to.
  Widget _buildInventorySummaryTrailing() {
    final l = L10n.of(context);
    return Text(
      l.inventorySummary(widget.items.length, _needRestockCount),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
    );
  }

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
              ],
            ),
          ),
          // Cancel lives in the bottom BatchBar (left of Delete), matching the
          // list and category screens; the header offers Add when not
          // selecting, or Add-to-restock when a batch selection is active.
          if (_batchMode)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: GestureDetector(
                onTap: _selected.isNotEmpty
                    ? () {
                        final selectedItems = widget.items
                            .where((i) => _selected.contains(i.id))
                            .toList();
                        widget.onBatchAddToRestock(selectedItems);
                        setState(() {
                          _selected.clear();
                          _batchMode = false;
                        });
                      }
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _selected.isNotEmpty
                        ? AppColors.brand
                        : AppColors.fieldBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.batchAddToRestock,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _selected.isNotEmpty
                            ? Colors.white
                            : AppColors.textDisabled,
                      ),
                    ),
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
          filled: true,
          fillColor: AppColors.fieldBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
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
}
