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
          ),
        ),
      ),
    );
  }
}
