part of 'list_screen.dart';

// ── Header / empty state / add bar (extracted for file size) ────────────────

extension _HeaderAndAddBarState on _ListScreenState {
  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
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
                  _isSmart
                      ? l.modeSmart
                      : (_isBudget ? l.budgetMode : l.modeSimple),
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
          if (_isSmart && _smartBatchMode)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              // Always tappable — saving an empty selection ("I want nothing
              // checked for the next trip") is a valid, intended action.
              child: GestureDetector(
                onTap: _saveSmartBatch,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.batchSave,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if ((_isSmart && widget.smartItems.isNotEmpty) ||
              (!_isSmart &&
                  !_isBudget &&
                  widget.simpleItems.any((i) => i.checked)))
            TutorialTarget(
              id: 'complete_trip_button',
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: GestureDetector(
                  onTap: _confirmCompleteTrip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _isSmart ? AppColors.brand : AppColors.danger,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isSmart ? l.addToInventoryButton : l.clearBudget,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (_isBudget && widget.budgetItems.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: GestureDetector(
                onTap: _confirmClearBudget,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l.clearBudget,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (!_isBudget && _ListScreenState._voiceInputEnabled)
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
              focusNode: _nameFocus,
              maxLength: 30,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: _isListening
                    ? l.listeningHint
                    : _isBudget
                    ? l.budgetAddHint
                    : (_isSmart ? l.smartAddHint : l.simpleAddHint),
                hintStyle: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                isDense: true,
                counterText: '',
              ),
              onSubmitted: (value) {
                // The keyboard's return key just means "close the
                // keyboard" when the field is empty — only treat it as a
                // submit when there's actually a name to add.
                if (value.trim().isEmpty) {
                  _nameFocus.unfocus();
                  return;
                }
                _submitAdd(context);
              },
            ),
          ),
          const SizedBox(width: 10),
          TutorialTarget(
            id: 'add_button',
            child: GestureDetector(
              onTap: () => _submitAdd(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
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
              shelfCodeOrder: widget.shelfCodeOrder,
              onAddCategory: widget.onAddCategory,
              onConfirm: (name, quantity, shelfCode, category, unitPrice) {
                widget.onEditSmart(
                  item.id,
                  name,
                  quantity,
                  shelfCode,
                  category,
                  unitPrice: unitPrice,
                );
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

    if (name.isEmpty) {
      showAppToast(context, L10n.of(context).addItemNameRequired);
      return;
    }

    if (_isBudget) {
      // Budget: open the expense sheet (name prefilled from the bar).
      _showBudgetSheet(initialName: name);
      _nameCtrl.clear();
      return;
    }

    if (_isSmart) {
      // Smart: show category picker sheet
      _showSmartAddSheet(context, name);
    } else {
      // Simple: just add directly, no category needed
      widget.onAddSimple(name);
      _nameCtrl.clear();
      // Keep the keyboard open for rapid consecutive entries instead of
      // letting the OS dismiss it after the submit action.
      _nameFocus.requestFocus();
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
        shelfCodeOrder: widget.shelfCodeOrder,
        onAddCategory: widget.onAddCategory,
        onConfirm:
            (category, quantityLabel, shelfCode, estimatedDays, unitPrice) {
              widget.onAddSmart(
                name,
                quantityLabel,
                shelfCode,
                estimatedDays,
                category,
                unitPrice: unitPrice,
              );
              _nameCtrl.clear();
            },
      ),
    );
  }

  // ── 滑动删除：先隐藏 + 显示"撤销"提示，超时后才真正删除 ──────────────────────

  void _handleSwipeDelete({
    required String id,
    required String label,
    required VoidCallback realDelete,
  }) {
    final l = L10n.of(context);
    // False positive: this extension method runs on the real
    // _ListScreenState instance, but the analyzer doesn't treat extension
    // bodies as members of the extended class.
    // ignore: invalid_use_of_protected_member
    setState(() => _pendingDeleteIds.add(id));
    showUndoToast(
      context,
      message: l.itemDeletedToast(label),
      actionLabel: l.undo,
      onAction: () {
        // ignore: invalid_use_of_protected_member
        if (mounted) setState(() => _pendingDeleteIds.remove(id));
      },
      onTimeout: () {
        realDelete();
        // ignore: invalid_use_of_protected_member
        if (mounted) setState(() => _pendingDeleteIds.remove(id));
      },
    );
  }
}
