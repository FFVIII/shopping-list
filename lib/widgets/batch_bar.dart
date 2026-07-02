import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../l10n/l10n.dart';

/// A single extra action pill rendered in the BatchBar.
class BatchBarAction {
  final String label;
  final Color color;
  final VoidCallback? onTap; // null = disabled

  const BatchBarAction({
    required this.label,
    required this.color,
    this.onTap,
  });
}

/// Shared bottom bar for batch-select mode.
///
/// Layout: [SelectAll] [extraActions…] [Spacer] [Cancel?] [Delete]
/// SelectAll always sits on the far left; Cancel (when present) and Delete
/// are grouped together on the far right, in that order.
class BatchBar extends StatelessWidget {
  final int selectedCount;
  final bool showCountLabel;
  final bool allSelected;
  final VoidCallback onToggleAll;

  /// null = delete button is disabled (no items selected).
  /// Pass an async VoidCallback to show a confirmation dialog before deleting.
  final VoidCallback? onDelete;

  /// If set, a Cancel pill appears next to Delete to exit batch mode.
  final VoidCallback? onCancel;

  /// Extra action pills inserted after SelectAll, before the spacer/Delete.
  final List<BatchBarAction> extraActions;

  const BatchBar({
    super.key,
    required this.selectedCount,
    this.showCountLabel = false,
    required this.allSelected,
    required this.onToggleAll,
    this.onDelete,
    this.onCancel,
    this.extraActions = const [],
  });

  Widget _pill(String text, Color textColor, Color bgColor, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final hasSelection = onDelete != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCountLabel) ...[
            Text(
              l.selectedCount(selectedCount),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              _pill(
                l.selectAll,
                allSelected ? AppColors.brand : AppColors.textSecondary,
                allSelected ? AppColors.brand.withValues(alpha: 0.12) : AppColors.fieldBg,
                onToggleAll,
              ),
              for (final action in extraActions) ...[
                const SizedBox(width: 8),
                _pill(
                  action.label,
                  action.onTap != null ? action.color : AppColors.textDisabled,
                  action.onTap != null ? action.color.withValues(alpha: 0.12) : AppColors.fieldBg,
                  action.onTap,
                ),
              ],
              const Spacer(),
              if (onCancel != null) ...[
                _pill(l.cancel, AppColors.textSecondary, AppColors.fieldBg, onCancel),
                const SizedBox(width: 8),
              ],
              _pill(
                l.delete,
                hasSelection ? AppColors.danger : AppColors.textDisabled,
                hasSelection ? AppColors.danger.withValues(alpha: 0.10) : AppColors.fieldBg,
                onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
