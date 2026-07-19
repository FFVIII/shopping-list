import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/tutorial_controller.dart';
import '../services/tutorial_store.dart';
import '../theme/app_colors.dart';
import 'tutorial_target.dart';

/// Renders the coach-mark spotlight for the first-run onboarding tutorial: a
/// hand-drawn oval outline circles the real on-screen target, a dashed arrow
/// connects it to a text bubble, and a single full-screen dim layer covers
/// everything — including the target itself, so there's no bright cutout to
/// rely on. Taps still only pass through at the target (via invisible
/// blockers elsewhere). Wraps the app's Navigator output via
/// `MaterialApp.builder` so the overlay stays on top of modal bottom sheets,
/// which are pushed as routes on that same Navigator.
class TutorialOverlay extends StatefulWidget {
  final Widget child;
  const TutorialOverlay({super.key, required this.child});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  // No entry for TutorialStep.viewInventory on purpose: completing the trip
  // already shows the app's own "trip completed" celebration toast, so
  // spotlighting the Inventory tab at the same moment competes with it and
  // reads as "you're already done" to a new user. Instead, render nothing
  // during this step (see the `targetRect == null` fallback in build()) and
  // let TutorialController.onTabChanged silently advance to finalMessage
  // once the user navigates to Inventory on their own.
  static const Map<TutorialStep, List<String>> _candidateIds = {
    TutorialStep.addItem: ['confirm_add_button', 'add_button'],
    TutorialStep.completeTrip: ['confirm_trip_button', 'complete_trip_button'],
  };

  /// Vertical gap between the target and the tooltip bubble, and between
  /// the target and the arrow's starting point.
  static const double _bubbleGap = 28;

  /// How much bigger the hand-drawn oval is than the real target rect.
  static const double _ovalPadding = 10;

  Rect? _targetRect;

  /// The plan-list content area during the completeTrip step, kept visible
  /// (excluded from the dim layer) so the user can still see the example
  /// item they just added. Null on every other step.
  Rect? _extraVisibleRect;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    TutorialController.instance.addListener(_onControllerChanged);
    _scheduleFrameCheck();
  }

  @override
  void dispose() {
    TutorialController.instance.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleFrameCheck();
  }

  void _scheduleFrameCheck() {
    if (_polling || TutorialController.instance.step == TutorialStep.done) {
      return;
    }
    _polling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _polling = false;
      if (!mounted) return;
      final rect = _findTargetRect();
      final extraRect = _findExtraVisibleRect();
      if (rect != _targetRect || extraRect != _extraVisibleRect) {
        setState(() {
          _targetRect = rect;
          _extraVisibleRect = extraRect;
        });
      }
      _scheduleFrameCheck();
    });
  }

  /// Which candidate id `_targetRect` actually resolved to, set by
  /// `_findTargetRect`. Used by `_findExtraVisibleRect` to tell whether the
  /// completeTrip step is still showing the header's "complete trip" pill
  /// (sheet not open yet) or has moved on to the sheet's own confirm button
  /// (sheet open) — the plan-list exemption below only makes sense in the
  /// former case; once the sheet is open, it sits on top of the plan list
  /// and punching a hole there would show through the sheet's own content
  /// in a confusing, patchy way.
  String? _matchedTargetId;

  Rect? _findTargetRect() {
    if (TutorialController.instance.step == TutorialStep.finalMessage) {
      // The inventory list uses a ReorderableListView, so its item can't
      // safely carry a GlobalKey (see TutorialRectReporter's doc comment) —
      // it reports its rect into TutorialRectRegistry instead.
      _matchedTargetId = null;
      return TutorialRectRegistry.rectFor('example_inventory_item');
    }
    if (TutorialController.instance.step == TutorialStep.itemAdded) {
      // Same reasoning as above: the Plan list is also a
      // ReorderableListView, so the newly-added example item reports its
      // rect rather than carrying a GlobalKey.
      _matchedTargetId = null;
      return TutorialRectRegistry.rectFor('example_smart_item');
    }
    final ids = _candidateIds[TutorialController.instance.step];
    if (ids == null) {
      _matchedTargetId = null;
      return null;
    }
    for (final id in ids) {
      final renderObject = TutorialRegistry.keyFor(
        id,
      ).currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.attached) {
        final topLeft = renderObject.localToGlobal(Offset.zero);
        _matchedTargetId = id;
        return topLeft & renderObject.size;
      }
    }
    _matchedTargetId = null;
    return null;
  }

  Rect? _findExtraVisibleRect() {
    if (TutorialController.instance.step != TutorialStep.completeTrip) {
      return null;
    }
    if (_matchedTargetId == 'confirm_trip_button') {
      return null;
    }
    final renderObject = TutorialRegistry.keyFor(
      'plan_list_area',
    ).currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.attached) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      return topLeft & renderObject.size;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final step = TutorialController.instance.step;
    if (step == TutorialStep.done) return widget.child;

    final l = L10n.of(context);

    final targetRect = _targetRect;
    if (targetRect == null) return widget.child;

    final size = MediaQuery.of(context).size;
    final clampedRect = targetRect.intersect(Offset.zero & size);
    if (clampedRect.width <= 0 || clampedRect.height <= 0) {
      return widget.child;
    }
    // Widen the un-dimmed hole past the target's exact bounds so the dimming
    // bars don't clip a shadow (e.g. the add button's BoxShadow) that paints
    // outside the target's own layout box.
    final rect = clampedRect.inflate(6);

    final tooltipBelow = rect.top < size.height / 2;
    final stepText = switch (step) {
      TutorialStep.addItem => l.tutorialStepAddItem,
      TutorialStep.itemAdded => l.tutorialStepItemAdded,
      TutorialStep.completeTrip => l.tutorialStepCompleteTrip,
      TutorialStep.viewInventory => l.tutorialStepViewInventory,
      TutorialStep.finalMessage => l.tutorialFinalMessage,
      // done already returns earlier in build(), so this branch is
      // unreachable by construction.
      TutorialStep.done => '',
    };
    const barColor = Colors.black54;

    final oval = rect.inflate(_ovalPadding);
    final anchorX = rect.center.dx.clamp(32.0, size.width - 32.0);
    final arrowStart = Offset(
      anchorX,
      tooltipBelow ? rect.bottom + _bubbleGap : rect.top - _bubbleGap,
    );
    final arrowEnd = tooltipBelow ? oval.bottomCenter : oval.topCenter;

    return Stack(
      children: [
        widget.child,
        // Single full-screen dim layer covering everything, including the
        // target itself — no bright cutout there (the oval/arrow/bubble are
        // what indicate the target, not a brightness contrast). The one
        // exception is `_extraVisibleRect` (the example item's row during
        // completeTrip), kept visible so the user can still see it.
        Positioned.fill(
          child: IgnorePointer(
            child: _extraVisibleRect == null
                ? Container(color: barColor)
                : CustomPaint(
                    painter: _DimExceptPainter(
                      visible: _extraVisibleRect!,
                      color: barColor,
                    ),
                  ),
          ),
        ),
        // Invisible blockers matching the target rect: they intercept taps
        // everywhere except `rect`, where taps pass through to the real
        // widget underneath (so the target stays tappable even though it's
        // visually dimmed like everything else). AbsorbPointer is what
        // actually swallows the taps here — a plain colored/transparent box
        // doesn't intercept hit-testing on its own (`hitTestSelf` defaults to
        // false without a GestureDetector), so taps would otherwise fall
        // straight through to the real app underneath.
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: rect.top,
          child: const AbsorbPointer(),
        ),
        Positioned(
          left: 0,
          top: rect.bottom,
          right: 0,
          bottom: 0,
          child: const AbsorbPointer(),
        ),
        Positioned(
          left: 0,
          top: rect.top,
          width: rect.left,
          height: rect.height,
          child: const AbsorbPointer(),
        ),
        Positioned(
          left: rect.right,
          top: rect.top,
          right: 0,
          height: rect.height,
          child: const AbsorbPointer(),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _HandDrawnOvalPainter(oval)),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DashedArrowPainter(start: arrowStart, end: arrowEnd),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: tooltipBelow ? rect.bottom + _bubbleGap : null,
          bottom: tooltipBelow ? null : size.height - rect.top + _bubbleGap,
          child: _TutorialBubble(
            text: stepText,
            // The last step has no more "next" step to skip to — it's just
            // acknowledging the message, so it gets "Got it"/finish. The
            // itemAdded step needs an explicit user tap to move on (rather
            // than skipping the tutorial), since it isn't triggered by an
            // app action the way every other step is. Everything else gets
            // "Skip"/skip.
            skipLabel: switch (step) {
              TutorialStep.finalMessage => l.tutorialGotIt,
              TutorialStep.itemAdded => l.tutorialContinue,
              _ => l.tutorialSkip,
            },
            onSkip: switch (step) {
              TutorialStep.finalMessage => TutorialController.instance.finish,
              TutorialStep.itemAdded =>
                TutorialController.instance.advanceFromItemAdded,
              _ => TutorialController.instance.skip,
            },
          ),
        ),
      ],
    );
  }
}

/// Fills the entire overlay with [color] except for a precise rectangular
/// [visible] area, using an even-odd fill rule so coverage is always exact.
class _DimExceptPainter extends CustomPainter {
  final Rect visible;
  final Color color;
  const _DimExceptPainter({required this.visible, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(visible);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DimExceptPainter oldDelegate) =>
      oldDelegate.visible != visible || oldDelegate.color != color;
}

/// Hand-drawn-style oval outline around a tutorial target. Two overlapping
/// strokes — one plain, one slightly offset and rotated — approximate the
/// look of someone circling the target twice with a pen.
class _HandDrawnOvalPainter extends CustomPainter {
  final Rect oval;
  const _HandDrawnOvalPainter(this.oval);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(oval, paint);

    canvas.save();
    canvas.translate(oval.center.dx, oval.center.dy);
    canvas.rotate(0.05);
    canvas.translate(-oval.center.dx, -oval.center.dy);
    canvas.drawOval(oval.translate(2, -2).deflate(1.5), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandDrawnOvalPainter oldDelegate) =>
      oldDelegate.oval != oval;
}

/// Dashed curved arrow connecting the tooltip bubble to the hand-drawn oval,
/// with a small filled triangular arrowhead at [end].
class _DashedArrowPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  const _DashedArrowPainter({required this.start, required this.end});

  static const double _dashLength = 6;
  static const double _gapLength = 5;
  static const double _arrowSize = 8;
  static const double _bowAmount = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final bowSign = end.dx >= start.dx ? 1.0 : -1.0;
    final control = mid + Offset(_bowAmount * bowSign, 0);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    _drawDashed(canvas, path, paint);
    _drawArrowHead(canvas, path, paint);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gapLength;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.last;
    final tangent = metric.getTangentForOffset(metric.length);
    if (tangent == null) return;

    final tip = tangent.position;
    final angle = tangent.angle;
    final p1 =
        tip - Offset(math.cos(angle - 0.5), math.sin(angle - 0.5)) * _arrowSize;
    final p2 =
        tip - Offset(math.cos(angle + 0.5), math.sin(angle + 0.5)) * _arrowSize;

    final fillPaint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedArrowPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}

class _TutorialBubble extends StatelessWidget {
  final String text;
  final String skipLabel;
  final VoidCallback onSkip;

  const _TutorialBubble({
    required this.text,
    required this.skipLabel,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSkip,
              behavior: HitTestBehavior.opaque,
              child: Text(
                skipLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
