import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';

class ListScreen extends StatefulWidget {
  final List<ShoppingItem> simpleItems;
  final List<ShoppingItem> smartItems;
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

  const ListScreen({
    super.key,
    required this.simpleItems,
    required this.smartItems,
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
  });

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  bool _isSmartMode = false;
  bool _byShelf = true;
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
      _isSmartMode ? widget.smartItems : widget.simpleItems;
  int get _pendingCount => _activeItems.where((i) => !i.checked).length;
  bool get _hasChecked => _activeItems.any((i) => i.checked);

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2ED),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(today),
            _buildModeToggle(),
            if (_isSmartMode) _buildSmartSubToggle(),
            const SizedBox(height: 4),
            Expanded(
              child: _activeItems.isEmpty
                  ? _emptyState()
                  : _isSmartMode
                      ? _buildSmartList()
                      : _buildSimpleList(),
            ),
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
                    color: Color(0xFF1A1A1A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pendingCount > 0
                      ? l.listSubtitlePending(_pendingCount, today)
                      : l.listSubtitleDone(today),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          if (_hasChecked)
            GestureDetector(
              onTap: _isSmartMode ? widget.onCompleteSmart : widget.onCompleteSimple,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
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
          else
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
              selected: !_isSmartMode,
              onTap: () => setState(() => _isSmartMode = false),
            ),
            _SegmentBtn(
              label: l.modeSmart,
              selected: _isSmartMode,
              onTap: () => setState(() => _isSmartMode = true),
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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 14, color: Color(0xFFBDBDBD)),
                      const SizedBox(width: 6),
                      Text(
                        l.purchasedSection,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0EA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l.itemCountChip(done.length),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                    ],
                  ),
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
      map.putIfAbsent(item.category.label, () => []).add(item);
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
      final newCat = Category.values.firstWhere(
        (c) => c.label == newGroup,
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
            ? (kShelfZones[item.shelfZone]?.dotColor ?? item.category.color)
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
        ? (kShelfZones[zone]?.dotColor ?? const Color(0xFF9E9E9E))
        : const Color(0xFF9E9E9E);
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
              color: Color(0xFF1A1A1A),
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
            _isSmartMode
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
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.listEmptySubtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
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
                  : (_isSmartMode ? l.smartAddHint : l.simpleAddHint),
                hintStyle: const TextStyle(
                    color: Color(0xFFBDBDBD), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F5F0),
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
                color: const Color(0xFF4CAF50),
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
              zoneFor: _zoneFor,
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
    if (name.isEmpty) return;

    if (!_isSmartMode) {
      // Simple: just add directly, no category needed
      widget.onAddSimple(name);
      _nameCtrl.clear();
    } else {
      // Smart: show category picker sheet
      _showSmartAddSheet(context, name);
    }
  }

  void _showSmartAddSheet(BuildContext context, String name) {
    Category selectedCategory = Category.produce;
    String selectedZone = '果蔬区';

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
                        fontSize: 13, color: Color(0xFF9E9E9E)),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Category.values.map((cat) {
                      final sel = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () {
                          setModal(() {
                            selectedCategory = cat;
                            selectedZone = _zoneFor(cat);
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
                            l.category(cat),
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
                            size: 14, color: Color(0xFFBDBDBD)),
                        const SizedBox(width: 4),
                        Text(
                          l.shelfZoneInline(l.data(selectedZone)),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9E9E9E)),
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
                        backgroundColor: const Color(0xFF4CAF50),
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
}

// ── Flat list entry for smart-mode drag ──────────────────────────────────────

class _FlatEntry {
  final String groupKey;
  final ShoppingItem? item;
  _FlatEntry.header(this.groupKey) : item = null;
  _FlatEntry.forItem(this.item, this.groupKey);
  bool get isHeader => item == null;
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
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onToggle,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 15),
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
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF1A1A1A),
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: const Color(0xFFBDBDBD),
                  ),
                ),
              ),
              if (showDragHandle && !item.checked && reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.drag_handle_rounded,
                        size: 20, color: Color(0xFFD0D0D0)),
                  ),
                ),
            ],
          ),
        ),
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
  final bool showDragHandle;
  final int? reorderIndex;

  const _SmartRow({
    super.key,
    required this.item,
    required this.zoneColor,
    required this.onToggle,
    required this.onDelete,
    this.onLongPress,
    this.showDragHandle = false,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Dismissible(
      key: Key('smart_${item.id}'),
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
        onTap: onToggle,
        onLongPress: onLongPress,
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 15),
                  child: _Checkbox(checked: item.checked),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l.data(item.name),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: item.checked
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF1A1A1A),
                            decoration: item.checked
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: const Color(0xFFBDBDBD),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.itemMeta(
                              l.data(item.quantityLabel),
                              item.shelfCode != null
                                  ? l.data(item.shelfCode!)
                                  : null),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9E9E9E)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (item.addedToInventory)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l.recordedBadge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: zoneColor,
                      ),
                    ),
                  ),
                if (showDragHandle && !item.checked && reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.drag_handle_rounded,
                          size: 20, color: Color(0xFFD0D0D0)),
                    ),
                  ),
                // Right color bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: item.checked
                        ? const Color(0xFFE8E8E8)
                        : zoneColor,
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(14)),
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

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Checkbox extends StatelessWidget {
  final bool checked;
  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            checked ? const Color(0xFF4CAF50) : Colors.transparent,
        border: checked
            ? null
            : Border.all(
                color: const Color(0xFFD0D0D0), width: 1.5),
      ),
      child: checked
          ? const Icon(Icons.check_rounded,
              color: Colors.white, size: 15)
          : null,
    );
  }
}

// ── Mic Button ────────────────────────────────────────────────────────────────

class _MicButton extends StatefulWidget {
  final bool isListening;
  final bool available;
  final VoidCallback onTap;

  const _MicButton({
    required this.isListening,
    required this.available,
    required this.onTap,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isListening) {
      return GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                const Color(0xFFE53935),
                const Color(0xFFEF9A9A),
                _pulse.value,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935)
                      .withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded,
                size: 22, color: Colors.white),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.available ? widget.onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.mic_none_rounded,
          size: 22,
          color: widget.available
              ? const Color(0xFF4CAF50)
              : const Color(0xFFD0D0D0),
        ),
      ),
    );
  }
}

class _SegmentBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentBtn(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: selected
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFF8A8A8A),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rename Sheet ──────────────────────────────────────────────────────────────

class _RenameSheet extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onConfirm;

  const _RenameSheet({required this.initialName, required this.onConfirm});

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    widget.onConfirm(name);
  }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.rename,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF5F5F0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              isDense: true,
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 14),
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
              onPressed: _confirm,
              child: Text(
                l.confirmEdit,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit Smart Item Sheet (name + quantity + shelf code + category) ──────────

class _EditSmartSheet extends StatefulWidget {
  final ShoppingItem item;
  final String Function(Category) zoneFor;
  final void Function(
    String name,
    String quantityLabel,
    String? shelfCode,
    Category category,
    String shelfZone,
  ) onConfirm;

  const _EditSmartSheet({
    required this.item,
    required this.zoneFor,
    required this.onConfirm,
  });

  @override
  State<_EditSmartSheet> createState() => _EditSmartSheetState();
}

class _EditSmartSheetState extends State<_EditSmartSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _shelfCtrl;
  late Category _category;
  late String _zone;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _qtyCtrl = TextEditingController(text: widget.item.quantityLabel);
    _shelfCtrl = TextEditingController(text: widget.item.shelfCode ?? '');
    _category = widget.item.category;
    _zone = widget.item.shelfZone;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final shelf = _shelfCtrl.text.trim();
    Navigator.pop(context);
    widget.onConfirm(
      name,
      _qtyCtrl.text.trim(),
      shelf.isEmpty ? null : shelf,
      _category,
      _zone,
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B6B6B),
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
              l.editItem,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration(''),
              onSubmitted: (_) => _confirm(),
            ),
            _label(l.quantityFieldLabel),
            TextField(
              controller: _qtyCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration('1'),
            ),
            _label(l.shelfCodeFieldLabel),
            TextField(
              controller: _shelfCtrl,
              style: const TextStyle(fontSize: 15),
              decoration: _fieldDecoration(''),
            ),
            _label(l.categoryLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Category.values.map((cat) {
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() {
                    _category = cat;
                    _zone = widget.zoneFor(cat);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Color(0xFFBDBDBD)),
                const SizedBox(width: 4),
                Text(
                  l.shelfZoneInline(l.data(_zone)),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                onPressed: _confirm,
                child: Text(
                  l.confirmEdit,
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

class _TextToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TextToggleBtn(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? const Color(0xFF4CAF50)
                : const Color(0xFF9E9E9E),
          ),
        ),
      ),
    );
  }
}
