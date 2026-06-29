import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';

part 'list_screen.widgets.dart';

/// List page modes, in display order: Simple · Budget · Smart.
enum ListMode { simple, budget, smart }

class ListScreen extends StatefulWidget {
  final List<ShoppingItem> simpleItems;
  final List<ShoppingItem> smartItems;
  final List<Category> categories;
  // Simple mode: just mark checked, no inventory
  final void Function(String id) onToggleSimple;
  // Smart mode: triggers "how many days?" sheet → inventory
  final void Function(String id) onToggleSmart;
  final void Function(String name) onAddSimple;
  final void Function(String name, Category category, String shelfZone) onAddSmart;
  final void Function(String id) onDeleteSimple;
  final void Function(String id) onDeleteSmart;
  final VoidCallback onCompleteSimple;
  final VoidCallback onCompleteSmart;
  final void Function(int oldIndex, int newIndex) onReorderSimple;
  final void Function(
    String movedId,
    String? newShelfZone,
    Category? newCategory,
    List<String> orderedIds,
  ) onReorderSmart;
  final void Function(String id, String newName) onRenameSimple;
  final void Function(
    String id,
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) onEditSmart;
  // Budget mode (记账)
  final List<BudgetItem> budgetItems;
  final void Function(String name, int quantity, double unitPrice) onAddBudget;
  final void Function(String id, String name, int quantity, double unitPrice)
      onEditBudget;
  final void Function(String id) onDeleteBudget;

  const ListScreen({
    super.key,
    required this.simpleItems,
    required this.smartItems,
    required this.categories,
    required this.onToggleSimple,
    required this.onToggleSmart,
    required this.onAddSimple,
    required this.onAddSmart,
    required this.onDeleteSimple,
    required this.onDeleteSmart,
    required this.onCompleteSimple,
    required this.onCompleteSmart,
    required this.onReorderSimple,
    required this.onReorderSmart,
    required this.onRenameSimple,
    required this.onEditSmart,
    required this.budgetItems,
    required this.onAddBudget,
    required this.onEditBudget,
    required this.onDeleteBudget,
  });

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  ListMode _mode = ListMode.simple;
  bool _byShelf = true;
  bool _smartHintDismissed = false;

  bool get _isSmart => _mode == ListMode.smart;
  bool get _isBudget => _mode == ListMode.budget;
  final _nameCtrl = TextEditingController();

  // ── Speech-to-text ──────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _nameCtrl.clear();
      });
      await _speech.listen(
        onResult: (result) {
          setState(() => _nameCtrl.text = result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          localeId: 'zh_CN',
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _speech.cancel();
    super.dispose();
  }

  List<ShoppingItem> get _activeItems =>
      _isSmart ? widget.smartItems : widget.simpleItems;
  int get _pendingCount => _activeItems.where((i) => !i.checked).length;
  bool get _hasChecked => _activeItems.any((i) => i.checked);
  int get _checkedCount => _activeItems.where((i) => i.checked).length;

  Future<void> _confirmCompleteTrip() async {
    final l = L10n.of(context);
    final bought = _checkedCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.completeTripTitle),
        content: Text(l.completeTripMessage(bought)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.brand),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.completeTrip),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_isSmart) {
      widget.onCompleteSmart();
    } else {
      widget.onCompleteSimple();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(today),
            _buildModeToggle(),
            if (_isSmart) _buildSmartSubToggle(),
            if (_isSmart && !_smartHintDismissed) _buildSmartHint(),
            const SizedBox(height: 4),
            Expanded(
              child: _isBudget
                  ? (widget.budgetItems.isEmpty
                      ? _budgetEmptyState()
                      : _buildBudgetList())
                  : _activeItems.isEmpty
                      ? _emptyState()
                      : _isSmart
                          ? _buildSmartList()
                          : _buildSimpleList(),
            ),
            if (_isBudget && widget.budgetItems.isNotEmpty)
              _buildBudgetTotalBar(),
            _buildAddBar(context),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(DateTime today) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.shoppingListTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBudget
                      ? l.budgetCount(widget.budgetItems.length)
                      : _pendingCount > 0
                          ? l.listSubtitlePending(_pendingCount, today)
                          : l.listSubtitleDone(today),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_hasChecked)
            GestureDetector(
              onTap: _confirmCompleteTrip,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l.completeTrip,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else if (!_isBudget)
            _MicButton(
              isListening: _isListening,
              available: _speechAvailable,
              onTap: _toggleListening,
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Smart-mode explanation banner ───────────────────────────────────────────

  Widget _buildSmartHint() {
    final l = L10n.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.smartHint,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xFF4B6B4D)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _smartHintDismissed = true),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── 简单 / 智能 main toggle ─────────────────────────────────────────────────

  Widget _buildModeToggle() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _SegmentBtn(
              label: l.modeSimple,
              selected: _mode == ListMode.simple,
              onTap: () => setState(() => _mode = ListMode.simple),
            ),
            _SegmentBtn(
              label: l.budgetMode,
              selected: _mode == ListMode.budget,
              onTap: () => setState(() => _mode = ListMode.budget),
            ),
            _SegmentBtn(
              label: l.modeSmart,
              selected: _mode == ListMode.smart,
              onTap: () => setState(() => _mode = ListMode.smart),
            ),
          ],
        ),
      ),
    );
  }

  // ── 按货架 / 按分类 sub-toggle (smart mode only) ────────────────────────────

  Widget _buildSmartSubToggle() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          _TextToggleBtn(
            label: l.byShelf,
            selected: _byShelf,
            onTap: () => setState(() => _byShelf = true),
          ),
          const SizedBox(width: 4),
          _TextToggleBtn(
            label: l.byCategory,
            selected: !_byShelf,
            onTap: () => setState(() => _byShelf = false),
          ),
        ],
      ),
    );
  }

  // ── Simple list ─────────────────────────────────────────────────────────────

  Widget _buildSimpleList() {
    final l = L10n.of(context);
    final pending = widget.simpleItems.where((i) => !i.checked).toList();
    final done = widget.simpleItems.where((i) => i.checked).toList();

    return CustomScrollView(
      slivers: [
        if (pending.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _simpleSectionHeader(
                icon: Icons.shopping_cart_outlined,
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
            onReorderItem: widget.onReorderSimple,
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                shadowColor: Colors.black26,
                child: child,
              );
            },
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

  /// Section header for simple-mode "待购 / 已购" groups (icon · label · count).
  Widget _simpleSectionHeader({
    required IconData icon,
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
          Icon(icon, size: 14, color: color),
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

  // ── Smart list ──────────────────────────────────────────────────────────────

  Map<String, List<ShoppingItem>> _groupByShelf() {
    final map = <String, List<ShoppingItem>>{};
    for (final item in widget.smartItems) {
      map.putIfAbsent(item.shelfZone, () => []).add(item);
    }
    return map;
  }

  Map<String, List<ShoppingItem>> _groupByCategory() {
    final map = <String, List<ShoppingItem>>{};
    for (final item in widget.smartItems) {
      map.putIfAbsent(item.category.name, () => []).add(item);
    }
    return map;
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

  // Called by ReorderableListView.onReorderItem — newIndex is pre-adjusted.
  void _onSmartReorder(int oldIndex, int newIndex, List<_FlatEntry> flat) {
    if (flat[oldIndex].isHeader) return;
    final movedItem = flat[oldIndex].item!;

    final mutable = List<_FlatEntry>.from(flat);
    final moved = mutable.removeAt(oldIndex);
    mutable.insert(newIndex, moved);

    // Find nearest preceding header to determine new group
    String newGroup = '';
    for (int i = newIndex; i >= 0; i--) {
      if (mutable[i].isHeader) {
        newGroup = mutable[i].groupKey;
        break;
      }
    }
    // Dropped before first header → use first available group
    if (newGroup.isEmpty) {
      for (final e in mutable) {
        if (e.isHeader) { newGroup = e.groupKey; break; }
      }
    }
    if (newGroup.isEmpty) return;

    final orderedIds = mutable
        .where((e) => !e.isHeader)
        .map((e) => e.item!.id)
        .toList();

    if (_byShelf) {
      widget.onReorderSmart(movedItem.id, newGroup, null, orderedIds);
    } else {
      final newCat = widget.categories.firstWhere(
        (c) => c.name == newGroup,
        orElse: () => movedItem.category,
      );
      widget.onReorderSmart(movedItem.id, null, newCat, orderedIds);
    }
  }

  Widget _buildSmartList() {
    final groups = _byShelf ? _groupByShelf() : _groupByCategory();
    final flat = _buildFlatEntries(groups);
    final groupCounts = {for (final e in groups.entries) e.key: e.value.length};

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
            key: Key('h_${entry.groupKey}'),
          );
        }
        final item = entry.item!;
        final zoneColor = _byShelf
            ? (defaultShelfZones.findByName(item.shelfZone)?.dotColor ?? item.category.color)
            : item.category.color;
        return _SmartRow(
          key: Key('si_${item.id}'),
          item: item,
          zoneColor: zoneColor,
          onToggle: () => widget.onToggleSmart(item.id),
          onDelete: () => widget.onDeleteSmart(item.id),
          onLongPress: () => _showRenameSheet(item, true),
          showDragHandle: !item.checked,
          reorderIndex: item.checked ? null : i,
        );
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

  Widget _buildSectionHeader(String zone, int count, {Key? key}) {
    final l = L10n.of(context);
    final color = _byShelf
        ? (defaultShelfZones.findByName(zone)?.dotColor ?? AppColors.textMuted)
        : AppColors.textMuted;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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

  // ── Empty state ─────────────────────────────────────────────────────────────

  Widget _emptyState() {
    final l = L10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isSmart
                ? Icons.inventory_2_outlined
                : Icons.format_list_bulleted_rounded,
            size: 56,
            color: const Color(0xFFD8D8D3),
          ),
          const SizedBox(height: 16),
          Text(
            l.listEmptyTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.listEmptySubtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  // ── Add bar ─────────────────────────────────────────────────────────────────

  Widget _buildAddBar(BuildContext context) {
    final l = L10n.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: _isListening
                  ? l.listeningHint
                  : _isBudget
                      ? l.budgetAddHint
                      : (_isSmart ? l.smartAddHint : l.simpleAddHint),
                hintStyle: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 14),
                filled: true,
                fillColor: AppColors.fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                isDense: true,
              ),
              onSubmitted: (_) => _submitAdd(context),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _submitAdd(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameSheet(ShoppingItem item, bool isSmart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => isSmart
          ? _EditSmartSheet(
              item: item,
              categories: widget.categories,
              onConfirm: (name, quantity, shelfCode, category, zone) {
                widget.onEditSmart(
                    item.id, name, quantity, shelfCode, category, zone);
              },
            )
          : _RenameSheet(
              initialName: item.name,
              onConfirm: (name) => widget.onRenameSimple(item.id, name),
            ),
    );
  }

  void _submitAdd(BuildContext context) {
    final name = _nameCtrl.text.trim();

    if (_isBudget) {
      // Budget: open the expense sheet (name prefilled from the bar).
      _showBudgetSheet(initialName: name);
      _nameCtrl.clear();
      return;
    }

    if (name.isEmpty) return;

    if (_isSmart) {
      // Smart: show category picker sheet
      _showSmartAddSheet(context, name);
    } else {
      // Simple: just add directly, no category needed
      widget.onAddSimple(name);
      _nameCtrl.clear();
    }
  }

  // ── Budget (记账) mode ───────────────────────────────────────────────────────

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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: widget.budgetItems.length,
      itemBuilder: (ctx, i) {
        final item = widget.budgetItems[i];
        return _BudgetRow(
          item: item,
          onTap: () => _showBudgetSheet(item: item),
          onDelete: () => widget.onDeleteBudget(item.id),
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
            style: const TextStyle(
                fontSize: 13, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }

  void _showSmartAddSheet(BuildContext context, String name) {
    Category selectedCategory = widget.categories.first;
    String selectedZone = selectedCategory.shelfZone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final l = L10n.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.addItemTitle(l.data(name)),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.chooseCategoryHint,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.categories.map((cat) {
                      final sel = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () {
                          setModal(() {
                            selectedCategory = cat;
                            selectedZone = cat.shelfZone;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? cat.color : cat.bgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  sel ? Colors.white : cat.color,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textDisabled),
                        const SizedBox(width: 4),
                        Text(
                          l.shelfZoneInline(l.data(selectedZone)),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onAddSmart(
                            name, selectedCategory, selectedZone);
                        _nameCtrl.clear();
                      },
                      child: Text(l.addToList,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

}
