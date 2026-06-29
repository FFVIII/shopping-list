import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';

part 'list_screen.widgets.dart';
part 'list_screen.simple.dart';
part 'list_screen.smart.dart';
part 'list_screen.budget.dart';

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
  final void Function(int oldIndex, int newIndex) onReorderBudget;
  // Batch operations
  final void Function(List<String> ids) onBatchDeleteSmart;
  final void Function(List<String> ids) onBatchMarkBought;
  final void Function(List<String> ids) onBatchDeleteBudget;
  // Incremented each time an item is added from the reminder screen;
  // causes this screen to switch to smart mode so the new item is visible.
  final int smartModeRequest;

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
    required this.onReorderBudget,
    required this.onBatchDeleteSmart,
    required this.onBatchMarkBought,
    required this.onBatchDeleteBudget,
    required this.smartModeRequest,
  });

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  ListMode _mode = ListMode.simple;
  bool _byShelf = true;
  bool _smartHintDismissed = false;

  // Batch selection state (smart mode)
  bool _smartBatchMode = false;
  final Set<String> _smartSelected = {};

  // Batch selection state (budget mode)
  bool _budgetBatchMode = false;
  final Set<String> _budgetSelected = {};

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

  @override
  void didUpdateWidget(ListScreen old) {
    super.didUpdateWidget(old);
    if (widget.smartModeRequest != old.smartModeRequest) {
      setState(() => _mode = ListMode.smart);
    }
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
            if (_isBudget && _budgetBatchMode) _buildBudgetBatchSubBar(),
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
            if (_isBudget && widget.budgetItems.isNotEmpty && !_budgetBatchMode)
              _buildBudgetTotalBar(),
            if (_isSmart && _smartBatchMode)
              _buildSmartBatchBar()
            else if (_isBudget && _budgetBatchMode)
              _buildBudgetBatchBar()
            else
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

  // ── Mode toggles ─────────────────────────────────────────────────────────────

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

  Widget _buildSmartSubToggle() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          if (!_smartBatchMode) ...[
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
          ] else ...[
            Text(
              l.selectedCount(_smartSelected.length),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _smartBatchMode = false;
                _smartSelected.clear();
              }),
              child: Text(
                l.batchDone,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  // ── Empty state (simple / smart) ────────────────────────────────────────────

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

  void _enterSmartBatchWithItem(String id) {
    setState(() {
      _smartBatchMode = true;
      _smartSelected.add(id);
    });
  }

  void _toggleSmartSelection(String id) {
    setState(() {
      if (_smartSelected.contains(id)) {
        _smartSelected.remove(id);
      } else {
        _smartSelected.add(id);
      }
    });
  }

  void _enterBudgetBatchWithItem(String id) {
    setState(() {
      _budgetBatchMode = true;
      _budgetSelected.add(id);
    });
  }

  void _toggleBudgetSelection(String id) {
    setState(() {
      if (_budgetSelected.contains(id)) {
        _budgetSelected.remove(id);
      } else {
        _budgetSelected.add(id);
      }
    });
  }

  Widget _buildBudgetBatchSubBar() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          Text(
            l.selectedCount(_budgetSelected.length),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _budgetBatchMode = false;
              _budgetSelected.clear();
            }),
            child: Text(
              l.batchDone,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetBatchBar() {
    final l = L10n.of(context);
    final allIds = widget.budgetItems.map((i) => i.id).toSet();
    final allSelected =
        allIds.isNotEmpty && _budgetSelected.containsAll(allIds);
    final hasSelection = _budgetSelected.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (allSelected) {
                _budgetSelected.clear();
              } else {
                _budgetSelected.addAll(allIds);
              }
            }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: allSelected
                    ? AppColors.brand.withValues(alpha: 0.12)
                    : AppColors.fieldBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l.selectAll,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: allSelected
                      ? AppColors.brand
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: hasSelection
                ? () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.selectedCount(_budgetSelected.length)),
                        content: const Text('确定要删除吗？此操作无法撤销。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l.cancel),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l.delete),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    widget.onBatchDeleteBudget(_budgetSelected.toList());
                    setState(() {
                      _budgetSelected.clear();
                      _budgetBatchMode = false;
                    });
                  }
                : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasSelection
                    ? AppColors.danger.withValues(alpha: 0.10)
                    : AppColors.fieldBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l.delete,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasSelection
                      ? AppColors.danger
                      : AppColors.textDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Smart batch bar ──────────────────────────────────────────────────────────

  Widget _buildSmartBatchBar() {
    final l = L10n.of(context);
    final allIds = widget.smartItems.map((i) => i.id).toSet();
    final allSelected = allIds.isNotEmpty && _smartSelected.containsAll(allIds);
    final hasSelection = _smartSelected.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Row(
        children: [
          // Select all
          GestureDetector(
            onTap: () => setState(() {
              if (allSelected) {
                _smartSelected.clear();
              } else {
                _smartSelected.addAll(allIds);
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: allSelected ? AppColors.brand.withValues(alpha: 0.12) : AppColors.fieldBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l.selectAll,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: allSelected ? AppColors.brand : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Delete
          GestureDetector(
            onTap: hasSelection ? () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(L10n.of(context).selectedCount(_smartSelected.length)),
                  content: const Text('确定要删除吗？此操作无法撤销。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(context).cancel)),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(L10n.of(context).delete),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              widget.onBatchDeleteSmart(_smartSelected.toList());
              setState(() {
                _smartSelected.clear();
                _smartBatchMode = false;
              });
            } : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasSelection ? AppColors.danger.withValues(alpha: 0.10) : AppColors.fieldBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l.delete,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasSelection ? AppColors.danger : AppColors.textDisabled,
                ),
              ),
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

  void _showSmartAddSheet(BuildContext context, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SmartAddSheet(
        name: name,
        categories: widget.categories,
        onConfirm: (category, zone) {
          widget.onAddSmart(name, category, zone);
          _nameCtrl.clear();
        },
      ),
    );
  }

}
