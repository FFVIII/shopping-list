import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/item.dart';
import '../theme/app_colors.dart';

class SpendingHistoryScreen extends StatelessWidget {
  final List<BudgetHistoryEntry> budgetHistory;
  final void Function(String id) onDeleteEntry;

  const SpendingHistoryScreen({
    super.key,
    required this.budgetHistory,
    required this.onDeleteEntry,
  });

  double _monthTotal() {
    final now = DateTime.now();
    return budgetHistory
        .where((e) =>
            e.clearedAt.year == now.year && e.clearedAt.month == now.month)
        .fold(0.0, (sum, e) => sum + e.totalAmount);
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final l = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteHistoryEntryTitle),
        content: Text(l.deleteHistoryEntryMessage),
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
    if (ok == true) onDeleteEntry(id);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: Text(l.spendingHistory)),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              l.spendingHistoryMonthTotal(l.money(_monthTotal())),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
          ),
          Expanded(
            child: budgetHistory.isEmpty
                ? Center(
                    child: Text(
                      l.spendingHistoryEmpty,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: budgetHistory.length,
                    itemBuilder: (ctx, i) {
                      final entry = budgetHistory[i];
                      return ExpansionTile(
                        key: Key('history_${entry.id}'),
                        title: Text(_formatDate(entry.clearedAt)),
                        subtitle: Text(l.money(entry.totalAmount)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.danger),
                          onPressed: () => _confirmDelete(context, entry.id),
                        ),
                        children: entry.items
                            .map((i) => ListTile(
                                  title: Text('${i.name} × ${i.quantity}'),
                                  trailing: Text(l.money(i.unitPrice)),
                                ))
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
