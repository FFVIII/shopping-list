import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A lightweight, self-contained toast shown in the root [Overlay].
///
/// Unlike `ScaffoldMessenger`'s SnackBar, this does not interact with the
/// Scaffold/semantics machinery, so it avoids the `!semantics.parentDataDirty`
/// assertion that SnackBars can trigger inside nested Scaffolds when an
/// accessibility / semantics service is active.
OverlayEntry? _activeToast;
Timer? _toastTimer;

void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  // Replace any toast currently on screen.
  _toastTimer?.cancel();
  _activeToast?.remove();
  _activeToast = null;

  final entry = OverlayEntry(
    // Dead center, same as the undo toast below — a bottom-anchored toast
    // ends up hidden behind the keyboard whenever one is up, no matter how
    // much viewInsets padding is added.
    builder: (ctx) => Positioned.fill(
      child: IgnorePointer(
        child: Center(child: _ToastCard(message: message)),
      ),
    ),
  );

  overlay.insert(entry);
  _activeToast = entry;
  _toastTimer = Timer(const Duration(milliseconds: 1500), () {
    entry.remove();
    if (identical(_activeToast, entry)) _activeToast = null;
  });
}

OverlayEntry? _activeUndoToast;
Timer? _undoTimer;
VoidCallback? _pendingUndoCommit;

/// A toast with an action button (e.g. "Undo"), shown for [duration]. If a
/// new undo toast is requested while one is still showing, the previous
/// one's [onTimeout] fires immediately (its grace period is over) before the
/// new one appears.
void showUndoToast(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  required VoidCallback onTimeout,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) {
    onTimeout();
    return;
  }

  _undoTimer?.cancel();
  _activeUndoToast?.remove();
  _activeUndoToast = null;
  _pendingUndoCommit?.call();
  _pendingUndoCommit = null;

  late final OverlayEntry entry;
  void dismiss() {
    _undoTimer?.cancel();
    if (identical(_activeUndoToast, entry)) {
      _activeUndoToast = null;
      _pendingUndoCommit = null;
    }
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) => Positioned.fill(
      child: Center(
        child: _UndoToastCard(
          message: message,
          actionLabel: actionLabel,
          onAction: () {
            dismiss();
            onAction();
          },
        ),
      ),
    ),
  );

  overlay.insert(entry);
  _activeUndoToast = entry;
  _pendingUndoCommit = onTimeout;
  _undoTimer = Timer(duration, () {
    dismiss();
    onTimeout();
  });
}

class _UndoToastCard extends StatefulWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  const _UndoToastCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  State<_UndoToastCard> createState() => _UndoToastCardState();
}

class _UndoToastCardState extends State<_UndoToastCard> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 11, 8, 11),
          decoration: BoxDecoration(
            color: const Color(0xFF313131).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: widget.onAction,
                child: Text(
                  widget.actionLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8BD17C),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  final String message;
  const _ToastCard({required this.message});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF313131).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            widget.message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// A brief animated checkmark + caption shown center-screen in the root
/// [Overlay] — the "done!" moment after completing a shopping trip.
/// Self-dismisses once its animation finishes (~900ms); does not block input.
void showCompletionCelebration(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: _CelebrationCard(
            message: message,
            onDone: () => entry.remove(),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

class _CelebrationCard extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  const _CelebrationCard({required this.message, required this.onDone});

  @override
  State<_CelebrationCard> createState() => _CelebrationCardState();
}

class _CelebrationCardState extends State<_CelebrationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Weights are ms-out-of-1500: pop-in and settle stay snappy (same
    // absolute timing as before), the extra time all goes into the hold.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.4,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 24,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 9),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 9),
    ]).animate(_controller);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 9),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 71),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8BD17C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
