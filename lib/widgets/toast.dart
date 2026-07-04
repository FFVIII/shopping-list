import 'dart:async';
import 'package:flutter/material.dart';

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
    builder: (ctx) => Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(ctx).padding.bottom + 80,
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
