import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Universal drag handle for all reorderable lists.
///
/// Standard usage:
///   DragHandle(index: i)                      // drag only
///   DragHandle(index: i, onTap: _enterBatch)  // drag + tap (batch mode)
///   DragHandle(onTap: _enterBatch)            // tap-only (non-reorderable list)
///
/// When [index] is null, [ReorderableDragStartListener] is skipped so the
/// widget is safe to use inside plain [ListView] or [Column].
class DragHandle extends StatefulWidget {
  /// Reorder index passed to [ReorderableDragStartListener].
  /// Pass null in non-reorderable contexts to show the bar tap-only.
  final int? index;
  final VoidCallback? onTap;

  const DragHandle({super.key, this.index, this.onTap});

  @override
  State<DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<DragHandle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget bar = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: AnimatedContainer(
        duration: _pressed
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 200),
        width: _pressed ? 6 : 4,
        height: _pressed ? 36 : 28,
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: _pressed ? 1.0 : 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    Widget handle = Listener(
      onPointerDown: (_) {
        if (!mounted) return;
        setState(() => _pressed = true);
        HapticFeedback.mediumImpact();
      },
      onPointerUp: (_) { if (mounted) setState(() => _pressed = false); },
      onPointerCancel: (_) { if (mounted) setState(() => _pressed = false); },
      child: widget.index != null
          ? ReorderableDragStartListener(index: widget.index!, child: bar)
          : bar,
    );

    if (widget.onTap != null) {
      return GestureDetector(onTap: widget.onTap, child: handle);
    }
    return handle;
  }
}
