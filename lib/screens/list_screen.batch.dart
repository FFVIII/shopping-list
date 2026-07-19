part of 'list_screen.dart';

// Extension methods live outside the State subclass, so calls to the
// protected setState() would otherwise trip invalid_use_of_protected_member.
// ignore_for_file: invalid_use_of_protected_member

// ── Batch selection + batch action bars (smart / budget) ─────────────────────

extension _ListBatch on _ListScreenState {
  void _enterSimpleBatchWithItem(String id) {
    setState(() {
      _simpleBatchMode = true;
      _simpleSelected.add(id);
    });
  }

  void _toggleSimpleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_simpleSelected.contains(id)) {
        _simpleSelected.remove(id);
      } else {
        _simpleSelected.add(id);
      }
    });
  }

  Widget _buildSimpleBatchBar() {
    final l = L10n.of(context);
    final allIds = widget.simpleItems.map((i) => i.id).toSet();
    final allSelected =
        allIds.isNotEmpty && _simpleSelected.containsAll(allIds);
    final hasSelection = _simpleSelected.isNotEmpty;

    return BatchBar(
      allSelected: allSelected,
      selectedCount: _simpleSelected.length,
      showCountLabel: true,
      onCancel: () => setState(() {
        _simpleBatchMode = false;
        _simpleSelected.clear();
      }),
      onToggleAll: () => setState(() {
        if (allSelected) {
          _simpleSelected.clear();
        } else {
          _simpleSelected.addAll(allIds);
        }
      }),
      onDelete: hasSelection
          ? () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.selectedCount(_simpleSelected.length)),
                  content: Text(l.deleteConfirmMessage),
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
              widget.onBatchDeleteSimple(_simpleSelected.toList());
              setState(() {
                _simpleSelected.clear();
                _simpleBatchMode = false;
              });
            }
          : null,
    );
  }

  // Commits the batch-mode selection to the outer trip-selection circles and
  // exits batch mode. This does NOT purchase or add anything to inventory —
  // it only persists "which items are checked". The trip-selection is what the
  // "Add" button later reads to actually complete a trip; Save just makes the
  // outer checkmarks match exactly what was checked in batch mode.
  void _saveSmartBatch() {
    setState(() {
      _tripSelected
        ..clear()
        ..addAll(_smartSelected);
      _smartBatchMode = false;
    });
    HapticFeedback.selectionClick();
  }

  void _enterSmartBatchWithItem(String id) {
    // _smartSelected is not reset here — it already carries over whatever
    // was left checked/unchecked from the last time batch mode was used
    // (kept in sync by didUpdateWidget), so re-entering doesn't wipe out
    // previous deselections.
    setState(() => _smartBatchMode = true);
  }

  void _toggleSmartSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_smartSelected.contains(id)) {
        _smartSelected.remove(id);
      } else {
        _smartSelected.add(id);
      }
    });
  }

  void _toggleTripSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_tripSelected.contains(id)) {
        _tripSelected.remove(id);
      } else {
        _tripSelected.add(id);
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
    HapticFeedback.selectionClick();
    setState(() {
      if (_budgetSelected.contains(id)) {
        _budgetSelected.remove(id);
      } else {
        _budgetSelected.add(id);
      }
    });
  }

  Widget _buildBudgetBatchBar() {
    final l = L10n.of(context);
    final allIds = widget.budgetItems.map((i) => i.id).toSet();
    final allSelected =
        allIds.isNotEmpty && _budgetSelected.containsAll(allIds);
    final hasSelection = _budgetSelected.isNotEmpty;

    return BatchBar(
      allSelected: allSelected,
      selectedCount: _budgetSelected.length,
      showCountLabel: true,
      onCancel: () => setState(() {
        _budgetBatchMode = false;
        _budgetSelected.clear();
      }),
      onToggleAll: () => setState(() {
        if (allSelected) {
          _budgetSelected.clear();
        } else {
          _budgetSelected.addAll(allIds);
        }
      }),
      onDelete: hasSelection
          ? () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.selectedCount(_budgetSelected.length)),
                  content: Text(l.deleteConfirmMessage),
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
              widget.onBatchDeleteBudget(_budgetSelected.toList());
              setState(() {
                _budgetSelected.clear();
                _budgetBatchMode = false;
              });
            }
          : null,
    );
  }

  // ── Smart batch bar ──────────────────────────────────────────────────────────

  Widget _buildSmartBatchBar() {
    final l = L10n.of(context);
    final allIds = widget.smartItems.map((i) => i.id).toSet();
    final allSelected = allIds.isNotEmpty && _smartSelected.containsAll(allIds);
    final hasSelection = _smartSelected.isNotEmpty;

    return BatchBar(
      allSelected: allSelected,
      selectedCount: _smartSelected.length,
      onCancel: () => setState(() => _smartBatchMode = false),
      onToggleAll: () => setState(() {
        if (allSelected) {
          _smartSelected.clear();
        } else {
          _smartSelected.addAll(allIds);
        }
      }),
      onDelete: hasSelection
          ? () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.selectedCount(_smartSelected.length)),
                  content: Text(l.deleteConfirmMessage),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.delete),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              final deletedIds = _smartSelected.toList();
              widget.onBatchDeleteSmart(deletedIds);
              setState(() {
                // Only drop the deleted ids — items left unselected must
                // keep their state for the next time batch mode opens.
                _smartSelected.removeAll(deletedIds);
                _knownSmartBatchIds.removeAll(deletedIds);
                _smartBatchMode = false;
              });
            }
          : null,
    );
  }
}
