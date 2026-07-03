import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Direction of a value sort. A non-null value means the sort is active and
/// shows an ascending/descending arrow; value sorts cycle off → asc → desc → off.
enum SortDir { asc, desc }

/// Pill-style toggle button used for all list sort/group selectors.
///
/// Selected = brand-tinted pill; unselected = transparent.
/// Supports deselect at the call site (tap selected → toggle off).
/// When [direction] is non-null and the pill is selected, an up/down arrow
/// is shown to indicate ascending/descending order.
class SortToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final SortDir? direction;

  const SortToggleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.direction,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
            if (selected && direction != null) ...[
              const SizedBox(width: 2),
              Icon(
                direction == SortDir.asc
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 13,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
