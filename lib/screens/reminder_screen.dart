import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';
import '../l10n/app_strings.dart';
import '../widgets/toast.dart';
import '../widgets/hint_banner.dart';

class ReminderScreen extends StatelessWidget {
  final List<InventoryItem> inventoryItems;
  final int thresholdDays;
  final void Function(InventoryItem) onAddToList;
  final void Function(InventoryItem) onRemoveFromList;
  final VoidCallback onAddAll;

  /// Names of items currently in the (unchecked) shopping list. Used to show
  /// the "already in list" state and to avoid silent no-op taps.
  final Set<String> activeListNames;

  final Set<String> dismissedHints;
  final void Function(String id) onDismissHint;

  const ReminderScreen({
    super.key,
    required this.inventoryItems,
    required this.thresholdDays,
    required this.onAddToList,
    required this.onRemoveFromList,
    required this.onAddAll,
    required this.activeListNames,
    required this.dismissedHints,
    required this.onDismissHint,
  });

  // Items with 0 days → "该补货"
  List<InventoryItem> get _restock => inventoryItems
      .where((i) => i.statusFor(thresholdDays) == StockStatus.empty)
      .toList();

  // Items with days > 0 but ≤ threshold → "即将用完"
  List<InventoryItem> get _expiringSoon => inventoryItems
      .where((i) => i.statusFor(thresholdDays) == StockStatus.low)
      .toList();

  bool get _hasAny => _restock.isNotEmpty || _expiringSoon.isNotEmpty;

  bool _inList(InventoryItem item) => activeListNames.contains(item.name);

  void _toast(BuildContext context, String message) {
    showAppToast(context, message);
  }

  void _handleToggle(BuildContext context, InventoryItem item) {
    final l = L10n.of(context);
    if (_inList(item)) {
      onRemoveFromList(item);
      _toast(context, l.removedFromListToast);
    } else {
      onAddToList(item);
      _toast(context, l.addedToListToast);
    }
  }

  void _handleAddAll(BuildContext context) {
    final l = L10n.of(context);
    final toAddCount = [..._restock, ..._expiringSoon]
        .where((i) => !_inList(i))
        .length;
    if (toAddCount == 0) {
      _toast(context, l.allAlreadyInList);
      return;
    }
    onAddAll();
    _toast(context, l.addedAllToListToast(toAddCount));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (!dismissedHints.contains('reminder_hint'))
              HintBanner(
                text: L10n.of(context).reminderHint,
                onDismiss: () => onDismissHint('reminder_hint'),
              ),
            Expanded(
              child: _hasAny ? _buildList(context) : _emptyState(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.reminderTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.reminderSummary(_restock.length, _expiringSoon.length),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_hasAny)
            GestureDetector(
              onTap: () => _handleAddAll(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEE8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l.addAll,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textChip,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l = L10n.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        if (_restock.isNotEmpty) ...[
          _sectionHeader(l.sectionRestock, AppColors.danger),
          ..._restock.map((item) => _ReminderRow(
                item: item,
                thresholdDays: thresholdDays,
                inList: _inList(item),
                onTap: () => _handleToggle(context, item),
              )),
          const SizedBox(height: 16),
        ],
        if (_expiringSoon.isNotEmpty) ...[
          _sectionHeader(l.sectionExpiringSoon, const Color(0xFFFF9800)),
          ..._expiringSoon.map((item) => _ReminderRow(
                item: item,
                thresholdDays: thresholdDays,
                inList: _inList(item),
                onTap: () => _handleToggle(context, item),
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final l = L10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            l.reminderEmptyTitle,
            style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            l.reminderEmptySubtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final InventoryItem item;
  final int thresholdDays;
  final bool inList;
  final VoidCallback onTap;

  const _ReminderRow({
    required this.item,
    required this.thresholdDays,
    required this.inList,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final status = item.statusFor(thresholdDays);
    final remaining = item.daysRemaining;
    final displayName = l.data(item.name);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.category.bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: displayName.length > 2 ? 10 : 13,
                    fontWeight: FontWeight.w600,
                    color: item.category.color.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + hint
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status == StockStatus.empty
                        ? l.usedUpNeedRestock
                        : l.daysLeftApprox(remaining),
                    style: TextStyle(
                      fontSize: 12,
                      color: status.color,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right: "in list" state or "add" action
            inList ? _inListPill(l) : _addPill(l),
          ],
        ),
      ),
    );
  }

  Widget _addPill(AppStrings l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        l.add,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _inListPill(AppStrings l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEE8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            l.alreadyInList,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
