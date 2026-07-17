import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/item.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../widgets/days_selector.dart';
import '../widgets/drag_handle.dart';
import '../widgets/sort_toggle_button.dart';
import '../widgets/batch_bar.dart';
import '../widgets/quantity_badge.dart';
import '../widgets/toast.dart';
import '../widgets/tutorial_target.dart';
import '../widgets/category_chip_picker.dart';
import '../services/navigation_store.dart';
import '../services/tutorial_controller.dart';
import '../services/tutorial_store.dart';

part 'list_screen.widgets.dart';
part 'list_screen.header.dart';
part 'list_screen.simple.dart';
part 'list_screen.smart.dart';
part 'list_screen.budget.dart';
part 'list_screen.sheets.dart';
part 'list_screen.batch.dart';
part 'list_screen.toggles.dart';

/// List page modes, in display order: Simple · Budget · Smart.
enum ListMode { simple, budget, smart }

enum BudgetSortMode { manual, name, price }

enum SmartGroupMode { shelf, category, manual }

class ListScreen extends StatefulWidget {
  final List<ShoppingItem> simpleItems;
  final List<ShoppingItem> smartItems;
  final List<Category> categories;
  // Simple mode: just mark checked, no inventory
  final void Function(String id) onToggleSimple;
  // Smart mode: triggers "how many days?" sheet → inventory
  final void Function(String id) onToggleSmart;
  final void Function(String name) onAddSimple;
  final void Function(String name, String quantityLabel, String? shelfCode, int estimatedDays, Category category, String shelfZone) onAddSmart;
  final void Function(String id) onDeleteSimple;
  final void Function(String id) onDeleteSmart;
  final VoidCallback onCompleteSimple;
  final void Function(List<String> selectedIds) onCompleteSmart;
  final void Function(List<String> orderedIds) onReorderSimple;
  final void Function(
    String movedId,
    String? newShelfZone,
    Category? newCategory,
    List<String> orderedIds,
    String? newShelfCode,
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
  final void Function(List<String> orderedIds) onReorderBudget;
  final void Function(List<BudgetItem> snapshot) onRecordBudgetPurchase;
  // Batch operations
  final void Function(List<String> ids) onBatchDeleteSimple;
  final void Function(List<String> ids) onBatchDeleteSmart;
  final void Function(List<String> ids) onBatchMarkBought;
  final void Function(List<String> ids) onBatchDeleteBudget;
  // Custom shelf-code ordering from the Shelf Order screen. Used by
  // _groupByShelf() to sort sections; empty = fall back to alphabetical.
  final List<String> shelfCodeOrder;
  // Incremented each time an item is added from the reminder screen;
  // causes this screen to switch to smart mode so the new item is visible.
  final int smartModeRequest;
  // Restored from NavigationStore so a full app restart reopens on the
  // last-viewed mode instead of always Jot.
  final ListMode initialMode;
  final Category Function(
      String name, Color color, String shelfZone, int defaultDays)
      onAddCategory;

  const ListScreen({
    super.key,
    this.initialMode = ListMode.simple,
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
    required this.onRecordBudgetPurchase,
    required this.onBatchDeleteSimple,
    required this.onBatchDeleteSmart,
    required this.onBatchMarkBought,
    required this.onBatchDeleteBudget,
    required this.smartModeRequest,
    required this.shelfCodeOrder,
    required this.onAddCategory,
  });

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  late ListMode _mode = widget.initialMode;
  SmartGroupMode _smartGroup = SmartGroupMode.shelf;
  SortDir _smartGroupDir = SortDir.asc;
  bool get _byShelf => _smartGroup == SmartGroupMode.shelf;

  // Batch selection state (smart mode)
  bool _smartBatchMode = false;
  final Set<String> _smartSelected = {};

  // Trip selection: which items to save to inventory on complete (default: all)
  final Set<String> _tripSelected = {};

  // Simple list sort: by name, off → asc → desc → off. null = off.
  SortDir? _simpleDir;

  // Batch selection state (simple mode)
  bool _simpleBatchMode = false;
  final Set<String> _simpleSelected = {};

  // Batch selection state (budget mode)
  bool _budgetBatchMode = false;
  final Set<String> _budgetSelected = {};
  BudgetSortMode _budgetSort = BudgetSortMode.manual;
  SortDir _budgetDir = SortDir.asc;

  bool get _isSmart => _mode == ListMode.smart;
  bool get _isBudget => _mode == ListMode.budget;

  // Items mid-swipe-delete: hidden from view while their undo toast is up.
  final Set<String> _pendingDeleteIds = {};

  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  bool _tutorialPrefilled = false;

  // ── Speech-to-text ──────────────────────────────────────────────────────────
  // Temporarily hidden — not used right now. Flip back on to restore the mic
  // button (and the permission request it triggers on startup via
  // _initSpeech).
  static const bool _voiceInputEnabled = false;
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    if (_voiceInputEnabled) _initSpeech();
    _tripSelected.addAll(widget.smartItems.map((i) => i.id));
  }

  @override
  void didUpdateWidget(ListScreen old) {
    super.didUpdateWidget(old);
    if (widget.smartModeRequest != old.smartModeRequest) {
      setState(() => _mode = ListMode.smart);
    }
    // Keep trip selection in sync with item list
    final currentIds = widget.smartItems.map((i) => i.id).toSet();
    _tripSelected
      ..addAll(currentIds.difference(_tripSelected))
      ..removeAll(_tripSelected.difference(currentIds));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tutorialPrefilled &&
        TutorialController.instance.step == TutorialStep.addItem &&
        _nameCtrl.text.isEmpty) {
      // The tutorial's flow (add -> complete trip -> inventory) only exists
      // in smart/plan mode — force it so tapping "+" opens the smart add
      // sheet instead of silently adding to the simple list.
      _mode = ListMode.smart;
      _nameCtrl.text = L10n.of(context).tutorialExampleItemName;
      _tutorialPrefilled = true;
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
    if (!_speechAvailable) {
      showAppToast(context, L10n.of(context).micPermissionDenied);
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _nameCtrl.clear();
      });
      final localeId =
          L10n.of(context) is ZhStrings ? 'zh_CN' : 'en_US';
      await _speech.listen(
        onResult: (result) {
          setState(() => _nameCtrl.text = result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    _speech.cancel();
    super.dispose();
  }

  List<ShoppingItem> get _activeItems =>
      _isSmart ? widget.smartItems : widget.simpleItems;
  int get _pendingCount => _activeItems.where((i) => !i.checked).length;

  // Trailing summary text ("1 left · Jul 3"), tucked onto the first section
  // header of the Simple/Plan lists rather than the page header, so it only
  // appears once there's at least one item to anchor it to.
  Widget _buildSummaryTrailing() {
    final l = L10n.of(context);
    final today = DateTime.now();
    return Text(
      _pendingCount > 0
          ? l.listSubtitlePending(_pendingCount, today)
          : l.listSubtitleDone(today),
      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
    );
  }

  Future<void> _confirmCompleteSimple() async {
    final l = L10n.of(context);
    final bought = widget.simpleItems.where((i) => i.checked).length;
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
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.onCompleteSimple();
    // Only celebrate if something was actually bought — an empty trip isn't
    // an accomplishment.
    if (mounted && bought > 0) {
      HapticFeedback.mediumImpact();
      showCompletionCelebration(context, l.tripCompletedCelebration);
    }
  }

  void _confirmCompleteTrip() {
    if (_isSmart) {
      // Ensure every current item is in _tripSelected before opening the sheet
      _tripSelected.addAll(widget.smartItems.map((i) => i.id));
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _CompleteTripSheet(
          items: widget.smartItems,
          initialSelected: Set<String>.from(_tripSelected),
          onConfirm: (selectedIds) {
            setState(() {
              _tripSelected
                ..clear()
                ..addAll(selectedIds);
            });
            widget.onCompleteSmart(selectedIds);
            // Only celebrate if something was actually saved to inventory.
            if (mounted && selectedIds.isNotEmpty) {
              HapticFeedback.mediumImpact();
              showCompletionCelebration(
                  context, L10n.of(context).tripCompletedCelebration);
            }
          },
        ),
      );
    } else {
      _confirmCompleteSimple();
    }
  }

  Future<void> _confirmClearBudget() async {
    final l = L10n.of(context);
    final count = widget.budgetItems.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.clearBudgetTitle),
        content: Text(l.clearBudgetMessage(count)),
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
    widget.onRecordBudgetPurchase(widget.budgetItems);
    widget.onBatchDeleteBudget(widget.budgetItems.map((i) => i.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildModeToggle(),
            if (_isSmart) _buildSmartSubToggle(),
            if (!_isSmart && !_isBudget) _buildSimpleSortToggle(),
            if (_isBudget && !_budgetBatchMode) _buildBudgetSortToggle(),
            const SizedBox(height: 4),
            Expanded(
              // Wrapped so the tutorial's completeTrip step can keep this
              // whole area visible (excluded from the dim overlay) instead
              // of tracking one specific list row — a per-row GlobalKey
              // isn't safe here since ReorderableListView can transiently
              // duplicate a row's subtree during its drag/reorder animation.
              child: TutorialTarget(
                id: 'plan_list_area',
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
            ),
            if (_isBudget && widget.budgetItems.isNotEmpty && !_budgetBatchMode)
              _buildBudgetTotalBar(),
            _AnimatedBottomBar(
              mode: _isSmart && _smartBatchMode
                  ? 0
                  : (_isBudget && _budgetBatchMode
                      ? 1
                      : (!_isSmart && !_isBudget && _simpleBatchMode ? 3 : 2)),
              child: _isSmart && _smartBatchMode
                  ? _buildSmartBatchBar()
                  : (_isBudget && _budgetBatchMode
                      ? _buildBudgetBatchBar()
                      : (!_isSmart && !_isBudget && _simpleBatchMode
                          ? _buildSimpleBatchBar()
                          : _buildAddBar(context))),
            ),
          ],
        ),
      ),
    );
  }

}
