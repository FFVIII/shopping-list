import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Small neutral pill for an item's quantity, next to a card's secondary
/// text (estimated days / last bought). Kept visually distinct from a
/// shelf-code chip (which uses the item's own zone color) by staying gray.
class QuantityBadge extends StatelessWidget {
  final String qty;
  const QuantityBadge({super.key, required this.qty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        qty,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
