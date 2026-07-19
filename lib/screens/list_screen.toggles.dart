part of 'list_screen.dart';

// Extension methods live outside the State subclass, so calls to the
// protected setState() would otherwise trip invalid_use_of_protected_member.
// ignore_for_file: invalid_use_of_protected_member

extension _ListToggles on _ListScreenState {
  // ── Mode toggles ─────────────────────────────────────────────────────────────

  void _setMode(ListMode mode) {
    setState(() => _mode = mode);
    NavigationStore.saveListMode(mode.index);
  }

  Widget _buildModeToggle() {
    final l = L10n.of(context);
    const modeCount = 3;
    final selectedIndex = switch (_mode) {
      ListMode.simple => 0,
      ListMode.budget => 1,
      ListMode.smart => 2,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              _SegmentIndicator(
                selectedIndex: selectedIndex,
                segmentWidth: constraints.maxWidth / modeCount,
              ),
              Row(
                children: [
                  _SegmentBtn(
                    label: l.modeSimple,
                    selected: _mode == ListMode.simple,
                    onTap: () => _setMode(ListMode.simple),
                  ),
                  _SegmentBtn(
                    label: l.budgetMode,
                    selected: _mode == ListMode.budget,
                    onTap: () => _setMode(ListMode.budget),
                  ),
                  _SegmentBtn(
                    label: l.modeSmart,
                    selected: _mode == ListMode.smart,
                    onTap: () => _setMode(ListMode.smart),
                  ),
                ],
              ),
            ],
          ),
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
          _TextToggleBtn(
            label: l.byCategory,
            selected: _smartGroup == SmartGroupMode.category,
            direction: _smartGroup == SmartGroupMode.category
                ? _smartGroupDir
                : null,
            onTap: () => setState(() {
              if (_smartGroup != SmartGroupMode.category) {
                _smartGroup = SmartGroupMode.category;
                _smartGroupDir = SortDir.asc;
              } else if (_smartGroupDir == SortDir.asc) {
                _smartGroupDir = SortDir.desc;
              } else {
                _smartGroup = SmartGroupMode.manual;
              }
            }),
          ),
          const SizedBox(width: 4),
          _TextToggleBtn(
            label: l.byShelf,
            selected: _smartGroup == SmartGroupMode.shelf,
            direction: _smartGroup == SmartGroupMode.shelf
                ? _smartGroupDir
                : null,
            onTap: () => setState(() {
              if (_smartGroup != SmartGroupMode.shelf) {
                _smartGroup = SmartGroupMode.shelf;
                _smartGroupDir = SortDir.asc;
              } else if (_smartGroupDir == SortDir.asc) {
                _smartGroupDir = SortDir.desc;
              } else {
                _smartGroup = SmartGroupMode.manual;
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSortToggle() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          _TextToggleBtn(
            label: l.sortByName,
            selected: _simpleDir != null,
            direction: _simpleDir,
            onTap: () => setState(() => _simpleDir = _cycleDir(_simpleDir)),
          ),
        ],
      ),
    );
  }

  // off → asc → desc → off, for a single-key value sort (nullable direction).
  SortDir? _cycleDir(SortDir? current) => current == null
      ? SortDir.asc
      : current == SortDir.asc
      ? SortDir.desc
      : null;

  // Cycle a multi-key value sort. Tapping a different key activates it ascending;
  // tapping the active key cycles asc → desc → off.
  void _cycleBudgetSort(BudgetSortMode mode) {
    if (_budgetSort != mode) {
      _budgetSort = mode;
      _budgetDir = SortDir.asc;
    } else if (_budgetDir == SortDir.asc) {
      _budgetDir = SortDir.desc;
    } else {
      _budgetSort = BudgetSortMode.manual;
    }
  }

  Widget _buildBudgetSortToggle() {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          _TextToggleBtn(
            label: l.sortByName,
            selected: _budgetSort == BudgetSortMode.name,
            direction: _budgetSort == BudgetSortMode.name ? _budgetDir : null,
            onTap: () => setState(() => _cycleBudgetSort(BudgetSortMode.name)),
          ),
          const SizedBox(width: 4),
          _TextToggleBtn(
            label: l.sortByPrice,
            selected: _budgetSort == BudgetSortMode.price,
            direction: _budgetSort == BudgetSortMode.price ? _budgetDir : null,
            onTap: () => setState(() => _cycleBudgetSort(BudgetSortMode.price)),
          ),
        ],
      ),
    );
  }
}
