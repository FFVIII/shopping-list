import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/drag_handle.dart';
import '../widgets/sort_toggle_button.dart';
import '../l10n/l10n.dart';
import '../l10n/canonical_edit.dart';
import '../widgets/batch_bar.dart';

class ShelfOrderScreen extends StatefulWidget {
  final List<String> shelfCodes;
  final void Function(int oldIndex, int newIndex) onReorderCodes;
  final void Function(String code) onAddCode;
  final void Function(String code) onDeleteCode;
  final void Function(String oldCode, String newCode) onRenameCode;

  const ShelfOrderScreen({
    super.key,
    required this.shelfCodes,
    required this.onReorderCodes,
    required this.onAddCode,
    required this.onDeleteCode,
    required this.onRenameCode,
  });

  @override
  State<ShelfOrderScreen> createState() => _ShelfOrderScreenState();
}

class _ShelfOrderScreenState extends State<ShelfOrderScreen> {
  late List<String> _codes;
  SortDir? _sortDir;
  bool _batchMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _codes = List<String>.from(widget.shelfCodes);
  }

  @override
  void didUpdateWidget(ShelfOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shelfCodes != widget.shelfCodes) {
      _codes = List<String>.from(widget.shelfCodes);
    }
  }

  List<String> get _displayCodes {
    if (_sortDir == null) return _codes;
    final sorted = [..._codes];
    sorted.sort((a, b) =>
        _sortDir == SortDir.asc ? a.compareTo(b) : b.compareTo(a));
    return sorted;
  }

  void _handleReorder(int oldIndex, int newIndex) {
    HapticFeedback.lightImpact();
    final wasUnsorted = _sortDir == null;
    final reordered = List<String>.from(_displayCodes);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() {
      _codes = reordered;
      _sortDir = null;
    });
    if (wasUnsorted) widget.onReorderCodes(oldIndex, newIndex);
  }

  void _openRename(String code) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RenameShelfCodeSheet(
        initial: code,
        onSubmit: (newCode) {
          if (newCode == code) return;
          if (_codes.contains(newCode)) return;
          widget.onRenameCode(code, newCode);
          setState(() {
            final idx = _codes.indexOf(code);
            if (idx != -1) {
              final updated = List<String>.from(_codes);
              updated[idx] = newCode;
              _codes = updated;
            }
          });
        },
      ),
    );
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddShelfCodeSheet(
        onSubmit: (code) {
          if (_codes.contains(code)) return;
          widget.onAddCode(code);
          setState(() => _codes = [..._codes, code]);
        },
      ),
    );
  }

  Future<void> _batchDelete() async {
    final l = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.selectedCount(_selected.length)),
        content: Text(l.deleteShelfCodeMessage),
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
    for (final code in _selected) {
      widget.onDeleteCode(code);
    }
    setState(() {
      _codes = _codes.where((c) => !_selected.contains(c)).toList();
      _selected.clear();
      _batchMode = false;
    });
  }

  Widget _buildBatchBar() {
    final allSelected =
        _codes.isNotEmpty && _selected.containsAll(_codes.toSet());
    final hasSelection = _selected.isNotEmpty;

    return BatchBar(
      selectedCount: _selected.length,
      showCountLabel: true,
      allSelected: allSelected,
      onToggleAll: () => setState(() {
        if (allSelected) {
          _selected.clear();
        } else {
          _selected.addAll(_codes);
        }
      }),
      onDelete: hasSelection ? _batchDelete : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final displayed = _displayCodes;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          l.shelfOrder,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_batchMode)
            IconButton(
              onPressed: () => setState(() {
                _batchMode = false;
                _selected.clear();
              }),
              icon: const Icon(Icons.close_rounded),
            )
          else ...[
            IconButton(
              onPressed: () => setState(() => _sortDir = _sortDir == null
                  ? SortDir.asc
                  : _sortDir == SortDir.asc
                      ? SortDir.desc
                      : null),
              icon: Icon(
                Icons.sort_rounded,
                color: _sortDir != null ? AppColors.brand : AppColors.textMuted,
              ),
              tooltip: _sortDir == SortDir.asc
                  ? 'A→Z'
                  : _sortDir == SortDir.desc
                      ? 'Z→A'
                      : l.shelfOrder,
            ),
            IconButton(
              onPressed: _openAdd,
              icon: const Icon(Icons.add_rounded),
              tooltip: l.addShelfCodeTitle,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: displayed.isEmpty
                  ? Center(
                      child: Text(
                        l.noShelfCodes,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: displayed.length,
                      buildDefaultDragHandles: false,
                      onReorderItem: _handleReorder,
                      proxyDecorator: (child, index, animation) => Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        shadowColor: Colors.black26,
                        child: child,
                      ),
                      itemBuilder: (ctx, i) {
                        final code = displayed[i];
                        final isSelected = _selected.contains(code);
                        return Container(
                          key: ValueKey('code_$code'),
                          margin: const EdgeInsets.only(bottom: 8),
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
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _batchMode
                                ? () => setState(() {
                                      if (isSelected) {
                                        _selected.remove(code);
                                      } else {
                                        _selected.add(code);
                                      }
                                    })
                                : () => _openRename(code),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  if (_batchMode)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 10),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        size: 20,
                                        color: isSelected
                                            ? AppColors.brand
                                            : AppColors.textDisabled,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      l.data(code),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  DragHandle(
                                    index: i,
                                    onTap: () => setState(() {
                                      _batchMode = true;
                                      _selected.add(code);
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_batchMode) _buildBatchBar(),
          ],
        ),
      ),
    );
  }
}

// ── Rename shelf code sheet ──────────────────────────────────────────────────

class _RenameShelfCodeSheet extends StatefulWidget {
  final String initial;
  final void Function(String newCode) onSubmit;
  const _RenameShelfCodeSheet({required this.initial, required this.onSubmit});

  @override
  State<_RenameShelfCodeSheet> createState() => _RenameShelfCodeSheetState();
}

class _RenameShelfCodeSheetState extends State<_RenameShelfCodeSheet> {
  late final TextEditingController _ctrl;
  bool _textInitialized = false;
  late String _display;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_textInitialized) {
      _display = canonicalDisplay(L10n.of(context), widget.initial);
      _ctrl.text = _display;
      _textInitialized = true;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = _ctrl.text.trim();
    if (typed.isEmpty) return;
    final code = resolveCanonicalEdit(typed, _display, widget.initial);
    Navigator.pop(context);
    widget.onSubmit(code);
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
              hintText: l.shelfCodeNameHint,
              hintStyle: const TextStyle(color: AppColors.textDisabled),
              filled: true,
              fillColor: AppColors.fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _submit,
            child: Text(
              l.rename,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add shelf code sheet ─────────────────────────────────────────────────────

class _AddShelfCodeSheet extends StatefulWidget {
  final void Function(String code) onSubmit;
  const _AddShelfCodeSheet({required this.onSubmit});

  @override
  State<_AddShelfCodeSheet> createState() => _AddShelfCodeSheetState();
}

class _AddShelfCodeSheetState extends State<_AddShelfCodeSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    Navigator.pop(context);
    widget.onSubmit(code);
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
            l.addShelfCodeTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: l.shelfCodeNameHint,
              hintStyle: const TextStyle(color: AppColors.textDisabled),
              filled: true,
              fillColor: AppColors.fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: _submit,
            child: Text(
              l.addShelfCodeTitle,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
