import 'package:flutter/material.dart';
import '../models/item.dart';
import '../l10n/l10n.dart';

class ReminderScreen extends StatelessWidget {
  final List<InventoryItem> inventoryItems;
  final int thresholdDays;
  final void Function(InventoryItem) onAddToList;
  final VoidCallback onAddAll;

  const ReminderScreen({
    super.key,
    required this.inventoryItems,
    required this.thresholdDays,
    required this.onAddToList,
    required this.onAddAll,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2ED),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
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
                    color: Color(0xFF1A1A1A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.reminderSummary(_restock.length, _expiringSoon.length),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          if (_hasAny)
            GestureDetector(
              onTap: onAddAll,
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
                    color: Color(0xFF424242),
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
          _sectionHeader(l.sectionRestock, const Color(0xFFE53935)),
          ..._restock.map((item) => _ReminderRow(
                item: item,
                thresholdDays: thresholdDays,
                onAddToList: () => onAddToList(item),
              )),
          const SizedBox(height: 16),
        ],
        if (_expiringSoon.isNotEmpty) ...[
          _sectionHeader(l.sectionExpiringSoon, const Color(0xFFFF9800)),
          ..._expiringSoon.map((item) => _ReminderRow(
                item: item,
                thresholdDays: thresholdDays,
                onAddToList: () => onAddToList(item),
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
              color: Color(0xFF1A1A1A),
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
            style: const TextStyle(fontSize: 15, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 4),
          Text(
            l.reminderEmptySubtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final InventoryItem item;
  final int thresholdDays;
  final VoidCallback onAddToList;

  const _ReminderRow({
    required this.item,
    required this.thresholdDays,
    required this.onAddToList,
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final status = item.statusFor(thresholdDays);
    final remaining = item.daysRemaining;
    final displayName = l.data(item.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                    color: Color(0xFF1A1A1A),
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right: button or badge
          if (status == StockStatus.empty)
            GestureDetector(
              onTap: onAddToList,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
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
              ),
            )
          else
            GestureDetector(
              onTap: onAddToList,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l.daysShortApprox(remaining),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
