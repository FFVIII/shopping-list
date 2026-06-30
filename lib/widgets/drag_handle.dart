import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Universal drag handle for all reorderable lists.
///
/// Standard usage:
///   DragHandle(index: i)                      // drag only
///   DragHandle(index: i, onTap: _enterBatch)  // drag + tap (batch mode)
///
/// Wrap in a conditional at the call site when visibility depends on state:
///   if (showHandle) DragHandle(index: i, onTap: fn)
class DragHandle extends StatelessWidget {
  final int index;
  final VoidCallback? onTap;

  const DragHandle({super.key, required this.index, this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget handle = ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: _DragBar(),
      ),
    );
    if (onTap != null) return GestureDetector(onTap: onTap, child: handle);
    return handle;
  }
}

class _DragBar extends StatelessWidget {
  const _DragBar();

  @override
  Widget build(BuildContext context) => Container(
        width: 4,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}
